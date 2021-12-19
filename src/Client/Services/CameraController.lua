local CameraController = {Priority = 50}
local MetronomeService

local InputManager, EntityService
local CurrentLook, LocalPlayer, CurrentEntity
local BindingMaid, CamJobID


local function UpdateCamera(_dt)
	if (CurrentEntity == nil) then return end

	print(CurrentLook.Yaw, CurrentLook.Pitch, CurrentLook.Zoom)
end


local function ModPitchYaw(object, _proc)
	CurrentLook.Yaw += object.Delta.X
	CurrentLook.Pitch += object.Delta.Y
end


local function ModZoom(object, proc)
	if (proc) then return end

	CurrentLook.Zoom += object.Position.Z
end


function CameraController:Enable(bool)
	if (bool) then
		BindingMaid:GiveTasks(
			InputManager:BindAction(Enum.UserInputType.MouseMovement, "PitchYawCamera", ModPitchYaw, nil),
			InputManager:BindAction(Enum.UserInputType.MouseWheel, "ZoomCamera", ModZoom, nil)			
		)
		CamJobID = MetronomeService:BindToFrequency(60, UpdateCamera)
	else
		if (CamJobID ~= nil) then
			BindingMaid:DoCleaning()
			MetronomeService:Unbind(CamJobID)
			CamJobID = nil
		end
	end
end


function CameraController:EngineInit()
	MetronomeService = self.Services.MetronomeService
	InputManager = self.Services.InputManager
	EntityService = self.Services.EntityService

	BindingMaid = self.Classes.Maid.new()

	self.FirstEntityReady = self.Classes.Signal.new()

	CurrentLook = {
		Yaw = 0;
		Pitch = 0;
		Zoom = 3;
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


function CameraController:EngineStart()
	LocalPlayer = self.LocalPlayer
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

	if (CurrentEntity == nil) then
		self.FirstEntityReady:Wait()
	end
	
	CameraController:Enable(true)
end


return CameraController