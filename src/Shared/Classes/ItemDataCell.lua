-- ItemDataCell, adds functionality only used by inventory cells
-- Dynamese(enduo)
-- 12.31.2021



local DataCell = require(script.Parent.DataCell)
local ItemDataCell = {}
ItemDataCell.__index = ItemDataCell
setmetatable(ItemDataCell, DataCell)


-- Creates a brand new data cell
-- @param data <table>
function ItemDataCell.new(data)
	return setmetatable(DataCell.new(ItemDataCell.Enums.DataCellType.Item, data), ItemDataCell)
end


-- Overrides default clear behavior
-- @param nosignal <boolean>
function ItemDataCell:Clear(nosignal)
	local emptyItem = self.Services.ItemService:GenerateEmptyItem()
	for key, _ in pairs(self._Data) do
		self:Set(key, nil, nosignal)
	end
	for key, val in pairs(emptyItem) do
		self:Set(key, val, nosignal)
	end
end


return ItemDataCell
