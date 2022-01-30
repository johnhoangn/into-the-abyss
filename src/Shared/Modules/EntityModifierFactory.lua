local Factory = {}


-- @param mUID <string>
-- @param asset <Asset>
-- @param modifierArgs <map> modifier constructor args
-- @param name <string?>
function Factory:Make(mUID, asset, modifierArgs, name)
    local expiresIn = modifierArgs.ExpiresIn or asset.ExpiresIn -- When replicating, subtract network delta
    local mod = {
        Name = name or asset.AssetName;
        Class = asset.Class;
        UID = mUID;
        Effects = {};
        ExpiresAt = -1;
    }

    if (expiresIn ~= nil) then
        mod.ExpiresAt = tick() + expiresIn
    end

    -- Parse modifier effects and normalize as to be used 
    --  uniformly by any interested parties
    if (asset.Effects) then
        for effect, value in pairs(asset.Effects) do
            local isPercentage = effect:sub(1, 1) == "%";

            if (isPercentage) then effect = effect:sub(2) end
            if (not mod.ContainsOverTimeEffect and effect:find("Time")) then 
                mod.ContainsOverTimeEffect = true 
            end

            mod.Effects[effect] = {
                Value = value;
                IsPercentage = isPercentage;
                Args = modifierArgs[effect] or {};
            }
        end
    end

    return mod
    --[[
        {
            Class;
            Effects = {
                Value;
                IsPercentage;
                Applies;
                Args;
            }
            ExpiresAt;
        }
    ]]--
end


return Factory