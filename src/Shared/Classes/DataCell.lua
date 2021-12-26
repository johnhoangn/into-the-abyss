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
-- @param nosignal <boolean>
function DataCell:Set(key, value, nosignal)
	self._Data[key] = value
	if (not nosignal) then
		self.Changed:Fire(key, value)
	end
end


-- Retrieves a value
-- @param key <any>
function DataCell:Get(key)
	return self._Data[key]
end


return DataCell
