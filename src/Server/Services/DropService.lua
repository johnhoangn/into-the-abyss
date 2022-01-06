-- DropService server, drops items on the ground and handles lootable/looting
-- Dynamese(enduo)
-- 1.5.2021



local DropService = {}

local DEFAULT_LOOT_DECAY_TIME = 120
local OWNER_UNLOCK_TIME = 60
local MAX_LOOT_DISTANCE = 10
local RANDOM_SPEED_MIN = 25
local RANDOM_SPEED_MAX = 40
local RANDOM_ANGLE_MIN = 45
local RANDOM_ANGLE_MAX = 70
local TAU = math.pi*2
local COS = math.cos
local SIN = math.sin
local MIN_WAIT = 1/30

local Network, AssetService, ItemService, InventoryService, EntityService
local HttpService
local DropRandom, ItemsOnGround


local function GenerateRandomSpeed()
    return DropRandom:NextNumber(RANDOM_SPEED_MIN, RANDOM_SPEED_MAX)
end


local function GenerateRandomDirection()
    local theta1 = DropRandom:NextNumber() * TAU
    local theta2 = DropRandom:NextNumber(RANDOM_ANGLE_MIN, RANDOM_ANGLE_MAX) * TAU
    return Vector3.new(
        COS(theta1),
        SIN(theta2),
        SIN(theta1)
    )
end


-- TODO
function DropService:CalculateEndPosition(origin, speed, direction)
    local velocity = direction * speed
    local nextFramePosition = origin + velocity * MIN_WAIT

    while (false) do
    end

    return origin
end


function DropService:MakeDrop(itemData, origin, speed, direction)
    return self.Classes.Lootable.new(
        HttpService:GenerateGUID(), 
        itemData, 
        origin, 
        self:CalculateEndPosition(
            origin, 
            speed or GenerateRandomSpeed(), 
            direction or GenerateRandomDirection()
        )
    )
end


function DropService:SetOwner(lootItem, user, timer)
    lootItem:SetOwner(user, timer or OWNER_UNLOCK_TIME) 
end


-- TODO
function DropService:Drop(lootItem, decay)
    lootItem.Decayed:Connect(function()
        self:RemoveDrop(lootItem.DropID)
    end)

    lootItem:Drop(decay or DEFAULT_LOOT_DECAY_TIME)
    ItemsOnGround:Add(lootItem.DropID, lootItem)
    Network:FireAllClients(packet)
end


-- TODO
function DropService:RemoveDrop(dropID)
    ItemsOnGround:Remove(dropID):Destroy()
    Network:FireAllClients(packet)
end


function DropService:Lootable(user, dropID)
    local lootItem = ItemsOnGround:Get(dropID)
    local entity = EntityService:GetEntity(user.Character)
    return lootItem ~= nil
        and entity ~= nil
        and (entity:GetPosition() - lootItem.Position).Magnitude <= MAX_LOOT_DISTANCE
        and lootItem.UserId == user.UserId
end


function DropService:EngineInit()
    Network = self.Services.Network
    AssetService = self.Services.AssetService
    ItemService = self.Services.ItemService
    InventoryService = self.Services.InventoryService
    EntityService = self.Services.EntityService

    HttpService = self.RBXServices.HttpService

    DropRandom = Random.new()
	ItemsOnGround = self.Classes.IndexedMap.new()
end


function DropService:EngineStart()
	
end


return DropService