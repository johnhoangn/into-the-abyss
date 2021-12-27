local ItemService = {Priority = 480}

local HTTPService


-- Creates an empty inventory element
function ItemService:GenerateEmptyItem()
	return {
		
	}
end


-- Creates a weapon
function ItemService:GenerateWeapon(baseID, weaponClass)
	return {
		BaseID = baseID;
		ItemInfo = {
			UID = HTTPService:GenerateGUID();
			Class = weaponClass;
			Amount = 1;
		}
	}
end


function ItemService:EngineInit()
	HTTPService = self.RBXServices.HttpService
end


function ItemService:EngineStart()
	
end


return ItemService