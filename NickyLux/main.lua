local pred = module.internal("pred")
local ts = module.internal('TS')
local orb = module.internal("orb")
local evade = module.seek("evade")
local ObjMinion_Type = objManager.minions

local q = { Range = 1170 }
local w = { Range = 1075 }
local e = { Range = 1000, ELight = { }}
local r = { Range = 3340}
local radius = player.boundingRadius*player.boundingRadius
local state = false
local data = { source = nil, spell_name = nil, wait_time = 0 } 
local PredQ = { delay = 0.25, width = 70, speed = 1200, boundingRadiusMod = 1, collision = { hero = false, minion = true, wall = true } }
local PredE = { delay = 0.25, radius = 250, speed = 1200, boundingRadiusMod = 0, collision = { hero = false, minion = false, wall = true } }
local PredR = { delay = 1, width = 130, speed = math.huge, boundingRadiusMod = 1, collision = { hero = false, minion = false } }


local spellsW = {
    ["ahriseduce"] = { delay = 0.1, state = true },
    ["akalimota"] = { delay = 0.1, state = true },
    ["bardr"] = { delay = 0.3, state = true },
    ["blindingdart"] = { delay = 0.1, state = true },
    ["blindmonkrkick"] = { delay = 0.1, state = true },
    ["bluecardpreattack"] = { delay = 0.1, state = true },
    ["brandq"] = { delay = 0.1, state = true },
    ["braumrwrapper"] = { delay = 0.3, state = true },
    ["caitlynaceinthehole"] = { delay = 1, state = true },
    ["cassiopeiar"] = { delay = 0.3, state = true },
    ["curseofthesadmummy"] = { delay = 0.1, state = true },
    ["dariusexecute"] = { delay = 0.1, state = true },
    ["darkbindingmissile"] = { delay = 0.1, state = true },
    ["dazzle"] = { delay = 0.1, state = true },
    ["dianateleport"] = { delay = 0.1, state = true },
    ["disintegrate"] = { delay = 0.1, state = true },
    ["elisehumane"] = { delay = 0.1, state = true },
    ["elisespiderqcast"] = { delay = 0.1, state = true },
    ["ezrealmysticshot"] = { delay = 0.1, state = true },
    ["feast"] = { delay = 0.1, state = true },
    ["fiddlesticksdarkwind"] = { delay = 0.1, state = true },
    ["fling"] = { delay = 0, state = true },
    ["frostbite"] = { delay = 0.1, state = true },
    ["garenqattack"] = { delay = 0.1, state = true },
    ["garenr"] = { delay = 0.1, state = true },
    ["goldcardpreattack"] = { delay = 0.1, state = true },
    ["gnarr"] = { delay = 0.1, state = true },
    ["gragasr"] = { delay = 0.1, state = true },
    ["headbutt"] = { delay = 0.1, state = true },
    ["hecarimrampattack"] = { delay = 0.1, state = true },
    ["iceblast"] = { delay = 0.1, state = true },
    ["infiniteduress"] = { delay = 0, state = true },
    ["ireliaequilibriumstrike"] = { delay = 0.1, state = true },
    ["jaycethunderingblow"] = { delay = 0, state = true },
    ["judicatorreckoning"] = { delay = 0.1, state = true },
    ["karthusfallenone"] = { delay = 2, state = true },
    ["khazixq"] = { delay = 0.1, state = true },
    ["khazixqlong"] = { delay = 0.1, state = true },
    ["leblancchaosorb"] = { delay = 0.1, state = true },
    ["leblancchaosorbm"] = { delay = 0.1, state = true },
    ["leonashieldofdaybreakattack"] = { delay = 0.1, state = true },
    ["leonasolarflare"] = { delay = 0.1, state = true },
    ["lissandrar"] = { delay = 0.1, state = true },
    ["luluwtwo"] = { delay = 0.1, state = true },
    ["luxlightbinding"] = { delay = 0.1, state = true },
    ["malzaharr"] = { delay = 0, state = true },
    ["maokaiunstablegrowth"] = { delay = 0.1, state = true },
    ["missfortunericochetshot"] = { delay = 0.1, state = true },
    ["monkeykingqattack"] = { delay = 0.1, state = true },
    ["mordekaiserchildrenofthegrave"] = { delay = 0, state = true },
    ["namiw"] = { delay = 0.1, state = true },
    ["namiqmissile"] = { delay = 0.1, state = true },
    ["namirmissile"] = { delay = 0.2, state = true },
    ["nasusw"] = { delay = 0.1, state = true },
    ["nocturneunspeakablehorror"] = { delay = 0, state = true },
    ["nulllance"] = { delay = 0.1, state = true },
    ["olafrecklessstrike"] = { delay = 0.1, state = true },
    ["orianadetonatecommand"] = { delay = 0.1, state = true },
    ["pantheonq"] = { delay = 0.1, state = true },
    ["pantheonw"] = { delay = 0.1, state = true },
    ["parley"] = { delay = 0.1, state = true },
    ["powerfistattack"] = { delay = 0, state = true },
    ["pulverize"] = { delay = 0.1, state = true },
    ["puncturingtaunt"] = { delay = 0, state = true },
    ["redcardpreattack"] = { delay = 0.1, state = true },
    ["rocketgrab"] = { delay = 0.1, state = true },
    ["ryzew"] = { delay = 0, state = true },
    ["sionq"] = { delay = 0.1, state = true },
    ["skarnerimpale"] = { delay = 0.1, state = true },
    ["sonar"] = { delay = 0.1, state = true },
    ["sowthewind"] = { delay = 0.1, state = true },
    ["staticfield"] = { delay = 0.1, state = true },
    ["syndrar"] = { delay = 0.1, state = true },
    ["tahmkenchq"] = { delay = 0.1, state = true },
    ["tahmkenchw"] = { delay = 0.1, state = true },
    ["terrify"] = { delay = 0, state = true },
    ["threshq"] = { delay = 0.1, state = true },
    ["tristanae"] = { delay = 0.1, state = true },
    ["tristanar"] = { delay = 0.1, state = true },
    ["twoshivpoison"] = { delay = 0.1, state = true },
    ["xayahe"] = { delay = 0, state = true },
    ["vaynecondemn"] = { delay = 0.1, state = true },
    ["veigarbalefulstrike"] = { delay = 0.1, state = true },
    ["veigardarkmatter"] = { delay = 0.1, state = true },
    ["veigareventhorizon"] = { delay = 0.1, state = true },
    ["veigarr"] = { delay = 0.1, state = true },
    ["vir"] = { delay = 0.1, state = true },
    ["volibearqattack"] = { delay = 0, state = true },
    ["volibearw"] = { delay = 0.1, state = true },
    ["zedult"] = { delay = 0.74, state = true },
    ["zileanqattackaudio"] = { delay = 2.5, state = true },
    ["zoee"] = { delay = 0, state = true },
    ["zyrae"] = { delay = 0.1, state = true }
}

local IgniteFlott = nil
if player:spellSlot(4).name == "SummonerDot" then
	IgniteFlott = 4
elseif player:spellSlot(5).name == "SummonerDot" then
	IgniteFlott = 5
end

local function GetAARange(target)
    return player.attackRange + player.boundingRadius + (target and target.boundingRadius or 0)
end

local function GetPercentHealth(obj)
    local obj = obj or player
    return (obj.health / obj.maxHealth) * 100
end

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


local function GetIgniteDamage(target)
    local damage = 55 + (25 * player.levelRef)
    if target then
        damage = damage - (GetShieldedHealth("AD", target) - target.health)
    end
    return damage
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
local function E2()
    return player:spellSlot(2).name == "LuxLightstrikeToggle"
end
--
local function EnemysInrange(pos) 
	local enemies_in_range = {}
	for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
		if IsValidTarget(enemy)  then
			enemies_in_range[#enemies_in_range + 1] = enemy
		end
	end
	return enemies_in_range
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
local function VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or { x = ax + rS * (bx - ax), y = ay + rS * (by - ay) }
    return pointSegment, pointLine, isOnSegment
end
--
local function DamageR(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {300, 400, 500}
        if player:spellSlot(3).state == 0 then
			Damage = (DamageAP[player:spellSlot(3).level] + 0.70 * player.flatMagicDamageMod * player.percentMagicDamageMod)
        end
		return Damage
	end
	return 0
end
--
local MLux = menu("[Nicky]Lux", "[Nicky]Lux")
MLux:menu("Qc", "[Q] Settings")
MLux.Qc:boolean("CQ", "Combo [Q]", true)
MLux.Qc:boolean("LCQ", "Champion [Q2]", true)
--
MLux:menu("Wc", "[W] Settings")
MLux.Wc:boolean("CW", "Combo [W]", true)
--
MLux:menu("Ec", "[E] Settings")
MLux.Ec:boolean("CE", "Combo [E]", true)
--
MLux:menu("Rc", "[R] Settings")
MLux.Rc:boolean("CR", "Combo [R]", true)
--
MLux:menu("Dt", "Drawings Settings")
MLux.Dt:boolean("DQ", "Draw [Q]", true)
MLux.Dt:boolean("DW", "Draw [W]", true)
MLux.Dt:boolean("DE", "Draw [E]", true)
MLux.Dt:boolean("DR", "Draw [R]", true)

local function ObjESpell(obj)
    if obj and obj.name then 
        if string.find(obj.name, "E_tar_aoe_green") then
            e.ELight[obj.ptr] = obj 
            --print("Created "..obj.name)
            --print("check created")
        end
    end
end 

local function ObjDelete(obj)
    if obj and obj.name then 
        if string.find(obj.name, "E_tar_aoe_green") then
            e.ELight[obj.ptr] = nil 
            --print("Created "..obj.name)
            --print("check created")
        end
    end
end 

local delayR = 0
local function AutoR()
    local target = TargetSelecton(r.Range)
    if target and IsValidTarget(target) then
        local seg = pred.linear.get_prediction(PredR, target)
        if seg and seg.startPos:dist(seg.endPos) < r.Range and player.pos:dist(target.pos) > player.attackRange then
            if DamageR(target) > target.health then
                player:castSpell("pos", 3, vec3(seg.endPos.x, game.mousePos.y, seg.endPos.y))
                delayR = game.time
            end 
        end 
    end 
end 

local function CastQ(target)
    if player.pos:dist(target.pos) <= q.Range then
        local seg = pred.linear.get_prediction(PredQ, target)
        if seg and seg.startPos:dist(seg.endPos) < q.Range then
            if not pred.collision.get_prediction(PredQ, seg, target) then
                player:castSpell("pos", 0, vec3(seg.endPos.x, game.mousePos.y, seg.endPos.y))
            end
        end 
    elseif player.pos:dist(target.pos) <= q.Range then
        for i = 0, ObjMinion_Type.size[TEAM_ENEMY] - 1 do
            local minion = ObjMinion_Type[TEAM_ENEMY][i]
            local minionpos = vec3(minion.x, minion.y, minion.z)
            local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(target.pos, minionpos, player.pos)
            if isOnSegment and player.pos:dist(pointSegment) < 100 + target.boundingRadius then
                local seg = pred.linear.get_prediction(PredQ, target)
                if seg and seg.startPos:dist(seg.endPos) < q.Range then
                    player:castSpell("pos", 0, vec3(seg.endPos.x, game.mousePos.y, seg.endPos.y))
                end 
            end 
        end 
    elseif player.pos:dist(target.pos) <= q.Range then
        for i = 0, ObjMinion_Type.size[TEAM_ENEMY] - 1 do
            local minion = ObjMinion_Type[TEAM_ENEMY][i]
            if minion.pos:ext(target.pos, -475) then
                local seg = pred.linear.get_prediction(PredQ, target)
                if seg and seg.startPos:dist(seg.endPos) < q.Range then
                    player:castSpell("pos", 0, vec3(seg.endPos.x, game.mousePos.y, seg.endPos.y))
                end 
            end 
        end 
    else
        if player.pos:dist(target.pos) <= q.Range then
            local seg = pred.linear.get_prediction(PredQ, target)
            if seg and seg.startPos:distSqr(seg.endPos) < (1170 * 1170) then
                if not pred.collision.get_prediction(PredQ, seg, target) then
                    if table.getn(pred.collision.get_prediction(PredQ, seg, target)) == 1 then
                        player:castSpell("pos", 0, vec3(seg.endPos.x, game.mousePos.y, seg.endPos.y));
                    end
                end 
            end 
        end 
    end
end 

local function CastE(target)
    if not E2() and player.pos:dist(target.pos) <= e.Range then
        local rpred = pred.circular.get_prediction(PredE, target)
        if not rpred then return end
        local pred_pos = vec3(rpred.endPos.x, target.pos.y, rpred.endPos.y);
        player:castSpell("pos", 2, pred_pos) 
    end 
end 

local function OnProcesseSpell(spell)
    if spell.owner.type == TYPE_HERO and spell.owner.team == TEAM_ENEMY then
        if spellsW[spell.name:lower()] then
            local dist_to_spell = spell.endPos and player.path.serverPos:distSqr(spell.endPos) or nil
            if (spell.target and spell.target.ptr == player.ptr) or (dist_to_spell and dist_to_spell <= radius) then                    
              data.wait_time = os.clock() + spellsW[spell.name:lower()].delay
              state = true
              data.source = spell.owner
              data.spell_name = spell.name:lower()
            end 
        end 
    end 
end 

local delay = 0.1
local function AutoW()
    for _, spell in pairs(evade.core.active_spells) do
        if type(spell) == "table" and spellsW[spell.name:lower()] then
            if spell.missile and spell.missile.speed then
                if spell.target and spell.target.ptr == player.ptr then
                    if player.pos2D:dist(spell.owner.pos2D) < 600 and IsValidTarget(spell.owner) and player:spellSlot(1).state == 0  then
                        player:castSpell("pos", 1, spell.owner)
                    end 
                else
                    if spell.target and spell.target.ptr == player.ptr then
                        player:castSpell("pos", 1,  spell.owner)
                    end 
                end 
            end 
        end 
    end     
end 

local function CastW()
    if player:spellSlot(0).state == 0 then return end
    if GetPercentHealth(player) <= 70 and #EnemysInrange(600) >= 1 and player:spellSlot(1).state == 0 then
        player:castSpell("pos", 1, game.mousePos)
    end
end 

local function CanCastIgnite()
    for i = 0, objManager.enemies_n - 1 do
        local target = objManager.enemies[i]
        if target and IsValidTarget(target) then 
            if player.pos:dist(target.pos) <= 625 then
                if (IgniteFlott and player:spellSlot(IgniteFlott).state == 0) then
                    if GetIgniteDamage(target) > target.health then
                        player:castSpell("obj", IgniteFlott, target)
                    end
                end 
            end 
        end 
    end 
end 

local function CastE2()
    for i = 0, objManager.enemies_n - 1 do
        local target = objManager.enemies[i]
        if E2() then
            for _, Light in pairs(e.ELight) do
                if Light then
                    if Light.pos:distSqr(target.pos) < 310*310 then
                        player:castSpell("self", 2)
                    end 
                end 
            end 
        end 
    end 
end

local function OnTick()
    AutoW()
    CastE2()
    if MLux.Rc.CR:get() then
        AutoR()
    end 
    --
    if (orb.combat.is_active()) then 
        local targetQ = TargetSelecton(q.Range)
        local targetE = TargetSelecton(e.Range)
        if targetQ and IsValidTarget(targetQ) then
            CastQ(targetQ) 
        end 
        if targetE and IsValidTarget(targetE) then
            CastE(targetE)
        end 
    end
    CastW()
    CanCastIgnite()
end 

local function OnDraw()
    if IsValidTarget(player) then
        if player.isVisible and player.isOnScreen and not player.isDead then
            if IsReady(0) and MLux.Dt.DQ:get() then
                graphics.draw_circle(player.pos, q.Range, 2, graphics.argb(255, 255, 0, 255), 100)
            end
            if IsReady(1) and MLux.Dt.DW:get() then
                graphics.draw_circle(player.pos, w.Range, 2, graphics.argb(255, 255, 204, 255), 100)
            end
            if IsReady(2) and MLux.Dt.DE:get()  then
                graphics.draw_circle(player.pos, e.Range, 2, graphics.argb(255, 255, 204, 255), 100)
            end 
            if IsReady(3) and MLux.Dt.DR:get() then
                graphics.draw_circle(player.pos, r.Range, 2, graphics.argb(255, 255, 204, 255), 100)
            end        
        end
       --[[ for _, Adaga in pairs(e.ELight) do
            if Adaga then
                local Adagapos = vec3(Adaga.x, Adaga.y, Adaga.z)
                if player.isVisible and player.isOnScreen and not player.isDead then
                    graphics.draw_circle(Adagapos, 310, 1, graphics.argb(255, 255, 0, 0), 100) 
                end 
            end 
        end ]]
    end 
end 

orb.combat.register_f_pre_tick(OnTick)
cb.add(cb.create_particle, ObjESpell)
cb.add(cb.delete_particle, ObjDelete)
cb.add(cb.draw, OnDraw)
cb.add(cb.spell, OnProcesseSpell)