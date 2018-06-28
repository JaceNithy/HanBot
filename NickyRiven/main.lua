local orb = module.internal("orb");
local evade = module.internal("evade");
local pred = module.internal("pred");
local ts = module.internal('TS');

local avada_lib = module.lib('avada_lib')
--Avada Lib
local common = avada_lib.common
local dmglib = avada_lib.damageLib


local NickyRiven = { }
local Spells = { }

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

--Variable

NickyRiven.FlashRange = 425 + 70 + 225 -- == self.FlashRange
NickyRiven.EngangeRange = 325
NickyRiven.QLastCastTick = 0
NickyRiven.WLastCastTick = 0
NickyRiven.ELastCastTick = 0
NickyRiven.RWindslashReady = false 
NickyRiven.RAttackRangeBoost = false

NickyRiven.SummonerSF = {
    IsFlash = {
        slot = player:spellSlot(4).name:find("SummonerFlash") and 4 or 5
    }
}

NickyRiven.targettedSpells =
{
   "MonkeyKingSpinToWin",
   "KatarinaRTrigger",
   "HungeringStrike",
   "RengarPassiveBuffDashAADummy",
   "RengarPassiveBuffDash",
   "BraumBasicAttackPassiveOverride",
   "gnarwproc",
   "hecarimrampattack",
   "illaoiwattack",
   "JaxEmpowerTwo",
   "JayceThunderingBlow",
   "RenektonSuperExecute",
   "vaynesilvereddebuff"
}

NickyRiven.avoidableSpells =
{
   "MonkeyKingQAttack",
   "FizzPiercingStrike",
   "IreliaEquilibriumStrike",
   "RengarQ",
   "GarenQAttack",
   "GarenRPreCast",
   "PoppyPassiveAttack",
   "viktorqbuff",
   "FioraEAttack",
   "TeemoQ"
}

--Spells
local SpellsQr = { Range = 260, QCout = 1}
local SpellsWr = { Range = 225 }
local SpellsEr = { Range = 325 }
local SpellsRr = { Range = 1100,  Width = 160, Delay = 0.25, Speed = 1600}
local RPsred = { delay = 0.25, width = 160, speed = 1600, boundingRadiusMod = 1, collision = { hero = false, minion = false,}}

local function LoadingRiven()
    NickyRiven:OnLoad()
    NickyRiven:MenuRiven()
end

function NickyRiven:MenuRiven()
    --local menu = menu("Nicky [Vayne]", "Vayne: By Nicky")
    self.mymenu = menu("Nicky [Riven]", "Riven:By Nicky")
    self.mymenu:menu("ri", "Setting [Riven]")
    self.mymenu.ri:boolean("AFE", "Auto Flash Execute", true)
    self.mymenu.ri:boolean("UT", "Use Tiamat", true)
    self.mymenu.ri:boolean("RC", "Use R in Combo", true)
    self.mymenu.ri:boolean("Keep", "Keep Q Active", true)
    self.mymenu.ri:header("xd", "Draws")
    self.mymenu.ri:boolean("Engage", "Draw Engage Range", true)
    self.mymenu.ri:header("x2d", "Burts [Key]")
    self.mymenu.ri:keybind("CK", "[Key] Burts", "T", nil)
    self.mymenu.ri:keybind("ComK", "[Key] Burts", "Space", nil)
end 

function NickyRiven:OnLoad()
    --CB
    cb.add(cb.tick, function() self:OnTick() end)
    cb.add(cb.draw, function() self:OnDraw() end)
    cb.add(cb.spell, function(spell) self:OnProcessSpell(spell) end)
    cb.add(cb.updatebuff, function(buff) self:OnUpdateBuff(buff) end)
    cb.add(cb.removebuff, function(buff) self:OnRemoveBuff(buff) end)
    orb.combat.register_f_after_attack(function() self:OnPreAttack() end)
    orb.combat.register_f_pre_tick(function() self:OnPreTick() end)
end 


function NickyRiven:OnTick()
    if player:spellSlot(3).state == 0 and self.mymenu.ri.RC:get() then 
        self.EngangeRange = SpellsEr.Range + player.attackRange + 230
    else
        self.EngangeRange = SpellsEr.Range + player.attackRange + 150
    end 

    if self.mymenu.ri.Keep:get() and self.QLastCastTick and os.clock() - self.QLastCastTick > 3.25 and SpellsQr.QCout ~= 1 then
        player:castSpell("pos", 0, game.mousePos)
    end 
    if self.mymenu.ri.CK:get() then
        player:move(game.mousePos)
        self:BurtsMode()
    end 
    ---Buffs
    if player.buff["rivenwindslashready"] then
        self.RWindslashReady = true
    else 
        self.RWindslashReady = false
    end 
    if player.buff["RivenFengShuiEngine"] then
        self.RAttackRangeBoost = true
    else
        self.RAttackRangeBoost = false
    end 
    self:LeituraSpell()
   -- player:castSpell("pos", Flash4, game.mousePos)
 --  self:CanCastTimat() 
    if self.mymenu.ri.UT:get() then
        local inimigo = common.GetEnemyHeroes()
        for i, target in ipairs(inimigo) do
            self:CanCastTimat(target)
        end        
    end 
    if self.RWindslashReady then
        local inimigo = common.GetEnemyHeroes()
        for i, target in ipairs(inimigo) do
            local hp = common.GetShieldedHealth("ap", target)
            if target and target.isVisible and common.IsValidTarget(target) and not target.isDead and dmglib.GetSpellDamage(3, target) > hp then
                self:CastR(target)
            end 
        end 
    end     
    if self.mymenu.ri.ComK:get() then     
        local inimigo = common.GetEnemyHeroes()
        for i, target in ipairs(inimigo) do
            if target and target.isVisible and common.IsValidTarget(target) and not target.isDead and player.pos:dist(target.pos) <= self.EngangeRange then
                player:castSpell("pos", 2, target.pos)
                if player:spellSlot(3).state == 0 and not self.RWindslashReady then
                    self:CastR(target)
                end
            end 
        end 
    end 
    if self.mymenu.ri.AFE:get() then 
        local inimigo = common.GetEnemyHeroes()
        for i, target in ipairs(inimigo) do
            local hp = common.GetShieldedHealth("ap", target)
            if player:spellSlot(2).state == 0 and target and target.isVisible and common.IsValidTarget(target) and not target.isDead and target.pos:dist(player.pos) >= 500 and (dmglib.GetSpellDamage(0, target) * 3 + dmglib.GetSpellDamage(1, target) + dmglib.GetSpellDamage(3, target) > hp) then
                local flashPos = target.pos + (target.pos - player.pos):norm() * -100
                player:castSpell("pos", 2, target.pos)
                common.DelayAction(function() player:castSpell("pos", Flash4, vec3(flashPos)) end, 0.2)
            end 
        end 
    end    
end 

function NickyRiven:OnPreTick()
--
end 

function NickyRiven:BurtsMode()
    local range = self.FlashRange - 425
    if player:spellSlot(Flash4).state == 0 then
        range = range + 425
    end 
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and common.IsValidTarget(target) and not target.isDead and player.pos:dist(target.pos) <= range then
            if player:spellSlot(2).state == 0 then
                player:castSpell("pos", 2, target.pos)
            end 
            if player:spellSlot(3).state == 0 then
                self:CastR(target)
            end 
            if player:spellSlot(1).state == 0 and player.pos:dist(target.pos) <= 225 + target.boundingRadius then
                player:castSpell("self", 1)
            end 
            if player:spellSlot(Flash4).state == 0 and player:spellSlot(1).state == 0 then
                self:FlashW(target)
            end 
        end 
    end 
end 


function NickyRiven:FlashW(target)
    local flashPos = target.pos + (target.pos - player.pos):norm() * -180
  
    if self.RAttackRangeBoost or player:spellSlot(3).state == 0 then
   --     player:castSpell("self", 1)
        common.DelayAction(function() player:castSpell("pos", Flash4, vec3(flashPos)) end, 0.2)
    else
        player:castSpell("pos", Flash4, vec3(flashPos))
        --player:castSpell("self", 1)
    end
end

function NickyRiven:CastR(target)
    if self.RWindslashReady then
        local RPred = pred.linear.get_prediction(RPsred, target)
        if RPred and RPred.startPos:dist(RPred.endPos) < SpellsRr.Range then
            self:CanCastTimat(target)
            common.DelayAction(function() player:castSpell("pos", 3, vec3(RPred.endPos.x, RPred.endPos.y, RPred.endPos.y)) end, 0.25)
        end
        player:castSpell("pos", 3, vec3(RPred.endPos.x, RPred.endPos.y, RPred.endPos.y))
        orb.core.reset() 
    else 
        player:castSpell("self", 3)
    end
end 

function NickyRiven:LeituraSpell()
    if player:spellSlot(4).name == "SummonerFlash" then
        Flash4 = 4
      elseif player:spellSlot(5).name == "SummonerFlash" then
        Flash4 = 5
    end
end 

function NickyRiven:Reset()
    player:move(game.mousePos)
    orb.core.set_pause_move(0)
    orb.core.set_pause_attack(0)
    orb.core.reset() 
end

function NickyRiven:CastQ(target)
    local delay = math.min(60/1000, network.latency/1000)
    local coreDelay =  0.21 - (0.008 * player.levelRef)
    delay = delay + coreDelay
  
    if SpellsQr.QCout == 3 then
      delay = delay + 0.03
    end
    if self:CanCastTimat(target) and SpellsQr.QCout == 3 then
        self:CanCastTimat(target) 
        common.DelayAction(function() player:castSpell('obj', 0, target) end, 0.23)
    else
        player:castSpell('obj', 0, target)
    end
    orb.core.set_pause_move(math.huge)
    orb.core.set_pause_attack(math.huge)
    common.DelayAction(function() self:Reset() end, delay)
end 

function NickyRiven:CanCastTimat(target)
   -- local inimigo = common.GetEnemyHeroes()
   -- for i, target in ipairs(inimigo) do
        if (target.pos:dist(player) <= 275) then
            for i = 6, 11 do
                local item = player:spellSlot(i).name
                if item and (item == "ItemTiamatCleave") then
                    player:castSpell("obj", i, target)
                end
                if item and (item == "ItemTitanicHydraCleave") then
                    player:castSpell("obj", i, target)
                end
            end 
        end 
   -- end 
end 

function NickyRiven:OnPreAttack()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and common.IsValidTarget(target)  and not target.isDead  then
            if self.mymenu.ri.CK:get() then
                if player:spellSlot(3).state == 0 then
                    self:CastR(target)
                end
                if self.RWindslashReady then
                    common.DelayAction(function() self:CastQ(target) end, 0.25)
                end 
            elseif player:spellSlot(0).state == 0  then
                self:CastQ(target)
            end 
            if orb.combat.target then
                if player:spellSlot(3).state == 0 then
                    if not self.RWindslashReady and self:ComboDamage(target) > target.health then
                        player:castSpell("self", 3)
                        common.DelayAction(function() self:CastW(target) end, 0.325)
                    end
                    if SpellsQr.QCout == 3 and target.health / target.maxHealth * 100 <= 50 then
                        self:CastR(target)
                        common.DelayAction(function() player:castSpell('obj', 0, target) end, 0.3)
                    end 
                end 
                if player:spellSlot(1).state == 0 and os.clock() - self.ELastCastTick < 1.20 then
                    self:CastW(target)
                end
                if player:spellSlot(0).state == 0 then
                    self:CastQ(target)
                    if player:spellSlot(1).state == 0 and os.clock() - self.ELastCastTick >= 0.100 then
                        common.DelayAction(function() self:CastW(target) end, 0.6)
                        common.DelayAction(function() self:CastQ(target) end, 0.8)
                    end
                end
            end 
        end 
    end 
end 

function NickyRiven:CastW(target)
    local wRange = 125 + target.boundingRadius
  
    if self.RAttackRangeBoost then
      wRange = wRange + 10
    end
  
    if target.pos:dist(player.pos) <= wRange then
        player:castSpell("self", 1)
    end
end

function NickyRiven:OnDraw()
    if self.mymenu.ri.Engage:get() then
        if player.isOnScreen then
            if player:spellSlot(2).state == 0 then
                graphics.draw_circle(player.pos, self.EngangeRange, 2, graphics.argb(255, 0, 204, 255), 100)
            end 
        end 
    end 
end 

function NickyRiven:OnProcessSpell(spell)
    if spell.name == "RivenTriCleave" then
        self.QLastCastTick = os.clock()
        SpellsQr.QCout = SpellsQr.QCout + 1


        if SpellsQr.QCout > 3 then
            SpellsQr.QCout = 1
        end
    
    elseif spell.name == "RivenMartyr" then
        self.WLastCastTick = os.clock()
    elseif spell.name == "RivenIzunaBlade" and player:spellSlot(0).state == 0 then
        local inimigo = common.GetEnemyHeroes()
        for i, target in ipairs(inimigo) do
            if target and target.isVisible and common.IsValidTarget(target) and not target.isDead and player.pos:dist(target.pos) <= player.attackRange + 200 then
                common.DelayAction(function() player:castSpell("pos", 0, target) end, 0.15)
            end 
        end 
    elseif player:spellSlot(2).state == 0  then
        if spell.owner.type == TYPE_MISSILE and spell.owner.team == TEAM_ENEMY then
            if vec3(spell.endPos.x, spell.endPos.y, spell.endPos.z):dist(player.pos) > 400 then return end
            if table.contains(self.targettedSpells, spell.name) or table.contains(self.avoidableSpells, spell.name) then
                player:castSpell("pos", 2, game.mousePos)

                if target.pos:dist(player.pos) <= SpellsWr.Range then
                    self:CastW(target)
                end
            end 
        end 
    end
end 


function NickyRiven:OnUpdateBuff(buff)
    if buff.name == "RivenFeint" then
        self.ELastCastTick = os.clock()
    end
end 

function NickyRiven:OnRemoveBuff(buff)
--Rs
end 

function NickyRiven:ComboDamage(target)
    local aa = common.GetTotalAD()
    local dmg = aa
  --  local hp = common.GetShieldedHealth("ap", target)

    if player:spellSlot(0).state == 0 then
        local count = 4 -  SpellsQr.QCout
        dmg = dmg + (dmglib.GetSpellDamage(0, target) + aa) * count
    end 
    if player:spellSlot(1).state == 0 then
        dmg = dmg + dmglib.GetSpellDamage(1, target)
    end 
    if player:spellSlot(3).state == 0 then
        dmg = dmg + dmglib.GetSpellDamage(3, target)
    end 

    dmg = self:RealDamage(target, dmg)
    return dmg
end 

function NickyRiven:RealDamage(target, damage)
    if target.buff["KindredRNoDeathBuff"] or target.buff["JudicatorIntervention"] or target.buff["FioraW"] or target.buff["ShroudofDarkness"]  or target.buff["SivirShield"] then
        return 0  
    end
    local pbuff = target.buff["UndyingRage"]
    if target.buff["UndyingRage"] and pbuff.endTime > os.clock() + 0.3  then
        return 0
    end
    local pbuff2 = target.buff["ChronoShift"]
    if target.buff["ChronoShift"] and pbuff2.endTime > os.clock() + 0.3 then
        return 0
    end
    if player.buff["SummonerExhaust"] then
        damage = damage * 0.6;
    end
    if target.buff["BlitzcrankManaBarrierCD"] and target.buff["ManaBarrier"] then
        damage = damage - target.MP / 2
    end
    if target.buff["GarenW"] then
        damage = damage * 0.6;
    end
    return damage
end

--Loading
LoadingRiven()

