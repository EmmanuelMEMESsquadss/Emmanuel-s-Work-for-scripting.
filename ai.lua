-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On + Camlock System [FIXED VERSION]

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

-- Profile Selector Button (+ icon)
local profileBtn = Instance.new("TextButton")
profileBtn.Size = UDim2.new(0, 24, 0, 24)
profileBtn.Position = UDim2.new(0, -30, 0, 13)
profileBtn.Text = "+"
profileBtn.BackgroundColor3 = Color3.fromRGB(46, 147, 216)
profileBtn.TextColor3 = Color3.new(1, 1, 1)
profileBtn.Font = Enum.Font.GothamBold
profileBtn.TextSize = 20
profileBtn.Active = true
profileBtn.ZIndex = 10 -- Higher than menu
profileBtn.Parent = charLockBtn

local profileCorner = Instance.new("UICorner")
profileCorner.CornerRadius = UDim.new(0.5, 0)
profileCorner.Parent = profileBtn

-- Make sure corner has proper ZIndex too
profileBtn.ZIndex = 10

-- Profile Menu Container
local profileMenu = Instance.new("Frame")
profileMenu.Size = UDim2.new(0, 160, 0, 0) -- Start at 0 height for animation
profileMenu.Position = UDim2.new(0, -30, 0, 40) -- Position BELOW the + button
profileMenu.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
profileMenu.BorderSizePixel = 0
profileMenu.ClipsDescendants = true
profileMenu.Visible = false
profileMenu.ZIndex = 5
profileMenu.Parent = charLockBtn

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 8)
menuCorner.Parent = profileMenu

-- Profile options
local profiles = {
	{name = "SMOOTH", desc = "Balanced", power = 15000, damping = 300, color = Color3.fromRGB(80, 200, 120)},
	{name = "SNAP", desc = "Instant", power = 25000, damping = 150, color = Color3.fromRGB(255, 140, 60)},
	{name = "BUTTER", desc = "Ultra Smooth", power = 12000, damping = 400, color = Color3.fromRGB(100, 180, 255)}
}

local currentProfile = 1
local profileButtons = {}

for i, profile in ipairs(profiles) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -10, 0, 35)
	btn.Position = UDim2.new(0, 5, 0, 5 + (i-1) * 40)
	btn.BackgroundColor3 = profile.color
	btn.BackgroundTransparency = 0.2
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Text = profile.name .. " · " .. profile.desc
	btn.ZIndex = 6 -- Above menu, below profile button
	btn.Parent = profileMenu
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn
	
	-- Selection indicator
	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 4, 1, -6)
	indicator.Position = UDim2.new(0, 3, 0, 3)
	indicator.BackgroundColor3 = Color3.new(1, 1, 1)
	indicator.BorderSizePixel = 0
	indicator.Visible = (i == 1) -- First profile selected by default
	indicator.ZIndex = 7 -- Above button
	indicator.Parent = btn
	
	local indCorner = Instance.new("UICorner")
	indCorner.CornerRadius = UDim.new(1, 0)
	indCorner.Parent = indicator
	
	profileButtons[i] = {button = btn, indicator = indicator, profile = profile}
	
	-- Profile selection
	btn.Activated:Connect(function()
		currentProfile = i
		GYRO_POWER = profile.power
		GYRO_DAMPING = profile.damping
		
		-- Update indicators
		for j, data in ipairs(profileButtons) do
			data.indicator.Visible = (j == i)
			-- Smooth color transition
			game:GetService("TweenService"):Create(data.button, TweenInfo.new(0.2), {
				BackgroundTransparency = (j == i) and 0.2 or 0.5
			}):Play()
		end
		
		-- Update existing BodyGyro if active
		if bodyGyro and bodyGyro.Parent then
			bodyGyro.P = GYRO_POWER
			bodyGyro.D = GYRO_DAMPING
		end
		
		-- Visual feedback
		game:GetService("TweenService"):Create(btn, TweenInfo.new(0.1), {
			Size = UDim2.new(1, -8, 0, 35)
		}):Play()
		task.wait(0.1)
		game:GetService("TweenService"):Create(btn, TweenInfo.new(0.1), {
			Size = UDim2.new(1, -10, 0, 35)
		}):Play()
	end)
end

-- Profile toggle animation
local menuOpen = false
profileBtn.Activated:Connect(function()
	menuOpen = not menuOpen
	
	local TweenService = game:GetService("TweenService")
	
	if menuOpen then
		profileMenu.Visible = true
		-- Smooth expand animation
		TweenService:Create(profileMenu, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 160, 0, 125)
		}):Play()
		TweenService:Create(profileBtn, TweenInfo.new(0.2), {
			Rotation = 45,
			BackgroundColor3 = Color3.fromRGB(206, 36, 36)
		}):Play()
	else
		-- Smooth collapse animation
		TweenService:Create(profileMenu, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 160, 0, 0)
		}):Play()
		TweenService:Create(profileBtn, TweenInfo.new(0.2), {
			Rotation = 0,
			BackgroundColor3 = Color3.fromRGB(46, 147, 216)
		}):Play()
		task.wait(0.2)
		profileMenu.Visible = false
	end
end)
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
	-- Restore camera to normal
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
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

-- ============================================
-- FIX #1: Character Rotation (BODYGYRO METHOD - PROFILE SYSTEM)
-- ============================================
-- Dynamic profile switching with smooth animations

local bodyGyro

-- Profile settings (controlled by UI buttons)
GYRO_POWER = 15000      -- Default: SMOOTH profile
GYRO_DAMPING = 300

RunService.Heartbeat:Connect(function()
	if charLockTarget and hrp and humanoid and humanoid.Health > 0 then
		if isDisabled then
			-- Remove gyro when disabled
			if bodyGyro then
				bodyGyro:Destroy()
				bodyGyro = nil
			end
			return
		end
		
		if humanoid.PlatformStand or humanoid.Sit then
			if bodyGyro then
				bodyGyro:Destroy()
				bodyGyro = nil
			end
			return
		end
		
		local targetHRP = charLockTarget:FindFirstChild("HumanoidRootPart")
		local targetHum = charLockTarget:FindFirstChildWhichIsA("Humanoid")
		
		if targetHRP and targetHum and targetHum.Health > 0 then
			-- Create BodyGyro if it doesn't exist
			if not bodyGyro or bodyGyro.Parent ~= hrp then
				bodyGyro = Instance.new("BodyGyro")
				bodyGyro.MaxTorque = Vector3.new(0, math.huge, 0)
				bodyGyro.P = GYRO_POWER
				bodyGyro.D = GYRO_DAMPING
				bodyGyro.Parent = hrp
			end
			
			-- Calculate look direction
			local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
			local lookCFrame = CFrame.new(hrp.Position, lookPos)
			
			-- Apply rotation
			bodyGyro.CFrame = lookCFrame
			
			-- Apply current profile settings
			if bodyGyro.P ~= GYRO_POWER then bodyGyro.P = GYRO_POWER end
			if bodyGyro.D ~= GYRO_DAMPING then bodyGyro.D = GYRO_DAMPING end
		else
			unlockChar()
			if bodyGyro then
				bodyGyro:Destroy()
				bodyGyro = nil
			end
		end
	else
		-- Clean up BodyGyro when not locked
		if bodyGyro then
			bodyGyro:Destroy()
			bodyGyro = nil
		end
	end
end)

-- ============================================
-- Camera Lock loop (CONSOLE-STYLE - ORIGINAL)
-- ============================================
local CAMERA_DISTANCE = 15
local CAMERA_HEIGHT = 3

RunService.RenderStepped:Connect(function()
	if camLockTarget and camera and hrp and humanoid then
		-- FORCE camera to scriptable EVERY FRAME (prevents default camera from taking over)
		camera.CameraType = Enum.CameraType.Scriptable
		
		local targetHRP = camLockTarget:FindFirstChild("HumanoidRootPart")
		local targetHum = camLockTarget:FindFirstChildWhichIsA("Humanoid")
		
		if targetHRP and targetHum and targetHum.Health > 0 then
			-- Get player position
			local playerPos = hrp.Position + Vector3.new(0, CAMERA_HEIGHT, 0)
			
			-- Calculate direction from player to target
			local directionToTarget = (targetHRP.Position - playerPos).Unit
			
			-- Position camera BEHIND player
			local cameraPosition = playerPos - (directionToTarget * CAMERA_DISTANCE)
			
			-- Point camera at target
			local targetLook = CFrame.new(cameraPosition, targetHRP.Position)
			
			-- Smooth transition
			camera.CFrame = camera.CFrame:Lerp(targetLook, 0.2)
		else
			unlockCam()
		end
	end
	
	-- Force restore when not locked (prevent camera from staying scriptable)
	if not camLockTarget and camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end
end)

print("Mobile Lock System [PROFILE SYSTEM] loaded!")
print("✅ CHAR LOCK: 3 Profiles Available (SMOOTH/SNAP/BUTTER)")
print("✅ CAM LOCK: Original console-style")
print("💡 Click [+] button to switch profiles | Drag to reposition")
