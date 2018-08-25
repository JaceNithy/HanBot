local pred = module.internal("pred")
local ts = module.internal("TS")
local orb = module.internal("orb")
local EvadeInternal = module.seek("evade")
local libss = module.load("NickyLeblanc", "libss")

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
		if pos:dist(enemy.pos) < range and libss.IsValidTarget(enemy)  then
			enemies_in_range[#enemies_in_range + 1] = enemy
		end
	end
	return enemies_in_range
end

local q = { Range = 700, Marked = false, MarkedR = false}
local w = { Range = 600, WIsReal = { }, TimeStart = 0, TimeEndPos = 0 }
local e = { Range = 865 }
local r = { Range = 0, RWIsReal = { }, TimeR = 0 }
local Posis = vec3(0,0,0)
local WPos = vec3(0,0,0)

local function ObjMarked(obj) --Base_Q_Tar_Mark or Base_RQ_Tar_Mark or Base_W_return_indicator
    if obj and obj.name then 
        if string.find(obj.name, "Base_Q_Tar_Mark") then
            q.Marked = true
        end 
    end 
    if obj and obj.name then 
        if string.find(obj.name, "Base_RQ_Tar_Mark") then
            q.MarkedR = true
        end 
    end 
    if obj and obj.name then 
        if string.find(obj.name, "Base_W_return_indicator") then
            w.WIsReal[obj.ptr] = obj 
            w.TimeStart = game.time 
            w.TimeEndPos = game.time + 2
        end
    end 
end 

local function ObjDelete(obj)
    if obj and obj.name then 
        if string.find(obj.name, "Base_Q_Tar_Mark") then
            q.Marked = false
        end 
    end 
    if obj and obj.name then 
        if string.find(obj.name, "Base_RQ_Tar_Mark") then
            q.MarkedR = false
        end 
    end 
    if obj and obj.name then 
        if string.find(obj.name, "Base_W_return_indicator") then
            w.WIsReal[obj.ptr] = obj 
            w.TimeStart = 0
            w.TimeEndPos = 0
        end
    end 
end 

local function OnDraw()
    for _, WIsPOS in pairs(w.WIsReal) do
        if WIsPOS then
            if player.isVisible and player.isOnScreen and not player.isDead then
                if game.time >= w.TimeStart and game.time <= w.TimeEndPos  then
                    graphics.draw_circle(WIsPOS.pos, 350, 2, graphics.argb(255, 255, 0, 0), 100) 
                end 
            end
        end 
    end 
end 

cb.add(cb.create_particle, ObjMarked)
cb.add(cb.delete_particle, ObjDelete)
cb.add(cb.draw, OnDraw)