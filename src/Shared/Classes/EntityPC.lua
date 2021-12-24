-- EntityPC class
--
-- Dynamese (Enduo)
-- 12.11.2021



local Engine = _G.Deep
local AssetService = Engine.Services.AssetService
local WeldUtil = Engine.Modules.WeldUtil
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

	self.FaceAsset = AssetService:GetAsset(initialParams._FaceID or "060")

	return setmetatable(self, EntityPC)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityPC end


-- Extended, attaches face
local superDraw = EntityPC.Draw
function EntityPC:Draw(dt)
	superDraw(self, dt)

	if (self.Face == nil) then
		self.Face = false

		local face = self.FaceAsset.Model:Clone()
		local parts = {}

        for _, part in ipairs(face:GetDescendants()) do
            if (part:IsA("BasePart") and part.Transparency < 1) then
                parts[part] = part.Transparency
            end
        end

		self._FaceParts = parts
		face:PivotTo(self.Skin.Head.CFrame)
		WeldUtil:WeldModelToPart(self.Skin.Head, face, true)
		face.Parent = self.Base
		self.Face = face
	end
end


-- Extended, removes the face
local superHide = EntityPC.Hide
function EntityPC:Hide()
	superHide(self)	

    self.Face:Destroy()
    self.Face = nil
    self._FaceParts = nil
end


return EntityPC
