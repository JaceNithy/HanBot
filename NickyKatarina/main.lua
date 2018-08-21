local orb = module.internal("orb");
local EvadeInternal = module.internal("evade");
local pred = module.internal("pred");
local ts = module.internal('TS');

--Avada Lib


--Real HP
local function GetRealHP(unit, dmgType)
    local mod = dmgType == 0 and unit.magicalShield or unit.allShield
    return unit.health + mod
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

local function EnemysInrange(pos, range) -- ty Kornis Thank you for allowing your code
	local enemies_in_range = {}
	for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
		if pos:dist(enemy.pos) < range  then
			enemies_in_range[#enemies_in_range + 1] = enemy
		end
	end
	return enemies_in_range
end


local unitsenemies = { }
local unitsallies = { }

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

  
local function valid_hero(hero)
    return hero and hero.type == TYPE_HERO
  end

  local function check_add_hero(o)
    if valid_hero(o) then
      if o.team == TEAM_ALLY then
        find_place_and_insert(unitsallies, #unitsallies, o, valid_hero)
      else
        find_place_and_insert(unitsenemies, #unitsenemies, o, valid_hero)
      end
    end
  end

  objManager.loop(function(obj)
    check_add_hero(obj)
  end)

  -- Returns table of enemy hero.obj
local function GetEnemyHeroes()
    return unitsenemies
end
  
local Rative = false
local TimeR = 0
local function RDance()
    local gametime = game.time
    for i = 0, player.buffManager.count - 1 do
        local buff = player.buffManager:get(i)
        if buff and buff.valid and buff.name == "katarinarsound" and buff.owner == player then
            local buffstart = buff.startTime 
            local buffend =  buff.endTime
            if gametime <= buffstart then
                return true, buffstart
            end  
        end 
    end
    return false, 0, buffend
end


--[[local function IsValidTarget(unit, range)
    local range = range or math.huge
    local distance = GetDistance(unit)
    return unit and not unit.isDead and unit.isVisible and distance <= range
end]]

local function IsValidTarget(unit, range)
    return unit and unit.isVisible and not unit.isDead and (not range or GetDistance(unit) <= range)
end

local NickyKatarina = { }

--Variable
NickyKatarina.DaggerRal = { }
NickyKatarina.dStartTime = 0 
NickyKatarina.dEndTime = 0
NickyKatarina.dLaftTime = 0
NickyKatarina.dCanTime = 0
NickyKatarina.dState = false
--NickyKatarina.Position = vec3(0, 0, 0)

--Spells
-- Q = 0
-- W = 1
-- E = 2 
-- R = 3
NickyKatarina.SpellQ = { Range = 625 }
NickyKatarina.SpellW = { Range = 340 }
NickyKatarina.DanggerSpell = { Range = 340 }
NickyKatarina.SpellE = { Range = 725 }
NickyKatarina.SpellR = { Range = 550 }


local function LoadingKat()
    NickyKatarina:OnLoad()
    NickyKatarina:MenuKat()
end

function NickyKatarina:OnLoad()
    orb.combat.register_f_pre_tick(function() self:OnTick() end)
    cb.add(cb.draw, function() self:OnDraw() end)
    cb.add(cb.create_particle, function(obj) self:OnCreateObj(obj) end)
    cb.add(cb.delete_particle, function(obj) self:OnDeleteObj(obj) end)
end 

function NickyKatarina:MenuKat()
    self.mymenu = menu("Nicky [Katarina]", "Katarina:By Nicky")
    self.mymenu:menu("kat", "Settings [Katarina]")
    self.mymenu.kat:header("XXd", "[Settings Q]")
    self.mymenu.kat:boolean("AFE", "Use [Q]", true)
    self.mymenu.kat:header("xdD", "[Settings W]")
    self.mymenu.kat:boolean("UT", "Use [W]", true)
    self.mymenu.kat:header("xd", "[Settings E]")
    self.mymenu.kat:boolean("RC", "Use [E] Dagger", true)
    self.mymenu.kat:boolean("OnlyE", "Only On Dagger", true)
    self.mymenu.kat:header("x1d", "[Settings R]")
    self.mymenu.kat:boolean("Keep", "Keep R Active", true) 
    self.mymenu.kat:boolean("CanR", "KillSteal [R]", true) 
    self.mymenu.kat:slider("Rhitenemy", "Min. Enemies to Use", 2, 1, 5, 1)
    self.mymenu.kat:header("x222d", "[Drawings]")
    self.mymenu.kat:boolean("DQ", "Draw [Q]", true)
    self.mymenu.kat:boolean("DW", "Draw [W]", true)
    self.mymenu.kat:boolean("DE", "Draw [E]", true)
    self.mymenu.kat:boolean("DR", "Draw [R]", true)
    self.mymenu.kat:boolean("DTD", "Draw Dagger Time", true)
    self.mymenu.kat:header("x2d", "[Key]")
    self.mymenu.kat:keybind("ComK", "[Key] Combo", "Space", nil)
end 



function NickyKatarina:OnTick()
   -- self:AuToQ()
   -- self:LeituraSpell()
    --Time DAGGER
    self.dLaftTime = self:MathTime(self.dEndTime - game.time)
    -- Time Pos Dagger
    --self.dCanTime = self:MathTime(self.dStartTime + game.time)
    --CheckR
    self:CheckTheR()



    if self.mymenu.kat.ComK:get() and not Rative == true then
        self:LogicQ() 
    end 
    if self.mymenu.kat.ComK:get() and not Rative == true then
        self:LogicE()     
    end 
    if self.mymenu.kat.ComK:get() and not Rative == true then
        self:LogicW()
        self:LogicR()
    end 
end 

function NickyKatarina:CheckTheR()
    if Rative == true then
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

function NickyKatarina:OnCreateObj(obj)
    if obj then 
        if string.find(obj.name, "W_Indicator_Ally") then
            self.DaggerRal[obj.ptr] = obj
            self.dStartTime = game.time + 1.1 - 0.2
            self.dEndTime = game.time + 5.1
            self.dLaftTime = 5.1
            self.dCanTime = 1.1 - 0.2
        --   self.CountDagger = self.CountDagger + 1
        end 
    end 
    if obj then
        if string.find(obj.name, "Base_R_cas") then
            Rative = true
            TimeR = game.time + 1
             -- Base_r_tar
        end 
    end
end

function NickyKatarina:OnDeleteObj(obj)
    if obj then 
        if string.find(obj.name, "W_Indicator_Ally") then
            self.DaggerRal[obj.ptr] = nil
            self.dStartTime = 0
            self.dEndTime = 0
            self.dLaftTime = 0
            self.dCanTime = 0
        --    self.CountDagger = self.CountDagger - 1
        end 
    end 
    if obj then
        if string.find(obj.name, "Base_R_cas") then
            Rative = false
            TimeR = 0
             -- Base_r_tar
        end 
    end
end 

function NickyKatarina:OnDraw()
    if player.isOnScreen then
        if player:spellSlot(0).state == 0 and self.mymenu.kat.DQ:get() then
            graphics.draw_circle(player.pos, self.SpellQ.Range, 2, graphics.argb(255, 0, 204, 255), 100)
        end 
        if player:spellSlot(1).state == 0 and self.mymenu.kat.DW:get() then
            graphics.draw_circle(player.pos, self.SpellW.Range, 2, graphics.argb(255, 255, 255, 255), 100)
        end
        if player:spellSlot(2).state == 0 and self.mymenu.kat.DE:get() then
            graphics.draw_circle(player.pos, self.SpellE.Range, 2, graphics.argb(255, 0, 255, 0), 100)
        end
        if player:spellSlot(3).state == 0 and self.mymenu.kat.DR:get() then
            graphics.draw_circle(player.pos, self.SpellR.Range, 2, graphics.argb(255, 255, 204, 255), 100)
        end
    end 
    if (self:CountAdaga() > 0)  and self.mymenu.kat.DTD:get() then
        for _, Adaga in pairs(self.DaggerRal) do
            if Adaga then
                if player.isVisible and player.isOnScreen and not player.isDead then
                    if game.time > self.dStartTime  and game.time < self.dEndTime  then
                        local AdagaPoS = graphics.world_to_screen(Adaga.pos)
                        local textWidth = graphics.text_area("1.00", 30)
                        graphics.draw_text_2D(tostring(self.dLaftTime), 30, AdagaPoS.x - (textWidth / 2), AdagaPoS.y, 0xFFffffff) 
                    end
                end 
            end 
        end 
    end
end 

function NickyKatarina:CountAdaga()
	local count = 0
	for _ in pairs(self.DaggerRal) do
		count = count + 1
	end
	return count
end

function NickyKatarina:MathTime(t) 
    return math.floor((t) * 100) * 0.01
end

function NickyKatarina:LogicQ()
    local inimigo = GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and not target.isDead then
            if player:spellSlot(0).state == 0 and IsValidTarget(target, self.SpellQ.Range) then
                player:castSpell("obj", 0, target)
            end 
        end 
    end 
end 

function NickyKatarina:AuToQ()
    local inimigo = GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and not target.isDead then
            if player:spellSlot(0).state == 0 and IsValidTarget(target, self.SpellQ.Range) then
                player:castSpell("obj", 0, target)
            end 
        end 
    end 
end 

function NickyKatarina:LogicW()
    local inimigo = GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and not target.isDead then
            if player:spellSlot(1).state == 0 and GetDistanceSqr(player, target) < self.SpellW.Range/2 * self.SpellW.Range/2 then
                player:castSpell("self", 1)
            end 
        end 
    end 
end 

function NickyKatarina:LogicR()
    local inimigo = GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if player:spellSlot(3).state == 0 and target and target.isVisible and not target.isDead and player.pos:dist(target.pos) < 490 then
            player:castSpell("pos", 3, player.pos)
        end 
    end 
end 

function NickyKatarina:LogicE()
    local inimigo = GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if (self:CountAdaga() > 0) then
            for _, Adaga in pairs(self.DaggerRal) do
                if target and target.isVisible and not target.isDead then
                    if player:spellSlot(2).state == 0 and IsValidTarget(target, 700) then
                        if game.time > self.dStartTime then
                         local DaggerPos = Adaga.pos + (target.pos - Adaga.pos):norm() * 125
                         local DaggerIsRange = Adaga.pos + (target.pos - Adaga.pos):norm() * 50
                         local DaggerRange = Adaga.pos + (target.pos - Adaga.pos):norm() * -50
                            if self:GetBestDaggerPoint(Adaga, target) and GetDistance(target, Adaga) < 450 then
                                player:castSpell("pos", 2, vec3(DaggerPos))
                            elseif self:LogicDistance(Adaga, target) and GetDistance(target, Adaga) < 450 then
                                player:castSpell("pos", 2, vec3(DaggerPos))
                            elseif self:LogicInstance(Adaga, target) and GetDistance(target, Adaga) < 450 then
                                player:castSpell("pos", 2, vec3(DaggerRange))
                            elseif self:ELogic(Adaga, target) and GetDistance(target, Adaga) < 450 then
                                player:castSpell("pos", 2, vec3(DaggerIsRange))
                            end 
                        end    
                    end 
                end 
            end 
        end 
    end 
end 

function NickyKatarina:LogicETarget()
    local inimigo = GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and not target.isDead then
            if player:spellSlot(2).state == 0 and IsValidTarget(target, self.SpellE.Range) then
                player:castSpell("pos", 2, target.pos)
            end 
        end 
    end 
end 

function NickyKatarina:GetRDamage(target)
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

function NickyKatarina:DamageIgnite(target)
    if target ~= 0 then
		local Damage = 0
        if player:spellSlot(Ignute).state == 0 then
			Damage = (50 + 20 * player.levelRef / 5 * 3)
        end
		return Damage
	end
	return 0
end

function NickyKatarina:GetEDamage(target)
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

function NickyKatarina:MathTime(t) 
    return math.floor((t) * 100) * 0.01
end

--Logic Dagger

function NickyKatarina:GetDaggers(daggers)
    return daggers.name == "Katarina_Base_W_Indicator_Ally" and daggers.isVisible and daggers.health == 100 
end 

function NickyKatarina:LogicDistance(position, target)
    local targetPos = vec3(target.x, target.y, target.z)
    local positionPos = vec3(position.x, position.y, position.z)
    if GetDistanceSqr(targetPos, positionPos) < 340 * 340 then
        return position
    end 
    return positionPos:ext(targetPos, 200)
end 

function NickyKatarina:LogicInstance(position, target)
    local targetPos = vec3(target.x, target.y, target.z)
    local positionPos = vec3(position.x, position.y, position.z)
    if GetDistanceSqr(targetPos, positionPos) < 340 * 340 then
        return position
    end 
    return positionPos:ext(targetPos, -50)
end 

function NickyKatarina:ELogic(position, target)
    local targetPos = vec3(target.x, target.y, target.z)
    local positionPos = vec3(position.x, position.y, position.z)
    if GetDistanceSqr(targetPos, positionPos) < 340 * 340 then
        return position
    end 
    return positionPos:ext(targetPos, 50)
end

function NickyKatarina:GetBestDaggerPoint(position, target)
    local targetPos = vec3(target.x, target.y, target.z)
    local positionPos = vec3(position.x, position.y, position.z)
    if GetDistanceSqr(targetPos, positionPos) < 340 * 340 then
        return position
    end 
    return positionPos:ext(targetPos, 150)
end 

function NickyKatarina:IsUnderTurretEnemy(pos)
    enemyTowers = GetEnemyTowers()
    for i = 1, #enemyTowers do
		local tower = enemyTowers[i]
        local turretPos = vec3(tower.x, tower.y, tower.z)
        if GetDistanceSqr(turretPos, pos) < 915*915 then
            return true
        end
    end 
    return false
end

--
LoadingKat()
--
