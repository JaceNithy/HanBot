local crypt = module.internal('crypt')
crypt.enc_f(hanbot.luapath .. "/NickyMissFortune,/MissFortune.lua", hanbot.luapath .. "/NickyMissFortune/MissFortune_enc.lua")
--
local pred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local evade = module.seek("evade")
--
local ObjMinion_Type = objManager.minions

local q = { Range = 625}
local q2 = {Range = 1300}
local w = { Range = 350 }
local e = { Range = 1000}
local r = { Range = 1300, RTime = 0, stateR = false}
local PredE = { delay = 0.9; radius = 150; speed = 1100; boundingRadiusMod = 1;}
local Q2Shot = { range = 420, delay = 0.25, speed = 1400, width = 60, boundingRadiusMod = 1, collision = {hero = true, minion = true}}

local SpellAttack =
{
    ["caitlynheadshotmissile"] = {},
    ["garenslash2"] = {},
    ["masteryidoublestrike"] = {},
    ["renektonexecute"] = {},
    ["rengarnewpassivebuffdash"] = {},
    ["xenzhaothrust"] = {},
    ["xenzhaothrust3"] = {},
    ["lucianpassiveshot"] = {},
    ["frostarrow"] = {},
    ["kennenmegaproc"] = {},
    ["quinnwenhanced"] = {},
    ["renektonsuperexecute"] = {},
    ["trundleq"] = {},
    ["xenzhaothrust2"] = {},
    ["viktorqbuff"] = {},
    ["lucianpassiveattack"] = {},
}

local NotAttackSpell =
{
    ["volleyattack"] = {},
    ["jarvanivcataclysmattack"] = {},
    ["shyvanadoubleattack"] = {},
    ["zyragraspingplantattack"] = {},
    ["zyragraspingplantattackfire"] = {},
    ["asheqattacknoonhit"] = {},
    ["heimertyellowbasicattack"] = {},
    ["heimertbluebasicattack"] = {},
    ["annietibbersbasicattack"] = {},
    ["yorickdecayedghoulbasicattack"] = {},
    ["yorickspectralghoulbasicattack"] = {},
    ["malzaharvoidlingbasicattack2"] = {},
    ["kindredwolfbasicattack"] = {},
    ["volleyattackwithsound"] = {},
    ["monkeykingdoubleattack"] = {},
    ["shyvanadoubleattackdragon"] = {},
    ["zyragraspingplantattack2"] = {},
    ["zyragraspingplantattack2fire"] = {},
    ["elisespiderlingbasicattack"] = {},
    ["heimertyellowbasicattack2"] = {},
    ["gravesautoattackrecoil"] = {},
    ["annietibbersbasicattack2"] = {},
    ["yorickravenousghoulbasicattack"] = {},
    ["malzaharvoidlingbasicattack"] = {},
    ["malzaharvoidlingbasicattack3"] = {},
}

local function IsAutoAttack(spell)
    return (string.find(string.lower(spell), "attack") ~= nil and not NotAttackSpell[string.lower(spell)]) or SpellAttack[string.lower(spell)]
end

local function GetAARange(target)
    return player.attackRange + player.boundingRadius + (target and target.boundingRadius or 0)
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
local function IsReady(spell)
    return player:spellSlot(spell).state == 0
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
local function IsUnderTurretEnemy(pos)
    if not pos then 
        return false 
    end
    for i = 0, objManager.turrets.size[TEAM_ENEMY] - 1 do
        local tower = objManager.turrets[TEAM_ENEMY][i]
        if  tower and not tower.isDead and tower.health > 0 and tower.isVisible and tower.isTargetable then
            local turretPos = vec3(tower.x, tower.y, tower.z)
			if turretPos:dist(pos) < 900 then
				return true
            end
        else 
            tower = nil
		end
	end
    return false
end
--
local function IsUnderAllyTurret(pos)
    if not pos then 
        return false 
    end
    for i = 0, objManager.turrets.size[TEAM_ALLY] - 1 do
        local tower = objManager.turrets[TEAM_ALLY][i]
        if  tower and not tower.isDead and tower.health > 0 and tower.isVisible and tower.isTargetable then
            local turretPos = vec3(tower.x, tower.y, tower.z)
			if turretPos:dist(pos) < 900  then
				return true
            end
        else 
            tower = nil
		end
	end
    return false
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
local function GetBonusAD(obj)
    local obj = obj or player
    return ((obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod) - obj.baseAttackDamage
end
--
local function GetTotalAP(obj)
    local obj = obj or player
    return obj.flatMagicDamageMod * obj.percentMagicDamageMod
end
--
local function GetPercentMana(obj)
    local obj = obj or player
    return (obj.mana / obj.maxMana) * 100
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
local function CountAllyChampAroundObject(pos, range) 
	local aleds_in_range = {}
	for i = 0, objManager.allies_n - 1 do
		local aled = objManager.allies[i]
		if pos:dist(aled.pos) < range and IsValidTarget(aled) then
			aleds_in_range[#aleds_in_range + 1] = aled
		end
	end
	return aleds_in_range
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
local function PredictedPos(object, delay)
    if not IsValidTarget(object) or not object.path or not delay or not object.moveSpeed then
        return object.pos
    end
    local pred_pos = pred.core.lerp(object.path, network.latency + delay, object.moveSpeed)
    return vec3(pred_pos.x, object.y, pred_pos.y)
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
local function CalculatePhysicalDamage(target, damage, damageSource)
    local damageSource = damageSource or player
    if target then
        return (damage * PhysicalReduction(target, damageSource)) * DamageReduction("AD", target, damageSource)
    end
    return 0
end
--
--
local function TargetSelecton(Range)
    Range = Range or 900 
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
local function DamageQ(target)
    local Damage = 0 
    local qdmg = {20, 40, 60, 80, 100}
    if player:spellSlot(0).state == 0 then
        Damage = (qdmg[player:spellSlot(0).level] + (GetTotalAD(player)*1.0)+(GetTotalAP(player)*0.3))
    end
    return CalculatePhysicalDamage(target, Damage)
end
--
local function DamageR(target)
    local Damage = 0 
    local rmg = {20, 40, 60, 80, 100}
    if player:spellSlot(3).state == 0 then
        Damage = (rmg[player:spellSlot(3).level] + (GetTotalAD(player)*0.9) + (GetTotalAP(player)*0.35))
    end
    return CalculatePhysicalDamage(target, Damage)
end
--
local MenuMiss = menu("NickyMiss", "[Nicky]MissFortune")
MenuMiss:menu("Qc", "[Q] Settings")
MenuMiss.Qc:boolean("autoQ", "Combo [Q]", true)
MenuMiss.Qc:boolean("autoQ2", "Combo [Q2]", true)
MenuMiss.Qc:boolean("QHarass", "Harass [Q]", true)
MenuMiss.Qc:boolean("LCQ", "LaneClear [Q]", true)
MenuMiss.Qc:slider('Qmana', "Mana [Q] farm", 60, 0, 100, 5)

MenuMiss:menu("Wc", "[W] Settings")
MenuMiss.Wc:boolean("autoW", "Combo [W]", true)
MenuMiss.Wc:boolean("WHarass", "Harass [W]", true)
MenuMiss.Wc:boolean("menu_Combo_farmQout", "Auto [W] End Dash", true)
MenuMiss.Wc:boolean("WKS", "Auto [W] Kill Steal", true)

MenuMiss:menu("Ec", "[E] Settings")
MenuMiss.Ec:boolean("autoE", "Auto [E] on CC", true)
MenuMiss.Ec:boolean("EComb", "Auto [E] in Combo", true)
MenuMiss.Ec:boolean("EEnds", "Auto [E] End Dash", true)

MenuMiss:menu("Rc", "[R] Settings")
MenuMiss.Rc:boolean("autoR", "Auto [R]", false)
MenuMiss.Rc:boolean("LRC", "Logic [R]", false)

MenuMiss:menu("Dt", "Drawings Settings")
MenuMiss.Dt:boolean("DQ", "Draw [Q]", true)
MenuMiss.Dt:boolean("DQ2", "Draw [Q2 (Shot)]", true)
MenuMiss.Dt:boolean("DE", "Draw [E]", true)
MenuMiss.Dt:boolean("DDM", "Draw [Damage]", true)

MenuMiss:menu("Keys", "Keys [Ez]")
MenuMiss.Keys:keybind("ComK", "[Key] Combo", "Space", nil)
MenuMiss.Keys:keybind("ComV", "[Key] Lane", "V", nil)
--
local function GetDistanceSqr(p1, p2)
    local p2 = p2 or player
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return dx * dx + dz * dz
end

local function GetDistance(p1, p2)
    local squaredDistance = GetDistanceSqr(p1, p2)
    return math.sqrt(squaredDistance)
end

--
local function ProSpell(spell)
    if spell and spell.owner and spell.owner.ptr == player.ptr and spell.name then
        if spell.name == "MissFortuneBulletTime" then
            r.RTime = game.time
        end
    end
end 
--
local function IsINSIDE_TAMGIAC(target, source, pos1, pos2)
	local fAB = (source.z - target.z)*(pos1.x - target.x) - (source.x - target.x)*(pos1.z - target.z)
	local fBC = (source.z - pos1.z)*(pos2.x - pos1.x) - (source.x - pos1.x)*(pos2.z - pos1.z)
	local fCA = (source.z - pos2.z)*(target.x - pos2.x) - (source.x - pos2.x)*(target.z - pos2.z)
    if ((fAB*fBC > 0) and (fBC*fCA > 0)) then 
        return true 
    end
    return false
end

local function CircleCircleIntersectionS(a1, a2, R1, R2)
	local C1 = vec3(a1.x, 0, a1.z)
    local C2 = vec3(a2.x, 0, a2.z)
    local D = GetDistance(C1, C2)
    local A = (R1 * R1 - R2 * R2 + D * D ) / (2 * D)
    local H = math.sqrt(R1 * R1 - A * A);
    local Direction = (C2 - C1):norm()
    local PA = C1 + A * Direction

    local S1 = PA + H * Direction:perp1()
    local S2 = PA - H * Direction:perp1()

    return S1, S2
end
--
local function Rotated(v, angle)
	local c = math.cos(angle)
	local s = math.sin(angle)
	return vec3(v.x * c - v.z * s, 0, v.z * c + v.x * s)
end

local function CrossProduct(p1, p2)
	return (p2.z * p1.x - p2.x * p1.z)
end
--
local function Qcone(Position, finishPos, firstPos)
	local range = 475
	local angle = 40 * math.pi / 180
	local end2 = finishPos - firstPos
	local edge1 = Rotated(end2, -angle / 2)
	local edge2 = Rotated(edge1, angle)

	local point = Position - firstPos
	if GetDistanceSqr(point, vec3(0,0,0)) < range * range and CrossProduct(edge1, point) > 0 and CrossProduct(point, edge2) > 0 then
		return true
	end
	return false
end 
--
local function CheckUltimate()
    if r.state == true then
        if (evade) then
            evade.core.set_pause(math.huge)
        end 
        orb.core.set_pause_move(math.huge)
        orb.core.set_pause_attack(math.huge)
    else 
        if (evade) then
            evade.core.set_pause(0)
        end 
        orb.core.set_pause_move(0)
        orb.core.set_pause_attack(0)
    end 
end 

local function LogicQ()
	local TargetQ = TargetSelecton(q.Range)
    local TargetQ2 = TargetSelecton(q2.Range)
    if TargetQ and IsValidTarget(TargetQ) and  ValidTargetRange(TargetQ, q.Range) and GetDistance(TargetQ) > 500 then
        local qDmg = DamageQ(TargetQ)
        if qDmg + CalculateAADamage(TargetQ) > TargetQ.health then
            player:castSpell("obj", 0, TargetQ)
        elseif qDmg + CalculateAADamage(target) * 3 > TargetQ.health  then
            player:castSpell("obj", 0, TargetQ)
        elseif IsValidTarget(TargetQ) and  ValidTargetRange(TargetQ, q.Range) then
            orb.combat.register_f_after_attack(function() 
                player:castSpell("obj", 0, TargetQ)
            end)
        end
    elseif ValidTargetRange(TargetQ2, q2.Range) then
        if TargetQ2 and IsValidTarget(TargetQ2) then
            local myHeroPos = vec3(player.x, player.y, player.z)
            local targetpos = vec3(TargetQ2.x, TargetQ2.y, TargetQ2.z)
            local posExtQ = targetpos + (myHeroPos - targetpos):norm() * -400
            local p1, p2 = CircleCircleIntersectionS(TargetQ2, posExtQ, 450, 225)
            if p1 and p2 then
                for i = 0, ObjMinion_Type.size[TEAM_ENEMY] - 1 do
                    local minion = ObjMinion_Type[TEAM_ENEMY][i]
                    if minion and IsValidTarget(minion) then
                        if ValidTargetRange(minion, 1300) then
                            local minionPos = vec3(minion.x, minion.y, minion.z)
                            local posExt = minionPos + (myHeroPos - minionPos):norm() * -400
                            if IsINSIDE_TAMGIAC(minionPos, targetpos, p1, p2) then
                                if Qcone(targetpos, posExt, minionPos) and minionPos:dist(player.pos) > 150 and minionPos:dist(targetpos) < 435 then
                                    player:castSpell("obj", 0, minion)
                                end
                            end
                        end
                    end
                end
            end 
        end
    end
end

local function LogicW()
    orb.combat.register_f_after_attack(function() 
        if player.mana > 180 then
            local TargetW = TargetSelecton(q.Range)
            if TargetW and IsValidTarget(TargetW) then
                player:castSpell("self", 1)
            end 
        end
    end)
end 

local function LogicE()
    local TargetE = TargetSelecton(e.Range)
    if TargetE and IsValidTarget(TargetE) and  ValidTargetRange(TargetE, e.Range) and GetDistance(TargetE) > 500 then
        local pos = pred.circular.get_prediction(PredE, TargetE)
        if pos and pos.startPos:dist(pos.endPos) < e.Range then
            player:castSpell("pos", 2, vec3(pos.endPos.x, mousePos.y, pos.endPos.y))
        end 
    end
end 

local function LogicR()
    if IsUnderTurretEnemy(player.pos) then
		return
	end
    local targetR = TargetSelecton(r.Range)
    if IsValidTarget(targetR) and targetR then
        if ValidUlt(targetR) then
			local rDmg = DamageR(targetR)
			if #CountEnemyChampAroundObject(player.pos, 800) < 2 then
				local tDis = GetDistance(targetR)
				if (rDmg * 7 > targetR.health and tDis < 800) then
					player:castSpell("pos", 3, targetR.pos)
                    r.RTime = game.time;
                elseif (rDmg * 6 > targetR.health and tDis < 900) then
                    player:castSpell("pos", 3, targetR.pos)
                    r.RTime = game.time;
                elseif (rDmg * 5 > targetR.health and tDis < 1000) then
                    player:castSpell("pos", 3, targetR.pos)
                    r.RTime = game.time;
                elseif (rDmg * 4 > targetR.health and tDis < 1100) then
                    player:castSpell("pos", 3, targetR.pos)
                    r.RTime = game.time;
                elseif (rDmg * 3 > targetR.health and tDis < 1200) then
                    player:castSpell("pos", 3, targetR.pos)
                    r.RTime = game.time;
                elseif (rDmg > targetR.health and tDis < 1300) then
                    player:castSpell("pos", 3, targetR.pos)
                    r.RTime = game.time;
                end
			end
			if (rDmg * 8 > targetR.health and rDmg * 2 < targetR.health and #CountEnemyChampAroundObject(player.pos, 300) == 0) then
                player:castSpell("pos", 2, targetR.pos)
                r.RTime = game.time;
            end
		end
	end
end

local function QClear()
    local TargetQ2 = TargetSelecton(q2.Range)
    if TargetQ2 and IsValidTarget(TargetQ2) and ValidTargetRange(TargetQ2, q2.Range) then
        if TargetQ2 and IsValidTarget(TargetQ2) then
            local myHeroPos = vec3(player.x, player.y, player.z)
            local targetpos = vec3(TargetQ2.x, TargetQ2.y, TargetQ2.z)
            local posExtQ = targetpos + (myHeroPos - targetpos):norm() * -400
            local p1, p2 = CircleCircleIntersectionS(TargetQ2, posExtQ, 450, 225)
            if p1 and p2 then
                for i = 0, ObjMinion_Type.size[TEAM_ENEMY] - 1 do
                    local minion = ObjMinion_Type[TEAM_ENEMY][i]
                    if minion and IsValidTarget(minion) then
                        if ValidTargetRange(minion, 1300) and DamageQ(minion) > minion.health then
                            local minionPos = vec3(minion.x, minion.y, minion.z)
                            local posExt = minionPos + (myHeroPos - minionPos):norm() * -400
                            if IsINSIDE_TAMGIAC(minionPos, targetpos, p1, p2) then
                                if Qcone(targetpos, posExt, minionPos) and minionPos:dist(player.pos) > 150 and minionPos:dist(targetpos) < 435 then
                                    player:castSpell("obj", 0, minion)
                                end
                            end
                        end
                    end
                end
            end 
        end
    end
end

local function OnTick()
    if CheckBuff(player, "missfortunebulletsound") then
        r.state = true
    else 
        r.state = false
    end
    --
    CheckUltimate()
    --
    if (orb.combat.is_active()) then
        if player:spellSlot(0).state == 0 and MenuMiss.Qc.autoQ:get() then
            LogicQ();
        end
        if player:spellSlot(1).state == 0 and MenuMiss.Wc.autoW:get() then
            LogicW();
        end
        if player:spellSlot(2).state == 0 and MenuMiss.Ec.autoE:get() then
            LogicE();
        end
        if player:spellSlot(3).state == 0 and MenuMiss.Rc.autoR:get() then
            LogicR();
        end
    end
    if (orb.menu.lane_clear:get()) then
		QClear()
    end
end 

local function OnDraw()
    local target = TargetSelecton(q.Range)
    if target and IsValidTarget(target) then
        if player.isVisible and player.isOnScreen and not player.isDead then
            graphics.draw_circle(target.pos, 70, 1, graphics.argb(255, 255, 204, 255), 100)
        end 
    end 
    if IsValidTarget(player) and (player.isOnScreen) then
        if player:spellSlot(0).state == 0 and MenuMiss.Dt.DQ:get() then
            graphics.draw_circle(player.pos, q.Range, 1, graphics.argb(255, 0, 255, 233), 100)
        end 
        if player:spellSlot(0).state == 0 and MenuMiss.Dt.DQ2:get() then
            graphics.draw_circle(player.pos, q2.Range, 1, graphics.argb(255, 0, 255, 233), 100)
        end 
        if player:spellSlot(2).state == 0 and MenuMiss.Dt.DE:get() then
            graphics.draw_circle(player.pos, e.Range, 1, graphics.argb(255, 255, 255, 255), 100)
        end 
    end 
    if MenuMiss.Dt.DDM:get() then
        for i = 0, objManager.enemies_n - 1 do
            local hero = objManager.enemies[i]
            if hero.isOnScreen then 
                if IsValidTarget(hero) then
                    local barPos = hero.barPos                   
                    local percentHealthAfterDamage = math.max(0, hero.health - (DamageQ(hero)+DamageR(hero))) / hero.maxHealth
                    graphics.draw_line_2D(barPos.x + 165 + 103 * hero.health/hero.maxHealth, barPos.y+123, barPos.x + 165 + 100 * percentHealthAfterDamage, barPos.y+123, 11, graphics.argb(255,235,103,25))        
                end    
            end  
        end
    end
end

cb.add(cb.tick, OnTick)
cb.add(cb.spell, ProSpell)
cb.add(cb.draw, OnDraw)