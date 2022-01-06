-- Animation Service client
-- 12.14.2021
-- Dynamese(Enduo)
-- ALL animation related requests will be routed through this service
-- Execution flow: 
--	LMB1 (melee attack)
--	-> Entity.Animator:PlayAction(animName) 
--	IF NOT CACHED
--	-> AnimServ:GetAnimation(animName)
--	IF NOT DOWNLOADED
--	-> AnimServ:QueryPack(animName) -> AssetService:GetPack(baseID)
-- 	-> AnimServ caches all animations in pack and returns the original requested animation
-- 	-> Animator loads and plays the track if entity is still in a state to at this point


local AnimationService = { Priority = 850 }

local AssetService, Network
local ManagedAnimators, CachedAnimations, CachedCoreAnimators


-- Manages a new entity's animator
-- @param entity to manage
-- @returns Animator
function AnimationService:ManageEntityAnimator(entity)
	local animator = self.Classes.Animator.new(entity)
	local autoDisconnector

	ManagedAnimators:Add(entity, animator)

	-- Self cleanup when the entity is destroyed
	autoDisconnector = entity.OnDestroyed:Connect(function()
		autoDisconnector:Disconnect()
		ManagedAnimators:Remove(entity)
	end)

	return animator
end


-- TODO
-- function AnimationService:ManageObjectAnimator(object)
-- 	local controller = object.Base:FindFirstChild("AnimationController") 
-- end


-- Retrieves an animator or invokes the creation of one
-- @param entity who's animator to retrieve
-- @returns Animator
function AnimationService:GetAnimator(entity)
	return ManagedAnimators:Get(entity) 
		or self:ManageEntityAnimator(entity)
end


-- Attempts to load an animation, will download if necessary
-- THIS FUNCTION YIELDS
-- @param animName <string> e.g. BloxianSwingSword001
-- @returns <Animation>
function AnimationService:GetAnimation(animName)
	local animation = CachedAnimations:Get(animName)

	if (not animation) then
		-- Yes, this introduces 2x the latency on first-time-pack downloads;
		--	HOWEVER, given a pack with 10, 20, ..., N animations in it,
		--	we ~reduce~ latency experienced by the player by a factor of N
		local animationPackID = Network:RequestServer(Network.NetRequestType.AnimationPackQuery, animName):Wait()
		local animationPackAsset = AssetService:GetAsset(animationPackID)

		for animationName, anim in pairs(animationPackAsset.Animations) do
			if (animationName == animName) then
				animation = anim
			end
			CachedAnimations:Add(animationName, anim)
		end
	end

	return animation
end


-- Attempts to retrieve a core animator module (which will be loaded into an <Animator>)
-- THIS FUNCTION YIELDS
-- @param coreAnimatorName <string> e.g. DefaultBloxianAnimator
-- @returns <ModuleScript>
function AnimationService:GetCoreAnimatorModule(coreAnimatorName)
	local coreAnimator = CachedCoreAnimators:Get(coreAnimatorName)

	-- Yes, doubles the latency involved in first-time loading of a coreanimator
	--	with no real upsides... This is the best I can think of right now that will
	--	keep things clean with how things work without making spaghetti edits
	if (not coreAnimator) then
		local coreAnimatorID = Network:RequestServer(Network.NetRequestType.CoreAnimatorQuery, coreAnimatorName):Wait()

		coreAnimator = AssetService:GetAsset(coreAnimatorID).AnimatorModule
		CachedCoreAnimators:Add(coreAnimatorName, coreAnimator)
	end

	return coreAnimator
end


function AnimationService:EngineInit()
	AssetService = self.Services.AssetService
	Network = self.Services.Network

	ManagedAnimators = self.Classes.IndexedMap.new()
	CachedAnimations = self.Classes.IndexedMap.new()
	CachedCoreAnimators = self.Classes.IndexedMap.new()
end


function AnimationService:EngineStart()
end


return AnimationService