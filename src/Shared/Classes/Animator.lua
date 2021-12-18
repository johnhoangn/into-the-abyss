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


local DeepObject = require(script.Parent.DeepObject)
local Animator = {States = {Disabled = 0, Enabled = 1}}
Animator.__index = Animator
setmetatable(Animator, DeepObject)


-- TODO: CONVERT "ACTIONTRACK" TO "ACTIONTRACK~S~" AS MULTIPLE ACTIONS CAN PLAY/END AT ONCE
-- @param entity <Entity> to play animations for
function Animator.new(entity)
	local self = DeepObject.new({
		_Controller = entity.Base:FindFirstChild("Humanoid");

		_CoreLock = nil;
		_CachedTracks = nil;
		_CurrentCoreTrack = nil;
		_CurrentActionTrack = nil;

		_CurrentCoreTrackName = nil;
		_CurrentActionTrackName = nil;

		_CoreTrackTime = 0;
		_ActionTrackTime = 0;

		_Entity = entity;

		State = Animator.States.Disabled;
	})

	setmetatable(self, Animator)
	self._CoreLock = self.Classes.Mutex.new()
	self._CachedTracks = self.Classes.IndexedMap.new()

	local coreAnimatorModule = self.Services.AnimationService
		:GetCoreAnimatorModule(entity.SkinAsset.CoreAnimator)
		
	self:LoadCoreModule(require(coreAnimatorModule))

	return self
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


-- Attempt to overwrite builtin methods with the provided core animator
-- 	if it changes the default behavior 
-- @param coreAnimator
function Animator:LoadCoreModule(coreAnimator)
	self.PickCoreTrack = coreAnimator.PickCoreTrack or self.PickCoreTrack
	self.PlayCore = coreAnimator.PlayCore or self.PlayCore
	self.PlayAction = coreAnimator.PlayAction or self.PlayAction
	self.Step = coreAnimator.Step or self.Step
end


-- Based on entity state, select a core track to play
function Animator:PickCoreTrack()
	return "BloxianDefaultIdle001"
end


-- Records where the animations are in time
function Animator:Pause()
	self._CoreTrackTime = self._CurrentCoreTrack.TimePosition
	self._ActionTrackTime = self._CurrentActionTrack.TimePosition
	
	if (self._CurrentCoreTrack) then
		self._CurrentCoreTrack:Stop(DEFAULT_FADE_TIME)
		self._CurrentCoreTrack = nil
	end

	if (self._CurrentActionTrack) then
		self._CurrentActionTrack:Stop(DEFAULT_FADE_TIME)
		self._CurrentActionTrack = nil
	end
end


-- Plays an animation on the core layer
-- Stops the previous core layer track
-- @param trackName <string>
function Animator:PlayCore(trackName, fade, weight, rate)
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
	self._CurrentCoreTrackName = trackName

	if (coreTrack == nil) then
		local animation = self.Services.AnimationService:GetAnimation(trackName)
		
		-- If we downloaded the animation, during which we changed to a disabled state,
		--	abort the load and do not resume; do not modify ANYTHING
		if (self.State == self.States.Disabled) then
			self._CoreLock:Unlock()
			return
		end

		coreTrack = self._Controller:LoadAnimation(animation)
		self._CachedTracks:Add(trackName, coreTrack)
	end

	self._CurrentCoreTrack = coreTrack
	coreTrack:Play(fade or DEFAULT_FADE_TIME, weight or 1, rate or 1)
	self._CoreLock:Unlock()
end


-- Plays an animation on the action layer
-- FOR NOW, stops the previous action layer track
function Animator:PlayAction(trackName, fade, weight, rate)
	local actionTrack = self._CachedTracks:Get(self._CurrentActionTrackName)

	if (actionTrack == nil) then
		local animation = self.Services.AnimationService:GetAnimation(trackName)
		
		-- If we downloaded the animation, during which we changed to a disabled state,
		--	abort the load and do not resume; do not modify ANYTHING
		if (self.State == self.States.Disabled) then
			return
		end

		actionTrack = self._Controller:LoadAnimation(animation)
		actionTrack.TimePosition = self._ActionTrackTime
	end

	self._CurrentActionTrack = actionTrack
	actionTrack:Play(fade or DEFAULT_FADE_TIME, weight or 1, rate or 1)
end


-- Used to do core track selection
function Animator:Step(dt)
	error("Step() not implemented")
end


return Animator
