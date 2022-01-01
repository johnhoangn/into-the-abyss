-- DataCell, holds information like an inventory item, or a skill icon, or a hotbar slot, etc.
-- Dynamese(enduo)
-- 12.24.2021



local DeepObject = require(script.Parent.DeepObject)
local DataCell = {}
DataCell.__index = DataCell
setmetatable(DataCell, DeepObject)


-- Creates a brand new data cell
-- @param cellType <Enum.DataCellType>
-- @param data <table>
function DataCell.new(cellType, data)
	local self = setmetatable(DeepObject.new({
		CellType = cellType;
		_Data = data;
	}), DataCell)

	self:AddSignal("Changed")

	return self
end


-- Sets a key under _Data to value (using IndexedMap)
-- @param key <any>
-- @param value <any>
-- @param nosignal <boolean> do not signal a change
function DataCell:Set(key, value, nosignal)
	if (self:Get(key) == value) then
		return
	end

	self._Data[key] = value

	if (value == nil) then
		value = self.Services.DataService.NIL_TOKEN
	end

	if (not nosignal) then
		self.Changed:Fire(key, value)
	end
end


-- Macro to read a data table
-- @param dataTable <table>
-- @param nosignal <boolean>
function DataCell:ReadData(dataTable, nosignal)
	self:Clear()
	for key, value in pairs(dataTable) do
		self:Set(key, value, nosignal)
	end
end


-- @returns <table> deepcopy of data
function DataCell:GetData()
	return self.Modules.TableUtil.Copy(self._Data)
end


-- Deep copies data from another cell into ours
-- @param otherDataCell <DataCell>
function DataCell:Copy(otherDataCell)
	self:Clear()
	for key, value in pairs(otherDataCell._Data) do
		if (typeof(value) == "table") then
			self:Set(key, self.Modules.TableUtil.Copy(value))
		else
			self:Set(key, value)
		end		
	end
end


-- Swap data with another cell
-- Can be done more elegantly, but not worth the debugging
-- @param otherDataCell <DataCell>
function DataCell:Swap(otherDataCell)
	local cache = {{}, {}}

	-- Backup, _Data is "private," but same class def so we know if it
	for key, val in pairs(self._Data) do
		cache[1][key] = val
	end
	for key, val in pairs(otherDataCell._Data) do
		cache[2][key] = val
	end

	-- Wipe
	self:Clear()
	otherDataCell:Clear()

	-- Swap
	for key, val in pairs(cache[1]) do
		otherDataCell:Set(key, val)
	end
	for key, val in pairs(cache[2]) do
		self:Set(key, val)
	end
end


-- Wipes the data table of this DataCell
-- @param nosignal <boolean>
function DataCell:Clear(nosignal)
	for k, _ in pairs(self._Data) do
		self:Set(k, nil, nosignal)
	end
end


-- Retrieves a value
-- @param key <any>
function DataCell:Get(key)
	return self._Data[key]
end


return DataCell
