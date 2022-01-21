local ItemService = { Priority = 700; CPriority = 200 }


-- Ordering here does NOT matter
local ITEM_CLASSES = {"Junk", "Ware", "Weapon", "Armor", "Consumable"}


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


-- Creates an equipment
-- @param baseID <string>
-- @param lower <number> rng
-- @param upper <number> rng
function ItemService:GenerateEquipment(baseID, lower, upper)
	local asset = AssetService:GetAsset(baseID)
	local class = asset.WeaponClass or asset.ArmorClass
	local lowRoll = lower or RandomInstance:NextInteger(asset.RollMin, asset.RollMax)
	local highRoll = upper or RandomInstance:NextInteger(lowRoll, asset.RollMax)

	assert(class ~= nil, "Not an equipment! " .. baseID)
	return {
		BaseID = baseID;
        UID = HTTPService:GenerateGUID();
		Amount = 1;
		Info = {
			Class = class;
			Roll = {lowRoll, highRoll};
		}
	}
end


-- Creates a weapon
-- @param baseID <string>
-- @param lower <number> rng
-- @param upper <number> rng
function ItemService:GenerateWeapon(baseID, lower, upper)
	return ItemService:GenerateEquipment(baseID, lower, upper)
end


-- Creates an armor
-- @param baseID <string>
-- @param lower <number> rng
-- @param upper <number> rng
function ItemService:GenerateArmor(baseID, lower, upper)
	return ItemService:GenerateEquipment(baseID, lower, upper)
end


-- Creates a consumable
-- @param baseID <string>
-- @param amount <number>
-- @param crafter <userid>
-- @returns <itemDescriptor>
function ItemService:GenerateConsumable(baseID, amount, crafter, crafterBonus)
	local subclass = AssetService:GetAsset(baseID).ConsumableClass
	assert(subclass ~= nil, "Not a consumable! " .. baseID)
	return {
		BaseID = baseID;
		Amount = amount or 1;
		Info = {
			Crafter = crafter or nil;
			Enhance = crafterBonus or 0;
			Class = subclass;
		}
	}
end


-- Convenience method that figures out the item class by itself
-- @param assetClass <Enums.AssetClass> 
-- @param assetID <string>
-- @param ... item class / subclass specific args
-- @returns <itemDescriptor>
function ItemService:GenerateItem(assetClass, assetID, ...)
	local classID = self.Modules.Hexadecimal.new(assetClass, 2)
	return self["Generate" .. AssetClassMap[classID]](self, classID .. assetID, ...)
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