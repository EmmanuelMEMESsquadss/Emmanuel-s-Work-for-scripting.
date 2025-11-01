-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On (v8)
-- FIX: Added robust Anchor and multi-part constraint checks to
--      prevent CFrame "tug-of-war" during cutscenes or grabs.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Only run on mobile
if not UserInputService.TouchEnabled then
	print("Non-mobile device detected. Lock-On script disabled.")
	return
end

local player = Players.LocalPlayer
local character, humanoid, hrp, upperTorso, lowerTorso
local camera = workspace.CurrentCamera

-- GUI (No changes)
local gui = Instance.new("ScreenGui")
gui.Name = "LockOnUI"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 110, 0, 50)
btn.Position = UDim2.new(0.06, 0, 0.8, 0)
btn.Text = "LOCK"
btn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 20
btn.Active = true
btn.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = btn

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(1, -12, 0, 4)
statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
statusDot.BorderSizePixel = 0
statusDot.Parent = btn

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(0.5, 0)
dotCorner.Parent = dotCorner

-- Draggable (No changes)
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
	local delta = input.Position - dragStart
	btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
		startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

btn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = btn.Position
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
local lockTarget, lockBillboard
local normalFOV = camera.FieldOfView

local function detachBillboard()
	if lockBillboard then
		lockBillboard:Destroy()
		lockBillboard = nil
	end
end

local function attachBillboard(model)
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
	label.TextColor3 = Color3.fromRGB(255, 80, 80)
	label.Parent = bb
	lockBillboard = bb
end

local function isValidTarget(model)
	if not model or not model:IsA("Model") then return false end
	local hum = model:FindFirstChildWhichIsA("Humanoid")
	local part = model:FindFirstChild("HumanoidRootPart")
	if not hum or not part or hum.Health <= 0 then return false end
	if model == character then return false end
	return true
end

local function getNearestTarget()
	if not hrp then return end
	local nearest, dist = nil, MAX_DIST
	local playerCharacters = {}
	local checkedModels = {}
	
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player and pl.Character and isValidTarget(pl.Character) then
			local d = (hrp.Position - pl.Character.HumanoidRootPart.Position).Magnitude
			if d < dist then
				dist = d
				nearest = pl.Character
			end
			playerCharacters[pl.Character] = true
		end
	end
	
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {character}
	local partsInRadius = workspace:GetPartsInRadius(hrp.Position, MAX_DIST, overlapParams)
	
	for _, part in ipairs(partsInRadius) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not checkedModels[model] and not playerCharacters[model] and isValidTarget(model) then
			local targetHrp = model:FindFirstChild("HumanoidRootPart")
			if targetHrp then
				local d = (hrp.Position - targetHrp.Position).Magnitude
				if d < dist then
					dist = d
					nearest = model
				end
			end
			checkedModels[model] = true
		end
	end
	
	return nearest
end

local function unlock()
	lockTarget = nil
	detachBillboard()
	if humanoid then 
		humanoid.AutoRotate = true 
	end
	btn.Text = "LOCK"
	btn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
end

-- === (THE FIX) v8 - Robust Scene/Grab Detection ===
local function isCharacterControllable()
	if not humanoid or not hrp then return false end

	-- 1. Check Camera (for cutscenes)
	if camera.CameraType == Enum.CameraType.Scriptable then return false end
	if camera.CameraSubject ~= humanoid then return false end
	if (camera.Focus.Position - hrp.Position).Magnitude > 10 then return false end
	if math.abs(camera.FieldOfView - normalFOV) > 15 then return false end

	-- 2. Check for physical/property states
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Physics or
	   state == Enum.HumanoidStateType.Ragdoll or
	   state == Enum.HumanoidStateType.FallingDown or
	   state == Enum.HumanoidStateType.Stunned or
	   state == Enum.HumanoidStateType.GettingUp then
		return false
	end
	
	if humanoid.PlatformStand or humanoid.Sit then
		return false
	end
	
	-- 3. NEW: Check if Anchored (common scene/grab technique)
	if hrp.Anchored then
		return false
	end

	-- 4. NEW: Expanded Constraint Check (for grabs/scenes)
	-- Check HRP, UpperTorso, and LowerTorso for any non-tool constraints
	local partsToCheck = {hrp, upperTorso, lowerTorso}
	for _, part in ipairs(partsToCheck) do
		if part then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Weld") or child:IsA("Constraint") then
					-- Ignore tool grip welds
					if child.Name ~= "RightGrip" and child.Name ~= "LeftGrip" then
						return false -- This is a grab or scene weld!
					end
				end
			end
		end
	end
	
	-- If none of the above, we are controllable
	return true
end

-- Main Setup Function
local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
	-- Store references to torso parts for the grab check
	upperTorso = char:FindFirstChild("UpperTorso")
	lowerTorso = char:FindFirstChild("LowerTorso")
	
	if humanoid then
		humanoid.AutoRotate = true
	end
	normalFOV = camera.FieldOfView
end

-- Button Logic
btn.Activated:Connect(function()
	if lockTarget then
		unlock()
	else
		local t = getNearestTarget()
		if t then
			lockTarget = t
			attachBillboard(t)
			btn.Text = "UNLOCK"
			btn.BackgroundColor3 = Color3.fromRGB(206, 36, 36)
		else
			btn.Text = "NO TARGET"
			task.delay(1, function()
				if not lockTarget then 
					btn.Text = "LOCK" 
				end
			end)
		end
	end
end)

-- Update status indicator
task.spawn(function()
	while true do
		task.wait(0.1)
		-- Update dot based on the *real-time* check
		if isCharacterControllable() then
			statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100) -- Green
		else
			statusDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80) -- Red
		end
	end
end)

-- === (THE FIX) Main Loop v8 ===
RunService.RenderStepped:Connect(function()
	-- Only run if we have a target
	if not lockTarget or not hrp or not humanoid or humanoid.Health <= 0 then
		return 
	end

	-- 1. Check target validity
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	local targetHum = lockTarget:FindFirstChildWhichIsA("Humanoid")
	if not (targetHRP and targetHum and targetHum.Health > 0) then
		unlock()
		return
	end

	-- 2. Check *our* state (frame-accurate)
	if isCharacterControllable() then
		-- We are good to go. Take control and aim.
		if humanoid.AutoRotate == true then
			humanoid.AutoRotate = false
		end
		
		-- Apply CFrame lock
		pcall(function()
			local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
			hrp.CFrame = CFrame.new(hrp.Position, lookPos)
		end)
	else
		-- We are grabbed/ragdolled/in a cutscene.
		-- Release camera control so it follows the game's script.
		if humanoid.AutoRotate == false then
			humanoid.AutoRotate = true
		end
	end
end)

-- Initial setup
if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

print("Mobile Lock System v8 loaded!")
print("FIX: Added Anchored and expanded constraint checks to prevent camera 'tug-of-war'.")
