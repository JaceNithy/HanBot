local pred = module.internal("pred")

local libss = {}

-- Delay Functions Call
local delayedActions, delayedActionsExecuter = {}, nil
function libss.DelayAction(func, delay, args) --delay in seconds
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

local _intervalFunction
function libss.SetInterval(userFunction, timeout, count, params)
  if not _intervalFunction then
    function _intervalFunction(userFunction, startTime, timeout, count, params)
      if userFunction(unpack(params or {})) ~= false and (not count or count > 1) then
        libss.DelayAction(
          _intervalFunction,
          (timeout - (os.clock() - startTime - timeout)),
          {userFunction, startTime + timeout, timeout, count and (count - 1), params}
        )
      end
    end
  end
  libss.DelayAction(_intervalFunction, timeout, {userFunction, os.clock(), timeout or 0, count, params})
end

-- Print Function
function libss.print(msg, color)
  local color = color or 42
  console.set_color(color)
  print(msg)
  console.set_color(15)
end

-- Returns percent health of @obj or player
function libss.GetPercentHealth(obj)
  local obj = obj or player
  return (obj.health / obj.maxHealth) * 100
end

-- Returns percent mana of @obj or player
function libss.GetPercentMana(obj)
  local obj = obj or player
  return (obj.mana / obj.maxMana) * 100
end

-- Returns percent par (mana, energy, etc) of @obj or player
function libss.GetPercentPar(obj)
  local obj = obj or player
  return (obj.par / obj.maxPar) * 100
end

function libss.CheckBuffType(obj, bufftype)
  if obj then
    for i = 0, obj.buffManager.count - 1 do
      local buff = obj.buffManager:get(i)
      if buff and buff.valid and buff.type == bufftype and (buff.stacks > 0 or buff.stacks2 > 0) then
        return true
      end
    end
  end
end
-- Returns @target health+shield
local yasuoShield = {100, 105, 110, 115, 120, 130, 140, 150, 165, 180, 200, 225, 255, 290, 330, 380, 440, 510}
function libss.GetShieldedHealth(damageType, target)
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

-- Returns total AD of @obj or player
function libss.GetTotalAD(obj)
  local obj = obj or player
  return (obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod
end

-- Returns bonus AD of @obj or player
function libss.GetBonusAD(obj)
  local obj = obj or player
  return ((obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod) - obj.baseAttackDamage
end

-- Returns total AP of @obj or player
function libss.GetTotalAP(obj)
  local obj = obj or player
  return obj.flatMagicDamageMod * obj.percentMagicDamageMod
end

-- Returns physical damage multiplier on @target from @damageSource or player
function libss.PhysicalReduction(target, damageSource)
  local damageSource = damageSource or player
  local armor =
    ((target.bonusArmor * damageSource.percentBonusArmorPenetration) + (target.armor - target.bonusArmor)) *
    damageSource.percentArmorPenetration
  local lethality =
    (damageSource.physicalLethality * .4) + ((damageSource.physicalLethality * .6) * (damageSource.levelRef / 18))
  return armor >= 0 and (100 / (100 + (armor - lethality))) or (2 - (100 / (100 - (armor - lethality))))
end

-- Returns magic damage multiplier on @target from @damageSource or player
function libss.MagicReduction(target, damageSource)
  local damageSource = damageSource or player
  local magicResist = (target.spellBlock * damageSource.percentMagicPenetration) - damageSource.flatMagicPenetration
  return magicResist >= 0 and (100 / (100 + magicResist)) or (2 - (100 / (100 - magicResist)))
end

-- Returns damage reduction multiplier on @target from @damageSource or player
function libss.DamageReduction(damageType, target, damageSource)
  local damageSource = damageSource or player
  local reduction = 1
  -- Ryan Fix Please ♥
  if damageType == "AD" then
  end
  if damageType == "AP" then
  end
  return reduction
end

-- Calculates AA damage on @target from @damageSource or player
function libss.CalculateAADamage(target, damageSource)
  local damageSource = damageSource or player
  if target then
    return libss.GetTotalAD(damageSource) * libss.PhysicalReduction(target, damageSource)
  end
  return 0
end

-- Calculates physical damage on @target from @damageSource or player
function libss.CalculatePhysicalDamage(target, damage, damageSource)
  local damageSource = damageSource or player
  if target then
    return (damage * libss.PhysicalReduction(target, damageSource)) *
      libss.DamageReduction("AD", target, damageSource)
  end
  return 0
end

-- Calculates magic damage on @target from @damageSource or player
function libss.CalculateMagicDamage(target, damage, damageSource)
  local damageSource = damageSource or player
  if target then
    return (damage * libss.MagicReduction(target, damageSource)) * libss.DamageReduction("AP", target, damageSource)
  end
  return 0
end

-- Returns @target attack range (@target is optional; will consider @target boundingRadius into calculation)
function libss.GetAARange(target)
  return player.attackRange + player.boundingRadius + (target and target.boundingRadius or 0)
end

-- Returns @obj predicted pos after @delay secs
function libss.GetPredictedPos(obj, delay)
  if not libss.IsValidTarget(obj) or not obj.path or not delay or not obj.moveSpeed then
    return obj
  end
  local pred_pos = pred.core.lerp(obj.path, network.latency + delay, obj.moveSpeed)
  return vec3(pred_pos.x, player.y, pred_pos.y)
end

-- Returns ignite damage
function libss.GetIgniteDamage(target)
  local damage = 55 + (25 * player.levelRef)
  if target then
    damage = damage - (libss.GetShieldedHealth("AD", target) - target.health)
  end
  return damage
end

libss.enum = {}
libss.enum.slots = {
  q = 0,
  w = 1,
  e = 2,
  r = 3
}
libss.enum.buff_types = {
  Internal = 0,
  Aura = 1,
  CombatEnchancer = 2,
  CombatDehancer = 3,
  SpellShield = 4,
  Stun = 5,
  Invisibility = 6,
  Silence = 7,
  Taunt = 8,
  Polymorph = 9,
  Slow = 10,
  Snare = 11,
  Damage = 12,
  Heal = 13,
  Haste = 14,
  SpellImmunity = 15,
  PhysicalImmunity = 16,
  Invulnerability = 17,
  AttackSpeedSlow = 18,
  NearSight = 19,
  Currency = 20,
  Fear = 21,
  Charm = 22,
  Poison = 23,
  Suppression = 24,
  Blind = 25,
  Counter = 26,
  Shred = 27,
  Flee = 28,
  Knockup = 29,
  Knockback = 30,
  Disarm = 31,
  Grounded = 32,
  Drowsy = 33,
  Asleep = 34
}

-- Returns true if @unit has buff.type btype

local hard_cc = {
  [5] = true, -- stun
  [8] = true, -- taunt
  [11] = true, -- snare
  [18] = true, -- sleep
  [21] = true, -- fear
  [22] = true, -- charm
  [24] = true, -- suppression
  [28] = true, -- flee
  [29] = true, -- knockup
  [30] = true -- knockback
}

-- Returns true if @object is valid target
function libss.IsValidTarget(object)
  return (object and not object.isDead and object.isVisible and object.isTargetable and
    not libss.CheckBuffType(object, 17))
end

libss.units = {}
libss.units.minions, libss.units.minionCount = {}, 0
libss.units.enemyMinions, libss.units.enemyMinionCount = {}, 0
libss.units.allyMinions, libss.units.allyMinionCount = {}, 0
libss.units.jungleMinions, libss.units.jungleMinionCount = {}, 0
libss.units.enemies, libss.units.allies = {}, {}

-- Returns true if enemy @minion is targetable
function libss.can_target_minion(minion)
  return minion and not minion.isDead and minion.team ~= TEAM_ALLY and minion.moveSpeed > 0 and minion.health and
    minion.maxHealth > 100 and
    minion.isVisible and
    minion.isTargetable
end

local excluded_minions = {
  ["CampRespawn"] = true,
  ["PlantMasterMinion"] = true,
  ["PlantHealth"] = true,
  ["PlantSatchel"] = true,
  ["PlantVision"] = true
}

local function valid_minion(minion)
  return minion and minion.type == TYPE_MINION and not minion.isDead and minion.health > 0 and minion.maxHealth > 100 and
    minion.maxHealth < 10000 and
    not minion.name:find("Ward") and
    not excluded_minions[minion.name]
end

local function valid_hero(hero)
  return hero and hero.type == TYPE_HERO
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

local function check_add_minion(o)
  if valid_minion(o) then
    if o.team == TEAM_ALLY then
      libss.units.allyMinionCount =
        find_place_and_insert(libss.units.allyMinions, libss.units.allyMinionCount, o, valid_minion)
    elseif o.team == TEAM_ENEMY then
      libss.units.enemyMinionCount =
        find_place_and_insert(libss.units.enemyMinions, libss.units.enemyMinionCount, o, valid_minion)
    else
      libss.units.jungleMinionCount =
        find_place_and_insert(libss.units.jungleMinions, libss.units.jungleMinionCount, o, valid_minion)
    end
    libss.units.minionCount = find_place_and_insert(libss.units.minions, libss.units.minionCount, o, valid_minion)
  end
end

local function check_add_hero(o)
  if valid_hero(o) then
    if o.team == TEAM_ALLY then
      find_place_and_insert(libss.units.allies, #libss.units.allies, o, valid_hero)
    else
      find_place_and_insert(libss.units.enemies, #libss.units.enemies, o, valid_hero)
    end
  end
end

cb.add(cb.create_minion, check_add_hero)
cb.add(cb.create_minion, check_add_minion)

objManager.loop(
  function(obj)
    check_add_hero(obj)
    check_add_minion(obj)
  end
)

-- Returns table of ally hero.obj in @range from @pos
function libss.GetAllyHeroesInRange(range, pos)
  local pos = pos or player
  local h = {}
  local allies = libss.GetAllyHeroes()
  for i = 1, #allies do
    local hero = allies[i]
    if libss.IsValidTarget(hero) and hero.pos:distSqr(pos) < range * range then
      h[#h + 1] = hero
    end
  end
  return h
end

-- Returns table of hero.obj in @range from @pos
function libss.GetEnemyHeroesInRange(range, pos)
  local pos = pos or player
  local h = {}
  local enemies = libss.GetEnemyHeroes()
  for i = 1, #enemies do
    local hero = enemies[i]
    if libss.IsValidTarget(hero) and hero.pos:distSqr(pos) < range * range then
      h[#h + 1] = hero
    end
  end
  return h
end

-- Returns table and number of objects near @pos
function libss.CountObjectsNearPos(pos, radius, objects, validFunc)
  local n, o = 0, {}
  for i, object in pairs(objects) do
    if validFunc(object) and pos:dist(object.pos) <= radius then
      n = n + 1
      o[n] = object
    end
  end
  return n, o
end

-- Returns table of @team minion.obj in @range
function libss.GetMinionsInRange(range, team, pos)
  pos = pos or player.pos
  range = range or math.huge
  team = team or TEAM_ENEMY
  local validFunc = function(obj)
    return obj and obj.type == TYPE_MINION and obj.team == team and not obj.isDead and obj.health and obj.health > 0 and
      obj.isVisible
  end
  local n, o = libss.CountObjectsNearPos(pos, range, libss.units.minions, validFunc)
  return o
end

-- Returns table of enemy hero.obj
function libss.GetEnemyHeroes()
  return libss.units.enemies
end

-- Returns table of ally hero.obj
function libss.GetAllyHeroes()
  return libss.units.allies
end

-- Returns ally fountain object
libss._fountain = nil
libss._fountainRadius = 750
function libss.GetFountain()
  if libss._fountain then
    return libss._fountain
  end

  local map = libss.GetMap()
  if map and map.index and map.index == 1 then
    libss._fountainRadius = 1050
  end

  if libss.GetShop() then
    objManager.loop(
      function(obj)
        if
          obj and obj.team == TEAM_ALLY and obj.name:lower():find("spawn") and not obj.name:lower():find("troy") and
            not obj.name:lower():find("barracks")
         then
          libss._fountain = obj
          return libss._fountain
        end
      end
    )
  end
  return nil
end

-- Returns true if you are near fountain
function libss.NearFountain(distance)
  local d = distance or libss._fountainRadius or 0
  local fountain = libss.GetFountain()
  if fountain then
    return (player.pos2D:distSqr(fountain.pos2D) <= d * d), fountain.x, fountain.y, fountain.z, d
  else
    return false, 0, 0, 0, 0
  end
end

-- Returns true if you are near fountain
function libss.InFountain()
  return libss.NearFountain()
end

-- Returns the ally shop object
libss._shop = nil
libss._shopRadius = 1250
function libss.GetShop()
  if libss._shop then
    return libss._shop
  end
  objManager.loop(
    function(obj)
      if obj and obj.team == TEAM_ALLY and obj.name:lower():find("shop") then
        libss._shop = obj
        return libss._shop
      end
    end
  )
  return nil
end

return libss