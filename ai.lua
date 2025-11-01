-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On System - Character-Based Lock (Like TSB)

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

-- Configuration
local MAX_DIST = 100
local ROTATION_SPEED = 0.2 -- Smooth rotation (0.1 = slower, 0.3 = faster)

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
	
	if humanoid then 
		humanoid.AutoRotate = true
	end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

-- GUI
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

-- SIMPLE & FAST: Check if we should rotate
local function canRotate()
	if not humanoid or humanoid.Health <= 0 then return false end
	if not hrp or not hrp.Parent then return false end
	
	-- Only skip rotation during these specific conditions
	-- Check 1: Humanoid states that mean loss of control
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Physics or 
	   state == Enum.HumanoidStateType.Ragdoll or
	   state == Enum.HumanoidStateType.FallingDown or
	   state == Enum.HumanoidStateType.PlatformStanding then
		return false
	end
	
	-- Check 2: Platform stand (common grab/finisher flag)
	if humanoid.PlatformStand then
		return false
	end
	
	-- Check 3: Sitting (some grabs use this)
	if humanoid.Sit then
		return false
	end
	
	-- Check 4: Camera manipulation (cutscenes/finishers)
	if camera.CameraType ~= Enum.CameraType.Custom then
		return false
	end
	
	-- Check 5: Camera subject changed (ultimate/finisher cutscenes)
	if camera.CameraSubject ~= humanoid then
		return false
	end
	
	-- Check 6: HRP is anchored (finishers often anchor)
	if hrp.Anchored then
		return false
	end
	
	-- Check 7: HRP has constraints (finishers add welds/constraints)
	for _, child in ipairs(hrp:GetChildren()) do
		if child:IsA("Weld") or child:IsA("WeldConstraint") or 
		   child:IsA("Motor6D") or child:IsA("Attachment") or
		   child:IsA("AlignPosition") or child:IsA("AlignOrientation") then
			return false
		end
	end
	
	-- Check 8: WalkSpeed is 0 (finishers disable movement)
	if humanoid.WalkSpeed == 0 then
		return false
	end
	
	-- Check 9: JumpPower/Height is 0 (finishers disable jumping)
	if humanoid.JumpPower == 0 or humanoid.JumpHeight == 0 then
		return false
	end
	
	-- Check 10: High velocity (being thrown/launched in finisher)
	if hrp.AssemblyLinearVelocity.Magnitude > 100 then
		return false
	end
	
	-- All checks passed - safe to rotate
	return true
end

-- SMOOTH CFRAME ROTATION - Character stays locked, only skips rotation when grabbed
RunService.RenderStepped:Connect(function()
	if lockTarget and hrp and humanoid and humanoid.Health > 0 then
		local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
		local targetHum = lockTarget:FindFirstChildWhichIsA("Humanoid")
		
		-- Check if target is still valid
		if not targetHRP or not targetHum or targetHum.Health <= 0 then
			unlock()
			return
		end
		
		-- Only rotate if we can (not grabbed/in cutscene)
		if canRotate() then
			-- Smooth lock-on rotation (only Y-axis)
			local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
			local targetCFrame = CFrame.new(hrp.Position, lookPos)
			
			-- Lerp for smooth rotation
			local currentCFrame = hrp.CFrame
			local newCFrame = currentCFrame:Lerp(targetCFrame, ROTATION_SPEED)
			
			-- Preserve Y position exactly to prevent floating
			newCFrame = CFrame.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z) * 
			            (newCFrame - newCFrame.Position)
			
			hrp.CFrame = newCFrame
		end
		-- Note: If canRotate() returns false, we simply skip rotation this frame
		-- The lock stays active, billboard stays visible, button stays "UNLOCK"
		-- Character just doesn't rotate until they regain control
	end
end)

-- Cleanup on character reset
player.CharacterRemoving:Connect(function()
	unlock()
end)

print("Mobile Lock System loaded! (Character-Based Lock)")
print("Rotation Speed: " .. ROTATION_SPEED .. " (adjust line 17)")
print("Lock stays ON during grabs - rotation pauses automatically")
