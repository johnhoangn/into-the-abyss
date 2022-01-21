-- Inventory service server
-- All inventory actions will be done via this service, direct access to an inventory should never be given
-- Dynamese(enduo)
-- 12.24.2021
--
-- !! ItemDescriptors shall be treated as IMMUTABLE !!

--[[

InventoryCell = {
	BaseID? <string>; / nil -> empty cell and Info = nil
	Info? = {
		Class = <string>;
		Amount <number>;
		UID? <string>;
		... 
		Other fields depending on item class
	}
}

]]



local InventoryService = { Priority = 600 }


local INVENTORY_PATH = "Inventory."
local DEFAULT_INVENTORY_OVERRIDE = "Empty" -- Set this to a default inventory module config if desired


local DataService, AssetService, Network, EquipService, EntityService, DropService
local Inventories
local ActionMap



-- Factory method to generate an auto updater
--	which will replicate any inventory changes to the client
-- @param user <Player>
-- @param cellIndex <number>
-- @returns <function>
local function UpdaterFactory(user, cellIndex)
	return function(key, val)
		DataService:SetKey(user, INVENTORY_PATH .. cellIndex, key, val)
	end
end


-- Responds to user requested inventory actions
-- @param user <Player>
-- @param dt <number>
-- @param action <Enums.InventoryAction>
-- @param ... action specific arguments
local function InventoryActionRequestHandler(user, _dt, action, ...)
	if (not ActionMap[action]) then
		InventoryService:Warn("Invalid Inventory Action!", user, action)
		return
	end

	return InventoryService[ActionMap[action]](InventoryService, user, ...)
end


------------------------------------------------------------------
-- BEGIN INVENTORY ACTION DEFINITIONS
------------------------------------------------------------------


-- Trades the contents of one datacell with another
-- @param user <Player>
-- @param indexA <number>
-- @param indexB <number>
function InventoryService:Swap(user, indexA, indexB)
	local inv = self:_GetInventory(user, 5)
	inv:Get(indexA):Swap(inv:Get(indexB))
end


-- Divides a stack into two, with "amount" of the item
--	going into a new stack
-- !! ONLY APPLICABLE TO STACKABLE ITEM TYPES !!
-- @param user <Player>
-- @param indexA <number>
-- @param indexB <number>
-- @param amount <number>
function InventoryService:Split(user, indexA, indexB, amount)
	local inv = self:_GetInventory(user, 5)
	local cellA = inv:Get(indexA)
	local cellB = inv:Get(indexB)

	cellB:Copy(cellA)
	cellB:Set("Amount", amount)
	cellA:Set("Amount", cellA:Get("Amount") - amount)
end


-- Drops an item out of the player's inventory
-- @param user <Player>
-- @param index <number>
-- @param amount <number>
-- @returns <number> dropped
function InventoryService:Drop(user, index, amount)
	local inv = self:_GetInventory(user, 5)
	local itemDescriptor = inv:Get(index):GetData()
    local entity = EntityService:GetEntity(user.Character)
	local dropped = 0

    if (entity) then
        itemDescriptor.Amount = amount or 1
        dropped = self:Take(user, itemDescriptor, false, false)
        DropService:Drop(
            DropService:MakeDrop(itemDescriptor),
            entity:GetPosition(),
            nil, nil, nil
        )
    end

	return dropped
end


-- Equips an item from the user's inventory
-- @param user <Player>
-- @param index <number>
-- @param modifier <boolean>
-- @returns <boolean> success
function InventoryService:Equip(user, index, modifier)
	if (not user.Character or not EntityService:GetEntity(user.Character)) then
		return false
	end

	local inv = self:_GetInventory(user, 5)
	local itemDescriptor = inv:Get(index):GetData()
	local necessaryEmpties = EquipService:EquipConditions(user, itemDescriptor, modifier)

	if (#self:Empties(user, necessaryEmpties) < necessaryEmpties) then
		return false
	end

	-- Item is now in equipment
	inv:Get(index):Clear()

	-- Return previously worn items to inventory
	for _, itemData in ipairs(EquipService:Equip(user, itemDescriptor, modifier)) do
		self:Give(user, itemData, true)
	end

	return true
end


-- Unequips an item from the user's equipment
-- @param user <Player>
-- @param slot <Enums.EquipSlot>
-- @returns <boolean> success
function InventoryService:Unequip(user, slot)
	if (not user.Character or not EntityService:GetEntity(user.Character)) then
		return false
	end

	if (#self:Empties(user, 1) == 0) then
		return false
	end

	self:Give(user, EquipService:Unequip(user, slot))

	return true
end


------------------------------------------------------------------
-- END INVENTORY ACTION DEFINITIONS
------------------------------------------------------------------


-- @param user <Player>
-- @param itemDescriptor <table> { BaseID <string>; Info <table>: { UID <string?>; ...; } }
-- @returns <number>, <table> how many and the indices where the matched DataCells are located
function InventoryService:Has(user, itemDescriptor)
	local indices = {}
	local amount = 0

	for i, cell in Inventories:Get(user):KeyIterator() do
		if (cell:Get("BaseID") == itemDescriptor.BaseID
			and cell:Get("UID") == itemDescriptor.UID) then -- nil == nil -> true

			amount += cell:Get("Amount") or 1
			table.insert(indices, i)
		end
	end

	return amount, indices
end


-- Attempts to give the player an item or items
-- @param user <Player>
-- @param itemDescriptor <table> { BaseID <string>; Amount <number?>; Info <table>: { UID <string?>; ...; } }
-- @param mustGiveAll <boolean> == false, all or nothing
-- @returns <number> given
function InventoryService:Give(user, itemDescriptor, mustGiveAll)
	local inv = self:_GetInventory(user, 5)
	local slots, space = self:Duplicates(user, itemDescriptor)
	local asset = AssetService:GetAsset(itemDescriptor.BaseID)
	local stackSize = asset.StackSize or 1
	local toGive, given = itemDescriptor.Amount, 0

	if (mustGiveAll or space < toGive) then
		local empties = self:Empties(user)
		space += #empties * stackSize

		if (space < toGive) then
			return given
		end

		for _, index in ipairs(empties) do
			table.insert(slots, index)
		end

		table.sort(slots)
	end	

	for _, cellIndex in ipairs(slots) do
		local cell = inv:Get(cellIndex)
		local cellHas = cell:Get("Amount") or 0
		local spaceFor = stackSize - cellHas

		cell:ReadData(itemDescriptor)

		if (spaceFor < toGive) then
			toGive -= spaceFor
			given += spaceFor
			cell:Set("Amount", stackSize)
		else
			given += toGive
			cell:Set("Amount", cellHas + toGive)
			toGive = 0 -- Not an effective op; left it in for readability
			break
		end
	end

	return given
end


-- Attempts to remove items from a player's inventory.
-- Unlike prior implementations, we do not explicitly check for UID matches in this method
--	as that will be handled in InventoryService:Has(), as in, the ItemDescriptor will be checked
--	for a UID and that will be run against each DataCell scanned by :Has()
-- @param user <Player>
-- @param itemDescriptor <table> { BaseID <string>; Amount <number?>; Info <table>: { UID <string?>; ...; } }
-- @param mustHaveAll <boolean>, only take if we have at least enough
-- @param reverse <boolean> == false, remove from bottom right when true
-- @returns <number> taken
function InventoryService:Take(user, itemDescriptor, mustHaveAll, reverse)
	local inv = self:_GetInventory(user, 5)
	local have, indices = self:Has(user, itemDescriptor)
	local toRemove, removed = itemDescriptor.Amount, 0

	if (reverse) then
		self.Modules.TableUtil.Reverse(indices)
	end

	if (not mustHaveAll or have >= toRemove) then
		toRemove = math.min(have, toRemove)

		for _, cellIndex in ipairs(indices) do
			local cell = inv:Get(cellIndex)
			local cellHas = cell:Get("Amount")
			print(cell)
			if (cellHas <= toRemove) then
				cell:Clear()
				removed += cellHas
				toRemove -= cellHas				
			else
				cell:Set("Amount", cellHas - toRemove)
				removed += toRemove
				toRemove = 0
				break
			end
		end
	end

	return removed
end


-- Finds empty cells in the player's inventory
-- @param user <Player>
-- @param desired <number> == nil, if we have at minimum this many we can stop the search here
-- @returns <table> array of indices corresponding to empty DataCells
function InventoryService:Empties(user, desired)
	local inv = self:_GetInventory(user, 5)
	local empties = {}

	for i, cell in inv:KeyIterator() do
		if (desired ~= nil and #empties >= desired) then break end
		if (cell:Get("BaseID") == -1) then
			table.insert(empties, i)
		end
	end

	return empties
end


-- Attempts to find matching non-full cells containing a stackable item of the same BaseID
-- NOTE: None of these will ever have UID fields as those, obviously, cannot stack.
-- @param user <Player>
-- @param itemDescriptor <table> { BaseID <string>; Info <table?>: { Crafter <userID?>; Enhance <number?> } }
-- @returns number, <table> how much more we can carry, array of non-full duplicate BaseID cells
function InventoryService:Duplicates(user, itemDescriptor)
	local inv = self:_GetInventory(user, 5)
	local asset = AssetService:GetAsset(itemDescriptor.BaseID)
	local stackSize = asset.StackSize or 1
	local _, indices = self:Has(user, itemDescriptor)
	local spaceFor, dupes = 0, {}

	for _, index in ipairs(indices) do
		local cell = inv:Get(index)
		local cellHas = cell:Get("Amount")
		local info = cell:Get("Info")

		if (info.Crafter == itemDescriptor.Crafter
			and info.Enhance == itemDescriptor.Info.Enhance
			and cellHas < stackSize) then

			spaceFor += (stackSize - cellHas)
			table.insert(dupes, index)
		end
	end

	return dupes, spaceFor
end


-- Informs the client whenever something changes in their inventory
-- @param user <Player>
-- @param inv <table>
function InventoryService:BindAutoReplicators(user, inv)
	-- IndexedMap does not extend DeepObject, manually add a maid
	inv.Maid = self.Classes.Maid.new()

	for cellIndex, dataCell in inv:KeyIterator() do
		inv.Maid:GiveTask(dataCell.Changed:Connect(UpdaterFactory(user, cellIndex)))
	end
end


-- Reads the user's inventory data table and decodes it into a structure
-- @param user <Player>
function InventoryService:Load(user) 
	local data = DataService:WaitData(user, 60)
	local inv = self.Classes.IndexedMap.new()

	if (not data) then
		self:Warn("User left before data load?", user)
		return
	end

	if (#data.Inventory == 0 or DEFAULT_INVENTORY_OVERRIDE ~= nil) then
		DataService:SetKey(
			user, 
			"", 
			"Inventory", 
			self.Modules.InventoryTemplates.GenerateDefaultInventory(
				DEFAULT_INVENTORY_OVERRIDE or "Empty"
			)
		)
	end

	for cellIndex, datum in ipairs(data.Inventory) do
		local dataCell = self.Classes.ItemDataCell.new(datum)
		inv:Add(cellIndex, dataCell)
	end

	self:BindAutoReplicators(user, inv)
	Inventories:Add(user, inv) 
	self.InventoryLoaded:Fire(user)
end


-- Removes record of a user's inventory when they leave
-- @param user <Player>
function InventoryService:Unload(user)
	local inv = Inventories:Get(user)
	inv.Maid:Destroy()
	Inventories:Remove(user)
end


-- Yielding code to get a user's inventory
-- @param user <Player>
-- @param timeout <number> == 60
function InventoryService:_GetInventory(user, timeout)
	local inv = Inventories:Get(user)

	if (not inv) then
		self:WaitForInventory(user, timeout)
		inv = Inventories:Get(user)
	end

	return inv
end


function InventoryService:Debug(user)
	local dbg = {}
	for _, dataCell in Inventories:Get(user):KeyIterator() do
		table.insert(dbg, dataCell._Data)
	end
	self:Print("OOP:", Inventories:Get(user), "RAW:", dbg)
end


function InventoryService:WaitForInventory(user, timeout)
	if (Inventories:Get(user) == nil) then
		local loaded = self.Classes.Signal.new()

		timeout = timeout or 60

		self.Modules.ThreadUtil.Delay(timeout, function()
			if (not Inventories:Get(user)) then
				loaded:Fire()
				self:Warn("Never retrieved inventory for", user, "within timeout of", timeout)
			end
		end)

		local conn = self.InventoryLoaded:Connect(function(_user)
			if (_user == user) then 
				loaded:Fire()
			end
		end)

		loaded:Wait()
		conn:Disconnect()
	end
end


function InventoryService:EngineInit()
	DataService = self.Services.DataService
	AssetService = self.Services.AssetService
	Network = self.Services.Network
	EquipService = self.Services.EquipService
	EntityService = self.Services.EntityService
	DropService = self.Services.DropService

	Inventories = self.Classes.IndexedMap.new()
	self.InventoryLoaded = self.Classes.Signal.new()

	ActionMap = {}
	for e, v in pairs(self.Enums.InventoryAction) do
		ActionMap[v] = e
	end
end


function InventoryService:EngineStart()
	local PlayerService = self.Services.PlayerService
	PlayerService:AddJoinTask(function(user) 
		self:Load(user)
	end, "InventoryLoader")
	PlayerService:AddLeaveTask(function(user)
		self:Unload(user)
	end, "InventoryUnloader")
	Network:HandleRequestType(Network.NetRequestType.InventoryAction, InventoryActionRequestHandler)
end


return InventoryService