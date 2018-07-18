local avada_lib = module.lib("avada_lib")
if not avada_lib then
  console.set_color(12)
  print("Avada Lib missing... Please download and place into your 'community_libs' folder!\nYou can find it here:")
  console.set_color(11)
  print("https://gitlab.soontm.net/get_clear_zip.php?fn=avada_lib")
  console.set_color(15)
  return
elseif avada_lib.version < 1.06 then
  console.set_color(12)
  print("Your Avada Lib is outdated.. Please download the updated version from here:")
  console.set_color(11)
  print("https://gitlab.soontm.net/get_clear_zip.php?fn=avada_lib")
  console.set_color(15)
  return
end

local orb = module.internal("orb")
local pred = module.internal("pred")
local common = avada_lib.common
local dmglib = avada_lib.damageLib
--local NickyJinx = { }

local function CountEnemyChampAroundObject(pos, range) -- ty Kornis Thank you for allowing your code
	local enemies_in_range = {}
	for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
		if pos:dist(enemy.pos) < range and common.IsValidTarget(enemy) then
			enemies_in_range[#enemies_in_range + 1] = enemy
		end
	end
	return enemies_in_range
end

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

local function GetDamageR(target)
    if target ~= 0 then
        local Damage = 0
        local DamageAP = {250, 350, 450}
        local BonusAD = {25, 30, 35}
        if player:spellSlot(3).state == 0 then
            Damage = (DamageAP[player:spellSlot(3).level] + BonusAD/100 * (target.maxHealth - target.health) + 1.5 * player.bonusSpellBlock)
        end
		return common.damage(target, Damage)
    end
end 

local function PysicalDamage(unit)
    local armor = ((unit.bonusArmor * player.percentBonusArmorPenetration) + (unit.armor - unit.bonusArmor)) * player.percentArmorPenetration
    local lethality = (player.physicalLethality * .4) + ((player.physicalLethality * .6) * (player.levelRef / 18))
    return armor >= 0 and (100 / (100 + (armor - lethality))) or (2 - (100 / (100 - (armor - lethality))))
end
local r_scale = {250,350,450};
local r_pct_scale = {0.25, 0.30, 0.35}
local function r_damage(unit)
    local dmg = r_scale[player:spellSlot(3).level] or 0;
    local pct_dmg = r_pct_scale[player:spellSlot(3).level] or 0;
    local mod = (((player.baseAttackDamage + player.flatPhysicalDamageMod) * player.percentPhysicalDamageMod) - player.baseAttackDamage) * 1.5;
    local missing_hp = unit.maxHealth - unit.health;
    local hp_mod = missing_hp * pct_dmg;
    return (dmg + mod + hp_mod) * PysicalDamage(unit);
end 

local function IsValidTarget(unit, range)
    return unit and unit.isVisible and not unit.isDead and (not range or GetDistance(unit) <= range)
end

local function GetTrueAttackRange()
    return player.attackRange + player.collisionRadius + player.boundingRadius
end 

local function ValidUlt(unit)
	if (common.HasBuffType(unit, 16) or common.HasBuffType(unit, 15) or common.HasBuffType(unit, 17) or unit.buff["kindredrnodeathbuff"] or common.HasBuffType(unit, 4)) then
		return false
	end
	return true
end

local function IsImmobileTarget(unit)
	if (common.HasBuffType(unit, 5) or common.HasBuffType(unit, 11) or common.HasBuffType(unit, 29) or common.HasBuffType(unit, 24) or common.HasBuffType(unit, 10) or common.HasBuffType(unit, 29))  then
		return true
	end
	return false
end

local function CanMove(unit)
	if (unit.moveSpeed < 50 or common.HasBuffType(unit, 5) or common.HasBuffType(unit, 21) or common.HasBuffType(unit, 11) or common.HasBuffType(unit, 29) or
		unit.buff["recall"] or common.HasBuffType(unit, 30) or common.HasBuffType(unit, 22) or common.HasBuffType(unit, 8) or common.HasBuffType(unit, 24)
		or common.HasBuffType(unit, 20) or common.HasBuffType(unit, 18)) then
		return false
	end
	return true
end

local function FishBoneActive()
	if player.buff["jinxq"] then
		return true;
	else
		return false;
	end
	return false;
end

local function bonusRange()
	return (player.attackRange + player.boundingRadius + 25 * player:spellSlot(0).level)
end

local function GetRealPowPowRange(target)
	return (620 + player.boundingRadius + target.boundingRadius)
end

local function GetRealDistance(target)
	local targetPos = vec3(target.x, target.y, target.z)
	return (GetDistance(targetPos) + player.boundingRadius + target.boundingRadius)
end

--Objetivo:
local myLastPath = vec3(0,0,0)
local targetLastPath = vec3(0,0,0)
local WCastTime = 0
local grabTime = 0
local IsMovingInSameDirection = false
local GrapAntiPos = nil 

--Menu
local MenuJinx = menu("NickyJinx", "Nicky [Jinx]")
MenuJinx:menu("Qc", "[Q] Settings")
MenuJinx.Qc:boolean("autoQ", "Auto [Q]", true)
MenuJinx.Qc:boolean("QHarass", "Harass [Q]", true)
MenuJinx.Qc:boolean("farmqout", "Farm out range [AA]", true)
MenuJinx.Qc:boolean("LCQ", "LaneClear [Q]", true)
MenuJinx.Qc:slider('Qmana', "Mana [Q] farm", 60, 0, 100, 5)

MenuJinx:menu("Wc", "[W] Settings")
MenuJinx.Wc:boolean("autoW", "Auto [W]", true)
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


local Q = { Range = player.attackRange }
local W = { Range = 1450, Delay = 0.6, Speed = 3200, Width = 60}
local E = { Range = 900, Delay = 1.2, Speed = 1600, Width = 50 }
local R = { Range = 6000, Delay = 0.7, Speed = 1500, Width = 140 }
--Pred
local PredR = { delay = 0.7; width = 140; speed = 1500; boundingRadiusMod = 1; collision = { hero = true, minion = false };}
local PredW = { delay = 0.6; width = 55; speed = 3200;  boundingRadiusMod = 1; collision = { hero = true, minion = true };}
local PredE = { delay = 1.2; radius = 50; speed = 1600;boundingRadiusMod = 1;}


local function LogicQ()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and not target.isDead then
            if IsValidTarget(target, bonusRange() + 60) then 
                if not FishBoneActive() and (GetDistance(target) > player.attackRange or #CountEnemyChampAroundObject(target.pos, 250) > 2) then
                    local distance = GetRealDistance(target)
                    if MenuJinx.Keys.ComK:get() and player.mana > 150 then
                         player:castSpell("self", 0)
                    elseif FishBoneActive() and GetDistance(target) <= player.attackRange  then
                        player:castSpell("self", 0)
                    elseif not FishBoneActive() and MenuJinx.Keys.ComK:get() and player.mana > 150 and #CountEnemyChampAroundObject(player.pos, 2000) > 2 then
                        player:castSpell("self", 0)
                    elseif FishBoneActive() and MenuJinx.Keys.ComK:get() and player.mana < 150 then
                        player:castSpell("self", 0)
                    elseif FishBoneActive() and MenuJinx.Keys.ComK:get() and #CountEnemyChampAroundObject(player.pos, 2000) == 0 then
                        player:castSpell("self", 0)
                    end 
                end
            end 
        end     
    end      
end 

local function LogicW()
    if #CountEnemyChampAroundObject(player.pos, bonusRange()) == 0 then
        if MenuJinx.Keys.ComK:get() and player.mana > 150 and IsValidTarget(target, W.Range - 150) then
            local inimigo = common.GetEnemyHeroes()
            for i, target in ipairs(inimigo) do
                if target and target.isVisible and not target.isDead then
                    if GetRealDistance(target) > player.attackRange then
                        local wpred = pred.linear.get_prediction(PredW, target)
                        if not wpred then return end
                        if not pred.collision.get_prediction(PredW, wpred, target) then
                            player:castSpell("pos", 1,  vec3(wpred.endPos.x, game.mousePos.y, wpred.endPos.y))
                        end 
                    end 
                end 
            end 
        end 
    end 
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and not target.isDead then
            if IsValidTarget(target, W.Range - 150) and GetDistance(target) > bonusRange() then
				if ValidUlt(target) then
                    local wpred = pred.linear.get_prediction(PredW, target)
                    if not pred.collision.get_prediction(PredW, wpred, target) then
                        player:castSpell("pos", 1,  vec3(wpred.endPos.x, game.mousePos.y, wpred.endPos.y))
                    end 
				end
			end
            if IsValidTarget(target, W.Range - 150) and not CanMove(target) then
                local wpred = pred.linear.get_prediction(PredW, target)
                if not wpred then return end
                if not pred.collision.get_prediction(PredW, wpred, target) then
                    player:castSpell("pos", 1,  vec3(wpred.endPos.x, game.mousePos.y, wpred.endPos.y))
                end
			end
		end
	end
end 

local function LogicE()
    if (player.mana > 150 and os.clock() - grabTime > 1) then
        local inimigo = common.GetEnemyHeroes()
        for i, target in ipairs(inimigo) do
			if IsValidTarget(target, E.Range + 50) then
				if IsValidTarget(target, E.Range - 100) then
                    if not CanMove(target) then
                        local EpRed = pred.circular.get_prediction(PredE, target)
						player:castSpell("pos", 2,  vec3(EpRed.endPos.x, game.mousePos.y, EpRed.endPos.y))
						return
					end
				end
			end
		end
		if MenuJinx.Ec.AutoInter:get() then
			if GetTrapPos ~= nil then
				player:castSpell("pos", 2,  vec3(GetTrapPos.x, GetTrapPos.y, GetTrapPos.z))
			end
		end
    end
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and not target.isDead then
            if common.HasBuffType(target, 10) then
                local EpRed = pred.circular.get_prediction(PredE, target)
                player:castSpell("pos", 2,  vec3(EpRed.endPos.x, game.mousePos.y, EpRed.endPos.y))
            end 
        end 
    end                      
end 

local function LogicR()
	if os.clock() - WCastTime > 0.9 then
        local inimigo = common.GetEnemyHeroes()
        for i, target in ipairs(inimigo) do
            if target and target.isVisible and not target.isDead then
				if IsValidTarget(target, R.Range) then
					if r_damage(target) > target.health and GetRealDistance(target) > bonusRange() + 200 then
                        local rpred = pred.linear.get_prediction(PredR, target)
                        if not rpred then return end
                        if not pred.collision.get_prediction(PredR, rpred, target) and GetRealDistance(target) > bonusRange() + 300 + target.boundingRadius and #CountEnemyChampAroundObject(player.pos, 400) == 0 and #common.GetAllyHeroesInRange(500, target.pos) < 1 then
                            player:castSpell("pos",3,  vec3(rpred.endPos.x, rpred.endPos.y, rpred.endPos.y))
						elseif #CountEnemyChampAroundObject(target.pos, 200) > 2 then
							player:castSpell("pos",3,  vec3(rpred.endPos.x, rpred.endPos.y, rpred.endPos.y))
						end
					end
				end
			end
		end
	end
end 

local function OnTick()
    if player.isDead then return end 
    if FishBoneActive() and #CountEnemyChampAroundObject(player.pos, 1000) == 0 then
        player:castSpell("self", 0)
    end 
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and not target.isDead then
            if FishBoneActive() and GetDistance(target) <= player.attackRange and MenuJinx.Keys.ComK:get() then
                player:castSpell("self", 0)
            end 
        end 
    end 

    if player:spellSlot(0).state == 0 and MenuJinx.Qc.autoQ:get() and MenuJinx.Keys.ComK:get() then
        LogicQ()
    end 
    if player:spellSlot(1).state == 0 and MenuJinx.Wc.autoW:get() and MenuJinx.Keys.ComK:get() then
        LogicW()
    end 
    if player:spellSlot(2).state == 0 and MenuJinx.Ec.autoE:get() and MenuJinx.Keys.ComK:get() then
        LogicE()
    end 
    if player:spellSlot(3).state == 0 and MenuJinx.Rc.autoR:get() then
        LogicR()
    end 
end 

local function OnProcess(spell)
    local spellName = spell.name:lower()

    if spell and spell.owner and spell.owner.ptr == player.ptr and spell.name then
        if spellName == "jinxwmissile" then
    		WCastTime = os.clock()
        end
    end 
    if spell and spell.owner and spell.owner.ptr == player.ptr and spell.name and spellName == "RocketGrab" then
        local inimigo = common.GetEnemyHeroes()
        for i, target in ipairs(inimigo) do
            if GetDistance(target) < E.Range then
                grabTime = os.clock()
            end 
        end   
    end
end 

--[[local function OnNewPath(unit, startPos, endPos)
    if player then
		myLastPath = endPos
    end
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if unit.networkID == target.networkID then
			targetLastPath = endPos
        end
    end 
    if myLastPath ~= vec3(0,0,0) and targetLastPath ~= vec3(0,0,0) then
		local myHeroPos = player.pos
		local getAngle = mathf.angle_between(myHeroPos, myLastPath, targetLastPath)
		if(getAngle < 20) then
            IsMovingInSameDirection = true;
        else
            IsMovingInSameDirection = false;
        end
	end
end ]]

local function OnDen()
    if player.isVisible and player.isOnScreen and not player.isDead then
        if player:spellSlot(1).state == 0 and MenuJinx.Dt.DW:get() then
            graphics.draw_circle(player.pos, W.Range, 2, graphics.argb(255, 255, 204, 255), 100)
        end 
        if FishBoneActive() then
            graphics.draw_circle(player.pos, bonusRange(), 2, graphics.argb(255, 255, 204, 255), 100)
        end 

        if player:spellSlot(2).state == 0 and MenuJinx.Dt.DE:get() then
            graphics.draw_circle(player.pos, E.Range, 2, graphics.argb(255, 255, 255, 255), 100)
        end 
    end
end

local function OnObj(obj)
    local objPos = vec3(0,0,0)
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and not target.isDead then
            targetPos = vec3(target.x, target.y, target.z)
            if GetDistance(objPos) < E.Range and obj.isVisible then
                if string.find(obj.name, "GateMarker_red.troy") or string.find(obj.name, "global_ss_teleport_target_red.troy") or
					string.find(obj.name, "r_indicator_red.troy") or (string.find(obj.name, "LifeAura.troy") and target.isVisible and GetDistance(objPos, targetPos) < 200) then
                    GrapAntiPos = objPos
				else
					GrapAntiPos = nil
				end
            end
        end 
    end 
end

cb.add(cb.draw, OnDen)
orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.createobj, OnObj)
cb.add(cb.spell, OnProcess)
--cb.add(cb.path, OnNewPath)