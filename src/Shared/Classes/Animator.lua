-- Animator Class
-- Dynamese(Enduo)
-- 12.15.2021
-- Base animator that can be extended by a core animator module
-- CORE animations are all looping types and are automatically handled by
--	the Animator unless the extension core animator provides different behavior
--	defined in Animator:Step(dt)
-- ACTION animations may or may not be looping types and must be kept track of
--	by the thread responsible for playing them



local DEFAULT_FADE_TIME = 0.1


local Engine = _G.Deep
local Parser = Engine.Modules.KeyframeMarkerArgumentParser
local HttpService = Engine.RBXServices.HttpService
local SoundClassID = Engine.Enums.AssetClass.Sound
local DeepObject = require(script.Parent.DeepObject)
local Animator = {States = {Disabled = 0, Enabled = 1}}
Animator.__index = Animator
setmetatable(Animator, DeepObject)


-- Generates a callback suitable for receiving keyframe marker signals
-- @param trigger <string> trigger type
local function TriggerFactory(trigger)
	if (trigger == "Sound") then
		return function(params)
			local args = Parser:Parse(params)
			Engine.Services.SoundService:PlaySound(
				Engine.Enums.SoundClass[
					params.SoundClass 
					or Engine.Enums.SoundClass.Effect
				],
				SoundClassID .. args.AssetID, 
				params
			)
		end
	elseif (trigger == "Effect") then
		return nil
	end
end


-- @param entity <Entity> to play animations for
function Animator.new(entity)
	local self = setmetatable(DeepObject.new({
		_Controller = entity.Base:WaitForChild("Humanoid", 5);

		_CoreLock = nil;
		_CachedTracks = nil;
		_CurrentCoreTrack = nil;
		_CurrentCoreTrackName = nil;
		_CoreTrackTime = 0;

		_MarkerTriggers = nil;

		_CurrentActions = nil;

		_Entity = entity;

		State = Animator.States.Disabled;
	}), Animator)

	assert(self._Controller ~= nil, "Humanoid never loaded " .. entity.Base.Name)

	self._CoreLock = self.Classes.Mutex.new()
	self._CachedTracks = self.Classes.IndexedMap.new()
	self._MarkerTriggers = self.Classes.IndexedMap.new()
	self._CurrentActions = self.Classes.IndexedMap.new()

	local coreAnimatorModule = self.Services.AnimationService
		:GetCoreAnimatorModule(entity.SkinAsset.CoreAnimator)

	self:LoadCoreModule(require(coreAnimatorModule))

	-- Plays and stops state-related action animations
	entity.StateMachine.StateChanged:Connect(function(from, to)
		if (to == entity.StateMachine.States.Jumping) then
			self._JumpActionID = self:PlayAction(self:PickJumpTrack())
		elseif (from == entity.StateMachine.States.Jumping) then
			if (self._JumpActionID) then
				self:StopAction(self._JumpActionID)
				self._JumpActionID = nil
			end
		end
	end)

	return self
end


-- Attempt to overwrite builtin methods with the provided core animator
-- 	if it changes the default behavior 
-- @param coreAnimator
function Animator:LoadCoreModule(coreAnimator)
	self.PickCoreTrack = coreAnimator.PickCoreTrack or self.PickCoreTrack
    self.PickJumpTrack = coreAnimator.PickJumpTrack or self.PickJumpTrack
	self.PlayCore = coreAnimator.PlayCore or self.PlayCore
	self.PlayAction = coreAnimator.PlayAction or self.PlayAction
	self.Step = coreAnimator.Step or self.Step
end


-- Based on entity state, select a core track to play
function Animator:PickCoreTrack()
	return "BloxianDefaultIdle001"
end


-- Special core track getter
function Animator:PickJumpTrack()
	return "BloxianDefaultJump001"
end


-- Reads triggermap and binds the markers to respective actions
-- @param track <AnimationTrack>
-- @param triggerMap <table>
function Animator:BindTriggers(track, triggerMap)
	local bindingMaid = self.Classes.Maid.new()

	for marker, trigger in pairs(triggerMap) do
		bindingMaid:GiveTask(track:GetMarkerReachedSignal(marker):Connect(TriggerFactory(trigger)))
	end

	self._MarkerTriggers:Add(track.Name, bindingMaid)
end


-- Plays an animation on the core layer
-- Stops the previous core layer track
-- @param trackName <string>
-- @param fade <number>
-- @param weight <number>
-- @param rate <number>
-- @param triggerMap <table> == nil
function Animator:PlayCore(trackName, fade, weight, rate, triggerMap)
	if (not self._CoreLock:TryLock()) then return end

	if (self._CurrentCoreTrack ~= nil) then
		-- CurrentCoreTrack is only non-nil if there is a core track playing
		if (self._CurrentCoreTrackName == trackName) then
			self._CoreLock:Unlock()
			return
		end
		self._CurrentCoreTrack:Stop(DEFAULT_FADE_TIME)
	end

	local coreTrack = self._CachedTracks:Get(trackName)

	if (coreTrack == nil) then
		local animation = self.Services.AnimationService:GetAnimation(trackName)
		
		-- If we downloaded the animation, during which we changed to a disabled state,
		--	abort the load and do not resume; do not modify ANYTHING
		if (self.State == self.States.Disabled) then
			self._CoreLock:Unlock()
			return
		end

		if (triggerMap ~= nil) then
			self:BindTriggers(trackName, triggerMap)
		end

		coreTrack = self._Controller:LoadAnimation(animation)
		self._CachedTracks:Add(trackName, coreTrack)
	end

	self._CurrentCoreTrackName = trackName
	self._CurrentCoreTrack = coreTrack
	coreTrack:Play(fade or DEFAULT_FADE_TIME, weight or 1, rate or 1)
	self._CoreLock:Unlock()
end


-- Plays an animation on the action layer
-- FOR NOW, stops the previous action layer track
-- @param trackName <string>
-- @param fade <number>
-- @param weight <number>
-- @param rate <number>
-- @returns trackID
function Animator:PlayAction(trackName, fade, weight, rate)
	local actionTrack = self._CachedTracks:Get(trackName)
	local actionID = HttpService:GenerateGUID()

	if (actionTrack == nil) then
		local animation = self.Services.AnimationService:GetAnimation(trackName)
		
		-- If we downloaded the animation, during which we changed to a disabled state,
		--	abort the load and do not resume; do not modify ANYTHING
		if (self.State == self.States.Disabled) then
			return
		end

		actionTrack = self._Controller:LoadAnimation(animation)
		self._CachedTracks:Add(trackName, actionTrack)
	end

	self._CurrentActions:Add(actionID, {
		Track = actionTrack;
		Name = trackName;
	})

	actionTrack.Priority = Enum.AnimationPriority.Action
	actionTrack:Play(fade or DEFAULT_FADE_TIME, weight or 1, rate or 1)

	return actionID
end


-- Stops a previously playing action referred to by ID
-- @param actionID <string>
-- @param fade <number>
function Animator:StopAction(actionID, fade) 
	local action = self._CurrentActions:Get(actionID)

	if (not action) then
		self:Warn("Action wasn't playing!", actionID)
		return
	end

	action.Track:Stop(fade)
end


-- Retrieves a playing track via actionID
-- @param actionID <string>
-- @return <AnimationTrack>
function Animator:GetActionTrack(actionID)
	return self._CurrentActions:Get(actionID).Track
end


-- Resumes any playing animations where they left off
function Animator:Resume()
	self.State = self.States.Enabled

	-- Resume core
	local coreTrackName = self:PickCoreTrack()
	self:PlayCore(coreTrackName)
	self._CurrentCoreTrack.TimePosition = self._CoreTrackTime

	-- Resume action
	if (self._CurrentActionTrackName) then
		self:PlayAction(self._CurrentActionTrackName)
	end
end


-- Records where the animations are in time
function Animator:Pause()
	if (self._CurrentCoreTrack) then
		self._CoreTrackTime = self._CurrentCoreTrack.TimePosition
		self._CurrentCoreTrack:Stop(DEFAULT_FADE_TIME)
		self._CurrentCoreTrack = nil
	end

	if (self._CurrentActionTrack) then
		self._ActionTrackTime = self._CurrentActionTrack.TimePosition
		self._CurrentActionTrack:Stop(DEFAULT_FADE_TIME)
		self._CurrentActionTrack = nil
	end
end


-- Used to do core track selection
function Animator:Step(dt)
	error("Step() not implemented")
end


local superDestroy = Animator.Destroy
function Animator:Destroy()
	for _, track in self._CachedTracks:KeyIterator() do
		track:Destroy()
	end

	for _, markerMaid in ipairs(self._MarkerTriggers) do
		print("Destroy maid")
		markerMaid:Destroy()
	end

	superDestroy(self)
end


return Animator
