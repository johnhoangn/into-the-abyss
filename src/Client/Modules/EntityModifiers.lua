-- EntityModifiers client, submodule of entityservice
-- Manages modifiers such as status effects in a single place
-- 
-- Dynamese(Enduo)
-- 01.25.22



local EntityModifiers = {}
local EntityService, AssetService, Network

local ManagedBases


function EntityModifiers:Manage(base)
    base.AncestryChanged:Connect(function()
        self:Unmanage(base)
    end)

    ManagedBases:Add(base, self.Classes.IndexedMap.new())
end


function EntityModifiers:Unmanage(base)
end


function EntityModifiers:AddModifier(base, mType, mUID, ...)
end


function EntityModifiers:RemoveModifier(base, mUID)
end


function EntityModifiers:GetModifiers(base)
end


function EntityModifiers:GetModifiersOfType(base, mType)
end


function EntityModifiers:EngineInit()
	EntityService = self.Services.EntityService
    AssetService = self.Services.AssetService
    Network = self.Services.Network

    ManagedBases = self.Classes.IndexedMap.new()
end


function EntityModifiers:EngineStart()
	
end


return EntityModifiers