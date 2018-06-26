local avada_lib = module.lib('avada_lib')
local orb = module.internal("orb");
local evade = module.internal("evade");
local pred = module.internal("pred");
local ts = module.internal('TS');
local common = avada_lib.common

--Spell
local spellQ = {
	range = 300
}

local spellW = { 
    stacks = 0
}

local spellE = {
    range = 700
}

local spellR = {
    range = 1000
}

local Invisible = false

--[[local interruptspells = { "glacialstorm"; "caitlynaceinthehole";
 "ezrealtrueshotbarrage";
 "drain";
 "crowstorm";
 "gragasw";
 "reapthewhirlwind";
 "karthusfallenone";
 "katarinar";
 "lucianr";
 "luxmalicecannon";
 "malzaharr";
 "meditate";
 "missfortunebullettime";
 "absolutezero";
 "pantheonrjump";
 "shenr";
 "gate";
 "varusq";
 "warwickr";
 "xerathlocusofpower2";
}]]

local menu = menu("Nicky [Vayne]", "Vayne: By Nicky")

menu:menu("combo", "Combo")
menu.combo:dropdown("Qmode", "AA Reset Mode: ", 1, {"GetSmartTumblePos", "GetKitingTumblePos"})
menu.combo:slider("DistanceAA", "Distance AA", 300, 0, 300, 1)
menu.combo:boolean("QC", "Use Q in Combo", true)
menu.combo:boolean("EC", "Use Auto Condemn", true)
menu.combo:boolean("RC", "Use R in Combo", true)
menu.combo:slider("Rhitenemy", "Min. Enemies to Use", 3, 1, 5, 1)
menu:menu("drawin", "Draws")
menu.drawin:boolean("pas", "Drawing Passive [Range]", true)
menu:menu("chave", "Key [Vayne]")
menu.chave:keybind("CK", "[Key] Combo", "Space", nil)


local function targets(res, obj, dist)
	if dist > 1000 then return end
	res.obj = obj
	return true
end

local function obtermeta()
	return ts.get_result(targets).obj
end

local function WStacks(args)
	if args.buff["vaynesilvereddebuff"] then
		spellW.stacks = args.buff["vaynesilvereddebuff"].stacks
	end
	return spellW.stacks
end

local function GetDistanceSqr(Pos1, Pos2)
	if Pos1 == nil or Pos2 == nil then
		return math.huge
    end
	local Pos2 = Pos2 or vec3(player.pos)
	local dx = Pos1.x - Pos2.x
	local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
	return dx * dx + dz * dz
end

local function GetDistance(one, two)
    if (not one or not two) then
        return math.huge
    end
    return one:dist(two)
end

local function count_enemies_in_range(pos, range) -- ty Kornis Thank you for allowing your code
	local enemies_in_range = {}
	for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
		if pos:dist(enemy.pos) < range and common.IsValidTarget(enemy) then
			enemies_in_range[#enemies_in_range + 1] = enemy
		end
	end
	return enemies_in_range
end

local function OnUpdateBuff(buff)
    if buff.name == "vaynetumblefade" then
        Invisible = true
    end 
end 

local function OnRemoveBuff(buff)
    if buff.name == "vaynetumblefade" then
        Invisible = false
    end 
end 

--[[local function StayInvisible()	
	if Invisible == false or #count_enemies_in_range(player.pos, 350) == 0 then
		orb.core.set_pause_attack(math.huge)
		return
	end

    local inimigo = common.GetEnemyHeroes()
    for i, v in ipairs(inimigo) do
        local GetAttackRange = player.attackRange 
    	if GetAttackRange < 400 and player.pos:dist(target.pos) == 350 then
    		orb.core.set_pause_attack(0)
    		return
    	end
    end
end]]

local function IsDangerousPosition(unit)
--    if UnderTower(unit) then return true end
    local inimigo = common.GetEnemyHeroes()
    for i, v in ipairs(inimigo) do
    	if not v.isDead and v.team == TEAM_ENEMY and unit:distSqr(v) < 300 * 300 then return true end
    end
   	return false
end

local function GetKitingTumblePos(target)
    local possiblePos = player.pos:ext(game.mousePos, 300)   
    if not IsDangerousPosition(possiblePos) and GetDistance(target.pos, possiblePos) > GetDistance(target.pos) then return possiblePos end
end

local function GetSmartTumblePos(target)
	local possiblePos = player.pos:ext(game.mousePos, 300) or vec3(0,0,0)
	local points= {
	[1] = player.pos + vec3(300,0,0),
	[2] = player.pos + vec3(277,0,114),
	[3] = player.pos + vec3(212,0,212),
	[4] = player.pos + vec3(114,0,277),
	[5] = player.pos + vec3(0,0,300),
	[6] = player.pos + vec3(-114,0,277),
	[7] = player.pos + vec3(-212,0,212),
	[8] = player.pos + vec3(-277,0,114),
	[9] = player.pos + vec3(-300,0,0),
	[10] = player.pos + vec3(-277,0,-114),
	[11] = player.pos + vec3(-212,0,-212),
	[12] = player.pos + vec3(-114,0,-277),
	[13] = player.pos + vec3(0,0,-300),
	[14] = player.pos + vec3(114,0,-277),
	[15] = player.pos + vec3(212,0,-212),
	[16] = player.pos + vec3(277,0,-114)}
	
	for i=1,#points do		
		if IsDangerousPosition(points[i]) == false and points[i]:distSqr(target) < 500 * 500 then
			if (navmesh.isWall(target.pos:ext(player.pos, -450))) then 
				return points[i]
			end 
		end
	end

	if IsDangerousPosition(possiblePos) == false then
		return possiblePos
	end

	
	for i=1,#points do
		if IsDangerousPosition(points[i]) == false and points[i]:distSqr(target) < 500 * 500  then 
			return points[i]
		end
	end	
	return nil
end

local function GetAggressiveTumblePos(target)
    --local mousePos = vec3(game.mousePos)
    --local targetPos = vec3(target)
    if target.pos:dist(game.mousePos) < target.pos:dist(player.pos) then return game.mousePos end
end


local function OnTick()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        
    --if orb.combat.target then
        if target and target.isVisible and menu.combo.EC:get() and player.pos:dist(target.pos) <= 700 then
            local enemiesCount = #count_enemies_in_range(player.pos, 1200)
            if 	enemiesCount > 1 and enemiesCount <= 3 then
                for i= 15, 450, 75 do
                   local vector3 = target.pos:ext(player.pos, -i)
                    if navmesh.isWall(vector3) then
                        player:castSpell("obj", 2, target)
                    end
                end
            else
                if (navmesh.isWall(target.pos:ext(player.pos, -450)) or navmesh.isWall(target.pos:ext(player.pos, -450/2)) or navmesh.isWall(target.pos:ext(player.pos, -450/3))) then
                    local hitchance = 50 / 100
                    local targetPos = target.pos + (target.pos - player.pos):norm() * target.moveSpeed * hitchance * 0.5     
                    for i = 15, 450, 75 do
                        local col1 = targetPos + (targetPos - player.pos):norm() * i
                        local col2 = target.pos + (target.pos - player.pos):norm() * i
                        if navmesh.isWall(col1) and navmesh.isWall(col2) then
                            player:castSpell("obj", 2, target)
                        end 
                    end 
                end 
            end 
        end 
    end
    local target = obtermeta();
    if not target then return end
    if orb.combat.target and menu.chave.CK:get() then
        if #count_enemies_in_range(player.pos, spellR.range) >= menu.combo.Rhitenemy:get() then
            player:castSpell("pos", 3, player.pos)
        end 
    end 
    local target = obtermeta();
	if not target then return end
    if menu.combo.Qmode:get() == 2 and orb.combat.target and menu.chave.CK:get() then
    	local range = menu.combo.DistanceAA:get() + player.attackRange + (player.boundingRadius + target.boundingRadius)
        if target.pos:dist(player.pos) <= range then
            player:castSpell("pos", 0, game.mousePos)
        end 
    end  
    local target = obtermeta();
    if not target then return end    
    if #count_enemies_in_range(player.pos, player.attackRange) > 1 then
        player:castSpell("obj", 2, target)
    end   
    local target = obtermeta();
	if not target then return end
    if player:spellSlot(2).state ~= 0 then return end
    if orb.combat.target then
        local QIsRange = player.attackRange + (player.boundingRadius + target.boundingRadius)
        if player.pos:dist(target.pos) < QIsRange and target.isDashing then
            player:castSpell("obj", 2, target)
        end 
    end 
   -- StayInvisible()
   --AggressiveTrumble()
end 

local function IsWRange()
    local AA = 250 
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        local AARange = player.attackRange + (player.boundingRadius + target.boundingRadius)
        if target and target.isVisible and player.pos:dist(target.pos) > AARange and menu.chave.CK:get() then
            if (WStacks(target) == 1 or WStacks(target) == 2) then
                player:castSpell("pos", 0, game.mousePos)
            end 
        end 
    end 
end 

local function OnDraw()
    if player.isOnScreen then
        if menu.drawin.pas:get() then
            graphics.draw_circle(player.pos, 2000, 2, graphics.argb(255, 150, 255, 200), 100)
        end 
    end 
end 

-------
--Spells Target--
-------
local function OnPreAttack()
    local target = obtermeta();
	if not target then return end
	local QRange = player.attackRange + target.boundingRadius
    if menu.combo.Qmode:get() == 1 and orb.combat.target then
        if player.pos:dist(target.pos) < QRange then
            local Qpos = GetSmartTumblePos(target)
            --if Qpos ~= nil then
                player:castSpell("pos", 0, vec3(Qpos.x, Qpos.y, Qpos.z))
                orb.combat.set_invoke_after_attack(false)
           --end 
        end
    end 
end 
    
---------
--Logic--
---------
local function IsCondemnable(target) 
    if (navmesh.isWall(target.pos:ext(player.pos, -450)) or navmesh.isWall(target.pos:ext(player.pos, -450/2)) or navmesh.isWall(target.pos:ext(player.pos, -450/3))) then
        local hitchance = 50 / 100
        target.pos = eP + (target.pos - player):norm() * target.moveSpeed * hitchance * 0.5     
        for i = 15, pD, 75 do
            local col1 = target.pos + (target.pos - pP):norm() * i
            local col2 = eP + (eP - pP):norm() * i
            if navmesh.isWall(col1) and navmesh.isWall(col2) then return true end
        end        
    end
end

---------
--Spells--
---------

---------
--Call--
---------
cb.add(cb.draw, OnDraw)
orb.combat.register_f_after_attack(OnPreAttack)
orb.combat.register_f_pre_tick(OnTick)
orb.combat.register_f_out_of_range(IsWRange)
cb.add(cb.updatebuff, OnUpdateBuff)
cb.add(cb.removebuff, OnRemoveBuff)
