
local ts = module.internal('TS')
local mainP = module.internal("pred")
local evade = module.seek("evade")
local orb = module.internal("orb")

local function GetTotalAD(obj)
  local obj = obj or player
  return (obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod
end

local function GetBonusAD(obj)
  local obj = obj or player
  return ((obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod) - obj.baseAttackDamage
end

local function GetTotalAP(obj)
  local obj = obj or player
  return obj.flatMagicDamageMod * obj.percentMagicDamageMod
end

local function PhysicalReduction(target, damageSource)
  local damageSource = damageSource or player
  local armor =
    ((target.bonusArmor * damageSource.percentBonusArmorPenetration) + (target.armor - target.bonusArmor)) *
    damageSource.percentArmorPenetration
  local lethality =
    (damageSource.physicalLethality * .4) + ((damageSource.physicalLethality * .6) * (damageSource.levelRef / 18))
  return armor >= 0 and (100 / (100 + (armor - lethality))) or (2 - (100 / (100 - (armor - lethality))))
end

local function MagicReduction(target, damageSource)
  local damageSource = damageSource or player
  local magicResist = (target.spellBlock * damageSource.percentMagicPenetration) - damageSource.flatMagicPenetration
  return magicResist >= 0 and (100 / (100 + magicResist)) or (2 - (100 / (100 - magicResist)))
end

local function DamageReduction(damageType, target, damageSource)
  local damageSource = damageSource or player
  local reduction = 1
  if damageType == "AD" then
  end
  if damageType == "AP" then
  end
  return reduction
end


local function CalculateAADamage(target, damageSource)
  local damageSource = damageSource or player
  if target then
    return GetTotalAD(damageSource) * PhysicalReduction(target, damageSource)
  end
  return 0
end


local function CalculatePhysicalDamage(target, damage, damageSource)
  local damageSource = damageSource or player
  if target then
    return (damage * PhysicalReduction(target, damageSource)) *
      DamageReduction("AD", target, damageSource)
  end
  return 0
end


local function CalculateMagicDamage(target, damage, damageSource)
  local damageSource = damageSource or player
  if target then
    return (damage * MagicReduction(target, damageSource)) * DamageReduction("AP", target, damageSource)
  end
  return 0
end

local function GetAARange(target)
  return player.attackRange + player.boundingRadius + (target and target.boundingRadius or 0)
end

local yasuoShield = {100, 105, 110, 115, 120, 130, 140, 150, 165, 180, 200, 225, 255, 290, 330, 380, 440, 510}
local function GetShieldedHealth(damageType, target)
local shield = 0
if damageType == "AD" then
  shield = target.physicalShield
elseif damageType == "AP" then
  shield = target.magicalShield
elseif damageType == "ALL" then
  shield = target.allShield
end
return target.health + shield
end


local function HasBuffType(obj, bufftype)
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

local function CheckBuff2(obj, buffname)
  if obj then
      for i = 0, obj.buffManager.count - 1 do
          local buff = obj.buffManager:get(i)
          if buff and buff.valid and buff.name:find(buffname) and (buff.stacks > 0 or buff.stacks2 > 0) then
              return true
          end 
      end 
  end
end

local function IsValidTarget(object)
  return (object and not object.isDead and object.isVisible and object.isTargetable and not HasBuffType(object, 17))
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

local function GetWHuman(target)
  if target ~= 0 then
  local Damage = 0
  local DamageAP = {40, 80, 120, 160, 200}
      if player:spellSlot(1).state == 0 then
    Damage = (DamageAP[player:spellSlot(1).level] + 0.2 * player.flatMagicDamageMod * player.percentMagicDamageMod)
      end
  return Damage
end
return 0
end


local function GetWCour(target)
  if target ~= 0 then
  local Damage = 0
  local DamageAP = {60, 110, 160, 21}
      if player:spellSlot(1).state == 0 then
    Damage = (DamageAP[player:spellSlot(3).level] + 0.3 * player.flatMagicDamageMod * player.percentMagicDamageMod)
      end
  return Damage
end
return 0
end


local function class()
	local cls = {}
	cls.__index = cls
	return setmetatable(cls, { __call = function (c, ...)
		local instance = setmetatable({}, cls)
		if cls.__init then
			cls.__init(instance, ...)
		end
		return instance
	end})
end

local TargetSelection = function(res, obj, dist)
	if dist > 1000 then
		res.obj = obj
		return true
	end
end

local GetTarget = function()
	return ts.get_result(TargetSelection).obj
end


local avadaNid = class()

function avadaNid:__init()
	self.menu = menu("nidaavada", "[Nicky]Nidalee")
	self.menu:header("title", "Avada Nidalee")
	self.menu:dropdown("pSet", "Prediction:", 1, {"Core", "Nebelwolfi"})
	self.menu:keybind("flee", "Flee/Kite to Mouse", "T", false)
	self.menu:menu("combo", "Combo Settings")
	self.menu:menu("harass", "Harass Settings")
	self.menu:menu("farm", "Farm/Jungle Settings")
	self.menu:menu("heal", "Heal Settings")
	self.menu:menu("misc", "Misc. Settings")
	self.menu:menu("draws", "Draw Settings")

	-- Combo section
	self.menu.combo:header("title", "Combo Settings")
	self.menu.combo:menu("human", "Human Spells")
	self.menu.combo.human:boolean("useQ", "Use Q", true)
	self.menu.combo.human:boolean("useW", "Use W", true)
	self.menu.combo:menu("cougar", "Cougar Spells")
	self.menu.combo.cougar:boolean("useQ", "Use Q", true)
	self.menu.combo.cougar:boolean("useW", "Use W", true)
	self.menu.combo.cougar:boolean("useE", "Use E", true)
	self.menu.combo:boolean("useR", "Use R", true)

	-- Harass section
	self.menu.harass:header("title", "Harass Settings")
	self.menu.harass:header("info", "[Human Only]")
	self.menu.harass:boolean("useQ", "Use Q", true)
	self.menu.harass:slider("mana", "Mana Limit %", 30, 10, 100, 5)

	-- Farm/Jungle section --
	self.menu.farm:header("title", "Farm/Jungle Settings")
	self.menu.farm:menu("human", "Human Spells")
	self.menu.farm.human:boolean("useQ", "Use Q", true)
	self.menu.farm.human:boolean("useW", "Use W", true)
	self.menu.farm:menu("cougar", "Cougar Spells")
	self.menu.farm.cougar:boolean("useQ", "Use Q", true)
	self.menu.farm.cougar:boolean("useW", "Use W", true)
	self.menu.farm.cougar:boolean("useE", "Use E", true)
	self.menu.farm:boolean("autoR", "Auto Switch Form", true)
	self.menu.farm:slider("mana", "Mana Limit %", 30, 10, 100, 5)

	-- Heal section
	self.menu.heal:header("title", "Heal Settings")
	self.menu.heal:header("info1", "- - - Self - - -")
	self.menu.heal:boolean("useSelf", "Use E to Heal", true)
	self.menu.heal:slider("manaSelf", "Heal if Mana % >", 40, 10, 100, 5)
	self.menu.heal:slider("hpSelf", "Heal if HP % <", 60, 10, 100, 5)
	self.menu.heal:header("info2", "- - - Ally - - -")
	self.menu.heal:boolean("useAlly", "Use E to Heal", true)
	self.menu.heal:slider("manaAlly", "Heal if Mana % >", 60, 10, 100, 5)
	self.menu.heal:slider("hpAlly", "Heal if HP % <", 50, 10, 100, 5)
	self.menu.heal:header("info3", "- - - - - - - -")
	self.menu.heal:boolean("autoR", "Auto Switch Form", true)

	-- Misc section
	self.menu.misc:header("title", "Misc. Settings")
	self.menu.misc:boolean("killsteal", "KS with Spear", true)

	-- Draw section
	self.menu.draws:header("title", "Draw Settings")
	self.menu.draws:boolean("drawCD", "Draw Cooldowns", true)
	self.menu.draws:menu("human", "Human Draw Settings")
	self.menu.draws.human:color("colors", "Color", 255, 0, 255, 150)
	self.menu.draws.human:boolean("drawQ", "Draw Q Range", true)
	self.menu.draws.human:boolean("drawW", "Draw W Range", false)
	self.menu.draws.human:boolean("drawE", "Draw E Range", false)
	self.menu.draws:menu("cougar", "Cougar Draw Settings")
	self.menu.draws.cougar:color("colors", "Color", 255, 0, 0, 150)
	self.menu.draws.cougar:boolean("drawQ", "Draw Q Range", false)
	self.menu.draws.cougar:boolean("drawW", "Draw W Range", false)
	self.menu.draws.cougar:boolean("drawE", "Draw E Range", true)

	
	self.CDTracker = {
		["Human"] = {
			[0] = { CD = player:spellSlot(0).cooldown <= 0 and 6 or player:spellSlot(0).cooldown, CDT = 0, T = 0, ready = false, name = "JavelinToss" },
			[1] = { CD = player:spellSlot(1).cooldown <= 0 and 13 or player:spellSlot(1).cooldown, CDT = 0, T = 0, ready = false, name = "Bushwhack" },
			[2] = { CD = player:spellSlot(2).cooldown <= 0 and 12 or player:spellSlot(2).cooldown, CDT = 0, T = 0, ready = false, name = "PrimalSurge" }
		},
		["Cougar"] = {
			[0] = { CD = player:spellSlot(0).cooldown <= 0 and 6 or player:spellSlot(0).cooldown, CDT = 0, T = 0, ready = false, name = "Takedown" },
			[1] = { CD = player:spellSlot(1).cooldown <= 0 and 6 or player:spellSlot(1).cooldown, CDT = 0, T = 0, ready = false, name = "Pounce" },
			[2] = { CD = player:spellSlot(2).cooldown <= 0 and 6 or player:spellSlot(2).cooldown, CDT = 0, T = 0, ready = false, name = "Swipe" }
		}
	}

	self.spells = {
		["Human"] = {
			[0] = {
				slot = player:spellSlot(0),
				range = 1500,
				cpre = { width = 40, delay = 0.25, speed = 1300, boundingRadiusMod = 1, collision = { hero = true, minion = true } },
				--apre = aPred.new_data{delay = 0.25, radius = 50, speed = 1300, collision = bit.bor(11), addBoundingRadius = true}
			}, --collision = aPred.enum.collisionType.minion | aPred.enum.collisionType.champion | aPred.enum.collisionType.yasuoWall
			[1] = {
				slot = player:spellSlot(1),
				range = 900,
				cpre = { delay = 1, radius = 80, speed = math.huge, boundingRadiusMod = 0 }
			},
			[2] = {
				slot = player:spellSlot(2),
				range = 600
			},
			[3] = {
				slot = player:spellSlot(3)
			}
		},
		["Cougar"] = {
			[0] = { slot = player:spellSlot(0), range = 200 },
			[1] = { slot = player:spellSlot(1), range = 375 },
			[2] = { slot = player:spellSlot(2), range = 300 },
			[3] = { slot = player:spellSlot(3) }
		}
	}
	
	--initialize callbacks
  orb.combat.register_f_pre_tick(function()
    local target = GetTarget()
    if target and target.pos:dist(player.pos) < GetAARange(target) then
      orb.combat.target = target
    end
    self:OnTick()
    return false
  end)

	cb.add(cb.spell, function(spell) self:OnProcessSpell(spell) end)
	cb.add(cb.draw, function() self:OnDraw() end)

end

local function roundNum(num, idp)
	local mult = 10 ^ (idp or 0)
	if num >= 0 then
		return math.floor(num * mult + 0.5) / mult
	else
		return math.ceil(num * mult - 0.5) / mult
	end
end

local function isHuman()
	return player:spellSlot(0).name == "JavelinToss"
end

local function isHunted(unit)
	return CheckBuff(unit, "NidaleePassiveHunted")
end

function avadaNid:Cooldowns()
	for i = 0, 2, 1 do
		if player:spellSlot(i).level > 0 then
			self.CDTracker.Human[i].T = self.CDTracker.Human[i].CDT + self.CDTracker.Human[i].CD - game.time
			self.CDTracker.Cougar[i].T = self.CDTracker.Cougar[i].CDT + self.CDTracker.Cougar[i].CD - game.time
			
			if self.CDTracker.Human[i].T <= 0 then
				self.CDTracker.Human[i].ready = true
				self.CDTracker.Human[i].T = 0
			else
				self.CDTracker.Human[i].ready = false
			end
			
			if self.CDTracker.Cougar[i].T <= 0 then
				self.CDTracker.Cougar[i].ready = true
				self.CDTracker.Cougar[i].T = 0
			else
				self.CDTracker.Cougar[i].ready = false
			end
		end
	end
end

function avadaNid:GetQDmg(unit, poss)
	if player:spellSlot(0).level < 1 or not unit or unit.isDead or not unit.isVisible or not unit.isTargetable or HasBuffType(unit, 17) then return 0 end
	-- default + (25% per 96.875 units traveled) capped at 200% at 1300 units
	-- 525 = default, 621.875 = 25%, 718.75 = 50%, 815.625 = 75%, 912.5 = 100%, 1009.375 = 125%, 1106.25 = 150%, 1203.125 = 175%, 1300 = 200%
	local d = poss and player.path.serverPos:dist(poss) or player.path.serverPos:dist(unit.path.serverPos)
	local pctIncrease = 1
	if d >= 622 then
		if d >= 1300 then
			pctIncrease = 3
		else
			local hold = (d - 525) / 96.875
			pctIncrease = ({ 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3 })[math.floor(hold)]
		end
	end
	local damage = (({ 70, 85, 100, 115, 130 })[player:spellSlot(0).level] + (0.4 * GetTotalAP())) * pctIncrease
	return CalculateMagicDamage(unit, damage)
end

function avadaNid:FleeKiteLogic()
	player:move(game.mousePos)
	local target = GetTarget()
  if target then
    local dist = player.path.serverPos:dist(target.path.serverPos)
    local Qlevel = player:spellSlot(0).level
    local manaSpear = Qlevel > 0 and ({ 50, 60, 70, 80, 90 })[Qlevel] or 0
    if isHuman() then
      if player:spellSlot(0).state == 0 and IsValidTarget(target) and dist < 1500 then
        if self.menu.pSet:get() == 1 or self.menu.pSet:get() == 2 then
          local seg = mainP.linear.get_prediction(self.spells.Human[0].cpre, target)
          if seg and seg.startPos:dist(seg.endPos) < self.spells.Human[0].range then
            local col = mainP.collision.get_prediction(self.spells.Human[0].cpre, seg, target)
            if not col and self.spells.Human[0].slot.state == 0 then
              player:castSpell("pos", 0, vec3(seg.endPos.x, target.y, seg.endPos.y))
            end
          end
        --[[elseif IsValidTarget(target) and self.menu.pSet:get() == 2 then
          local p = aPred.get(target, self.spells.Human[0].apre)
          if IsValidTarget(target) and p and p.pos:dist(player.pos) < self.spells.Human[0].range and not p:collision(0) and self.spells.Human[0].slot.state == 0 then
            game.cast("pos", 0, p.pos)
          end]]
        end
      elseif (player:spellSlot(0).state ~= 0 or not IsValidTarget(target) or (IsValidTarget(target) and dist >= 1500)) and player:spellSlot(3).state == 0 then
        player:castSpell("self", 3)
        -- change to cougar
      end
    end
    if not isHuman() then
      if self.CDTracker.Human[0].ready == true and IsValidTarget(target) and player:spellSlot(3).state == 0 and player.par >= manaSpear then
        if IsValidTarget(target) and dist < 1500 then
          player:castSpell("self", 3)
        end
        -- change to human to spear
      elseif player:spellSlot(1).state == 0 then
        if self.CDTracker.Human[0].ready == false or player:spellSlot(3).state ~= 0 or not IsValidTarget(target) or player.par < manaSpear or (IsValidTarget(target) and dist >= 1500) then
          local jumpPos = player.pos + (game.mousePos - player.pos):norm() * 400
          player:castSpell("pos", 1, jumpPos)
          -- cast W to mouse
        end
      end
    end
  end
end

function avadaNid:farming()
	local manaCheck = GetPercentPar() > self.menu.farm.mana:get()
  local minions = objManager.minions
  for i = 0, minions.size[TEAM_ENEMY] - 1 do
    local minion = minions[TEAM_ENEMY][i]
		if minion and not minion.isDead and minion.isVisible and minion.isTargetable and not HasBuffType(minion, 17) and minion.baseAttackDamage > 5 then
      local dist = player.path.serverPos:dist(minion.path.serverPos)
      if not isHuman() then
        if self.menu.farm.cougar.useQ:get() and self.spells.Cougar[0].slot.state == 0 and dist <= 400 then
          player:castSpell("self", 0)
        end
        if self.menu.farm.cougar.useW:get() and self.spells.Cougar[1].slot.state == 0 then
          if dist <= self.spells.Cougar[1].range and (GetWCour(minion) + CalculateAADamage(minion)) > minion.health then
            player:castSpell("pos", 1, minion.pos)
          end
        end
        if self.menu.farm.cougar.useE:get() and self.spells.Cougar[2].slot.state == 0 then
          if dist < (self.spells.Cougar[2].range + minion.boundingRadius) then
            player:castSpell("pos", 2, minion.pos)
          end
        end
        if self.menu.farm.autoR:get() and player:spellSlot(3).state == 0 then
          if self.spells.Cougar[0].slot.state ~= 0 and self.spells.Cougar[1].slot.state ~= 0 and self.spells.Cougar[2].slot.state ~= 0 and manaCheck then
            player:castSpell("self", 3)
          end
        end
      end
      if isHuman() then
        if self.menu.farm.human.useQ:get() and self.spells.Human[0].slot.state == 0 and manaCheck and dist <= self.spells.Human[0].range then
          if self.menu.pSet:get() == 1 or self.menu.pSet:get() == 2 then
            local seg = mainP.linear.get_prediction(self.spells.Human[0].cpre, minion)
            if seg and seg.startPos:dist(seg.endPos) < self.spells.Human[0].range then
              local col = mainP.collision.get_prediction(self.spells.Human[0].cpre, seg, minion)
              if not col then
                player:castSpell("pos", 0, vec3(seg.endPos.x, minion.y, seg.endPos.y))
              end
            end
          --[[elseif can_target_minion(minion) and self.menu.pSet:get() == 2 then
            local p = aPred.get(minion, self.spells.Human[0].apre)
            if can_target_minion(minion) and p and p.pos:dist(player.pos) < self.spells.Human[0].range and not p:collision(0) then
              game.cast("pos", 0, p.pos)
            end]]
          end
        end
        if self.menu.farm.human.useW:get() and self.spells.Human[1].slot.state == 0 and dist < self.spells.Human[1].range and manaCheck then
          if GetWHuman(minion) > minion.health and not minion.path.isActive then
            player:castSpell("pos", 1, minion.pos)
          end
        end
        if self.menu.farm.autoR:get() and player:spellSlot(3).state == 0 and (self.spells.Human[0].slot.state ~= 0 or not manaCheck or not self.menu.farm.human.useQ:get()) then
          player:castSpell("self", 3)
        end
      end
    end
	end
end

function avadaNid:GetClosestJungleMob()
	local closestMob, distanceMob = nil, math.huge
  local minions = objManager.minions
  for i = 0, minions.size[TEAM_NEUTRAL] - 1 do
    local check = minions[TEAM_NEUTRAL][i]
		if check and not check.isDead and check.isVisible then
			local mobDist = player.path.serverPos:dist(check.path.serverPos)
			if mobDist < distanceMob then
				distanceMob = mobDist
				closestMob = check
			end
		end
	end
	return closestMob
end

function avadaNid:jungling()
	local manaCheck = GetPercentPar() > self.menu.farm.mana:get()
  local minions = objManager.minions
  for i = 0, minions.size[TEAM_NEUTRAL] - 1 do
    local minion = minions[TEAM_NEUTRAL][i]
		if minion and not minion.isDead and minion.isVisible and minion.isTargetable and not HasBuffType(minion, 17) and minion.baseAttackDamage > 5 then
      local dist = player.path.serverPos:dist(minion.path.serverPos)
      if not isHuman() then
        if self.menu.farm.cougar.useQ:get() and self.spells.Cougar[0].slot.state == 0 and dist <= 400 then
          player:castSpell("self", 0)
        end
        if self.menu.farm.cougar.useW:get() and self.spells.Cougar[1].slot.state == 0 then
          if dist <= 750 and isHunted(minion) then
            player:castSpell("pos", 1, minion.pos)
          elseif dist <= self.spells.Cougar[1].range then
            player:castSpell("pos", 1, minion.pos)
          end
        end
        if self.menu.farm.cougar.useE:get() and self.spells.Cougar[2].slot.state == 0 then
          if dist < (self.spells.Cougar[2].range + minion.boundingRadius) then
            player:castSpell("pos", 2, minion.pos)
          end
        end
        if self.menu.farm.autoR:get() and player:spellSlot(3).state == 0 and manaCheck then
          if self.spells.Cougar[0].slot.state ~= 0 and self.spells.Cougar[1].slot.state ~= 0 and self.spells.Cougar[2].slot.state ~= 0 then
            player:castSpell("self", 3)
          end
        end
      end
      if isHuman() then
        if self.menu.farm.human.useQ:get() and self.spells.Human[0].slot.state == 0 and manaCheck then
          local closeMob = self:GetClosestJungleMob()
          if closeMob and closeMob.ptr == minion.ptr and dist <= self.spells.Human[0].range then
            if self.menu.pSet:get() == 1 or self.menu.pSet:get() == 2 then
              local seg = mainP.linear.get_prediction(self.spells.Human[0].cpre, minion)
              if seg and seg.startPos:dist(seg.endPos) < self.spells.Human[0].range then
                local col = mainP.collision.get_prediction(self.spells.Human[0].cpre, seg, minion)
                if not col then
                  player:castSpell("pos", 0, vec3(seg.endPos.x, minion.y, seg.endPos.y))
                end
              end
            --[[elseif can_target_minion(minion) and self.menu.pSet:get() == 2 then
              local p = aPred.get(minion, self.spells.Human[0].apre)
              if can_target_minion(minion) and p and p.pos:dist(player.pos) < self.spells.Human[0].range and not p:collision(0) then
                game.cast("pos", 0, p.pos)
              end]]
            end
          end
        end
        if self.menu.farm.human.useW:get() and self.spells.Human[1].slot.state == 0 then
          if dist < self.spells.Human[1].range and manaCheck and not isHunted(minion) and not minion.path.isActive then
            player:castSpell("pos", 1, minion.pos)
          end
        end
        if self.menu.farm.autoR:get() and player:spellSlot(3).state == 0 then
          if not self.menu.farm.human.useQ:get() or self.spells.Human[0].slot.state ~= 0 or not manaCheck then
            player:castSpell("self", 3)
          end
        end
      end
    end
	end
end

function avadaNid:healing()
	if player.isRecalling or player.isDead then return end
	if self.CDTracker.Human[2].ready == true then
		if self.menu.heal.useSelf:get() and GetPercentHealth() < self.menu.heal.hpSelf:get() and GetPercentPar() > self.menu.heal.manaSelf:get() then
			if isHuman() and player:spellSlot(2).state == 0 then
				player:castSpell("self", 2)
			end
			if not isHuman() and self.menu.heal.autoR:get() and player:spellSlot(3).state == 0 and not orb.combat.is_active() and not orb.menu.lane_clear:get() then
				player:castSpell("self", 3)
        orb.core.set_server_pause()
				player:castSpell("self", 2)
			end
		end
		if self.menu.heal.useAlly:get() and GetPercentPar() > self.menu.heal.manaAlly:get() then
      for i = 0, objManager.allies_n - 1 do
        local ally = objManager.allies[i]
				if ally and not ally.isDead and ally.isVisible and not HasBuffType(ally, 17) then
          local dist = player.path.serverPos:dist(ally.path.serverPos)
          if dist <= 600 and GetPercentHealth(ally) < self.menu.heal.hpAlly:get() then
            if isHuman() and player:spellSlot(2).state == 0 then
              player:castSpell("obj", 2, ally)
            end
            if not isHuman() and self.menu.heal.autoR:get() and player:spellSlot(3).state == 0 and not orb.combat.is_active() and not orb.menu.lane_clear:get() then
              player:castSpell("self", 3)
              orb.core.set_server_pause()
              player:castSpell("obj", 2, ally)
            end
          end
				end
			end
		end
	end
end

function avadaNid:KS()
	if not self.menu.misc.killsteal:get() or player:spellSlot(0).level < 1 or self.CDTracker.Human[0].ready == false then return end
  for i = 0, objManager.enemies_n - 1 do
    local enemy = objManager.enemies[i]
    if enemy and IsValidTarget(enemy) and enemy.pos:dist(player.pos) <= 1500 then
      if isHuman() and player:spellSlot(0).state == 0 and self.CDTracker.Human[0].ready == true then
        if self:GetQDmg(enemy) > GetShieldedHealth("AP", enemy) then
          if self.menu.pSet:get() == 1 or self.menu.pSet:get() == 2 then
            local seg = mainP.linear.get_prediction(self.spells.Human[0].cpre, enemy)
            if seg and seg.startPos:dist(seg.endPos) <= self.spells.Human[0].range then
              local col = mainP.collision.get_prediction(self.spells.Human[0].cpre, seg, enemy)
              if not col and self:GetQDmg(enemy, vec3(seg.endPos.x, enemy.y, seg.endPos.y)) > GetShieldedHealth("AP", enemy) then
                player:castSpell("pos", 0, vec3(seg.endPos.x, enemy.y, seg.endPos.y))
              end
            end
          --[[elseif IsValidTarget(e) and self.menu.pSet:get() == 2 then
            local p = aPred.get(e, self.spells.Human[0].apre)
            if IsValidTarget(e) and p and p.pos:dist(player.pos) <= self.spells.Human[0].range and not p:collision(0) and self.spells.Human[0].slot.state == 0 and self:GetQDmg(e, p.pos) > GetShieldedHealth("ap", e) then
              game.cast("pos", 0, p.pos)
            end]]
          end
        end
      end
    end
  end
end

function avadaNid:Harass()
	if GetPercentPar() < self.menu.harass.mana:get() or not isHuman() then return end
	if self.menu.harass.useQ:get() and isHuman() and player:spellSlot(0).state == 0 then
		local target = GetTarget()
		if target and IsValidTarget(target) and target.pos:dist(player.pos) <= 1500 then
			if self.menu.pSet:get() == 1 or self.menu.pSet:get() == 2 then
				local seg = mainP.linear.get_prediction(self.spells.Human[0].cpre, target)
				if seg and seg.startPos:dist(seg.endPos) <= self.spells.Human[0].range then
					local col = mainP.collision.get_prediction(self.spells.Human[0].cpre, seg, target)
					if not col and self.spells.Human[0].slot.state == 0 then
						player:castSpell("pos", 0, vec3(seg.endPos.x, target.y, seg.endPos.y))
					end
				end
			--[[elseif IsValidTarget(target) and self.menu.pSet:get() == 2 then
				local p = aPred.get(target, self.spells.Human[0].apre)
				if IsValidTarget(target) and p and p.pos:dist(player.pos) <= self.spells.Human[0].range and not p:collision(0) and self.spells.Human[0].slot.state == 0 then
					game.cast("pos", 0, p.pos)
				end]]
			end
		end
	end
end

function avadaNid:Combo()
	local target = GetTarget()
	if orb.combat.target then
		target = orb.combat.target
	end
  if target and IsValidTarget(target) then
    local dist = player.path.serverPos:dist(target.path.serverPos)
    if isHuman() then
      if self.menu.combo.human.useQ:get() and self.spells.Human[0].slot.state == 0 and dist <= 1500 then
        if self.menu.pSet:get() == 1 or self.menu.pSet:get() == 2 then
          local seg = mainP.linear.get_prediction(self.spells.Human[0].cpre, target)
          if seg and seg.startPos:dist(seg.endPos) <= self.spells.Human[0].range then
            local col = mainP.collision.get_prediction(self.spells.Human[0].cpre, seg, target)
            if not col then
              player:castSpell("pos", 0, vec3(seg.endPos.x, game.mousePos.y, seg.endPos.y))
            end
          end
        --[[elseif IsValidTarget(target) and self.menu.pSet:get() == 2 then
          local p = aPred.get(target, self.spells.Human[0].apre)
          if IsValidTarget(target) and p and p.pos:dist(player.pos) <= self.spells.Human[0].range and not p:collision(0) and self.spells.Human[0].slot.state == 0 then
            game.cast("pos", 0, p.pos)
          end]]
        end
      end
      if self.menu.combo.human.useW:get() and self.spells.Human[1].slot.state == 0 then
        if dist <= self.spells.Human[1].range then
          local seg = mainP.circular.get_prediction(self.spells.Human[1].cpre, target)
          if seg and seg.startPos:dist(seg.endPos) <= self.spells.Human[1].range then
            player:castSpell("pos", 1, vec3(seg.endPos.x, target.y, seg.endPos.y))
          end
        end
      end
      if self.menu.combo.useR:get() and player:spellSlot(3).state == 0 then
        if dist <= 375 or (isHunted(target) and dist <= 750 and self.CDTracker.Cougar[1].ready == true) then
          player:castSpell("self", 3)
        end
      end
    end
    if not isHuman() then
      if self.menu.combo.cougar.useW:get() and player:spellSlot(1).state == 0 then
        if isHunted(target) and dist <= 750 then
          player:castSpell("pos", 1, target.pos)
        elseif dist <= self.spells.Cougar[1].range then
          player:castSpell("pos", 1, target.pos)
        end
      end
      if self.menu.combo.cougar.useE:get() and player:spellSlot(2).state == 0 then
        if dist < (self.spells.Cougar[2].range + target.boundingRadius) then
          player:castSpell("pos", 2, target.pos)
        end
      end
      if self.menu.combo.cougar.useQ:get() and player:spellSlot(0).state == 0 and dist < 400 then
        player:castSpell("self", 0)
        orb.core.reset()
      end
      if self.menu.combo.useR:get() and player:spellSlot(3).state == 0 then
        local Qlevel = player:spellSlot(0).level
        local manaSpear = Qlevel > 0 and ({ 50, 60, 70, 80, 90 })[Qlevel] or 0
        if isHunted(target) and dist > 750 and player.par >= manaSpear and self.CDTracker.Human[0].ready == true then
          player:castSpell("self", 3)
        elseif dist > 375 then
          player:castSpell("self", 3)
        elseif player:spellSlot(0).state ~= 0 and player:spellSlot(1).state ~= 0 and player:spellSlot(2).state ~= 0 then
          if player.par >= manaSpear and self.CDTracker.Human[0].ready == true then
            player:castSpell("self", 3)
          end
        end
      end
    end
  end
end

function avadaNid:OnProcessSpell(spell)
	if spell.owner.ptr == player.ptr and not spell.isBasicAttack then
		for i = 0, 2, 1 do
			if spell.name == self.CDTracker.Human[i].name then
				self.CDTracker.Human[i].CDT = game.time
			elseif spell.name == self.CDTracker.Cougar[i].name then
				self.CDTracker.Cougar[i].CDT = game.time
			end
		end
	end
end

function avadaNid:OnDraw()
	if not player.isDead and player.isOnScreen then
    if self.menu.draws.drawCD:get() then
      local wtspos = graphics.world_to_screen(player.pos)
      if isHuman() then
        for i = 0, 2 do
          local slot = ({ "Q", "W", "E" })[(i + 1)]
          local color = self.CDTracker.Cougar[i].ready == true and graphics.argb(255, 0, 255, 10) or graphics.argb(255, 255, 0, 0)
          graphics.draw_text_2D(tostring(slot)..": "..tostring(roundNum(self.CDTracker.Cougar[i].T > 0 and self.CDTracker.Cougar[i].T or 0)), 20, (wtspos.x - 60 + (i * 40)), (wtspos.y + 50), color)
        end
      else
        for i = 0, 2 do
          local slot = ({ "Q", "W", "E" })[(i + 1)]
          local color = self.CDTracker.Human[i].ready == true and graphics.argb(255, 0, 255, 10) or graphics.argb(255, 255, 0, 0)
          graphics.draw_text_2D(tostring(slot)..": "..tostring(roundNum(self.CDTracker.Human[i].T > 0 and self.CDTracker.Human[i].T or 0)), 20, (wtspos.x - 60 + (i * 40)), (wtspos.y + 50), color)
        end
      end
    end
    if isHuman() then
      if self.menu.draws.human.drawQ:get() then
        graphics.draw_circle(player.pos, self.spells.Human[0].range, 2, self.menu.draws.human.colors:get(), 40)
      end
      if self.menu.draws.human.drawW:get() then
        graphics.draw_circle(player.pos, self.spells.Human[1].range, 2, self.menu.draws.human.colors:get(), 40)
      end
      if self.menu.draws.human.drawE:get() then
        graphics.draw_circle(player.pos, self.spells.Human[2].range, 2, self.menu.draws.human.colors:get(), 40)
      end
    else
      if self.menu.draws.cougar.drawQ:get() then
        graphics.draw_circle(player.pos, self.spells.Cougar[0].range, 2, self.menu.draws.cougar.colors:get(), 40)
      end
      if self.menu.draws.cougar.drawW:get() then
        graphics.draw_circle(player.pos, self.spells.Cougar[1].range, 2, self.menu.draws.cougar.colors:get(), 40)
      end
      if self.menu.draws.cougar.drawE:get() then
        graphics.draw_circle(player.pos, self.spells.Cougar[2].range, 2, self.menu.draws.cougar.colors:get(), 40)
      end
    end
  end
end

function avadaNid:OnTick()
	if player.isDead or (evade and evade.core.is_active()) then return end
	self:Cooldowns()
	if self.menu.flee:get() then
		self:FleeKiteLogic()
	elseif orb.combat.is_active() then
		self:Combo()
	elseif orb.menu.hybrid:get() then
		self:Harass()
	elseif orb.menu.lane_clear:get() then
		self:farming()
		self:jungling()
	end
	self:KS()
  self:healing()
 
end -- NidaleePassiveHunted

--Execute the Class
if player.charName == "Nidalee" then
	avadaNid()
end