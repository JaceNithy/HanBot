--Vayne

local pred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local EvadeInternal = module.seek("evade")
local minionmanager = objManager.minions


local delayedActions, delayedActionsExecuter = {}, nil
local function DelayAction(func, delay, args) --delay in seconds
  if not delayedActionsExecuter then
    function delayedActionsExecuter()
      for t, funcs in pairs(delayedActions) do
        if t <= os.clock() then
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
  local t = os.clock() + (delay or 0)
  if delayedActions[t] then
    delayedActions[t][#delayedActions[t] + 1] = {func = func, args = args}
  else
    delayedActions[t] = {{func = func, args = args}}
  end
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

local function CheckBuff(obj, buffname)
    if obj then
        for i = 0, obj.buffManager.count - 1 do
            local buff = obj.buffManager:get(i)
            if buff and buff.valid and buff.name == buffname and buff.stacks == 1 then
                return true
            end 
        end 
    end     
end

local function GetPercentHealth(obj)
    local obj = obj or player
    return (obj.health / obj.maxHealth) * 100
end
  
local function GetPercentMana(obj)
    local obj = obj or player
    return (obj.mana / obj.maxMana) * 100
end
  
local function GetPercentPar(obj)
    local obj = obj or player
    return (obj.par / obj.maxPar) * 100
end
  

local interruptableSpells = {
	["anivia"] = {
		{menuslot = "R", slot = 3, spellname = "glacialstorm", channelduration = 6}
	},
	["caitlyn"] = {
		{menuslot = "R", slot = 3, spellname = "caitlynaceinthehole", channelduration = 1}
	},
	["ezreal"] = {
		{menuslot = "R", slot = 3, spellname = "ezrealtrueshotbarrage", channelduration = 1}
	},
	["fiddlesticks"] = {
		{menuslot = "W", slot = 1, spellname = "drain", channelduration = 5},
		{menuslot = "R", slot = 3, spellname = "crowstorm", channelduration = 1.5}
	},
	["gragas"] = {
		{menuslot = "W", slot = 1, spellname = "gragasw", channelduration = 0.75}
	},
	["janna"] = {
		{menuslot = "R", slot = 3, spellname = "reapthewhirlwind", channelduration = 3}
	},
	["karthus"] = {
		{menuslot = "R", slot = 3, spellname = "karthusfallenone", channelduration = 3}
	}, 
	["katarina"] = {
		{menuslot = "R", slot = 3, spellname = "katarinar", channelduration = 2.5}
	},
	["lucian"] = {
		{menuslot = "R", slot = 3, spellname = "lucianr", channelduration = 2}
	},
	["lux"] = {
		{menuslot = "R", slot = 3, spellname = "luxmalicecannon", channelduration = 0.5}
	},
	["malzahar"] = {
		{menuslot = "R", slot = 3, spellname = "malzaharr", channelduration = 2.5}
	},
	["masteryi"] = {
		{menuslot = "W", slot = 1, spellname = "meditate", channelduration = 4}
	},
	["missfortune"] = {
		{menuslot = "R", slot = 3, spellname = "missfortunebullettime", channelduration = 3}
	},
	["nunu"] = {
		{menuslot = "R", slot = 3, spellname = "absolutezero", channelduration = 3}
	},
	["pantheon"] = {
		{menuslot = "R", slot = 3, spellname = "pantheonrjump", channelduration = 2}
	},
	["shen"] = {
		{menuslot = "R", slot = 3, spellname = "shenr", channelduration = 3}
	},
	["twistedfate"] = {
		{menuslot = "R", slot = 3, spellname = "gate", channelduration = 1.5}
	},
	["varus"] = {
		{menuslot = "Q", slot = 0, spellname = "varusq", channelduration = 4}
	},
	["warwick"] = {
		{menuslot = "R", slot = 3, spellname = "warwickr", channelduration = 1.5}
	},
	["xerath"] = {
		{menuslot = "R", slot = 3, spellname = "xerathlocusofpower2", channelduration = 3}
	}
}

local function ST(res, obj, Distancia)
    if Distancia >= 1000 then 
        return true
    end 
    res.obj = obj
    return true
end

local function GetTargetSelector()
	return ts.get_result(ST).obj
end

local function Floor(number) 
    return math.floor((number) * 100) * 0.01
end


local FlashSlot = nil
if player:spellSlot(4).name == "SummonerFlash" then
	FlashSlot = 4
elseif player:spellSlot(5).name == "SummonerFlash" then
	FlashSlot = 5
end

local condemnTable = { }
local tumblePositions = { }
local  castPos = nil

local menu = menu("Nicky [Vayne]", "[Nicky]Vayne")
menu:menu("MQ", "Setting [Q]")
menu.MQ:header("XD", "Setting [Q]")
menu.MQ:boolean("QC", "Use Q in Combo", true)
menu.MQ:dropdown("AFO", "Use [Q]: ", 2, {"After Attack", "Pos Attack"})
menu.MQ:dropdown("Qmode", "AA Reset Mode: ", 2, {"Heroes Only", "Heroes + Jungle", "Always", "Never"})
menu.MQ:dropdown("Q2mode", "Tumble Logic: ", 1, {"Smart", "Aggressive"})
    --
menu:menu("MW", "Setting [W]")
menu.MW:header("XD2", "Setting [W]")
menu.MW:boolean("FW", "Force Marked Target", true)
    --
menu:menu("ME", "Setting [E]")
menu.ME:boolean("AutoCoondem", "Use Auto Condemn", true)
menu.ME:boolean("CF", "Use Auto Flash + Condemn", true)
menu.ME:boolean("ATE", "AutoInterrupt", false)
menu.ME:slider("CH", "Condemn Hitchance", 50, 0, 100, 1)
menu.MW:boolean("try", "Use To Proc Third Mark", false)

    --
menu:menu("MR", "Setting [R]")
menu.MR:boolean("RC", "Use R in Combo", true)
menu.MR:slider("Rhitenemy", "Min. Enemies to Use", 3, 1, 5, 1)

menu:menu("JC", "Setting [Jungle]")
menu.JC:boolean("QJ", "Use Q in Jungle", true)
menu.JC:boolean("AAE", "Use [E] Condemn", true)
menu.JC:slider("manaj", "Mana [Jungle]", 45, 0, 100, 1)

    --
menu:menu("Keys", "Setting [Keys]")
menu.Keys:keybind("CK", "[Key] Combo", "Space", nil)

local function ValidTarget(object)
    return (object and not object.isDead and object.isVisible and object.isTargetable and not CheckBuffType(object, 17))
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

local function IsValidTarget(unit, range)
    return unit and unit.isVisible and not unit.isDead and (not range or GetDistance(unit) <= range)
end


local function RotateAroundPoint(v1,v2, angle)
    cos, sin = math.cos(angle), math.sin(angle)
    x = ((v1.x - v2.x) * cos) - ((v2.z - v1.z) * sin) + v2.x
    z = ((v2.z - v1.z) * cos) + ((v1.x - v2.x) * sin) + v2.z
   return vec3(x, v1.y, z or 0)
end

local function GetWallPosition(target, range)
    range = range or 400
    for i= 0, 360, 45 do
        angle = i * math.pi/180
        targetPosition = target.pos
        targetRotated = vec3(targetPosition.x + range, targetPosition.y, targetPosition.z)
        Wallid = vec3(RotateAroundPoint(targetRotated, targetPosition, angle))

        if navmesh.isWall(Wallid) and GetDistance(Wallid) < range then
            return Wallid
        end
    end
end

local function FlashE()
    for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
        if ValidTarget(enemy) then
            if IsValidTarget(enemy, 700) and (FlashSlot and player:spellSlot(FlashSlot).state == 0) and player:spellSlot(2).state == 0  then
                targetPos = enemy.pos
                playerPos = player.pos
                wallPos = GetWallPosition(enemy, 400)
                
                if (wallPos) then
                    insecPos = targetPos + (targetPos - wallPos):norm() * 200
                    if insecPos:dist(playerPos) <= 425 then
                        --if  then
                            player:castSpell("obj", 2, enemy)
                            DelayAction(function() player:castSpell("pos", FlashSlot, insecPos) end, 0.1)
                        --end
                        
                    end 
                end 
            end 
        end 
    end 
end 

local function OnProcessSpell(spell)
    if menu.ME.ATE:get() then
        if spell.owner.type == TYPE_HERO and spell.owner.team == TEAM_ENEMY then -- <3 <3 <3 By Kornis <3 <3 <3 
            local enemyName = string.lower(spell.owner.charName)
            if interruptableSpells[enemyName] then
                for i = 1, #interruptableSpells[enemyName] do
                    if player.pos2D:dist(spell.owner.pos2D) < 700 and ValidTarget(spell.owner) and player:spellSlot(2).state == 0 then
                        player:castSpell("obj", 2, spell.owner)
                    end 
                end 
            end 
        end 
    end 
end 

local function Condemn(target)
    local pP = vec3(player.x, player.y, player.z) 
    local eP = vec3(target.x, target.y, target.z)
    local eP2 = target.pos 
    local pD = Floor(410)
    if (navmesh.isWall(eP:ext(pP,-pD)) or navmesh.isWall(eP:ext(pP, -pD/2)) or navmesh.isWall(eP:ext(pP, -pD/3))) then 
        local hitchance = 50 / 100
        eP2 = eP + (eP2 - eP):norm() * target.moveSpeed * hitchance * 0.5    
        for i = 15, pD, 75 do
            local col1 = eP2 + (eP2 - pP):norm() * i
            local col2 = eP + (eP - pP):norm() * i
            if navmesh.isWall(col1) and navmesh.isWall(col2) then 
                player:castSpell("obj", 2, target)
            end
        end        
    end
end



local function GetKitePosition(target)
    tumblePositions = {}
  
    for i = 0, 360, 22.5 do
      angle = i * (math.pi/180)
  
      myPos = player.pos
      tPos = target.pos
  
      rot = RotateAroundPoint(tPos, myPos, angle)
      pos = myPos + (myPos - rot):norm() * 300
  
       table.insert(tumblePositions, pos)
  
      if ValidTarget(target) then
        for i = 0, objManager.enemies_n - 1 do
            local target = objManager.enemies[i]
          dist = GetDistance(target, pos) / 2
          if (dist < 340 and dist > 200) then
             return pos end
           end
         else
            dist = GetDistance(vec3(target.x, target.y,  target.z), pos)
            if dist > 250 and dist < 380 then
            return pos end
          end
    end
    return nil
end

local function count_enemies_in_range(pos, range)
	local enemies_in_range = {}
	for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
		if pos:dist(enemy.pos) < range and IsValidTarget(enemy) then
			enemies_in_range[#enemies_in_range + 1] = enemy
		end
	end
	return enemies_in_range
end

local function count_allyes_in_range(pos, range)
	local allyes_in_range = {}
	for i = 0, objManager.allies_n - 1 do
        local allg = objManager.allies[i]
		if pos:dist(allg.pos) < range and IsValidTarget(allg) then
			allyes_in_range[#allyes_in_range + 1] = allg
		end
	end
	return allyes_in_range
end

local function dasdasdasda(target)
    local wallPos = GetWallPosition(target, 140)
    local qToEPos = GetWallPosition(target, 200)
    local kitePos = GetKitePosition(target)

    if GetPercentHealth(player) < 50 and GetPercentHealth(target) > 50 then
        local IspOS = player.pos + (target.pos - player.pos):norm() * -150
        player:castSpell("pos", 0, vec3(IspOS))
    elseif GetPercentHealth(player) > 50 and GetPercentHealth(target) < 50 then
        local IspOS2 = player.pos + (target.pos - player.pos):norm() * 150
        player:castSpell("pos", 0, vec3(IspOS2))
    elseif GetDistance(target) > player.attackRange then
        local IspOS32 = player.pos + (target.pos - player.pos):norm() * 150
        player:castSpell("pos", 0, vec3(IspOS32))
    elseif #count_enemies_in_range(player.pos, 1000) >= 2 then
        local ddddd = player.pos + (target.pos - player.pos):norm() * -150
        player:castSpell("pos", 0, vec3(ddddd))
    end
end

local function IsDangerousPosition(unit)
    for i = 0, objManager.enemies_n - 1 do
        local target = objManager.enemies[i]
        if not target.isDead and unit:distSqr(target) < 300 * 300 then 
            return true 
        end	
    end
   	return false
end

local function GetSmartTumblePos(target)
    local myHeroPos = player.pos
    local possiblePos = myHeroPos:ext(mousePos, 300) or vec3(0,0,0)
    local targetPos = vec3(target.x, target.y, target.z) or vec3(0,0,0)   
    local p0 = myHeroPos    
    local points= {
    [1] = p0 + vec3(300,0,0),
    [2] = p0 + vec3(277,0,114),
    [3] = p0 + vec3(212,0,212),
    [4] = p0 + vec3(114,0,277),
    [5] = p0 + vec3(0,0,300),
    [6] = p0 + vec3(-114,0,277),
    [7] = p0 + vec3(-212,0,212),
    [8] = p0 + vec3(-277,0,114),
    [9] = p0 + vec3(-300,0,0),
    [10] = p0 + vec3(-277,0,-114),
    [11] = p0 + vec3(-212,0,-212),
    [12] = p0 + vec3(-114,0,-277),
    [13] = p0 + vec3(0,0,-300),
    [14] = p0 + vec3(114,0,-277),
    [15] = p0 + vec3(212,0,-212),
    [16] = p0 + vec3(277,0,-114)}
    ---
    for i=1,#points do      
        if IsDangerousPosition(points[i]) == false and GetDistanceSqr(points[i], targetPos) < 500 * 500 then
            if (navmesh.isWall(targetPos:ext(myHeroPos, -450))) then 
                return points[i]
            end 
        end
    end
    if IsDangerousPosition(possiblePos) == false then
        return possiblePos
    end 
    for i=1,#points do
        if IsDangerousPosition(points[i]) == false and GetDistanceSqr(points[i], targetPos) < 500 * 500  then --and GetDistance(points[i],mousePos) <= GetDistance(bestPos, mousePos)
            return points[i]
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
		if target.mode == "jungleclear" and player.par / player.maxPar * 100 >= menu.JC.manaj:get() then
			if menu.JC.QJ:get() and player:spellSlot(0).state == 0 then
                local ddddd = player.pos + (target.obj.pos - player.pos):norm() * -150
                player:castSpell("pos", 0, vec3(ddddd))
        
			end
			if menu.JC.AAE:get() and player:spellSlot(2).state == 0 then
				Condemn(target.obj)
			end
		end
	end
end

local function CastQ(target, force)
    local castPos = nil

    local wallPos = GetWallPosition(target, 140)
    local qToEPos = GetWallPosition(target, 200)
    local kitePos = GetKitePosition(target)
    local playerPos = vec3(player.x, player.y, player.z)
    local mousePos = game.mousePos
    local final = playerPos:ext(mousePos, 500)
    local castPos = final

    if (kitePos) then
        if qToEPos and player:castSpell("obj", 2, target) and force then
            tPos = target.pos
            newPos = tPos + (tPos - qToEPos):norm() * 100
            if (GetDistance(newPos) < 300) then
                player:castSpell("pos", 0, newPos)
            end 
        end 
    end 
    if (wallPos) then
        if qToEPos and player:castSpell("obj", 2, target) and force then
            tPos = target.pos
            newPos = tPos + (tPos - qToEPos):norm() * 100
            if (GetDistance(newPos) < 300) then
                player:castSpell("pos", 0, newPos)
            end 
        end 
    end 
    if GetDistance(target) > player.attackRange + 70 then
        player:castSpell("pos", 0, target.pos)
    end 
    for i = 0, objManager.allies_n - 1 do
        local target = objManager.allies[i]
        if #count_enemies_in_range(player.pos, 1000) >= 2 then
            local ddddd = player.pos + (target.pos - player.pos):norm() * -150
            player:castSpell("pos", 0, vec3(ddddd))
        end
    end   
    if player:spellSlot(0).state == 0 then
        local tpos = GetSmartTumblePos(target)
        player:castSpell("pos", 0, tpos)
        orb.combat.set_invoke_after_attack(false)
    end

end

local function CastR(target)
    if GetDistance(target) <= 1000 and #count_enemies_in_range(player.pos, 1000) >= menu.MR.Rhitenemy:get() then
        player:castSpell("self", 3)
    end
end


local function Combo()
    local target = GetTargetSelector()
    if ValidTarget(target) then
        if menu.MQ.AFO:get() == 1 then
            CastQ(target, false)
        end
        Condemn(target) 
        CastR(target)    
    end
   
end

local function ComboIsReday()
    local target = GetTargetSelector()
    if ValidTarget(target) then
        if menu.MQ.AFO:get() == 2 then
            CastQ(target, false)
        end
        Condemn(target)     
    end
end

local function OnDraw() 

end

local function OnTick()
    if menu.ME.CF:get() then
        FlashE()
    end 
    if orb.combat.is_active() then 
        ComboIsReday() 
    end
end 

local function On_Load()
    if orb.menu.lane_clear:get() then
		Clear()
    end
    if orb.combat.is_active() then 
       Combo() 
    end
end 

orb.combat.register_f_pre_tick(OnTick)
orb.combat.register_f_after_attack(On_Load)
cb.add(cb.draw, OnDraw)
cb.add(cb.spell, OnProcessSpell)