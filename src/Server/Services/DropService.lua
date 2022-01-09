-- DropService server, drops items on the ground and handles lootable/looting
-- Dynamese(enduo)
-- 1.5.2021



local DropService = {}

local DEFAULT_LOOT_DECAY_TIME = 120
local BOUNCE_EFFICIENCY = 0.75
local OWNER_UNLOCK_TIME = 60
local MAX_LOOT_DISTANCE = 10
local RANDOM_SPEED_MIN = 15
local RANDOM_SPEED_MAX = 25
local RANDOM_ANGLE_MIN = 45
local RANDOM_ANGLE_MAX = 70
local TAU = math.pi*2
local COS = math.cos
local SIN = math.sin
local RAD = math.rad
local ABS = math.abs
local MIN_WAIT = 1/30
local GRAVITY = Vector3.new(0, 196.2, 0)
local RAY_PARAMS = RaycastParams.new()
local DEBUGGING = true

local Network, AssetService, ItemService, InventoryService, EntityService, RayUtil
local HttpService, CollectionService
local DropRandom, ItemsOnGround

local CollisionGroup


local function GenerateRandomSpeed()
    return DropRandom:NextNumber(RANDOM_SPEED_MIN, RANDOM_SPEED_MAX)
end


local function GenerateRandomDirection()
    local theta1 = DropRandom:NextNumber() * TAU
    local theta2 = RAD(DropRandom:NextNumber(RANDOM_ANGLE_MIN, RANDOM_ANGLE_MAX))
    return Vector3.new(
        COS(theta1),
        SIN(theta2),
        SIN(theta1)
    )
end


-- @param results <RayResult>
local function CollisionQualifier(results)
    local instance = results.Instance
    
    return (
            instance.CanCollide
            and instance.CollisionGroupId ~= CollisionGroup.Entity
        )

        or (
            CollectionService:HasTag(instance, "OutOfBounds")
        )
end


local function Visualize(a, b)
    if (not DEBUGGING) then return end
    local p = Instance.new("Part")
    p.Anchored = true
    p.Size = Vector3.new(.1, .1, (a - b).Magnitude)
    p.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -p.Size.Z/2)
    p.CanCollide = false
    p.Color = Color3.new(1,0,0)
    p.Parent = workspace
end


function DropService:CalculateEndPosition(origin, speed, direction)
    local currentPosition = origin
    local velocity = direction * speed
    local nextFramePosition = currentPosition + velocity * MIN_WAIT
    local travelBudget = 300

    Visualize(currentPosition, nextFramePosition)

    while (travelBudget > 0) do
        travelBudget -= velocity.Magnitude * MIN_WAIT

        local rayResults = RayUtil:CastQualifier(currentPosition, velocity * MIN_WAIT, RAY_PARAMS, CollisionQualifier)
        
        if (#rayResults > 0) then
            local result = rayResults[1] -- First element is first intersected and qualified

            if (CollectionService:HasTag(result.Instance, "OutOfBounds")) then
                Visualize(currentPosition, result.Position)
                local bounceDir = velocity.Unit - (2 * velocity.Unit:Dot(result.Normal) * result.Normal)
                currentPosition = result.Position
                velocity = bounceDir * ABS(velocity.Magnitude) * BOUNCE_EFFICIENCY
                nextFramePosition = currentPosition + velocity * MIN_WAIT -- u/s * s -> u
            else
                -- Valid landing position
                Visualize(currentPosition, result.Position)
                return result.Position
            end
        else
            -- Normal arc progression
            Visualize(currentPosition, nextFramePosition)
            currentPosition = nextFramePosition
            nextFramePosition += velocity * MIN_WAIT -- u/s * s -> u
        end

        velocity -= GRAVITY * MIN_WAIT -- u/s^2 * s -> u/s
    end
print("max ranged")
    -- Max-range. Default position to origin
    return origin
end


function DropService:MakeDrop(itemData)
    return self.Classes.Lootable.new(
        HttpService:GenerateGUID(), 
        itemData
    )
end


function DropService:SetOwner(lootItem, user, timer)
    lootItem:SetOwner(user, timer or OWNER_UNLOCK_TIME) 
end


function DropService:Drop(lootItem, origin, decay, speed, direction)
    lootItem.Decayed:Connect(function()
        self:RemoveDrop(lootItem.DropID)
    end)

    lootItem:Drop(decay or DEFAULT_LOOT_DECAY_TIME, 
        origin, 
        self:CalculateEndPosition(
            origin, 
            speed or GenerateRandomSpeed(), 
            direction or GenerateRandomDirection()
        )
    )

    ItemsOnGround:Add(lootItem.DropID, lootItem)
    Network:FireAllClients(
        Network:Pack(
            Network.NetProtocol.Forget, 
            Network.NetRequestType.LootableDropped,
            lootItem:Encode()
        )
    )
end



function DropService:RemoveDrop(dropID)
    ItemsOnGround:Remove(dropID):Destroy()
    Network:FireAllClients(
        Network:Pack(
            Network.NetProtocol.Forget, 
            Network.NetRequestType.LootableRemoved,
            dropID
        )
    )
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
    CollectionService = self.RBXServices.CollectionService

    RayUtil = self.Modules.RayUtil

    CollisionGroup = self.Enums.CollisionGroup

    DropRandom = Random.new()
	ItemsOnGround = self.Classes.IndexedMap.new()
end


function DropService:EngineStart()
	
end


return DropService