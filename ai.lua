-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On with Advanced Grab/Ragdoll Detection (v2)

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
local isDisabled = false

-- GUI
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
dotCorner.Parent = statusDot

-- Draggable
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

-- === IMPROVED getNearestTarget ===
-- This function is now more efficient and won't check players twice.
local function getNearestTarget()
	if not hrp then return end
	local nearest, dist = nil, MAX_DIST
	local playerCharacters = {} -- A set to ignore later
	
	-- 1. Check all players
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player and pl.Character and isValidTarget(pl.Character) then
			local d = (hrp.Position - pl.Character.HumanoidRootPart.Position).Magnitude
			if d < dist then
				dist = d
				nearest = pl.Character
			end
			playerCharacters[pl.Character] = true -- Add to ignore list
		end
	end
	
	-- 2. Check all other models in workspace (NPCs, etc.)
	for _, obj in ipairs(workspace:GetDescendants()) do
		-- Only check models that ARE NOT player characters and ARE valid
		if obj:IsA("Model") and not playerCharacters[obj] and isValidTarget(obj) then
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
	if humanoid then 
		humanoid.AutoRotate = true 
	end
	btn.Text = "LOCK"
	btn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
end

-- Main Setup Function
local function setupCharacter(char)
	-- Wrap in pcall to prevent errors on weird spawns
	pcall(function()
		character = char
		humanoid = char:WaitForChild("Humanoid")
		hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
		
		if humanoid then 
			humanoid.AutoRotate = true 
			
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
			
			humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
				isDisabled = humanoid.PlatformStand
			end)
			
			humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
				if humanoid.Sit then
					isDisabled = true
				end
			end)
		end
		
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
							-- Only set false if still alive and not in a bad state
							if humanoid and humanoid.Health > 0 and not humanoid.PlatformStand and not humanoid.Sit then
								isDisabled = false
							end
						end
					end)
				end
			end)
		end
	end)
end

-- Button Logic
btn.Activated:Connect(function()
	if lockTarget then
		unlock()
	else
		local t = getNearestTarget()
		if t then
			lockTarget = t
			if humanoid then 
				humanoid.AutoRotate = false -- Take control
			end
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
		if isDisabled then
			statusDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80) -- Red
		else
			statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100) -- Green
		end
	end
end)

-- === (THE FIX) IMPROVED Rotation loop ===
local wasDisabled = false -- Keep track of the previous state

RunService.RenderStepped:Connect(function()
	if not lockTarget or not hrp or not humanoid or humanoid.Health <= 0 then
		return 
	end

	-- Check target validity FIRST
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	local targetHum = lockTarget:FindFirstChildWhichIsA("Humanoid")
	if not (targetHRP and targetHum and targetHum.Health > 0) then
		unlock() -- Target is invalid, unlock completely
		return
	end

	-- Now, handle grab/ragdoll state
	if isDisabled then
		-- We are grabbed/ragdolled.
		-- Release camera control so it follows the ragdoll/grab physics.
		if humanoid.AutoRotate == false then
			humanoid.AutoRotate = true
		end
		wasDisabled = true -- Flag that we were disabled
		return -- Do NOT apply our own rotation
	end
	
	-- If we're here, isDisabled is false. We are NOT grabbed.
	
	-- Check if we *just* came out of a disabled state
	if wasDisabled then
		humanoid.AutoRotate = false -- Re-take control of camera
		wasDisabled = false
	end

	-- We are not disabled, and we have a valid target.
	-- Apply the lock-on rotation.
	pcall(function()
		local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
		hrp.CFrame = CFrame.new(hrp.Position, lookPos)
	end)
end)

-- Initial setup
if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

print("Mobile Lock System v2 loaded!")
print("FIX: Camera now releases on grab/ragdoll.")
