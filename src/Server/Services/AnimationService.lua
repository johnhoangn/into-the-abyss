-- Animation Service server
-- 12.14.2021
-- Dynamese(Enduo)
-- At least for now, this only exists because I didn't want to bunch edge-case logic into AssetService
-- Will extend to replicating animations across clients


local AnimationService = {Priority = 109} -- inits AFTER assetservice
local Network
local AnimationPackLookup, CoreAnimatorLookup


local function GeneratePackLookups()
	local Hexadecimal = AnimationService.Modules.Hexadecimal
	local classID = Hexadecimal.new(AnimationService.Enums.AssetClass.AnimationPack, 2)
	local allPacks = AnimationService.Root.Assets[classID]:GetChildren()

	-- Hmm, this is quite a large single level structure...
	-- TODO: Consider some other data structure that would divide 
	--	the dataset more effectively
	for _, pack in ipairs(allPacks) do
		local assetID = Hexadecimal.new(tonumber(pack.AssetID.Value))
		local baseID = classID .. assetID
		
		for _, animation in ipairs(pack.Client.Animations:GetChildren()) do
			AnimationPackLookup:Add(animation.Name, baseID)
		end
	end
end


local function GenerateCoreAnimatorLookups()
	local Hexadecimal = AnimationService.Modules.Hexadecimal
	local classID = Hexadecimal.new(AnimationService.Enums.AssetClass.CoreAnimator, 2)
	local allCoreAnimators = AnimationService.Root.Assets[classID]:GetChildren()

	-- Hmm, this is quite a large single level structure...
	-- TODO: Consider some other data structure that would divide 
	--	the dataset more effectively
	for _, coreAnimator in ipairs(allCoreAnimators) do
		local assetID = Hexadecimal.new(tonumber(coreAnimator.AssetID.Value))
		local baseID = classID .. assetID

		CoreAnimatorLookup:Add(coreAnimator.Shared.AssetName.Value, baseID)
	end
end


-- Processes pack queries
-- @param client <Player>
-- @param _deltaTime <number>
-- @param trackName <string>
-- @returns <BaseID>
local function ServePackQuery(client, _deltaTime, trackName)
	return AnimationService:GetAnimationPackID(client, trackName)
end


-- Process core animator queries
-- @param client <Player>
-- @param _deltaTime <number>
-- @param coreAnimatorName <string>
-- @returns <BaseID>
local function ServeCoreAnimatorQuery(client, _deltaTime, coreAnimatorName)
	return AnimationService:GetCoreAnimatorID(client, coreAnimatorName)
end


-- Retrieves an animation pack via animation name
-- @param trackName <string> e.g. BloxianSwingSword001
function AnimationService:GetAnimationPackID(client, trackName)
	local packID = AnimationPackLookup:Get(trackName)

	if (not packID) then
		-- TODO: Bigbrother, invalid trackname
		self:Warn("Invalid track to request pack for:", trackName, client)
		return nil
	end

	return packID
end


-- Retrieves a core animator via core animator name
-- @param client <Player>
-- @param coreAnimatorName <string>
-- @returns <BaseID>
function AnimationService:GetCoreAnimatorID(client, coreAnimatorName)
	local coreAnimatorID = CoreAnimatorLookup:Get(coreAnimatorName)

	if (not coreAnimatorID) then
		-- TODO: Bigbrother, invalid trackname
		self:Warn("Invalid track to request pack for: ", coreAnimatorName, client)
		return nil
	end

	return coreAnimatorID
end


function AnimationService:EngineInit()
	Network = self.Services.Network

	AnimationPackLookup = self.Classes.IndexedMap.new()
	CoreAnimatorLookup = self.Classes.IndexedMap.new()

	GeneratePackLookups()
	GenerateCoreAnimatorLookups()
end


function AnimationService:EngineStart()
	Network:HandleRequestType(Network.NetRequestType.AnimationPackQuery, ServePackQuery)
	Network:HandleRequestType(Network.NetRequestType.CoreAnimatorQuery, ServeCoreAnimatorQuery)
end


return AnimationService