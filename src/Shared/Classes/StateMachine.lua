local Engine = _G.Deep
local DeepObject = require(script.Parent.DeepObject)
local StateMachine = {}
StateMachine.__index = StateMachine
setmetatable(StateMachine, DeepObject)

local TableUtil


function StateMachine.new(initialStateName)
	TableUtil = TableUtil or Engine.Modules.TableUtil
	local self = setmetatable(DeepObject.new({
		States = {Any = -1};
		NumStates = 0;
		CurrentState = 0;
		
		Transitions = nil;
	}), StateMachine)

	self:AddSignal("StateChanged")
	self.Transitions = self.Classes.IndexedMap.new()
	self:AddState(initialStateName)

	return self
end


-- TODO: THIS DOESN'T WORK WITH NEW "UPDATESTATE" TYPE MACHINE
-- function StateMachine.fromStateMapping(mappingTable)
-- 	local machine = StateMachine.new(mappingTable.InitialState)

-- 	for _, state in ipairs(mappingTable.States) do
-- 		machine:AddState(state)
-- 	end

-- 	for _, transition in ipairs(mappingTable.Transitions) do
-- 		machine:AddTransition(machine.States[transition[1]], machine.States[transition[2]])
-- 	end

-- 	return machine
-- end


function StateMachine:AddState(stateName)
	self.States[stateName] = self.NumStates
	self.NumStates += 1
end


function StateMachine:AddTransition(name, from, to, qualifier)
	assert(self.Transitions:Get(name) == nil, "Redundant transition definition: " .. name)
	print("Add", name, from, to, qualifier)
	self.Transitions:Add(name, {
		FromState = from;
		ToState = to;
		Qualifier = qualifier;
	})
end


function StateMachine:GetStateNameFromEnum(stateEnum)
	for name, enum in pairs(self.States) do
		if (enum == stateEnum) then
			return name
		end
	end

	return nil
end


function StateMachine:GetState()
	return self:GetStateNameFromEnum(self.CurrentState)
end


-- @param transitionName <string>
-- @returns true if we may transition (nil qualifier means manual transition ONLY)
function StateMachine:TransitionQualifies(transitionName)
	local transition = self.Transitions:Get(transitionName)
	assert(transition, "Invalid transition: " .. transitionName)
	return transition.Qualifier == nil or transition.Qualifier()
end


function StateMachine:Transition(transitionName, ...)
	local currState = self.CurrentState
	local transition = self.Transitions:Get(transitionName)

	assert(currState ~= transition.ToState, "Circular transition: " .. transitionName)

	assert(self:TransitionQualifies(transitionName),
		string.format(
			"Invalid transition from %s to %s!", 
			self:GetStateNameFromEnum(currState), 
			self:GetStateNameFromEnum(transition.ToState)
		)
	)

	self.CurrentState = transition.ToState
	self.StateChanged:Fire(currState, transition.ToState, transitionName, ...)
end


function StateMachine:UpdateState()
	local currState = self.CurrentState

	for transitionName, transition in self.Transitions:KeyIterator() do
		-- If we do not have a qualifier, this is not an automatically transitioned state
		-- If we are not currently in the fromstate, disqualify immediately
		-- If we are already in the tostate, we don't need to check this transition
		--if (transitionName == 5) then print(transition.Qualifier == nil, currState ~= transition.FromState, currState == transition.ToState) end
		if (transition.Qualifier == nil 
			or currState ~= transition.FromState 
			or currState == transition.ToState) then continue end

		if (self:TransitionQualifies(transitionName)) then
			self:Transition(transitionName)
		end
	end
end


return StateMachine
