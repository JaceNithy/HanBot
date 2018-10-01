local pred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local evade = module.seek("evade")
local ObjMinion_Type = objManager.minions
--Spells
local q = { Range = 260, QCout = 1}
local w = { Range = 225 }
local e = { Range = 325 }
local r = { Range = 1100,  Width = 160, Delay = 0.25, Speed = 1600}

local RPsred = { delay = 0.25, width = 160, speed = 1600, boundingRadiusMod = 1, collision = { hero = false, minion = false,}}
--
local FlashRange = 425 + 70 + 225 
local EngangeRange = 325
local QLastCastTick = 0
local WLastCastTick = 0
local ELastCastTick = 0
local RWindslashReady = false 
local RAttackRangeBoost = false
local IsFlash = nil
local IgniteFlott = nil
local UnderTurret = false
local TimeTurret = 0

local spellsToSilence = {
	["Anivia"] = { 3 },
	["Caitlyn"] = { 3 },
	["Darius"] = { 3 },
	["FiddleSticks"] = { 1, 3 },
	["Gragas"] = { 1 },
	["Janna"] = { 3 },
	["Karthus"] = { 3 },
	["Katarina"] = { 3 },
	["Malzahar"] = { 3 },
	["MasterYi"] = { 1 },
	["MissFortune"] = { 3 },
	["Nunu"] = { 3 },
	["Pantheon"] = { 2, 3 },
	["Sion"] = { 0 },
	["TwistedFate"] = { 3 },
	["Varus"] = { 0 },
	["Vi"] = { 0, 3 },
	["Warwick"] = { 3 },
	["Xerath"] = { 0, 3 }
}
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

if player:spellSlot(4).name == "SummonerFlash" then
	IsFlash = 4
elseif player:spellSlot(5).name == "SummonerFlash" then
	IsFlash = 5
end

if player:spellSlot(4).name == "SummonerDot" then
	IgniteFlott = 4
elseif player:spellSlot(5).name == "SummonerDot" then
	IgniteFlott = 5
end

local function IsUnderTurrent(pos)
	if TimeTurret < game.time then
		TimeTurret = game.time + 0.1
        objManager.loop(function(obj) if obj and obj.pos:dist(pos) < 900 and obj.team == TEAM_ENEMY and obj.type == TYPE_TURRET then
            UnderTurret = true
            end
        end)
        return UnderTurret
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
local function IsReady(spell)
    return player:spellSlot(spell).state == 0
end 
--
local function RealDamage(target, damage)
    if CheckBuff(target, "KindredRNoDeathBuff") or CheckBuff(target, "JudicatorIntervention") or CheckBuff(target, "FioraW") or CheckBuff(target, "ShroudofDarkness")  or CheckBuff(target, "SivirShield") then
        return 0  
    end
    local pbuff = CheckBuff(target, "UndyingRage")
    if CheckBuff(target, "UndyingRage") and pbuff.endTime > game.time + 0.3  then
        return 0
    end
    local pbuff2 = CheckBuff(target, "ChronoShift")
    if CheckBuff(target, "ChronoShift") and pbuff2.endTime > game.time + 0.3 then
        return 0
    end
    if CheckBuff(player, "SummonerExhaust") then
        damage = damage * 0.6;
    end
    if CheckBuff(target, "BlitzcrankManaBarrierCD") and CheckBuff(target, "ManaBarrier") then
        damage = damage - target.mana / 2
    end
    if CheckBuff(target,"GarenW") then
        damage = damage * 0.6;
    end
    return damage
end 
--
local function DamageQ(target)
    if target ~= 0 then
		local Damage = 0
        local DamageAP = {15, 35, 55, 75, 95}
        local BonusQ = {0.45, 0.5, 0.55, 0.6, 0.65}
        if player:spellSlot(0).state == 0 then
			Damage = (DamageAP[player:spellSlot(0).level] + BonusQ[player:spellSlot(0).level] * ((player.baseAttackDamage + player.flatPhysicalDamageMod)*(1 + player.percentPhysicalDamageMod)))
        end
		return CalculatePhysicalDamage(target, Damage)
	end
	return 0
end
local function DamageW(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {55, 85, 115, 145, 175}
        if player:spellSlot(1).state == 0 then
			Damage = (DamageAP[player:spellSlot(1).level] + 0.6 * ( (player.baseAttackDamage + player.flatPhysicalDamageMod) * (1 + player.percentPhysicalDamageMod) - player.baseAttackDamage) )
        end
		return CalculatePhysicalDamage(target, Damage)
	end
	return 0
end
local function DamageR(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {100, 150, 200}
        if player:spellSlot(3).state == 0 then
			Damage = (DamageAP[player:spellSlot(3).level] + 0.6 * ((player.baseAttackDamage + player.flatPhysicalDamageMod) * (1 + player.percentPhysicalDamageMod) - player.baseAttackDamage))
        end
		return CalculatePhysicalDamage(target, Damage)
	end
	return 0
end
--
local function RealDamageR(target)
    local aa = GetTotalAP(player)
    local dmg = aa
    if player:spellSlot(3).state == 0 then
        dmg = dmg + DamageR(target)
    end
    dmg = RealDamage(target, dmg)
    return dmg
end 
--
local function ComboDamage(target)
    local aa = GetTotalAD(player)
    local dmg = aa
    if player:spellSlot(0).state == 0 then
        dmg = dmg + DamageQ(target) 
    end
    if player:spellSlot(1).state == 0 then
        dmg = dmg + DamageW(target) 
    end
    if player:spellSlot(3).state == 0 then
        dmg = dmg + DamageR(target) 
    end
    dmg = RealDamage(target, dmg)
    return dmg
end 
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

local function GetIgniteDamage(target)
    local damage = 55 + (25 * player.levelRef)
    if target then
        damage = damage - (GetShieldedHealth("AD", target) - target.health)
    end
    return damage
end 

--
local MRiven = menu("Nicky [Riven]", "[Nicky]Riven")
MRiven:menu("ri", "Setting [Riven]")
MRiven.ri:boolean("AFE", "Auto Flash Execute", true)
MRiven.ri:boolean("UT", "Use Tiamat", true)
MRiven.ri:boolean("RC", "Use R in Combo", true)
MRiven.ri:boolean("Keep", "Keep Q Active", true)
MRiven.ri:header("xd", "Draws")
MRiven.ri:boolean("Engage", "Draw Engage Range", true)
MRiven.ri:header("x2d", "Burts [Key]")
MRiven.ri:keybind("CK", "[Key] Burts", "T", nil)
MRiven.ri:keybind("ComK", "[Key] Burts", "Space", nil)
MRiven.ri:header("xd", "KillSteal")
MRiven.ri:boolean("KQ", "KillSteal [Q]", true)
MRiven.ri:boolean("KW", "KillSteal [W]", true)
--
local function Reset()
    orb.core.set_pause_move(0)
    orb.core.set_pause_attack(0)
    orb.core.reset()
    print("Reseted")
end
--
local function CanCastTimat(target)
    if (target.pos:dist(player.pos) <= 275) then
        for i = 6, 11 do
            local item = player:spellSlot(i).name
            if item and (item == "ItemTiamatCleave") then
                player:castSpell("obj", i, target)
            end
            if item and (item == "ItemTitanicHydraCleave") then
                player:castSpell("obj", i, target)
            end
        end 
    end 
end 
--
local function UpdateBuff()
    if CheckBuff(player, "RivenFeint") then
        ELastCastTick = game.time
    end 
    if CheckBuff(player, "rivenwindslashready") then
        RWindslashReady = true
    else
        RWindslashReady = false
    end 
    if CheckBuff(player, "RivenFengShuiEngine") then
        RAttackRangeBoost = true
    else
        RAttackRangeBoost = false
    end 
end 

local function CastW(target)
    local wRange = 125 + target.boundingRadius
  
    if RAttackRangeBoost == true then
      wRange = wRange + 10
    end
  
    if target.pos:dist(player.pos) <= wRange then
        player:castSpell("self", 1)
    end
end

local function OnPrecesse(spell)
    if player:spellSlot(1).state == 0 then
        local wRange = 100 + player.boundingRadius
		local champ = spell.owner
		if champ.team == TEAM_ENEMY then
			local slot = spell.slot
			if player.pos:dist(champ.pos) <= wRange then
				if spell.name == "SummonerTeleport" then
					player:castSpell("pos", 1, spell.owner.pos)
				else
					local spells = spellsToSilence[champ.charName]
					if spells then
						for i = 1, #spells do
							if slot == spells[i] then
								player:castSpell("pos", 1, spell.owner.pos)
								break
							end
						end
					end
				end
			end
		end
    end
    if spell.owner.type == TYPE_HERO and spell.owner.team == TEAM_ALLY and spell.owner.charName == "Riven" and spell.name == "RivenTriCleave" then
        QLastCastTick = game.time
        q.QCout = q.QCout + 1
        if q.QCout > 3 then
            q.QCout = 1
        end
    end
end 

local function CastQ(target)
    local delay = math.min(60/1000, network.latency/1000)
    local coreDelay =  0.11 - (0.008 * player.levelRef)
    delay = delay + coreDelay
    if q.QCout == 3 then
      delay = delay + 0.03
    end
    if CanCastTimat(target) and q.QCout == 3 then
        CanCastTimat(target) 
        DelayAction(function() player:castSpell("obj", 0, target) end, 0.23)
    else
        player:castSpell("obj", 0, target)
    end
    orb.core.set_pause_move(math.huge)
    orb.core.set_pause_attack(math.huge)
    DelayAction(function() Reset() end, delay)
end 

local function CastR(target)
    if RWindslashReady == true then
        local RPred = pred.linear.get_prediction(RPsred, target)
        if RPred and RPred.startPos:dist(RPred.endPos) < r.Range  then
            DelayAction(function() player:castSpell("pos", 3, vec3(RPred.endPos.x, game.mousePos.y, RPred.endPos.y)) end, 0.25)
        end
        player:castSpell("pos", 3, vec3(RPred.endPos.x, RPred.endPos.y, RPred.endPos.y))
        orb.core.reset() 
    else 
        player:castSpell("self", 3)
        CanCastTimat(target)
    end

end 

local function CastE(target)
    if player.pos:dist(target.pos) <= EngangeRange and player.pos:dist(target.pos) > player.attackRange then
        if player:spellSlot(2).state == 0 then
            player:castSpell("pos", 2, target.pos)
        end 
    end 
end 

local function FlashW(target)
    local flashPos = target.pos + (target.pos - player.pos):norm() * -180
  
    if (RAttackRangeBoost == true or player:spellSlot(3).state == 0) then
        DelayAction(function() player:castSpell("pos", IsFlash, vec3(flashPos)) end, 0.2)
    else
        player:castSpell("pos", IsFlash, vec3(flashPos))
    end
end

local function BurtsMode()
    player:move(mousePos)
    local range = FlashRange - 425
    if (IsFlash and player:spellSlot(IsFlash).state == 0) then
        range = range + 425
    end 
    local target = TargetSelecton()
    if IsValidTarget(target) and player.pos:dist(target.pos) <= range then
        if player:spellSlot(2).state == 0 then
            player:castSpell("pos", 2, target.pos)
        end 
        if player:spellSlot(3).state == 0 then
            CastR(target)
        end 
        if player:spellSlot(1).state == 0 and player.pos:dist(target.pos) <= 225 + target.boundingRadius then
            player:castSpell("self", 1)
        end 
        if player:spellSlot(IsFlash).state == 0 and player:spellSlot(1).state == 0 then
            FlashW(target)
        end 
        if player:spellSlot(0).state == 0  then
            CastQ(target)
        end 
        if player.pos:dist(target.pos) <= player.attackRange then
            player:attack(target)
        end
    end 
end 

local function OnCombo(target)
    --local target = TargetSelecton()
    --if IsValidTarget(target) then
        if (orb.combat.is_active()) then
            if player:spellSlot(3).state == 0 then
                CastR(target)
            end
            if RWindslashReady == true then
                DelayAction(function() CastQ(target) end, 0.25)
            end 
        elseif player:spellSlot(0).state == 0  then
            CastQ(target)
        end 
        if orb.combat.target then
            if player:spellSlot(3).state == 0 and GetPercentHealth(target) > 10 then
                if not RWindslashReady == true  and ComboDamage(target) > target.health then
                    player:castSpell("self", 3)
                    DelayAction(function() CastW(target) end, 0.325)
                end
                if q.QCout == 3 and target.health / target.maxHealth * 100 <= 50 then
                    CastR(target)
                    DelayAction(function() player:castSpell("obj", 0, target) end, 0.3)
                end 
            end 
            if player:spellSlot(1).state == 0 and game.time - ELastCastTick < 1.20 then
                CastW(target)
            end
            if player:spellSlot(0).state == 0 then
                CastQ(target)
                if player:spellSlot(1).state == 0 and game.time - ELastCastTick >= 0.1 then
                    DelayAction(function() CastW(target) end, 0.1)
                    DelayAction(function() CastQ(target) end, 0.8)
                end
            end
        end 
    --end
end 

local function Lane()
    if (#CountEnemyChampAroundObject(player.pos, 1500) == 0 and orb.menu.lane_clear:get()) then
        for i = 0, ObjMinion_Type.size[TEAM_ENEMY] - 1 do
            local minion = ObjMinion_Type[TEAM_ENEMY][i]
            if minion and IsValidTarget(minion) then
                if player:spellSlot(0).state == 0 and minion.pos:dist(player.pos) < q.Range and #CountMinionsChampAroundObject(player.pos, 340) > 1 then
                    CastQ(minion)
                end
                local wRange = 125 + minion.boundingRadius
                if player:spellSlot(1).state == 0 and minion.pos:dist(player.pos) < q.Range and #CountMinionsChampAroundObject(player.pos, wRange) == 3 then
                    CastW(minion)
                end 
            end 
        end 
    end
    if (#CountEnemyChampAroundObject(player.pos, 900) == 0 and orb.menu.lane_clear:get()) then
        local target = { obj = nil, health = 0, mode = "jungleclear" }
        local aaRange = player.attackRange + player.boundingRadius + 200
        for i = 0, ObjMinion_Type.size[TEAM_NEUTRAL] - 1 do
            local obj = ObjMinion_Type[TEAM_NEUTRAL][i]
            if player.pos:dist(obj.pos) <= aaRange and obj.maxHealth > target.health then
                target.obj = obj
                target.health = obj.maxHealth
            end
        end
        if target.obj then
            if target.mode == "jungleclear" then
                if player:spellSlot(0).state == 0 then
                    CastQ(target.obj)
                end
                if player:spellSlot(1).state == 0 then
                    CastW(target.obj)
                end
                if player:spellSlot(2).state == 0 then
                    CastE(target.obj)
                end
            end
        end
    end 
end 

local function CanCastIgnite()
    for i = 0, objManager.enemies_n - 1 do
        local target = objManager.enemies[i]
        if target and IsValidTarget(target) then 
            if player.pos:dist(target.pos) <= 625 then
                if (IgniteFlott and player:spellSlot(IgniteFlott).state == 0) then
                    if GetIgniteDamage(target) > target.health then
                        player:castSpell("obj", IgniteFlott, target)
                    end
                end 
            end 
        end 
    end 
end 

local function AutoFlash()
    local range = FlashRange - 425
    if (IsFlash and player:spellSlot(IsFlash).state == 0) then
        range = range + 425
    end 
    local target = TargetSelecton()
    if IsValidTarget(target) and player.pos:dist(target.pos) <= range and player.pos:dist(target.pos) > GetAARange(player) and IsUnderTurrent(target.pos) == false then
        if (#CountEnemyChampAroundObject(player.pos, 1100)) == 1 and (DamageQ(target) + DamageW(target) > target.health) then
            if player:spellSlot(1).state == 0 and player.pos:dist(target.pos) <= 225 + target.boundingRadius then
                player:castSpell("self", 1)
            end 
            if player:spellSlot(IsFlash).state == 0 and player:spellSlot(1).state == 0 then
                FlashW(target)
            end 
            if player:spellSlot(0).state == 0  then
                CastQ(target)
            end 
        end 
    end 
end 

local function KillQ()
    local target = TargetSelecton()
    if target and IsValidTarget(target) and player.pos:dist(target.pos) > GetAARange(player) and IsUnderTurrent(target.pos) == false then
        if (#CountEnemyChampAroundObject(player.pos, 1100)) == 1 and DamageQ(target) > target.health then
            CastQ(target)
        end 
    end 
end 

local function KillW()
    local target = TargetSelecton()
    if target and IsValidTarget(target) then 
        local wRange = 125 + target.boundingRadius
        if player.pos:dist(target.pos) <= wRange then
            if DamageW(target) > target.health then
                CastW(target)
            end
        end 
    end 
end 

local function OnTick()
    UpdateBuff()
    --
    if player:spellSlot(3).state == 0 and MRiven.ri.RC:get() then 
        EngangeRange = e.Range + player.attackRange + 230
    else
        EngangeRange = e.Range + player.attackRange + 150
    end 
    --
    if (#CountEnemyChampAroundObject(player.pos, 1000) == 0 and not orb.menu.lane_clear:get()) then
        if MRiven.ri.Keep:get() and QLastCastTick and game.time - QLastCastTick > 3.25 and q.QCout ~= 1 then
            player:castSpell("pos", 0, game.mousePos)
        end 
    end
    --
    if MRiven.ri.CK:get() and player:spellSlot(3).state == 0 then
        BurtsMode()
    end 
    --
    if (orb.combat.is_active()) then 
        local target = TargetSelecton()
        if target and IsValidTarget(target) then
            OnCombo(target) 
            CastE(target)
        end 
    end
    CanCastIgnite()
    --
    if MRiven.ri.AFE:get() then
        AutoFlash()
    end
    --
    if MRiven.ri.KQ:get() then
        KillQ()
    end 
    --
    if MRiven.ri.KW:get() then
        KillW()
    end 
end 

local function OnDraw()
    if MRiven.ri.Engage:get() then
        if player.isOnScreen and IsValidTarget(player) then
            if player:spellSlot(2).state == 0 then
                graphics.draw_circle(player.pos, EngangeRange, 2, graphics.argb(255, 0, 204, 255), 100)
            end 
        end 
    end 
end 

orb.combat.register_f_pre_tick(OnTick)
orb.combat.register_f_after_attack(Lane)
cb.add(cb.spell, OnPrecesse)
cb.add(cb.draw, OnDraw)