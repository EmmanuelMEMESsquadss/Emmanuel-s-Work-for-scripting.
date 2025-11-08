-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On + Camlock System

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
camLockBtn.Position = UDim2.new(0.06, 120, 0.8, 0) -- Next to character lock
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

-- Draggable (both buttons move together)
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
	local delta = input.Position - dragStart
	charLockBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
		startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	camLockBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X + 120,
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

UserInputService.InputChanged:Connect(function(input)
	if dragging and input == dragInput then updateDrag(input) end
end)

-- Lock state
local MAX_DIST = 100
local charLockTarget, camLockTarget
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
	if not camLockTarget then detachBillboard() end
end

local function unlockCam()
	camLockTarget = nil
	camLockBtn.Text = "CAM LOCK"
	camLockBtn.BackgroundColor3 = Color3.fromRGB(206, 137, 36)
	if not charLockTarget then detachBillboard() end
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
			local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
			hrp.CFrame = CFrame.new(hrp.Position, lookPos)
		else
			unlockChar()
		end
	end
end)

-- Camera Lock loop (CONSOLE-STYLE)
local CAMERA_DISTANCE = 12 -- Distance behind player
local CAMERA_HEIGHT = 2 -- Height above player

RunService.RenderStepped:Connect(function()
	if camLockTarget and camera and hrp then
		local targetHRP = camLockTarget:FindFirstChild("HumanoidRootPart")
		local targetHum = camLockTarget:FindFirstChildWhichIsA("Humanoid")
		
		if targetHRP and targetHum and targetHum.Health > 0 then
			-- Calculate camera position BEHIND player, LOOKING at target
			local playerPos = hrp.Position + Vector3.new(0, CAMERA_HEIGHT, 0)
			
			-- Direction from player to target
			local targetDirection = (targetHRP.Position - playerPos).Unit
			
			-- Position camera BEHIND player
			local cameraPos = playerPos - (targetDirection * CAMERA_DISTANCE)
			
			-- Make camera look at target
			local cameraCFrame = CFrame.new(cameraPos, targetHRP.Position)
			
			-- Smooth camera movement
			camera.CFrame = camera.CFrame:Lerp(cameraCFrame, 0.15)
		else
			unlockCam()
		end
	end
end)

print("Mobile Lock System + Camlock loaded!")
print("CHAR LOCK = Rotates character | CAM LOCK = Locks camera")
