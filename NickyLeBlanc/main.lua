
local ts = module.internal("TS")

local orb = module.internal("orb")
local gpred = module.internal("pred")

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

local function GetTotalAD(obj)
    local obj = obj or player
    return (obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod
end
  
local function GetBonusAD(obj)
    local obj = obj or player
    return ((obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod) - obj.baseAttackDamage
end
  
local function GetTotalAP(obj)
    local obj = obj or player
    return obj.flatMagicDamageMod * obj.percentMagicDamageMod
end

local function PhysicalReduction(target, damageSource)
    local damageSource = damageSource or player
    local armor =
      ((target.bonusArmor * damageSource.percentBonusArmorPenetration) + (target.armor - target.bonusArmor)) *
      damageSource.percentArmorPenetration
    local lethality =
      (damageSource.physicalLethality * .4) + ((damageSource.physicalLethality * .6) * (damageSource.levelRef / 18))
    return armor >= 0 and (100 / (100 + (armor - lethality))) or (2 - (100 / (100 - (armor - lethality))))
end
  
local function MagicReduction(target, damageSource)
    local damageSource = damageSource or player
    local magicResist = (target.spellBlock * damageSource.percentMagicPenetration) - damageSource.flatMagicPenetration
    return magicResist >= 0 and (100 / (100 + magicResist)) or (2 - (100 / (100 - magicResist)))
end
  
local function DamageReduction(damageType, target, damageSource)
    local damageSource = damageSource or player
    local reduction = 1
    if damageType == "AD" then
    end
    if damageType == "AP" then
    end
    return reduction
end
  

local function CalculateAADamage(target, damageSource)
    local damageSource = damageSource or player
    if target then
      return GetTotalAD(damageSource) * PhysicalReduction(target, damageSource)
    end
    return 0
end
  
  
local function CalculatePhysicalDamage(target, damage, damageSource)
    local damageSource = damageSource or player
    if target then
      return (damage * PhysicalReduction(target, damageSource)) *
        DamageReduction("AD", target, damageSource)
    end
    return 0
end
  

local function CalculateMagicDamage(target, damage, damageSource)
    local damageSource = damageSource or player
    if target then
      return (damage * MagicReduction(target, damageSource)) * DamageReduction("AP", target, damageSource)
    end
    return 0
end
  
local function GetAARange(target)
    return player.attackRange + player.boundingRadius + (target and target.boundingRadius or 0)
end

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

-- Returns ignite damage
local function GetIgniteDamage(target)
	local damage = 55 + (25 * player.levelRef)
	if target then
	  damage = damage - (GetShieldedHealth("AD", target) - target.health)
	end
	return damage
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

local function CheckBuff(obj, buffname)
    if obj then
        for i = 0, obj.buffManager.count - 1 do
            local buff = obj.buffManager:get(i)
            if buff and buff.valid and buff.name == buffname and buff.stacks == 1 then
                return true
            end 
        end 
    end     
end

local function CheckBuff2(obj, buffname)
    if obj then
        for i = 0, obj.buffManager.count - 1 do
            local buff = obj.buffManager:get(i)
            if buff and buff.valid and buff.name:find(buffname) and (buff.stacks > 0 or buff.stacks2 > 0) then
                return true
            end 
        end 
    end
end

local function IsValidTarget(object)
    return (object and not object.isDead and object.isVisible and object.isTargetable and not CheckBuffType(object, 17))
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

-- Returns table of enemy hero.obj
local function GetEnemyHeroes()
	return units.enemies
  end

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

local QMissile, RMissile = nil, nil
local Qobj, Robj = false, false
local leblancW, leblancRW = nil, nil
local LW, RW = false, false

local QlvlDmg = {55, 80, 105, 130, 155}
local WlvlDmg = {85, 125, 165, 205, 245}
local ElvlDmg = {40, 60, 80, 100, 120}
local RQlvlDmg = {70, 140, 210}
local RWlvlDmg = {150, 300, 450}
local RElvlDmg = {70, 140, 210}

local wPred = {
	delay = 0.6,
	radius = 260,
	speed = 1450,
	boundingRadiusMod = 0,
	collision = {hero = false, minion = false}
}
local ePred = {
	delay = 0.25,
	width = 54,
	speed = 1750,
	boundingRadiusMod = 1,
	collision = {hero = true, minion = true, wall = true}
}

local IgniteFlott = nil
if player:spellSlot(4).name == "SummonerDot" then
	IgniteFlott = 4
elseif player:spellSlot(5).name == "SummonerDot" then
	IgniteFlott = 5
end


local menu = menu("NickyLB", "[Nicky] LeBlanc")
menu:header("xd", "Cyrex Leblanc")
menu:menu("keys", "Key Settings")
menu.keys:header("xd", "Where The Magic Happens")
menu.keys:keybind("c", "2 Chains Combo", "A", false)
menu:menu("combo", "Combo Settings")
menu.combo:header("xd", "Combo Settings")
menu.combo:header("xd", "Q Settings")
menu.combo:boolean("q", "Use Q", true)

menu.combo:header("xd", "W Settings")
menu.combo:boolean("w", "Use W", true)
menu.combo:boolean("smartW", "Use Smart W", true)
menu.combo:boolean("wBack", "W Back After Target Dead", false)
menu.combo:keybind("comboGap1", "Gap Close if Needed", false, "T")

menu.combo:header("xd", "E Settings")
menu.combo:boolean("e", "Use E", true)

menu.combo:header("xd", "R Settings")
menu.combo:boolean("r", "Use Smart R", true)

menu:menu("harass", "Harass Settings")
menu.harass:header("xd", "Harass Settings")
menu.harass:slider("mode", "Mode: 1 = Q | 2 = Q-W | 3 = Q-W-E |", 2, 1, 3, 1)
menu.harass:boolean("smartW", "No Back W", true)
menu.harass:boolean("QCheck", "Check for Q", true)
menu.harass:slider("Mana", "Min. Mana Percent: ", 10, 0, 100, 10)

menu:menu("auto", "Killsteal Settings")
menu.auto:header("xd", "KillSteal Settings")
menu.auto:boolean("uks", "Use Killsteal", true)
menu.auto:boolean("uksr", "Use R on Killsteal", false)

menu:menu("draws", "Draw Settings")
menu.draws:header("xd", "Drawing Options")
menu.draws:boolean("q", "Draw Q Range", true)
menu.draws:boolean("e", "Draw E Range", true)
menu.draws:boolean("ds", "GapClose State", true)
ts.load_to_menu()

local function select_target(res, obj, dist)
	if dist > 865 then
		return
	end
	res.obj = obj
	return true
end

local function select_gaptarget(res, obj, dist)
	if dist > 1300 then
		return
	end
	res.obj = obj
	return true
end

local function get_target(func)
	return ts.get_result(func).obj
end

local function qDmg(target)
	if player:spellSlot(0).level > 0 then
	    local damage = (QlvlDmg[player:spellSlot(0).level] + (GetTotalAP() * .4)) or 0
	    return CalculateMagicDamage(target, damage)
    end
end

local function wDmg(target)
	if player:spellSlot(1).level > 0 then
	    local damage = WlvlDmg[player:spellSlot(1).level] + (GetTotalAP() * .6) or 0
	    return CalculateMagicDamage(target, damage)
	end
end

local function eDmg(target)
	if player:spellSlot(2).level > 0 then
	    local damage = (ElvlDmg[player:spellSlot(2).level] + (GetTotalAP() * .3)) or 0
	    return CalculateMagicDamage(target, damage)
	end
end

local function rqDmg(target)
    if player:spellSlot(3).level > 0 then
        local damage = (RQlvlDmg[player:spellSlot(3).level] + (GetTotalAP() * .4)) or 0
        return CalculateMagicDamage(target, damage)
    end
end

local function rwDmg(target)
    if player:spellSlot(3).level > 0 then
        damage = RWlvlDmg[player:spellSlot(3).level] + (GetTotalAP() * .75) or 0
        return CalculateMagicDamage(target, damage)
    end
end

local function reDmg(target)
    if player:spellSlot(3).level > 0 then
        damage = (RElvlDmg[player:spellSlot(3).level] + (GetTotalAP() * .4)) or 0
        return CalculateMagicDamage(target, damage)
    end
end

--print(player:spellSlot(1).name)
local function wUsed() 
	if player:spellSlot(1).name == "LeblancWReturn" then 
		return true
	else 
		return false
	end
end

local function oncreateobj(obj)
	if obj.type then
		if obj.name:find("W_return_indicator") then
			leblancW = obj
			LW = true
		end
		if obj.name:find("RW_return_indicator") then
			leblancRW = obj
			RW = true
		end
	--if obj and obj.name and obj.name:lower():find("leblanc") then print("Created "..obj.name) end
	end
end

local function ondeleteobj(obj)
	if obj.type then
		if obj.name:find("W_return_indicator") then
			leblancW = false
			LW = false
		end
		if obj.name:find("RW_return_indicator") then
			leblancRW = false
			RW = false
		end
	--if obj and obj.name and obj.name:lower():find("leblanc") then print("Deleted "..obj.name) end
	end
end


local function CastQ(target)
	if player.path.serverPos:dist(target.path.serverPos) < 710 and player:spellSlot(0).state == 0 then
		player:castSpell("obj", 0, target)
	end
end

local function CastRQ(target)
	if player.path.serverPos:dist(target.path.serverPos) < 710 and player:spellSlot(3).state == 0 and player:spellSlot(3).name == "LeblancRQ" then
		player:castSpell("obj", 3, target)
	end
end

local function CastW(target)
	if not wUsed() or not leblancW then
		if player:spellSlot(1).state == 0 and player.path.serverPos:distSqr(target.path.serverPos) < (750 * 750) then
			local res = gpred.circular.get_prediction(wPred, target)
			if res and res.startPos:dist(res.endPos) < 800 and not navmesh.isWall(vec3(res.endPos.x, game.mousePos.y, res.endPos.y)) then
				player:castSpell("pos", 1, vec3(res.endPos.x, game.mousePos.y, res.endPos.y))
			end
		end
	end
end

local function CastRW(target)
	if player:spellSlot(3).state == 0 and player.path.serverPos:distSqr(target.path.serverPos) < (750 * 750) and player:spellSlot(3).name == "LeblancRW" then
		local res = gpred.circular.get_prediction(wPred, target)
		if res and res.startPos:dist(res.endPos) < 750 and not navmesh.isWall(vec3(res.endPos.x, game.mousePos.y, res.endPos.y)) then
			player:castSpell("pos", 3, vec3(res.endPos.x, game.mousePos.y, res.endPos.y))
		end
	end
end

local function CastE(target)
	if player:spellSlot(2).state == 0 and player.path.serverPos:dist(target.path.serverPos) < 865 then
		local seg = gpred.linear.get_prediction(ePred, target)
		if seg and seg.startPos:dist(seg.endPos) < 865 then
			if not gpred.collision.get_prediction(ePred, seg, target) then
				player:castSpell("pos", 2, vec3(seg.endPos.x, game.mousePos.y, seg.endPos.y))
			end
		end
	end
end

local function CastRE(target)
	if player:spellSlot(3).state == 0 and player.path.serverPos:dist(target.path.serverPos) < 865 and player:spellSlot(3).name == "LeblancRE" then
		local seg = gpred.linear.get_prediction(ePred, target)
		if seg and seg.startPos:dist(seg.endPos) < 865 then
			if not gpred.collision.get_prediction(ePred, seg, target) then
				player:castSpell("pos", 3, vec3(seg.endPos.x, game.mousePos.y, seg.endPos.y))
			end
		end
	end
end

local function CastGPW(target)
	if player:spellSlot(1).name == "LeblancWReturn" then return end
	if not wUsed() then
		if vec3(target.x, target.y, target.z):dist(player) < 1200 and target.pos:dist(player.pos) > 700 and not wUsed() and player:spellSlot(1).state == 0 and not navmesh.isWall(target.pos) then
			if player:spellSlot(1).name == "LeblancW" then
				player:castSpell("pos", 1, target.pos)
			end
		end
	end
end

local function CastGPR(target)
	if player:spellSlot(0).state == 0 and vec3(target.x, target.y, target.z):dist(player) < 1200 and target.pos:dist(player.pos) > 700 and player:spellSlot(3).state == 0 and player:spellSlot(3).name == "LeblancRW" and not navmesh.isWall(target.pos) then
		player:castSpell("pos", 3, target.pos)
	end
end


local function Combo()
	local wPriority = (player:spellSlot(1).level > player:spellSlot(0).level) or false
	if menu.combo.comboGap1:get() and player.levelRef > 5 then
		local target = get_target(select_gaptarget)
		if target and IsValidTarget(target) and not CheckBuff(target, "sionpassivezomie") then
			local d = player.path.serverPos:dist(target.path.serverPos)
			if d <= 1300 and not wPriority then
				if not wUsed() then
					if target.pos:dist(player.pos) < 600 and player:spellSlot(1).state == 0 and not LW then
						CastW(target)
					elseif player:spellSlot(1).name == "LeblancW" and not LW then
						if not wUsed() or not leblancW then
							if player:spellSlot(1).state == 0 and player.path.serverPos:distSqr(target.path.serverPos) < (1200 * 1200) then
								local res = gpred.circular.get_prediction(wPred, target)
								if res and res.startPos:dist(res.endPos) < 1200 and not navmesh.isWall(vec3(res.endPos.x, game.mousePos.y, res.endPos.y)) then
									player:castSpell("pos", 1, vec3(res.endPos.x, game.mousePos.y, res.endPos.y))
								end
							end
						end
					end
				end
				if menu.combo.q:get() and d <= 710 then
					CastQ(target)
				end
				if menu.combo.r:get() and d <= 710 and player:spellSlot(0).state == 32 then
					CastRQ(target)
				end
				if menu.combo.e:get() and d <= 865 and player:spellSlot(3).state == 32 or CheckBuff(target, "LeblancQMark") then
					CastE(target)
				end
			elseif d <= 1200 and wPriority then
				if not wUsed() or not leblancW then
					if player:spellSlot(0).state == 0 and vec3(target.x, target.y, target.z):dist(player) < 1200 and d > 700 and not wUsed() and player:spellSlot(1).state == 0 then
						player:castSpell("pos", 1, target.pos) 
					elseif d < 600 and player:spellSlot(1).state == 0 then
						CastW(target)
					end
				end
				if menu.combo.r:get() and d <= 750 and LW then
					CastRW(target)
				end
				if menu.combo.q:get() and d <= 700 and RW then
					CastQ(target)
				end
				if menu.combo.e:get() and d <= 865 and RW or CheckBuff(target, "LeblancQMark")then
					CastE(target)
				end
			end
		end
	elseif not menu.combo.comboGap1:get() then
		local target = get_target(select_target)
		if target and IsValidTarget(target) and not CheckBuff(target, "sionpassivezomie") then
			local d = player.path.serverPos:dist(target.path.serverPos)
			if d <= 865 and not wPriority then
				if menu.combo.e:get() then
					CastE(target)
				end
				if menu.combo.q:get() and d <= 710 and player:spellSlot(2).state ~= 0 then
					CastQ(target)
				end
				if menu.combo.r:get() and d <= 710 and player:spellSlot(3).name == "LeblancRQ" and CheckBuff(target, "LeblancQMark")then
					CastRQ(target)
				end
				if menu.combo.w:get() and d <= 750 and CheckBuff(target, "LeblancRQMark") or CheckBuff(target, "LeblancQMark")then
					CastW(target)
				end
			elseif d <= 865 and wPriority then
				if menu.combo.w:get() and d <= 750 then
					CastW(target)
				end
				if menu.combo.r:get() and d <= 750 and LW then
					CastRW(target)
				end
				if menu.combo.q:get() and d <= 700 and player.levelRef < 6 then
					CastQ(target)
				elseif menu.combo.q:get() and player:spellSlot(3).state ~= 0 then
					DelayAction(function() CastQ(target) end, 0.4)
				end
				if menu.combo.e:get() and CheckBuff(target, "LeblancQMark")or player:spellSlot(0).state ~= 0 then
					CastE(target)
				end
				if player:spellSlot(1).state ~= 0 or player:spellSlot(2).state ~= 0 then
					CastRQ(target)
				end
			end
			if #GetEnemyHeroesInRange(300, target.pos) > 2 then
				CastW(target)
				if wUsed() then
					CastRW(target)
				end
			end
		end
	end
end


local function Harass()
	if player.par / player.maxPar * 100 >= menu.harass.Mana:get() then
		local target = get_target(select_target)
		if target and IsValidTarget(target) and not CheckBuff(target, "sionpassivezomie") then
			if menu.harass.mode:get() == 1 then
				CastQ(target)
			elseif menu.harass.mode:get() == 2 then
				CastQ(target)
				if player:spellSlot(0).state ~= 0 and player.path.serverPos:dist(target.path.serverPos) <= 700 then
					DelayAction(function() CastW(target) end, 0.2)
				end
			elseif menu.harass.mode:get() == 3 then
				CastE(target)
				if CheckBuff(target, "leblanceroot") then
					CastQ(target)
					if CheckBuff(target, "LeblancQMark")then
						CastW(target)
					end
				end
			end
			if not menu.harass.smartW:get() and wUsed() then
				player:castSpell("pos", 1, player.pos)
			end
		end
	end
end


local function KillSteal()
	for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
		if enemy and menu.auto.uks:get() and IsValidTarget(enemy) and not CheckBuff(enemy,"sionpassivezombie") then
			local d = player.path.serverPos:distSqr(enemy.path.serverPos)
			local q, ql = player:spellSlot(0).state == 0, player:spellSlot(0).level > 0
			local w, wl = player:spellSlot(1).state == 0, player:spellSlot(1).level > 0
			local e, el = player:spellSlot(2).state == 0, player:spellSlot(2).level > 0
			local r, rl = player:spellSlot(3).state == 0, player:spellSlot(3).level > 0
			local hp = enemy.health
			local WQRange = 1300
			local WWQRange = 1900
			if player:spellSlot(0).level > 0 and hp < qDmg(enemy) and d < (WWQRange * WWQRange) and d > (WQRange+5 * WQRange+5) then
	  			CastQ(enemy)
	  		elseif player:spellSlot(0).level > 0 and hp < qDmg(enemy) and d < (710 * 710) then
	  			CastQ(enemy)
	  		elseif ql and w and hp < qDmg(enemy) and d < (WQRange * WQRange) and d > (710 * 710) then
	  			CastGPW(enemy)
	  			CastQ(enemy)
	  		elseif ql and w and rl and hp < qDmg(enemy) and d < (WWQRange * WWQRange) and d > (WQRange+5 * WQRange+5) then
	  				CastGPW(enemy)
		  			if d < 1900 * 1900 then
		  				CastGPR(enemy)
		  				CastQ(enemy)
		  			end
   			elseif wl and hp < wDmg(enemy) and d < (750 * 750) then 
   				CastW(enemy)
   			elseif el and hp < eDmg(enemy) and d < (865 * 865) then
   				CastE(enemy)
   			elseif el and wl and ql and hp < eDmg(enemy) + qDmg(enemy)*1.5 and d > (750 * 750) and d < (WQRange * WQRange) then
   				if not wUsed() then
   					CastGPW(enemy)
   				end
   				CastE(enemy)
   				CastQ(enemy)
   			elseif ql and rl and hp < qDmg(enemy) + rqDmg(enemy) and d < (710 * 710) and CheckBuff(enemy, "LeblancRQMark") then
   				CastQ(enemy)
   			elseif rl and player:spellSlot(3).name == "LeblancRQ" and menu.auto.uksr:get() and hp < rqDmg(enemy) * 2 and d < (710 * 710) then
   				CastRQ(enemy)
   			elseif rl and player:spellSlot(3).name == "LeblancRQ" and menu.auto.uksr:get() and d < (710 * 710) and hp < rqDmg(enemy) + qDmg(enemy) * 2 and CheckBuff(enemy, "LeblancQMark")then
   				CastRQ(enemy)
   			elseif rl and player:spellSlot(3).name == "LeblancRW" and menu.auto.uksr:get() and hp < rwDmg(enemy) and d < (700 * 700) then
   				CastRW(enemy)
   			elseif rl and ql and wl and menu.auto.uksr:get() and hp < (qDmg(enemy)*2+rqDmg(enemy)) and d < (WQRange * WQRange) and d > (700 * 700) then
   				if not wUsed then
   					CastGPW(enemy)
   				end
   				CastQ(enemy)
   				CastRQ(enemy)
   			elseif rl and q and w and menu.auto.uksr:get() and hp < (qDmg(enemy)+wDmg(enemy)+rwDmg(enemy)) and d < (700 * 700) then
   				CastQ(enemy)
   				CastW(enemy)
   				if wUsed then
   					CastRW(enemy)
   				end
			end
		end
	end
end

local function Chainz()
	if menu.keys.c:get() then
		local target = get_target(select_target)
		player:move((game.mousePos))
		if target and target.pos:dist(player.pos) < 865 then
			if player:spellSlot(2).state == 0 then
				CastE(target)
			end
			if CheckBuff(target, "leblanceroot") then
				CastRE(target)
			end
		end
	end
end


local function smartW()
    if wUsed() and leblancW then -- LeblancQMark
    	local target = get_target(select_gaptarget)
        if #GetEnemyHeroesInRange(600, leblancW.pos) < #GetEnemyHeroesInRange(600, player.pos) then
            if target and IsValidTarget(target) and player:spellSlot(0).level > 0 and player:spellSlot(1).level > 0 and player:spellSlot(2).level > 0 and player:spellSlot(3).level > 0 then
                if target.health > (qDmg(target) + wDmg(target) + eDmg(target)+ rqDmg(target) + 500) then
                    player:castSpell("pos", 1, player.pos)
                end
            end
        end
    end
end

local function TisIgnite()
    for i = 0, objManager.enemies_n - 1 do
		local target = objManager.enemies[i]
        if not target.isDead and target.isVisible and target.isTargetable and IsValidTarget(target) then
            if player.path.serverPos:dist(target.path.serverPos) < 625 then
                if (IgniteFlott and player:spellSlot(IgniteFlott).state) then
                    if GetIgniteDamage(target) >= target.health then
                        player:castSpell("obj", IgniteFlott, target)
                    end
                end 
            end 
        end 
    end 
end 


local function OnTick()
	TisIgnite()
	if orb.combat.is_active() then
		Combo()
	end
	if menu.combo.smartW:get() then smartW() end
	if menu.harass.smartW:get() then smartW() end
	--if orb.menu.lane_clear:get() then Clear() end
	if menu.auto.uks:get() then
		KillSteal()
	end
	if orb.menu.hybrid.key:get() then
		Harass()
	end
	if menu.keys.c:get() then Chainz() 
	end	

end

local function OnDraw()
	if menu.draws.q:get() and player:spellSlot(0).state == 0 and player.isOnScreen then
		graphics.draw_circle(player.pos, 700, 2, graphics.argb(255, 7, 141, 237), 50)
	end
	if menu.draws.e:get() and player:spellSlot(2).state == 0 and player.isOnScreen then
		graphics.draw_circle(player.pos, 865, 2, graphics.argb(255, 255, 112, 255), 50)
	end
	if leblancW then
		graphics.draw_circle(leblancW.pos, 260, 2, graphics.argb(255, 248, 131, 121), 50)
	end
	if leblancRW then
		graphics.draw_circle(leblancRW.pos, 260, 2, graphics.argb(255, 248, 70, 121), 50)
	end
	 if menu.draws.ds:get() and player:spellSlot(3).level > 0 then
        local pos = graphics.world_to_screen(vec3(player.x-20, player.y, player.z-50))
        if menu.combo.comboGap1:get() then
           graphics.draw_text_2D("Gapclosing: On", 15, pos.x, pos.y, graphics.argb(255, 51, 255, 51))
        else
           graphics.draw_text_2D("Gapclosing: Off", 15, pos.x, pos.y, graphics.argb(255, 255, 30, 30))
        end
     end
end

orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.draw, OnDraw)
cb.add(cb.create_particle, oncreateobj)
cb.add(cb.delete_particle, ondeleteobj)
--cb.add(cb.updatebuff, OnUpdateBuff)
--cb.add(cb.removebuff, OnRemoveBuff)


