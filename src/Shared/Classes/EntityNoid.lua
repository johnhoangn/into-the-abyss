-- EntityNoid class
--
-- Dynamese (Enduo)
-- 12.11.2021



local Entity = require(script.Parent.Entity)
local EntityNoid = {}
EntityNoid.__index = EntityNoid
setmetatable(EntityNoid, Entity)

local AssetService


-- Normal constructor
-- @param base <Model>
-- @param initialParams <table> == nil, convenience for EntityNoid subclasses
-- @returns <EntityNoid>
function EntityNoid.new(base, initialParams)
	local self = Entity.new(base, initialParams)
	local StateMachine = self.Classes.StateMachine.new("Idle")
	local States = StateMachine.States

	StateMachine:AddState("Jogging")
	StateMachine:AddState("Jumping")
	StateMachine:AddState("Attacking")
	StateMachine:AddState("Staggering")
	StateMachine:AddState("Stun")

	StateMachine:AddTransition(States.Any, States.Staggering)

	StateMachine:AddTransition(States.Idle, States.Jogging)
	StateMachine:AddTransition(States.Idle, States.Attacking)
	StateMachine:AddTransition(States.Idle, States.Jumping)

	StateMachine:AddTransition(States.Jogging, States.Idle)
	StateMachine:AddTransition(States.Jogging, States.Jumping)
	StateMachine:AddTransition(States.Jogging, States.Attacking)

	StateMachine:AddTransition(States.Jumping, States.Jogging)
	StateMachine:AddTransition(States.Jumping, States.Idle)

	StateMachine:AddTransition(States.Attacking, States.Idle)
	StateMachine:AddTransition(States.Attacking, States.Jumping)

	StateMachine:AddTransition(States.Stun, States.Idle)
	StateMachine:AddTransition(States.Staggering, States.Idle)

	self.StateMachine = StateMachine

	self:AddSignal("Landed")
	self:AddSignal("Jumped")
	
	base.Humanoid.StateChanged:Connect(function(_from, to)
		if (to == Enum.HumanoidStateType.Landed) then
			if (StateMachine:CanTransitionTo(States.Idle)) then
				StateMachine:TransitionTo(States.Idle)
			end
			self.Landed:Fire()
		end
	end)

	return setmetatable(self, EntityNoid)
end


function EntityNoid:CanJump()
	return self.Base.Humanoid.FloorMaterial ~= Enum.Material.Air
		and (self.Base.Humanoid:GetState() == Enum.HumanoidStateType.Running
			or self.Base.Humanoid:GetState() == Enum.HumanoidStateType.RunningNoPhysics)
		and self.StateMachine:CanTransitionTo(self.StateMachine.States.Jumping)
end


function EntityNoid:Jump()
	local mass = self.Root.AssemblyMass

	self.StateMachine:TransitionTo(self.StateMachine.States.Jumping)
	self.Root:ApplyImpulse(Vector3.new(0, 50, 0) * mass)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityNoid end


-- Client constructor variant, adds on data that only the client needs
local new = EntityNoid.new
function EntityNoid.new(...)
	AssetService = AssetService or Entity.Services.AssetService

	local self = new(...)
	local asset = AssetService:GetAsset(self.InitialParams._SkinID)

	self.SkinAsset = asset

	self._LastOpacity = Entity.Enums.Opacity.Opaque;
	self._Opacity = Entity.Enums.Opacity.Opaque;

	self.Root = self.Base.PrimaryPart

	return self
end


-- Renders this EntityNoid
function EntityNoid:Draw(dt)
    if (self.Skin == nil) then
        local skin = self.SkinAsset.Model:Clone()
        local parts = {}

        for _, part in ipairs(skin:GetDescendants()) do
            if (part:IsA("BasePart") and part.Transparency < 1) then
                parts[part] = part.Transparency
            end
        end

        skin:PivotTo(self.Base.PrimaryPart.CFrame * skin.PrimaryPart.Root.C1)
		skin.PrimaryPart.Root.Part0 = self.Base.PrimaryPart
        skin.Parent = self.Base

		-- Try to resume the animator if I have one
		if (self._Animator ~= nil) then
			self._Animator:Resume()
		else
			-- Initialize my client sided animator if applicable
			if (self.SkinAsset.CoreAnimator ~= nil) then
				self._Animator = self.Services.AnimationService:GetAnimator(self)
				self._Animator:Resume()
			end
		end

        self.Skin = skin
        self._Parts = parts
	elseif (self._Animator ~= nil) then
		self._Animator:Step(dt)
    end
end


-- Does the skin attached to me have a client-sided animator?
function EntityNoid:HasAnimator()
	return self._Animator ~= nil
end


-- Only if we have one
-- @param dt seconds since last step
function EntityNoid:StepAnimator(dt)
	self._Animator:Step(dt)
end


-- Sets how transparent/opaque to draw this EntityNoid
function EntityNoid:SetOpacity()
    error("Cannot change opacity")
end


-- Removes the skin
function EntityNoid:Hide()
	if (self._Animator ~= nil) then
		self._Animator:Pause()
	end

    self.Skin:Destroy()
    self.Skin = nil
    self._Parts = nil
end


-- Destroys this instance and its physical skin along with it
local superDestroy = Entity.Destroy
function EntityNoid:Destroy()
    self:Hide()

	if (self._Animator ~= nil) then
		self._Animator:Destroy()
	end

    superDestroy()
end


return EntityNoid
