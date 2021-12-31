local ItemService = {Priority = 100}


local ITEM_CLASSES = {"Junk", "Ware", "Weapon", "Consumable"}


local HTTPService, AssetService
local RandomInstance
local AssetClassMap


-- Generates the classmap at runtime as to avoid hard coding classIDs
local function LoadAssetClassMap()
	local assetClass = ItemService.Enums.AssetClass
	local hex = ItemService.Modules.Hexadecimal

	AssetClassMap = {}
	for _, className in ipairs(ITEM_CLASSES) do
		AssetClassMap[hex.new(assetClass[className], 2)] = className
	end
end


-- Creates an empty inventory element
function ItemService:GenerateEmptyItem()
	return {
		BaseID = -1;
	}
end


-- Creates a weapon
-- @param baseID <string>
-- @param lower <number> rng
-- @param upper <number> rng
function ItemService:GenerateWeapon(baseID, lower, upper)
	local asset = AssetService:GetAsset(baseID)
	local weaponClass = asset.WeaponClass
	assert(weaponClass ~= nil, "Not a weapon! " .. baseID)
	return {
		BaseID = baseID;
		Amount = 1;
		Info = {
			UID = HTTPService:GenerateGUID();
			Class = weaponClass;
			Roll = {
				lower or RandomInstance:NextInteger(asset.Roll.Min);
				upper or RandomInstance:NextInteger(asset.Roll.Min);
			};
		}
	}
end


-- Creates a consumable
-- @param baseID <string>
-- @param amount <number>
-- @param crafter <userid>
-- @returns <itemDescriptor>
function ItemService:GenerateConsumable(baseID, amount, crafter, crafterBonus)
	local subClass = AssetService:GetAsset(baseID).ConsumableClass
	assert(subClass ~= nil, "Not a consumable! " .. baseID)
	return {
		BaseID = baseID;
		Amount = amount or 1;
		Info = {
			Crafter = crafter or nil;
			Enhance = crafterBonus or 0;
			Class = subClass;
		}
	}
end


-- Convenience method that figures out the item class by itself
-- @param baseID <string>
-- @param amount <number>
-- @param ... item class / subclass specific args
-- @returns <itemDescriptor>
function ItemService:GenerateItem(baseID, amount, ...)
	return self["Generate" .. AssetClassMap[baseID:sub(1,2)]](self, baseID, amount, ...)
end


function ItemService:EngineInit()
	HTTPService = self.RBXServices.HttpService
	AssetService = self.Services.AssetService
	RandomInstance = Random.new()

	LoadAssetClassMap()
end


function ItemService:EngineStart()
end


return ItemService