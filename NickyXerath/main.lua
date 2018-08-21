local pred = module.internal("pred")
local ts = module.internal("TS")
local orb = module.internal("orb")
local evade = module.seek("evade")
local libss = module.load("NickyXerath", "lib")


local q = { MaxRange = 1400, MinRange = 750, speed = 2000, width = 70, delay = 0.25 }
local w = { Range = 1100 }
local e = { Range = 1050 }
local r = { Range = 6160 }

--Q
local TimeCharge = 0
local ChargeOn = false
local CastTime = 0
local CanCast = true

local function ChargeRangeQ(time)
	local Redefine = q.MaxRange - q.MinRange
	local MinimoRange = q.MinRange
	local AlcanceQ = Redefine / 1.3 * time + MinimoRange
    if AlcanceQ > q.MaxRange then 
        AlcanceQ = q.MaxRange 
    end
	return AlcanceQ
end

local function BuffQ()
    for i = 0, player.buffManager.count - 1 do
        local buff = player.buffManager:get(i)
        if buff and buff.valid and buff.name == "XerathArcanopulseChargeUp" and buff.owner == player then
            TimeCharge = game.time 
            ChargeOn = true
            orb.core.set_pause_attack(math.huge)
        else 
            TimeCharge = 0
            ChargeOn = false
            orb.core.set_pause_attack(0)
        end 
    end 
end 


cb.add(cb.draw, function()
    if ChargeOn == true then
        local TimeQ = game.time - CastTime
        local range = ChargeRangeQ(TimeQ)
        graphics.draw_circle(player.pos, range, 2, graphics.argb(255, 255, 204, 255), 100)
    else
        graphics.draw_circle(player.pos, q.MinRange, 2, graphics.argb(255, 255, 204, 255), 100)
    end 
end)

cb.add(cb.castspell, function()
    if spell and spell.owner == player and spell.name == "XerathArcanopulseChargeUp" then
        CastTime = game.time
        CanCast = false
    end 
end)