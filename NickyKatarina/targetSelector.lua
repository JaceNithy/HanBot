local myChamp = objManager.player
local avadaCommon = module.load("NickyKatarina", "libss")

local enemies = avadaCommon.GetEnemyHeroes()
----------------------------------------------------------------
-- Create A Target Selector
----------------------------------------------------------------
local targetSelector = avadaCommon.Class(function (s, mymenu, range, dmgType, addBBox) -- dmgType: 1 = Physical, 2 = Magical
	assert(type(mymenu) == "table", "Avada\'s Target Selector: wrong argument type (<table> expected for mymenu got "..type(mymenu)..")")
	assert(type(range) == "number", "Avada\'s Target Selector: wrong argument type (<number> expected for range got "..type(menu)..")")
	s.dtsmenu = mymenu
	s.range = range
	s.damgType = (dmgType and dmgType > 0 and dmgType < 3) and dmgType or 1
	s.target = nil
	s.focus = nil
	s.addBBox = addBBox
end)

function targetSelector:addToMenu(noSubMenu)
	self.championTable = {
		[1] = {"Alistar", "Braum", "DrMundo", "Galio", "Garen", "Leona", "Nautilus", "Shen", "Singed", "Sion", "Poppy", "Rammus", "Skarner", "TahmKench", "Taric", "Thresh", "Zac"},
		[2] = {"Aatrox", "Amumu", "Blitzcrank", "Darius", "Gnar", "Gragas", "Illaoi", "Ivern", "Janna", "Kled", "Malphite", "Maokai", "Nami", "Nasus", "Nunu", "Olaf", "Ornn", "Sejuani", "Shyvana", "Rakan", "RekSai", "Renekton", "Swain", "Trundle", "Udyr", "Urgot", "Volibear", "Yorick"},
		[3] = {"Akali", "Anivia", "Bard", "Chogath", "Ekko", "Elise", "Fiora", "Gangplank", "Hecarim", "Heimerdinger", "Irelia", "JarvanIV", "Jax", "Jayce", "Kassadin", "Kayle", "LeeSin", "Lissandra", "Lulu", "Mordekaiser", "Morgana", "Nidalee", "Pantheon", "Rumble", "Sona", "Taliyah", "Tryndamere", "Vi", "Vladimir", "Warwick", "Wukong", "XinZhao", "Zilean", "Zyra"},
		[4] = {"Ahri", "Annie", "AurelionSol", "Azir", "Camille", "Cassiopeia", "Corki", "Diana", "Evelynn", "FiddleSticks", "Fizz", "Graves", "Kayn", "Karma", "Karthus", "Katarina", "Kennen", "Kindred", "LeBlanc", "Lux", "Malzahar", "Nocturne", "Orianna", "Ryze", "Shaco", "Riven", "Rengar", "Syndra", "Soraka", "Talon", "TwistedFate", "Veigar", "VelKoz", "Viktor", "Xerath", "Zed", "Ziggs"},
		[5] = {"Ashe", "Brand", "Caitlyn", "Draven", "Ezreal", "Jhin", "Jinx", "Kalista", "Khazix", "KogMaw", "Lucian", "MasterYi", "MissFortune", "Quinn", "Sivir", "Teemo", "Tristana", "Twitch", "Varus", "Vayne", "Xayah", "Yasuo", "Zoe"}
	}
	if noSubMenu then
		self.dtsmenu.dtsmain = self.dtsmenu
	else
		self.dtsmenu:menu("dtsmain", "Avada\'s Target Selector")
	end
	self.dtsmenu.dtsmain:header("title", "Avada\'s Target Selector")
	self.dtsmenu.dtsmain:menu("focusmenu", "Focus Target Settings")
	self.dtsmenu.dtsmain.focusmenu:boolean("focusselect", "Focus Selected Target", true)
	self.dtsmenu.dtsmain.focusmenu:boolean("drawww", "Draw Focused Target", true)
	self.dtsmenu.dtsmain.focusmenu:color("drawcolor", "Draw Color", 255, 0, 255, 255)
	self.dtsmenu.dtsmain:dropdown("damagetype", "Damage Type: ", self.damgType ,{"Physical", "Magical"})
	self.dtsmenu.dtsmain:dropdown("mode", "Targetting Mode", 2, {"Less Cast AD/AP + Priority", "Automatic", "Least Cast AD", "Least Cast AP", "Lowest HP", "Closest", "Closest to Mouse"})
	self.dts_prio = {}
	self.dtsmenu.dtsmain:header("kek", "--- Priority Settings ---")
	self.dtsmenu.dtsmain:header("kekk", "[Low] 1, 2, 3, 4, 5 [High]")
	for i=1, #enemies do
		local enemy = enemies[i]
		table.insert(self.dts_prio, {charname = enemy.charName})
		self.dtsmenu.dtsmain:slider(enemy.charName, enemy.charName, self:GetDBPriority(enemy.charName), 1, 5, 1)
	end
	cb.add(cb.tick, function() self:OnTick() end)
	cb.add(cb.draw, function() self:OnDraw() end)
	cb.add(cb.keydown, function(key) self:OnKeyDown(key) end)
end

function targetSelector:OnDraw()
	if self.dtsmenu.dtsmain.focusmenu.drawww:get() and self.dtsmenu.dtsmain.focusmenu.focusselect:get() then
		if self.target and avadaCommon.IsValidTarget(self.target) and self.target.isOnScreen then
			graphics.draw_circle(self.target.pos, self.target.boundingRadius, 3, self.dtsmenu.dtsmain.focusmenu.drawcolor:get(), 20)
		end
	end	
end

function targetSelector:closestEnemy(pos)
	local closestEnemy, distanceEnemy = nil, math.huge
	for i=1, #enemies do
		local hero = enemies[i]
		if hero and not hero.isDead and hero.isVisible then
			if pos:distSqr(hero.pos2D) < distanceEnemy then
				distanceEnemy = pos:distSqr(hero.pos2D)
				closestEnemy = hero
			end
		end
	end
	return closestEnemy, distanceEnemy
end

function targetSelector:OnKeyDown(key)
	if key == 1 and self.dtsmenu.dtsmain.focusmenu.focusselect:get() then
		local enemy, distance = self:closestEnemy(vec2.clone(game.mousePos2D))
		if distance < 62500 then -- 250
			if self.focus and avadaCommon.IsValidTarget(self.focus) and self.focus.networkID == enemy.networkID then
				self.focus = nil
			else
				self.focus = enemy
			end
		end
	end
end

function targetSelector:GetPriority(unit)
	local prio = 1
	for i=1, #self.dts_prio do
		if self.dts_prio[i].charname == unit.charName then
			prio = self.dtsmenu.dtsmain[unit.charName]:get()
		end
	end
	if prio == 2 then
		return 1.5
	elseif prio == 3 then
		return 1.75
	elseif prio == 4 then
		return 2
	elseif prio == 5 then
		return 2.5
	end
	return prio
end

function targetSelector:GetDBPriority(charname)
	for j = 1, 5 do
		for k = 1, #self.championTable[j] do
			if string.lower(self.championTable[j][k]) == string.lower(charname) then
				return j
			end
		end
	end
	return 1
end

local TSCalcDamage = function(sender, target, DamageType, value) 
	return DamageType == 1 and avadaCommon.CalculatePhysicalDamage(target, value, sender) or avadaCommon.CalculateMagicDamage(target, value, sender)
end

local modes = {
	[1] = function(a, b, c) -- less cast ad/ap priority
				return TSCalcDamage(myChamp, a, b, 100) / a.health * c
			end,
	[2] = function(a, b) -- auto
				return (1+(a.baseAttackDamage+a.flatPhysicalDamageMod)*(1+a.percentPhysicalDamageMod)*(1+a.crit)*a.attackSpeedMod*a.attackRange/425+a.flatMagicDamageMod*(1-a.percentCooldownMod)*a.percentMagicDamageMod) * TSCalcDamage(myChamp, a, b, 100)/(a.health+(b == 1 and a.physicalShield or a.allShield))
			end,
	[3] = function(a) -- least AA
				return TSCalcDamage(myChamp, a, 1, 100) / a.health
			end,
	[4] = function(a) -- least magic casts
				return TSCalcDamage(myChamp, a, 2, 100) / a.health
			end,
	[5] = function(a) -- least HP
				return a.health
			end,
	[6] = function(a, _, _, d) -- closest to self
				return d
			end,
	[7] = function(a) -- closest to mouse
				local mp = game.mousePos
				local dx, dz = (a.x - mp.x), (a.z - mp.z)
				return dx * dx + dz * dz
			end
}

function targetSelector:update(range, dmgType)
	dmgType = dmgType or self.dtsmenu.dtsmain.damagetype:get()
	if self.focus and avadaCommon.IsValidTarget(self.focus) and myChamp.pos2D:dist(self.focus.pos2D) < range + (self.addBBox and self.focus.boundingRadius+myChamp.boundingRadius or 0) then
		self.target = self.focus
		return
	end
	local mode = self.dtsmenu.dtsmain.mode:get()
	local threat = {}
	for i=1, #enemies do
		local hero = enemies[i]
		if hero and avadaCommon.IsValidTarget(hero) then
			local d = myChamp.pos2D:dist(hero.pos2D)
			if d < range + (self.addBBox and hero.boundingRadius + myChamp.boundingRadius or 0) then
				threat[hero.networkID] = modes[mode](hero, dmgType, self:GetPriority(hero), d)
			end
		end
	end
	self.target = nil
	for i=1, #enemies do
		local hero = enemies[i]
		if threat[hero.networkID] and mode <= 4 then
			self.target = not self.target and hero or (threat[self.target.networkID] < threat[hero.networkID] and hero or self.target)
		elseif threat[hero.networkID] and mode >= 5 then
            self.target = not self.target and hero or (threat[self.target.networkID] > threat[hero.networkID] and hero or self.target)
        end
	end
end

function targetSelector:OnTick()
	self:update(self.range, self.dtsmenu.dtsmain.damagetype:get())
end

----------------------------------------------------------------
-- End Target Selector Class
----------------------------------------------------------------
return targetSelector