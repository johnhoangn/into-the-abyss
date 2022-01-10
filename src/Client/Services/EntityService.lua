-- Entity service, client
-- Responsible of keeping track of all entities present in the player's cache
--  as well as rendering them
--
-- Dynamese (Enduo)
-- 07.19.2021



local SQRT = math.sqrt
local RENDER_DISTANCE = 100


local EntityService = { Priority = 700 }
local Network, MetronomeService
local ThreadUtil

local Camera
local RenderOrigin

local AllEntities
local VisibleEntities
local CachedEntities
local CacheMutex -- Make sure nothing changes during iteration
local RenderJobID, RenderJobSignal, RenderBuffer
local Requesting


-- Retrieves distance to entity
-- @param entity <Entity>
-- @retuns <float>
local function DistanceTo(entity)
    local pos = entity:GetPosition()
    return SQRT((pos.X - RenderOrigin.X)^2 + (pos.Z - RenderOrigin.Z)^2)
end


-- Tasker to draw/cache entities
-- @param dt <float>
local function RenderJob(dt)
    RenderOrigin.X = Camera.CFrame.Position.X
    RenderOrigin.Z = Camera.CFrame.Position.Z -- Transforming Z axis to Y

    if (not CacheMutex:TryLock()) then return end

    -- Check if there are any cached entities that are now in range
    table.clear(RenderBuffer)
    for base, entity in CachedEntities:KeyIterator() do
        if (entity.MustRender or DistanceTo(entity) < RENDER_DISTANCE) then
            table.insert(RenderBuffer, base)
        end
    end

    -- Load them
    for _, base in ipairs(RenderBuffer) do
        EntityService:LoadEntity(base)
    end

    -- Now to process visible entities if there are any
    local toProcess = VisibleEntities.Size

    if (toProcess > 0) then
        local function ProcessEntity(base, entity)
            -- Async due to potential asset downloads
            if (entity.MustRender or DistanceTo(entity) < RENDER_DISTANCE) then
                local s, e = pcall(entity.Draw, entity, dt)
                if (not s) then
                    warn("-------------------------------------------")
                    EntityService:Warn("DRAW ERROR: ", base, e)
                    local errModel = EntityService.Services.AssetService:GetAsset("00FFFF").Model:Clone()
                    errModel:PivotTo(base.PrimaryPart.CFrame)
                    errModel.PrimaryPart.Root.Part0 = base.PrimaryPart
                    errModel.Parent = base
                    warn(entity)
                    warn("NumEntities:", AllEntities.Size)
                    warn("-------------------------------------------")
                    VisibleEntities:Remove(base)
                end
                entity:UpdateState()
            else
                table.insert(RenderBuffer, base)
            end

            -- Lua is natively single thread, no race condition here
            if (toProcess == 1) then
                RenderJobSignal:Fire()
                return
            else
                toProcess -= 1
            end
        end

        -- Process them
        table.clear(RenderBuffer)
        for base, entity in VisibleEntities:KeyIterator() do
            -- entity:SetOpacity()
            ThreadUtil.Spawn(ProcessEntity, base, entity)
        end

        -- Yield for processing completion
        RenderJobSignal:Wait()

        -- Cleanup
        for _, base in ipairs(RenderBuffer) do
            EntityService:CacheEntity(base)
        end
    end
    CacheMutex:Unlock()
end


-- Updates an entity's equipment
-- I ~could~ force a draw update, but I'll leave that to the next render cycle for now
-- @param _dt <number>
-- @param base <Model>
-- @param slotChanged <Enums.EquipSlot>
-- @param itemData <ItemData> 
local function HandleEntityEquipmentChange(_dt, base, slotChanged, itemData)
    local entity = EntityService:GetEntity(base, 30)

    -- We're probably not getting this entity, forget it!
    if (not entity) then
        EntityService:Print("No entity for:", base, "DROPPED", itemData)
        return
    end

    entity.Equipment[slotChanged] = itemData
    EntityService:Log(1, "Update Equipment:", base)
end


-- Reconstructs entities from provided information
-- @param dt <float>
-- @param entities <table>, {<Model> = {Type = <string>; InitialParams = <table>}}
function EntityService:ReceiveEntities(_dt, bases, entityInfo)
    for i, base in pairs(bases) do
        if (EntityService:GetEntity(base) ~= nil) then
            continue
        end

        local info = entityInfo[i]
        local entity = EntityService:CreateEntity(
            base,
            info.Type,
            info.InitialParams
        )

        if (base == self.LocalPlayer.Character) then
            entity:MarkMustRender(true)
        end
    end
end


-- Retrieves an entity
-- @param base <Model>
-- @param downloadTimeout <number>, download if we don't have it (and are allowed)
-- @returns <T extends Entity>
-- @returns <boolean> if visible
function EntityService:GetEntity(base, downloadTimeout)
    local entity = AllEntities:Get(base)

    if (entity == nil and downloadTimeout) then
        if (Requesting[base] == nil) then
            Requesting[base] = true
            Network:RequestServer(
                Network.NetRequestType.EntityRequest,
                base
            ):Wait()
            Requesting[base] = nil
        else
            local waited = self.Classes.Signal.new()
            local waiter = self.EntityCreated:Connect(function(_base)
                if (_base == base) then
                    waited:Fire()
                end
            end)

            self.Modules.ThreadUtil.Delay(downloadTimeout, function()
                waited:Fire()
            end)

            waited:Wait()
            waiter:Disconnect()
        end
        
        entity = AllEntities:Get(base)
    end

    return entity, entity ~= nil and entity.Skin ~= nil
end


-- Creates a new entity and notifies all present players
-- @param base <Model>
-- @param entityType <string>
-- @param entityParams <table>
-- @param noLock <boolean> == false, calling thread owns lock; saves excessive calls and locking
-- @returns <T extends Entity>
function EntityService:CreateEntity(base, entityType, entityParams, noLock)
    local newEntity = self.Classes[entityType].new(base, entityParams)

    if (not noLock) then
        CacheMutex:Lock()
    end

    AllEntities:Add(base, newEntity)
    CachedEntities:Add(base, newEntity)

    if (not noLock) then
        CacheMutex:Unlock()
    end

    -- Auto cleanup
    base.PrimaryPart.AncestryChanged:Connect(function()
        if (not base.PrimaryPart or not base.PrimaryPart:IsDescendantOf(workspace)) then
            self:DestroyEntity(base)
        end
    end)

    self.EntityCreated:Fire(base)
    self:Log(1, "Create", base)
    
    return newEntity
end


-- Removes an entity and its physical base
-- @param base <Model>
function EntityService:DestroyEntity(base)
    CacheMutex:Lock()
    local entity = AllEntities:Get(base)

    if (entity ~= nil) then
        AllEntities:Remove(base)
        CachedEntities:Remove(base)
        VisibleEntities:Remove(base)

        self.EntityDestroyed:Fire(base)
        entity:Destroy()
    end
    CacheMutex:Unlock()
end


-- Removes all entities from the cache
--  useful for debugging as well as inter-system travel
-- @returns <integer> number of entries purged
function EntityService:PurgeCache()
    local size = AllEntities.Size

    CacheMutex:Lock()
    for base, entity in AllEntities:KeyIterator() do
        if (entity.PurgeExempt) then
            continue
        end

        self:CacheEntity(base)
        AllEntities:Remove(base)
        CachedEntities:Remove(base)
        VisibleEntities:Remove(base)
    end
    CacheMutex:Unlock()

    return size
end


-- Methods to move entities from cache/render
-- THREAD-UNSAFE, MAKE SURE TO LOCK/UNLOCK CACHEMUTEX
-- @param base <Model>
function EntityService:LoadEntity(base)
    local entity = CachedEntities:Remove(base)
    -- Entity may have been destroyed by the time we got the lock
    if (entity ~= nil) then
        VisibleEntities:Add(base, entity)
    end
end
function EntityService:CacheEntity(base)
    local entity = VisibleEntities:Remove(base)
    -- Entity may have been destroyed by the time we got the lock
    if (entity ~= nil) then
        entity:Hide()
        CachedEntities:Add(base, entity)
    end
end


-- Turns the renderer on or off
-- @param state <boolean>
function EntityService:Enable(state)
    if (state) then
        -- TODO: configuration for render-update-rate
        RenderJobID = MetronomeService:BindToFrequency(60, RenderJob)
    else
        MetronomeService:Unbind(RenderJobID)
    end

    self.Enabled = state
end


function EntityService:EngineInit()
    Network = self.Services.Network
    MetronomeService = self.Services.MetronomeService

    ThreadUtil = self.Modules.ThreadUtil

    Camera = workspace.CurrentCamera
    RenderOrigin = {
        X = Camera.CFrame.Position.X,
        Z = Camera.CFrame.Position.Z
    }

    AllEntities = self.Classes.IndexedMap.new()
    CachedEntities = self.Classes.IndexedMap.new()
    VisibleEntities = self.Classes.IndexedMap.new()
    CacheMutex = self.Classes.Mutex.new()

    RenderJobID = nil
    RenderJobSignal = self.Classes.Signal.new()
    RenderBuffer = {}
    Requesting = {}

    self.EntityCreated = self.Classes.Signal.new()
    self.EntityDestroyed = self.Classes.Signal.new()

    self.Enabled = false
end


function EntityService:EngineStart()
    self:Enable(true)

    wait(5)
    Network:HandleRequestType(Network.NetRequestType.EntityStream, function(dt, bases, entityData)
        EntityService:ReceiveEntities(dt, bases, entityData)
    end)
    Network:HandleRequestType(Network.NetRequestType.EntityEquipmentChanged, HandleEntityEquipmentChange)
end


return EntityService