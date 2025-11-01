-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On with Camera Control (v8)
-- FIX: Controls the CAMERA, not the CHARACTER. This prevents all conflicts.

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
local character, humanoid, hrp
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

-- Optimized Target Finding
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
	-- No longer need to touch AutoRotate
	btn.Text = "LOCK"
	btn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
end

-- === (THE FIX) v8 - Scene-Aware Check ===
-- This function now only checks if the GAME is controlling the camera.
-- It no longer cares about the character's physical state.
local function isGameControllingCamera()
	if not humanoid or not hrp then return true end

	-- 1. Check Camera Type/Subject
	if camera.CameraType == Enum.CameraType.Scriptable then
		return true -- Obvious cutscene
	end
	if camera.CameraSubject ~= humanoid then
		return true -- Camera is locked onto something else
	end
	
	-- 2. Check Camera Focus
	if (camera.Focus.Position - hrp.Position).Magnitude > 10 then
		return true -- Camera focus has been pulled away
	end
	
	-- 3. Check FOV
	if math.abs(camera.FieldOfView - normalFOV) > 15 then
		return true -- Camera is zoomed for a scene
	end
	
	-- If none of the above, the game is NOT controlling the camera
	return false
end

-- Main Setup Function
local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
	-- We no longer touch AutoRotate here
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
		-- Dot now reflects if a scene is active
		if isGameControllingCamera() then
			statusDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80) -- Red (Game has control)
		else
			statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100) -- Green (Script can run)
		end
	end
end)

-- === (THE FIX) v8 - Main Loop ===
-- This loop now *ONLY* controls the camera.
RunService.RenderStepped:Connect(function()
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

	-- 2. Check if the game is in a scene
	if isGameControllingCamera() then
		-- The game is in a cutscene.
		-- Do *not* apply the camera lock. Let the game do its thing.
		return 
	end
	
	-- 3. We are clear! Apply the camera lock.
	-- This will not fight physics. Your character can be grabbed,
	-- but your camera will stay locked on the target.
	pcall(function()
		camera.CFrame = CFrame.new(camera.CFrame.Position, targetHRP.Position)
	end)
end)

-- Initial setup
if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

print("Mobile Lock System v8 loaded!")
print("FIX: Now controls CAMERA CFrame, not CHARACTER CFrame. No more conflicts.")
