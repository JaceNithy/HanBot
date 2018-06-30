local orb = module.internal("orb");
local EvadeInternal = module.internal("evade");
local pred = module.internal("pred");
local ts = module.internal('TS');

local avada_lib = module.lib('avada_lib')
--Avada Lib
local common = avada_lib.common
local dmglib = avada_lib.damageLib

local function EnemysInrange(pos, range) -- ty Kornis Thank you for allowing your code
	local enemies_in_range = {}
	for i = 0, objManager.enemies_n - 1 do
		local enemy = objManager.enemies[i]
		if pos:dist(enemy.pos) < range and common.IsValidTarget(enemy) then
			enemies_in_range[#enemies_in_range + 1] = enemy
		end
	end
	return enemies_in_range
end

--Real HP
local function GetRealHP(unit, dmgType)
    local mod = dmgType == 0 and unit.magicalShield or unit.allShield
    return unit.health + mod
end


local NickyKatarina = { }

--Variable
NickyKatarina.DaggerRal = { }
NickyKatarina.IsValidDanger = 0 
NickyKatarina.CountDagger = 0
NickyKatarina.RDance = false

--Spells
-- Q = 0
-- W = 1
-- E = 2 
-- R = 3
NickyKatarina.SpellQ = { Range = 625 }
NickyKatarina.SpellW = { Range = 340 }
NickyKatarina.DanggerSpell = { Range = 340 }
NickyKatarina.SpellE = { Range = 725 }
NickyKatarina.SpellR = { Range = 550 }


local function LoadingKat()
    NickyKatarina:OnLoad()
    NickyKatarina:MenuKat()
end

function NickyKatarina:OnLoad()
    cb.add(cb.tick, function() self:OnTick() end)
    cb.add(cb.draw, function() self:OnDraw() end)
    cb.add(cb.updatebuff, function(buff) self:OnUpdateBuff(buff) end)
    cb.add(cb.removebuff, function(buff) self:OnRemoveBuff(buff) end)
    cb.add(cb.createobj, function(obj) self:OnCreateObj(obj) end)
    cb.add(cb.deleteobj, function(obj) self:OnDeleteObj(obj) end)
end 

function NickyKatarina:MenuKat()
    self.mymenu = menu("Nicky [Katarina]", "Katarina:By Nicky")
    self.mymenu:menu("kat", "Combo [Katarina]")
    self.mymenu.kat:boolean("AFE", "Use [Q]", true)
    self.mymenu.kat:boolean("UT", "Use [W]", true)
    self.mymenu.kat:boolean("RC", "Use [E] Dagger", true)
    self.mymenu.kat:boolean("OnlyE", "Only On Dagger", true)
    self.mymenu.kat:boolean("Keep", "Keep R Active", true) 
    self.mymenu.kat:boolean("CanR", "Cancel [R]", true) 
    self.mymenu.kat:slider("Rhitenemy", "Min. Enemies to Use", 2, 1, 5, 1)
    self.mymenu.kat:header("x2d", "[Key]")
    self.mymenu.kat:keybind("ComK", "[Key] Combo", "Space", nil)
end 

function NickyKatarina:OnTick()
    --CheckR
    self:CheckTheR()
    --CancelR
    if self.mymenu.kat.CanR:get() then
        self:ChancelR()
    end 
    if self.mymenu.kat.ComK:get() then
        if not self.RDance then
            self:ComboQ()
            self:EDagger()
        end 
    end 
    if self.mymenu.kat.OnlyE:get() and self.mymenu.kat.ComK:get() then
        local inimigo = common.GetEnemyHeroes()
        for i, target in ipairs(inimigo) do
            if self.CountDagger > 0 then
                self:EDagger()
            else
                self:ETargeted(target)
            end 
        end 
    end 
    self:KillSteal()
    self:CastW()
    self:CastR()
    self:CastR2()
    --self:CastR()
    --self:TestR()
    self:SpellSummoer()
    self:AutoIgnite()
end 

function NickyKatarina:ComboQ()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if not self.RDance then 
            if target and target.isVisible and common.IsValidTarget(target) and not target.isDead and player.pos:dist(target.pos) <= self.SpellQ.Range then
                player:castSpell("obj", 0, target)
            end 
        end   
    end 
end 

function NickyKatarina:EDagger()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        for _, Adaga in pairs(self.DaggerRal) do
            if not self.RDance then
            local spot = Adaga.pos + (target.pos - Adaga.pos):norm() * 125
            local delay = 0.2
            if os.clock() - self.IsValidDanger > 1.0 - delay then
                if player:spellSlot(2).state == 0  and spot:distSqr(target) < self.DanggerSpell.Range * self.DanggerSpell.Range then
                    player:castSpell("pos", 2, vec3(spot))
                end 
            end 
        end 
    end 
end 
end 

function NickyKatarina:KillSteal()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        local HealthEnemy = common.GetShieldedHealth("ap", target)
        if target and target.isVisible and common.IsValidTarget(target) and not target.isDead and player.pos:dist(target.pos) <= self.SpellQ.Range and dmglib.GetSpellDamage(0, target) > HealthEnemy then
            player:castSpell("obj", 0, target)
        end 
        if target and target.isVisible and common.IsValidTarget(target) and not target.isDead and player.pos:dist(target.pos) <= self.SpellE.Range and dmglib.GetSpellDamage(2, target) > HealthEnemy then
            player:castSpell("pos", 2, target.pos)
        end 
    end 
end 

function NickyKatarina:SpellSummoer()
    if player:spellSlot(4).name == "SummonerDot" then
        Ignite = 4
      elseif player:spellSlot(5).name == "SummonerDot" then
        Ignite = 5
    end
end 

function NickyKatarina:AutoIgnite()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if target and target.isVisible and common.IsValidTarget(target) and not target.isDead and player.pos:dist(target.pos) >= 550 then
            if self:DamageIgnite(target) > target.health then
                player:castSpell("obj", Ignite, target)
            end 
        end 
    end
end 

function NickyKatarina:CastW()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if not self.RDance then
            if target and target.isVisible and common.IsValidTarget(target) and not target.isDead and player.pos:dist(target.pos) < self.SpellW.Range/2 then
                if player:spellSlot(1).state == 0 then
                    player:castSpell("obj", 1, player)
                end 
            end 
        end 
    end 
end 

function NickyKatarina:ETargeted(target)
    if player:spellSlot(2).state == 0 and  not self.RDance and player.pos:dist(target.pos) < self.SpellE.Range then
        player:castSpell("pos", 2, target.pos)
    end 
end 

function NickyKatarina:OnUpdateBuff(buff)
    if player and buff.name == "katarinarsound" then
        self.RDance = true
    end 
end 

function NickyKatarina:OnRemoveBuff(buff)
    if player and buff.name == "katarinarsound" then
        self.RDance = false
    end 
end 

function NickyKatarina:OnCreateObj(obj)
    if obj then 
        if string.find(obj.name, "Katarina_Base_W_Indicator_Ally") then
            self.DaggerRal[obj.ptr] = obj
            self.IsValidDanger = os.clock()
            self.CountDagger = self.CountDagger + 1
        end 
    end 
end

function NickyKatarina:OnDeleteObj(obj)
    if obj then 
        if string.find(obj.name, "Katarina_Base_W_Indicator_Ally") then
            self.DaggerRal[obj.ptr] = nil
            self.IsValidDanger = 0
            self.CountDagger = self.CountDagger - 1
        end 
    end 
end 

function NickyKatarina:CastR()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        local HealthEnemy = common.GetShieldedHealth("ap", target)
        if #EnemysInrange(player.pos, 500 - 100) >= self.mymenu.kat.Rhitenemy:get() and target and target.isVisible and common.IsValidTarget(target) and not target.isDead and player.pos:dist(target.pos) <= self.SpellR.Range and self:GetRDamage(target) > target.health then
            player:castSpell("obj", 3,  player)
        end 
    end 
end 

function NickyKatarina:CastR2()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        local HealthEnemy = common.GetShieldedHealth("ap", target)
        if target and target.isVisible and common.IsValidTarget(target) and not target.isDead and player.pos:dist(target.pos) <= self.SpellR.Range and self:GetRDamage(target) > target.health then
            player:castSpell("obj", 3,  player)
        end 
    end 
end 


function NickyKatarina:OnDraw()
    if player.isOnScreen then
        if player:spellSlot(0).state == 0 then
            graphics.draw_circle(player.pos, self.SpellQ.Range, 2, graphics.argb(255, 0, 204, 255), 100)
        end 
        if player:spellSlot(1).state == 0 then
            graphics.draw_circle(player.pos, self.SpellW.Range, 2, graphics.argb(255, 255, 255, 255), 100)
        end
        if player:spellSlot(2).state == 0 then
            graphics.draw_circle(player.pos, self.SpellE.Range, 2, graphics.argb(255, 0, 255, 0), 100)
        end
        if player:spellSlot(3).state == 0 then
            graphics.draw_circle(player.pos, self.SpellR.Range, 2, graphics.argb(255, 255, 204, 255), 100)
        end
    end 
    for _, Adaga in pairs(self.DaggerRal) do
        if Adaga then
            if player.isOnScreen then
                local delay = 0.2
                if os.clock() - self.IsValidDanger > 1.1 - delay then
                    graphics.draw_circle(Adaga.pos, 340, 2, graphics.argb(255, 0, 255, 0), 50)
                end 
            end 
        end 
    end 
end 

function NickyKatarina:CheckTheR()
    if self.RDance then
        if (EvadeInternal) then
            EvadeInternal.core.set_pause(math.huge)
        end 
        orb.core.set_pause_move(math.huge)
        orb.core.set_pause_attack(math.huge)
    else 
        if (EvadeInternal) then
            EvadeInternal.core.set_pause(0)
        end 
        orb.core.set_pause_move(0)
        orb.core.set_pause_attack(0)
    end 
end 

function NickyKatarina:ChancelR()
    local inimigo = common.GetEnemyHeroes()
    for i, target in ipairs(inimigo) do
        if self.RDance then
            if #EnemysInrange(player.pos, 550 + 5) == 0 then
                player:move(game.mousePos)
            else 
                self:ETargeted(target)
            end 
        end 
    end 
end 

function NickyKatarina:GetRDamage(target)
    if target ~= 0 then
		local Damage = 0
		local DamageAP = {375, 562.5, 750}

        if player:spellSlot(3).state == 0 then
			Damage = (DamageAP[player:spellSlot(3).level] + 3.3 * player.bonusSpellBlock + 2.85 * player.flatMagicDamageMod)
        end
		return Damage
	end
	return 0
end

function NickyKatarina:DamageIgnite(target)
    if target ~= 0 then
		local Damage = 0
        if player:spellSlot(Ignite).state == 0 then
			Damage = (50 + 20 * player.levelRef / 5 * 3)
        end
		return Damage
	end
	return 0
end

function NickyKatarina:GetEDamage(target)
    if target ~= 0 then
		local Damage = 0
		local DamageSpell = {15, 30, 45, 60, 75}

        if player:spellSlot(2).state == 0 then
			Damage = (DamageSpell[player:spellSlot(2).level] + 0.50 * player.bonusSpellBlock + 0.25 * player.flatMagicDamageMod)
        end
		return Damage
	end
	return 0
end

--
LoadingKat()
--
