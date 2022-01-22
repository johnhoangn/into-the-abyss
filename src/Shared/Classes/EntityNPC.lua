-- EntityNPC class
--
-- Dynamese (Enduo)
-- 12.11.2021



local EntityNoid = require(script.Parent.EntityNoid)
local EntityNPC = {}
EntityNPC.__index = EntityNPC
setmetatable(EntityNPC, EntityNoid)

-- Normal constructor
-- @param base <Model>
-- @param initParams <table> == nil, convenience for EntityNPC subclasses
-- @returns <EntityNPC>
function EntityNPC.new(base, initParams)
	local self = EntityNoid.new(base, initParams)

	return setmetatable(self, EntityNPC)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityNPC end


return EntityNPC
