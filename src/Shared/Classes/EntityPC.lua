-- EntityPC class
--
-- Dynamese (Enduo)
-- 12.11.2021



local EntityNoid = require(script.Parent.EntityNoid)
local EntityPC = {}
EntityPC.__index = EntityPC
setmetatable(EntityPC, EntityNoid)

-- Normal constructor
-- @param base <Model>
-- @param initialParams <table> == nil, convenience for EntityPC subclasses
-- @returns <EntityPC>
function EntityPC.new(base, initialParams)
	local self = EntityNoid.new(base, initialParams)

	return setmetatable(self, EntityPC)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityPC end


return EntityPC
