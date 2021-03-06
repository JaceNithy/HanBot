--Katarina

local pred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local EvadeInternal = module.seek("evade")
local libss = module.load("NickyKatarina", "libss")


units = {}
units.towers, units.towerCount = {}, 0

local function find_place_and_insert(t, c, o, v)
    local dead_place = nil
    for i = 1, c do
      local tmp = t[i]
      if not v(tmp) then
        dead_place = i
        break
      end
    end
    if dead_place then
      t[dead_place] = o
    else
      c = c + 1
      t[c] = o
    end
    return c
end

local function valid_tower(tower)
    return tower and tower.type == TYPE_TURRET -- 9217
end

local function check_add_tower(o)
    if valid_tower(o) then
        units.towerCount = find_place_and_insert(units.towers, units.towerCount, o, valid_tower) 
    end
end

cb.add(cb.create_particle, check_add_tower)
objManager.loop(function(obj)check_add_tower(obj) end)

_enemyTowers = nil
local function GetEnemyTowers()
    if _enemyTowers then 
        return _enemyTowers 
    end
    _enemyTowers = {}
    for i = 1, units.towerCount do
        local obj = units.towers[i]
        if valid_tower(obj) and obj.team ~= TEAM_ALLY then
            _enemyTowers[#_enemyTowers + 1] = obj
        end 
    end 
    return _enemyTowers
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

local function CheckDance(obj, buffname)
    if obj then
      for i = 0, obj.buffManager.count - 1 do
        local buff = obj.buffManager:get(i)
  
        if buff and buff.valid and buff.name:find(buffname) and (buff.stacks > 0 or buff.stacks2 > 0) then
          return true
        end
      end
    end
  end

local function UnderTower(unit)
    enemyTowers = GetEnemyTowers()
    for i = 1, #enemyTowers do
		local tower = enemyTowers[i]
        if GetDistance(player, tower) < 800 + player.boundingRadius then
            if GetDistance(unit, tower) <= 800 + player.boundingRadius then 
                return true
            else
                return false
            end
        end
    end
end

local function EnemysInrange(pos, range) -- ty Kornis Thank you for allowing your code
	local enemies_in_range = {}
	for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
		if pos:dist(enemy.pos) < range and libss.IsValidTarget(enemy)  then
			enemies_in_range[#enemies_in_range + 1] = enemy
		end
	end
	return enemies_in_range
end

local function Floor(number) 
    return math.floor((number) * 100) * 0.01
end

local q = { Range = 625, Dagger = { }, DaggerStart = 0, DaggerEnd = 0, CoutD = 0 }
local w = { Range = 375, DaggerMis = { }, DaggerStartMis = 0, DaggerEndMis = 0 }
local e = { Range = 700 }
local r = { Range = 550, RCasting = false, TimeR = 0 }
local Posis = vec3(0,0,0)
local WPos = vec3(0,0,0)
local DaggerPosition = vec3(0,0,0)
local ComboNum = 0

local IgniteFlott = nil
if player:spellSlot(4).name == "SummonerDot" then
	IgniteFlott = 4
elseif player:spellSlot(5).name == "SummonerDot" then
	IgniteFlott = 5
end

local MenuKatarina = menu("Nicky [Katarina]", "Katarina:By Nicky")
--Combo
MenuKatarina:menu("kat", "Combo [Katarina]")
MenuKatarina.kat:dropdown("combomode", "Combo Mode: ", 3, {"Auto", "EWQR", "EQWR"})
MenuKatarina.kat:boolean("EAA", "Only use e if target is outside auto attack range", true)
MenuKatarina.kat:slider("CanOln", "Level CanCast [Only]", 6, 1, 18, 1)
MenuKatarina.kat:boolean("CQ", "Use [Q]", true)
MenuKatarina.kat:boolean("CW", "Use [W]", true)
MenuKatarina.kat:boolean("CE", "Use [E]", true)
MenuKatarina.kat:boolean("CR", "Use [R]", true)
--ModR
MenuKatarina.kat:dropdown("UR", "[R] Utility: ", 2, {"Always", "Killable", "Never"})
--Harass
---MenuKatarina:menu("katH", "Harass [Katarina]")
--MenuKatarina.katH:boolean("HQ", "Use [Q] Harass", true)
---MenuKatarina.katH:boolean("HE", "Use [E] Harass", true)
--Lane
MenuKatarina:menu("katL", "Lane [Katarina]")
MenuKatarina.katL:boolean("LQ", "Use [Q] Lane", true)
--MenuKatarina.katL:boolean("LE", "Use [E] Lane", true)
--Killable
MenuKatarina:menu("katK", "Killable [Katarina]")
MenuKatarina.katK:boolean("KQ", "Use [Q] Killable", true)
MenuKatarina.katK:boolean("KE", "Use [E] Killable", true)
--DaggerOps
MenuKatarina:menu("katD", "Dagger Options [Katarina]")
MenuKatarina.katD:boolean("EFE", "Use [E] Dagger", true)
MenuKatarina.katD:boolean("DG", "Only [E]", true)
--Draw
MenuKatarina:menu("katDra", "Drawing [Katarina]")
MenuKatarina.katDra:boolean("DQ", "Draw [Q]", true)
MenuKatarina.katDra:boolean("DE", "Draw [E]", true)
MenuKatarina.katDra:boolean("DD", "Draw [Dagger]", true)
--Keys
MenuKatarina:menu("katKeys", "Keys [Katarina]")
MenuKatarina.katKeys:keybind("CK", "Combo [Key]", "Space", nil)
MenuKatarina.katKeys:keybind("CL", "Lane [Key]", "V", nil)

local function ST(res, obj, Distancia)
    if Distancia < 1000 then 
        res.obj = obj
        return true
    end 
end

local function GetTargetSelector()
	return ts.get_result(ST).obj
end

local function ObjDagger(obj)
    if obj and obj.name then 
        if string.find(obj.name, "W_Indicator_Ally") then
            q.Dagger[obj.ptr] = obj 
            q.DaggerStart = game.time + Floor(1.25)
            q.DaggerEnd = game.time + Floor(5.1)
            q.CoutD = q.CoutD + 1
        end 
    end 
    if obj and obj.name then 
        if string.find(obj.name, "W_Mis") then
            w.DaggerMis[obj.ptr] = obj 
            w.DaggerStartMis = game.time + Floor(1.25)
            w.DaggerEndMis = game.time + Floor(5.1)
        end 
    end 
end

local function ObjDelete(obj)
    if obj and obj.name then 
        if string.find(obj.name, "W_Indicator_Ally") then
            q.Dagger[obj.ptr] = nil 
            q.DaggerStart = 0
            q.DaggerEnd = 0
            q.CoutD = q.CoutD - 1
        end 
    end 
    if obj and obj.name then 
        if string.find(obj.name, "W_Mis") then
            w.DaggerMis[obj.ptr] = nil 
            w.DaggerStartMis = 0
            w.DaggerEndMis = 0
        end 
    end
end 

local function CountAdaga()
	local count = 0
	for _ in pairs(q.Dagger) do
		count = count + 1
	end
	return count
end

local function DamageR(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {375, 562.5, 750}
        if player:spellSlot(3).state == 0 then
			Damage = (DamageAP[player:spellSlot(3).level] + 3.3 * player.bonusSpellBlock + 2.85 * player.flatMagicDamageMod)
        end
		return Damage
	end
	return 0
end

local function DamageE(target)
    if target ~= 0 then
		local Damage = 0
		local DamageSpell = {15, 30, 45, 60, 75}

        if player:spellSlot(2).state == 0 then
			Damage = (DamageSpell[player:spellSlot(2).level] + 0.50 * player.bonusSpellBlock + 0.25 * player.flatMagicDamageMod)
        end
		return Damage
	end
	return 0
end

local function DamageW()
    return 0
end 

local function DamageQ(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {75, 105, 135, 165, 195 }
        if player:spellSlot(0).state == 0 then
			Damage = (DamageAP[player:spellSlot(0).level] + 0.30 * player.flatMagicDamageMod)
        end
		return Damage
	end
	return 0
end 

local function Kat_GetHP(enemy)
end

--[[local function DrawLineHPBar(damage, text, unit, team)
    if unit.isDead or not unit.isVisible then 
        return 
    end
    local p = graphics.world_to_screen_xyz(unit.x, unit.y, unit.z)
    local thedmg = 0
    local line = 2
    local linePosA  = { x = 0, y = 0 }
    local linePosB  = { x = 0, y = 0 }
    local TextPos   = { x = 0, y = 0 }
  
    if damage >= unit.health then
      thedmg = unit.health - 1
      text = "KILLABLE!"
    else
      thedmg = damage
      text = "Possible Damage"
    end
  
    thedmg = Floor(thedmg)
  
    local StartPos = unit.barPos
    local Real_X = StartPos.x 
    local Offs_X = (Real_X + ((unit.health - thedmg) / unit.maxHealth) * (StartPos.x + 3))
    if Offs_X < Real_X then Offs_X = Real_X end 
    local mytrans = 350 - Floor(255*((unit.health-thedmg)/unit.maxHealth))
    if mytrans >= 255 then mytrans= 254 end
    local my_bluepart = Floor(400*((unit.health-thedmg)/unit.maxHealth))
    if my_bluepart >= 255 then my_bluepart=254 end
  
    if team then
      linePosA.x = Offs_X - 24
      linePosA.y = (StartPos.y-(30+(line*15)))    
      linePosB.x = Offs_X - 24 
      linePosB.y = (StartPos.y+10)
      TextPos.x = Offs_X - 20
      TextPos.y = (StartPos.y-(30+(line*15)))
    else
      linePosA.x = Offs_X-125
      linePosA.y = (StartPos.y-(30+(line*15)))    
      linePosB.x = Offs_X-125
      linePosB.y = (StartPos.y-15)
  
      TextPos.x = Offs_X-122
      TextPos.y = (StartPos.y-(30+(line*15)))
    end
  
    graphics.draw_line_2D(linePosA.x, linePosA.y, linePosB.x, linePosB.y , 2, graphics.argb(mytrans, 255, my_bluepart, 0))
    graphics.draw_text_2D(tostring(thedmg).." "..tostring(text), 15, TextPos.x, TextPos.y , graphics.argb(mytrans, 255, my_bluepart, 0))
end]]

local function HasRBuff()
    if RCasting == true then
        if (EvadeInternal) then
            EvadeInternal.core.set_pause(math.huge)
        end 
        orb.core.set_pause_move(math.huge)
        orb.core.set_pause_attack(math.huge)
    else 
        if (EvadeInternal) then
            EvadeInternal.core.set_pause(0)
        end 
        orb.core.set_pause_move(0)
        orb.core.set_pause_attack(0)
    end 
end 


local function OnDraw()
    if MenuKatarina.katDra.DQ:get() and player:spellSlot(0).state == 0 then
        graphics.draw_circle(player.pos, q.Range, 2, graphics.argb(255, 255, 204, 255), 100) 
    end 
    if MenuKatarina.katDra.DE:get() and player:spellSlot(2).state == 0 then
        graphics.draw_circle(player.pos, e.Range, 2, graphics.argb(255, 255, 255, 255), 100) 
    end 
    if MenuKatarina.katDra.DD:get() then
        if (q.CoutD > 0)  then
            for _, Adaga in pairs(q.Dagger) do
                if Adaga then
                    if player.isVisible and player.isOnScreen and not player.isDead then
                        if q.DaggerStart <= game.time  then
                            graphics.draw_circle(Adaga.pos, 350, 2, graphics.argb(255, 255, 0, 0), 100) 
                        end
                    end 
                end 
            end 
        end
    end 
end 

local function GetBestDaggerPoint(position, target)
    local targetPos = vec3(target.x, target.y, target.z)
    local positionPos = vec3(position.x, position.y, position.z)
    if GetDistanceSqr(targetPos, positionPos) <= 340 * 340 then
        return position
    end 
    return positionPos:ext(targetPos, 150)
end 

local function LogicDistance(position, target)
    local targetPos = vec3(target.x, target.y, target.z)
    local positionPos = vec3(position.x, position.y, position.z)
    if GetDistanceSqr(targetPos, positionPos) < 340 * 340 then
        return position
    end 
    return positionPos:ext(targetPos, 200) 
end 

local function LogicInstance(position, target)
    local targetPos = vec3(target.x, target.y, target.z)
    local positionPos = vec3(position.x, position.y, position.z)
    if GetDistanceSqr(targetPos, positionPos) < 340 * 340 then
        return position
    end 
    return positionPos:ext(targetPos, -50)
end 

local function ELogic(position, target)
    local targetPos = vec3(target.x, target.y, target.z)
    local positionPos = vec3(position.x, position.y, position.z)
    if GetDistanceSqr(targetPos, positionPos) < 340 * 340 then
        return position
    end 
    return positionPos:ext(targetPos, 50)
end

local function GetBestDaggerPoint(position, target)
    local targetPos = vec3(target.x, target.y, target.z)
    local positionPos = vec3(position.x, position.y, position.z)
    if GetDistanceSqr(targetPos, positionPos) < 340 * 340 then
        return position
    end 
    return positionPos:ext(targetPos, 150)
end 

local function GetBestDaggerPoint2(position, target)
    local targetPos = vec3(target.x, target.y, target.z)
    local positionPos = vec3(position.x, position.y, position.z)
    if GetDistanceSqr(targetPos, positionPos) >= 340 * 340 then
        return position
    end 
    return positionPos:ext(targetPos, 150)
end 
local TimeE = 0
local function CastE(target)
    if MenuKatarina.kat.EAA:get() and MenuKatarina.kat.CanOln:get() <= player.levelRef then
        if (q.CoutD == 0) and not HasRBuff() then
            local adasdasdasdas = player.pos + (target.pos - player.pos):norm() * 50 
            player:castSpell("pos", 2, target.pos)
        end 
    end 
    for _, Adaga in pairs(q.Dagger) do
        if Adaga then
            if q.DaggerStart <= game.time then
                local DaggerPos = Adaga.pos + (target.pos - Adaga.pos):norm() * 150
                local DaggerIsRange = Adaga.pos + (target.pos - Adaga.pos):norm() * 50
                local DaggerRange = Adaga.pos + (target.pos - Adaga.pos):norm() * -50
                local DaggerPos2 = Adaga.pos + (target.pos - Adaga.pos):norm() * -150
                if GetBestDaggerPoint(Adaga, target) and GetDistance(target, Adaga) <= 450 then
                   -- player:castSpell("pos", 2, vec3(DaggerPos))
                    libss.DelayAction(function() player:castSpell("pos", 2, vec3(DaggerPos)) end, 0.1)
                    --TimeE = game.time
                elseif LogicDistance(Adaga, target) and GetDistance(target, Adaga) <= 450 then
                    libss.DelayAction(function() player:castSpell("pos", 2, vec3(DaggerPos)) end, 0.1)
                elseif LogicInstance(Adaga, target) and GetDistance(target, Adaga) <= 450 then
                 --   player:castSpell("pos", 2, vec3(DaggerRange))
                    libss.DelayAction(function() player:castSpell("pos", 2, vec3(DaggerRange)) end, 0.1)
                elseif ELogic(Adaga, target) and GetDistance(target, Adaga) <= 450 then
                    --player:castSpell("pos", 2, vec3(DaggerIsRange))
                    libss.DelayAction(function() player:castSpell("pos", 2, vec3(DaggerIsRange)) end, 0.1)
                elseif LogicInstance(Adaga, target) and GetDistance(target, Adaga) <= 450 then
                    --player:castSpell("pos", 2, vec3(DaggerPos2))
                    libss.DelayAction(function() player:castSpell("pos", 2, vec3(DaggerPos2)) end, 0.1)
                end  
            end
        end 
    end 
end

local function CastW()
    if WPos then
        player:castSpell("self", 1)
        return player.Posis 
    end 
end 

local function CastQ(target)
    if GetDistance(target) <= 625 then
        player:castSpell("obj", 0, target)
    end 
    return q.Dagger[DaggerPosition]
end 

local function Combo1()
    for i = 0, objManager.enemies_n - 1 do
		local target = objManager.enemies[i]
        if not target.isDead and target.isVisible and target.isTargetable and libss.IsValidTarget(target) then
            if player:spellSlot(2).state == 0  and GetDistance(target) <= e.Range and not HasRBuff() then
                for _, Adaga in pairs(q.Dagger) do
                    if Adaga then
                        if q.DaggerStart <= game.time then
                            local DaggerPos = Adaga.pos + (target.pos - Adaga.pos):norm() * 200
                            if GetBestDaggerPoint(Adaga, target) and GetDistance(target, Adaga) <= w.Range then
                                player:castSpell("pos", 2, vec3(DaggerPos))
                            else 
                                if GetDistance(target) >= w.Range and not HasRBuff() then
                                    player:castSpell("pos", 2, target.pos)
                                end 
                            end 
                        end 
                    end 
                end
            end 
            if player:spellSlot(1).state == 0  and GetDistance(target) <= w.Range and not HasRBuff()  then
                CastW(target)
            end
            if player:spellSlot(0).state == 0 and GetDistance(target) <= q.Range and not HasRBuff()  then
                CastQ(target)
            end
            if player:spellSlot(3).state == 0 and DamageR(target) >= target.health and GetDistance(target) <= w.Range and not HasRBuff() then
                libss.DelayAction(function() player:castSpell("pos", 3, target.pos) end, 0.100)
               --TimeE = game.time
            end 
        end 
    end 
end 
--EWQR
local function Combo2()
    for i = 0, objManager.enemies_n - 1 do
		local target = objManager.enemies[i]
        if not target.isDead and target.isVisible and target.isTargetable and libss.IsValidTarget(target) then
            if player:spellSlot(2).state == 0  and GetDistance(target) <= e.Range and not HasRBuff() then
                CastE(target)
            end
            if player:spellSlot(0).state == 0 and GetDistance(target) <= q.Range and not HasRBuff()  then
                CastQ(target)
            end
            if player:spellSlot(1).state == 0  and GetDistance(target) <= w.Range and not HasRBuff()  then
                CastW(target)
            end
            if player:spellSlot(3).state == 0 and DamageR(target) >= target.health and GetDistance(target) < w.Range and not HasRBuff() then
                libss.DelayAction(function() player:castSpell("pos", 3, target.pos) end, 0.100)
               --TimeE = game.time
            end 
        end 
    end 
end

local function Combo3()
    for i = 0, objManager.enemies_n - 1 do
		local target = objManager.enemies[i]
        if not target.isDead and target.isVisible and target.isTargetable and libss.IsValidTarget(target) then
            if player:spellSlot(0).state == 0 and GetDistance(target) <= q.Range and not HasRBuff() then
                CastQ(target)
            end 
            if player:spellSlot(2).state == 0  and GetDistance(target) <= e.Range and not HasRBuff() then
                if GetDistance(target) >= w.Range and not HasRBuff() and (q.CoutD == 0) then
                    player:castSpell("pos", 2, target.pos)
                else
                    for _, Adaga in pairs(q.Dagger) do
                        if Adaga then
                            if q.DaggerStart <= game.time then
                                local DaggerPos = Adaga.pos + (target.pos - Adaga.pos):norm() * 200
                                if GetBestDaggerPoint(Adaga, target) and GetDistance(target, Adaga) <= w.Range then
                                    player:castSpell("pos", 2, vec3(DaggerPos))
                                end
                            end 
                        end 
                    end
                end 
               
            end 
            if player:spellSlot(1).state == 0  and GetDistance(target) <= w.Range and not HasRBuff()  then
                CastW(target)
            end
            if player:spellSlot(3).state == 0 and DamageR(target) >= target.health and GetDistance(target) < w.Range and not HasRBuff() then
                libss.DelayAction(function() player:castSpell("pos", 3, target.pos) end, 0.100)
               --TimeE = game.time
            end 
        end 
    end 
end


local function CheckUpR()
    if RCasting == true and #EnemysInrange(player.pos, 550 + 10) == 0 then
        player:move(mousePos)
    end 
end 

local function KillStela()
    for i = 0, objManager.enemies_n - 1 do
		local target = objManager.enemies[i]
        if not target.isDead and target.isVisible and target.isTargetable then
            if DamageQ(target) >= target.health then
                if GetDistance(target) <= 625 then
                    player:castSpell("obj", 0, target)
                end 
            end 
            if (DamageE(target) + libss.GetTotalAD(player) >= target.health) then
                if GetDistance(target) <= 700 then
                    player:castSpell("pos", 2, target.pos)
                end 
            end 
        end 
    end 
   
end 

local function LaneClear()
    local Mindingo = libss.GetMinionsInRange(q.Range, TEAM_ENEMY)
    for i, minion in pairs(Mindingo) do
        if minion and not minion.isDead and libss.IsValidTarget(minion) then
            local MinPos = vec3(minion.x, minion.y, minion.z)
            if (DamageQ(minion) >= minion.health) then
                if GetDistance(minion) <= q.Range then
                    player:castSpell("obj", 0, minion)
                end 
            end 
        end 
    end 
end 

local function TisIgnite()
    for i = 0, objManager.enemies_n - 1 do
		local target = objManager.enemies[i]
        if not target.isDead and target.isVisible and target.isTargetable and libss.IsValidTarget(target) then
            if GetDistance(target) <= 625 then
                if (IgniteFlott and player:spellSlot(IgniteFlott).state) then
                    if libss.GetIgniteDamage(target) >= target.health then
                        player:castSpell("obj", IgniteFlott, target)
                    end
                end 
            end 
        end 
    end 
end 

local function OnTick()
    if CheckDance(player, "katarinarsound") then
        RCasting = true
    else 
        RCasting = false
    end 

    HasRBuff()
    CheckUpR()
    KillStela()
    TisIgnite()
    if (MenuKatarina.katKeys.CK:get()) then
        if MenuKatarina.kat.combomode:get() == 1 and not HasRBuff() then
            Combo1()
        elseif MenuKatarina.kat.combomode:get() == 2  and not HasRBuff() then
            Combo2()
        elseif MenuKatarina.kat.combomode:get() == 3  and not HasRBuff() then
            Combo3()
        end 
    end 
    if (MenuKatarina.katKeys.CL:get()) then
        LaneClear()
    end
end 

orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.create_particle, ObjDagger)
cb.add(cb.delete_particle, ObjDelete)
cb.add(cb.draw, OnDraw)