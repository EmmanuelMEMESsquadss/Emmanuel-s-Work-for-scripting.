-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On with Advanced Scene/Grab Detection (v9)
-- This version builds ON YOUR SCRIPT, replacing the 'isRagdolled'
-- flag with a smarter, event-driven 'isControllable' flag.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Only run on mobile
if not UserInputService.TouchEnabled then
	return
end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character, humanoid, hrp, upperTorso, lowerTorso

-- === (THE FIX) This is our new, smarter boolean ===
local isControllable = true
-- =================================================

-- === (THE FIX) This is the new "brain" of the script ===
-- This master function checks everything and sets the 'isControllable' flag.
local function updateControlState()
	-- Check for valid character components
	if not humanoid or not hrp or not character or not character.Parent then
		isControllable = false
		return
	end

	-- 1. Check Camera (for cutscenes/scenes)
	if camera.CameraType == Enum.CameraType.Scriptable or camera.CameraSubject ~= humanoid then
		isControllable = false
		return
	end

	-- 2. Check for physical/property states
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Physics or
	   state == Enum.HumanoidStateType.Ragdoll or
	   state == Enum.HumanoidStateType.FallingDown or
	   state == Enum.HumanoidStateType.Stunned or
	   state == Enum.HumanoidStateType.GettingUp then
		isControllable = false
		return
	end
	
	if humanoid.PlatformStand or humanoid.Sit then
		isControllable = false
		return
	end
	
	-- 3. Check if Anchored (common scene/grab technique)
	if hrp.Anchored then
		isControllable = false
		return
	end

	-- 4. Expanded Constraint Check (for grabs/scenes)
	-- Check HRP, UpperTorso, and LowerTorso for any non-tool constraints
	local partsToCheck = {hrp, upperTorso, lowerTorso}
	for _, part in ipairs(partsToCheck) do
		if part then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Weld") or child:IsA("Constraint") then
					if child.Name ~= "RightGrip" and child.Name ~= "LeftGrip" then
						isControllable = false -- This is a grab or scene weld!
						return
					end
				end
			end
		end
	end
	
	-- If nothing stopped us, we are controllable
	isControllable = true
end

-- This is your original setup function, now upgraded
-- to connect all our new listeners.
local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
	upperTorso = char:FindFirstChild("UpperTorso")
	lowerTorso = char:FindFirstChild("LowerTorso")

	if humanoid then 
		humanoid.AutoRotate = true 
		
		-- Hook up all events to the master check function
		humanoid.StateChanged:Connect(updateControlState)
		humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(updateControlState)
		humanoid:GetPropertyChangedSignal("Sit"):Connect(updateControlState)
	end
	
	if hrp then
		hrp:GetPropertyChangedSignal("Anchored"):Connect(updateControlState)
		hrp.ChildAdded:Connect(updateControlState)
		hrp.ChildRemoved:Connect(updateControlState) -- Detects when a grab ends
	end
	
	if upperTorso then
		upperTorso.ChildAdded:Connect(updateControlState)
		upperTorso.ChildRemoved:Connect(updateControlState)
	end
	
	if lowerTorso then
		lowerTorso.ChildAdded:Connect(updateControlState)
		lowerTorso.ChildRemoved:Connect(updateControlState)
	end
	
	-- Also listen for camera changes
	camera:GetPropertyChangedSignal("CameraType"):Connect(updateControlState)
	camera:GetPropertyChangedSignal("CameraSubject"):Connect(updateControlState)
	
	-- Run it once to set the initial state
	updateControlState()
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

-- GUI (Your original code, untouched)
local gui = Instance.new("ScreenGui")
gui.Name = "LockOnUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

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

-- === (THE FIX) This dot now uses our new master boolean ===
local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(1, -12, 0, 4)
statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
statusDot.BorderSizePixel = 0
statusDot.Parent = btn

task.spawn(function()
	while true do
		task.wait(0.1)
		if isControllable then
			statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100) -- Green
		else
			statusDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80) -- Red
		end
	end
end)
-- ==========================================================

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(0.5, 0)
dotCorner.Parent = dotCorner

-- Draggable (Your original code, untouched)
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

-- Lock state (Your original code, untouched)
local MAX_DIST = 100
local lockTarget, lockBillboard

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
	if Players:GetPlayerFromCharacter(model) == player then return false end
	return true
end

-- Your getNearestTarget function, untouched.
-- It's slow, but it's *your* code and it works. I will not break it.
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

local function unlock()
	lockTarget = nil
	detachBillboard()
	if humanoid then humanoid.AutoRotate = true end
	btn.Text = "LOCK"
	btn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
end

-- Your button code, untouched.
btn.Activated:Connect(function()
	if lockTarget then
		unlock()
	else
		local t = getNearestTarget()
		if t then
			lockTarget = t
			if humanoid then humanoid.AutoRotate = false end
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

-- === (THE FIX) This is your original RenderStepped loop ===
-- It now checks our new, smart 'isControllable' flag
RunService.RenderStepped:Connect(function()
	if lockTarget and hrp and humanoid and humanoid.Health > 0 then
		
		-- Check target validity first
		local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
		local targetHum = lockTarget:FindFirstChildWhichIsA("Humanoid")
		if not (targetHRP and targetHum and targetHum.Health > 0) then
			unlock()
			return
		end

		-- This is the core fix.
		-- We check our single, fast, smart boolean.
		if isControllable then
			-- We are in control. Take over.
			if humanoid.AutoRotate == true then
				humanoid.AutoRotate = false
			end
			
			local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
			hrp.CFrame = CFrame.new(hrp.Position, lookPos)
		else
			-- We are in a scene or grabbed. Release control.
			if humanoid.AutoRotate == false then
				humanoid.AutoRotate = true
			end
		end
	end
end)

print("Mobile Lock System v9 loaded!")
print("FIX: Using event-driven checks. This should fix the camera tug-of-war.")
