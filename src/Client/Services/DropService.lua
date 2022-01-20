-- DropService client, replicates items dropped on the ground
-- Dropped items will be spawned on the client via EffectService, and a client-sided entity
--  will be created to ensure that it is only visible when in render distance
-- Dynamese(enduo)
-- 1.5.2021



local DropService = {}

local BOUNCE_VELOCITY = 30
local REMOVE_TRY_AGAIN = 5
local MIN_WAIT = 1/30
local GRAVITY = Vector3.new(0, 196.2, 0)
local RAY_PARAMS = RaycastParams.new()

local Network, EffectService, MetronomeService
local CollectionService
local ItemsOnGround
local RayUtil


local function ReplicateDropped(dt, dropData, speed, direction, decayTime)
    local lootItem = DropService.Classes.Lootable.fromData(dropData)

    DropService.Modules.ThreadUtil.IntDelay(
        decayTime - dt, 
        function() 
            DropService:Remove(lootItem.DropID)
        end,
        lootItem.OnDestroyed
    )

    DropService:Throw(lootItem, speed, direction)
    ItemsOnGround:Add(lootItem.DropID, lootItem)
end


local function ReplicateUpdated(dt, dropID, dropData)
    local lootItem = ItemsOnGround:Get(dropID)

    if (lootItem ~= nil) then
        lootItem.Item = dropData.Item

        if (lootItem.Owner ~= dropData.Owner) then
            lootItem.Owner = dropData.Owner
            lootItem.Unlocked:Fire()
        end
    end
end


-- Replicates removal of an item from the ground
-- If the item doesn't exist yet, it could still be drawing
--  as in the asset could've been downloading whilst we
--  received the removal message. To protect against this
--  case, we simply try again after REMOVE_TRY_AGAIN seconds
-- @param dt <number>
-- @param dropID <string>
local function ReplicateRemoved(dt, dropID)
    if (ItemsOnGround:Get(dropID)) then
        DropService:Remove(dropID)
    else
        DropService.Modules.ThreadUtil.Delay(
            REMOVE_TRY_AGAIN, 
            DropService.Remove, 
            DropService, 
            dropID
        )
    end
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
    -- TODO: Create the entity

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
            currentPosition = nextFramePosition + Vector3.new(0, 0.001, 0)
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


-- Attempts to loot the item
-- @param dropID <string>
-- @returns <any>
function DropService:Take(dropID)
    return Network:RequestServer(Network.NetRequestType.LootableTak, dropID):Wait()
end


-- Retrieves item information
-- @param dropID <string>
-- @returns 
function DropService:GetInfo(dropID)
    return ItemsOnGround:Get(dropID)
end


-- Removes an item from the system
-- @param dropID <string>
function DropService:Remove(dropID)
    local lootItem = ItemsOnGround:Remove(dropID)
    if (lootItem ~= nil) then
        EffectService:StopEffect(lootItem.EffectUID, 0)
        lootItem:Destroy()
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