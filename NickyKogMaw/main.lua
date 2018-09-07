local gpred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local EvadeInternal = module.seek("evade")

local delayedActions, delayedActionsExecuter = {}, nil
local function DelayAction(func, delay, args) --delay in seconds
  if not delayedActionsExecuter then
    function delayedActionsExecuter()
      for t, funcs in pairs(delayedActions) do
        if t <= game.time then
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
  local t = game.time + (delay or 0)
  if delayedActions[t] then
    delayedActions[t][#delayedActions[t] + 1] = {func = func, args = args}
  else
    delayedActions[t] = {{func = func, args = args}}
  end
end

local _intervalFunction
local function SetInterval(userFunction, timeout, count, params)
  if not _intervalFunction then
    function _intervalFunction(userFunction, startTime, timeout, count, params)
      if userFunction(unpack(params or {})) ~= false and (not count or count > 1) then
        DelayAction(
          _intervalFunction,
          (timeout - (game.time - startTime - timeout)),
          {userFunction, startTime + timeout, timeout, count and (count - 1), params}
        )
      end
    end
  end
  DelayAction(_intervalFunction, timeout, {userFunction, game.time, timeout or 0, count, params})
end


-- Returns percent health of @obj or player -- P_Soldier_Ring
local function GetPercentHealth(obj)
  local obj = obj or player
  return (obj.health / obj.maxHealth) * 100
end

-- Returns percent mana of @obj or player
local function GetPercentMana(obj)
  local obj = obj or player
  return (obj.mana / obj.maxMana) * 100
end

-- Returns percent par (mana, energy, etc) of @obj or player
local function GetPercentPar(obj)
  local obj = obj or player
  return (obj.par / obj.maxPar) * 100
end

local function CheckBuff(obj, buffname)
  if obj then
    for i = 0, obj.buffManager.count - 1 do
      local buff = obj.buffManager:get(i)

      if buff and buff.valid and buff.name == buffname and (buff.stacks > 0 or buff.stacks2 > 0) then
        return true
      end
    end
  end
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
-- Returns @target health+shield
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

-- Returns total AD of @obj or player
local function GetTotalAD(obj)
  local obj = obj or player
  return (obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod
end

-- Returns bonus AD of @obj or player
local function GetBonusAD(obj)
  local obj = obj or player
  return ((obj.baseAttackDamage + obj.flatPhysicalDamageMod) * obj.percentPhysicalDamageMod) - obj.baseAttackDamage
end

-- Returns total AP of @obj or player
local function GetTotalAP(obj)
  local obj = obj or player
  return obj.flatMagicDamageMod * obj.percentMagicDamageMod
end

-- Returns physical damage multiplier on @target from @damageSource or player
local function PhysicalReduction(target, damageSource)
  local damageSource = damageSource or player
  local armor =
    ((target.bonusArmor * damageSource.percentBonusArmorPenetration) + (target.armor - target.bonusArmor)) *
    damageSource.percentArmorPenetration
  local lethality =
    (damageSource.physicalLethality * .4) + ((damageSource.physicalLethality * .6) * (damageSource.levelRef / 18))
  return armor >= 0 and (100 / (100 + (armor - lethality))) or (2 - (100 / (100 - (armor - lethality))))
end

-- Returns magic damage multiplier on @target from @damageSource or player
local function MagicReduction(target, damageSource)
  local damageSource = damageSource or player
  local magicResist = (target.spellBlock * damageSource.percentMagicPenetration) - damageSource.flatMagicPenetration
  return magicResist >= 0 and (100 / (100 + magicResist)) or (2 - (100 / (100 - magicResist)))
end

-- Returns damage reduction multiplier on @target from @damageSource or player
local function DamageReduction(damageType, target, damageSource)
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
local function CalculateAADamage(target, damageSource)
  local damageSource = damageSource or player
  if target then
    return GetTotalAD(damageSource) * PhysicalReduction(target, damageSource)
  end
  return 0
end

-- Calculates physical damage on @target from @damageSource or player
local function CalculatePhysicalDamage(target, damage, damageSource)
  local damageSource = damageSource or player
  if target then
    return (damage * PhysicalReduction(target, damageSource)) *
      DamageReduction("AD", target, damageSource)
  end
  return 0
end

-- Calculates magic damage on @target from @damageSource or player
local function CalculateMagicDamage(target, damage, damageSource)
  local damageSource = damageSource or player
  if target then
    return (damage * MagicReduction(target, damageSource)) * DamageReduction("AP", target, damageSource)
  end
  return 0
end

-- Returns @target attack range (@target is optional; will consider @target boundingRadius into calculation)
local function GetAARange(target)
  return player.attackRange + player.boundingRadius + (target and target.boundingRadius or 0)
end

-- Returns @obj predicted pos after @delay secs
local function GetPredictedPos(obj, delay)
  if not IsValidTarget(obj) or not obj.path or not delay or not obj.moveSpeed then
    return obj
  end
  local pred_pos = pred.core.lerp(obj.path, network.latency + delay, obj.moveSpeed)
  return vec3(pred_pos.x, player.y, pred_pos.y)
end

-- Returns ignite damage
local function GetIgniteDamage(target)
  local damage = 55 + (25 * player.levelRef)
  if target then
    damage = damage - (GetShieldedHealth("AD", target) - target.health)
  end
  return damage
end

enum = {}
enum.slots = {
  q = 0,
  w = 1,
  e = 2,
  r = 3
}
enum.buff_types = {
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
  --Flee = 28,
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
 -- [28] = true, -- flee
  [29] = true, -- knockup
  [30] = true -- knockback
}

-- Returns true if @object is valid target
local function IsValidTarget(object)
  return (object and not object.isDead and object.isVisible and object.isTargetable and
    not CheckBuffType(object, 17))
end

units = {}
units.minions, units.minionCount = {}, 0
units.enemyMinions, units.enemyMinionCount = {}, 0
units.allyMinions, units.allyMinionCount = {}, 0
units.jungleMinions, units.jungleMinionCount = {}, 0
units.towers, units.towerCount = {}, 0
units.enemies, units.allies = {}, {}

local function can_target_minion(minion)
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

local function valid_tower(tower)
    return tower and tower.type == TYPE_TURRET -- 9217
  end

local function check_add_minion(o)
  if valid_minion(o) then
    if o.team == TEAM_ALLY then
      units.allyMinionCount =
        find_place_and_insert(units.allyMinions, units.allyMinionCount, o, valid_minion)
    elseif o.team == TEAM_ENEMY then
      units.enemyMinionCount =
        find_place_and_insert(units.enemyMinions, units.enemyMinionCount, o, valid_minion)
    else
      units.jungleMinionCount =
        find_place_and_insert(units.jungleMinions, units.jungleMinionCount, o, valid_minion)
    end
    units.minionCount = find_place_and_insert(units.minions, units.minionCount, o, valid_minion)
  end
end

local function check_add_hero(o)
  if valid_hero(o) then
    if o.team == TEAM_ALLY then
      find_place_and_insert(units.allies, #units.allies, o, valid_hero)
    else
      find_place_and_insert(units.enemies, #units.enemies, o, valid_hero)
    end
  end
end

local function check_add_tower(o)
    if valid_tower(o) then
      units.towerCount = find_place_and_insert(units.towers, units.towerCount, o, valid_tower)
    end
  end

cb.add(cb.create_minion, check_add_hero)
cb.add(cb.create_minion, check_add_minion)
cb.add(cb.create_particle, check_add_tower)

objManager.loop(
  function(obj)
    check_add_hero(obj)
    check_add_minion(obj)
    check_add_tower(obj)
  end
)

-- Returns table of ally hero.obj in @range from @pos
local function GetAllyHeroesInRange(range, pos)
  local pos = pos or player
  local h = {}
  local allies = GetAllyHeroes()
  for i = 1, #allies do
    local hero = allies[i]
    if IsValidTarget(hero) and hero.pos:distSqr(pos) < range * range then
      h[#h + 1] = hero
    end
  end
  return h
end

-- Returns table of hero.obj in @range from @pos
local function GetEnemyHeroesInRange(range, pos)
  local pos = pos or player
  local h = {}
  local enemies = GetEnemyHeroes()
  for i = 1, #enemies do
    local hero = enemies[i]
    if IsValidTarget(hero) and hero.pos:distSqr(pos) < range * range then
      h[#h + 1] = hero
    end
  end
  return h
end

_enemyTowers = nil
local function GetEnemyTowers()
  if _enemyTowers then return _enemyTowers end
  _enemyTowers = {}
  for i = 1, units.towerCount do
    local obj = units.towers[i]
    if valid_tower(obj) and obj.team ~= TEAM_ALLY then
    _enemyTowers[#_enemyTowers + 1] = obj
    end
  end
  return _enemyTowers
end


-- Returns table and number of objects near @pos
local function CountObjectsNearPos(pos, radius, objects, validFunc)
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
local function GetMinionsInRange(range, team, pos)
  pos = pos or player.pos
  range = range or math.huge
  team = team or TEAM_ENEMY
  local validFunc = function(obj)
    return obj and obj.type == TYPE_MINION and obj.team == team and not obj.isDead and obj.health and obj.health > 0 and
      obj.isVisible
  end
  local n, o = CountObjectsNearPos(pos, range, units.minions, validFunc)
  return o
end

-- Returns table of enemy hero.obj
local function GetEnemyHeroes()
  return units.enemies
end

-- Returns table of ally hero.obj
local function GetAllyHeroes()
  return units.allies
end

-- Returns ally fountain object
_fountain = nil
_fountainRadius = 750
local function GetFountain()
  if _fountain then
    return _fountain
  end

  local map = GetMap()
  if map and map.index and map.index == 1 then
    _fountainRadius = 1050
  end

  if GetShop() then
    objManager.loop(
      function(obj)
        if
          obj and obj.team == TEAM_ALLY and obj.name:lower():find("spawn") and not obj.name:lower():find("troy") and
            not obj.name:lower():find("barracks")
         then
          _fountain = obj
          return _fountain
        end
      end
    )
  end
  return nil
end

-- Returns true if you are near fountain
local function NearFountain(distance)
  local d = distance or _fountainRadius or 0
  local fountain = GetFountain()
  if fountain then
    return (player.pos2D:distSqr(fountain.pos2D) <= d * d), fountain.x, fountain.y, fountain.z, d
  else
    return false, 0, 0, 0, 0
  end
end

-- Returns true if you are near fountain
local function InFountain()
  return NearFountain()
end

-- Returns the ally shop object
_shop = nil
_shopRadius = 1250
local function GetShop()
  if _shop then
    return _shop
  end
  objManager.loop(
    function(obj)
      if obj and obj.team == TEAM_ALLY and obj.name:lower():find("shop") then
        _shop = obj
        return _shop
      end
    end
  )
  return nil
end

local function is_ready(sp) 
  return player:spellSlot(sp).state == 0
end 

local on_end_func = nil
local on_end_time = 0
local f_spell_map = {}



local menu = menu("Kog'Maw", "[Nicky]Kog'Maw")


menu:menu("combo", "Combo Settings")
  menu.combo:menu("q", "Q Settings")
    menu.combo.q:boolean("q", "Use Caustic Spittle", true)
    menu.combo.q:slider("mana_mngr", "Minimum Mana %", 10, 0, 100, 5)

  menu.combo:menu("w", "W Settings")
    menu.combo.w:boolean("w", "Use Bio-Arcane Barrage", true)
    menu.combo.w:slider("mana_mngr", "Minimum Mana %", 5, 0, 100, 5)

  menu.combo:menu("e", "E Settings")
    menu.combo.e:dropdown("use", "Use Void Ooze", 1, { "Out of AA Range", "Always", "Never" })
    menu.combo.e:slider("mana_mngr", "Minimum Mana %", 50, 0, 100, 5)

  menu.combo:menu("r", "R Settings")
    menu.combo.r:boolean("r", "Use Living Artillery", true)
    menu.combo.r:slider("stacks", "Max Stacks", 3, 1, 10, 1)
    menu.combo.r:boolean("cced", "Use on CCed", true)
      menu.combo.r.cced:set("tooltip", "Will only use on enemies with <40% health")
    menu.combo.r:slider("at_hp", "Use only if enemy health is below %", 40, 5, 100, 5)
    menu.combo.r:boolean("in_aa", "Use within AA range", false)

  menu.combo:menu("items", "Item Settings")
    menu.combo.items:boolean("botrk", "Use Cutlass/BotRK", true)
    menu.combo.items:slider("botrk_at_hp", "Cutlass/BotRK if enemy health is below %", 70, 5, 100, 5)

menu:menu("harass", "Hybrid/Harass Settings")
  menu.harass:menu("q", "Q Settings")
    menu.harass.q:boolean("q", "Use Caustic Spittle", true)
    menu.harass.q:slider("mana_mngr", "Minimum Mana %", 30, 0, 100, 5)

  menu.harass:menu("w", "W Settings")
    menu.harass.w:boolean("w", "Use Bio-Arcane Barrage", true)
    menu.harass.w:slider("mana_mngr", "Minimum Mana %", 20, 0, 100, 5)

  menu.harass:menu("e", "E Settings")
    menu.harass.e:dropdown("use", "Use Void Ooze", 3, { "Out of AA Range", "Always", "Never" })
    menu.harass.e:slider("mana_mngr", "Minimum Mana %", 50, 0, 100, 5)

  menu.harass:menu("r", "R Settings")
    menu.harass.r:boolean("r", "Use Living Artillery", true)
    menu.harass.r:slider("stacks", "Max Stacks", 1, 1, 10, 1)
    menu.harass.r:boolean("cced", "Use on CCed", true)
      menu.harass.r.cced:set("tooltip", "Will only use on enemies with <40% health")
    menu.harass.r:slider("at_hp", "Use only if enemy health is below %", 40, 5, 100, 5)
    menu.harass.r:boolean("in_aa", "Use within AA range", false)

menu:menu("clear", "Lane Clear Settings")
  menu.clear:menu("w", "W Settings")
    menu.clear.w:boolean("w", "Use Bio-Arcane Barrage", true)
    menu.clear.w:slider("mana_mngr", "Minimum Mana %", 70, 0, 100, 5)
    menu.clear.w:slider("min_minions", "Minimum minions", 3, 1, 5, 1)

  menu.clear:menu("e", "E Settings")
    menu.clear.e:boolean("e", "Use Void Ooze", false)
    menu.clear.e:slider("mana_mngr", "Minimum Mana %", 70, 0, 100, 5)
    menu.clear.e:slider("min_minions", "Minimum minions to hit", 3, 1, 5, 1)

menu:menu("auto", "Auto Settings")
  menu.auto:menu("p", "Passive Settings")
    menu.auto.p:boolean("use", "Chase Lowest HP Target", true)
    menu.auto.p:slider("dist", "Distance to check within", 750, 100, 1500, 100)

  menu.auto:menu("q", "Q Settings")
    menu.auto.q:boolean("kill", "Q if killable", true)
      menu.auto.q.kill:set("tooltip", "This will override all 'Q settings'")

  menu.auto:menu("r", "R Settings")
    menu.auto.r:boolean("dash", "R on dash", true)
    menu.auto.r:boolean("kill", "R if killable", true)
      menu.auto.r.kill:set("tooltip", "This will override all 'R settings'")

menu:header("xd", "Misc.")
menu:keybind("semi_r", "Semi-Manual R", "T", nil)

menu:menu("draws", "Drawings")
  menu.draws:slider("width", "Width/Thickness", 1, 1, 10, 1)
  menu.draws:slider("numpoints", "Numpoints (quality of drawings)", 40, 15, 100, 5)
    menu.draws.numpoints:set("tooltip", "Higher = smoother but more FPS usage")
  menu.draws:boolean("q_range", "Draw Q Range", true)
  menu.draws:color("q", "Q Drawing Color", 255, 255, 255, 255)
  menu.draws:boolean("w_range", "Draw W Extension Range", true)
  menu.draws:color("w", "W Drawing Color", 255, 255, 255, 255)
  menu.draws:boolean("e_range", "Draw E Range", true)
  menu.draws:color("e", "E Drawing Color", 255, 255, 255, 255)
  menu.draws:boolean("r_range", "Draw R Range", true)
  menu.draws:color("r", "R Drawing Color", 255, 255, 255, 255)

  local q = {
    slot = player:spellSlot(0),
    last = 0,
    range = 1175, --1380625
    
    result = {
      obj = nil,
      dist = 0,
      seg = nil,
    },
    
    predinput = {
      delay = 0.25,
      width = 70,
      speed = 1650,
      boundingRadiusMod = 1,
      collision = {
        hero = true,
        minion = true,
        wall = true,
      },
    },
  }
  
  local w = {
    slot = player:spellSlot(1),
    last = 0,
    range = { 630, 650, 670, 690, 710 },
    
    predinput = {
      delay = 0.25,
      dashRadius = 0,
      boundingRadiusModSource = 1,
      boundingRadiusModTarget = 1,
    }
  }

  local e = {
    slot = player:spellSlot(2),
    last = 0,
    range = 1280, --1638400
  
    result = {
      seg = nil,
      obj = nil,
    },
  
    predinput = {
      delay = 0.25,
      width = 120,
      speed = 1400,
      boundingRadiusMod = 0,
      collision = {
        wall = true,
      },
    },
  }

  local r = {
    slot = player:spellSlot(3),
    last = 0,
    range = { 1200, 1500, 1800 },
    stacks = 0,
    
    result = {
      seg = nil,
      obj = nil,
    },
  
    predinput = {
      delay = 1.1,
      radius = 241,
      speed = math.huge,
      boundingRadiusMod = 0,
    },
  }


local qget_damage = function(target)
    local damage = (30 + (50 * q.slot.level)) + (GetTotalAP() * 0.5)
    return CalculateMagicDamage(target, damage)
end
  
local qinvoke_action = function()
    player:castSpell("pos", 0, vec3(q.result.seg.endPos.x, q.result.obj.y, q.result.seg.endPos.y))
    orb.core.set_server_pause()
end
  
local qinvoke_killsteal = function()
    local target = ts.get_result(function(res, obj, dist)
      if dist > GetAARange(obj) and dist < 1500 then
        if qget_damage(obj) > GetShieldedHealth("AP", obj) then
          local seg = gpred.linear.get_prediction(q.predinput, obj)
          if seg and seg.startPos:distSqr(seg.endPos) <= 1380625 then
            local col = gpred.collision.get_prediction(q.predinput, seg, obj)
            if not col then
              res.obj = obj
              res.seg = seg
              return true
            end
          end
        end
      end
    end)
    if target.seg and target.obj then
      player:castSpell("pos", 0, vec3(target.seg.endPos.x, target.obj.y, target.seg.endPos.y))
      orb.core.set_server_pause()
      return true
    end
  end
  
local qtrace_filter = function()
    if q.result.seg.startPos:distSqr(q.result.seg.endPos) > 1380625 then
      return false
    end
    if q.result.seg.startPos:distSqr(q.result.obj.path.serverPos2D) > 1380625 then
      return false
    end
    if gpred.trace.linear.hardlock(q.predinput, q.result.seg, q.result.obj) then
      if q.result.dist <= GetAARange(q.result.obj) then
        return false
      end
      return true
    end
    if gpred.trace.linear.hardlockmove(q.predinput, q.result.seg, q.result.obj) then
      return true
    end
    if gpred.trace.newpath(q.result.obj, 0.033, 0.500) then
      return true
    end
  end
  
local qget_prediction = function()
    if q.last == game.time then
      return q.result.seg
    end
    q.last = game.time
    q.result.obj = nil
    q.result.dist = 0
    q.result.seg = nil
    
    q.result = ts.get_result(function(res, obj, dist)
      if dist > 1500 then
        return
      end
      if dist <= GetAARange(obj) then
        local aa_damage = CalculateAADamage(obj)
        if (aa_damage * 2) > GetShieldedHealth("AD", obj) then
          return
        end
      end
      local seg = gpred.linear.get_prediction(q.predinput, obj)
      if seg and seg.startPos:distSqr(seg.endPos) < 1380625 then
        local col = gpred.collision.get_prediction(q.predinput, seg, obj)
        if not col then
          res.obj = obj
          res.dist = dist
          res.seg = seg
          return true
        end
      end
    end)
    if q.result.seg and qtrace_filter() then
      return q.result
    end
  end

local einvoke_action = function()
    player:castSpell("pos", 2, vec3(e.result.seg.endPos.x, e.result.obj.y, e.result.seg.endPos.y))
    orb.core.set_server_pause()
end
  
local einvoke__lane_clear = function()
    local valid = {}
    local minions = objManager.minions
    for i = 0, minions.size[TEAM_ENEMY] - 1 do
      local minion = minions[TEAM_ENEMY][i]
      if minion and not minion.isDead and minion.isVisible then
        local dist = player.path.serverPos:distSqr(minion.path.serverPos)
        if dist <= 1638400 then
          valid[#valid + 1] = minion
        end
      end
    end
    local max_count, cast_pos = 0, nil
    for i = 1, #valid do
      local minion_a = valid[i]
      local current_pos = player.path.serverPos + ((minion_a.path.serverPos - player.path.serverPos):norm() * (minion_a.path.serverPos:dist(player.path.serverPos) + 1300))
      local hit_count = 1
      for j = 1, #valid do
        if j ~= i then
          local minion_b = valid[j]
          local point = mathf.closest_vec_line(minion_b.path.serverPos, player.path.serverPos, current_pos)
          if point and point:dist(minion_b.path.serverPos) < (89 + minion_b.boundingRadius) then
            hit_count = hit_count + 1
          end
        end
      end
      if not cast_pos or hit_count > max_count then
        cast_pos, max_count = current_pos, hit_count
      end
      if cast_pos and max_count > menu.clear.e.min_minions:get() then
        player:castSpell("pos", 2, cast_pos)
        orb.core.set_server_pause()
        break
      end
    end
  end
  
local etrace_filter = function()
    if e.result.seg.startPos:distSqr(e.result.obj.path.serverPos2D) > 1638400 then
      return false
    end
    if gpred.trace.linear.hardlock(e.predinput, e.result.seg, e.result.obj) then
      return false
    end
    if gpred.trace.linear.hardlockmove(e.predinput, e.result.seg, e.result.obj) then
      return true
    end
    if e.result.seg.startPos:distSqr(e.result.seg.endPos) < (420 * 420) then
      return true
    end
    if gpred.trace.newpath(e.result.obj, 0.033, 0.500) then
      return true
    end
  end
  
local eget_prediction = function()
    if e.last == game.time then
      return e.result.seg
    end
    e.last = game.time
    e.result.obj = nil
    e.result.seg = nil
    
    e.result = ts.get_result(function(res, obj, dist)
      if dist > 1500 then
        return
      end
      if dist <= GetAARange(obj) then
        local aa_damage = CalculateAADamage(obj)
        if (aa_damage * 2) >= GetShieldedHealth("AD", obj) then
          return
        end
      end
      local seg = gpred.linear.get_prediction(e.predinput, obj)
      if seg and seg.startPos:distSqr(seg.endPos) < 1638400 then
        local col = gpred.collision.get_prediction(e.predinput, seg, obj)
        if not col then
          res.obj = obj
          res.seg = seg
          return true
        end
      end
    end)
    if e.result.seg and etrace_filter() then
      return e.result
    end
  end 
  
local winvoke_action = function()
    player:castSpell("self", 1)
    orb.core.set_server_pause()
end
  
 local winvoke__lane_clear = function()
    local extended_range = w.range[w.slot.level] + 65
    local count = 0
    local minions = objManager.minions
    for i = 0, minions.size[TEAM_ENEMY] - 1 do
      local minion = minions[TEAM_ENEMY][i]
      if minion and not minion.isDead and minion.isVisible then
        local dist_to_minion = player.path.serverPos:distSqr(minion.path.serverPos)
        if dist_to_minion <= (extended_range * extended_range) then
          count = count + 1
        end
      end
      if count == menu.clear.w.min_minions:get() then
        player:castSpell("self", 1)
        orb.core.set_server_pause()
        break
      end
    end
  end
  
 local  wget_prediction = function()
    if w.last == game.time then
      return w.result
    end
    w.last = game.time
    w.result = nil
    
    local target = ts.get_result(function(res, obj, dist)
      if dist > 1500 then
        return
      end
      w.predinput.radius = w.range[w.slot.level]
      if gpred.present.get_prediction(w.predinput, obj) then
        res.obj = obj
        return true
      end
    end).obj
    if target then
      w.result = target
      return w.result
    end
    
    return w.result
  end 
  
  
local rget_action_state = function()
    if is_ready(3) then
      return rget_prediction()
    end
  end
  
local rinvoke_action = function()
    player:castSpell("pos", 3, vec3(r.result.seg.endPos.x, r.result.obj.y, r.result.seg.endPos.y))
    --orb.core.set_server_pause()
  end
  
local rget_damage = function(target)
    local damage = (60 + (40 * r.slot.level)) + (GetBonusAD() * 0.65) + (GetTotalAP() * 0.25)
    local target_health_scaling = (1 - (target.health / target.maxHealth)) * 0.833
    target_health_scaling = (target_health_scaling * 100) > 50 and 0.5 or target_health_scaling
    return (damage + (target_health_scaling * damage)) * MagicReduction(target)
  end
  
local rinvoke_killsteal = function()
    local target = ts.get_result(function(res, obj, dist)
      if dist > 2500 then
        return
      end
      if dist <= r.range[r.slot.level] and dist > GetAARange(obj) then
        if rget_damage(obj) > GetShieldedHealth("AP", obj) then
          res.obj = obj
          return true
        end
      end
    end, ts.filter_set[8]).obj
    if target then
      local seg = gpred.circular.get_prediction(r.predinput, target)
      local range = r.range[r.slot.level] * r.range[r.slot.level]
      if seg and seg.startPos:distSqr(seg.endPos) <= range then
        player:castSpell("pos", 3, vec3(seg.endPos.x, target.y, seg.endPos.y))
        --orb.core.set_server_pause()
        return true
      end
    end
  end
  
local rinvoke__on_dash = function()
    local target = ts.get_result(function(res, obj, dist)
      if dist > 2500 or GetPercentHealth(obj) > 40 then
        return
      end
      if dist <= (r.range[r.slot.level] + obj.boundingRadius) and obj.path.isActive and obj.path.isDashing then
        res.obj = obj
        return true
      end
    end).obj
    if target then
      local pred_pos = gpred.core.lerp(target.path, network.latency + r.predinput.delay, target.path.dashSpeed)
      if pred_pos and pred_pos:dist(player.path.serverPos2D) > GetAARange() and pred_pos:dist(player.path.serverPos2D) <= 1200 then
        player:castSpell("pos", 3, vec3(pred_pos.x, target.y, pred_pos.y))
        --orb.core.set_server_pause()
        return true
      end
    end
  end
  
local rtrace_filter = function()
    if menu.combo.r.cced:get() then
      if gpred.trace.circular.hardlock(r.predinput, r.result.seg, r.result.obj) then
        return true
      end
      if gpred.trace.circular.hardlockmove(r.predinput, r.result.seg, r.result.obj) then
        return true
      end
    end
    if gpred.trace.newpath(r.result.obj, 0.033, 0.500) then
      return true
    end
  end
  
local rget_prediction = function()
    if r.last == game.time then
      return r.result.seg
    end
    r.last = game.time
    r.result.obj = nil
    r.result.seg = nil
    
    r.result = ts.get_result(function(res, obj, dist)
      if dist > 2500 then
        return
      end
      if dist <= GetAARange(obj) then
        if (orb.combat.is_active() and not menu.combo.r.in_aa:get()) or (orb.menu.hybrid:get() and not menu.harass.r.in_aa:get()) then
          return
        end
        local aa_damage = CalculateAADamage(obj)
        if (aa_damage * 3) > GetShieldedHealth("AD", obj) then
          return
        end
      end
      if (orb.combat.is_active() and GetPercentHealth(obj) < menu.combo.r.at_hp:get()) or (orb.menu.hybrid:get() and GetPercentHealth(obj) < menu.harass.r.at_hp:get()) then
        local seg = gpred.circular.get_prediction(r.predinput, obj)
        local range = r.range[r.slot.level] * r.range[r.slot.level]
        if seg and seg.startPos:distSqr(seg.endPos) <= range then
          res.obj = obj
          res.seg = seg
          return true
        end
      end
    end)
    if r.result.seg and rtrace_filter() then
      return r.result
    end
  end
  
local on_update_buff = function()
  for i = 0, player.buffManager.count - 1 do
		local buff = player.buffManager:get(i)
    if buff and buff.valid and buff.name == "kogmawlivingartillerycost" then
      r.stacks = math.min(10, buff.stacks + 1)
    end 
      
    end
end
  
local on_remove_buff = function()
  for i = 0, player.buffManager.count - 1 do
		local buff = player.buffManager:get(i)
    if buff and buff.valid and buff.name == "kogmawlivingartillerycost" then
      r.stacks = 0
    end 
    end
end
  
local on_end_q = function()
    on_end_func = nil
    orb.core.set_pause(0)
  end
  
 local on_cast_q = function(spell)
    if os.clock() + spell.windUpTime > on_end_time then
      on_end_func = on_end_q
      on_end_time = os.clock() + spell.windUpTime
      orb.core.set_pause(0)
    end
  end
  
local  on_end_e = function()
    on_end_func = nil
    orb.core.set_pause(0)
  end
  
local  on_cast_e = function(spell)
    if os.clock() + spell.windUpTime > on_end_time then
      on_end_func = on_end_e
      on_end_time = os.clock() + spell.windUpTime
      orb.core.set_pause(0)
    end
  end
  
 local on_end_r = function()
    on_end_func = nil
    orb.core.set_pause(0)
  end
  
local on_cast_r = function(spell)
    if os.clock() + spell.windUpTime > on_end_time then
      on_end_func = on_end_r
      on_end_time = os.clock() + spell.windUpTime
      orb.core.set_pause(0)
    end
  end
  
local get_passive_target = function(res, obj, dist)
    if dist > (menu.auto.p.dist:get() + 500) then
      return
    end
    if (dist < menu.auto.p.dist:get() and (100 + (25 * player.levelRef)) > obj.health) then
      res.obj = obj
      return true
    else
      if dist < menu.auto.p.dist:get() then
        res.obj = obj
        return true
      end
    end
  end

local get_action = function()
    if on_end_func and os.clock() + network.latency > on_end_time then
      on_end_func()
    end
    if menu.auto.p.use:get() and CheckBuff(player, "KogMawIcathianSurprise") then
      local target = ts.get_result(get_passive_target, ts.filter_set[8], true, true)
      if target.obj then
        local pos = target.obj.path.serverPos
        local dist = player.path.serverPos:dist(pos)
        if dist < (menu.auto.p.dist:get() - 50) then
          orb.core.set_pause_move(5)
          player:move(pos)
        end
      end
    end
    if menu.auto.q.kill:get() and is_ready(0) then
      if qinvoke_killsteal() then
        return
      end
    end
    if menu.auto.r.kill:get() and is_ready(3) then
      if rinvoke_killsteal() then
        return
      end
    end
    if menu.auto.r.dash:get() and is_ready(3) then
      if rinvoke__on_dash() then
        return
      end
    end
    if menu.semi_r:get() and is_ready(3) then
      local target = ts.get_result(function(res, obj, dist)
        if dist > 2500 then
          return
        end
        local seg = gpred.circular.get_prediction(r.predinput, obj)
        local range = r.range[r.slot.level] * r.range[r.slot.level]
        if seg and seg.startPos:distSqr(seg.endPos) <= range then
          res.obj = obj
          res.seg = seg
          return true
        end
      end)
      if target.seg and target.obj then
        player:castSpell("pos", 3, vec3(target.seg.endPos.x, target.obj.y, target.seg.endPos.y))
        orb.core.set_server_pause()
      end
    end
    if orb.combat.is_active() then
      if menu.combo.items.botrk:get() then
        local target = ts.get_result(function(res, obj, dist)
          if dist > 1000 or GetPercentHealth(target) > menu.combo.items.botrk_at_hp:get() then
            return
          end
          if dist <= GetAARange(obj) then
            local aa_damage = CalculateAADamage(obj)
            if (aa_damage * 2) > GetShieldedHealth("AD", obj) then
              return
            end
          end
          if dist < 550 then
            res.obj = obj
            return true
          end
        end).obj
        if target then
          for i = 6, 11 do
            local slot = player:spellSlot(i)
            if slot.isNotEmpty and (slot.name == 'BilgewaterCutlass' or slot.name == 'ItemSwordOfFeastAndFamine') and slot.state == 0 then
              player:castSpell("obj", i, target)
              orb.core.set_server_pause()
              break
            end
          end
        end
      end
      if menu.combo.e.use:get() == 2 then
        if is_ready(2) and GetPercentPar() >= menu.combo.e.mana_mngr:get() and eget_prediction() then
          einvoke_action()
          return
        end
      end
      if menu.combo.q.q:get() then
        if is_ready(0) and GetPercentPar() >= menu.combo.q.mana_mngr:get() and qget_prediction() then
          qinvoke_action()
          return
        end
      end
      if menu.combo.w.w:get() and orb.core.can_attack() then
        if is_ready(1) and GetPercentPar() >= menu.combo.w.mana_mngr:get() and wget_prediction() then
          winvoke_action()
          return
        end
      end
      if menu.combo.r.r:get() and not orb.core.is_attack_paused() then
        if is_ready(3) and r.stacks <= menu.combo.r.stacks:get() and rget_prediction() then
          rinvoke_action()
          return
        end
      end
    end
    if orb.menu.hybrid:get() then
      if menu.harass.e.use:get() == 2 then
        if is_ready(2) and GetPercentPar() >= menu.harass.e.mana_mngr:get() and eget_prediction() then
          einvoke_action()
          return
        end
      end
      if menu.harass.q.q:get() then
        if is_ready(0) and GetPercentPar() >= menu.harass.q.mana_mngr:get() and qget_prediction() then
          qinvoke_action()
          return
        end
      end
      if menu.harass.w.w:get() and orb.core.can_attack() then
        if is_ready(1) and GetPercentPar() >= menu.harass.w.mana_mngr:get() and wget_prediction() then
          winvoke_action()
          return
        end
      end
      if menu.harass.r.r:get() and not orb.core.is_attack_paused() then
        if is_ready(3) and r.stacks <= menu.harass.r.stacks:get() and rget_prediction()then
          rinvoke_action()
          return
        end
      end
    end
    if orb.menu.lane_clear:get() then
      if menu.clear.e.e:get() then
        if is_ready(2) and GetPercentPar() >= menu.clear.w.mana_mngr:get() then
          einvoke__lane_clear()
          return
        end
      end
      if menu.clear.w.w:get() then
        if is_ready(1) and GetPercentPar() >= menu.clear.w.mana_mngr:get() then
          winvoke__lane_clear()
          return
        end
      end
    end
  end

 local function on_recv_spell(spell)
  if f_spell_map[spell.name] then
    f_spell_map[spell.name](spell)
  end
 end 

 local function on_after_attack()
  if (orb.combat.is_active() and menu.combo.e.use:get() == 1) or (orb.menu.hybrid:get() and menu.harass.e.use:get() == 1) then
    if is_ready(2) and eget_prediction() and (e.result.obj and e.result.seg) then
      local dist = player.path.serverPos:dist(e.result.obj.path.serverPos)
      if dist > GetAARange() then
        einvoke_action()
        orb.combat.set_invoke_after_attack(false)
        return
      end
    end
  end
end

local function on_tick()
get_action()
end 

  local function OnTick()
    on_update_buff()
    on_remove_buff()
    
  end 

f_spell_map["KogMawQ"] = on_cast_q
f_spell_map["KogMawVoidOoze"] = on_cast_e
f_spell_map["KogMawLivingArtillery"] = on_cast_r

cb.add(cb.tick, OnTick)
--cb.add(cb.draw, OnDraw)
cb.add(cb.spell, on_recv_spell)
orb.combat.register_f_pre_tick(on_tick)
orb.combat.register_f_after_attack(on_after_attack)