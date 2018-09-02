
--Update
local gpred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local EvadeInternal = module.seek("evade")
local libss = module.load("NickyKhazix", "libss")
local minionmanager = objManager.minions

local function ST(res, obj, Distancia)
    if Distancia < 1000 then 
        res.obj = obj
        return true
    end 
end

local function GetTargetSelector()
	return ts.get_result(ST).obj
end

local QlvlDmg = {50, 75, 100, 125, 150}
local WlvlDmg = {85, 115, 145, 165, 205}
local ElvlDmg = {65, 100, 135, 170, 205}
local IsoDmg = {14, 22, 30, 38, 46, 54, 62, 70, 78, 86, 94, 102, 110, 118, 126, 134, 142, 150}
local QRange, ERange = 0, 0
local Isolated = false

local PredE = { delay = 0.25, radius = 300, speed = 1500, boundingRadiusMod = 0, collision = { hero = false, minion = false } }
local PredW = { delay = 0.25, width = 70, speed = 1700, boundingRadiusMod = 1, collision = { hero = true, minion = true } }

local MenuBarata = menu("KZ", "[Nicky]Kha'Zix")
	MenuBarata:header("script", "[Nicky]Kha'Zix")
	--Combo
	MenuBarata:menu("combo", "Combo Settings")
		MenuBarata.combo:header("xd1", "Q Settings")
		MenuBarata.combo:boolean("q", "Use Q", true)
		MenuBarata.combo:header("xd2", "W Settings")
		MenuBarata.combo:boolean("w", "Use W", true)
		MenuBarata.combo:header("xd3", "E Settings")
		MenuBarata.combo:boolean("e", "Use E in Combo", true)
		MenuBarata.combo:dropdown("ed", "E Mode", 2, {"Mouse Pos", "With Prediction"})
		MenuBarata.combo:header("xd4", "R Settings")
		MenuBarata.combo:boolean("r", "Use R", true)
		MenuBarata.combo:dropdown("rm", "Ultimate Mode: ", 2, {"Always Ultimate", "Smart Ultimate"})

	MenuBarata:menu("harass", "Harass Settings")
		MenuBarata.harass:header("xd5", "Harass Settings")
		MenuBarata.harass:boolean("q", "Use Q", true)
		MenuBarata.harass:boolean("w", "Use W", true)
		MenuBarata.harass:slider("Mana", "Min. Mana Percent: ", 10, 0, 100, 10)

	MenuBarata:menu("jg", "Jungle Clear Settings")
		MenuBarata.jg:header("xd6", "Jungle Settings")
		MenuBarata.jg:boolean("q", "Use Q", true)
		MenuBarata.jg:boolean("w", "Use W", true)

	MenuBarata:menu("auto", "Automatic Settings")
		MenuBarata.auto:header("xd8", "KillSteal Settings")
		MenuBarata.auto:boolean("uks", "Use Smart Killsteal", true)
		MenuBarata.auto:boolean("ukse", "Use E in Killsteal", false)
        MenuBarata.auto:slider("mhp", "Min. HP to E: ", 30, 0, 100, 10)
        
    MenuBarata:menu("keys", "[Key] Settings")
		MenuBarata.keys:header("xd7", "Where The Magic Happens")
		MenuBarata.keys:keybind("combo", "Combo Key", "Space", false)
		MenuBarata.keys:keybind("harass", "Harass Key", "C", false)
		MenuBarata.keys:keybind("clear", "Clear Key", "V", false)
		MenuBarata.keys:keybind("run", "Flee [Run]", "Z", false)

	MenuBarata:menu("draws", "Draw Settings")
		MenuBarata.draws:header("xd9", "Drawing Options")
		MenuBarata.draws:boolean("q", "Draw Q Range", true)
		MenuBarata.draws:boolean("e", "Draw E Range", true)


local function GetPercentHealth(obj)
    local obj = obj or player
    return (obj.health / obj.maxHealth) * 100
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
	return false
end 
	
local function IsValidTarget(object)
	return (object and not object.isDead and object.isVisible and object.isTargetable and not CheckBuffType(object, 17))
end

local function PhysicalReduction(target, damageSource)
	local damageSource = damageSource or player
	local armor = ((target.bonusArmor * damageSource.percentBonusArmorPenetration) + (target.armor - target.bonusArmor)) * damageSource.percentArmorPenetration
	local lethality = (damageSource.physicalLethality * .4) + ((damageSource.physicalLethality * .6) * (damageSource.levelRef / 18))
	return armor >= 0 and (100 / (100 + (armor - lethality))) or (2 - (100 / (100 - (armor - lethality))))
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
	  
local function CalculatePhysicalDamage(target, damage, damageSource)
	local damageSource = damageSource or player
	if target then
		return (damage * PhysicalReduction(target, damageSource)) * DamageReduction("AD", target, damageSource)
	end
	return 0
end

local function GetBonusAD(obj)
	local obj = obj or player
	return ((obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod) - obj.baseAttackDamage
end 

local function qDmg(target)
  local damage = QlvlDmg[player:spellSlot(0).level] + (GetBonusAD() * 1.3)
  	if Isolated then
    	damage = damage + damage
  	end
  	return CalculatePhysicalDamage(target, damage)
end

local function wDmg(target)
    local damage = WlvlDmg[player:spellSlot(1).level] + (GetBonusAD() * 1)
    return CalculatePhysicalDamage(target, damage)
end

local function eDmg(target)
	local damage = ElvlDmg[player:spellSlot(2).level] + (GetBonusAD() * 0.2)
	return CalculatePhysicalDamage(target, damage)
end

local function CastE(target)
	if player:spellSlot(2).state == 0 then
		if player:spellSlot(2).name == "KhazixE" then
			local res = gpred.circular.get_prediction(PredE, target)
			if res and res.startPos:dist(res.endPos) < 600 and res.startPos:dist(res.endPos) > 325  then
				player:castSpell("pos", 2, vec3(res.endPos.x, game.mousePos.y, res.endPos.y))
			end
		elseif player:spellSlot(2).name == "KhazixELong" then
			local res = gpred.circular.get_prediction(PredE, target)
			if res and res.startPos:dist(res.endPos) < 900 and res.startPos:dist(res.endPos) > 400 then
				player:castSpell("pos", 2, vec3(res.endPos.x, game.mousePos.y, res.endPos.y))
			end
		end
	end
end

local function CastW(target)
	if player:spellSlot(1).state == 0 then
		local seg = gpred.linear.get_prediction(PredW, target)
		if seg and seg.startPos:dist(seg.endPos) < 970 then
			if not gpred.collision.get_prediction(PredW, seg, target) then
				player:castSpell("pos", 1, vec3(seg.endPos.x, game.mousePos.y, seg.endPos.y))
			end
		end
	end
end

local function CastR()
	if player:spellSlot(3).state == 0 then
		player:castSpell("self", 3)
	end
end

local function CastQ(target)
	if player:spellSlot(0).state == 0 then
		if player:spellSlot(0).name == "KhazixQ" then
			if target.pos:dist(player.pos) <= 325 then
				player:castSpell("obj", 0, target)
			end
		elseif player:spellSlot(0).name == "KhazixQLong" then
			if target.pos:dist(player.pos) then
				player:castSpell("obj", 0, target)
			end
		end
	end
end

local function PlayerAD()
	if Isolated == false then
    	return player.flatPhysicalDamageMod + player.baseAttackDamage
    else
    	return player.flatPhysicalDamageMod + player.baseAttackDamage + (IsoDmg[player.levelRef] + player.flatPhysicalDamageMod * .2 )
    end
end

local function KillSteal()
	for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
		if not enemy.isDead and enemy.isVisible and enemy.isTargetable and MenuBarata.auto.uks:get() then
			local hp = enemy.health;
			if hp == 0 then return end
			if player:spellSlot(0).state == 0 and qDmg(enemy) + PlayerAD() > hp and enemy.pos:dist(player.pos) < 325 then
				CastQ(enemy);
			elseif player:spellSlot(1).state == 0 and wDmg(enemy) > hp and enemy.pos:dist(player.pos) < 960 then
				CastW(enemy);
			elseif player:spellSlot(1).state == 0 and player:spellSlot(0).state == 0 and wDmg(enemy) + qDmg(enemy) > hp and enemy.pos:dist(player.pos) < 500 then
				CastQ(enemy)
				CastW(enemy)
			elseif player:spellSlot(2).state == 0 and player:spellSlot(0).state == 0 and qDmg(enemy) + eDmg(enemy) + PlayerAD() > hp and MenuBarata.auto.ukse:get() and GetPercentHealth(player) >= MenuBarata.auto.mhp:get() and enemy.pos:dist(player.pos) < 990 then
				CastE(enemy)
				CastQ(enemy)
			elseif player:spellSlot(1).state == 0 and player:spellSlot(0).state == 0 and player:spellSlot(2).state == 0 and qDmg(enemy) + eDmg(enemy) + wDmg(enemy) + PlayerAD() > hp and MenuBarata.auto.ukse:get() and GetPercentHealth(player) >= MenuBarata.auto.mhp:get() and enemy.pos:dist(player.pos) < 990 then
				CastE(enemy)
				CastQ(enemy)
				if enemy.pos:dist(player.pos) <= 700 then
					CastW(enemy)
				end
			end
		end
	end
end

local function Combo()
	local target = GetTargetSelector()
	if target and IsValidTarget(target) then
		if MenuBarata.combo.e:get() then
			if MenuBarata.combo.ed:get() == 1 then
				if player:spellSlot(2).state == 0 and target.pos:dist(player.pos) <= 700 then
					libss.DelayAction(function()player:castSpell("pos", 2, (game.mousePos)) end, 0.2)
				end
			elseif MenuBarata.combo.ed:get() == 2 then
				CastE(target)
			end
		end
		if MenuBarata.combo.q:get() then
			CastQ(target)
		end
		if MenuBarata.combo.w:get() and target.pos:dist(player.pos) >= 470 then
			CastW(target)
		elseif MenuBarata.combo.w:get() and Isolated == true or player:spellSlot(0).state ~= 0 then
			CastW(target)
		end
		if MenuBarata.combo.r:get() and player:spellSlot(3).state == 0 then
			if MenuBarata.combo.rm:get() == 2 then
				if player:spellSlot(1).state == 0 and player:spellSlot(0).state == 0 and player:spellSlot(2).state == 0 and target.health <= ((qDmg(target)*2) + wDmg(target) + eDmg(target)) and target.health > (wDmg(target) + eDmg(target)) then
	                if target.pos:dist(player.pos) <= 900 then
	                    if player:spellSlot(2).state == 0 then CastR() end
	                end
	            end
	        elseif MenuBarata.combo.rm:get() == 1 then
	            if target.pos:dist(player.pos) <= 500 then 
	                if player:spellSlot(2).state == 0 then CastR() end
	            end
	        end
		end
	end
end

local function Harass()
	local target = GetTargetSelector()
	if target and IsValidTarget(target) then
		if MenuBarata.keys.harass:get() then
			if player.par / player.maxPar * 100 >= MenuBarata.harass.Mana:get() then
				if MenuBarata.harass.q:get() then
					CastQ(target)
				end
				if MenuBarata.harass.w:get() then
					CastW(target)
				end
			end
		end
	end
end

local function Clear()
	local target = { obj = nil, health = 0, mode = "jungleclear" }
	local aaRange = player.attackRange + player.boundingRadius + 200
	for i = 0, minionmanager.size[TEAM_NEUTRAL] - 1 do
		local obj = minionmanager[TEAM_NEUTRAL][i]
		if player.pos:dist(obj.pos) <= aaRange and obj.maxHealth > target.health then
			target.obj = obj
			target.health = obj.maxHealth
		end
	end
	if target.obj then
		if target.mode == "jungleclear" then
			if MenuBarata.jg.q:get() and player:spellSlot(0).state == 0 then
				player:castSpell("obj", 0, target.obj)
			end
			if MenuBarata.jg.w:get() and player:spellSlot(1).state == 0 then
				CastW(target.obj)
			end
		end
	end
end


local function Run()
	if MenuBarata.keys.run:get() then
		player:move((game.mousePos))
		if player:spellSlot(2).state == 0 then
			player:castSpell("pos", 2, (game.mousePos))
		end
	end
end

local function Evoluir()
    if player:spellSlot(0).name == "KhazixQ" then
        QRange = 325
    elseif player:spellSlot(0).name == "KhazixQLong" then
    	QRange = 375
    end 
    if player:spellSlot(2).name == "KhazixE" then
        ERange = 700
    elseif player:spellSlot(2).name == "KhazixELong" then
    	ERange = 900
    end 
end

local function ObjCreat(obj)
    if obj and obj.name and obj.type then
        if obj.name:find("SingleEnemy_Indicator") then
            Isolated = true
        end
    end
end

local function ObjDelete(obj)
    if obj and obj.name and obj.type then
    	if obj.name:find("SingleEnemy_Indicator") then
            Isolated = false
        end
    end
end

local function OnTick()
	KillSteal()
    if orb.combat.is_active() then 
        Combo() 
    end
    if orb.menu.hybrid:get() then 
        Harass() 
    end
    if MenuBarata.keys.run:get() then 
        Run() 
    end
    if MenuBarata.draws.q:get() or MenuBarata.draws.e:get() then 
        Evoluir() 
    end
	if orb.menu.lane_clear:get() then
		Clear()
	end
end

local function OnDraw()
	if MenuBarata.draws.q:get() and player:spellSlot(0).state == 0 and player.isOnScreen then
		graphics.draw_circle(player.pos, QRange, 2, graphics.argb(255, 168, 0, 157), 50)
	end
	if MenuBarata.draws.e:get() and player:spellSlot(2).state == 0 and player.isOnScreen then
		graphics.draw_circle(player.pos, ERange, 2, graphics.argb(255, 0, 21, 255), 50)
	end
end

orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.create_particle, ObjCreat)
cb.add(cb.delete_particle, ObjDelete)
cb.add(cb.draw, OnDraw)
