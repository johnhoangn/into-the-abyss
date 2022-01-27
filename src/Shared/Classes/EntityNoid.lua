-- EntityNoid class, variant of entity that resembles a roblox humanoid type existence
--
-- Dynamese (Enduo)
-- 12.11.2021



local Engine = _G.Deep
local AssetService = Engine.Services.AssetService
local EntityModifiers = Engine.Services.EntityModifiers
local Entity = require(script.Parent.Entity)
local EntityNoid = {}
EntityNoid.__index = EntityNoid
setmetatable(EntityNoid, Entity)


-- Add transitions here
local Transitions = {
	MoveStart = 0;
	MoveStop = 1;

	MoveJump = 2;
	Jump = 3;
	Falling1 = 4;
	Falling2 = 5;
	Falling3 = 6;
	Landed = 7;

    --Died = 253;
	StaggerStart = 254;
	StaggerStop = 255;
}


-- Normal constructor
-- @param base <Model>
-- @param initParams <table> == nil, convenience for EntityNoid subclasses
-- @returns <EntityNoid>
function EntityNoid.new(base, initParams)
	local self = setmetatable(Entity.new(base, initParams), EntityNoid)
	local StateMachine = self.StateMachine
	local States = StateMachine.States

	-- Extend StateMachine as necessary for various entity behaviors
    -- Add transitions above as needed
	StateMachine:AddState("Moving")
	StateMachine:AddState("Jumping")
	StateMachine:AddState("Falling")
	StateMachine:AddState("Staggering")
    --StateMachine:AddState("Knocked")
    --StateMachine:AddState("Dead")

	StateMachine:AddTransition(Transitions.MoveStart, States.Idle, States.Moving, function() 
		return self.Base.Humanoid.MoveDirection.Magnitude > 0.5 
	end)
	StateMachine:AddTransition(Transitions.MoveStop, States.Moving, States.Idle, function() 
		return self.Base.Humanoid.MoveDirection.Magnitude < 0.5 
	end)

	StateMachine:AddTransition(Transitions.MoveJump, States.Moving, States.Jumping, nil)
	StateMachine:AddTransition(Transitions.Jump, States.Idle, States.Jumping, nil)

	StateMachine:AddTransition(Transitions.Falling1, States.Idle, States.Falling, function()
		return self.Base.Humanoid.FloorMaterial == Enum.Material.Air and self.Base.PrimaryPart.Velocity.Y < 1
	end)
	StateMachine:AddTransition(Transitions.Falling2, States.Moving, States.Falling, function()
		return self.Base.Humanoid.FloorMaterial == Enum.Material.Air and self.Base.PrimaryPart.Velocity.Y < 1
	end)
	StateMachine:AddTransition(Transitions.Falling3, States.Jumping, States.Falling, function()
		return self.Base.PrimaryPart.Velocity.Y < 1
	end)
	
	StateMachine:AddTransition(Transitions.Landed, States.Falling, States.Idle, function()
		return self.Base.Humanoid.FloorMaterial ~= Enum.Material.Air
	end)

	StateMachine:AddTransition(
        Transitions.StaggerStart,
        States.Any,
        States.Staggering,
        nil,
        function()
            self:UpdateMovement()
        end)
    StateMachine:AddTransition(
        Transitions.StaggerStop,
        States.Staggering,
        States.Any,
        nil,
        function()
            self:UpdateMovement()
        end)

    self:AttachAttributes()

    if (self.LocalPlayer == nil) then
        self.Randoms = {
            Critical = Random.new();
            Attack = Random.new();
        }
    end

	return self
end


-- Applies attributes for auto-replication convenience
-- (Much better than the old "EntityChanged" communication via Network)
-- Unfortunately, will still need "EntityStatusApplied" and "EntityStatusRemoved"
-- @param base <Model>
function Entity:AttachAttributes()
    self.Base:SetAttribute("MaxHealth", 50)
    self.Base:SetAttribute("Health", 50)
    self.Base:SetAttribute("MaxEnergy", 20)
    self.Base:SetAttribute("Energy", 20)
end


function EntityNoid:CanJump()
	return self.Base.Humanoid.FloorMaterial ~= Enum.Material.Air
		and self.Base.PrimaryPart.Velocity.Y < 5
		and (self.StateMachine.CurrentState == self.StateMachine.States.Idle
			or self.StateMachine.CurrentState == self.StateMachine.States.Moving)
end


function EntityNoid:Jump()
	self.StateMachine:Transition(Transitions.Jump)
	self.Base.Humanoid.Jump = true
	--self.Root:ApplyImpulse(Vector3.new(0, 50, 0) * self.Root.AssemblyMass)
end


function EntityNoid:UpdateMovement()
    if (not EntityModifiers:IsManaging(self.Base)) then return end

    local states = self.StateMachine.States
    local state = self.StateMachine.CurrentState

    if (state == states.Staggering) then
        self.Base.Humanoid.WalkSpeed = 0
        self.Base.Humanoid.JumpPower = 0
    else
        self.Base.Humanoid.WalkSpeed = EntityModifiers:CalculateTarget(self.Base, "Walkspeed")
        self.Base.Humanoid.JumpPower = EntityModifiers:CalculateTarget(self.Base, "JumpPower")
    end
end


-- Go through all transitions' conditions to check which state we 
--	should be in
function EntityNoid:UpdateState()
	self.StateMachine:UpdateState()
end


-- Retrieves attack values
-- @returns <table>
function EntityNoid:GetOffensiveValues()
    return {
        Melee = 0;
        Ranged = 0;
        Arcane = 0;
    }
end


-- Retrieves offensive multipliers
-- @returns <table>
function EntityNoid:GetOffensiveMultipliers()
    return {
        Melee = 1.25;
        Ranged = 1;
        Arcane = 1;
    }
end


-- Calculates critical rate
-- @returns <number> [0, 0.75]
function EntityNoid:GetCriticalRate()
    return 1
end


-- Calculates critical multiplier
-- @returns <number> [1.25, 3]
function EntityNoid:GetCriticalMultiplier()
    return 1.25
end


-- Calculates defense values
-- @returns <table>
function EntityNoid:GetDefensiveValues()
    return {
        Melee = 2;
        Ranged = 2;
        Arcane = 2;
    }
end


-- Retrieves defensive multipliers
-- @returns <table>
function EntityNoid:GetDefensiveMultipliers()
    return {
        Melee = 1;
        Ranged = 1;
        Arcane = 1;
    }
end


-- Calculates defense against critical damage
-- @returns <number> [0, 0.75]
function EntityNoid:GetCriticalDefense()
    return 0
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityNoid end


-- Client constructor variant, adds on data that only the client needs
local new = EntityNoid.new
function EntityNoid.new(...)
	local self = new(...)
	local asset = AssetService:GetAsset(self.InitParams._SkinID)

	self.SkinAsset = asset

	self._LastOpacity = Entity.Enums.Opacity.Opaque;
	self._Opacity = Entity.Enums.Opacity.Opaque;

	self.Root = self.Base.PrimaryPart

	return self
end


-- Renders this EntityNoid
function EntityNoid:Draw(dt)
    if (self.Skin == nil) then
		self.Skin = false -- Blocks redundant call mid asset downloads below
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

		-- If we were hidden (Skin = false -> nil) we cancel the draw here
		if (self.Skin == false) then
			self.Skin = skin
			self._Parts = parts
		end
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

    superDestroy(self)
end


return EntityNoid
