-- InventoryDataCell, adds functionality only used by inventory cells
-- Dynamese(enduo)
-- 12.31.2021



local DataCell = require(script.Parent.DataCell)
local InventoryDataCell = {}
InventoryDataCell.__index = InventoryDataCell
setmetatable(InventoryDataCell, DataCell)


-- Creates a brand new data cell
-- @param cellType <Enum.InventoryDataCellType>
-- @param data <table>
function InventoryDataCell.new(cellType, data)
	return setmetatable(DataCell.new(cellType, data), InventoryDataCell)
end


-- Overrides default clear behavior
-- @param nosignal <boolean>
function InventoryDataCell:Clear(nosignal)
	local emptyItem = self.Services.ItemService:GenerateEmptyItem()
	for key, _ in pairs(self._Data) do
		self:Set(key, nil, nosignal)
	end
	for key, val in pairs(emptyItem) do
		self:Set(key, val, nosignal)
	end
end


return InventoryDataCell
