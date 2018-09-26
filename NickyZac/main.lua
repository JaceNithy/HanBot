local pred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local evade = module.seek("evade")
local ObjMinion_Type = objManager.minions

local q = { Range = 800 }
local w = { Range = 350 }
local e = { Range = 0, ECharge = false, TimeE = 0, TimeEnd = 0}
local r = { Range = 0, RCharge = false, TimeR = 0}

local PredQ = { delay = 0.7; width = 140; speed = 1500; boundingRadiusMod = 1; collision = { hero = true, minion = true };}
local PredE = { delay = 0.9; radius = 150; speed = 1100; boundingRadiusMod = 1;}

local function GetAARange(target)
    return player.attackRange + player.boundingRadius + (target and target.boundingRadius or 0)
end

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
local MZac = menu("[Nicky]Zac", "[Nicky]Zac")
MZac:menu("Qc", "[Q] Settings")
MZac.Qc:boolean("CQ", "Combo [Q]", true)
MZac.Qc:boolean("QLane", "Jungle [Q]", true)
MZac.Qc:boolean("farmqout", "Farm out range [AA]", true)
MZac.Qc:boolean("LCQ", "Champion + Collision [Q2]", true)
--
MZac:menu("Wc", "[W] Settings")
MZac.Wc:boolean("CW", "Combo [W]", true)
MZac.Wc:boolean("LaneW", "Jungle [W]", true)
--
MZac:menu("Ec", "[E] Settings")
MZac.Ec:boolean("CE", "Combo [E]", true)
MZac.Ec:boolean("LaneE", "Lane [E]", true)
--
MZac:menu("Rc", "[R] Settings")
MZac.Rc:header("xd8", "[R] does not work at the moment")
MZac.Rc:boolean("CR", "Combo [R]", false)
MZac.Rc:dropdown("MR", "Ultimate Mode: ", 2, {"Allied Direction", "MousePos"})

MZac:menu("Dt", "Drawings Settings")
MZac.Dt:boolean("DQ", "Draw [Q]", true)
MZac.Dt:boolean("DW", "Draw [W]", true)
MZac.Dt:boolean("DE", "Draw [E]", true)
MZac.Dt:boolean("DR", "Draw [R]", true)


local function CheckE()
    if e.ECharge == true then
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

local function CheckBuffE()
   --[[] if player then
        for i = 0, player.buffManager.count - 1 do
            local buff = player.buffManager:get(i)
            if buff and buff.valid and buff.owner == player then
                print(buff.name) --ZacE
            end 
        end 
    end 
    return false]]
    --
    if CheckBuff(player, "ZacE") then
        e.ECharge = true
    else
        e.ECharge = false
    end 
end 

local function ERange(tempo)
    local rangediff = e.Range - 400
	local miniomorange = 400
	local AlcanceT = rangediff / 0.9 * tempo + miniomorange
    if AlcanceT > e.Range then 
        AlcanceT = e.Range
    end
	return AlcanceT
end

local function RRange(tempo)
    local rangediff = r.Range - 400
	local miniomorange = 400
	local AlcanceT = rangediff / 1.0 * tempo + miniomorange
    if AlcanceT > r.Range then 
        AlcanceT = r.Range
    end
	return AlcanceT
end

local function IsCombo(target)
    if IsReady(0) and e.ECharge == false and MZac.Qc.CQ:get() then
        if player.pos:dist(target.pos) <= q.Range then
            local Qpred = pred.linear.get_prediction(PredQ, target)
            if not Qpred then return end
            if not pred.collision.get_prediction(PredQ, Qpred, target) then
                player:castSpell("pos", 0, vec3(Qpred.endPos.x, Qpred.endPos.y, Qpred.endPos.y))
            end
        end
    else 
        if CheckBuff(target, "zacqempowered") and ValidTargetRange(target, 1000) then
            for i = 0, ObjMinion_Type.size[TEAM_ENEMY] - 1 do
                local binion = ObjMinion_Type[TEAM_ENEMY][i]
                if binion and IsValidTarget(binion) then
                    if player.pos:dist(binion.pos) <= GetAARange(player) then
                        player.pos:attack(binion.pos)
                    end 
                end 
            end 
        elseif CheckBuff(target, "zacqempowered") and ValidTargetRange(target, 1000) then
            for i = 0, ObjMinion_Type.size[TEAM_NEUTRAL] - 1 do
                local binionJungle = ObjMinion_Type[TEAM_NEUTRAL][i]
                if binionJungle and IsValidTarget(binionJungle) then
                    if player.pos:dist(binionJungle.pos) <= GetAARange(player) then
                        player.pos:attack(binionJungle.pos)
                    end 
                end 
            end 
        end
    end
    if IsReady(1) and MZac.Wc.CW:get() and e.ECharge == false then
        if player.pos:dist(target.pos) <= w.Range then
            player:castSpell("self", 1)
        end 
    end 
    if IsReady(2) and MZac.Ec.CE:get() then
        local TempoCang = game.time - e.TimeE
        local range = ERange(TempoCang)
        if ValidTargetRange(target, range) then
            if e.ECharge == false then
                player:castSpell("pos", 2, target.pos)
            end  
        end   
        if e.ECharge == true then
            if ValidTargetRange(target, range) then
                local rpred = pred.circular.get_prediction(PredE, target)
                if not rpred then return end
                local pred_pos = vec3(rpred.endPos.x, target.pos.y, rpred.endPos.y);
                player:castSpell("release", 2, pred_pos)  
            end 
        end 
    end
    if MZac.Rc.CR:get() and e.ECharge == false then
        local TempoChager = game.time - r.TimeR
        local ranger = RRange(TempoChager)
        if CheckBuff(player, "ZacR") and player.pos:dist(target.pos) <= ranger then
            if MZac.Rc.MR:get() == 1 and #CountAllyChampAroundObject(player.pos, 1200) > 0 then
                for i = 0, objManager.allies_n - 1 do
                    local aled = objManager.allies[i]
                    if aled and IsValidTarget(aled) then
                        player:castSpell("release", 3, aled.pos) 
                    end 
                end 
            end 
        elseif MZac.Rc.MR:get() == 2 and CheckBuff(player, "ZacR") then
            player:castSpell("release", 3, game.mousePos)
        end 
    end 
 
end 

local function Clear()
	for i = 0, ObjMinion_Type.size[TEAM_NEUTRAL] - 1 do
        local mobs = ObjMinion_Type[TEAM_NEUTRAL][i]
        if MZac.Qc.QLane:get() and player:spellSlot(0).state == 0 and e.ECharge == false then
            if player.pos:dist(mobs.pos) <= q.Range then
                player:castSpell("pos", 0, mobs.pos)
            end 
        end
        if MZac.Wc.LaneW:get() and player:spellSlot(1).state == 0 then
            if player.pos:dist(mobs.pos) <= w.Range then
                player:castSpell("self", 1)
            end 
        end
        if MZac.Ec.LaneE:get() and player:spellSlot(2).state == 0 then
            local TempoCang = game.time - e.TimeE
            local range = ERange(TempoCang)
            if ValidTargetRange(mobs, range) then
                if e.ECharge == false then
                    player:castSpell("pos", 2, mobs.pos)
                end  
            end   
            if e.ECharge == true then
                if ValidTargetRange(mobs, range) then
                    local rpred = pred.circular.get_prediction(PredE, mobs)
                    if not rpred then return end
                    local pred_pos = vec3(rpred.endPos.x, mobs.pos.y, rpred.endPos.y);
                    player:castSpell("release", 2, pred_pos)  
                end 
            end 
        end 
    end 
            
		
end 

local function OnTick()
    CheckE()
    CheckBuffE()
    local buff, time = CheckBuff(player, "ZacE")
	if buff then
		e.TimeE = time
    end
    --
    local buffR, timeR = CheckBuff(player, "ZacR")
	if buffR then
		r.TimeR = timeR
	end
    --E
    if player:spellSlot(2).level == 1 then
        e.Range = 1200 
    elseif player:spellSlot(2).level == 2 then
        e.Range = 1350 
    elseif player:spellSlot(2).level == 3 then
        e.Range = 1500 
    elseif player:spellSlot(2).level == 4 then
        e.Range = 1650 
    elseif player:spellSlot(2).level == 5 then
        e.Range = 1800 
    end 
    --R
    if player:spellSlot(3).level == 1 then
        r.Range = 700  
    elseif player:spellSlot(3).level == 2 then
        r.Range = 850  
    elseif player:spellSlot(3).level == 3 then -- zacqempowered
        r.Range = 1000 
    end --zacemove
    if (orb.combat.is_active()) then 
        local target = TargetSelecton(2000)
        if target and IsValidTarget(target) then
            IsCombo(target) 
        end 
    end
    if (orb.menu.lane_clear:get()) then
		Clear()
	end
end 

local function OnDraw()
    if IsValidTarget(player) then
        if player.isVisible and player.isOnScreen and not player.isDead then
            if IsReady(0) and MZac.Dt.DQ:get() then
                graphics.draw_circle(player.pos, q.Range, 2, graphics.argb(255, 255, 0, 255), 100)
            end
            if IsReady(1) and MZac.Dt.DW:get() then
                graphics.draw_circle(player.pos, w.Range, 2, graphics.argb(255, 255, 204, 255), 100)
            end
            if IsReady(2) and MZac.Dt.DE:get()  then
                local TempoCang = game.time - e.TimeE
                local range = ERange(TempoCang)
                graphics.draw_circle(player.pos, range, 2, graphics.argb(255, 255, 204, 255), 100)
            end 
            if IsReady(3) and MZac.Dt.DR:get() then
                graphics.draw_circle(player.pos, r.Range, 2, graphics.argb(255, 255, 204, 255), 100)
            end        
        end
    end 
end 

orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.draw, OnDraw)