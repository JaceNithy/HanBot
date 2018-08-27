--Update: By JaceNicky and MrImpressive
local pred = module.internal('pred')
local TS = module.internal('TS')
local orb = module.internal("orb")
local EvadeInternal = module.seek("evade")

-- Delay Functions Call
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

-- Returns @obj predicted pos after @delay secs
local function GetPredictedPos(obj, delay)
  if not IsValidTarget(obj) or not obj.path or not delay or not obj.moveSpeed then
    return obj
  end
  local pred_pos = pred.core.lerp(obj.path, network.latency + delay, obj.moveSpeed)
  return vec3(pred_pos.x, player.y, pred_pos.y)
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


local enemies = GetEnemyHeroes()
local allies = GetAllyHeroes()

local objHolder = {}
local objTimeHolder = {}
local t = {}

t.pos = mousePos

local spellQ = {
    range = 740,
    speed = 1600,
    delay = 0.25,
    width = 150,
    mana = 70,
    collision = false,
    boundingRadiusMod = 1
}

local spellW = {
    range = 500,
    speed = math.huge,
    delay = 0.25,
    radius = 315,
    mana = 40,
    collision = false,
    boundingRadiusMod = 1
}

local spellE = {
    range = 1100,
    speed = 1200,
    delay = 0,
    width = 315,
    mana = 60,
    hitbox = 60,
    collision = true,
    boundingRadiusMod = 1
}

local spellR = {
    range = 250,
    speed = 1300,
    delay = 0.5,
    width = 600,
    mana = 100,
    collision = true,
    boundingRadiusMod = 1
}

local azirAA = {
    range = 525
}

local soldierAA = {
    range = 315
}

local menu = menu("AzirMenu", "[Nicky]Azir")

menu:menu("qsettings", "Q Settings")
    menu.qsettings:boolean("qw", "Use Q If Out Of W Range", true)

menu:menu("rsettings", "R Settings")
	menu.rsettings:header("fill", "Offensive")
	menu.rsettings:boolean("smartr", "Use Smart R For Kill",  true)
	menu.rsettings:header("fill", "Defensive")
	menu.rsettings:boolean("protectcombo", "Protect In Combo Mode Only", true)
	menu.rsettings:dropdown("fill", "", 1, {""})
	menu.rsettings:boolean("protectgap", "Protect From Gap Closers", true)
	menu.rsettings:dropdown("fill", "", 1, {""})
	menu.rsettings:boolean("protectenemy", "Protect From Enemies In Range", true)
	menu.rsettings:slider("protectnumenemy", "Protect If X Enemies In Range", 1, 1, 5, 1)

menu:menu("combo", "Combo")
	menu.combo:boolean("qcombo", "Use Q", true)
	menu.combo:boolean("ecombo", "Use E", true)
	menu.combo:dropdown("fill", "", 1, {""})
	menu.combo:slider("qmana", "Q Minimum % Mana", 0, 0, 100, 1)
	menu.combo:slider("emana", "E Minimum % Mana", 0, 0, 100, 1)

menu:menu("harass", "Harass")
	menu.harass:boolean("qharass", "Use Q", true)
	menu.harass:boolean("eharass", "Use E", false)
	menu.harass:dropdown("fill", "", 1, {""})
	menu.harass:slider("qmana", "Q Minimum % Mana", 40, 0, 100, 1)
	menu.harass:slider("emana", "E Minimum % Mana", 40, 0, 100, 1)

menu:menu("laneclear", "Lane Clear")
	menu.laneclear:boolean("qlaneclear", "Use Q", true)
	menu.laneclear:dropdown("fill", "", 1, {""})
	menu.laneclear:boolean("smartclear", "Use Smart Clear", true)
	menu.laneclear:dropdown("fill", "", 1, {""})
	menu.laneclear:slider("qmana", "Q Minimum % Mana", 60, 0, 100, 1)
	menu.laneclear:slider("wmana", "W Minimum % Mana", 40, 0, 100, 1)

menu:menu("lasthit", "Last Hit")
	menu.lasthit:boolean("qlasthit", "Use Q", true)

menu:menu("draws", "Draw Settings")
	menu.draws:header("fill", "Spell Draws")
	menu.draws:boolean("drawq", "Draw Q", true)
	menu.draws:color("colorq", "Color Q", 255, 255, 255, 255)
	menu.draws:dropdown("fill", "", 1, {""})
	menu.draws:boolean("draww", "Draw W", true)
	menu.draws:color("colorw", "Color W", 255, 0x66, 0x33, 0x00 )
	menu.draws:dropdown("fill", "", 1, {""})
	menu.draws:boolean("drawe", "Draw E", true)
	menu.draws:color("colore", "Color E", 255, 0x66, 0x33, 0x00)
    menu.draws:dropdown("fill", "", 1, {""})
    menu.draws:boolean("drawtarget", "Draw Target", true)
    menu.draws:color("colortarget", "Color Target", 255, 0x66, 0x33, 0x00)

menu:menu("key", "Key Settings")
    menu.key:header("fill", "Spell Keys")
    menu.key:keybind("combokey", "Combo Key", "Space", nil)
	menu.key:keybind("harasskey", "Harass Key", "X", nil)
	menu.key:keybind("clearkey", "Lane Clear Key", "A", nil)
	menu.key:keybind("lasthitkey", "Last Hit Key", "S", nil)
    menu.key:header("fill", "Miscellaneous Keys")
	menu.key:keybind("fleekey", "Flee Key", "Z", nil)
	menu.key:keybind("inseckey", "Insec Key", "C", nil)

TS.load_to_menu(menu)

local function GetDistanceSqr(p1, p2)
    local p2 = p2 or player
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return dx * dx + dz * dz
end

local function GetDistance(one, two)
    if (not one or not two) then
        return math.huge
    end

    return one.pos:dist(two)
end

-- See If Enemy Is Under Tower --
local function UnderTower(unit)
    enemyTowers = GetEnemyTowers()
    for i = 1, #enemyTowers do
		local tower = enemyTowers[i]
        if GetDistance(player, tower) < 775 + spellW.range then
            if GetDistance(unit, tower) <= 775 then -- Tower range
                return true
            else
                return false
            end
        end
    end
end

-- Counting Soldiers --
local function CreateObj(object)
    if object and object.name then
        if string.find(object.name, "Base_P_Soldier_Ring") then --Base_W_SoldierIndicator
            if UnderTower(object) then
                objHolder[object.ptr] = object
				objTimeHolder[object.ptr] = game.time + 6
			else
				objHolder[object.ptr] = object
				objTimeHolder[object.ptr] = game.time + 11
			end
        end
    end
end

local function CountSoldiers()
    soldiers = 0
    for _, obj in pairs(objHolder) do
        if objTimeHolder[obj.ptr] and objTimeHolder[obj.ptr] > game.time and GetDistance(obj, player) < 2000 then
            soldiers = soldiers + 1
        end
    end
    return soldiers
end

local function GetSoldier(i)
    soldiers = 0
    for _,obj in pairs(objHolder) do
        if objTimeHolder[obj.ptr] and objTimeHolder[obj.ptr] > game.time then
            soldiers = soldiers + 1
            if i == soldiers then
                return obj
            end
        end
    end
end

local function GetSoldiers()
    soldiers = {}
    for _,obj in pairs(objHolder) do
        if objTimeHolder[obj.ptr] and objTimeHolder[obj.ptr] > game.time then
            table.insert(soldiers, obj)
        end
    end
    return soldiers
end

local TargetSelection = function(res, obj, dist)
    if dist < 2000 then
      res.obj = obj
      return true
    end
end

local res = {}

local GetTarget = function()
    return TS.get_result(TargetSelection).obj
end

-- Check If Spell Is Ready --
local function IsReady(spell)
    return player:spellSlot(spell).state == 0
end

--Damage Calcs --
local function GetDmg(spell, unit)
	local lvl = player:spellSlot(spell).level
	if spell == 0 and IsReady(0) then
		local baseDamageQ = {60, 80, 100, 120, 140}
		local trueDamageQ = (baseDamageQ[lvl] + 0.3 * (player.flatMagicDamageMod * player.percentMagicDamageMod))
		return CalculateMagicDamage(unit, trueDamageQ, player)
	elseif spell == 2 and IsReady(2) then
		local baseDamageE = {60, 90, 120, 150, 180}
		local trueDamageE = (baseDamageE[lvl] + 0.4 * (player.flatMagicDamageMod * player.percentMagicDamageMod))
		return CalculateMagicDamage(unit, trueDamageE, player)
	elseif spell == 3 and IsReady(3) then
		local baseDamageR = {150, 250, 450}
		local trueDamageR = (baseDamageR[lvl] + 0.6 * (player.flatMagicDamageMod * player.percentMagicDamageMod))
		return CalculateMagicDamage(unit, trueDamageR, player)
	end
end

-- Check Percent Health --
local function EnemyHPPercent(range)
	local h = 0
	local mh = 0
	for _,v in pairs(enemies) do
		if v.visible and range > GetDistance(player, v) then
			h = h + v.health
			mh = mh + v.maxHealth
		end
			h = h / #enemies
			mh = mh / #enemies
	return h / mh  *100 -- Percent
	end
end

local function AllyHPPercent(range)
	local h = 0
	local mh = 0
	for _,v in pairs(allies) do
		if v.isVisible and range > GetDistance(player, v) then
			h = h + v.health
			mh = mh + v.maxHealth
		end
			h = h / #allies
			mh = mh / #allies
	return h / mh * 100 -- Percent
	end
end

-- Count # Objects In Circle --
local function CountObjectsInCircle(pos, radius, pos2)
	if not pos then return -1 end
	if not pos2 then return -1 end

	local n = 0
	if GetDistance(pos, pos2) <= radius and not pos2.isDead then
        n = n + 1
    end

    return n
end


local function VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.pos.x, (v.pos.z or v.pos.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or { x = ax + rS * (bx - ax), y = ay + rS * (by - ay) }
    return pointSegment, pointLine, isOnSegment
end

-- Find Best Position To Cast Spell For Enemy Heroes --
local function CountEnemyOnLineSegment(StartPos, EndPos, width, objects)
    local n = 0
    for i, enemy in ipairs(enemies) do
		if not enemy and not enemy.isDead then
			local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(StartPos, EndPos, enemy)
			if isOnSegment and GetDistance(pointSegment, enemy) < width * width and GetDistance(StartPos, EndPos) > GetDistance(StartPos, enemy) then
				n = n + 1
			end
		end
    end
    return n
end

local function CountEnemyHitOnLine(slot, from, target, enemy)
	return CountEnemyOnLineSegment(from, Normalize(target, from, soldierAA.range), spellW.hitbox, enemy)
end

-- Gets Best Position To Cast Spell For Farming --
local function CountMinionsInCircle(pos, radius, objects)
    local n = 0
    for i, object in ipairs(objects) do
        if GetDistance(pos, object) <= radius * radius then
            n = n + 1
        end
    end
    return n
end

local function GetBestFarmPosition(range)
    local BestPos
    local BestHit = 0
    local enemyMinions = GetMinionsInRange(1000, TEAM_ENEMY)
    for i, object in ipairs(enemyMinions) do
        local hit = CountMinionsInCircle(object, range, enemyMinions)
        if hit > BestHit then
            BestHit = hit
            BestPos = object
            if BestHit == #enemyMinions then
               break
            end
         end
    end
    return BestPos, BestHit
end

local function ClosestMinionToSoldier()
	local distanceMinion = math.huge
    local enemyMinions = GetMinionsInRange(1000, TEAM_ENEMY)
	if CountSoldiers() > 0 then
		for _,k in pairs(GetSoldiers()) do
			for i, cminion in ipairs(enemyMinions) do
				if cminion and not cminion.isDead then
					if GetDistance(k, cminion) < distanceMinion then
						distanceMinion = GetDistance(k, cminion)
					end
				end
			end
		end
	end
	return distanceMinion
end

-- Random Calcs --
local function Normalize(pos, start, range)
	local castX = start.x + range * ((pos.x - start.x) / GetDistance(player, pos))
	local castZ = start + range * ((pos.y - start.y) / GetDistance(player, pos))

	return {x = castX, z = castZ}
end


local function A2V ( a, m )
	m = m or 1
	local x = math.cos ( a ) * m
	local y = math.sin ( a ) * m
	return x, y
end

local function ECheck()
    local target = GetTarget()

	if not IsValidTarget(target) then
		return
	end

    for i, enemy in ipairs(enemies) do
        for _, ally in ipairs(allies) do
            if CountObjectsInCircle(target, 2000, ally) >= CountObjectsInCircle(target, 2000, enemy) then
                if AllyHPPercent(2000) - EnemyHPPercent(2000) > 30 then
                  return true
                end
                if EnemyHPPercent(2000) < AllyHPPercent(2000) and EnemyHPPercent(2000) < 50 then
                  return true
                end
            end
        end
    end
    return false
end

local function towerCheck()
    local target = GetTarget()

	if not IsValidTarget(target) then
		return
	end

    if UnderTower(target) then
        if target.health > GetDmg(2, target) - 5 then
    		return false
    	elseif target.health < GetDmg(2, target) - 5 and GetPercentHealth(player) > 35 then
    		return true
        end
    else
        return true
    end
end

local function qCheck()
    local target = GetTarget()

    if pred.trace.newpath(target, 0.033, 0.500) then
      return true
    end
end

local function Combo()
    local target = GetTarget()

	if not IsValidTarget(target) then
		return
	end

    local posBehind = target.pos:lerp(player.pos, -200 / target.pos:dist(player.pos))

    if menu.key.combokey:get() then
		for i, enemy in ipairs(enemies) do
        	-- Casting Soldiers --
			if CountObjectsInCircle(player, 2000, enemy) <= 3 then
				if IsReady(1) and GetDistance(player, posBehind) < (spellW.range) then
                    if posBehind then
                        player:castSpell("pos", 1, vec3(posBehind.x, t.pos.y, posBehind.z))
                        if CountSoldiers() > 0 then
                            for _,k in pairs(GetSoldiers()) do
                                player:attack(target)
                            end
                        end
                    end
                elseif IsReady(1) and GetDistance(player, target) < (spellW.range + (soldierAA.range / 2)) then
                    local pos = pred.circular.get_prediction(spellW, target)
					if pos then
						player:castSpell("pos", 1, vec3(pos.endPos.x, t.pos.y, pos.endPos.y))
                        if CountSoldiers() > 0 then
                            for _,k in pairs(GetSoldiers()) do
                                player:attack(target)
                            end
                        end
					end
				elseif IsReady(0) and IsReady(1) and GetDistance(player, target) < (spellQ.range + soldierAA.range) and GetDistance(player, target) > (spellW.range) + (soldierAA.range / 2) then
					if menu.qsettings.qw:get() then
						if player.mana > menu.combo.qmana:get() and player.mana >= (spellQ.mana + spellW.mana) then
							local pos = pred.linear.get_prediction(spellQ, target)
							if pos and pos.startPos:dist(pos.endPos) < (spellQ.range + soldierAA.range / 2) and qCheck() then
								player:castSpell("self", 1)
						        DelayAction(player:castSpell("pos", 0, vec3(pos.endPos.x, t.pos.y, pos.endPos.y)), 0.25)
                                if CountSoldiers() > 0 then
                					for _,k in pairs(GetSoldiers()) do
                                        player:attack(target)
                                    end
                                end
							end
						end
					end
				end
			elseif CountObjectsInCircle(player, 2000, enemy) >= 4 then
				if IsReady(1) and GetDistance(player, posBehind) < (spellW.range) then
                    if posBehind then
                        player:castSpell("pos", 1, vec3(posBehind.x, t.pos.y, posBehind.z))
                        if CountSoldiers() > 0 then
                            for _,k in pairs(GetSoldiers()) do
                                player:attack(target)
                            end
                        end
                    end
                elseif IsReady(1) and GetDistance(player, target) < (spellW.range + (soldierAA.range / 2)) then
                    local pos = pred.circular.get_prediction(spellW, target)
					if pos then
						player:castSpell("pos", 1, vec3(pos.endPos.x, t.pos.y, pos.endPos.y))
                        if CountSoldiers() > 0 then
                            for _,k in pairs(GetSoldiers()) do
                                player:attack(target)
                            end
                        end
					end
				elseif IsReady(0) and IsReady(1) and GetDistance(player, target) < (spellQ.range) + (soldierAA.range / 2) and GetDistance(player, target) > (spellW.range) + (soldierAA.range / 2) then
					if menu.qsettings.qw:get() then
						if player.mana > menu.combo.qmana:get() and player.mana >= (spellQ.mana + spellW.mana) then
							if CountEnemyHitOnLine(0, player, target, enemy) >= 1 then
								local pos = pred.linear.get_prediction(spellQ, target)
								if pos and pos.startPos:dist(pos.endPos) < (spellQ.range) + (soldierAA.range / 2) and qCheck() then
									player:castSpell("self", 1)
							        DelayAction(player:castSpell("pos", 0, vec3(pos.endPos.x, t.pos.y, pos.endPos.y)), 0.25)
                                    if CountSoldiers() > 0 then
                    					for _,k in pairs(GetSoldiers()) do
                                            player:attack(target)
                                        end
                                    end
								end
							end
						end
					end
				end
			end

	-- Actual Combo --
		-- One Champion In Range --
			if CountObjectsInCircle(player, 2000, enemy) >= 1 then
				if CountSoldiers() > 0 then
					for _,k in pairs(GetSoldiers()) do
						if menu.combo.qcombo:get() then
							if IsReady(0) then
								if GetDistance(k, target) > soldierAA.range and GetDistance(player, target) < (spellQ.range + (soldierAA.range / 2)) then
									local pos = pred.linear.get_prediction(spellQ, target)
									if pos and pos.startPos:dist(pos.endPos) < (spellQ.range + (soldierAA.range / 2)) and qCheck() then
										player:castSpell("pos", 0, vec3(pos.endPos.x, t.pos.y, pos.endPos.y))
                                        player:attack(target)
									end
								elseif GetDistance(k, target) < soldierAA.range and GetDistance(player, target) < (spellQ.range + (soldierAA.range / 2)) then
									if target.health < GetDmg(0, target) - 5 then
										local pos = pred.linear.get_prediction(spellQ, target)
										if pos and pos.startPos:dist(pos.endPos) < (spellQ.range + (soldierAA.range / 2)) and qCheck() then
											player:castSpell("pos", 0, vec3(pos.endPos.x, t.pos.y, pos.endPos.y))
                                            player:attack(target)
										end
									end
								end
							end
						end
						if menu.combo.qcombo:get() and menu.combo.ecombo:get() then
							if IsReady(1) and IsReady(3) then
								if player.mana > menu.combo.qmana:get() and player.mana > menu.combo.emana:get() and player.mana >= (spellQ.mana + spellE.mana) then
									if GetDistance(k, target) > soldierAA.range and  GetDistance(player, target) > spellQ.range then
										if GetDistance(k, target) < spellQ.range and GetDistance(k, player) < spellE.range then
											if ECheck() == true and towerCheck() == true then
												player:castSpell("self", 2)
												local pos = pred.linear.get_prediction(spellQ, target)
												if pos and pos.startPos:dist(pos.endPos) < spellQ.range then
													player:castSpell("pos", 0, vec3(pos.endPos.x, t.pos.y, pos.endPos.y))
                                                    player:attack(target)
												end
											end
										end
									end
								end
							end
						end
						-- E For Auto AA --
						if menu.combo.ecombo:get() then
							if IsReady(2) then
								if GetDistance(k, target) < azirAA.range and GetDistance(k, target) > soldierAA.range and GetDistance(k, target) < spellE.range then
									if ECheck() == true and towerCheck() == true then
										player:castSpell("self", 2)
                                        player:attack(target)
									end
								end
							end
							-- Enemy Directly Infront --
							if IsReady(2) then
								if GetDistance(player, enemy) < (player.boundingRadius + 100) then
                                    for i, ally in pairs(allies) do
    									if CountObjectsInCircle(player, azirAA.range, ally) <= 1 and player.health < enemy.health then
    										player:castSpell("self", 2)
    									end
                                    end
								end
							end
                            -- E For Kil --
							if IsReady(2) then
								if GetDistance(player, target) < soldierAA.range then
									if ECheck() == true and towerCheck() == true then
										if target.health < GetDmg(2, target) - 5 then
											local x, y = VectorPointProjectionOnLineSegment(player, k, target)
								        	if y and GetDistance(target, x) < (spellE.hitbox ^ 2) then
												player:castSpell("self", 2)
											end
										end
								    end
								end
							end
                            -- E To Try And Avoid Death --
                            if IsReady(2) then
                                if GetPercentHealth(player) < 10 then
                                    player:castSpell("self", 2)
                                end
                            end
						end
					end
				end

                -- R For Kill --
				if menu.rsettings.smartr:get() then
					if IsReady(3) and not IsReady(1) then
						if target.health < GetDmg(3, target) - 5 then
                            if CountSoldiers() == 0 then
								if GetDistance(player, target) < spellR.range then
									player:castSpell("obj", 3, target)
								end
							elseif CountSoldiers() > 0 then
								if GetDistance(player, target) > soldierAA.range then
									if GetDistance(player, target) < spellQ.range and not IsReady(0) then
										if GetDistance(player, target) < spellW.range and not IsReady(1) then
											if GetDistance(player, target) < spellR.range and IsReady(3) then
												player:castSpell("obj", 3, target)
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

local function Harass()
    local target = GetTarget()

	if not IsValidTarget(target) then
		return
	end

    local posBehind = target.pos:lerp(player.pos, -200 / target.pos:dist(player.pos))

    if menu.key.harasskey:get() then
		for i, enemy in ipairs(enemies) do

            -- Casting Soldiers --
			if CountObjectsInCircle(player, 2000, enemy) <= 3 then
                if CountSoldiers() > 0 then
                    for _, k in pairs(GetSoldiers()) do
                        if GetDistance(k, target) < soldierAA.range then
                            return
                        end
                    end
                else
    				if IsReady(1) and GetDistance(player, posBehind) < (spellW.range) then
                        if posBehind then
                            player:castSpell("pos", 1, vec3(posBehind.x, t.pos.y, posBehind.z))
                            if CountSoldiers() > 0 then
                                for _,k in pairs(GetSoldiers()) do
                                    player:attack(target)
                                end
                            end
                        end
                    elseif IsReady(1) and GetDistance(player, target) < (spellW.range + (soldierAA.range / 2)) then
                        local pos = pred.circular.get_prediction(spellW, target)
    					if pos then
    						player:castSpell("pos", 1, vec3(pos.endPos.x, t.pos.y, pos.endPos.y))
                            if CountSoldiers() > 0 then
                                for _,k in pairs(GetSoldiers()) do
                                    player:attack(target)
                                end
                            end
    					end
                    elseif IsReady(0) and IsReady(1) and GetDistance(player, posBehind) < (spellQ.range) and GetDistance(player, target) > (spellW.range) + (soldierAA.range / 2) then
                        if CountSoldiers == 0 then
    						if menu.qsettings.qw:get() then
    							if player.mana > menu.harass.qmana:get() and player.mana >= (spellQ.mana + spellW.mana) then
    								if posBehind then
    									player:castSpell("self", 1)
    							        DelayAction(player:castSpell("pos", 0, vec3(posBehind.x, t.pos.y, posBehind.z)), 0.25)
                                        if CountSoldiers() > 0 then
                        					for _,k in pairs(GetSoldiers()) do
                                                player:attack(target)
                                            end
                                        end
    								end
    							end
    						end
    					end
    				elseif IsReady(0) and IsReady(1) and GetDistance(player, target) < (spellQ.range + soldierAA.range / 2) and GetDistance(player, target) > (spellW.range) + (soldierAA.range / 2) then
    					if CountSoldiers == 0 then
    						if menu.qsettings.qw:get() then
    							if player.mana > menu.harass.qmana:get() and player.mana >= (spellQ.mana + spellW.mana) then
    	                            local pos = pred.linear.get_prediction(spellQ, target)
    								if pos and pos.startPos:dist(pos.endPos) < (spellQ.range + soldierAA.range) then
    									player:castSpell("self", 1)
    							        DelayAction(player:castSpell("pos", 0, vec3(pos.endPos.x, t.pos.y, pos.endPos.y)), 0.25)
                                        if CountSoldiers() > 0 then
                        					for _,k in pairs(GetSoldiers()) do
                                                player:attack(target)
                                            end
                                        end
    								end
    							end
    						end
    					end
    				end
                end
			elseif CountObjectsInCircle(player, 2000, enemy) >= 4 then
				if IsReady(1) and GetDistance(player, posBehind) < (spellW.range) then
                    if posBehind then
                        player:castSpell("pos", 1, vec3(posBehind.x, t.pos.y, posBehind.z))
                        if CountSoldiers() > 0 then
                            for _,k in pairs(GetSoldiers()) do
                                player:attack(target)
                            end
                        end
                    end
                elseif IsReady(1) and GetDistance(player, target) < (spellW.range + (soldierAA.range / 2)) then
                    local pos = pred.circular.get_prediction(spellW, target)
					if pos then
						player:castSpell("pos", 1, vec3(pos.endPos.x, t.pos.y, pos.endPos.y))
                        if CountSoldiers() > 0 then
                            for _,k in pairs(GetSoldiers()) do
                                player:attack(target)
                            end
                        end
					end
				elseif IsReady(0) and IsReady(1) and GetDistance(player, target) < (spellQ.range) + (soldierAA.range / 2) and GetDistance(player, target) > (spellW.range) + (soldierAA.range / 2) then
					if menu.qsettings.qw:get() then
						if player.mana > menu.harass.qmana:get() and player.mana >= (spellQ.mana + spellW.mana) then
							if CountEnemyHitOnLine(0, player, target, enemy) >= 1 then
                                local pos = pred.linear.get_prediction(spellQ, target)
    							if pos and pos.startPos:dist(pos.endPos) < (spellQ.range) + (soldierAA.range / 2) then
    								player:castSpell("self", 1)
    						        DelayAction(player:castSpell("pos", 0, vec3(pos.endPos.x, t.pos.y, pos.endPos.y)), 0.25)
                                    if CountSoldiers() > 0 then
                    					for _,k in pairs(GetSoldiers()) do
                                            player:attack(target)
                                        end
                                    end
    							end
							end
						end
					end
				end
			end

	-- Actual Harass --
		-- One Champion In Range --
			if CountObjectsInCircle(player, 2000, enemy) >= 1 then
				if CountSoldiers() > 0 then
					for _,k in pairs(GetSoldiers()) do
						if menu.harass.qharass:get() then
							if IsReady(0) then
								if GetDistance(k, target) > soldierAA.range and GetDistance(player, posBehind) < (spellQ.range) then
                                    if posBehind then
                                        player:castSpell("pos", 0, vec3(posBehind.x, t.pos.y, posBehind.z))
                                        player:attack(target)
                                    end
                                elseif GetDistance(k, target) > soldierAA.range and GetDistance(player, target) < (spellQ.range + (soldierAA.range / 2)) then
                                    local pos = pred.linear.get_prediction(spellQ, target)
                                    if pos and pos.startPos:dist(pos.endPos) < (spellQ.range + (soldierAA.range / 2)) then
                                        player:castSpell("pos", 0, vec3(pos.endPos.x, t.pos.y, pos.endPos.y))
                                        player:attack(target)
                                    end
								elseif GetDistance(k, target) < soldierAA.range and GetDistance(player, target) < (spellQ.range + (soldierAA.range / 2)) then
									if target.health < GetDmg(0, target) - 5 then
                                        local pos = pred.linear.get_prediction(spellQ, target)
										if pos and pos.startPos:dist(pos.endPos) < (spellQ.range + (soldierAA.range / 2)) then
											player:castSpell("pos", 0, vec3(pos.endPos.x, t.pos.y, pos.endPos.y))
                                            player:attack(target)
										end
									end
								end
							end
						end
						if menu.harass.qharass:get() and menu.harass.eharass:get() then
							if IsReady(0) and IsReady(2) then
								if player.mana > menu.harass.qmana:get() and player.mana > menu.harass.emana:get() and player.mana >= (spellQ.mana + spellE.mana) then
									if GetDistance(k, target) > soldierAA.range and  GetDistance(player, target) > spellQ.range then
										if GetDistance(k, target) < spellQ.range and GetDistance(k, player) < spellE.range then
											if ECheck() == true and towerCheck() == true then
                                                player:castSpell("self", 2)
												local pos = pred.linear.get_prediction(spellQ, target)
												if pos and pos.startPos:dist(pos.endPos) < spellQ.range then
													player:castSpell("pos", 0, vec3(pos.endPos.x, t.pos.y, pos.endPos.y))
                                                    player:attack(target)
												end
											end
										end
									end
								end
							end
						end
						-- E For Auto AA --
						if menu.harass.eharass:get() then
							if not IsReady(0) and IsReady(2) then
								if GetDistance(k, target) < azirAA.range and GetDistance(k, target) > soldierAA.range and GetDistance(k, player) < spellE.range then
									if ECheck() == true and towerCheck() == true then
										player:castSpell("self", 2)
                                        player:attack(target)
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

local function LaneClear()
    local enemyMinions = GetMinionsInRange(1000, TEAM_ENEMY)

	if not enemyMinions then
		return
	end

	if menu.key.clearkey:get() then
		if menu.laneclear.smartclear:get() then
			if GetPercentPar(player) >= menu.laneclear.wmana:get() then

				-- Casting Soldiers --
				for i, minion in pairs(enemyMinions) do
					if CountObjectsInCircle(player, spellW.range, minion) <= 5 and not minion.isDead then
						if CountSoldiers() > 0 then
							for _,k in pairs(GetSoldiers()) do
								if GetDistance(k, minion) < soldierAA.range and CountSoldiers() >= 1 then
									return
								elseif GetDistance(k, minion) > soldierAA.range and not IsReady(0) and CountSoldiers() >= 1 then
									return
								end
							end
						elseif CountSoldiers() == 0 then
							if IsReady(1) then
								local BestPos, BestHit = GetBestFarmPosition(spellW.range + soldierAA.range / 2)
								if BestPos and BestHit >= 2 then
									player:castSpell("pos", 1, vec3(BestPos.x, BestPos.y, BestPos.z))
								end
							end
						end

					elseif CountObjectsInCircle(player, spellW.range, minion) >= 6 and not minion.isDead then

						if CountSoldiers() > 0 then
							for _,k in pairs(GetSoldiers()) do
								if GetDistance(k, minion) < soldierAA.range and CountSoldiers() >= 2 then
									return
								elseif GetDistance(k, minion) > soldierAA.range and not IsReady(0) and CountSoldiers() >= 2 then
									return
								end
							end
						elseif CountSoldiers() == 0 then
							if IsReady(1) then
								local BestPos, BestHit = GetBestFarmPosition(spellW.range + soldierAA.range / 2)
								if BestPos and BestHit >= 3 then
									player:castSpell("pos", 1, vec3(BestPos.x, BestPos.y, BestPos.z))
								end
							end
						end
					end

					-- Lane Clear Logic --
					if CountSoldiers() > 0 then
						for _,k in pairs(GetSoldiers()) do
							for i, enemy in ipairs(enemies) do
								if not enemy or GetDistance(player, enemy) > 2000 and ClosestMinionToSoldier() > soldierAA.range and not minion.isDead then
									if menu.laneclear.qlaneclear:get() and IsReady(0) then
										local BestPos, BestHit = GetBestFarmPosition(spellQ.range + soldierAA.range / 2)
										if BestPos and BestHit >= 2 then
											if CountObjectsInCircle(BestPos, azirAA.range, minion) > CountObjectsInCircle(k, azirAA.range, minion) then
												player:castSpell("pos", 0, vec3(BestPos.x, BestPos.y, BestPos.z))
											end
										end
									end
								end
							end
						end
					end
		        end
			end
		else
			if GetPercentPar(player) >= menu.laneclear.wmana:get() then

				-- Casting Soldiers --
				for i, minion in pairs(enemyMinions) do
					if CountSoldiers() > 0 then
						for _,k in pairs(GetSoldiers()) do
							if IsReady(1) then
								local BestPos, BestHit = GetBestFarmPosition(soldierAA.range)
								if BestPos and BestHit >= 0 then
                                    player:castSpell("pos", 1, vec3(BestPos.x, BestPos.y, BestPos.z))
								end
							end
						end
					end

					-- Lane Clear Logic --
					if CountSoldiers() > 0 then
						for _,k in pairs(GetSoldiers()) do
							for i, enemy in ipairs(enemies) do
								if not enemy or GetDistance(player, enemy) > 2000 and GetDistance(k, minion) > soldierAA.range and not minion.isDead then
									if menu.laneclear.qlaneclear:get() and IsReady(0) then
										local BestPos, BestHit = GetBestFarmPosition(spellQ.range + soldierAA.range / 2)
										if BestPos and BestHit >= 1 then
											player:castSpell("pos", 0, vec3(BestPos.x, BestPos.y, BestPos.z))
										end
									end
								end
							end
						end
					end
		        end
			end
		end
	end
end

local function LastHit()
    local enemyMinions = GetMinionsInRange(1000, TEAM_ENEMY)

	if not enemyMinions then
		return
	end

	if menu.key.lasthitkey:get() and menu.lasthit.qlasthit:get() then
		if CountSoldiers() > 0 then
			for _,k in pairs(GetSoldiers()) do
				for i, minion in pairs(enemyMinions) do
					if GetDistance(k, minion) > soldierAA.range and GetDistance(player, k) > azirAA.range and GetDistance(player, minion) < spellQ.range then
						if IsReady(0) and GetDmg(0, minion) > minion.health then
                            player:castSpell("pos", 0, vec3(minion.x, minion.y, minion.z))
						end
					end
				end
			end
		end
	end
end

local function UltProtect()
	for i, enemy in ipairs(enemies) do
		if menu.rsettings.protectenemy:get() and not menu.rsettings.protectcombo:get() then
			if CountObjectsInCircle(player, spellR.range, enemy) >= menu.rsettings.protectnumenemy:get() then
				if GetDistance(player, enemy) < spellR.range then
					player:castSpell("obj", 3, enemy)
				end
			end
		elseif menu.rsettings.protectenemy:get() and menu.rsettings.protectcombo:get() then
			if menu.key.combokey:get() then
				if CountObjectsInCircle(player, spellR.range, enemy) >= menu.rsettings.protectnumenemy:get() then
					if GetDistance(player, enemy) < spellR.range then
						player:castSpell("obj", 3, enemy)
					end
				end
			end
		end
	end
end

local function InsecR(pos, obj)
	if IsValidTarget(obj) and GetDistance(player, obj) < 250 then
		player:castSpell("pos", 3, vec3(t.pos.x, t.pos.y, t.pos.z))
	else
		DelayAction(InsecR, 0.03)
	end	
end

local function Insec()
    local target = GetTarget()

	if not IsValidTarget(target) then
		return
	end

	if menu.key.inseckey:get() then
        if CountSoldiers() == 0 then
            if IsReady(0) and IsReady(1) and IsReady(2) and IsReady(3) then
                local wPos = player.pos:lerp(target.pos, spellW.range / target.pos:dist(player.pos))
                if wPos and GetDistance(player, target) < (spellQ.range + 200) then
                    player:castSpell("pos", 1, vec3(wPos.x, wPos.y, wPos.z))
                end
            end
        else
            local qPos = target.pos:lerp(player.pos, -200 / target.pos:dist(player.pos))
			if qPos then
                if GetDistance(player, qPos) < spellQ.range then
                    player:castSpell("pos", 0, vec3(qPos.x, qPos.y, qPos.z))
                    InsecR(player, target)
					player:castSpell("self", 2)
                end
    		end
        end
    player:move(vec3(t.pos.x, t.pos.y, t.pos.z))
	end
end

local function Flee()
	if menu.key.fleekey:get() then
	    if CountSoldiers() == 0 then
			if IsReady(0) and IsReady(1) and IsReady(2) and player.mana > (spellQ.mana + spellW.mana + spellE.mana) then
			    -- local movePos = player.pos + (vec3(t.pos.x, t.pos.y, t.pos.z) - player.pos) * spellQ.range
			    player:castSpell("pos", 1, vec3(t.pos.x, t.pos.y, t.pos.z))
				player:castSpell("self", 2)
				player:castSpell("pos", 0, vec3(t.pos.x, t.pos.y, t.pos.z))
			end
		elseif CountSoldiers() > 0 then
			if IsReady(0) and IsReady(2) and player.mana > (spellQ.mana + spellE.mana) then
                for _, k in pairs(GetSoldiers()) do
                    if GetDistance(t, k) < spellW.range then
                        player:castSpell("self", 2)
        				player:castSpell("pos", 0, vec3(t.pos.x, t.pos.y, t.pos.z))
                    else
                        player:castSpell("pos", 1, vec3(t.pos.x, t.pos.y, t.pos.z))
        				player:castSpell("self", 2)
        				player:castSpell("pos", 0, vec3(t.pos.x, t.pos.y, t.pos.z))
                    end
                end
			end
		end
    player:move(vec3(t.pos.x, t.pos.y, t.pos.z))
	end
end

-- Drawing Shit --
local function OnDraw()
    if menu.draws.drawq:get() and IsReady(0) then
        graphics.draw_circle(player.pos, spellQ.range, 2, menu.draws.colorq:get(), 100)
	end
	if menu.draws.draww:get() and IsReady(1) then
		graphics.draw_circle(player.pos, spellW.range, 2, menu.draws.colorw:get(), 100)
	end
	if menu.draws.drawe:get() and IsReady(2) then
		graphics.draw_circle(player.pos, spellE.range, 2, menu.draws.colore:get(), 100)
    end
end

local function OnTick()
    Combo()
    Harass()
    Insec()
    LaneClear()
    LastHit()
    UltProtect()
    Flee()
end

orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.draw, OnDraw)
cb.add(cb.create_particle, CreateObj)
