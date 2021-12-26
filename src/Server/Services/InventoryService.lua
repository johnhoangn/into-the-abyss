-- Inventory service server
-- All inventory actions will be done via this service, direct access to an inventory should never be given
-- Dynamese(enduo)
-- 12.24.2021

--[[

InventoryCell = {
	BaseID? <string>; / nil -> empty cell and ItemInfo = nil
	ItemInfo? = {
		Class = <string>;
		Amount <number>;
		UID? <string>;
		... 
		Other fields depending on item class
	}
}

]]



local InventoryService = { Priority = 250 }

local UNINITIALIZED_INVENTORY = "UNINITIALIZED"
local DEFAULT_INVENTORY_OVERRIDE = "Empty" -- Set this to a default inventory module config if desired

local ItemService, PlayerService, DataService, SlotService
local DataCellType
local Inventories


-- @param user <Player>
-- @param itemDescriptor <table> { BaseID <string>; Amount <number?>; ItemInfo <table>: { UID <string?>; ...; } }
function InventoryService:Has(user, itemDescriptor)
end


-- @param user <Player>
-- @param itemDescriptor <table> { BaseID <string>; Amount <number?>; ItemInfo <table>: { UID <string?>; ...; } }
function InventoryService:Give(user, itemDescriptor)
end


-- @param user <Player>
-- @param itemDescriptor <table> { BaseID <string>; Amount <number?>; ItemInfo <table>: { UID <string?>; ...; } }
function InventoryService:Take(user, itemDescriptor)
end


-- Creates an empty inventory element
function InventoryService:GenerateEmptyItem()
	return {
		
	}
end


-- Reads the user's inventory data table and decodes it into a structure
function InventoryService:Load(user)
	local data = DataService:WaitData(user, 60)
	local inv = self.Classes.IndexedMap.new()

	if (not data) then
		return
	end

	if (data.Inventory == UNINITIALIZED_INVENTORY or DEFAULT_INVENTORY_OVERRIDE ~= nil) then
		DataService:SetKey(
			user, 
			"", 
			"Inventory", 
			self.Modules.InventoryTemplates.GenerateDefaultInventory(
				DEFAULT_INVENTORY_OVERRIDE or "Empty"
			)
		)
	end

	for slotIndex, datum in ipairs(data.Inventory) do
		inv:Add(slotIndex, self.Classes.DataCell.new(
			DataCellType.Item, 
			datum
		))
	end

	Inventories:Add(user, inv)
	self.InventoryLoaded:Fire(user)
end


-- Removes record of a user's inventory when they leave
-- @param user <Player>
function InventoryService:Unload(user)
	local inv = Inventories:Get(user)
	inv:Destroy()
	Inventories:Remove(user)
end


function InventoryService:EngineInit()
	-- ItemService = self.Services.ItemService -- Creation of items
	PlayerService = self.Services.PlayerService
	DataService = self.Services.DataService
	-- SlotService = self.Services.SlotService -- Drag and drop functionality

	DataCellType = self.Enums.DataCellType

	Inventories = self.Classes.IndexedMap.new()
	self.InventoryLoaded = self.Classes.Signal.new()
end


function InventoryService:EngineStart()
	PlayerService:AddJoinTask(function(user)
		self:Load(user)
	end, "InventoryLoader")
end


return InventoryService