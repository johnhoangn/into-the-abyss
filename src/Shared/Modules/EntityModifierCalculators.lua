-- Calculator method module used by EntityModifiers
-- "self" refers to the requiring EntityModifiers module
--
-- Dynamese(Enduo)
-- 01.??.22


local Calculators = {}


-- Sums the flat and percentage modifier effects of each target in a targets list
-- @param modifiers <arraylike> list of modifiers affecting an entity
-- @param targets <dictionarylike> table of targets we're interested in
-- @returns <tuple<dictionarylike, dictionarylike>> sums of flat and percentage modifiers
function Calculators:SumTargets(modifiers, targets)
    local flats = {}
    local percs = {}

    for _, target in pairs(targets) do
        flats[target] = 0
        percs[target] = 1
    end

    for _, modifier in ipairs(modifiers) do
        for effect, effectData in pairs(modifier.Effects) do
            for _, target in ipairs(targets) do
                if (effect == target) then
                    if (effectData.IsPercentage) then
                        percs[target] += effectData.Value
                    else
                        flats[target] += effectData.Value
                    end
                end
            end
        end
    end

    return flats, percs
end


-- Macro for simple use, only interested in one target
-- @param entityBase <Model> base of an EntityNoid
-- @param target <string> interested effect total
-- @param baseVal <number> flat base
-- @returns resulting <number> 
function Calculators:CalculateSimple(entityBase, target, baseVal)
    local modifiers = self:GetModifiers(entityBase)
    local flats, percs = Calculators:SumTargets(modifiers, {target})

    return (baseVal + flats[target]) * percs[target]
end


-- Macros for movement targets
-- @param entityBase <Model>
function Calculators:CalculateWalkspeed(entityBase)
    return Calculators.CalculateSimple(self, entityBase, "Walkspeed", 16)
end
function Calculators:CalculateJumpPower(entityBase)
    return Calculators.CalculateSimple(self, entityBase, "JumpPower", 50)
end


-- Grabs flat and percentage combat modifier values
-- @param entitybase <Model>
-- @returns <tuple<dictionarylike, dictionarylike>>
function Calculators:CalculateOffensives(entityBase)
    local modifiers = self:GetModifiers(entityBase)
    local flats, percs = {}, {}
    local flatSums, percSums = Calculators:SumTargets(modifiers, {
        "ArcaneAttack", "MeleeAttack", "RangedAttack"
    })

    for target, val in pairs(flatSums) do
        flats[target:gsub("Attack", "")] = val
    end

    for target, val in pairs(percSums) do
        percs[target:gsub("Attack", "")] = val
    end

    return flats, percs
end
function Calculators:CalculateDefensives(entityBase)
    local modifiers = self:GetModifiers(entityBase)
    local flats, percs = {}, {}
    local flatSums, percSums = Calculators:SumTargets(modifiers, {
        "ArcaneDefense", "MeleeDefense", "RangedDefense"
    })

    for target, val in pairs(flatSums) do
        flats[target:gsub("Defense", "")] = val
    end

    for target, val in pairs(percSums) do
        percs[target:gsub("Defense", "")] = val
    end

    return flats, percs
end


return Calculators