local pred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local evade = module.seek("evade")

--Spells
local q = { Range = { 600, 625, 650, 675, 700 }, minicon = false }
local w = { Range = 1450 }
local e = { Range = 900 }
local r = { Range = 5000}
--Pred
local PredR = { delay = 0.7; width = 140; speed = 1500; boundingRadiusMod = 1; collision = { hero = true, minion = false };}
local PredW = { delay = 0.6; width = 55; speed = 3200;  boundingRadiusMod = 1; collision = { hero = true, minion = true };}
local PredE = { delay = 1.2; radius = 50; speed = 1600;boundingRadiusMod = 1;}

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
local function PysicalDamage(unit)
    local armor = ((unit.bonusArmor * player.percentBonusArmorPenetration) + (unit.armor - unit.bonusArmor)) * player.percentArmorPenetration
    local lethality = (player.physicalLethality * .4) + ((player.physicalLethality * .6) * (player.levelRef / 18))
    return armor >= 0 and (100 / (100 + (armor - lethality))) or (2 - (100 / (100 - (armor - lethality))))
end
--Damage [R]
local r_scale = {250,350, 400}
local r_pct_scale = {0.25, 0.28, 0.35}
local function r_damage(unit)
    local dmg = r_scale[player:spellSlot(3).level] or 0;
    local pct_dmg = r_pct_scale[player:spellSlot(3).level] or 0;
    local mod = (((player.baseAttackDamage + player.flatPhysicalDamageMod) * player.percentPhysicalDamageMod) - player.baseAttackDamage) * 1.5;
    local missing_hp = unit.maxHealth - unit.health;
    local hp_mod = missing_hp * pct_dmg;
    return (dmg + mod + hp_mod) * PysicalDamage(unit);
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

local function IsReady(spell)
    return player:spellSlot(spell).state == 0
end 

local MenuJinx = menu("NickyJinx", "Nicky [Jinx]")
MenuJinx:menu("Qc", "[Q] Settings")
MenuJinx.Qc:boolean("autoQ", "Combo [Q]", true)
MenuJinx.Qc:boolean("QHarass", "Harass [Q]", true)
MenuJinx.Qc:boolean("farmqout", "Farm out range [AA]", true)
MenuJinx.Qc:boolean("LCQ", "LaneClear [Q]", true)
MenuJinx.Qc:slider('Qmana', "Mana [Q] farm", 60, 0, 100, 5)

MenuJinx:menu("Wc", "[W] Settings")
MenuJinx.Wc:boolean("autoW", "Combo [W]", true)
MenuJinx.Wc:boolean("WHarass", "Harass [W]", true)
MenuJinx.Wc:boolean("menu_Combo_farmQout", "Auto [W] End Dash", true)
MenuJinx.Wc:boolean("WKS", "Auto [W] Kill Steal", true)

MenuJinx:menu("Ec", "[E] Settings")
MenuJinx.Ec:boolean("autoE", "Auto [E] on CC", true)
MenuJinx.Ec:boolean("EComb", "Auto [E] in Combo BETA", true)
MenuJinx.Ec:boolean("EEnds", "Auto [E] End Dash", true)
MenuJinx.Ec:boolean("AutoInter", "Auto [E] Teleport", true)

MenuJinx:menu("Rc", "[R] Settings")
MenuJinx.Rc:boolean("autoR", "Auto [R]", true)
MenuJinx.Rc:boolean("LRC", "Logic [R]", true)

MenuJinx:menu("Dt", "Drawings Settings")
MenuJinx.Dt:boolean("DW", "Draw [W]", true)
MenuJinx.Dt:boolean("DE", "Draw [E]", true)

MenuJinx:menu("Keys", "Keys [Jinx]")
MenuJinx.Keys:keybind("ComK", "[Key] Combo", "Space", nil)
MenuJinx.Keys:keybind("ComV", "[Key] Lane", "V", nil)


local function OnDraw()
    local target = TargetSelecton(1500)
    if target and IsValidTarget(target) then
        if player.isVisible and player.isOnScreen and not player.isDead then
            graphics.draw_circle(target.pos, 80, 2, graphics.argb(255, 255, 204, 255), 100)
        end 
    end 
    if IsValidTarget(player) then
        if IsReady(0) and minicon == true then
            local extended_range = q.Range[player:spellSlot(0).level] + 65
            graphics.draw_circle(player.pos, extended_range, 2, graphics.argb(255, 0, 255, 233), 100)
        end 

        if player:spellSlot(2).state == 0 and MenuJinx.Dt.DE:get() then
            graphics.draw_circle(player.pos, e.Range, 2, graphics.argb(255, 255, 255, 255), 100)
        end 
        if player:spellSlot(1).state == 0 and MenuJinx.Dt.DW:get() then
            graphics.draw_circle(player.pos, w.Range, 2, graphics.argb(255, 255, 255, 255), 100)
        end 
    end 
end 


local function OnUpdateBuffed()
    if CheckBuff(player, "JinxQ") then
        minicon = true
    else 
        minicon = false
    end 
end 

local function IsCombo(target)
    local extended_range = q.Range[player:spellSlot(0).level] + 65 
    if MenuJinx.Qc.autoQ:get() and ValidTargetRange(target, extended_range) then
        if minicon == false and (player.pos:dist(target.pos) > GetAARange(player) or #CountEnemyChampAroundObject(target.pos, 250) > 2) and player.mana > 150 then
            player:castSpell("self", 0)
        else
            if minicon == true and player.pos:dist(target.pos) <= 525 then
                player:castSpell("self", 0)
            end
        end
    end
    --
    if MenuJinx.Wc.autoW:get() and player:spellSlot(1).state == 0 and ValidTargetRange(target, w.Range) and player.pos:dist(target.pos) > player.attackRange then
        local wpred = pred.linear.get_prediction(PredW, target)
        if not wpred then return end
        if not pred.collision.get_prediction(PredW, wpred, target) then
            player:castSpell("pos", 1,  vec3(wpred.endPos.x, game.mousePos.y, wpred.endPos.y))
        end 
    end 
    --
    if MenuJinx.Ec.autoE:get() and player:spellSlot(2).state == 0 and ValidTargetRange(target, e.Range) and IsLogicE(target) then
        local EpRed = pred.circular.get_prediction(PredE, target)
        player:castSpell("pos", 2,  vec3(EpRed.endPos.x, game.mousePos.y, EpRed.endPos.y))
    else 
        if player:spellSlot(2).state == 0 and ValidTargetRange(target, e.Range) then
            if IsImmobileTarget(target) then
                local EpRed = pred.circular.get_prediction(PredE, target)
                player:castSpell("pos", 2,  vec3(EpRed.endPos.x, game.mousePos.y, EpRed.endPos.y))
            end 
        end 
    end 
    --
end 

local function AutoR()
    local target = TargetSelecton(5000)
    if target and IsValidTarget(target) then
        local extended_range = q.Range[player:spellSlot(0).level] + 65
        if ValidTargetRange(target, 5000) and ValidUlt(target) then
            if r_damage(target) > target.health and player.pos:dist(target.pos) > extended_range then
                if #CountEnemyChampAroundObject(player.pos, 350) == 0 and #CountAllyChampAroundObject(target.pos, 500) == 0  then
                    local rpred = pred.linear.get_prediction(PredR, target)
                    if not rpred then return end
                    if not pred.collision.get_prediction(PredR, rpred, target) then
                        player:castSpell("pos", 3, vec3(rpred.endPos.x, rpred.endPos.y, rpred.endPos.y))
                    end
                end 
            end 
        end 
    end 
end 

local function OnTick()
    AutoR()
    --[[for i = 0, player.buffManager.count - 1 do
        local buff = player.buffManager:get(i)
        if buff and buff.valid then
            print("Resolve ".. buff.name)
        end 
    end jinxqicon ]]
    OnUpdateBuffed()
    --
    if (orb.combat.is_active()) then 
        local target = TargetSelecton(1500)
        if target and IsValidTarget(target) then
            IsCombo(target) 
            
        end 
    end
    --AutoRelod
    if minicon == true then
        if #CountEnemyChampAroundObject(player.pos, 1000) == 0 then
            player:castSpell("self", 0)
        end 
    end 

end 

orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.draw, OnDraw)