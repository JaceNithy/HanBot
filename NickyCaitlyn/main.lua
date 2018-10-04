local pred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local evade = module.seek("evade")
--Spells
local q = { Range = 1250, QCout = 1}
local w = { Range = 800, LastTrapTime = 0 }
local e = { Range = 750 }
local r = { Range = 2000}

local PredQ = {	delay = 0.625, speed = 2200, width = 90, boundingRadiusMod = 0, collision = { hero = false, minion = false }}
local PredE = { delay = 0.125, speed = 1600, width = 90, boundingRadiusMod = 0, collision = { hero = true, minion = true }}

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
--API
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
local function GetTotalAP(obj)
    local obj = obj or player
    return obj.flatMagicDamageMod * obj.percentMagicDamageMod
end
--
local function GetTotalAD(obj)
    local obj = obj or player
    return (obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod
end  
--
local function GetPercentHealth(obj)
    local obj = obj or player
    return (obj.health / obj.maxHealth) * 100
end
--
local function PhysicalReduction(target, damageSource)
    local damageSource = damageSource or player
    local armor = ((target.bonusArmor * damageSource.percentBonusArmorPenetration) + (target.armor - target.bonusArmor)) * damageSource.percentArmorPenetration
    local lethality = (damageSource.physicalLethality * .4) + ((damageSource.physicalLethality * .6) * (damageSource.levelRef / 18))
    return armor >= 0 and (100 / (100 + (armor - lethality))) or (2 - (100 / (100 - (armor - lethality))))
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
local function CalculatePhysicalDamage(target, damage, damageSource)
    local damageSource = damageSource or player
    if target then
        return (damage * PhysicalReduction(target, damageSource)) * DamageReduction("AD", target, damageSource)
    end
    return 0
end
--
--
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
--
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
local function CountMinionsChampAroundObject(pos, range) 
	local EnemysMinion = {}
	for i = 0, ObjMinion_Type.size[TEAM_ENEMY] - 1 do
        local minion = ObjMinion_Type[TEAM_ENEMY][i]
		if pos:dist(minion.pos) < range and IsValidTarget(minion) then
			EnemysMinion[#EnemysMinion + 1] = minion
		end
	end
	return EnemysMinion
end
--
local hard_cc = {
    [5] = true, -- stun
    [8] = true, -- taunt
    [11] = true, -- snare
    [18] = true, -- sleep
    [21] = true, -- fear
    [22] = true, -- charm
    [24] = true, -- suppression
    [29] = true, -- knockup
    [30] = true -- knockback
  }
--
local function ValidUlt(unit)
	if (CheckBuffType(unit, 16) or CheckBuffType(unit, 15) or CheckBuffType(unit, 17) or CheckBuff(unit, "kindredrnodeathbuff") or CheckBuffType(unit, 4)) then
		return false
	end
	return true
end

local function IsImmobileTarget(unit)
	if (CheckBuffType(unit, 5) or CheckBuffType(unit, 11) or CheckBuffType(unit, 29) or CheckBuffType(unit, 24) or CheckBuffType(unit, 10) or CheckBuffType(unit, 29))  then
		return true
	end
	return false
end
--
local function IsLogicE(target)
	return player.path.serverPos:distSqr(target.path.serverPos) > player.path.serverPos:distSqr(target.path.serverPos + target.direction)
end
--
local function IsReady(spell)
    return player:spellSlot(spell).state == 0
end 
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
local function DamageR(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {250,475,700}
        if player:spellSlot(3).state == 0 then
			Damage = (DamageAP[player:spellSlot(3).level] + 1 * ((player.baseAttackDamage + player.flatPhysicalDamageMod)*(1 + player.percentPhysicalDamageMod)))
        end
		return CalculatePhysicalDamage(target, Damage)
	end
	return 0
end
--
local function DamageQ(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {30, 70, 110, 150, 190}
		local bonusR = {1.3, 1.4, 1.5, 1.6, 1.7}
        if player:spellSlot(0).state == 0 then
			Damage = (DamageAP[player:spellSlot(0).level] + bonusR[player:spellSlot(0).level] * player.baseAttackDamage + player.flatPhysicalDamageMod * 1 + player.percentPhysicalDamageMod)
        end
		return CalculatePhysicalDamage(target, Damage)
	end
	return 0
end
--
local MCait = menu("[Nicky]Caitlyn", "[Nicky]Caitlyn")
MCait:menu("Qc", "[Q] Settings")
MCait.Qc:boolean("CQ", "Combo [Q]", true)
MCait.Qc:dropdown("QMode", "Is [Q]Mode", 2, {"Only Kill", "Always", "Only Buff [CC]"})
MCait.Qc:boolean("farmqout", "Farm out range [AA]", true)
MCait.Qc:boolean("LCQ", "Champion [Q2]", true)
MCait.Qc:boolean("ForcAAQ", "Force AA + [Q]", true)
MCait.Qc:header("xd8", "[Q] Auto [Harass]")
MCait.Qc:boolean("AHA", "Harass [Q]", true)
MCait.Qc:slider("ManaHarass", "Only Mana AutoHarass [Q] % <", 75, 1, 100, 1)
--
MCait:menu("Wc", "[W] Settings")
MCait.Wc:boolean("CW", "Combo [W]", true)
MCait.Wc:boolean("CWCC", "Buff CC [W]", true)
MCait.Wc:boolean("CDFW", "E + [W]", true)
MCait.Wc:boolean("ASF", "AA + Buff [W]", true)
MCait.Wc:boolean("AEA", "Force AA + [W]", true)
MCait.Wc:boolean("ASDCW", "[W] + [Q]", true)
MCait.Wc:boolean("CSA", "TAF + AA + [W]", true)
--
MCait:menu("Ec", "[E] Settings")
MCait.Ec:boolean("CE", "Combo [E]", true)
--
MCait:menu("Rc", "[R] Settings")
MCait.Rc:boolean("CR", "Combo [R]", true)

MCait:menu("Dt", "Drawings Settings")
MCait.Dt:boolean("DQ", "Draw [Q]", true)
MCait.Dt:boolean("DW", "Draw [W]", false)
MCait.Dt:boolean("DE", "Draw [E]", false)
MCait.Dt:boolean("DR", "Draw [R]", true)
--
local function AAForce()
    if (orb.menu.lane_clear:get()) then
        local target = TargetSelecton()
        if target and IsValidTarget(target) then
            if player.pos:dist(target.pos) <= GetAARange(player) + 10 then
                if CheckBuff(player, "caitlynheadshot") then
                    player:attack(target)
                end 
            end 
        end 
    end 
end

local function BuffAA()
    local target = TargetSelecton(1200)
    if target and IsValidTarget(target) then
        if vec3(target.x, target.y, target.z):dist(player) <= 1300 then
            if CheckBuff(target, "caitlynyordletrapinternal") then
                player:attack(target)
            end 
        end 
    end 
end

local function EGapcloser()
	if player:spellSlot(2).state == 0 then
		for i = 0, objManager.enemies_n - 1 do
			local IsDashingPlayer = objManager.enemies[i]
			if IsDashingPlayer.type == TYPE_HERO and IsDashingPlayer.team == TEAM_ENEMY then
				if IsDashingPlayer and IsValidTarget(IsDashingPlayer) and IsDashingPlayer.path.isActive and IsDashingPlayer.path.isDashing and player.pos:dist(IsDashingPlayer.path.point[1]) < 850 then
					if player.pos2D:dist(IsDashingPlayer.path.point2D[1]) < player.pos2D:dist(IsDashingPlayer.path.point2D[0]) then
						if ((player.health / player.maxHealth) * 100 <= 100) then
							player:castSpell("pos", 2, IsDashingPlayer.path.point2D[1])
						end
					end
				end
			end
		end
	end
end

local function KillSteal()
    for i = 0, objManager.enemies_n - 1 do
        local target = objManager.enemies[i]
        if target and IsValidTarget(target) then
            local Distancia = (target.pos - player.pos):len()
            if player:spellSlot(0).state == 0 and (Distancia > 675 and target.pos:dist(player.pos) < q.Range) and #CountEnemyChampAroundObject(player.pos, 625) == 0 and (DamageQ(target) - target.healthRegenRate) > GetShieldedHealth("AD", target) then
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
local function OnCombo(target)
    local ModeQ = MCait.Qc.QMode:get()
    local Distancia = (target.pos - player.pos):len()
    if ModeQ == 1 then
        if player:spellSlot(0).state == 0 and (Distancia > 675 and target.pos:dist(player.pos) < q.Range) and #CountEnemyChampAroundObject(player.pos, 625) == 0 and (DamageQ(target) - target.healthRegenRate) > GetShieldedHealth("AD", target) then
            local PosQ3D = pred.linear.get_prediction(PredQ, target)
            if PosQ3D then
                local QEndPos = vec3(PosQ3D.endPos.x, target.pos.y, PosQ3D.endPos.y)
                player:castSpell("pos", 0, vec3(QEndPos))
            end 
        end 
    elseif ModeQ == 2 then
        if player:spellSlot(0).state == 0  and target.pos:dist(player.pos) < q.Range and #CountEnemyChampAroundObject(player.pos, 600) == 0 and target.pos:dist(player.pos) > GetAARange(player) then 
            local PosQ3D = pred.linear.get_prediction(PredQ, target)
            if PosQ3D then
                local QEndPos = vec3(PosQ3D.endPos.x, target.pos.y, PosQ3D.endPos.y)
                player:castSpell("pos", 0, vec3(QEndPos))
            end 
        end 
    elseif ModeQ == 3 then
        if player:spellSlot(0).state == 0 and (CheckBuff(target, "caitlynyordletrapinternal") or IsImmobileTarget(target)) and target.pos:dist(player.pos) < q.Range then
            local PosQ3D = pred.linear.get_prediction(PredQ, target)
            if PosQ3D then
                local QEndPos = vec3(PosQ3D.endPos.x, target.pos.y, PosQ3D.endPos.y)
                player:castSpell("pos", 0, vec3(QEndPos))
            end 
        end 
    end 
    if MCait.Rc.CR:get() and player:spellSlot(3).state == 0 and Distancia < r.Range and Distancia > 1000 and (DamageR(target) - target.healthRegenRate) > GetShieldedHealth("AD", target) and #CountEnemyChampAroundObject(player.pos, 625) == 0 then
        if (#CountAllyChampAroundObject(target.pos, 550) > 0 or #CountAllyChampAroundObject(target.pos, 550) == 0) then
            player:castSpell("obj", 3, target)
        end 
       
    end
    if MCait.Wc.CW:get() and player:spellSlot(1).state == 0 and Distancia < w.Range and (IsImmobileTarget(target) or CheckBuff(target, "caitlynyordletrapinternal")) then
        if os.clock() - w.LastTrapTime > 2 then
            player:castSpell("pos", 1, target.pos)
            w.LastTrapTime = os.clock()
        end 
    end  
    if MCait.Ec.CE:get() and (player:spellSlot(2).level > 0 or player:spellSlot(2).state == 0) and Distancia < 500 then
        local pos2 = pred.linear.get_prediction(PredE, target)
        if not pred.collision.get_prediction(PredE, pos2, target) then
            if pos2 then
                local ppos = vec3(pos2.endPos.x, target.pos.y, pos2.endPos.y)
                player:castSpell("pos", 2, ppos)
            end 
        end 
    end 				
end 
--
local function AutoClear()
    local target = TargetSelecton(q.Range)
    if target and IsValidTarget(target) then
        if MCait.Qc.AHA:get() and (player.mana / player.maxMana) * 100 >= MCait.Qc.ManaHarass:get() then
            if player:spellSlot(0).state == 0  and target.pos:dist(player.pos) < q.Range and #CountEnemyChampAroundObject(player.pos, 600) == 0 and target.pos:dist(player.pos) > GetAARange(player) then 
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
    AAForce()
    KillSteal()
    if MCait.Qc.ForcAAQ:get() then
        BuffAA()
    end 
    --
    EGapcloser()
    --
    if player:spellSlot(3).level == 1 then
        r.Range = 2000  
    elseif player:spellSlot(3).level == 2 then
        r.Range = 2500  
    elseif player:spellSlot(3).level == 3 then 
        r.Range = 3000 
    end 
   --[[if CheckBuff(player, "caitlynheadshot") then caitlynheadshot
        print("Soht")
    end ]]
    if (orb.combat.is_active()) then 
        local target = TargetSelecton(1500)
        if target and IsValidTarget(target) then
            OnCombo(target) 
        end 
    end
    if (orb.menu.lane_clear:get()) then
		AutoClear()
	end
end 

local function OnDraw()
    if IsValidTarget(player) then
        if IsReady(0) and MCait.Dt.DQ:get() then
            graphics.draw_circle(player.pos, q.Range, 1, graphics.argb(255, 255, 0, 255), 10)
        end
        if IsReady(1) and MCait.Dt.DW:get() then
            graphics.draw_circle(player.pos, w.Range, 2, graphics.argb(255, 255, 204, 255), 100)
        end
        if IsReady(2) and MCait.Dt.DE:get()  then
            graphics.draw_circle(player.pos, e.Range, 2, graphics.argb(255, 255, 204, 255), 100)
        end 
        if IsReady(3) and MCait.Dt.DR:get() then
            graphics.draw_circle(player.pos, r.Range, 2, graphics.argb(255, 255, 204, 255), 100)
        end   
    end 
end 

orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.draw, OnDraw)