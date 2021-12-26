local Templates = {}


function Templates.Empty(service)
	local inv = {}

	for _ = 1, 15 do
		table.insert(inv, service:GenerateEmptyItem())
	end

	return inv
end


function Templates.GenerateDefaultInventory(template, service)
	return Templates[template](service)
end


return Templates