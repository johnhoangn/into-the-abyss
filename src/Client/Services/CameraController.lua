-- Spring based camera controller
-- Dynamese(Enduo)
-- 12.19.2021



local CameraController = {Priority = 50}
local MetronomeService


local RAD = math.rad
local CLAMP = math.clamp
local MIN_PITCH = -89
local MAX_PITCH = 89
local MIN_ZOOM = 1
local MAX_ZOOM = 20


local InputManager, EntityService, CollectionService
local TargetLook, Springs, States
local CurrentEntity, Camera
local BindingMaid, CamJobID
local RayParams


-- Looks for obstacles and returns the occluded cframe
-- @param subjectPos <Vector3>
-- @param desiredCFrame <CFrame>
local function Occlude(subjectPos, desiredCFrame)
	local towardsDesired = (desiredCFrame.Position - subjectPos)
	local maxLen = towardsDesired.Magnitude
	local ignore = CollectionService:GetTagged("Entity")
	local origin = subjectPos
	local rayResults

	towardsDesired = towardsDesired.Unit
	RayParams.FilterDescendantsInstances = ignore
	rayResults = workspace:Raycast(origin, towardsDesired * maxLen, RayParams)

	while rayResults and (rayResults.Instance.Transparency > 0.3 or not rayResults.Instance.CanCollide) and maxLen > 0 do
		maxLen -= (rayResults.Position - origin).Magnitude
		table.insert(ignore, rayResults.Instance)
		RayParams.FilterDescendantsInstances = ignore
		origin = rayResults.Position
		rayResults = workspace:Raycast(origin, towardsDesired * maxLen, RayParams)
	end

	if not rayResults then
		return desiredCFrame
	else
		local weirdSignThing = ((rayResults.Position - subjectPos).Magnitude < (desiredCFrame.Position - subjectPos).Magnitude) and -1 or 1
		local intersectVector = (rayResults.Position - desiredCFrame.Position)
		intersectVector = intersectVector - (intersectVector.Unit * 2) * weirdSignThing
		local occlude = desiredCFrame:VectorToObjectSpace(intersectVector)

		return desiredCFrame * CFrame.new(occlude.X, occlude.Y, occlude.Z)
	end
end


-- Called every heartbeat
local function UpdateCamera(dt)
	if (CurrentEntity == nil) then return end

	for lookField, spring in pairs(Springs) do
		spring:Step(dt)
		spring:SetGoal(TargetLook[lookField])
	end

	local subjectPosition = CurrentEntity:GetPosition()
	local desiredCFrame = CFrame.new(subjectPosition)
		-- Shake yaw and look yaw
		* CFrame.Angles(0, RAD(Springs.OriginYaw.x + Springs.Yaw.x), 0)

		-- Shake pitch and look pitch
		* CFrame.Angles(RAD(Springs.OriginPitch.x + Springs.Pitch.x), 0, 0)

		-- Shake offset and look offset
		* CFrame.new(
			States.Shoulder * (Springs.OriginX.x + Springs.OffsetX.x), 
			Springs.OriginY.x + Springs.OffsetY.x, 
			Springs.Zoom.x
		)

	Camera.CFrame = Occlude(subjectPosition, desiredCFrame)
    Camera.Focus = Camera.CFrame
end


-- Handles both pitch and yaw
-- Currently only supports MouseKB
local function ModPitchYaw(object, _proc)
	TargetLook.Yaw -= object.Delta.X * 0.4
	TargetLook.Pitch = CLAMP(TargetLook.Pitch - object.Delta.Y * 0.4, MIN_PITCH, MAX_PITCH)
end


-- Handles zooming
-- Currently only supports MouseKB
local function ModZoom(object, proc)
	if (proc) then return end
	TargetLook.Zoom = CLAMP(TargetLook.Zoom - object.Position.Z * 1.5, MIN_ZOOM, MAX_ZOOM)
end


-- Toggles mouse lock
-- TODO: Consider moving this to InputManager?
local function ToggleMouse(object, proc)
	if (object.UserInputState ~= Enum.UserInputState.Begin or proc) then
		return
	end

	States.MouseLocked = not States.MouseLocked
	CameraController.RBXServices.UserInputService.MouseBehavior = States.MouseLocked
		and Enum.MouseBehavior.LockCenter
		or Enum.MouseBehavior.Default
end


-- Manual panning of the camera when not mouse locked
local function PanCamera(object, proc)
	if (States.MouseLocked) then
		return
	end

	CameraController.RBXServices.UserInputService.MouseBehavior = 
		(not proc and object.UserInputState == Enum.UserInputState.Begin)
			and Enum.MouseBehavior.LockCurrentPosition
			or Enum.MouseBehavior.Default
end


-- Flips which side the camera is on
local function SwapShoulder(object, _proc)
	States.Shoulder *= -1
end


-- Throws the origin springs offcenter... somehow...
-- @param bias <number> direction/angle bias?
-- @param magnitude <number> how big of a shake
function CameraController:Shake(bias, magnitude)
end


-- Enable/Disable
function CameraController:Enable(bool)
	if (bool) then
		BindingMaid:GiveTasks(
			InputManager:BindAction(Enum.UserInputType.MouseMovement, "PitchYawCamera", ModPitchYaw, nil),
			InputManager:BindAction(Enum.UserInputType.MouseWheel, "ZoomCamera", ModZoom, nil),
			InputManager:BindAction(Enum.UserInputType.MouseButton2, "PanCamera", PanCamera, nil),
			
			InputManager:BindAction(Enum.KeyCode.Z, "ToggleMouse", ToggleMouse, Enum.UserInputState.Begin),
			InputManager:BindAction(Enum.KeyCode.V, "SwapShoulder", SwapShoulder, Enum.UserInputState.Begin)
		)

		CamJobID = MetronomeService:BindToHeartbeat(UpdateCamera)
	else
		if (CamJobID ~= nil) then
			BindingMaid:DoCleaning()
			MetronomeService:UnbindFromHeartbeat(CamJobID)
			CamJobID = nil
		end
	end
end


function CameraController:EngineInit()
	MetronomeService = self.Services.MetronomeService
	InputManager = self.Services.InputManager
	EntityService = self.Services.EntityService
	CollectionService = self.RBXServices.CollectionService

	Camera = workspace.CurrentCamera
	RayParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Blacklist

	BindingMaid = self.Classes.Maid.new()

	self.FirstEntityReady = self.Classes.Signal.new()

	TargetLook = {
		OriginX = 0;
		OriginY = 0;
		OriginYaw = 0;
		OriginPitch = 0;

		OffsetX = 2;
		OffsetY = 1;
		Yaw = 0;
		Pitch = 0;
		Zoom = 3;
	}

	Springs = {
		OriginX = self.Classes.ConstrainedSpring.new(2, 2, -3, 3);
		OriginY = self.Classes.ConstrainedSpring.new(2, 1, -3, 3);
		OriginYaw = self.Classes.Spring.new(2, 0);
		OriginPitch = self.Classes.ConstrainedSpring.new(2, -30, MIN_PITCH, MAX_PITCH);

		OffsetX = self.Classes.ConstrainedSpring.new(2, 2, -3, 3);
		OffsetY = self.Classes.ConstrainedSpring.new(2, 1, -3, 3);
		Yaw = self.Classes.Spring.new(60, 0);
		Pitch = self.Classes.ConstrainedSpring.new(60, -30, MIN_PITCH, MAX_PITCH);
		Zoom = self.Classes.ConstrainedSpring.new(4, 8, MIN_ZOOM, MAX_ZOOM);
	}

	States = {
		MouseLocked = false;
		Shoulder = 1;
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
	if (CurrentEntity == nil) then
		self.FirstEntityReady:Wait()
	end

	Camera.CameraType = Enum.CameraType.Scriptable
	CameraController:Enable(true)
end


return CameraController


--[[
	Sensitivities(?) ripped from corescripts
	local NAV_GAMEPAD_SPEED  = Vector3.new(1, 1, 1)
	local NAV_KEYBOARD_SPEED = Vector3.new(1, 1, 1)
	local PAN_MOUSE_SPEED    = Vector2.new(1, 1)*(pi/64)
	local PAN_GAMEPAD_SPEED  = Vector2.new(1, 1)*(pi/8)
	local FOV_WHEEL_SPEED    = 1.0
	local FOV_GAMEPAD_SPEED  = 0.25
	local NAV_ADJ_SPEED      = 0.75
	local NAV_SHIFT_MUL      = 0.25
	*0.4
]]