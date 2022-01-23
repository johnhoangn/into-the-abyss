-- Entity class, represents an existence to be rendered.
--
-- Dynamese (Enduo)
-- 07.19.2021



local DeepObject = require(script.Parent.DeepObject)
local Entity = {}
Entity.__index = Entity
setmetatable(Entity, DeepObject)

local HttpService, AssetService


-- Normal constructor
-- @param base <Model>
-- @param initParams <table> == nil, convenience for entity subclasses
-- @returns <Entity>
function Entity.new(base, initParams)
	HttpService = HttpService or Entity.RBXServices.HttpService

	assert(base:IsA("Model"), "Base must be a model " .. base:GetFullName())
	assert(base.PrimaryPart ~= nil, "Missing primary part " .. base:GetFullName())

	local self = setmetatable(DeepObject.new({
		_LastPosition = Vector3.new();
		
		InitParams = initParams;
		Base = base;
		UID = initParams.UID or HttpService:GenerateGUID();
	}), Entity)

	if (initParams ~= nil) then
		for k, v in pairs(initParams) do
			self[k] = v
		end
	end

    for _, part in ipairs(base:GetDescendants()) do
        if (part:IsA("BasePart")) then
            part.CollisionGroupId = self.Enums.CollisionGroup.Entity
        end
    end

	self.StateMachine = self.Classes.StateMachine.new("Idle")
	self.StateChanged = self.StateMachine.StateChanged
	self.Attributes = {}

	self:StartAttributeTracker()
    self:AttachAttributes()
	self:AddSignal("HealthChanged")
	self:AddSignal("EnergyChanged")

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


--[[ Code from Nova that isn't used for Abyss
-- Retrieves the position of this entity when centered at REAL ORIGIN
-- @returns <Vector3>
function Entity:RealPosition()
	return Vector2.new(
		self.Base.PrimaryPart.Position.X,
		self.Base.PrimaryPart.Position.Z
	)
end
-- Retrieves the position of this entity relative to the virtual galaxy
-- @returns <Vector3>
function Entity:UniversalPosition()
	assert(self._System ~= nil, "This entity is not part of a solar system")
	return Vector3.new()
end
]]


-- Instead of the above, and while each subclass might compute this differently,
--	we use this:
function Entity:GetPosition()
	local position = nil

	if (self.Base.PrimaryPart ~= nil) then
		position = self.Base.PrimaryPart.Position
		self._LastPosition = position
	end

	return position or self._LastPosition
end


-- Destroys this instance and its physical model along with it
local superDestroy = Entity.Destroy
function Entity:Destroy()
	if (self.Base.PrimaryPart ~= nil) then
		self.Base:Destroy()
		self.Base = nil
	end
	superDestroy(self)
end


-- For consistency
function Entity:UpdateState()
end


-- Health/Energy modifiers
-- @param resource <string>
-- @param delta <number>
-- @param source <string>
function Entity:ChangeResourceVal(resource, delta, source)
	local current = self.Base:GetAttribute(resource)
	local max = self.Base:GetAttribute("Max" .. resource)
	local new = math.clamp(current + delta, 0, max)

	if (new == current) then
		return
	end

	self.Base:SetAttribute(resource, new)
	self[resource .. "Changed"]:Fire(current, new, source)
end
function Entity:Hurt(amt, source)
	self:ChangeResourceVal("Health", -amt, source)
end
function Entity:Heal(amt, source)
	self:ChangeResourceVal("Health", amt, source)
end
function Entity:Drain(amt, source)
	self:ChangeResourceVal("Energy", -amt, source)
end
function Entity:Recover(amt, source)
	self:ChangeResourceVal("Energy", amt, source)
end


-- Binds attribute changes to Entity members
function Entity:StartAttributeTracker()
	self:GetMaid():GiveTask(self.Base.AttributeChanged:Connect(function(attr)
		self.Attributes[attr] = self.Base:GetAttribute(attr)
		self:UpdateState()
	end))
end




-- Retrieves attack values
-- @returns <table>
function Entity:GetOffensiveValues()
    return {
        Melee = 0;
        Ranged = 0;
        Arcane = 0;
    }
end


-- Retrieves offensive multipliers
-- @returns <table>
function Entity:GetOffensiveMultipliers()
    return {
        Melee = 1.25;
        Ranged = 1;
        Arcane = 1;
    }
end


-- Calculates critical rate
-- @returns <number> [0, 0.75]
function Entity:GetCriticalRate()
    return 1
end


-- Calculates critical multiplier
-- @returns <number> [1.25, 3]
function Entity:GetCriticalMultiplier()
    return 1.25
end


-- Calculates defense values
-- @returns <table>
function Entity:GetDefensiveValues()
    return {
        Melee = 2;
        Ranged = 2;
        Arcane = 2;
    }
end


-- Retrieves defensive multipliers
-- @returns <table>
function Entity:GetDefensiveMultipliers()
    return {
        Melee = 1;
        Ranged = 1;
        Arcane = 1;
    }
end


-- Calculates defense against critical damage
-- @returns <number> [0, 0.75]
function Entity:GetCriticalDefense()
    return 0
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return Entity end


-- Client constructor variant, adds on data that only the client needs
local new = Entity.new
function Entity.new(...)
	AssetService = AssetService or Entity.Services.AssetService

	local self = new(...)
	local asset = AssetService:GetAsset(self.InitParams._BaseID)

	self._Asset = asset

	self._LastOpacity = Entity.Enums.Opacity.Opaque;
	self._Opacity = Entity.Enums.Opacity.Opaque;

	self.Root = self.Base.PrimaryPart
	self.Root.Transparency = 1

	return self
end


-- Marks this entity to be exempt or not from purges
-- @param bool, true for exempt
function Entity:MarkPurgeExempt(bool)
	self.PurgeExempt = bool or nil
end


-- Marks this entity to be permanently rendered
-- @param bool, true for always visible
function Entity:MarkMustRender(bool)
	self.MustRender = bool or nil
end


-- Renders this entity
function Entity:Draw()
	error("Entity itself cannot be rendered, maybe you intended to render a subclass?")
end


-- Hides this entity
function Entity:Hide()
	error("Entity itself cannot be hidden, maybe you intended to render a subclass?")
end


-- Sets how transparent/opaque to draw this entity
function Entity:SetOpacity()
	error("Entity itself cannot have its opacity changed, maybe you intended to edit a subclass?")
end


return Entity
