local CharacterController = {Priority = 50}


local MetronomeService

local CurrentMove, InputManager, EntityService
local LocalPlayer, CurrentEntity
local BindingMaid, MoveJobID


local function UpdateMove(_dt)
	if (CurrentEntity == nil) then return end
	LocalPlayer:Move(Vector3.new(
		CurrentMove.Right,
		0,
		CurrentMove.Forward
	), true)

	if (CurrentMove.Jump and CurrentEntity:CanJump()) then
		CurrentEntity:Jump()
	end
end


local function ModDir(dir, coeff)
	return function(object, proc)
		CurrentMove[dir] += coeff * (object.UserInputState == Enum.UserInputState.Begin and not proc and 1 or -1)
	end
end


local function ModJump(object, _proc)
	CurrentMove.Jump = object.UserInputState == Enum.UserInputState.Begin
end


function CharacterController:CanJump()
	return CurrentEntity ~= nil 
		and CurrentEntity:CanJump()
end


function CharacterController:Enable(bool)
	if (bool) then
		BindingMaid:GiveTasks(
			InputManager:BindAction(Enum.KeyCode.W, "ModForward", ModDir("Forward", -1), nil),
			InputManager:BindAction(Enum.KeyCode.A, "ModRight", ModDir("Right", -1), nil),
			InputManager:BindAction(Enum.KeyCode.S, "ModForwardInverse", ModDir("Forward", 1), nil),
			InputManager:BindAction(Enum.KeyCode.D, "ModRightInverse", ModDir("Right", 1), nil),

			InputManager:BindAction(Enum.KeyCode.Space, "Jump", ModJump, nil)
		)
		MoveJobID = MetronomeService:BindToFrequency(60, UpdateMove)
	else
		if (MoveJobID ~= nil) then
			BindingMaid:DoCleaning()
			MetronomeService:Unbind(MoveJobID)
			MoveJobID = nil
		end
	end
end


function CharacterController:EngineInit()
	MetronomeService = self.Services.MetronomeService
	InputManager = self.Services.InputManager
	EntityService = self.Services.EntityService

	BindingMaid = self.Classes.Maid.new()

	self.FirstEntityReady = self.Classes.Signal.new()

	CurrentMove = {
		Forward = 0;
		Right = 0;
		Jump = false;
	}

	EntityService.EntityCreated:Connect(function(base)
		if (base == self.LocalPlayer.Character) then
			CurrentEntity = EntityService:GetEntity(base)
			self.FirstEntityReady:Fire()
		end
	end)
	EntityService.EntityDestroyed:Connect(function(base)
		if (base == CurrentEntity.Base) then
			CurrentEntity = nil
		end
	end)
end


function CharacterController:EngineStart()
	LocalPlayer = self.LocalPlayer

	if (CurrentEntity == nil) then
		self.FirstEntityReady:Wait()
	end

	CharacterController:Enable(true)
end


return CharacterController