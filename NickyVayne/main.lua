local orb = module.internal("orb");
local evade = module.internal("evade");
local pred = module.internal("pred");

local avada_lib = module.lib('avada_lib')
--Avada Lib
local common = avada_lib.common
local dmglib = avada_lib.damageLib

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
    local range = range or math.huge
    local distance = GetDistance(unit)
    return unit and not unit.isDead and unit.isVisible and distance <= range
end

local function IsImmobile(unit)
    local CountBuffByType = common.HasBuffType()
    if CountBuffByType(unit, 5) ~= 0 or CountBuffByType(unit, 11) ~= 0 or CountBuffByType(unit, 24) ~= 0 or CountBuffByType(unit, 29) ~= 0 or unit.isRecalling then
        return true
    end
    return false
end

local NickyVayne = { }

NickyVayne.listSpellInterrup =
{
    ["KatarinaR"] = true,
    ["AlZaharNetherGrasp"] = true,
    ["TwistedFateR"] = true,
    ["VelkozR"] = true,
    ["InfiniteDuress"] = true,
    ["JhinR"] = true,
    ["CaitlynAceintheHole"] = true,
    ["UrgotSwap2"] = true,
    ["LucianR"] = true,
    ["GalioIdolOfDurand"] = true,
    ["MissFortuneBulletTime"] = true,
    ["XerathLocusPulse"] = true,
}

NickyVayne.EnemySpells =
{
["katarinar"] 					= {},
["drain"] 						= {},
["consume"] 					= {},
["absolutezero"] 				= {},
["staticfield"] 				= {},
["reapthewhirlwind"] 			= {},
["jinxw"] 						= {},
["jinxr"] 						= {},
["shenstandunited"] 			= {},
["threshe"] 					= {},
["threshrpenta"] 				= {},
["threshq"] 					= {},
["meditate"] 					= {},
["caitlynpiltoverpeacemaker"] 	= {},
["volibearqattack"] 			= {},
["cassiopeiapetrifyinggaze"] 	= {},
["ezrealtrueshotbarrage"] 		= {},
["galioidolofdurand"] 			= {},
["luxmalicecannon"] 			= {},
["missfortunebullettime"] 		= {},
["infiniteduress"]				= {},
["alzaharnethergrasp"] 			= {},
["lucianq"] 					= {},
["velkozr"] 					= {},
["rocketgrabmissile"] 			= {},
}

--Spells
NickyVayne.SpellsQ = { Range = 300 }
NickyVayne.SpellsW = { Stacks = 0 }
NickyVayne.SpellsE = { Range = 700 }
NickyVayne.SpellsR = { Range = 1000, Invisible = false }

local function LoadingVayne()
    NickyVayne:OnLoad()
end 

function NickyVayne:OnLoad()
    self:MenuVayne()
    cb.add(cb.tick, function() self:OnTick() end)
 --   cb.add(cb.draw, function() self:OnDraw() end)
    cb.add(cb.spell, function(unit, spell) self:OnProcessSpell(unit, spell) end)
    cb.add(cb.updatebuff, function(buff) self:OnUpdateBuff(buff) end)
    cb.add(cb.removebuff, function(buff) self:OnRemoveBuff(buff) end)
    orb.combat.register_f_after_attack(function() self:OnPosAttack() end)
end 

function NickyVayne:MenuVayne()
    self.MyVayne = menu("Nicky [Vayne]", "Vayne: By Nicky")
    self.MyVayne:menu("MQ", "Setting [Q]")
    self.MyVayne.MQ:header("XD", "Setting [Q]")
    self.MyVayne.MQ:boolean("QC", "Use Q in Combo", true)
    self.MyVayne.MQ:dropdown("Qmode", "AA Reset Mode: ", 2, {"Heroes Only", "Heroes + Jungle", "Always", "Never"})
    self.MyVayne.MQ:dropdown("Q2mode", "Tumble Logic: ", 1, {"Smart", "Aggressive"})
    --
    self.MyVayne:menu("MW", "Setting [W]")
    self.MyVayne.MW:header("XD2", "Setting [W]")
    self.MyVayne.MW:boolean("FW", "Force Marked Target", true)
    --
    self.MyVayne:menu("ME", "Setting [E]")
    self.MyVayne.ME:boolean("AutoCoondem", "Use Auto Condemn", true)
    self.MyVayne.ME:slider("CH", "Condemn Hitchance", 50, 0, 100, 1)
    self.MyVayne.ME:slider("CD", "Condemn Distance", 470, 0, 500, 1)
    self.MyVayne.MW:boolean("try", "Use To Proc Third Mark", false)
    --
    self.MyVayne:menu("MR", "Setting [R]")
    self.MyVayne.MR:boolean("RC", "Use R in Combo", true)
    self.MyVayne.MR:slider("Rhitenemy", "Min. Enemies to Use", 3, 1, 5, 1)
    --
    self.MyVayne:menu("Keys", "Setting [Keys]")
    self.MyVayne.Keys:keybind("CK", "[Key] Combo", "Space", nil)
end 

function NickyVayne:OnTick()
    if player.isDead or player.isRecalling then return end  

    self:Auto()
end 

function NickyVayne:Auto()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and not target.isDead then
            if self.MyVayne.Keys.CK:get() and player:spellSlot(3).state == 0 and #count_enemies_in_range(player.pos, 1000) >= self.MyVayne.MR.Rhitenemy:get() then
                player:castSpell("self", 3, player)
            end
            if player:spellSlot(2).state == 0  then
                if IsValidTarget(target, player.attackRange) and self:IsCondemnable(target) then
                    player:castSpell("obj", 2, target)
                    break
                end 
            end 
        end 
    end 
end 

function NickyVayne:OnProcessSpell(unit, spell)
    if spell and spell.owner.team == TEAM_ENEMY and unit.team == TEAM_ENEMY and IsValidTarget(unit, self.SpellsE.Range) and player:spellSlot(2).state == 0 then
        if self.EnemySpells[spell.name] ~= nil then
            player:castSpell("obj", 2, unit)
        end
    end
	if spell and spell.owner.team == TEAM_ENEMY and unit.team == TEAM_ENEMY then
        if self.listSpellInterrup[spell.name] ~= nil then
            if IsValidTarget(unit, self.SpellsE.Range) then
                player:castSpell("obj", 2, unit)
			end
		end
	end
end 

function NickyVayne:OnUpdateBuff(buff)
    if player and buff.name == "vaynetumblefade" then
        self.SpellsR.Invisible = true
    end 
end 

function NickyVayne:OnRemoveBuff(buff)
    if player and buff.name == "vaynetumblefade" then
        self.SpellsR.Invisible = false
    end 
end 

function NickyVayne:OnPosAttack()
    if self.MyVayne.Keys.CK:get() then
        local inimigo = common.GetEnemyHeroes()
        for i, target in ipairs(inimigo) do
            if target and target.isVisible and not target.isDead then
                if player:spellSlot(0).state == 0 then
                    if self.MyVayne.MQ.Q2mode:get() == 1 then
                        local tpos = self:GetSmartTumblePos(target)
                     --  if tpos ~= nil then
                            player:castSpell("pos", 0, tpos)
                            orb.combat.set_invoke_after_attack(false)
                     --  end 
                     elseif self.MyVayne.MQ.Q2mode:get() == 2 then
                        local tpos = self:GetAggressiveTumblePos(target)
                       if tpos ~= nil then
                               player:castSpell("pos", 0, tpos)
                               orb.combat.set_invoke_after_attack(false)
                        end 
                    end 
                end 
            end 
        end 
    end               
end 

function NickyVayne:WStacks(args)
	if args.buff["vaynesilvereddebuff"] then
		self.SpellsW.Stacks = args.buff["vaynesilvereddebuff"].stacks
	end
	return self.SpellsW.Stacks
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

function NickyVayne:IsDangerousPosition(unit)
    local inimigo = common.GetEnemyHeroes()
    for i, v in ipairs(inimigo) do
    	if not v.isDead and v.team == TEAM_ENEMY and unit:distSqr(v) < 300 * 300 then return true end
    end
   	return false
end

function NickyVayne:GetAggressiveTumblePos(target)
    local targetPos = vec3(target.x, target.y, target.z)
    if GetDistance(targetPos, mousePos) < GetDistance(targetPos) then return mousePos end
end

function NickyVayne:GetSmartTumblePos(target)
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
        if self:IsDangerousPosition(points[i]) == false and GetDistanceSqr(points[i], targetPos) < 500 * 500 then
            if (navmesh.isWall(targetPos:ext(myHeroPos, -450))) then 
                return points[i]
            end 
        end
    end
    if self:IsDangerousPosition(possiblePos) == false then
        return possiblePos
    end 
    for i=1,#points do
        if self:IsDangerousPosition(points[i]) == false and GetDistanceSqr(points[i], targetPos) < 500 * 500  then --and GetDistance(points[i],mousePos) <= GetDistance(bestPos, mousePos)
            return points[i]
        end
    end     
end

function NickyVayne:IsCollisionable(vector)
    return navmesh.isWall(vector.x, vector.y, vector.z)
end

function NickyVayne:IsCondemnable(target) 
    local pP = vec3(player.x, player.y, player.z) 
    local eP = vec3(target.x, target.y, target.z)
    local eP2 = target.pos
    local pD = self.MyVayne.ME.CD:get() 
    if (navmesh.isWall(eP:ext(pP,-pD)) or navmesh.isWall(eP:ext(pP, -pD/2)) or navmesh.isWall(eP:ext(pP, -pD/3))) then 
        local hitchance = self.MyVayne.ME.CH:get() / 100
        eP2 = eP + (eP2 - eP):norm() * target.moveSpeed * hitchance * 0.5    
        for i = 15, pD, 75 do
            local col1 = eP2 + (eP2 - pP):norm() * i
            local col2 = eP + (eP - pP):norm() * i
            if navmesh.isWall(col1) and navmesh.isWall(col2) then return true end
        end        
    end
end



---
LoadingVayne()
---