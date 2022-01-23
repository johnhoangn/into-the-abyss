-- ItemService shared
-- Generates items on the fly
--
-- Dynamese (Enduo)
-- ??.??.2022



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


-- Creates a weapon
-- @param baseID <string>
-- @param values <number> damage ratings
-- @param extraData <table> dictionary of extra data
-- @returns <ItemDescriptor>
function ItemService:GenerateWeapon(baseID, values, extraData)
	local asset = AssetService:GetAsset(baseID)
	local class = asset.WeaponClass

    values = values or {}
    extraData = extraData or asset.ExtraData or {}

    if (class == self.Enums.WeaponClass.Shield) then
        -- interpreted as parameters for :GenerateArmor()
        return self:GenerateArmor(baseID, values, extraData)
    end

	assert(class ~= nil, "Not a weapon! " .. baseID)

    local attacks = asset.Attack

    local lowerMelee = values.LowerM or RandomInstance:NextInteger(attacks.Melee.Min, attacks.Melee.Max)
    local upperMelee = values.UpperM or RandomInstance:NextInteger(lowerMelee, attacks.Melee.Max)

    local lowerRanged = values.LowerR or RandomInstance:NextInteger(attacks.Ranged.Min, attacks.Ranged.Max)
    local upperRanged = values.UpperR or RandomInstance:NextInteger(lowerRanged, attacks.Ranged.Max)

    local lowerArcane = values.LowerA or RandomInstance:NextInteger(attacks.Arcane.Min, attacks.Arcane.Max)
    local upperArcane = values.UpperA or RandomInstance:NextInteger(lowerArcane, attacks.Arcane.Max)

    local itemData = {
		BaseID = baseID;
        UID = HTTPService:GenerateGUID();
		Amount = 1;
		Info = {
			Class = class;
			Rolls = {
                Melee = { lowerMelee, upperMelee };
                Ranged = { lowerRanged, upperRanged };
                Arcane = { lowerArcane, upperArcane };
            };
		}
	}

    if (extraData) then
        for key, data in pairs(self.Modules.TableUtil.Copy(extraData)) do
            itemData.Info[key] = data
        end
    end

	return itemData
end


-- Creates an armor
-- @param baseID <string>
-- @param values <number> defense ratings
-- @param extraData <table> dictionary of extra data
-- @returns <ItemDescriptor>
function ItemService:GenerateArmor(baseID, values, extraData)
	local asset = AssetService:GetAsset(baseID)
	local class = asset.ArmorClass or asset.WeaponClass -- Covers shields

    values = values or {}
    extraData = extraData or asset.ExtraData or {}

	assert(class ~= nil, "Not an armor! " .. baseID)
    local itemData = {
		BaseID = baseID;
        UID = HTTPService:GenerateGUID();
		Amount = 1;
		Info = {
			Class = class;
			Rolls = {
                Melee = values.LowerM or RandomInstance:NextInteger(
                    asset.Defense.Melee.Min, asset.Defense.Melee.Max);
                Ranged = values.LowerR or RandomInstance:NextInteger(
                    asset.Defense.Ranged.Min, asset.Defense.Ranged.Max);
                Arcane = values.LowerA or RandomInstance:NextInteger(
                    asset.Defense.Arcane.Min, asset.Defense.Arcane.Max);
            }
		}
	}

    if (extraData) then
        for key, data in pairs(self.Modules.TableUtil.Copy(extraData)) do
            itemData.Info[key] = data
        end
    end

	return itemData
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