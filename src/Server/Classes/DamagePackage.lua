-- Damage package class
-- Contains offensive information, can be used to inflict damage to multiple victims
--
-- Dynamese (Enduo)
-- 01.22.2022



local DamagePackage = {}
DamagePackage.__index = DamagePackage


-- Creates a new package containing damage information gathered from
--  an attacker entity
-- @param offensiveValues <table> flat values
-- @param offensiveMultipliers <table> % values to scale the flats by
-- @params ...Rate <number> based on the attack, scale again
-- @returns <DamagePackage>
function DamagePackage.new(offensiveValues, offensiveMultipliers, meleeRate, rangedRate, arcaneRate, allRate)
	local self = setmetatable({
        OffensiveValues = offensiveValues;
        OffensiveMultipliers = offensiveMultipliers;
        Rates = {
            Melee = meleeRate or 0;
            Ranged = rangedRate or 0;
            Arcane = arcaneRate or 0;
        };
        AllRate = allRate or 1;
    }, DamagePackage)
	
	return self
end


-- Replaces offensive values and multipliers
-- Used for instances where one value source is to be
--  dealt as a different type
--  e.g. spirit -> arcane
-- @param damageType <string> damage to be dealt as
-- @param value <integer> amount of the source
-- @param multiplier <number?> rate to scale this value
function DamagePackage:Substitute(damageType, value, multiplier)
    self.OffensiveValues[damageType] = value
    self.OffensiveMultipliers[damageType] = multiplier or self.OffensiveMultipliers[damageType]
end


-- Takes the victim's defenses into account and generates damage values
--  that should occur if the victim were to get hit by this package
-- @param victim <Entity>
-- @param isCrit <boolean>
-- @param critMult <number>
function DamagePackage:Mitigate(victim, isCrit, critMult)
    local defensiveValues = victim:GetDefensiveValues()
    local defensiveModifiers = victim:GetDefensiveMultipliers()
    local mitigated = {
        Damages = {};
        IsCrit = isCrit;
        Sum = 0
    }

    if (isCrit) then
        self.AllRate *= critMult * (1 - victim:GetCriticalDefense())
    end

    for damageType, rate in pairs(self.Rates) do
        local defensive = defensiveValues[damageType] * defensiveModifiers[damageType]
        local scaledDamage = self.OffensiveValues[damageType] 
            * self.OffensiveMultipliers[damageType] 
            * rate * self.AllRate

        local calculated = (scaledDamage ^ 2) / (scaledDamage + defensive)

        if (calculated ~= calculated) then
            calculated = 0
        else
            calculated = math.floor(calculated)
        end

        mitigated.Damages[damageType] = calculated
        mitigated.Sum += calculated
    end
    
    return mitigated
end


return DamagePackage
