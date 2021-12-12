local CharacterController = {Priority = 50}


local MetronomeService

local CurrentMove, InputManager
local LocalPlayer, CurrentEntity
local MoveJobID


local function UpdateMove(dt)
	LocalPlayer:Move(Vector3.new(
		CurrentMove.Right,
		0,
		CurrentMove.Forward
	), true)
end


local function ModDir(dir, coeff)
	return function(object, _proc)
		CurrentMove[dir] += coeff * (object.UserInputState == Enum.UserInputState.Begin and 1 or -1)
	end
end


local function TryJump(object, _proc)
	local pivot = CharacterController.LocalPlayer.Character.PrimaryPart
	pivot:ApplyImpulse(Vector3.new(
		0,
		pivot.AssemblyMass * 50,
		0
	))
end


function CharacterController:TrySetState(entityState, ...)
	
end


function CharacterController:Enable(bool)
	if (bool) then
		MoveJobID = MetronomeService:BindToFrequency(60, UpdateMove)
	else
		if (MoveJobID ~= nil) then
			MetronomeService:Unbind(MoveJobID)
			MoveJobID = nil
		end
	end
end


function CharacterController:EngineInit()
	MetronomeService = self.Services.MetronomeService
	InputManager = self.Services.InputManager

	CurrentMove = {
		Forward = 0;
		Right = 0;
	}

	InputManager:BindAction(Enum.KeyCode.W, "ModForward", ModDir("Forward", -1), nil)
	InputManager:BindAction(Enum.KeyCode.A, "ModRight", ModDir("Right", -1), nil)
	InputManager:BindAction(Enum.KeyCode.S, "ModForwardInverse", ModDir("Forward", 1), nil)
	InputManager:BindAction(Enum.KeyCode.D, "ModRightInverse", ModDir("Right", 1), nil)

	InputManager:BindAction(Enum.KeyCode.Space, "Jump", TryJump, Enum.UserInputState.Begin)
end


function CharacterController:EngineStart()
	LocalPlayer = self.LocalPlayer
	require(LocalPlayer.PlayerScripts.PlayerModule):GetControls():Enable(false)
	CharacterController:Enable(true)
end


return CharacterController