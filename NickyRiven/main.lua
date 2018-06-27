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
end 

function NickyRiven:OnLoad()
    --CB
    cb.add(cb.tick, function() self:OnTick() end)
    cb.add(cb.draw, function() self:OnDraw() end)
    cb.add(cb.spell, function(spell) self:OnProcessSpell(spell) end)
    cb.add(cb.updatebuff, function(buff) self:OnUpdateBuff(buff) end)
    cb.add(cb.removebuff, function(buff) self:OnRemoveBuff(buff) end)
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
end 

function NickyRiven:BurtsMode()
    local range = self.FlashRange - 425
    if player:spellSlot(Flash4).state == 0 then
        range = range + 425
    end 
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and player:dist(target) <= range then
            if orb.core.can_attack() then
                player:attack(target)
            end 
            if player:spellSlot(2).state == 0 then
                player:castSpell("pos", 0, target)
            end 
            if player:spellSlot(Flash4).state == 0  and player:spellSlot(1).state == 0 then
                self:FlashW(target)
            end 
        end 
    end 
end 


function NickyRiven:FlashW(target)
    local flashPos = target.pos + (target.pos - player.pos):norm() * -180
  
    if self.RAttackRangeBoost or player:spellSlot(3).state == 0 then
        player:castSpell('obj', 1, player)
        common.DelayAction(function() player:castSpell("pos", 0, Flash4) end, 0.2)
    else
        player:castSpell("pos", 0, Flash4)
        player:castSpell('obj', 1, player)
    end
end

function NickyRiven:LeituraSpell()
    if player:spellSlot(4).name == "SummonerFlash" then
        Flash4 = 4
      elseif player:spellSlot(5).name == "SummonerFlash" then
        Flash4 = 5
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
            if player.pos:dist(target.pos) <= player.attackRange + 200 then
                common.DelayAction(function() player:castSpell("pos", 0, target) end, 0.15)
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

--Loading
LoadingRiven()

