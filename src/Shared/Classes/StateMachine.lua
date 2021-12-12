local Engine = _G.Deep
local DeepObject = require(script.Parent.DeepObject)
local StateMachine = {}
StateMachine.__index = StateMachine
setmetatable(StateMachine, DeepObject)

local TableUtil


function StateMachine.new(initialStateName)
	TableUtil = TableUtil or Engine.Modules.TableUtil
	local self = DeepObject.new({
		States = {Any = -1};
		NumStates = 0;
		CurrentState = 0;
		
		Transitions = nil;
	})

	self:AddSignal("StateChanged")
	self.Transitions = self.Classes.IndexedMap.new()
	self.Transitions:Add(self.States.Any, {})

	setmetatable(self, StateMachine)
	self:AddState(initialStateName)

	return self
end


function StateMachine.fromStateMapping(mappingTable)
	local machine = StateMachine.new(mappingTable.InitialState)

	for _, state in ipairs(mappingTable.States) do
		machine:AddState(state)
	end

	for _, transition in ipairs(mappingTable.Transitions) do
		machine:AddTransition(machine.States[transition[1]], machine.States[transition[2]])
	end

	return machine
end


function StateMachine:AddState(stateName)
	self.Transitions:Add(self.NumStates, {})
	self.States[stateName] = self.NumStates
	self.NumStates += 1
end


function StateMachine:AddTransition(from, to)
	local transitionsFrom = self.Transitions:Get(from)
	table.insert(transitionsFrom, to)
	table.sort(transitionsFrom)
end


function StateMachine:GetStateNameFromEnum(stateEnum)
	for name, enum in pairs(self.States) do
		if (enum == stateEnum) then
			return name
		end
	end

	return nil
end


function StateMachine:CanTransitionTo(to)
	return table.find(self.Transitions:Get(self.CurrentState), to) ~= nil
		or table.find(self.Transitions:Get(self.States.Any), to) ~= nil
end


function StateMachine:TransitionTo(to, ...)
	local currState = self.CurrentState

	assert(self:CanTransitionTo(to),
		string.format(
			"Invalid transition from %s to %s!", 
			self:GetStateNameFromEnum(currState), 
			self:GetStateNameFromEnum(to)
		)
	)

	self.CurrentState = to
	self.StateChanged:Fire(currState, to, ...)
end


return StateMachine
