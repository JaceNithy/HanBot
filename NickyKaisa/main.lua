local pred = module.internal("pred")
local TS = module.internal('TS')
local orb = module.internal("orb")
local EvadeInternal = module.seek("evade")


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
    return (object and not object.isDead and object.isVisible and object.isTargetable and not CheckBuffType(object, 17))
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

local on_end_func = nil
local on_end_time = 0
local f_spell_map = {}


local q = {
    last = 0,

    result = {
        seg = nil,
        obj = nil,
        },

    predinput = {
      delay = 0.25,
      radius = 600,
      dashRadius = 0,
      boundingRadiusModSource = 0,
      boundingRadiusModTarget = 0,
    },
}

local w = {
    slot = player:spellSlot(1),
    last = 0,
    range = 3000,
    
    result = {
      seg = nil,
      obj = nil,
      },
    
    predinput = {
          delay = 0.40000000596046,
          width = 150,
          speed = 1750,
          boundingRadiusMod = 1,
      collision = {
        hero = true,
        minion = true,
        wall = true,
      },
    },
}

local menu = menu("Nicky Kais'sa", "[Nicky] Kai'Sa")

menu:header("q", "[Q] Icathian Rain")
menu:boolean('combo_q', 'Use in Combo [Q]', true)
  menu.combo_q:set('tooltip', 'atm will only be used if no minion in range')

menu:header("w", "[W] Void Seeker")
menu:dropdown('combo_w', 'Use in Combo [W]', 1, { 'Only on CC', 'Always', 'Never' })
menu:slider('combo_w_slider', "[Combo] Maximum range to check", 1000, 500, 2500, 100)
menu:boolean('ks_w', 'Use to Killsteal', true)
menu:slider('ks_w_slider', "[Killsteal] Maximum range to check", 2000, 500, 2500, 100)

menu:header("flee", "Flee Settings")
menu:keybind('flee_key', 'Key', 'T', nil)
menu:boolean('flee_e', 'Use E', true)

TS.load_to_menu(menu)

local TargetSelection = function(res, obj, dist)
	if dist > 1000 then
		res.obj = obj
		return true
	end
end

local GetTarget = function()
	return TS.get_result(TargetSelection).obj
end

local on_end_q = function()
    on_end_func = nil
    orb.core.set_pause(0)
end
  
local on_end_w = function()
    on_end_func = nil
    orb.core.set_pause(0)
end
  
local on_end_e = function()
    on_end_func = nil
    orb.core.set_pause(0)
end
  
local on_end_r = function()
    on_end_func = nil
    orb.core.set_pause(0)
end
  
local on_end_dash = function()
    on_end_func = nil
    orb.core.set_pause(0)
end

local on_cast_q = function(spell)
    if os.clock() + spell.windUpTime > on_end_time then
      on_end_func = on_end_q
      on_end_time = os.clock() + spell.windUpTime
      orb.core.set_pause(math.huge)
    end
end
  
local  on_cast_w = function(spell)
    if os.clock() + spell.windUpTime > on_end_time then
      on_end_func = on_end_w
      on_end_time = os.clock() + spell.windUpTime
      orb.core.set_pause(math.huge)
    end
end
  
local on_cast_e = function(spell)
    if os.clock() + spell.windUpTime > on_end_time then
      on_end_func = on_end_e
      on_end_time = os.clock() + spell.windUpTime
      orb.core.set_pause(math.huge)
    end
end
  
local on_cast_r = function(spell)
    if os.clock() + spell.windUpTime > on_end_time then
      on_end_func = on_end_r
      on_end_time = os.clock() + spell.windUpTime
      orb.core.set_pause(math.huge)
    end
end


local function on_end_dash()
    on_end_func = nil
    orb.core.set_pause(0)
end
  

local function IsReady(spell)
    return player:spellSlot(spell).state == 0 
end 

local function CastQ()
    player:castSpell("self", 0)
    orb.core.set_server_pause()
end 

local function CastW()
    local target = GetTarget()
    if IsValidTarget(target) and GetDistance(target) <= 3000 then
        local wpred = pred.linear.get_prediction(w.predinput, target)
        if not wpred then 
            return 
        end
        if not pred.collision.get_prediction(w.predinput, wpred, target) then
            player:castSpell("pos", 1,  vec3(wpred.endPos.x, game.mousePos.y, wpred.endPos.y))
        end 
    end 
end 

local function CastE()
    player:castSpell("self", 2)
    orb.core.set_server_pause()
end

local function on_recv_spell(spell)
    if spell.owner.ptr == player.ptr then
        if f_spell_map[spell.name] then
            f_spell_map[spell.name](spell)
        end 
    end
end
  
local function on_recv_path(obj)
    if obj.ptr == player.ptr and obj.path.isDashing then
        local t = player.path.serverPos2D:dist(player.path.point2D[1]) / player.path.dashSpeed
        if os.clock() + t > on_end_time then
          on_end_func = on_end_dash()
          on_end_time = os.clock() + t
          orb.core.set_pause(0)
        end
    end
end

local function Wgetdamage(target)
    local damage = (20 + (25 * (player.levelRef - 1))) + (GetTotalAD() * 1.5) + (GetTotalAP() * 0.45)
    return CalculateMagicDamage(target, damage)
end

local function invoke_killsteal()

    local target = TS.get_result(function(res, obj, dist)

        if dist >= menu.ks_w_slider:get() then
            return
        end

        if dist <= GetAARange(obj) then
            local aa_damage = CalculateAADamage(obj)
            if (aa_damage * 2) > GetShieldedHealth("AD", obj) then
                return
            end 
        end 
        if Wgetdamage(obj) > GetShieldedHealth("AP", obj) then
            local seg = pred.linear.get_prediction(w.predinput, obj)

            if seg and seg.startPos:distSqr(seg.endPos) <= (w.range * w.range) then
                local col = pred.collision.get_prediction(w.predinput, seg, obj)
                if not col then
                    res.obj = obj
                    res.seg = seg
                    return true
                end 
            end 
        end     
    end)
    if target.obj and target.seg then
        player:castSpell("pos", 1, vec3(target.seg.endPos.x, target.obj.y, target.seg.endPos.y))
    end    
end 

local function ActionW()
    if IsReady(1) then
        return invoke_killsteal()
    end
end 

local function Qprediction()
    if q.last == game.time then
        return q.result 
    end
    q.last = game.time
    q.result = nil

    local count = 0
    for i = 0, objManager.minions.size[TEAM_ENEMY] - 1 do
        local minion = objManager.minions[TEAM_ENEMY][i]
        if minion and not minion.isDead and minion.isVisible then
            local distSqr = player.path.serverPos:distSqr(minion.path.serverPos)
            if distSqr <= (q.predinput.radius * q.predinput.radius) then
                count = count + 1
            end 
        end 
    end 

    if count == 0 then
        local target = TS.get_result(function(res, obj, dist)
            if dist > 1000 then
                return
            end 
            if pred.present.get_prediction(q.predinput, obj) then
                res.obj = obj
                res.seg = seg
                return true
            end 
        end).obj

        if target then
            q.result = target
            return q.result
          end 
    end 
    return q.result
end 

local function qget_action_state()
    if IsReady(0) then
        return Qprediction()
    end
end

local function OnFoAttack()
    if orb.combat.is_active() then
        if menu.combo_q:get() and qget_action_state() then
            CastQ()
            orb.combat.set_invoke_after_attack(false)
            return
        end
    end
end 


local function Get_Combo()
    if on_end_func and os.clock() + network.latency > on_end_time then
        on_end_func()
    end 
    if menu.flee_key:get() then
        if not orb.menu.movement.minimap:get() and minimap.on_map(game.cursorPos) then
            orb.combat.move_to_cursor()
        else
            player:move(mousePos)
        end
        if menu.flee_e:get() and IsReady(2) then
            CastE()
            return 
        end 
    end 
    if orb.combat.is_active() or orb.menu.hybrid:get() or orb.menu.last_hit:get() or orb.menu.lane_clear:get() then
        if CheckBuff(player, "kaisae") then
            if not orb.menu.movement.minimap:get() and minimap.on_map(game.cursorPos) then
                orb.combat.move_to_cursor()
            else
                player:move(mousePos) 
            end 
        end 
    end 
    if menu.ks_w:get() then
        invoke_killsteal()
    end 
    if orb.combat.is_active() then
        if menu.combo_w:get() ~= 3 then
            CastW()
            return          
        end
    end
end 

local function OnTick()
    Get_Combo()
end 

f_spell_map["KaisaQ"] = on_cast_q
f_spell_map["KaisaW"] = on_cast_w
f_spell_map["KaisaE"] = on_cast_e
f_spell_map["KaisaR"] = on_cast_r


orb.combat.register_f_pre_tick(OnTick)
orb.combat.register_f_after_attack(OnFoAttack)
cb.add(cb.spell, on_recv_spell)
cb.add(cb.path, on_recv_path)