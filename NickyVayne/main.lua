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

local spellE = {
	range = 700
}

local spellR = {
	range = 1000
}

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

local menu = menu("Nicky [Vayne]", "Vayne: By JaceNicky")

menu:menu("combo", "Combo")
menu.combo:dropdown("Qmode", "AA Reset Mode: ", 1, {"Mouse[Pos]", "Pos AA", "Aggressive AA"})
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

local function OnTick()
    local target = obtermeta();
	if not target then return end
    if player:spellSlot(2).state ~= 0 then return end
    if orb.combat.target then
        if menu.combo.EC:get() and player.pos:dist(target.pos) < 1000 then
            local enemiesCount = #count_enemies_in_range(player.pos, 1200)
            if 	enemiesCount > 1 and enemiesCount <= 3 then
                for i= 15, 450, 75 do
                   local vector3 = target.pos:ext(player.pos, -i)
                    if navmesh.isWall(vector3) then
                        return true
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
            player:castSpell("pos", 0, game.mousePos)
            orb.combat.set_invoke_after_attack(false)
        end
    end 
    if menu.combo.Qmode:get() == 3 and orb.combat.target then
        local QIsRange = player.attackRange + (player.boundingRadius + target.boundingRadius)
        local QisPred = { delay = 0.5, width = math.huge, speed = 1000, boundingRadiusMod = 1, collision = { hero = false, minion = false, }}
        local PredLinear = pred.linear.get_prediction(QisPred, target)
        if player.pos:dist(target.pos) < QIsRange then
            player:castSpell("pos", 0, vec3(PredLinear.endPos.x, game.mousePos.y, PredLinear.endPos.y))
            orb.combat.set_invoke_after_attack(false)
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
--[[local function InterSpell(spell)
    local spellDINTER = {};
    if not spell or not spell.name or not spell.owner then return end
	if spell.owner.isDead then return end
	if spell.owner.team == player.team then return end
	if player.pos:dist(spell.owner.pos) > player.attackRange + (player.boundingRadius + spell.owner.boundingRadius) then return end	

	for s = 0, #spells.interrupt.names do
		if (spells.interrupt.names[s] == string.lower(spell.name)) then
			spellDINTER.start = os.clock();
			spellDINTER.owner = spell.owner;
		end
	end
    if not spellDINTER.owner then return end
	if player.pos:dist(spellDINTER.owner.pos) > player.attackRange + (player.boundingRadius + spellDINTER.owner.boundingRadius) then return end
	
	if os.clock() - spellDINTER.channel >= spellDINTER.start then
		spellDINTER.owner = false;
		return
	end

	if os.clock() - 0.35 >= spellDINTER.start then
		player:castSpell("obj", 2, spellDINTER.owner);
		spellDINTER.owner = false;
	end
end ]]

---------
--Call--
---------
cb.add(cb.draw, OnDraw)
orb.combat.register_f_after_attack(OnPreAttack)
orb.combat.register_f_pre_tick(OnTick)