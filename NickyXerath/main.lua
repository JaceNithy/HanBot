local pred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local evade = module.seek("evade")

--Spells
local q = { MaxRange = 1400, MinRange = 750, QCharge = false, TimeQ = 0 }
local w = { Range = 1100 }
local e = { Range = 1000 }
local r = { Range = 0, RCharge = false, RStacks = 0 }
--Pred
local PredQ = { delay = 0.25; width = 72; speed = 2000; boundingRadiusMod = 1; collision = { hero = false, minion = false };}
local PredE = { delay = 0.7; width = 30; speed = 2300; boundingRadiusMod = 1; collision = { hero = true, minion = true };}
local PredW = { delay = 0.75; radius = 200; speed = 1200; boundingRadiusMod = 1;}
local PredR = { delay = 0.25; radius = 200; speed = 1600; boundingRadiusMod = 1;}

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
local function GetPercentHealth(obj)
    local obj = obj or player
    return (obj.health / obj.maxHealth) * 100
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
local function RealDamageMagic(target, damage)
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
local function DamageR(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {200, 240, 280}
        if player:spellSlot(3).state == 0 then
			Damage = (DamageAP[player:spellSlot(3).level] + 0.43 * (player.flatMagicDamageMod * player.percentMagicDamageMod))
        end
		return Damage
	end
	return 0
end
--
local function RealDamageR(target)
    local aa = GetTotalAP(player)
    local dmg = aa
    if player:spellSlot(3).state == 0 then
        dmg = dmg + DamageR(target) * r.RStacks
    end
    dmg = RealDamageMagic(target, dmg)
    return dmg
end 
--
local MenuXerath = menu("[Nicky]Xerath", "[Nicky]Xerath")
MenuXerath:menu("Qc", "Arcanopulse [Q] Settings")
MenuXerath.Qc:boolean("CQ", "Combo [Q]", true)
--
MenuXerath:menu("Wc", "Eye of Destruction [W] Settings")
MenuXerath.Wc:boolean("CW", "Combo [W]", true)
--
MenuXerath:menu("Ec", "Shocking Orb	 [E] Settings")
MenuXerath.Ec:boolean("CE", "Combo [E]", true)
MenuXerath.Ec:boolean("AtuOE", "Silence [E]", true)
--
MenuXerath:menu("Rc", "Rite of the Arcane [R] Settings")
MenuXerath.Rc:boolean("CR", "Combo [R]", true)
MenuXerath.Rc:keybind("ACR", "Rite of the Arcane", "R", nil)
MenuXerath.Rc:boolean("Mode", "Kill Enemy [R]", true)

MenuXerath:menu("Dt", "Drawings Settings")
MenuXerath.Dt:boolean("DQ", "Draw [Q]", true)
MenuXerath.Dt:boolean("DW", "Draw [W]", true)
MenuXerath.Dt:boolean("DE", "Draw [E]", true)
MenuXerath.Dt:boolean("DR", "Draw [R]", true)
--
local function UpBuff()
    if CheckBuff(player, "XerathArcanopulseChargeUp") then
        q.QCharge = true
    else
        q.QCharge = false
    end 
    if CheckBuff(player, "XerathLocusOfPower2") then
        r.RCharge = true
    else
        r.RCharge = false
    end 
end 
--
local function CheckQ()
    if q.QCharge == true then
        orb.core.set_pause_attack(math.huge)
    else 
        orb.core.set_pause_attack(0)
    end 
end 

local function CheckR()
    if r.RCharge == true then
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

local function OnProcessSpell(spell)
    if player:spellSlot(2).state == 0 then
		local champ = spell.owner
		if champ.team == TEAM_ENEMY then
			local slot = spell.slot
			if player.pos:dist(champ.pos) <= e.Range then
				if spell.name == "SummonerTeleport" then
					player:castSpell("pos", 2, spell.owner.pos)
				else
					local spells = spellsToSilence[champ.charName]
					if spells then
						for i = 1, #spells do
							if slot == spells[i] then
								player:castSpell("pos", 2, spell.owner.pos)
								break
							end
						end
					end
				end
			end
		end
    end
    if spell.owner.type == TYPE_HERO and spell.owner.team == TEAM_ALLY and spell.owner.charName == "Xerath" and spell.name == "XerathLocusPulse" then
        if r.RStacks > 0 then
            r.RStacks = r.RStacks - 1
        end 
    end 
end 

local function DrawDamages(target)
    local thedmg = 0
	if target.isVisible and not target.isDead then
        local pos = graphics.world_to_screen(target.pos)
        local thedmg =  RealDamageR(target)
		graphics.draw_line_2D(pos.x, pos.y - 30, pos.x + 30, pos.y - 80, 1, graphics.argb(255, 150, 255, 200), 100)
		graphics.draw_line_2D(pos.x + 30, pos.y - 80, pos.x + 50, pos.y - 80, 1, graphics.argb(255, 150, 255, 200), 100)
		graphics.draw_line_2D(pos.x + 50, pos.y - 85, pos.x + 50, pos.y - 75, 1, graphics.argb(255, 150, 255, 200), 100)
		graphics.draw_text_2D(tostring(math.floor(thedmg)) .. " (" .. tostring(math.floor(thedmg / target.health * 100)) .. "%)", 20, pos.x + 55, pos.y - 80, graphics.argb(255, 150, 255, 200), 100)
	end
end

local function QRange(time)
	local RangeQ = q.MaxRange - q.MinRange
	local MinRangeSpell = q.MinRange
	local AlcanceLocal = RangeQ / 1.4 * time + MinRangeSpell
    if AlcanceLocal > q.MaxRange then 
        AlcanceLocal = q.MaxRange 
    end
	return AlcanceLocal
end

local function IsCombo(target)
    if IsReady(0) and MenuXerath.Qc.CQ:get() then
        local TempoCang = game.time - q.TimeQ
        local range = QRange(TempoCang)
        if ValidTargetRange(target, range - 150) then
            if q.QCharge == false then
                player:castSpell("pos", 0, target.pos)
            end  
        end   
        if q.QCharge == true then
            if ValidTargetRange(target, range - 150) then
                local Qpred = pred.linear.get_prediction(PredQ, target)
                if not Qpred then return end
                if not pred.collision.get_prediction(PredQ, Qpred, target) then
                    player:castSpell("release", 0, vec3(Qpred.endPos.x, game.mousePos.y, Qpred.endPos.y))
                end 
            end 
        end 
    end
    if IsReady(1) and MenuXerath.Wc.CW:get() then
        if player.pos:dist(target.pos) <= w.Range then
            local rpred = pred.circular.get_prediction(PredW, target)
            if not rpred then return end
            local pred_pos = vec3(rpred.endPos.x, target.pos.y, rpred.endPos.y)
            player:castSpell("pos", 1, pred_pos)
        end 
    end 
    if player.pos:dist(target.pos) <= e.Range then
        local Epred = pred.linear.get_prediction(PredE, target)
        if not Epred then return end
        if not pred.collision.get_prediction(PredE, Epred, target) then
            player:castSpell("pos", 2, vec3(Epred.endPos.x, game.mousePos.y, Epred.endPos.y))
        end 
    end
end 

local function CanCastR(target)
    if ValidTargetRange(target, 6000) and r.RCharge == false then
        player:castSpell("self", 3)
    end 
end 

local TimeDelayR = 0
local function OnTick()
    CheckQ()
    CheckR()
    UpBuff()
    --
    local buff, time = CheckBuff(player, "XerathArcanopulseChargeUp")
	if buff then
		q.TimeQ = time
    end
    --
    if player:spellSlot(3).level == 1 then
        r.Range = 3520   
    elseif player:spellSlot(3).level == 2 then
        r.Range = 4840   
    elseif player:spellSlot(3).level == 3 then 
        r.Range = 6160  
    end
    if player:spellSlot(3).level == 1 then
        r.RStacks = 3   
    elseif player:spellSlot(3).level == 2 then
        r.RStacks = 4   
    elseif player:spellSlot(3).level == 3 then 
        r.RStacks = 5  
    else
        r.RStacks = 0
    end 
    if (orb.combat.is_active()) then 
        local target = TargetSelecton(1500)
        if target and IsValidTarget(target) then
            IsCombo(target) 
        end 
    end
    if (MenuXerath.Rc.ACR:get()) then
        local target = TargetSelecton()
        if target and IsValidTarget(target) then
            CanCastR(target)
        end
    end 
    local target = TargetSelecton(6000)
    if target and IsValidTarget(target) then
        if r.RCharge == true and RealDamageR(target) >= target.health then
            if player.pos:dist(target.pos) <= 6000 then
                local RpRED = pred.circular.get_prediction(PredR, target)
                if not RpRED then return end
                player:castSpell("pos", 3, vec3(RpRED.endPos.x, target.pos.y, RpRED.endPos.y))  
                TimeDelayR = game.time
            end
        end 
    end 
end 

local function OnDraw()
    if IsValidTarget(player) then
        if player.isVisible and player.isOnScreen and not player.isDead then
            if IsReady(0) and MenuXerath.Dt.DQ:get() then
                local TempoCang = game.time - q.TimeQ
                local range = QRange(TempoCang)
                graphics.draw_circle(player.pos, range, 2, graphics.argb(255, 255, 0, 255), 100)
            end
            if IsReady(1) and MenuXerath.Dt.DW:get() then
                graphics.draw_circle(player.pos, w.Range, 2, graphics.argb(255, 255, 204, 255), 100)
            end
            if IsReady(2) and MenuXerath.Dt.DE:get()  then
                graphics.draw_circle(player.pos, e.Range, 2, graphics.argb(255, 255, 204, 255), 100)
            end 
            if IsReady(3) and MenuXerath.Dt.DR:get() then
                graphics.draw_circle(player.pos, r.Range, 2, graphics.argb(255, 255, 204, 255), 100)
            end  
            local target = TargetSelecton(6000)
            if target and IsValidTarget(target) then 
                DrawDamages(target)
            end    
        end
    end 
end 

orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.draw, OnDraw)
cb.add(cb.spell, OnProcessSpell)