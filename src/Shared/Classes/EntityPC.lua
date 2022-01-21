-- EntityPC class
--
-- Dynamese (Enduo)
-- 12.11.2021



local Engine = _G.Deep
local AssetService = Engine.Services.AssetService
local Players = Engine.RBXServices.Players
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
	if (not Engine.LocalPlayer) then
		initialParams.Equipment = Engine.Modules.EquipmentTemplates.GenerateDefaultEquipment("Empty")
	end

	local self = setmetatable(EntityNoid.new(base, initialParams), EntityPC)

	self.Player = Players:GetPlayerFromCharacter(base)
	self.FaceAsset = AssetService:GetAsset(initialParams._FaceID or "060")

	return self
end


-- @param equipSlot <Enums.EquipSlot>
-- @param itemData <ItemDescriptor>
function EntityPC:ChangeEquipment(equipSlot, itemData)
    if (self.Equipment[equipSlot].BaseID ~= itemData.BaseID 
        or self.Equipment[equipSlot].UID ~= itemData.UID) then

        self.Equipment[equipSlot] = itemData
        self:DrawEquipmentSlot(equipSlot)
    end
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityPC end


-- @param groupName <string> name of the submodel
-- @param equipSlot <Enums.EquipSlot> slot equipped to
-- @returns <string> name of the BasePart located in the entity's skin to mount the submodel to
local function ChooseAttachmentBase(groupName, equipSlot)
    if (groupName ~= "ESLOT_BASED") then
        return groupName
    else
        return equipSlot == EntityPC.Enums.EquipSlot.Primary and "Right"
            or equipSlot == EntityPC.Enums.EquipSlot.Secondary and "Left"
    end
end


function EntityPC:DrawEquipmentSlot(equipSlot)
    if (not self.EquipmentModels) then
        return
    end

    if (self.EquipmentModels[equipSlot] ~= nil) then
        self.EquipmentModels[equipSlot]:Destroy()
        table.clear(self.EquipmentModelsParts[equipSlot])
    end

    local itemData = self.Modules.TableUtil.Copy(self.Equipment[equipSlot])

    if (itemData.BaseID ~= -1) then
        local asset = AssetService:GetAsset(itemData.BaseID)
        local model = asset.EquipModel:Clone()

        -- Per equipment sub-section
        for _, submodel in ipairs(model:GetChildren()) do
            local attachmentBase = self.Skin:FindFirstChild(ChooseAttachmentBase(submodel.Name, equipSlot))

            submodel:PivotTo(attachmentBase.CFrame)
            submodel.PrimaryPart:Destroy()

            self.Modules.WeldUtil:WeldParts(attachmentBase, unpack(submodel:GetChildren()))
            table.insert(self.EquipmentModelsParts[equipSlot], attachmentBase)
        end

        model.Name = equipSlot
        model.Parent = self.Base

        return model
    end

    return nil
end


-- Extended, attaches face
local superDraw = EntityPC.Draw
function EntityPC:Draw(dt)
	superDraw(self, dt)

	if (not self._DrawDownloading and self.Face == nil) then
        self._DrawDownloading = true

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

        self._DrawDownloading = nil
	end

    if (not self._DrawDownloading and not self.EquipmentModels) then
        self._DrawDownloading = true

        local models = {}
        local parts = {}

        self.EquipmentModels = models
        self.EquipmentModelsParts = parts

        for equipSlot, _ in pairs(self.Equipment) do
            parts[equipSlot] = {}
            models[equipSlot] = self:DrawEquipmentSlot(equipSlot)
        end

        self._DrawDownloading = nil
    end
end


-- Extended, removes the face
local superHide = EntityPC.Hide
function EntityPC:Hide()
	superHide(self)	

    -- Unnecessary to :Destroy() Face and EquipmentModels 
    --  as they're parented to Base; which, is :Destroyed()'d above
    self.Face = nil
    self._FaceParts = nil
    self.EquipmentModels = nil
    self.EquipmentModelsParts = nil
end


return EntityPC
