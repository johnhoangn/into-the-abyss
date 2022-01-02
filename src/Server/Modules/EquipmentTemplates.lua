local Templates = {}


function Templates.Empty()
	local eqp = {}

	for i = 1, 6 do
		eqp[i] = Templates.Services.ItemService:GenerateEmptyItem()
	end

	return eqp
end


function Templates.GenerateDefaultEquipment(template)
	return Templates[template]()
end


return Templates