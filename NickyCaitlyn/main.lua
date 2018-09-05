
local preds = module.internal("pred")
local TS = module.internal("TS")
local orb = module.internal("orb")

local delayedActions, delayedActionsExecuter = {}, nil
local function DelayAction(func, delay, args) --delay in seconds
  if not delayedActionsExecuter then
    function delayedActionsExecuter()
      for t, funcs in pairs(delayedActions) do
        if t <= game.time then
          for i = 1, #funcs do
            local f = funcs[i]
            if f and f.func then
              f.func(unpack(f.args or {}))
            end
          end
          delayedActions[t] = nil
        end
      end
    end
    cb.add(cb.tick, delayedActionsExecuter)
  end
  local t = game.time + (delay or 0)
  if delayedActions[t] then
    delayedActions[t][#delayedActions[t] + 1] = {func = func, args = args}
  else
    delayedActions[t] = {{func = func, args = args}}
  end
end

local _intervalFunction
local function SetInterval(userFunction, timeout, count, params)
  if not _intervalFunction then
    function _intervalFunction(userFunction, startTime, timeout, count, params)
      if userFunction(unpack(params or {})) ~= false and (not count or count > 1) then
        DelayAction(
          _intervalFunction,
          (timeout - (game.time - startTime - timeout)),
          {userFunction, startTime + timeout, timeout, count and (count - 1), params}
        )
      end
    end
  end
  DelayAction(_intervalFunction, timeout, {userFunction, game.time, timeout or 0, count, params})
end


-- Returns percent health of @obj or player -- P_Soldier_Ring
local function GetPercentHealth(obj)
  local obj = obj or player
  return (obj.health / obj.maxHealth) * 100
end

-- Returns percent mana of @obj or player
local function GetPercentMana(obj)
  local obj = obj or player
  return (obj.mana / obj.maxMana) * 100
end

-- Returns percent par (mana, energy, etc) of @obj or player
local function GetPercentPar(obj)
  local obj = obj or player
  return (obj.par / obj.maxPar) * 100
end

local function CheckBuff(obj, buffname)
  if obj then
    for i = 0, obj.buffManager.count - 1 do
      local buff = obj.buffManager:get(i)

      if buff and buff.valid and buff.name == buffname and (buff.stacks > 0 or buff.stacks2 > 0) then
        return true
      end
    end
  end
end
local function CheckBuffType(obj, bufftype)
  if obj then
    for i = 0, obj.buffManager.count - 1 do
      local buff = obj.buffManager:get(i)
      if buff and buff.valid and buff.type == bufftype and (buff.stacks > 0 or buff.stacks2 > 0) then
        return true
      end
    end
  end
end
-- Returns @target health+shield
local yasuoShield = {100, 105, 110, 115, 120, 130, 140, 150, 165, 180, 200, 225, 255, 290, 330, 380, 440, 510}
local function GetShieldedHealth(damageType, target)
  local shield = 0
  if damageType == "AD" then
    shield = target.physicalShield
  elseif damageType == "AP" then
    shield = target.magicalShield
  elseif damageType == "ALL" then
    shield = target.allShield
  end
  return target.health + shield
end

-- Returns total AD of @obj or player
local function GetTotalAD(obj)
  local obj = obj or player
  return (obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod
end

-- Returns bonus AD of @obj or player
local function GetBonusAD(obj)
  local obj = obj or player
  return ((obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod) - obj.baseAttackDamage
end

-- Returns total AP of @obj or player
local function GetTotalAP(obj)
  local obj = obj or player
  return obj.flatMagicDamageMod * obj.percentMagicDamageMod
end

-- Returns physical damage multiplier on @target from @damageSource or player
local function PhysicalReduction(target, damageSource)
  local damageSource = damageSource or player
  local armor =
    ((target.bonusArmor * damageSource.percentBonusArmorPenetration) + (target.armor - target.bonusArmor)) *
    damageSource.percentArmorPenetration
  local lethality =
    (damageSource.physicalLethality * .4) + ((damageSource.physicalLethality * .6) * (damageSource.levelRef / 18))
  return armor >= 0 and (100 / (100 + (armor - lethality))) or (2 - (100 / (100 - (armor - lethality))))
end

-- Returns magic damage multiplier on @target from @damageSource or player
local function MagicReduction(target, damageSource)
  local damageSource = damageSource or player
  local magicResist = (target.spellBlock * damageSource.percentMagicPenetration) - damageSource.flatMagicPenetration
  return magicResist >= 0 and (100 / (100 + magicResist)) or (2 - (100 / (100 - magicResist)))
end

-- Returns damage reduction multiplier on @target from @damageSource or player
local function DamageReduction(damageType, target, damageSource)
  local damageSource = damageSource or player
  local reduction = 1
  -- Ryan Fix Please ♥
  if damageType == "AD" then
  end
  if damageType == "AP" then
  end
  return reduction
end

-- Calculates AA damage on @target from @damageSource or player
local function CalculateAADamage(target, damageSource)
  local damageSource = damageSource or player
  if target then
    return GetTotalAD(damageSource) * PhysicalReduction(target, damageSource)
  end
  return 0
end

-- Calculates physical damage on @target from @damageSource or player
local function CalculatePhysicalDamage(target, damage, damageSource)
  local damageSource = damageSource or player
  if target then
    return (damage * PhysicalReduction(target, damageSource)) *
      DamageReduction("AD", target, damageSource)
  end
  return 0
end

-- Calculates magic damage on @target from @damageSource or player
local function CalculateMagicDamage(target, damage, damageSource)
  local damageSource = damageSource or player
  if target then
    return (damage * MagicReduction(target, damageSource)) * DamageReduction("AP", target, damageSource)
  end
  return 0
end

-- Returns @target attack range (@target is optional; will consider @target boundingRadius into calculation)
local function GetAARange(target)
  return player.attackRange + player.boundingRadius + (target and target.boundingRadius or 0)
end

-- Returns ignite damage
local function GetIgniteDamage(target)
  local damage = 55 + (25 * player.levelRef)
  if target then
    damage = damage - (GetShieldedHealth("AD", target) - target.health)
  end
  return damage
end

enum = {}
enum.slots = {
  q = 0,
  w = 1,
  e = 2,
  r = 3
}
enum.buff_types = {
  Internal = 0,
  Aura = 1,
  CombatEnchancer = 2,
  CombatDehancer = 3,
  SpellShield = 4,
  Stun = 5,
  Invisibility = 6,
  Silence = 7,
  Taunt = 8,
  Polymorph = 9,
  Slow = 10,
  Snare = 11,
  Damage = 12,
  Heal = 13,
  Haste = 14,
  SpellImmunity = 15,
  PhysicalImmunity = 16,
  Invulnerability = 17,
  AttackSpeedSlow = 18,
  NearSight = 19,
  Currency = 20,
  Fear = 21,
  Charm = 22,
  Poison = 23,
  Suppression = 24,
  Blind = 25,
  Counter = 26,
  Shred = 27,
  --Flee = 28,
  Knockup = 29,
  Knockback = 30,
  Disarm = 31,
  Grounded = 32,
  Drowsy = 33,
  Asleep = 34
}

-- Returns true if @unit has buff.type btype

local hard_cc = {
  [5] = true, -- stun
  [8] = true, -- taunt
  [11] = true, -- snare
  [18] = true, -- sleep
  [21] = true, -- fear
  [22] = true, -- charm
  [24] = true, -- suppression
 -- [28] = true, -- flee
  [29] = true, -- knockup
  [30] = true -- knockback
}

-- Returns true if @object is valid target
local function IsValidTarget(object)
  return (object and not object.isDead and object.isVisible and object.isTargetable and
    not CheckBuffType(object, 17))
end

units = {}
units.minions, units.minionCount = {}, 0
units.enemyMinions, units.enemyMinionCount = {}, 0
units.allyMinions, units.allyMinionCount = {}, 0
units.jungleMinions, units.jungleMinionCount = {}, 0
units.towers, units.towerCount = {}, 0
units.enemies, units.allies = {}, {}

local function can_target_minion(minion)
  return minion and not minion.isDead and minion.team ~= TEAM_ALLY and minion.moveSpeed > 0 and minion.health and
    minion.maxHealth > 100 and
    minion.isVisible and
    minion.isTargetable
end

local excluded_minions = {
  ["CampRespawn"] = true,
  ["PlantMasterMinion"] = true,
  ["PlantHealth"] = true,
  ["PlantSatchel"] = true,
  ["PlantVision"] = true
}

local function valid_minion(minion)
  return minion and minion.type == TYPE_MINION and not minion.isDead and minion.health > 0 and minion.maxHealth > 100 and
    minion.maxHealth < 10000 and
    not minion.name:find("Ward") and
    not excluded_minions[minion.name]
end

local function valid_hero(hero)
  return hero and hero.type == TYPE_HERO
end

local function find_place_and_insert(t, c, o, v)
  local dead_place = nil
  for i = 1, c do
    local tmp = t[i]
    if not v(tmp) then
      dead_place = i
      break
    end
  end
  if dead_place then
    t[dead_place] = o
  else
    c = c + 1
    t[c] = o
  end
  return c
end

local function valid_tower(tower)
    return tower and tower.type == TYPE_TURRET -- 9217
  end

local function check_add_minion(o)
  if valid_minion(o) then
    if o.team == TEAM_ALLY then
      units.allyMinionCount =
        find_place_and_insert(units.allyMinions, units.allyMinionCount, o, valid_minion)
    elseif o.team == TEAM_ENEMY then
      units.enemyMinionCount =
        find_place_and_insert(units.enemyMinions, units.enemyMinionCount, o, valid_minion)
    else
      units.jungleMinionCount =
        find_place_and_insert(units.jungleMinions, units.jungleMinionCount, o, valid_minion)
    end
    units.minionCount = find_place_and_insert(units.minions, units.minionCount, o, valid_minion)
  end
end

local function check_add_hero(o)
  if valid_hero(o) then
    if o.team == TEAM_ALLY then
      find_place_and_insert(units.allies, #units.allies, o, valid_hero)
    else
      find_place_and_insert(units.enemies, #units.enemies, o, valid_hero)
    end
  end
end

local function check_add_tower(o)
    if valid_tower(o) then
      units.towerCount = find_place_and_insert(units.towers, units.towerCount, o, valid_tower)
    end
  end

cb.add(cb.create_minion, check_add_hero)
cb.add(cb.create_minion, check_add_minion)
cb.add(cb.create_particle, check_add_tower)

objManager.loop(
  function(obj)
    check_add_hero(obj)
    check_add_minion(obj)
    check_add_tower(obj)
  end
)

-- Returns table of ally hero.obj in @range from @pos
local function GetAllyHeroesInRange(range, pos)
  local pos = pos or player
  local h = {}
  local allies = GetAllyHeroes()
  for i = 1, #allies do
    local hero = allies[i]
    if IsValidTarget(hero) and hero.pos:distSqr(pos) < range * range then
      h[#h + 1] = hero
    end
  end
  return h
end

-- Returns table of hero.obj in @range from @pos
local function GetEnemyHeroesInRange(range, pos)
  local pos = pos or player
  local h = {}
  local enemies = GetEnemyHeroes()
  for i = 1, #enemies do
    local hero = enemies[i]
    if IsValidTarget(hero) and hero.pos:distSqr(pos) < range * range then
      h[#h + 1] = hero
    end
  end
  return h
end

_enemyTowers = nil
local function GetEnemyTowers()
  if _enemyTowers then return _enemyTowers end
  _enemyTowers = {}
  for i = 1, units.towerCount do
    local obj = units.towers[i]
    if valid_tower(obj) and obj.team ~= TEAM_ALLY then
    _enemyTowers[#_enemyTowers + 1] = obj
    end
  end
  return _enemyTowers
end

local function GetPredictedPos(obj, delay)
  if not IsValidTarget(obj) or not obj.path or not delay or not obj.moveSpeed then
    return obj
  end
  local pred_pos = preds.core.lerp(obj.path, network.latency + delay, obj.moveSpeed)
  return vec3(pred_pos.x, player.y, pred_pos.y)
end


-- Returns table and number of objects near @pos
local function CountObjectsNearPos(pos, radius, objects, validFunc)
  local n, o = 0, {}
  for i, object in pairs(objects) do
    if validFunc(object) and pos:dist(object.pos) <= radius then
      n = n + 1
      o[n] = object
    end
  end
  return n, o
end

-- Returns table of @team minion.obj in @range
local function GetMinionsInRange(range, team, pos)
  pos = pos or player.pos
  range = range or math.huge
  team = team or TEAM_ENEMY
  local validFunc = function(obj)
    return obj and obj.type == TYPE_MINION and obj.team == team and not obj.isDead and obj.health and obj.health > 0 and
      obj.isVisible
  end
  local n, o = CountObjectsNearPos(pos, range, units.minions, validFunc)
  return o
end

-- Returns table of enemy hero.obj
local function GetEnemyHeroes()
  return units.enemies
end

-- Returns table of ally hero.obj
local function GetAllyHeroes()
  return units.allies
end

-- Returns ally fountain object
_fountain = nil
_fountainRadius = 750
local function GetFountain()
  if _fountain then
    return _fountain
  end

  local map = GetMap()
  if map and map.index and map.index == 1 then
    _fountainRadius = 1050
  end

  if GetShop() then
    objManager.loop(
      function(obj)
        if
          obj and obj.team == TEAM_ALLY and obj.name:lower():find("spawn") and not obj.name:lower():find("troy") and
            not obj.name:lower():find("barracks")
         then
          _fountain = obj
          return _fountain
        end
      end
    )
  end
  return nil
end

-- Returns true if you are near fountain
local function NearFountain(distance)
  local d = distance or _fountainRadius or 0
  local fountain = GetFountain()
  if fountain then
    return (player.pos2D:distSqr(fountain.pos2D) <= d * d), fountain.x, fountain.y, fountain.z, d
  else
    return false, 0, 0, 0, 0
  end
end

-- Returns true if you are near fountain
local function InFountain()
  return NearFountain()
end

-- Returns the ally shop object
_shop = nil
_shopRadius = 1250
local function GetShop()
  if _shop then
    return _shop
  end
  objManager.loop(
    function(obj)
      if obj and obj.team == TEAM_ALLY and obj.name:lower():find("shop") then
        _shop = obj
        return _shop
      end
    end
  )
  return nil
end

--spell
local spellQ = {
	range = 1250,
	delay = 0.625,
	speed = 2200,
	width = 90,
	boundingRadiusMod = 0,
	collision = { hero = false, minion = false }
}

local spellW = {
	range = 800
}

local spellE = {
	range = 750,
	delay = 0.125,
	speed = 1600,
	width = 90,
	boundingRadiusMod = 0,
	collision = { hero = true, minion = true }
}

local rRange = { 2000, 2500, 3000 }

--spell

local ComboTrap = false
local UseNet = false
local UseNetCombo = false
local LastTrapTime = os.clock()

local ComboTrap  = false
local UseNet = false
local UseNetCombo = false 
local LastTrapTime = 0
local ComboTarget = nil



--menu

local menu = menu("Caitlyn [Update]", "[Nicky]Caitlyn")
menu:menu("combo", "Combo")
menu.combo:boolean("QInCombo","Use Q in Combo",true)
menu.combo:boolean("SafeQKS","Safe Q KS",true)
menu.combo:slider("ShortQDisableLevel", "Disable Short-Q after level", 11, 0, 18, 1)
menu.combo:boolean("WAfterE","Use W in Burst Combo",true)
menu.combo:dropdown("TrapEnemyCast", "Use W on Enemy AA/Spellcast", 1, { "Exact Position", "Vector Extension", "Turn Off" })
menu.combo:boolean("TrapImmobileCombo","Use W on Immobile Enemies",true)
menu.combo:slider("EBeforeLevel", "Disable Long-E After Level", 18, 0, 18, 1)
menu.combo:boolean("EWhenClose","Use E on Gapcloser/Close Enemy",true)
menu.combo:keybind("SemiManualEMenuKey", "E Semi-Manual Key",  "G", nil)
menu.combo:boolean("RInCombo","Use R in Combo",true)
menu.combo:keybind("SemiManualRMenuKey", "R Semi-Manual Key",  "T", nil)
menu.combo:slider("UltRange", "Dont R if Enemies in Range", 1100, 0, 3000, 1)
menu.combo:boolean("EnemyToBlockR","Dont R if an Enemy Can Block",false)

menu:menu("harass", "Harass")
menu.harass:boolean("SafeQHarass", "Use Q Smart Harass", true)
menu.harass:slider("SafeQHarassMana", "Q Harass Above Mana Percent", 60 , 0 , 100, 1)
menu.harass:dropdown("TrapEnemyCastHarass", "Use W on Enemy AA/Spellcast", 1, { "Exact Position", "Vector Extension", "Turn Off" })

menu:menu("extra", "Extra Settings")
menu.extra:slider("WDelay", "Minimum Delay Between Traps (W)", 2, 0, 15, 1)


--menu
TS.load_to_menu(menu)
local TargetSelection = function(res, obj, dist)
	if dist < spellQ.range then
		res.obj = obj
		return true
	end
end

local GetTarget = function()
	return TS.get_result(TargetSelection).obj
end

local TargetSelectionR = function(res, obj, dist)
	if dist < rRange[player:spellSlot(3).level] then
		res.obj = obj
		return true
	end
end

local GetTargetR = function()
	return TS.get_result(TargetSelectionR).obj
end

local TargetSelectionE = function(res, obj, dist)
	if dist < spellE.range then
		res.obj = obj
		return true
	end
end

local GetTargetE = function()
	return TS.get_result(TargetSelectionE).obj
end

local function DamageQ(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {30, 70, 110, 150, 190}
		local bonusR = {1.3, 1.4, 1.5, 1.6, 1.7}
        if player:spellSlot(0).state == 0 then
			Damage = (DamageAP[player:spellSlot(0).level] + bonusR[player:spellSlot(0).level] * player.baseAttackDamage + player.flatPhysicalDamageMod * 1 + player.percentPhysicalDamageMod)
        end
		return Damage
	end
	return 0
end


local function DamageR(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {250,475,700}
        if player:spellSlot(3).state == 0 then
			Damage = (DamageAP[player:spellSlot(3).level] + 2 * player.baseAttackDamage + player.flatPhysicalDamageMod * 1 + player.percentPhysicalDamageMod)
        end
		return Damage
	end
	return 0
end

local function GetAllyHeroesInRange(range, pos)
  local pos = pos or player
  local count = 0
  local allies = GetAllyHeroes()
  for i = 1, #allies do
    local hero = allies[i]
    if IsValidTarget(hero) and hero.pos:distSqr(pos) < range * range then
      count = count + 1
    end
  end
  return count
end

local function GetEnemyHeroesInRange(range, pos)
  local pos = pos or player
  local count = 0
  local enemies = GetEnemyHeroes()
  for i = 1, #enemies do
    local hero = enemies[i]
    if IsValidTarget(hero) and hero.pos:distSqr(pos) < range * range then
      count = count + 1
    end
  end
  return count
end



local function Combo()
	for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
		local flDistance = (enemy.pos - player.pos):len()
		
		if enemy == nil then return end
		if IsValidTarget(enemy) then
			if player:spellSlot(0).level > 0 and menu.combo["SafeQKS"]:get() and flDistance > 675 and GetEnemyHeroesInRange(650,player.pos) == 0 and (DamageQ(enemy) - enemy.healthRegenRate) > GetShieldedHealth("AD", enemy)
				then
				local pos = preds.linear.get_prediction(spellQ, enemy)
				if pos then
						local poss = vec3(pos.endPos.x, enemy.pos.y, pos.endPos.y)
						player:castSpell("pos", 0, poss)
					end
			end
			if player:spellSlot(3).level > 0 and menu.combo["RInCombo"]:get() and flDistance < rRange[player:spellSlot(3).level] and flDistance > menu.combo["UltRange"]:get() and (DamageR(enemy) - enemy.healthRegenRate) > GetShieldedHealth("AD", enemy) and GetEnemyHeroesInRange(menu.combo["UltRange"]:get(),player.pos) == 0
			then
				if menu.combo["EnemyToBlockR"]:get() and GetAllyHeroesInRange(550,enemy.pos) > 0 then
				    return
				end
				player:castSpell("obj", 3, enemy)
				
			end
			if player:spellSlot(1).level > 0 and  menu.combo["TrapImmobileCombo"]:get() and flDistance < spellW.range and (CheckBuffType(enemy, 11) or CheckBuffType(enemy, 5) or CheckBuffType(enemy, 24) or CheckBuffType(enemy, 29) ) then
				if os.clock() - LastTrapTime > menu.extra["WDelay"]:get() then
					player:castSpell("obj", 1, enemy)
					LastTrapTime = os.clock()
					return
				end
			end
			if player:spellSlot(2).level > 0 and menu.combo["EWhenClose"]:get() and flDistance < 300 then
				local pos2 = preds.linear.get_prediction(spellE, enemy)
				if pos2 then
					local ppos = vec3(pos2.endPos.x, enemy.pos.y, pos2.endPos.y)
					player:castSpell("pos", 2, ppos)
					ComboTarget = enemy
					UseNetCombo = true
				end
				
			end
		end

	end
end

local function OnSpell(spell)
	if orb.menu.combat:get() and menu.combo["TrapEnemyCast"]:get() < 3 and spell.owner.team == TEAM_ENEMY and spell.owner.type == TYPE_HERO and IsValidTarget(spell.owner) then
		if os.clock() - LastTrapTime > menu.extra["WDelay"]:get() then
			if menu.combo["TrapEnemyCast"]:get() == 1 then
				player:castSpell("obj", 1, spell.owner)
				LastTrapTime = os.clock()
				return
			else
				local EndPosition = player.pos + (spell.owner.pos - player.pos):norm() * ((spell.owner.pos - player.pos):len() + 50);
				player:castSpell("pos", 1, EndPosition)
				LastTrapTime = os.clock()
				return
			end
		end
	end
	
	if orb.menu.hybrid:get() and menu.harass["TrapEnemyCastHarass"]:get() < 3 and spell.owner.team == TEAM_ENEMY and spell.owner.type == TYPE_HERO and IsValidTarget(spell.owner) then
		if os.clock() - LastTrapTime > menu.extra["WDelay"]:get() then
			if menu.harass["TrapEnemyCastHarass"]:get() == 1 then
				player:castSpell("obj", 1, spell.owner)
				LastTrapTime = os.clock()
				return
			else
				local EndPosition = player.pos + (spell.owner.pos - player.pos):norm() * ((spell.owner.pos - player.pos):len() + 50);
				player:castSpell("pos", 1, EndPosition)
				LastTrapTime = os.clock()
				return
			end
		end
	end
	
	if (orb.menu.lane_clear:get() or orb.menu.hybrid:get() ) and spell.owner.team == TEAM_ENEMY and spell.owner.type == TYPE_HERO and IsValidTarget(spell.owner) then
		if menu.harass["SafeQHarass"]:get() and GetPercentMana(player) > menu.harass["SafeQHarassMana"]:get() and GetEnemyHeroesInRange(800, player) == 0 then
			local pos31 = preds.linear.get_prediction(spellQ, spell.owner)
			if pos31 then
				local posss = vec3(pos31.endPos.x, spell.owner.pos.y, pos31.endPos.y)
				player:castSpell("pos", 0, posss)
			end
		end
	end
	
	if spell and menu.combo["QInCombo"]:get() and spell.name == "CaitlynHeadshotMissile" and spell.target.type == TYPE_HERO and IsValidTarget(spell.target) then
		local flDistance = (spell.target.pos - player.pos):len();
		if flDistance < spellQ.range then
			if flDistance > 650 or player.levelRef < menu.combo["ShortQDisableLevel"]:get() then
				local target = GetTarget()
				
				if target == nil then return end
				
				local pos = preds.linear.get_prediction(spellQ, target)
				if pos then
					local poss = vec3(pos.endPos.x, target.pos.y, pos.endPos.y)
					player:castSpell("pos", 0, poss)
				end
			end
		end
	end
	
	if spell and menu.combo["WAfterE"]:get() and spell.name == "CaitlynEntrapment" then
		if ComboTarget ~= nil and IsValidTarget(ComboTarget) then
			local EstimatedEnemyPos = GetPredictedPos(ComboTarget, 0.5)
			if EstimatedEnemyPos then
				player:castSpell("pos", 1, EstimatedEnemyPos)
				return
			end
		end
	end
end
	

local function OnTick()
    if orb.menu.combat:get()
	then
		Combo()
	end
	
	if menu.combo["SemiManualRMenuKey"]:get() then
		local target = GetTargetR()
		
		if target == nil then return end
		
		player:castSpell("obj", 3, target)		
	end
	
	if menu.combo["SemiManualEMenuKey"]:get() then
		local target = GetTargetE()
		
		if target == nil then return end
		
		local pos2 = preds.linear.get_prediction(spellE, target)
		if pos2 then
			local ppos = vec3(pos2.endPos.x, target.pos.y, pos2.endPos.y)
			player:castSpell("pos", 2, ppos)
			ComboTarget = target
			UseNetCombo = true
		end	
	end
end

cb.add(cb.draw, function()

end)
cb.add(cb.spell, OnSpell)
cb.add(cb.tick, OnTick)
orb.combat.register_f_after_attack(function()
	if orb.combat.target == nil then return end
	
	local target = orb.combat.target
	local pos2 = preds.linear.get_prediction(spellE, target)
					
	if orb.menu.combat:get() and target.type == TYPE_HERO and IsValidTarget(target) then
		if player.levelRef <= menu.combo.EBeforeLevel:get() and pos2 then
			local ppos = vec3(pos2.endPos.x, target.pos.y, pos2.endPos.y)
			player:castSpell("pos", 2, ppos)
			UseNetCombo = true
            ComboTarget = target
			return
		end
	end
end
)