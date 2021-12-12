-- EntityNoid class
--
-- Dynamese (Enduo)
-- 12.11.2021



local Entity = require(script.Parent.Entity)
local EntityNoid = {}
EntityNoid.__index = EntityNoid
setmetatable(EntityNoid, Entity)

-- Normal constructor
-- @param base <Model>
-- @param initialParams <table> == nil, convenience for EntityNoid subclasses
-- @returns <EntityNoid>
function EntityNoid.new(base, initialParams)
	local self = Entity.new(base, initialParams)
	local StateMachine = self.Classes.StateMachine.new("Idle")
	local States = StateMachine.States

	StateMachine:AddState("Jogging")
	StateMachine:AddState("Running")
	StateMachine:AddState("Attacking")
	StateMachine:AddState("Staggering")

	StateMachine:AddTransition(States.Any, States.Staggering)

	StateMachine:AddTransition(States.Idle, States.Jogging)
	StateMachine:AddTransition(States.Idle, States.Attacking)

	StateMachine:AddTransition(States.Jogging, States.Idle)
	StateMachine:AddTransition(States.Jogging, States.Running)
	StateMachine:AddTransition(States.Jogging, States.Attacking)

	StateMachine:AddTransition(States.Running, States.Jogging)
	StateMachine:AddTransition(States.Running, States.Idle)

	StateMachine:AddTransition(States.Attacking, States.Idle)
	StateMachine:AddTransition(States.Attacking, States.Running)

	StateMachine:AddTransition(States.Staggering, States.Idle)

	self.StateMachine = StateMachine

	return setmetatable(self, EntityNoid)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityNoid end


-- Renders this EntityNoid
function EntityNoid:Draw()
    if (self.Model == nil) then
        local model = self._Asset.Model:Clone()
        local parts = {}

        for _, part in ipairs(model:GetDescendants()) do
            if (part:IsA("BasePart") and part.Transparency < 1) then
                parts[part] = part.Transparency
            end
        end

        model:SetPrimaryPartCFrame(self.Base.PrimaryPart.CFrame)
        model.Parent = self.Base
        self.Modules.WeldUtil:WeldParts(model.PrimaryPart, self.Base.PrimaryPart)
        self.Model = model
        self._Parts = parts
    end
end


-- Sets how transparent/opaque to draw this EntityNoid
function EntityNoid:SetOpacity()
    error("Cannot change opacity")
end


-- Removes the model
function EntityNoid:Hide()
    self.Model:Destroy()
    self.Model = nil
    self._Parts = nil
end


-- Destroys this instance and its physical model along with it
local superDestroy = Entity.Destroy
function EntityNoid:Destroy()
    self:Hide()
    superDestroy()
end


return EntityNoid
