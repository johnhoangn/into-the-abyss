-- DropService client, replicates items dropped on the ground
-- Dropped items will be spawned on the client via EffectService, and a client-sided entity
--  will be created to ensure that it is only visible when in render distance
-- Dynamese(enduo)
-- 1.5.2021



local DropService = {}

local DEFAULT_LOOT_DECAY_TIME = 120
local BOUNCE_VELOCITY = 30
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

local Network, AssetService, EffectService, InventoryService, EntityService, MetronomeService
local HttpService, CollectionService
local ItemsOnGround
local RayUtil


local function ReplicateDropped(dt, dropData, speed, direction)
    local lootItem = DropService.Classes.Lootable.fromData(dropData)

    ItemsOnGround:Add(lootItem.DropID, lootItem)
    DropService:Throw(lootItem, speed, direction)
end


local function ReplicateUpdated(dt, dropID, dropData)
    local lootItem = ItemsOnGround:Get(dropID)
    -- TODO: Update owner
    if (lootItem ~= nil) then
        lootItem.Item = dropData.Item
    end
end


local function ReplicateRemoved(dt, dropID)
    DropService:Remove(dropID)
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


-- TODO: If thrown when out of render distance, just spawn it 
--  immediately at the endposition defined by the server
-- @param lootItem <Lootable>
-- @param speed <number>
-- @param direction <Vector3>
function DropService:Throw(lootItem, speed, direction)
    -- TODO: Put the drop asset in
    -- TODO: Create the entity
    -- TODO: Throw the entity via effectservice

    local currentPosition = lootItem.Origin
    local velocity = direction * speed
    local nextFramePosition = currentPosition + velocity * MIN_WAIT
    local travelBudget = 300

    local eUID = EffectService:Make("FD1", nil, 0, lootItem, currentPosition, nextFramePosition)
    local jobID
    
    jobID = MetronomeService:BindToFrequency(60, function(dt)
        travelBudget -= velocity.Magnitude * dt

        local rayResults = RayUtil:CastQualifier(currentPosition, velocity * dt, RAY_PARAMS, CollisionQualifier)
        
        if (#rayResults > 0) then
            local result = rayResults[1] -- First element is first intersected and qualified

            if (CollectionService:HasTag(result.Instance, "OutOfBounds")) then
                EffectService:ChangeEffect(eUID, 0, currentPosition, result.Position)
                local bounceDir = velocity.Unit - (2 * velocity.Unit:Dot(result.Normal) * result.Normal)
                currentPosition = result.Position
                velocity = bounceDir * BOUNCE_VELOCITY
                nextFramePosition = currentPosition + velocity * dt -- u/s * s -> u
            else
                -- Valid landing position, stop fx
                EffectService:ChangeEffect(eUID, 0, lootItem.Position + Vector3.new(0, 1, 0), Vector3.new())
                MetronomeService:Unbind(jobID)
            end
        else
            -- Normal arc progression
            EffectService:ChangeEffect(eUID, 0, currentPosition, nextFramePosition)
            currentPosition = nextFramePosition
            nextFramePosition += velocity * dt -- u/s * s -> u
        end

        velocity -= GRAVITY * dt -- u/s^2 * s -> u/s

        if (travelBudget <= 0) then
            EffectService:ChangeEffect(eUID, 0, lootItem.Position + Vector3.new(0, 1, 0), Vector3.new())
            MetronomeService:Unbind(jobID)
        end
    end)

    -- For use when destroying the lootable
    lootItem.EffectUID = eUID
end


function DropService:Take(dropID)
    Network:RequestServer(Network.NetRequestType.LootableTak, dropID)
end


function DropService:GetInfo(dropID)
    return ItemsOnGround:Get(dropID)
end


function DropService:Remove(dropID)
    local lootItem = ItemsOnGround:Remove(dropID)

    if (lootItem ~= nil) then
        lootItem:Destroy()
        -- TODO: Destroy attached members
    end
end


function DropService:EngineInit()
	Network = self.Services.Network
    AssetService = self.Services.AssetService
    EffectService = self.Services.EffectService
    InventoryService = self.Services.InventoryService
    EntityService = self.Services.EntityService
    MetronomeService = self.Services.MetronomeService

    HttpService = self.RBXServices.HttpService
    CollectionService = self.RBXServices.CollectionService

    RayUtil = self.Modules.RayUtil

    CollisionGroup = self.Enums.CollisionGroup

	ItemsOnGround = self.Classes.IndexedMap.new()
end


function DropService:EngineStart()
	Network:HandleRequestType(Network.NetRequestType.LootableDropped, ReplicateDropped)
    Network:HandleRequestType(Network.NetRequestType.LootableUpdated, ReplicateUpdated)
    Network:HandleRequestType(Network.NetRequestType.LootableRemoved, ReplicateRemoved)
end


return DropService