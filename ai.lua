-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On + Camlock V1 & V2 System

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Only run on mobile
if not UserInputService.TouchEnabled then
	return
end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character, humanoid, hrp
local isDisabled = false

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
	isDisabled = false
	
	if humanoid then 
		humanoid.AutoRotate = true 
		
		-- Detect ragdoll/grab through state changes
		humanoid.StateChanged:Connect(function(oldState, newState)
			if newState == Enum.HumanoidStateType.Physics or 
			   newState == Enum.HumanoidStateType.Ragdoll or
			   newState == Enum.HumanoidStateType.FallingDown or
			   newState == Enum.HumanoidStateType.PlatformStanding then
				isDisabled = true
			elseif newState == Enum.HumanoidStateType.Running or
			       newState == Enum.HumanoidStateType.Landed or
			       newState == Enum.HumanoidStateType.Jumping then
				isDisabled = false
			end
		end)
		
		-- Detect PlatformStand changes (common grab method)
		humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
			if humanoid.PlatformStand then
				isDisabled = true
			else
				isDisabled = false
			end
		end)
		
		-- Detect Sit changes (some grabs use this)
		humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
			if humanoid.Sit then
				isDisabled = true
			else
				isDisabled = false
			end
		end)
	end
	
	-- Monitor for welds/constraints added to HRP (grab detection)
	if hrp then
		hrp.ChildAdded:Connect(function(child)
			if child:IsA("Weld") or child:IsA("WeldConstraint") or 
			   child:IsA("AlignPosition") or child:IsA("AlignOrientation") or
			   child:IsA("RopeConstraint") then
				isDisabled = true
				
				-- Re-enable when constraint is removed
				child.AncestryChanged:Connect(function()
					if not child:IsDescendantOf(game) then
						task.wait(0.5)
						isDisabled = false
					end
				end)
			end
		end)
	end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "LockOnUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Character Lock Button
local charLockBtn = Instance.new("TextButton")
charLockBtn.Size = UDim2.new(0, 110, 0, 50)
charLockBtn.Position = UDim2.new(0.06, 0, 0.8, 0)
charLockBtn.Text = "CHAR LOCK"
charLockBtn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
charLockBtn.TextColor3 = Color3.new(1, 1, 1)
charLockBtn.Font = Enum.Font.GothamBold
charLockBtn.TextSize = 16
charLockBtn.Active = true
charLockBtn.Parent = gui

local charCorner = Instance.new("UICorner")
charCorner.CornerRadius = UDim.new(0, 8)
charCorner.Parent = charLockBtn

-- Status indicator for character lock
local charDot = Instance.new("Frame")
charDot.Size = UDim2.new(0, 8, 0, 8)
charDot.Position = UDim2.new(1, -12, 0, 4)
charDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
charDot.BorderSizePixel = 0
charDot.Parent = charLockBtn

local charDotCorner = Instance.new("UICorner")
charDotCorner.CornerRadius = UDim.new(0.5, 0)
charDotCorner.Parent = charDot

-- Camlock Button
local camLockBtn = Instance.new("TextButton")
camLockBtn.Size = UDim2.new(0, 110, 0, 50)
camLockBtn.Position = UDim2.new(0.06, 120, 0.8, 0)
camLockBtn.Text = "CAM LOCK"
camLockBtn.BackgroundColor3 = Color3.fromRGB(206, 137, 36)
camLockBtn.TextColor3 = Color3.new(1, 1, 1)
camLockBtn.Font = Enum.Font.GothamBold
camLockBtn.TextSize = 16
camLockBtn.Active = true
camLockBtn.Parent = gui

local camCorner = Instance.new("UICorner")
camCorner.CornerRadius = UDim.new(0, 8)
camCorner.Parent = camLockBtn

-- Camlock V2 Button (STRAFE MODE)
local camLockV2Btn = Instance.new("TextButton")
camLockV2Btn.Size = UDim2.new(0, 110, 0, 50)
camLockV2Btn.Position = UDim2.new(0.06, 240, 0.8, 0)
camLockV2Btn.Text = "CAM V2"
camLockV2Btn.BackgroundColor3 = Color3.fromRGB(36, 206, 137)
camLockV2Btn.TextColor3 = Color3.new(1, 1, 1)
camLockV2Btn.Font = Enum.Font.GothamBold
camLockV2Btn.TextSize = 16
camLockV2Btn.Active = true
camLockV2Btn.Parent = gui

local camV2Corner = Instance.new("UICorner")
camV2Corner.CornerRadius = UDim.new(0, 8)
camV2Corner.Parent = camLockV2Btn

-- Draggable (all three buttons move together)
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
	local delta = input.Position - dragStart
	charLockBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
		startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	camLockBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X + 120,
		startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	camLockV2Btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X + 240,
		startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

charLockBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = charLockBtn.Position
		dragInput = input
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

camLockBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = charLockBtn.Position
		dragInput = input
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

camLockV2Btn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = charLockBtn.Position
		dragInput = input
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input == dragInput then updateDrag(input) end
end)

-- Lock state
local MAX_DIST = 100
local charLockTarget, camLockTarget, camLockV2Target
local lockBillboard

local function detachBillboard()
	if lockBillboard then
		lockBillboard:Destroy()
		lockBillboard = nil
	end
end

local function attachBillboard(model, color)
	detachBillboard()
	local targetHrp = model:FindFirstChild("HumanoidRootPart")
	if not targetHrp then return end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 120, 0, 40)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = targetHrp
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "LOCKED"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.Parent = bb
	lockBillboard = bb
end

local function isValidTarget(model)
	if not model or not model:IsA("Model") then return false end
	local hum = model:FindFirstChildWhichIsA("Humanoid")
	local part = model:FindFirstChild("HumanoidRootPart")
	if not hum or not part or hum.Health <= 0 then return false end
	if model == character then return false end
	if Players:GetPlayerFromCharacter(model) == player then return false end
	return true
end

local function getNearestTarget()
	if not hrp then return end
	local nearest, dist = nil, MAX_DIST
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player and pl.Character and isValidTarget(pl.Character) then
			local d = (hrp.Position - pl.Character.HumanoidRootPart.Position).Magnitude
			if d < dist then
				dist = d
				nearest = pl.Character
			end
		end
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and isValidTarget(obj) then
			local targetHrp = obj:FindFirstChild("HumanoidRootPart")
			if targetHrp then
				local d = (hrp.Position - targetHrp.Position).Magnitude
				if d < dist then
					dist = d
					nearest = obj
				end
			end
		end
	end
	return nearest
end

local function unlockChar()
	charLockTarget = nil
	if humanoid then humanoid.AutoRotate = true end
	charLockBtn.Text = "CHAR LOCK"
	charLockBtn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
	if not camLockTarget and not camLockV2Target then detachBillboard() end
end

local function unlockCam()
	camLockTarget = nil
	camLockBtn.Text = "CAM LOCK"
	camLockBtn.BackgroundColor3 = Color3.fromRGB(206, 137, 36)
	if not charLockTarget and not camLockV2Target then detachBillboard() end
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function unlockCamV2()
	camLockV2Target = nil
	camLockV2Btn.Text = "CAM V2"
	camLockV2Btn.BackgroundColor3 = Color3.fromRGB(36, 206, 137)
	if not charLockTarget and not camLockTarget then detachBillboard() end
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
			humanoid.AutoRotate = true
		end
	end
end

-- Character Lock Button
charLockBtn.Activated:Connect(function()
	if charLockTarget then
		unlockChar()
	else
		local t = getNearestTarget()
		if t then
			charLockTarget = t
			if humanoid then humanoid.AutoRotate = false end
			attachBillboard(t, Color3.fromRGB(255, 80, 80))
			charLockBtn.Text = "UNLOCK"
			charLockBtn.BackgroundColor3 = Color3.fromRGB(206, 36, 36)
		else
			charLockBtn.Text = "NO TARGET"
			task.delay(1, function()
				if not charLockTarget then 
					charLockBtn.Text = "CHAR LOCK" 
				end
			end)
		end
	end
end)

-- Camlock Button
camLockBtn.Activated:Connect(function()
	if camLockTarget then
		unlockCam()
	else
		local t = getNearestTarget()
		if t then
			camLockTarget = t
			attachBillboard(t, Color3.fromRGB(80, 255, 80))
			camLockBtn.Text = "UNLOCK"
			camLockBtn.BackgroundColor3 = Color3.fromRGB(36, 206, 36)
		else
			camLockBtn.Text = "NO TARGET"
			task.delay(1, function()
				if not camLockTarget then 
					camLockBtn.Text = "CAM LOCK" 
				end
			end)
		end
	end
end)

-- Camlock V2 Button (STRAFE MODE)
camLockV2Btn.Activated:Connect(function()
	if camLockV2Target then
		unlockCamV2()
	else
		local t = getNearestTarget()
		if t then
			camLockV2Target = t
			if humanoid then humanoid.AutoRotate = false end
			attachBillboard(t, Color3.fromRGB(80, 255, 255))
			camLockV2Btn.Text = "UNLOCK"
			camLockV2Btn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
		else
			camLockV2Btn.Text = "NO TARGET"
			task.delay(1, function()
				if not camLockV2Target then 
					camLockV2Btn.Text = "CAM V2" 
				end
			end)
		end
	end
end)

-- Update status indicator
spawn(function()
	while true do
		wait(0.1)
		if isDisabled then
			charDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
		else
			charDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
		end
	end
end)

-- Character Rotation loop (ORIGINAL)
RunService.RenderStepped:Connect(function()
	if charLockTarget and hrp and humanoid and humanoid.Health > 0 then
		if isDisabled then
			return
		end
		
		if humanoid.PlatformStand or humanoid.Sit then
			return
		end
		
		local targetHRP = charLockTarget:FindFirstChild("HumanoidRootPart")
		local targetHum = charLockTarget:FindFirstChildWhichIsA("Humanoid")
		
		if targetHRP and targetHum and targetHum.Health > 0 then
			pcall(function()
				local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
				hrp.CFrame = CFrame.new(hrp.Position, lookPos)
			end)
		else
			unlockChar()
		end
	end
end)

-- CRITICAL: Force camera type EVERY FRAME (Heartbeat)
RunService.Heartbeat:Connect(function()
	if camLockTarget or camLockV2Target then
		camera.CameraType = Enum.CameraType.Scriptable
	elseif camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end)

-- Camera Lock loop (CONSOLE-STYLE - Normal camlock)
local CAMERA_DISTANCE = 15
local CAMERA_HEIGHT = 3

RunService.RenderStepped:Connect(function()
	if camLockTarget and camera and hrp and humanoid then
		local targetHRP = camLockTarget:FindFirstChild("HumanoidRootPart")
		local targetHum = camLockTarget:FindFirstChildWhichIsA("Humanoid")
		
		if targetHRP and targetHum and targetHum.Health > 0 then
			local playerPos = hrp.Position + Vector3.new(0, CAMERA_HEIGHT, 0)
			local directionToTarget = (targetHRP.Position - playerPos).Unit
			local cameraPosition = playerPos - (directionToTarget * CAMERA_DISTANCE)
			local targetLook = CFrame.new(cameraPosition, targetHRP.Position)
			camera.CFrame = camera.CFrame:Lerp(targetLook, 0.2)
		else
			unlockCam()
		end
	end
end)

-- Camera Lock V2 loop (STRAFE MODE - Character rotates with movement!)
local CAMERA_DISTANCE_V2 = 15
local CAMERA_HEIGHT_V2 = 3

RunService.RenderStepped:Connect(function()
	if camLockV2Target and camera and hrp and humanoid then
		local targetHRP = camLockV2Target:FindFirstChild("HumanoidRootPart")
		local targetHum = camLockV2Target:FindFirstChildWhichIsA("Humanoid")
		
		if targetHRP and targetHum and targetHum.Health > 0 then
			-- Camera position (same as normal camlock)
			local playerPos = hrp.Position + Vector3.new(0, CAMERA_HEIGHT_V2, 0)
			local directionToTarget = (targetHRP.Position - playerPos).Unit
			local cameraPosition = playerPos - (directionToTarget * CAMERA_DISTANCE_V2)
			local targetLook = CFrame.new(cameraPosition, targetHRP.Position)
			camera.CFrame = camera.CFrame:Lerp(targetLook, 0.2)
			
			-- CHARACTER ROTATION based on MOVEMENT DIRECTION (KEY FEATURE!)
			local moveDirection = humanoid.MoveDirection
			if moveDirection.Magnitude > 0.1 then
				-- Character faces the direction they're moving (side dash rotates character!)
				local moveCFrame = CFrame.new(hrp.Position, hrp.Position + moveDirection)
				hrp.CFrame = CFrame.new(hrp.Position) * (moveCFrame - moveCFrame.Position)
			else
				-- When standing still, face the target
				local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
				hrp.CFrame = CFrame.new(hrp.Position, lookPos)
			end
		else
			unlockCamV2()
		end
	end
end)

print("Mobile Lock System + Camlock V1 & V2 loaded!")
print("CHAR LOCK = Character rotation | CAM LOCK = Console camera")
print("CAM V2 = STRAFE MODE - Move any direction while camera locked!")
