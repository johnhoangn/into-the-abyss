-- Entity service, server
-- Responsible of keeping track of all entities present in the game
--
-- Dynamese (Enduo)
-- 07.19.2021



local EntityService = {Priority = 100}
local AssetService, CollectionService, Network
local NetProtocol, NetRequestType


local AllEntities
local CacheMutex


-- Creates an entity based on a prefabricated entity
-- e.g. the world during dev
-- @param base <Model>
local function Prefab(base)
    local entityParams = {}

    for _, parameter in ipairs(base.Configuration:GetChildren()) do
        entityParams[parameter.Name] = parameter.Value
    end

    local classID = entityParams._BaseID:sub(1, 2)
    local entityType = AssetService:GetClassName(classID)

    return EntityService.Classes[entityType].new(base, entityParams)
end


-- Grabs necessary information that would enable clients to
--  reconstruct all entities from the bases given
-- @param bases <table>, list of entity information
-- @returns <table>
function EntityService:PackEntityInfo(bases)
    local entities = {}

    -- Pack only relevant info, omitting functions and signals
    CacheMutex:Lock()
    for i, base in ipairs(bases) do
        local entity =  EntityService:GetEntity(base)
        entities[i] = {
            Type = entity.ClassName;
            InitialParams = entity.InitialParams;
        }
    end
    CacheMutex:Unlock()

    return entities
end


-- Retrieves an entity
-- @param base <Model>
-- @returns <T extends Entity>
function EntityService:GetEntity(base)
    return AllEntities:Get(base)
end


-- Retrieves a list of entities
-- @param bases <table>
-- @returns <table>
function EntityService:GetEntities(bases)
    local entities = {}

    for i, base in ipairs(bases) do
        entities[i] = self:GetEntity(base)
    end

    return entities
end


-- Creates a new entity and notifies all present players
-- @param base <Model>
-- @param entityType <string>
-- @param entityParams <table>
-- @returns <T extends Entity>
function EntityService:CreateEntity(base, entityType, entityParams)
    local newEntity = self.Classes[entityType].new(base, entityParams)

    CacheMutex:Lock()
    AllEntities:Add(base, newEntity)
    CacheMutex:Unlock()

    self.EntityCreated:Fire(base)

	Network:FireAllClients(
		Network:Pack(
			NetProtocol.Forget, 
			NetRequestType.EntityStream, 
			{base}, 
			EntityService:PackEntityInfo({base})
		)
	)

    return newEntity
end


-- Removes an entity and its physical base
-- @param base <Model>
function EntityService:DestroyEntity(base)
    local entity = AllEntities:Get(base)

    if (entity ~= nil) then
        AllEntities:Remove(base)
        self.EntityDestroyed:Fire(base)
        entity:Destroy()

        -- entity destroyed replication automatically handled when "base"
        --  is destroyed and that state is communicated via Roblox
    end
end


function EntityService:EngineInit()
	Network = self.Services.Network
	NetRequestType = self.Enums.NetRequestType
	NetProtocol = self.Enums.NetProtocol
    AssetService = self.Services.AssetService
	CollectionService = self.RBXServices.CollectionService

    CacheMutex = self.Classes.Mutex.new()
    AllEntities = self.Classes.IndexedMap.new()

    self.EntityCreated = self.Classes.Signal.new()
    self.EntityDestroyed = self.Classes.Signal.new()

    -- Gather map entity placements and log them
    for _, model in ipairs(CollectionService:GetTagged("EntityInit")) do
        if (not model:IsDescendantOf(workspace)) then continue end
        AllEntities:Add(model, Prefab(model))
        if (model:FindFirstChild("Model") ~= nil) then model.Model:Destroy() end
        model.PrimaryPart.Transparency = 1
        model.Configuration:Destroy()
        -- Don't waste memory on storing/replicating the models
    end
end


function EntityService:EngineStart()
	self.Services.PlayerService:AddJoinTask(function(user)
		local bases = {}
		local entityData

		for base, _ in AllEntities:KeyIterator() do
			table.insert(bases, base)
		end

		entityData = EntityService:PackEntityInfo(bases)

		Network:FireClient(
			user, 
			Network:Pack(
				NetProtocol.Forget, 
				NetRequestType.EntityStream, 
				bases, 
				entityData
			)
		)
	end, "Initial Entity Streamer")

	self.Services.PlayerService:AddJoinTask(function(user)
		user.CharacterAdded:Connect(function()
			if (user.Character.Parent ~= workspace) then
				print("Waiting for reparent")
				user.Character.AncestryChanged:Wait()
				print("Reparented")
			end
			warn("ready to create for", user.Character)
			EntityService:CreateEntity(user.Character, "EntityPC", self.Modules.DefaultEntityNoid)
			warn("created for", user.Character, self:GetEntity(user.Character))
		end)

		if (user.Character ~= nil) then
			if (user.Character.Parent ~= workspace) then
				user.Character.AncestryChanged:Wait()
			end
			EntityService:CreateEntity(user.Character, "EntityPC", self.Modules.DefaultEntityNoid)
		end
	end, "AutoUserEntityCreator")
end


return EntityService