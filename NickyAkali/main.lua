local orb = module.internal("orb");
local EvadeInternal = module.internal("evade");
local pred = module.internal("pred");
local ts = module.internal('TS');

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

local towers = { } 
local towerCount = 0 
local function valid_tower(tower)
    return tower and tower.type == TYPE_TURRET
end

local function check_add_tower(o)
    if valid_tower(o) then
        towerCount = find_place_and_insert(towers, towerCount, o, valid_tower)
    end
end

local function IsValidTarget(unit, range)
    return unit and unit.isVisible and not unit.isDead and (not range or GetDistance(unit) <= range)
end

local function select_target(res, obj, dist)
	if dist > 1000 then return end
	
	res.obj = obj
	return true
end

local function get_target()
	return ts.get_result(select_target).obj
end

cb.add(cb.create_particle, check_add_tower)

objManager.loop(function(obj)
    check_add_tower(obj)
end)

local _enemyTowers = nil
local function GetEnemyTowers()
    if _enemyTowers then 
        return _enemyTowers 
    end
    _enemyTowers = {}
    for i = 1, towerCount do
        local obj = towers[i]
        if valid_tower(obj) and obj.team ~= TEAM_ALLY then
            _enemyTowers[#_enemyTowers + 1] = obj
        end 
    end 
    return _enemyTowers
end

local function is_under_tower(pos, addRange)
    if not pos then 
        return false 
    end
    for i = 1, towerCount do
        local tower = towers[i]
        if valid_tower(tower) and tower.team ~= TEAM_ALLY then
            if tower.pos:dist(pos) < 900 + (addRange or 0) then
                return tower
            end
        end 
    end 
    return false
end

local function HealthHP(hero)
    return hero.health/hero.maxHealth * 100
end 

local PredE = { delay = 0.25; width = 55; speed = 3200;  boundingRadiusMod = 1; collision = { hero = true, minion = true };}
local PredQ = { delay = 0.25; width = 100; speed = 1800;  boundingRadiusMod = 1; collision = { hero = false, minion = false };}
local PredR = { delay = 0.25; width = 75; speed = 1800;  boundingRadiusMod = 1; collision = { hero = false, minion = false };}
local NickyAkali  = { }

NickyAkali.SpellQ = { Range = 500 }
NickyAkali.SpellW = { Range = 250, Invisible = false }
NickyAkali.SpellE = { Range = 650, Range2 = math.huge}
NickyAkali.SpellR = { Range = 600, Range2 = math.huge }

local E2 = false

local function LoadingAkalied()
    NickyAkali:OnLoad()
    NickyAkali:MenuAkali()
end 

function NickyAkali:OnLoad()
    cb.add(cb.draw, function() self:OnDraw() end)
    --
    cb.add(cb.tick, function() self:OnTick() end)
    cb.add(cb.create_particle, function(obj) self:OnCreateObj(obj) end)
    cb.add(cb.delete_particle, function(obj) self:OnDeleteObj(obj) end)
end 

function NickyAkali:OnTick()
    local target = get_target();
    if not target then return end
    --local range = player.attackRange + (player.boundingRadius + target.boundingRadius)

    if self.mymenu.akt.ComK:get() and self.mymenu.akt.RC:get() and IsValidTarget(target, 750) and not E2 then
        if player:spellSlot(2).state == 0 then
            local wpred = pred.linear.get_prediction(PredE, target)
            if not wpred then return end
            if not pred.collision.get_prediction(PredE, wpred, target) then
                player:castSpell("pos", 2,  vec3(wpred.endPos.x, game.mousePos.y, wpred.endPos.y))
            end 
        end 
    end 
    if self.mymenu.akt.ComK:get() then
        if IsValidTarget(target, 3000) and E2 then
            player:castSpell("self", 2)
        end 
    end 
    if self.mymenu.akt.UT:get() then
        if #EnemysInrange(target.pos, 1000) >= 2 then
            player:castSpell("pos", 1, game.mousePos)
        end 
    end 
    if HealthHP(player) <= 50 then
        player:castSpell("pos", 1, game.mousePos)
    end 

    if self.mymenu.akt.ComK:get() and self.mymenu.akt.AFE:get() and IsValidTarget(target, 500) then
        if player:spellSlot(0).state == 0 then
            local Qpred = pred.linear.get_prediction(PredQ, target)
            if not Qpred then return end
            if not pred.collision.get_prediction(PredQ, Qpred, target) then
                player:castSpell("pos", 0,  vec3(Qpred.endPos.x, game.mousePos.y, Qpred.endPos.y))
            end 
        end 
    end      
    if self.mymenu.akt.ComK:get() and self.mymenu.akt.Keep:get() and IsValidTarget(target, 750) and target.health/target.maxHealth*100 <= self.mymenu.akt.LifeEnemy:get() then
        if player:spellSlot(3).state == 0 then
            player:castSpell("pos", 3,  target.pos)
        end 
    end          
end

function NickyAkali:OnCreateObj(obj)
    if obj then 
        if string.find(obj.name, "Base_E_Enemy_Indicator") then -- Base_E_Enemy_Indicator
            E2 = true
        end 
    end 
end 

function NickyAkali:OnDeleteObj(obj)
    if obj then 
        if string.find(obj.name, "Base_E_Enemy_Indicator") then -- Base_E_Enemy_Indicator
            E2 = false
        end 
    end 
end 

--[[cb.add(cb.spell, function(spell)
    local spellName = spell.name:lower()
    if spell and spell.owner and spell.owner.ptr == player.ptr and spell.name then
       if spellName == "Base_E_Tar" then
        E2 = true
       end 
    end 
end)]]

function NickyAkali:MenuAkali()
    --Main
    self.mymenu = menu("Nicky [Akali]", "Akali:By Nicky")
    --
    self.mymenu:menu("akt", "Settings [Akali]")
    --
    self.mymenu.akt:header("XXd", "[Settings Q]")
    self.mymenu.akt:boolean("AFE", "Use [Q]", true)
    --
    self.mymenu.akt:header("xdD", "[Settings W]")
    self.mymenu.akt:boolean("UT", "Use [W] Logic", true)
    --
    self.mymenu.akt:header("xd", "[Settings E]")
    self.mymenu.akt:boolean("RC", "Use [E]", true)
    self.mymenu.akt:boolean("OnlyE", "Use [E2]", true)
    self.mymenu.akt:boolean("Under", "Use [E2] UnderTower", false)
    --
    self.mymenu.akt:header("x1d", "[Settings R]")
    self.mymenu.akt:boolean("Keep", "Keep R Active", true) 
    self.mymenu.akt:boolean("CanR", "KillSteal [R]", true) 
    self.mymenu.akt:slider("LifeEnemy", "Min. Enemies Life", 75, 1, 100, 1)
    --
    self.mymenu.akt:header("x222d", "[Drawings]")
    self.mymenu.akt:boolean("DQ", "Draw [Q]", true)
    self.mymenu.akt:boolean("DW", "Draw [W]", true)
    self.mymenu.akt:boolean("DE", "Draw [E]", true)
    self.mymenu.akt:boolean("DR", "Draw [R]", true)
    self.mymenu.akt:header("x2d", "[Key]")
    self.mymenu.akt:keybind("ComK", "[Key] Combo", "Space", nil)
end 

function NickyAkali:OnDraw()
    if player.isOnScreen and not player.isDead then
        if player:spellSlot(0).state == 0 and self.mymenu.akt.DQ:get() then
            graphics.draw_circle(player.pos, 500, 2, graphics.argb(255, 0, 204, 255), 100)
        end 
        if player:spellSlot(1).state == 0 and self.mymenu.akt.DW:get() then
            graphics.draw_circle(player.pos, 250, 2, graphics.argb(255, 0, 255, 255), 100)
        end 
        if player:spellSlot(2).state == 0 and self.mymenu.akt.DE:get() then
            graphics.draw_circle(player.pos, 800, 2, graphics.argb(255, 0, 0, 255), 100)
        end
        if player:spellSlot(3).state == 0 and self.mymenu.akt.DR:get() then
            graphics.draw_circle(player.pos, 600, 2, graphics.argb(255, 255, 255, 255), 100)
        end
    end 
end

LoadingAkalied()