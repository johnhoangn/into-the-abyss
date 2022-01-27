local Calculators = {}


function Calculators:CalculateSimple(base, target, baseVal)
    local modifiers = self:GetModifiers(base)
    local flatMod = 0
    local percMod = 1

    for _, modifier in ipairs(modifiers) do
        for effect, effectData in pairs(modifier.Effects) do
            if (effect == target) then
                if (effectData.IsPercentage) then
                    percMod += effectData.Value
                else
                    flatMod += effectData.Value
                end
            end
        end
    end

    return (baseVal + flatMod) * percMod
end


function Calculators:CalculateWalkspeed(base)
    return Calculators.CalculateSimple(self, base, "Walkspeed", 16)
end


function Calculators:CalculateJumpPower(base)
    return Calculators.CalculateSimple(self, base, "JumpPower", 50)
end


return Calculators