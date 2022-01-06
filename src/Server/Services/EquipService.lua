-- EquipService server
-- Dynamese(Enduo)
-- 1.1.21
--
-- Handles modifying PLAYERS' equipped items
-- Completely unknowing of players' inventories, will simply equip whatever InventoryService
--	asks it to equip. InventoryService will do the replacement logic in a player's bag,
--	and EquipService will inform it about what can and cannot be equipped as well as various
--	details such as how many inventory slots will be required to do an action.


local EquipService = { Priority = 650; }


local EQUIPMENT_PATH = "Equipment."
local DEFAULT_EQUIPMENT_OVERRIDE = "Empty"


local DataService, AssetService, EntityService, ItemService
local Equipments
local EquipActionMap, WeaponClass, EquipSlot


-- Factory method to generate an auto updater
--	which will replicate any equipment changes to the client
-- @param user <Player>
-- @param slot <Enums.EquipSlot>
-- @returns <function>
local function UpdaterFactory(user, slot)
	return function(key, val)
		DataService:SetKey(user, EQUIPMENT_PATH .. slot, key, val)
	end
end


------------------------------------------------------------------
-- BEGIN WEAPON CLASS SPECIFIC EQUIP METHODS
------------------------------------------------------------------


-- @param user <Player>
-- @param itemData <ItemData>
-- @param modifier <boolean>
-- @returns <table<ItemData>> of any replaced items
function EquipService:EquipSingleSlotItem(user, itemData, modifier)
	local equipment = self:_GetEquipment(user)
	local asset = AssetService:GetAsset(itemData.BaseID)
	local equipSlot = asset.EquipSlot
	local replacing = {}
	local targetSlot

	-- Cover one-handed weapons
	if (equipSlot == EquipSlot.PrimaryOrSecondary) then
		equipSlot = modifier and EquipSlot.Secondary or EquipSlot.Primary
	end

	-- Target datacell
	targetSlot = equipment:Get(equipSlot)

	-- There is something in the slot we want to equip to
	if (targetSlot:Get("BaseID") ~= -1) then
		table.insert(replacing, targetSlot:GetData())
	end

	-- Equip it
	targetSlot:ReadData(itemData)

	-- Inform of the equipment change
	EntityService:NotifyEquipmentChange(user.Character, equipSlot, itemData)

	return replacing
end
function EquipService:EquipSword(user, itemData, modifier)
	return self:EquipSingleSlotItem(user, itemData, modifier)
end
function EquipService:EquipShield(user, itemData)
	return self:EquipSingleSlotItem(user, itemData, nil)
end
function EquipService:EquipArmor(user, itemData)
	return self:EquipSingleSlotItem(user, itemData, nil)
end


-- @param user <Player>
-- @param itemData <ItemData>
-- @returns <table<ItemData>> of any replaced items
function EquipService:EquipDualSlotItem(user, itemData)
	local equipment = self:_GetEquipment(user)
	local primarySlot = equipment:Get(EquipSlot.Primary)
	local secondarySlot = equipment:Get(EquipSlot.Secondary)
	local replacing = {}

	if (primarySlot:Get("BaseID") ~= -1) then
		-- Not clearing since the below :ReadData() has a builtin :Clear() call
		table.insert(replacing, primarySlot:GetData())
		-- Inform of the new primary weapon
		EntityService:NotifyEquipmentChange(
			user.Character, 
			EquipSlot.Primary, 
			itemData
		)
	end

	if (secondarySlot:Get("BaseID") ~= -1) then
		table.insert(replacing, secondarySlot:GetData())
		secondarySlot:Clear()
		-- Inform of the removal of a secondary weapon
		EntityService:NotifyEquipmentChange(
			user.Character, 
			EquipSlot.Secondary, 
			ItemService:GenerateEmptyItem()
		)
	end

	-- Equip it
	primarySlot:ReadData(itemData)

	return replacing
end
function EquipService:EquipGreatsword(user, itemData)
	return self:EquipDualSlotItem(user, itemData)
end
function EquipService:EquipBow(user, itemData)
	return self:EquipDualSlotItem(user, itemData)
end

------------------------------------------------------------------
-- END WEAPON CLASS SPECIFIC EQUIP METHODS
------------------------------------------------------------------


-- Is the user holding a two-handed weapon? e.g. Greatsword/Bow
-- @param user <Player>
-- @returns <boolean>
function EquipService:IsTwoHandedEquipped(user)
	local equipment = self:_GetEquipment(user)
	local baseID = equipment:Get(EquipSlot.Primary):Get("BaseID")
	local asset = baseID ~= -1 and AssetService:GetAsset(baseID) or nil

	if (baseID == -1) then
		return false
	end

	return asset.WeaponClass == WeaponClass.Greatsword
		or asset.WeaponClass == WeaponClass.Bow
end


-- Informs the caller of the conditions required to equip an item
-- Armor will always return 0
-- Ammo will always return 0
-- One handed weapons will always return 0
-- Two handed weapons will return 1 IFF there are two weapons equipped; otherwise 0
-- @param user <Player>
-- @param itemData <table>
-- @param modifier <boolean?> for lefthand equipping
-- @returns <number> of empty inventory slots required to equip this item
--	based on current equip status
function EquipService:EquipConditions(user, itemData, modifier)
	local equipment = self:_GetEquipment(user)
	local assetClass = tonumber(itemData.BaseID:sub(1,2), 16)
	local asset = AssetService:GetAsset(itemData.BaseID)
	local equipSlot = asset.EquipSlot
	local emptySlotsRequired = 0

	-- Single slot weapons and armor ALWAYS return 0, we only need to consider
	--	two-handed weapon related actions
	if (assetClass == self.Enums.AssetClass.Weapon) then
		local subclass = asset.WeaponClass

		-- Either-hand weapons' destinations decided by modifier
		if (equipSlot == EquipSlot.PrimaryOrSecondary) then
			equipSlot = modifier 
				and EquipSlot.Secondary
				or EquipSlot.Primary
		end

		-- Dual slot types
		if (subclass == WeaponClass.Greatsword
			or subclass == WeaponClass.Bow) then

			-- Up to 1 required slot
			if (not self:IsTwoHandedEquipped(user)) then
				emptySlotsRequired += equipment:Get(EquipSlot.Primary):Get("BaseID") ~= -1 and 1 or 0
				emptySlotsRequired += equipment:Get(EquipSlot.Secondary):Get("BaseID") ~= -1 and 1 or 0
				emptySlotsRequired = math.min(1, emptySlotsRequired)
			end
		end
	end

	return emptySlotsRequired
end


-- Wields an item
-- @param user <Player>
-- @param itemData <table>
-- @param modifier <boolean> for lefthand equipping
-- @returns <table<ItemData>> of any replaced items
function EquipService:Equip(user, itemData, modifier)
	local assetClass = tonumber(itemData.BaseID:sub(1,2), 16)

	if (assetClass == self.Enums.AssetClass.Weapon) then
		local asset = AssetService:GetAsset(itemData.BaseID)
		local subclassHex = self.Modules.Hexadecimal.new(asset.WeaponClass, 2)
		return self["Equip" .. EquipActionMap[subclassHex]](self, user, itemData, modifier)

	elseif (assetClass == self.Enums.AssetClass.Armor) then
		return self:EquipArmor(user, itemData, modifier)
	end	
end


-- Removes an item from equipment
-- @param user <Player>
-- @param slot <Enums.EquipSlot>
-- @returns <ItemData> unequipped item
function EquipService:Unequip(user, slot)
	local equipment = self:_GetEquipment(user)
	local itemData = equipment:Get(slot):GetData()

	equipment:Get(slot):Clear()
	return itemData
end


-- Checks if any of the equipped items match a descriptor
-- @param user <Player>
-- @param itemDescriptor <ItemDescriptor>
-- @returns <boolean>
function EquipService:HasEquipped(user, itemDescriptor) self:Debug(user)
	local equipment = self:_GetEquipment(user)

	for _equipSlot, dataCell in equipment:KeyIterator() do
		local info = dataCell:Get("Info")

		if (dataCell:Get("BaseID") == itemDescriptor.BaseID) then
			if (info.UID == itemDescriptor.Info.UID) then
				return true
			end
		end
	end

	return false
end


-- Informs the client whenever something changes in their equipment
-- @param user <Player>
-- @param equipment <table>
function EquipService:BindAutoReplicators(user, equipment)
	-- IndexedMap does not extend DeepObject, manually add a maid
	equipment.Maid = self.Classes.Maid.new()

	for slot, dataCell in equipment:KeyIterator() do
		equipment.Maid:GiveTask(dataCell.Changed:Connect(UpdaterFactory(user, slot)))
	end
end


-- Reads the user's equipment data table and decodes it into a structure
-- @param user <Player>
function EquipService:Load(user)
	local data = DataService:WaitData(user, 60)
	local equipment = self.Classes.IndexedMap.new()

	if (not data) then
		self:Warn("User left before data load?", user)
		return
	end

	if (#data.Equipment == 0 or DEFAULT_EQUIPMENT_OVERRIDE ~= nil) then
		DataService:SetKey(
			user, 
			"", 
			"Equipment", 
			self.Modules.EquipmentTemplates.GenerateDefaultEquipment(
				DEFAULT_EQUIPMENT_OVERRIDE or "Empty"
			)
		)
	end

	for slot, datum in ipairs(data.Equipment) do
		local dataCell = self.Classes.ItemDataCell.new(datum)
		equipment:Add(slot, dataCell)
	end

	self:BindAutoReplicators(user, equipment)
	Equipments:Add(user, equipment)
	self.EquipmentLoaded:Fire(user)
end


-- Removes record of a user's equipment when they leave
-- @param user <Player>
function EquipService:Unload(user)
	local equipment = Equipments:Get(user)
	equipment.Maid:Destroy()
	Equipments:Remove(user)
end


-- Yielding code to get a user's equipment
-- @param user <Player>
-- @param timeout <number> == 60
function EquipService:_GetEquipment(user, timeout)
	local equipment = Equipments:Get(user)

	if (not equipment) then
		self:WaitForEquipment(user, timeout)
		equipment = Equipments:Get(user)
	end

	return equipment
end


function EquipService:Debug(user)
	local dbg = {}
	for _, dataCell in Equipments:Get(user):KeyIterator() do
		table.insert(dbg, dataCell._Data)
	end
	self:Print("OOP:", Equipments:Get(user), "RAW:", dbg)
end


function EquipService:WaitForEquipment(user, timeout)
	if (Equipments:Get(user) == nil) then
		local loaded = self.Classes.Signal.new()

		timeout = timeout or 60

		self.Modules.ThreadUtil.Delay(timeout, function()
			if (not Equipments:Get(user)) then
				loaded:Fire()
				self:Warn("Never retrieved equipment for", user, "within timeout of", timeout)
			end
		end)

		local conn = self.EquipmentLoaded:Connect(function(_user)
			if (_user == user) then 
				loaded:Fire()
			end
		end)

		loaded:Wait()
		conn:Disconnect()
	end
end


function EquipService:EngineInit()
	local Players = self.RBXServices.Players

	DataService = self.Services.DataService
	AssetService = self.Services.AssetService
	EntityService = self.Services.EntityService
	ItemService = self.Services.ItemService

	WeaponClass = self.Enums.WeaponClass
	EquipSlot = self.Enums.EquipSlot

	Equipments = self.Classes.IndexedMap.new()
	self.EquipmentLoaded = self.Classes.Signal.new()

	EquipActionMap = {}
	for key, val in pairs(WeaponClass) do
		EquipActionMap[self.Modules.Hexadecimal.new(val, 2)] = key
	end

	-- Initialize EntityPCs as they are created; since, they have no equipment on instantiation
	EntityService.EntityCreated:Connect(function(base)
		local user = Players:GetPlayerFromCharacter(base)

		if (user ~= nil) then
			local equipment = self:_GetEquipment(user)		
			for slot, dataCell in equipment:KeyIterator() do
				EntityService:NotifyEquipmentChange(user.Character, slot, dataCell:GetData())
			end
		end
	end)
end


function EquipService:EngineStart()
	local PlayerService = self.Services.PlayerService
	PlayerService:AddJoinTask(function(user)
		self:Load(user)
	end, "EquipmentLoader")
	PlayerService:AddLeaveTask(function(user)
		self:Unload(user)
	end, "EquipmentUnloader")
end


return EquipService