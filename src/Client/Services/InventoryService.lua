-- Inventory service client
-- All inventory action requests will be done via this service, 
--	direct access to an inventory should never be given
-- Since DataService will be replicating changes to the raw data, this service exists
--	to read from and notify of updates pertaining to the inventory contents
--	and request mutations to be done on our inventory by the server
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



local InventoryService = { Priority = 150 }


local DataService, Network, AssetService
local InventoryAction
local Inventory, NetworkMutex



-- @param itemDescriptor <table> { BaseID <string>; Info <table>: { UID <string?>; ...; } }
-- @returns <number>, <table> how many and the indices where the matched DataCells are located
function InventoryService:Has(itemDescriptor)
	local indices = {}
	local amount = 0

	for i, cell in Inventory:KeyIterator() do
		if (cell:Get("BaseID") == itemDescriptor.BaseID
			and cell:Get("UID") == itemDescriptor.UID) then -- nil == nil -> true

			amount += cell:Get("Amount") or 1
			table.insert(indices, i)
		end
	end

	return amount, indices
end


-- Finds empty cells in the player's inventory
-- @param desired <number> == nil, if we have at minimum this many we can stop the search here
-- @returns <table> array of indices corresponding to empty DataCells
function InventoryService:Empties(desired)
	local empties = {}

	for i, cell in Inventory:KeyIterator() do
		if (desired ~= nil and #empties >= desired) then break end
		if (cell:Get("BaseID") == -1) then
			table.insert(empties, i)
		end
	end

	return empties
end


-- Attempts to find matching non-full cells containing a stackable item of the same BaseID
-- NOTE: None of these will ever have UID fields as those, obviously, cannot stack.
-- @param itemDescriptor <table> { BaseID <string>; Info <table?>: { Crafter <userID?>; Enhance <number?> } }
-- @returns number, <table> how much more we can carry, array of non-full duplicate BaseID cells
function InventoryService:Duplicates(itemDescriptor)
	local asset = AssetService:GetAsset(itemDescriptor.BaseID)
	local stackSize = asset.StackSize or 1
	local _, indices = self:Has(itemDescriptor)
	local spaceFor, dupes = 0, {}

	for _, index in ipairs(indices) do
		local cell = Inventory:Get(index)
		local cellHas = cell:Get("Amount")
		local info = cell:Get("Info")

		if (info.Crafter == itemDescriptor.Crafter
			and info.Enhance == itemDescriptor.Enhance
			and cellHas < stackSize) then

			spaceFor += (stackSize - cellHas)
			table.insert(dupes, index)
		end
	end

	return dupes, spaceFor
end


-- Lock the inventory from any other actions and request 
--	an inventory action from the server
-- @param action <Enums.InventoryAction>
-- @param ... action specific args
-- @returns <tuple<any>>
function InventoryService:NetworkRequest(action, ...)
	if (not NetworkMutex:TryLock()) then 
		return 
	end

	self.NetworkState = true
	self.NetworkStateChanged:Fire(true)

	local retVal = {
		Network:RequestServer(
			Network.NetRequestType.InventoryAction, 
			action,
			...
		):Wait()
	}

	self.NetworkState = false
	self.NetworkStateChanged:Fire(false)

	NetworkMutex:Unlock()

	return unpack(retVal)
end


-- Trades the contents of one datacell with another
-- @param indexA <number>
-- @param indexB <number>
-- @returns <nil> for now?
function InventoryService:Swap(indexA, indexB)
	return self:NetworkRequest(InventoryAction.Swap, indexA, indexB)
end


-- Divides a stack into two, with "amount" of the item
--	going into a new stack
-- !! ONLY APPLICABLE TO STACKABLE ITEM TYPES !!
-- @param indexA <number>
-- @param indexB <number>
-- @param amount <number>
-- @returns <nil> for now?
function InventoryService:Split(indexA, indexB, amount)
	return self:NetworkRequest(InventoryAction.Split, indexA, indexB, amount)
end


-- Drops an item
-- @param index <number>
-- @param amount <number>
-- @returns <number> dropped
function InventoryService:Drop(index, amount)
	return self:NetworkRequest(InventoryAction.Drop, index, amount)
end


-- Grabs a copy of the cell data
-- @param index <number>
-- @returns <ItemDescriptor>
function InventoryService:GetCellData(index)
	return self.Modules.TableUtil.Copy(Inventory:Get(index)._Data)
end


function InventoryService:Debug()
	local dbg = {}
	for _, dataCell in Inventory:KeyIterator() do
		table.insert(dbg, dataCell._Data)
	end
	self:Print("OOP:", Inventory, "RAW:", dbg)
end


function InventoryService:EngineInit()
	Network = self.Services.Network
	DataService = self.Services.DataService
	AssetService = self.Services.AssetService

	InventoryAction = self.Enums.InventoryAction

	-- Purely to notify subscribers of changes, 
	--	does not propogate data changes like the server-side
	self.InventoryChanged = self.Classes.Signal.new()
	
	NetworkMutex = self.Classes.Mutex.new()
	self.NetworkStateChanged = self.Classes.Signal.new()
	self.NetworkState = false -- F: none, T: in process
end


function InventoryService:EngineStart()
	Inventory = self.Classes.IndexedMap.new()
	for cellIndex, cellData in ipairs(DataService:GetCache().Inventory) do
		Inventory:Add(cellIndex, self.Classes.ItemDataCell.new(cellData))
	end
	DataService.DataChanged:Connect(function(routeString, key, val)
		local cellIndex = routeString:reverse():sub(1, routeString:find("."))
		self.InventoryChanged:Fire(cellIndex, key, val)
	end)
end


return InventoryService