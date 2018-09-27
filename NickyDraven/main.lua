local pred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local evade = module.seek("evade")
local ObjMinion_Type = objManager.minions

local EPrediction = { -- range is 1050
  width = 130,
  delay = 0.25,
  speed = 1400,
  boundingRadiusMod = 0
}

local RPrediction = { -- range is global
  width = 160,
  delay = 0.4,
  speed = 2000,
  boundingRadiusMod = 1
}

local AxePositions = {}
local LatestAxeCreateTick = 0
local Qpause = 0


local interruptableSpells = {
	["anivia"] = {
		{menuslot = "R", slot = 3, spellname = "glacialstorm", channelduration = 6},
	},
	["caitlyn"] = {
		{menuslot = "R", slot = 3, spellname = "caitlynaceinthehole", channelduration = 1},
	},
	["ezreal"] = {
		{menuslot = "R", slot = 3, spellname = "ezrealtrueshotbarrage", channelduration = 1},
	},
	["fiddlesticks"] = {
		{menuslot = "W", slot = 1, spellname = "drain", channelduration = 5},
		{menuslot = "R", slot = 3, spellname = "crowstorm", channelduration = 1.5},
	},
	["gragas"] = {
		{menuslot = "W", slot = 1, spellname = "gragasw", channelduration = 0.75},
	},
	["janna"] = {
		{menuslot = "R", slot = 3, spellname = "reapthewhirlwind", channelduration = 3},
	},
	["karthus"] = {
		{menuslot = "R", slot = 3, spellname = "karthusfallenone", channelduration = 3},
	}, --IsValidTarget will prevent from casting @ karthus while he's zombie
	["katarina"] = {
		{menuslot = "R", slot = 3, spellname = "katarinar", channelduration = 2.5},
	},
	["lucian"] = {
		{menuslot = "R", slot = 3, spellname = "lucianr", channelduration = 2},
	},
	["lux"] = {
		{menuslot = "R", slot = 3, spellname = "luxmalicecannon", channelduration = 0.5},
	},
	["malzahar"] = {
		{menuslot = "R", slot = 3, spellname = "malzaharr", channelduration = 2.5},
	},
	["masteryi"] = {
		{menuslot = "W", slot = 1, spellname = "meditate", channelduration = 4},
	},
	["missfortune"] = {
		{menuslot = "R", slot = 3, spellname = "missfortunebullettime", channelduration = 3},
	},
	["nunu"] = {
		{menuslot = "R", slot = 3, spellname = "absolutezero", channelduration = 3},
	},
	--excluding Orn's Forge Channel since it can be cancelled just by attacking him
	["pantheon"] = {
		{menuslot = "R", slot = 3, spellname = "pantheonrjump", channelduration = 2},
	},
	["shen"] = {
		{menuslot = "R", slot = 3, spellname = "shenr", channelduration = 3},
	},
	["twistedfate"] = {
		{menuslot = "R", slot = 3, spellname = "gate", channelduration = 1.5},
	},
	["varus"] = {
		{menuslot = "Q", slot = 0, spellname = "varusq", channelduration = 4},
	},
	["warwick"] = {
		{menuslot = "R", slot = 3, spellname = "warwickr", channelduration = 1.5},
	},
	["xerath"] = {
		{menuslot = "R", slot = 3, spellname = "xerathlocusofpower2", channelduration = 3},
	}
}

local function GetAARange(target)
    return player.attackRange + player.boundingRadius + (target and target.boundingRadius or 0)
end

local function CountAllyChampAroundObject(pos, range) 
	local aleds_in_range = {}
	for i = 0, objManager.allies_n - 1 do
		local aled = objManager.allies[i]
		if pos:dist(aled.pos) < range and IsValidTarget(aled) then
			aleds_in_range[#aleds_in_range + 1] = aled
		end
	end
	return aleds_in_range
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
--
local function CheckBuff(obj, buffname)
    if obj then
        for i = 0, obj.buffManager.count - 1 do
            local buff = obj.buffManager:get(i)
            if buff and buff.valid and string.lower(buff.name) == string.lower(buffname) and buff.owner == obj then
                if game.time <= buff.endTime then
                    return true, buff.startTime
                end 
            end 
        end 
    end 
    return false, 0
end 
--
local function IsValidTarget(object)
    return (object and not object.isDead and object.isVisible and object.isTargetable and not CheckBuffType(object, 17))
end
--
local function ValidTargetRange(unit, range)
    return unit and unit.isVisible and not unit.isDead and unit.isTargetable and not CheckBuffType(unit, 17) and (not range or player.pos:dist(unit.pos) <= range)
end
--
local function IsReady(spell)
    return player:spellSlot(spell).state == 0
end 
--
local function set_server_pause()
	Qpause = os.clock() + network.latency + 0.25
end
--
local function is_Q_paused()
	return Qpause > os.clock()
end
--
local function GetPercentPar(obj)
	local obj = obj or player
	return (obj.par / obj.maxPar) * 100
end
--
local function DamageR(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {175, 275, 375}
        if player:spellSlot(3).state == 0 then
			Damage = (DamageAP[player:spellSlot(3).level] + 1.1 * player.baseAttackDamage + player.flatPhysicalDamageMod * 1 + player.percentPhysicalDamageMod - player.baseAttackDamage)
        end
		return Damage
	end
	return 0
end
--
local function CountQs()
	if player then
		for i = 0, player.buffManager.count - 1 do
			local buff = player.buffManager:get(i)
			if buff and buff.valid and buff.name == "DravenSpinningAttack" then
				return buff.stacks + #AxePositions
			end
		end 
	end
	return #AxePositions
end
--
local function TargetSelecton(Range)
    Range = Range or 900 
    if orb.combat.target and not orb.combat.target.isDead and orb.combat.target.isTargetable and orb.combat.target.isVisible then
        return orb.combat.target
    else 
        local dist, closest = math.huge, nil
        for i = 0, objManager.enemies_n - 1 do
            local unit = objManager.enemies[i]
            local unit_distance = player.pos:dist(unit.pos);
            
			if not unit.isDead and unit.isVisible and unit.isTargetable and unit_distance <= Range then
                if unit_distance < dist then
                    closest = unit
                    dist = unit_distance;
                end
            end
            if closest then
                return closest
            end
        end
        return nil
    end 
end 
--
-- menu initialization
local menu = menu("[Nicky]Draven", "[Nicky]Draven")
menu:header("title", "[Nicky]Draven")
menu:menu("combo", "Combo Settings")
menu:menu("axe", "Axe Settings")
menu:menu("drawing", "Draw Settings")
menu:menu("misc", "Miscellaneous Settings")

--combo submenu options
menu.combo:header("title", "Combo Settings")
menu.combo:boolean("comboQ", "Use Q", true)
menu.combo:boolean("comboW", "Use W", true)
menu.combo:slider("wmana", "Don't Use W if Mana % < ", 1, 1, 100, 1)
menu.combo:boolean("comboE", "Use E", true)
menu.combo:boolean("comboR", "Use R", true)
menu.combo:slider("Rrange", "R Range Modifier", 5000, 1000, 10000, 500)

menu.axe:header("title", "Axe Settings")
menu.axe:dropdown("catchMode", "Catch Axe\'s", 2, {"Combo", "Always", "Never"})
menu.axe:slider("catchRange", "Catch Range", 600, 100, 1500, 10)
menu.axe:slider("max", "Max Axe\'s to Juggle", 3, 1, 7, 1)
menu.axe:boolean("turret", "Dont Catch Axe\'s Under Turret", true)

menu.drawing:header("title", "Draw Settings")
menu.drawing:boolean("drawAxe", "Draw Axe Drop Location", true)
menu.drawing:boolean("drawAxeRange", "Draw Axe Catch Range", true)
menu.drawing:color("colorAxeRange", "Axe Range Color", 255, 100, 255, 100)

menu.misc:header("title", "Miscellaneous Settings")
menu.misc:boolean("QNotCombo", "Use Q During Farm/Harass", true)
menu.misc:boolean("wifslowed", "Use W if slowed", true)
menu.misc:boolean("gapcloser", "Use E on Gapclosers", true)
menu.misc:boolean("interrupt", "Use E to Interrupt Casts", true)
menu.misc:menu("interruptmenu", "Interrupt Settings")
menu.misc.interruptmenu:header("lol", "Interrupt Settings")
for i = 0, objManager.enemies_n - 1 do
    local enemy = objManager.enemies[i]
    local name = string.lower(enemy.charName)
    if enemy and interruptableSpells[name] then
        for v = 1, #interruptableSpells[name] do
            local spell = interruptableSpells[name][v]
			menu.misc.interruptmenu:boolean(string.format(enemy.charName .. spell.menuslot), "Interrupt " .. enemy.charName .. " " .. spell.menuslot, true)
		end 
	end 	
end

local function OnAxeCreation(unit)
	if player.pos:dist(unit.pos) > 2000 then return end
	if string.find(unit.name, "reticle_self") then
		LatestAxeCreateTick = LatestAxeCreateTick + 1
		table.insert(AxePositions, unit)
		set_server_pause()
	end 
end

local function OnAxeDeletion(unit)
	if player.pos:dist(unit.pos) > 2000 or AxePositions == nil then return end
	for k, v in pairs(AxePositions) do
		if v.ptr ~= unit.ptr then 
			return 
		end
		table.remove(AxePositions, k)
		set_server_pause()
	end 
end 

local function AutoInterrupt(spell)
	if menu.misc.interrupt:get() and player:spellSlot(2).state == 0 then
    local owner = spell.owner
		if owner.type == TYPE_HERO and owner.team == TEAM_ENEMY then
			local enemyName = string.lower(owner.charName)
			if interruptableSpells[enemyName] then
				for i = 1, #interruptableSpells[enemyName] do
					local spellCheck = interruptableSpells[enemyName][i]
					if menu.misc.interruptmenu[owner.charName .. spellCheck.menuslot]:get() and string.lower(spell.name) == spellCheck.spellname then
						if IsValidTarget(enemy) and owner.pos:dist(player.pos) < 950 then
							player:castSpell('pos', 2, vec3(owner.x, game.mousePos.y, owner.z))
						end
					end
				end
			end
		end
	end
end

local function OnDraw()
	if IsValidTarget(player) then
		if AxePositions ~= nil then
			for k, axe in pairs(AxePositions) do
				graphics.draw_circle(axe.pos, 110, 2, graphics.argb(255, 0, 255, 0), 50)
				graphics.draw_line(player.pos, axe.pos, 2, graphics.argb(255, 255, 255, 0))
			end 
		end 
		if menu.drawing.drawAxeRange:get() then
			graphics.draw_circle(game.mousePos, menu.axe.catchRange:get(), 1, menu.drawing.colorAxeRange:get(), 40)
		end
	end 
end 

local function BestAxe()
	local best = nil
	local distance = 10000
	for i = 1, #AxePositions do
		local axe = AxePositions[i]
		if axe then
			local axePos = vec3(axe.x, axe.y, axe.z)
			if mousePos:dist(axePos) < menu.axe.catchRange:get() and axePos:dist(player) < distance then
				best = axe
				distance = axePos:dist(player)
			end
		end
	end
	return best
end

local function FuryCount()
	if player then
		for i = 0, player.buffManager.count - 1 do
			local buff = player.buffManager:get(i)
			if buff and buff.valid and buff.name == "dravenfurybuff" then
				return buff.stacks
			end
		end
	end
	return 0
end

local function GoFetch()
	local method = menu.axe.catchMode:get()
	if (method == 1 and orb.combat.is_active()) or (method == 2) then
		local axe = BestAxe()
		if axe and axe.pos:dist(player) > 85 then
			if menu.axe.turret:get() then
				if orb.core.can_action() and not orb.core.can_attack() then
					player:move(axe.pos)
				end
			end
		end
	end
end 

local function UseQOutsideCombo()
	if menu.misc.QNotCombo:get() and player:spellSlot(0).state == 0 and orb.core.can_attack() and not is_Q_paused() and CountQs() < 1 then
		player:castSpell("self", 0)
	end
end

local function IsCombo(target)
	if target.pos:dist(player.pos) <= 1200 then
		if menu.combo.comboQ:get() and player:spellSlot(0).state == 0 and IsValidTarget(target) and orb.core.can_attack() and CountQs() < menu.axe.max:get() then
			player:castSpell("self", 0)
		end 
		if menu.combo.comboW:get() and player:spellSlot(1).state == 0 and IsValidTarget(target) and FuryCount() < 1 and GetPercentPar() > menu.combo.wmana:get() then
			player:castSpell("self", 1)
		end
		if menu.combo.comboE:get() and player:spellSlot(2).state == 0 then
			local c_target = orb.combat.target
			if c_target and IsValidTarget(c_target) and c_target.pos:dist(player.pos) <= GetAARange(c_target) then
				target = c_target
			end
			local seg = pred.linear.get_prediction(EPrediction, target)
			if seg and seg.startPos:distSqr(seg.endPos) < (950 * 950) then
				player:castSpell("pos", 2, vec3(seg.endPos.x, target.y, seg.endPos.y))
			end 
		end 
		if menu.combo.comboR:get() and player:spellSlot(3).state == 0 then
			if DamageR(target) >= target.health then
				local seg2 = pred.linear.get_prediction(RPrediction, target)
				if seg2 then
					player:castSpell("pos", 3, vec3(seg2.endPos.x, target.pos.y, seg2.endPos.y))
				end	
			end
		end 		 
	end 
end 

local function OnTick()
	GoFetch()
	if player:spellSlot(1).state == 0 and menu.misc.wifslowed:get() and CheckBuffType(player, 10) then
		player:castSpell("self", 1)
	end 
	--
	if (orb.combat.is_active()) then
		local target = TargetSelecton(1000)
		if target and IsValidTarget(target) then
			IsCombo(target)
		end
	end 
	if (orb.menu.lane_clear:get() or orb.menu.hybrid:get() or orb.menu.last_hit:get()) then
		UseQOutsideCombo()
	end 
end

orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.create_particle, OnAxeCreation)
cb.add(cb.delete_particle, OnAxeDeletion)
cb.add(cb.draw, OnDraw)
cb.add(cb.spell, AutoInterrupt)
