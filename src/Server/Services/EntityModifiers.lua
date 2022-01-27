-- EntityModifiers server
--
-- "Modifiers," Not to be confused with an item's "Modifiers*" field,
--  or a "modifier key," etc. Will be used to refer to the collection
--  of entity-state affecting objects such as:
--  Conditions (Buffs, Ailments), Passives (Skills), Equipment effects*(Enchants, Innates, etc.)
--
-- An item's "Modifiers" list refers to modifiers that will be applied to the owning
--  entity via this service by EquipService
--
-- Manages modifiers such as status effects in a single place
-- Also applies modifier effects that must happening on application of the modifier
--  as well as those that tick over time e.g. modifier effects such as max health
-- The modifier effects, to be non-exhaustive, melee/ranged/arcane defense/offense, are 
--  not "applied," but rather are simply kept track of until someone who needs to
--  do calculations with them comes along and accumulates a bunch for their work
-- 
-- Dynamese(Enduo)
-- 01.25.22



local EntityModifiers = { Priority = 690; }
local Calculators
local Network, EntityService
local HttpService

local ModifierFactory

local ManagedBases


-- Begins tracking an entity's base
-- @param base <Model> associated with an entity
function EntityModifiers:Manage(base)
    local manager = self.Classes.IndexedMap.new()

    manager.Unmanager = base.AncestryChanged:Connect(function()
        self:Unmanage(base)
    end)

    ManagedBases:Add(base, manager)
end


-- Stops tracking this base
-- @param base <Model> associated with an entity
function EntityModifiers:Unmanage(base)
    local manager = ManagedBases:Remove(base)

    manager.Unmanager:Disconnect()
    
    for _mUID, modifier in manager:KeyIterator() do
        if (modifier.Expirer) then
            modifier.Expirer:Disconnect()
        end
        if (modifier.Repeater) then
            modifier.Repeater:Disconnect()
        end
    end
end


-- Adds a modifier to a managed base
-- @param base <Model>
-- @param baseID <string>
-- @param modifierArgs <map> modifier constructor args for if an effect's power is to be overridden
-- @param name <string?>
-- @returns <string?> mUID
function EntityModifiers:AddModifier(base, baseID, modifierArgs, name)
    local manager = ManagedBases:Get(base)

    if (not manager) then
        return nil
    end

    local mUID = HttpService:GenerateGUID()
    local asset = self.Services.AssetService:GetAsset(baseID)
    local modifier = ModifierFactory:Make(mUID, asset, modifierArgs or {}, name)

    manager:Add(mUID, modifier)

    -- If this modifier has an applicator module, link the modifier to DGF so it has services,
    --  and also inject the modifier into the applicator so it has self context (with modifierArgs), 
    --  then finally call on the entity base
    if (asset.Applicator ~= nil) then
        self:Link(modifier)
        modifier.Applicator.Apply(modifier, base)

        -- Kick off periodic application if applicable (haha)
        if (modifier.ContainsOverTimeEffect) then
            modifier.Repeater = self.Modules.ThreadUtil.DelayRepeat(
                1, modifier.Applicator, modifier, base)
        end
    end

    -- Expire the modifier, allowing for timer refreshing
    if (modifier.ExpiresAt > 0) then
        modifier.Expirer = self.Modules.ThreadUtil.DelayRepeat(1, function()
            if (tick() >= modifier.ExpiresAt) then
                self:Unmanage(base, mUID)
            end
        end)
    end

    -- Apply movement modifiers
    EntityService:GetEntity(base):UpdateMovement()

    -- Let everyone know
    Network:FireAllClients(
        Network:Pack(
            Network.NetProtocol.Forget,
            Network.NetRequestType.ReplicateModifierAdd,
            base,
            baseID,
            modifierArgs,
            name
        )
    )

    return mUID
end


function EntityModifiers:RefreshModifier(base, mUID, offset)
    -- modifier.ExpiresAt += offset
end


function EntityModifiers:RemoveModifier(base, mUID)
end


function EntityModifiers:GetModifiers(base)
    local manager = ManagedBases:Get(base)
    local modifiers = {}

    for _mUID, modifier in manager:KeyIterator() do
        table.insert(modifiers, modifier)
    end

    return modifiers
end


function EntityModifiers:CalculateTarget(base, target)
    return Calculators["Calculate" .. target](self, base)
end


function EntityModifiers:IsManaging(base)
    return ManagedBases:Get(base) ~= nil
end


function EntityModifiers:EngineInit()
    Network = self.Services.Network
    EntityService = self.Services.EntityService

    HttpService = self.RBXServices.HttpService

    ModifierFactory = self.Modules.EntityModifierFactory
    Calculators = self.Modules.EntityModifierCalculators

    ManagedBases = self.Classes.IndexedMap.new()
end


function EntityModifiers:EngineStart()
	EntityService.EntityCreated:Connect(function(base)
        self:Manage(base)
    end)
end


return EntityModifiers