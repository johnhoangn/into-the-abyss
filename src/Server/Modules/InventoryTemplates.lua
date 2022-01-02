local Templates = {}


function Templates.Empty()
	local inv = {}

	for _ = 1, 15 do
		table.insert(inv, Templates.Services.ItemService:GenerateEmptyItem())
	end

	return inv
end


function Templates.GenerateDefaultInventory(template)
	return Templates[template]()
end


return Templates