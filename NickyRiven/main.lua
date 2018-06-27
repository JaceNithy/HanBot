local orb = module.internal("orb");
local evade = module.internal("evade");
local pred = module.internal("pred");
local ts = module.internal('TS');

local avada_lib = module.lib('avada_lib')
--Avada Lib
local common = avada_lib.common
local dmglib = avada_lib.damageLib


local NeCHTRiven = { }
local Spells = { }

--Spells
local Spells.Q = { Range = 260, QCout = 1 }
local Spells.W = { Range = 225 }
local Spells.E = { Range = 325 }
local Spells.R = { Range = 1100,  Width = 160, Delay = 0.25, Speed = 1600}

local function  LoadingRiven()
    NeCHTRiven:OnLoad()
end

function NeCHTRiven:OnLoad()

    self.targettedSpells =
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

  self.avoidableSpells =
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


    --CB
    cb.add(cb.tick, function() self:OnTick() end)
    cb.add(cb.draw, function() self:OnDraw() end)
    cb.add(cb.spell, function(spell) self:OnProcessSpell(spell) end)
    cb.add(cb.updatebuff, function(buff) self:OnUpdateBuff(buff) end)
    cb.add(cb.removebuff, function(buff) self:OnRemoveBuff(buff))
end 

--Loading
LoadingRiven()

