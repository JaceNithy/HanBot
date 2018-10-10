local ts = module.internal('TS')
local orb = module.internal("orb")
local evade = module.seek("evade")
local pred = module.internal("pred")
local ObjMinion_Type = objManager.minions
--Spells
local q = { Range = 1150 }
local w = { Range = 1150 }
local e = { Range = 475, OverKill = 0 }
local r = { Range = 3000}
--
local UnderTurret = false
local TimeTurret = 0
--
local PredQ = { range = 1150; delay = 0.25; width = 60; speed = 2000;  boundingRadiusMod = 1; collision = { hero = true, minion = true };}
local PredW = { range = 1150; delay = 0.25; width = 80; speed = 1600;  boundingRadiusMod = 1; collision = { hero = true, minion = false };}
local PredR = { range = 3000; delay = 1.1; width = 160; speed = 2000;  boundingRadiusMod = 1; collision = { hero = false, minion = false };}
--
local function PredictedPos(object, delay)
    if not IsValidTarget(object) or not object.path or not delay or not object.moveSpeed then
        return object.pos
    end
    local pred_pos = pred.core.lerp(object.path, network.latency + delay, object.moveSpeed)
    return vec3(pred_pos.x, object.y, pred_pos.y)
end
--
local delayedActions, delayedActionsExecuter = {}, nil

local function DelayAction(func, delay, args) 
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
--
local function IsUnderTurretEnemy(pos)
	if TimeTurret < game.time then
		TimeTurret = game.time + 0.1
        objManager.loop(function(obj) if obj and obj.pos:dist(pos) < 900 and obj.team == TEAM_ENEMY and obj.type == TYPE_TURRET then
            UnderTurret = true
            end
        end)
        return UnderTurret
	end
end
--
local function IsUnderAllyTurret(pos)
	if TimeTurret < game.time then
		TimeTurret = game.time + 0.1
        objManager.loop(function(obj) if obj and obj.pos:dist(pos) < 900 and obj.team == TEAM_ALLY and obj.type == TYPE_TURRET then
            UnderTurret = true
            end
        end)
        return UnderTurret
	end
end
--
local function GetDistanceSqr(p1, p2)
    local p2 = p2 or player
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return dx * dx + dz * dz
end
--
local function GetDistance(p1, p2)
    local squaredDistance = GetDistanceSqr(p1, p2)
    return math.sqrt(squaredDistance)
end
--
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
--
local function CheckBuff(obj, buffname)
    if obj then
        for i = 0, obj.buffManager.count - 1 do
            local buff = obj.buffManager:get(i)
            if buff and buff.valid and string.lower(buff.name) == string.lower(buffname) and buff.owner == obj then
                if game.time <= buff.endTime then
                    return true, buff.startTime
                end 
            end 
        end 
    end 
    return false, 0
end 
--
local function IsValidTarget(object)
    return (object and not object.isDead and object.isVisible and object.isTargetable and not CheckBuffType(object, 17))
end
--
local function ValidTargetRange(unit, range)
    return unit and unit.isVisible and not unit.isDead and unit.isTargetable and not CheckBuffType(unit, 17) and (not range or player.pos:dist(unit.pos) <= range)
end
--
local function GetAARange(target)
    return player.attackRange + player.boundingRadius + (target and target.boundingRadius or 0)
end
--
local function GetTotalAD(obj)
    local obj = obj or player
    return (obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod
end  
--
local function PhysicalReduction(target, damageSource)
    local damageSource = damageSource or player
    local armor = ((target.bonusArmor * damageSource.percentBonusArmorPenetration) + (target.armor - target.bonusArmor)) * damageSource.percentArmorPenetration
    local lethality = (damageSource.physicalLethality * .4) + ((damageSource.physicalLethality * .6) * (damageSource.levelRef / 18))
    return armor >= 0 and (100 / (100 + (armor - lethality))) or (2 - (100 / (100 - (armor - lethality))))
end
--
local function CalculateAADamage(target, damageSource)
    local damageSource = damageSource or player
    if target then
      return GetTotalAD(damageSource) * PhysicalReduction(target, damageSource)
    end
    return 0
end
--
local function CountEnemiesInRange(pos, range)
    local n = 0
    for i = 0, objManager.enemies_n - 1 do
		local object = objManager.enemies[i]
        if IsValidTarget(object) then
        	local objectPos = vec3(object.x, object.y, object.z)
          	if GetDistanceSqr(pos, objectPos) <= math.pow(range, 2) then
            	n = n + 1
          	end
        end
    end
    return n
end
--
local function CountEnemyChampAroundObject(pos, range) 
	local enemies_in_range = {}
	for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
		if pos:dist(enemy.pos) < range and IsValidTarget(enemy) then
			enemies_in_range[#enemies_in_range + 1] = enemy
		end
	end
	return enemies_in_range
end
--
local function MagicReduction(target, damageSource)
    local damageSource = damageSource or player
    local magicResist = (target.spellBlock * damageSource.percentMagicPenetration) - damageSource.flatMagicPenetration
    return magicResist >= 0 and (100 / (100 + magicResist)) or (2 - (100 / (100 - magicResist)))
end
--
local function DamageReduction(damageType, target, damageSource)
    local damageSource = damageSource or player
    local reduction = 1
    if damageType == "AD" then
    end
    if damageType == "AP" then
    end
    return reduction
end
--
local function CalculateMagicDamage(target, damage, damageSource)
    local damageSource = damageSource or player
    if target then
      return (damage * MagicReduction(target, damageSource)) * DamageReduction("AP", target, damageSource)
    end
    return 0
end
--
local function GetMousePos()
    return vec3(mousePos.x, mousePos.y, mousePos.z)
end
--
local function PredSlow(input, segment, target)
	if pred.trace.linear.hardlock(input, segment, target) then
		return true
	end
	if pred.trace.linear.hardlockmove(input, segment, target) then
		return true
	end
	if segment.startPos:dist(segment.endPos) <= 625 then
		return true
	end
	if pred.trace.newpath(target, 0.033, 0.5) then
		return true
	end
end
--
local function CanHarras()
	local myHeroPos = vec3(player.x, player.y, player.z)
	if not IsUnderTurretEnemy(myHeroPos) then
		return true
	end
	return false
end
--
local function ValidUlt(unit)
	if (CheckBuffType(unit, 16) or CheckBuffType(unit, 15) or CheckBuffType(unit, 17) or CheckBuff(unit, "kindredrnodeathbuff") or CheckBuffType(unit, 4)) then
		return false
	end
	return true
end
--
local function DamageQ(target)
    local Damage = 0 
    local qdmg = {15, 40, 65, 90, 115}
    if player:spellSlot(0).state == 0 then
        Damage = (qdmg[player:spellSlot(0).level] + 0.4 * (player.flatMagicDamageMod * player.percentMagicDamageMod) + 1.1 * ((player.baseAttackDamage + player.flatPhysicalDamageMod)*(1 + player.percentPhysicalDamageMod)))
    end
    return CalculateMagicDamage(target, Damage)
end
--
local function DamageE(target)
    local Damage = 0 
    local edmg = {80, 130, 180, 230, 280}
    if player:spellSlot(2).state == 0 then
        Damage = (edmg[player:spellSlot(2).level] + 0.75 * (player.flatMagicDamageMod * player.percentMagicDamageMod) + 0.5 * ((player.baseAttackDamage + player.flatPhysicalDamageMod)*(1 + player.percentPhysicalDamageMod) - player.baseAttackDamage))
    end
    return CalculateMagicDamage(target, Damage)
end
--
local function DamageR(target)
    local Damage = 0 
    local rdmg = {350, 500, 650}
    if player:spellSlot(3).state == 0 then
        Damage = (rdmg[player:spellSlot(3).level] + 0.9 * (player.flatMagicDamageMod * player.percentMagicDamageMod) + 1 * ((player.baseAttackDamage + player.flatPhysicalDamageMod)*(1 + player.percentPhysicalDamageMod) - player.baseAttackDamage))
    end
    return CalculateMagicDamage(target, Damage)
end
--
local MenuEzreal = menu("NickyEz", "[Nicky]Ezreal")
MenuEzreal:menu("Qc", "[Q] Settings")
MenuEzreal.Qc:boolean("autoQ", "Combo [Q]", true)
MenuEzreal.Qc:boolean("QHarass", "Harass [Q]", true)
MenuEzreal.Qc:boolean("farmqout", "Farm out range [AA]", true)
MenuEzreal.Qc:boolean("LCQ", "LaneClear [Q]", true)
MenuEzreal.Qc:slider('Qmana', "Mana [Q] farm", 60, 0, 100, 5)
MenuEzreal.Qc:slider("ManaHarass", "Only Mana AutoHarass [Q] % <", 75, 1, 100, 1)

MenuEzreal:menu("Wc", "[W] Settings")
MenuEzreal.Wc:boolean("autoW", "Combo [W]", true)
MenuEzreal.Wc:boolean("WHarass", "Harass [W]", true)
MenuEzreal.Wc:boolean("menu_Combo_farmQout", "Auto [W] End Dash", true)
MenuEzreal.Wc:boolean("WKS", "Auto [W] Kill Steal", true)

MenuEzreal:menu("Ec", "[E] Settings")
MenuEzreal.Ec:boolean("autoE", "Auto [E] on you CC", true)
MenuEzreal.Ec:dropdown("E_Mode", "Is [E] Mode Dash", 3, {"Mouse", "Side", "Safe position"})
MenuEzreal.Ec:boolean("EComb", "Auto [E] in Combo BETA", true)
MenuEzreal.Ec:boolean("EEnds", "Auto [E] End Dash", true)
MenuEzreal.Ec:boolean("AutoInter", "Auto [E] Teleport", true)

MenuEzreal:menu("Rc", "[R] Settings")
MenuEzreal.Rc:boolean("autoR", "Auto [R]", true)
MenuEzreal.Rc:boolean("LRC", "Logic [R]", true)
MenuEzreal.Rc:dropdown("UR", "[R] Utility: ", 2, {"Manual [R]", "Automatic"})
MenuEzreal.Rc:keybind("RUT", "Manual R", "T", nil)

MenuEzreal:menu("Misc", "[Misc] Settings")
MenuEzreal.Misc:boolean("SQ", "Stack [Item]", true)

MenuEzreal:menu("Dt", "Drawings Settings")
MenuEzreal.Dt:boolean("DQ", "Draw [Q]", true)
MenuEzreal.Dt:boolean("DE", "Draw [E]", false)

MenuEzreal:menu("Keys", "Keys [Ez]")
MenuEzreal.Keys:keybind("ComK", "[Key] Combo", "Space", nil)
MenuEzreal.Keys:keybind("ComV", "[Key] Lane", "V", nil)
MenuEzreal.Keys:keybind("smew", "Smart EW", "Z", nil)
MenuEzreal:menu("Pred", "[Prediction] Settings")
MenuEzreal.Pred:dropdown("PredMod", "Predictions", 2, {"Slow Predictions", "HanBot Predictions"})
--
local function TargetSelecton(Range)
    Range = Range or math.huge 
    if orb.combat.target and not orb.combat.target.isDead and orb.combat.target.isTargetable and orb.combat.target.isVisible then
        return orb.combat.target
    else 
        local dist, closest = math.huge, nil
        for i = 0, objManager.enemies_n - 1 do
            local unit = objManager.enemies[i]
            local unit_distance = player.pos:dist(unit.pos);
            
			if not unit.isDead and unit.isVisible and unit.isTargetable and unit_distance <= Range then
                if unit_distance < dist then
                    closest = unit
                    dist = unit_distance;
                end
            end
            if closest then
                return closest
            end
        end
        return nil
    end 
end 
--
local function OnDraw()
    local target = TargetSelecton(1500)
    if target and IsValidTarget(target) then
        if player.isVisible and player.isOnScreen and not player.isDead then
            graphics.draw_circle(target.pos, 80, 2, graphics.argb(255, 255, 204, 255), 100)
        end 
    end 
    if IsValidTarget(player) and (player.isOnScreen) then
        if player:spellSlot(0).state == 0 and MenuEzreal.Dt.DQ:get() then
            graphics.draw_circle(player.pos, q.Range, 2, graphics.argb(255, 0, 255, 233), 100)
        end 
        if player:spellSlot(2).state == 0 and MenuEzreal.Dt.DE:get() then
            graphics.draw_circle(player.pos, e.Range, 2, graphics.argb(255, 255, 255, 255), 100)
        end 
    end 
end 
--
local function InAARange(point, target)
    if (orb.combat.is_active()) then
    local targetpos = vec3(target.x, target.y, target.z)
    return GetDistance(point, targetpos) < GetAARange()
else 
    return CountEnemiesInRange(point, GetAARange()) > 0
  end
end
--
local function CirclePoints(CircleLineSegmentN, radius, position)
    local points = {}
    for i = 1, CircleLineSegmentN, 1 do
        local angle = i * 2 * math.pi / CircleLineSegmentN
        local point = vec3(position.x + radius * math.cos(angle), position.y + radius * math.sin(angle), position.z);
        table.insert(points, point)
    end 
    return points 
end
--
local function IsGoodPosition(dashPos)
	local segment = 475 / 5;
	local myHeroPos = vec3(player.x, player.y, player.z)
	for i = 1, 5, 1 do
		pos = myHeroPos:ext(dashPos, i * segment)
		if navmesh.isWall(pos) then
			return false
		end
	end

	if IsUnderTurretEnemy(dashPos) then
		return false
	end

	local enemyCheck = 2 
    local enemyCountDashPos = CountEnemiesInRange(dashPos, 600);
    if enemyCheck > enemyCountDashPos then
    	return true
    end
    local enemyCountPlayer = #CountEnemyChampAroundObject(player.pos, 400)
    if enemyCountDashPos <= enemyCountPlayer then
    	return true
    end

    return false
end
--
local function CastDash(asap, target)
    asap = asap and asap or false
    local DashMode =  MenuEzreal.Ec.E_Mode:get()
    local bestpoint = vec3(0, 0, 0)
    local myHeroPos = vec3(player.x, player.y, player.z)

    if DashMode == 1 then
    	bestpoint = game.mousePos
    end

    if DashMode == 2 then
    	--if (orb.combat.is_active()) then
		    local startpos = vec3(player.x, player.y, player.z)
		    local endpos = vec3(target.x, target.y, target.z)
		    local dir = (endpos - startpos):norm()
		    local pDir = dir:perp1()
		    local rightEndPos = endpos + pDir * GetDistance(target)
		    local leftEndPos = endpos - pDir * GetDistance(target)
		    local rEndPos = vec3(rightEndPos.x, rightEndPos.y, player.z)
		    local lEndPos = vec3(leftEndPos.x, leftEndPos.y, player.z);
		    if GetDistance(game.mousePos, rEndPos) < GetDistance(game.mousePos, lEndPos) then
		        bestpoint = myHeroPos:ext(rEndPos, 475);
		    else
		        bestpoint = myHeroPos:ext(lEndPos, 475);
		    end
   		--end
  	end

    if DashMode == 3 then
	    points = CirclePoints(15, 475, myHeroPos)
	    bestpoint = myHeroPos:ext(game.mousePos, 475);
	    local enemies = CountEnemiesInRange(bestpoint, 350)

	    for i, point in pairs(points) do
		    local count = CountEnemiesInRange(point, 350)
		    if not InAARange(point, target) then
			  	if IsUnderAllyTurret(point) then
			        bestpoint = point;
			        enemies = count - 1;
			    elseif count < enemies then
			        enemies = count;
			        bestpoint = point;
			    elseif count == enemies and GetDistance(game.mousePos, point) < GetDistance(game.mousePos, bestpoint) then
			        enemies = count;
			        bestpoint = point;
			  	end
		    end
		end
  	end

  	if bestpoint == vec3(0, 0, 0) then
    	return vec3(0, 0, 0)
  	end

  	local isGoodPos = IsGoodPosition(bestpoint)

  	if asap and isGoodPos then
    	return bestpoint
  	elseif isGoodPos and InAARange(bestpoint, target) then
    	return bestpoint
  	end
  	return vec3(0, 0, 0)
end
--
local function OnUpdateBuff()
    local target = TargetSelecton(1500)
    if CheckBuff(player, "rocketgrab2") and player:spellSlot(2).state == 0 then
        if target and IsValidTarget(target) then
            local dashPos = CastDash(true, target.pos)
			if dashPos ~= vec3(0, 0, 0) then
                DelayAction(function() player:castSpell("pos", 2, dashPos) end, 0.1)
            end
		end
	end
end
--
local function LogicQ()
    local targetQ = TargetSelecton(q.Range)
    local Modq = MenuEzreal.Pred.PredMod:get()
    if targetQ and IsValidTarget(targetQ) then
        if player.mana > 140 and player.pos:dist(targetQ) < 1150 then
            local PredictionPosQ = pred.linear.get_prediction(PredQ, targetQ)
            if not PredictionPosQ then return end
            if Modq == 1 then
                if not pred.collision.get_prediction(PredQ, PredictionPosQ, targetQ) and PredSlow(PredQ, PredictionPosQ, targetQ)  then
                    player:castSpell("pos", 0,  vec3(PredictionPosQ.endPos.x, game.mousePos.y, PredictionPosQ.endPos.y))
                end
            else 
                if Modq == 2 then
                    if not pred.collision.get_prediction(PredQ, PredictionPosQ, targetQ) then
                        player:castSpell("pos", 0,  vec3(PredictionPosQ.endPos.x, game.mousePos.y, PredictionPosQ.endPos.y))
                    end
                end 
            end
        end
        if (orb.menu.lane_clear:get()) then
            if player.mana > 300 and CanHarras() then
                local PredictionPosQ = pred.linear.get_prediction(PredQ, targetQ)
                if not PredictionPosQ then return end
                if Modq == 1 then
                    if not pred.collision.get_prediction(PredQ, PredictionPosQ, targetQ) and PredSlow(PredQ, PredictionPosQ, targetQ)  then
                        player:castSpell("pos", 0,  vec3(PredictionPosQ.endPos.x, game.mousePos.y, PredictionPosQ.endPos.y))
                    end
                else 
                    if Modq == 2 then
                        if not pred.collision.get_prediction(PredQ, PredictionPosQ, targetQ) then
                            player:castSpell("pos", 0,  vec3(PredictionPosQ.endPos.x, game.mousePos.y, PredictionPosQ.endPos.y))
                        end
                    end 
                end
            end
        end
    end
end
--
local function LogicW()
    local targetW = TargetSelecton(w.Range)
    local Modw = MenuEzreal.Pred.PredMod:get()
    if targetW and IsValidTarget(targetW) and player.pos:dist(targetW) < 1000 then
        if player.mana > 240 then
            local PredictionPosW = pred.linear.get_prediction(PredW, targetW)
            if not PredictionPosW then return end
            if Modw == 1 then
                if not pred.collision.get_prediction(PredW, PredictionPosW, targetW) and PredSlow(PredW, PredictionPosW, targetW)  then
                    player:castSpell("pos", 1,  vec3(PredictionPosW.endPos.x, game.mousePos.y, PredictionPosW.endPos.y))
                end
            else 
                if Modw == 2 then
                    if not pred.collision.get_prediction(PredW, PredictionPosW, targetW) then
                        player:castSpell("pos", 1,  vec3(PredictionPosW.endPos.x, game.mousePos.y, PredictionPosW.endPos.y))
                    end
                end 
            end
        end
       --[[ if (orb.menu.lane_clear:get()) then
            if player.mana > player.maxMana * 0.8 and CanHarras() then
                if not pred.collision.get_prediction(PredW, PredictionPosW, targetW) then
                    player:castSpell("pos", 1,  vec3(PredictionPosW.endPos.x, game.mousePos.y, PredictionPosW.endPos.y))
                end
            end
        end]]
    end
end
--
local function KillSteal()
    for i = 0, objManager.enemies_n - 1 do
        local target = objManager.enemies[i]
        if not target.isDead and target.isVisible and target.isTargetable then
            if DamageQ(target) > target.health and player.pos:dist(target) < 1000 then
                local PredictionPosQ = pred.linear.get_prediction(PredQ, target)
                if not PredictionPosQ then return end
                if not pred.collision.get_prediction(PredQ, PredictionPosQ, target) then
                    player:castSpell("pos", 0,  vec3(PredictionPosQ.endPos.x, game.mousePos.y, PredictionPosQ.endPos.y))
                    e.OverKill = game.time
                end
            end
        end 
        if IsValidTarget(target) and CountEnemiesInRange(player.pos, 800) == 0 and game.time - e.OverKill > 0.6 then
            if DamageR(target) > target.health and GetDistance(target) > player.attackRange and GetDistance(target) < 3000 then
                local PredictionPosR = pred.linear.get_prediction(PredR, target)
                if not PredictionPosR then return end
                if ValidUlt(target) and #CountEnemyChampAroundObject(player.pos, 500) == 0 then
                    player:castSpell("pos", 3,  vec3(PredictionPosR.endPos.x, target.pos.y, PredictionPosR.endPos.y))
                end
            end 
        end
    end 
end
--
local function LogicR()
    local targetR = TargetSelecton(r.Range)
    local Modr = MenuEzreal.Pred.PredMod:get()
    if IsValidTarget(targetR) and CountEnemiesInRange(player.pos, 800) == 0 and game.time - e.OverKill > 0.6 then
        if DamageR(targetR) > targetR.health and GetDistance(targetR) > player.attackRange and GetDistance(targetR) < 3000 then
            local PredictionPosR = pred.linear.get_prediction(PredR, targetR)
            if not PredictionPosR then return end
            if Modw == 1 then
                if not pred.collision.get_prediction(PredR, PredictionPosR, targetR) and PredSlow(PredR, PredictionPosR, targetR)  then
                    if ValidUlt(targetR) and #CountEnemyChampAroundObject(player.pos, 500) == 0 then
                        player:castSpell("pos", 3,  vec3(PredictionPosR.endPos.x, targetR.pos.y, PredictionPosR.endPos.y))
                    end
                end
            else 
                if Modw == 2 then
                    if not pred.collision.get_prediction(PredR, PredictionPosR, targetR) then
                        if ValidUlt(targetR) and #CountEnemyChampAroundObject(player.pos, 500) == 0 then
                            player:castSpell("pos", 3,  vec3(PredictionPosR.endPos.x, targetR.pos.y, PredictionPosR.endPos.y))
                        end
                    end
                end 
            end
        end 
    end
end
--
local function LogicE()
    local targetE = TargetSelecton(1300)
    if IsValidTarget(targetE) and ValidTargetRange(targetE, 475 + GetAARange(player)) and player.mana > 150 and GetDistance(vec3(targetE.x, targetE.y, targetE.z), GetMousePos()) + 300 < GetDistance(targetE) and GetDistance(vec3(targetE.x, targetE.y, targetE.z)) > player.attackRange and (game.time - e.OverKill) > 0.3  then
        local dashPosition = vec3(player.x, player.y, player.z):ext(GetMousePos(), 475)
        if CountEnemiesInRange(dashPosition, 900) < 3 then
            local dmgCombo = 0
            if ValidTargetRange(targetE, 950) then
                dmgCombo = CalculateAADamage(targetE) + DamageE(targetE)
            end
            if player:spellSlot(0).state == 0 and player.mana > 120 then
                dmgCombo = DamageQ(targetE)
            end
            if dmgCombo > targetE.health and ValidUlt(targetE) then
                player:castSpell("pos", 2, dashPosition)
                e.OverKill = game.time
            end
        end
    end
    if ValidTargetRange(targetE, 1000) and IsValidTarget(targetE)  then 
        if GetDistance(vec3(targetE.x, targetE.y, targetE.z)) < 250 then
            local dashPos = CastDash(true, targetE)
            if dashPos ~= vec3(0, 0, 0) then
                player:castSpell("pos", 2, dashPos)
            end
        end
    end
end
---
local function EGapcloser()
	if player:spellSlot(2).state == 0 then
		for i = 0, objManager.enemies_n - 1 do
			local IsDashingPlayer = objManager.enemies[i]
			if IsDashingPlayer.type == TYPE_HERO and IsDashingPlayer.team == TEAM_ENEMY then
                if IsDashingPlayer and IsValidTarget(IsDashingPlayer) and IsDashingPlayer.path.isActive and IsDashingPlayer.path.isDashing and player.pos:dist(IsDashingPlayer.path.point[1]) < 500 then
                    points = CirclePoints(10, 475, vec3(player.x, player.y, player.z))
                    bestpoint = vec3(player.x, player.y, player.z):ext(IsDashingPlayer, -475);
                    local enemies = CountEnemiesInRange(bestpoint, 475)
                    for i, point in pairs(points) do
                        local count = CountEnemiesInRange(point, 475)
                        if count < enemies then
                            enemies = count;
                            bestpoint = point;
                        elseif count == enemies and GetDistance(GetMousePos(), point) < GetDistance(GetMousePos(), bestpoint) then
                            enemies = count;
                            bestpoint = point;
                        end
                    end
                    if IsGoodPosition(bestpoint) and (orb.combat.is_active()) then   
                        DelayAction(function()  player:castSpell("pos", 2, bestpoint) end, 0)          				
                    end
                end
            end 
        end 
    end 
end 
--
local function Clear()
    if player.mana > 30 then
        for i = 0, ObjMinion_Type.size[TEAM_ENEMY] - 1 do
            local minion = ObjMinion_Type[TEAM_ENEMY][i]
            if minion and IsValidTarget(minion) then
                if ValidTargetRange(minion, q.Range) and GetDistance(vec3(minion.x, minion.y, minion.z)) > GetAARange(player) then
                    local delay = GetDistance(minion) / 2000 + 0.25
                    if (DamageQ(minion) >= orb.farm.predict_hp(minion, delay, true)) then
                        local PredictionPosQ = pred.linear.get_prediction(PredQ, minion)
                        if not PredictionPosQ then return end
                        if not pred.collision.get_prediction(PredQ, PredictionPosQ, minion) then
                            player:castSpell("pos", 0,  vec3(PredictionPosQ.endPos.x, minion.pos.y, PredictionPosQ.endPos.y))
                        end
                    end
                end
            end 
        end 
    end
    local target = TargetSelecton(q.Range)
    if target and IsValidTarget(target) then
        if MenuEzreal.Qc.QHarass:get() and (player.mana / player.maxMana) * 100 >= MenuEzreal.Qc.ManaHarass:get() then
            if player:spellSlot(0).state == 0 and target.pos:dist(player.pos) < q.Range and #CountEnemyChampAroundObject(player.pos, 700) == 0 and target.pos:dist(player.pos) > GetAARange(player) then 
                local PosQ3D = pred.linear.get_prediction(PredQ, target)
                if PosQ3D then
                    local QEndPos = vec3(PosQ3D.endPos.x, target.pos.y, PosQ3D.endPos.y)
                    player:castSpell("pos", 0, vec3(QEndPos))
                end 
            end 
        end 
    end 
end
--
local function OnTick()
    if MenuEzreal.Ec.autoE:get() then
        OnUpdateBuff()
    end
    --
    EGapcloser()
    --
    if MenuEzreal.Keys.smew:get() and player:spellSlot(1).state == 0 then
        player:castSpell("pos", 1, GetMousePos())
        castE = vec3(player.x, player.y, player.z):lerp(GetMousePos(), 475)
        player:castSpell("pos", 2, GetMousePos())
    end
    --
    if MenuEzreal.Rc.RUT:get() and player:spellSlot(3).state == 0 then
        local targetR = TargetSelecton(r.Range)
        if IsValidTarget(targetR) and CountEnemiesInRange(player.pos, 800) == 0 then
            if GetDistance(targetR) > player.attackRange and GetDistance(targetR) < 3000 then
                local PredictionPosR = pred.linear.get_prediction(PredR, targetR)
                if not PredictionPosR then return end
                if not pred.collision.get_prediction(PredR, PredictionPosR, targetR) and PredSlow(PredR, PredictionPosR, targetR)  then
                    if ValidUlt(targetR) and #CountEnemyChampAroundObject(player.pos, 500) == 0 then
                        player:castSpell("pos", 3,  vec3(PredictionPosR.endPos.x, targetR.pos.y, PredictionPosR.endPos.y))
                    end
                end                  
            end 
        end
    end
    --
    KillSteal()
    --
    if (orb.combat.is_active()) then
        if player:spellSlot(0).state == 0 and MenuEzreal.Qc.autoQ:get() then
            LogicQ();
        end
        if player:spellSlot(1).state == 0 and MenuEzreal.Wc.autoW:get() then
            LogicW();
        end
        if player:spellSlot(2).state == 0 and MenuEzreal.Ec.autoE:get() then
            LogicE();
        end
        if player:spellSlot(3).state == 0 and MenuEzreal.Rc.autoR:get() then
            LogicR();
        end
    end
    if (orb.menu.lane_clear:get()) then
		Clear()
    end
    --
    if MenuEzreal.Misc.SQ:get() then
        if not CheckBuff(player, "recall") and player.mana > 250 then
            for i = 6, 11 do
                local item = player:itemID(i)
                if ((item and item == 3070) or (item == 3004) or (item == 3003)) then
                    if #CountEnemyChampAroundObject(player.pos, 1000) == 0 then
                        posQW = vec3(player.x, player.y, player.z):ext(GetMousePos(), 500)
                        if player:spellSlot(0).state == 0 then
                            player:castSpell("pos", 0, posQW)
                        end
                        if player:spellSlot(1).state == 0 then
                            player:castSpell("pos", 1, posQW)
                        end
                    end
                end 
            end 
        end 
    end
end 
--
orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.draw, OnDraw)