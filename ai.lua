-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On System - Instant CFrame with Smart Detection

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

-- Configuration
local MAX_DIST = 100
local CUTSCENE_CHECK_INTERVAL = 0.05

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
	isDisabled = false
	
	if humanoid then 
		humanoid.AutoRotate = true
		
		-- State detection
		humanoid.StateChanged:Connect(function(oldState, newState)
			local disablingStates = {
				[Enum.HumanoidStateType.Physics] = true,
				[Enum.HumanoidStateType.Ragdoll] = true,
				[Enum.HumanoidStateType.FallingDown] = true,
				[Enum.HumanoidStateType.PlatformStanding] = true,
				[Enum.HumanoidStateType.Swimming] = true,
			}
			
			if disablingStates[newState] then
				isDisabled = true
				-- Wait a bit before re-enabling
				task.spawn(function()
					task.wait(0.5)
					if newState ~= humanoid:GetState() then
						isDisabled = false
					end
				end)
			end
		end)
		
		-- Property monitoring
		humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
			isDisabled = humanoid.PlatformStand
		end)
		
		humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
			isDisabled = humanoid.Sit
		end)
		
		-- Critical: Monitor WalkSpeed (grabs often set to 0)
		humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if humanoid.WalkSpeed == 0 and humanoid.Health > 0 then
				isDisabled = true
				-- Re-enable when WalkSpeed returns
				task.spawn(function()
					while humanoid.WalkSpeed == 0 do
						task.wait(0.1)
					end
					task.wait(0.3)
					isDisabled = false
				end)
			end
		end)
		
		-- Monitor JumpPower/Height (some moves disable jumping)
		humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
			if humanoid.JumpPower == 0 then
				isDisabled = true
				task.spawn(function()
					while humanoid.JumpPower == 0 do task.wait(0.1) end
					task.wait(0.2)
					isDisabled = false
				end)
			end
		end)
	end
	
	-- Monitor HRP for constraints/welds
	if hrp then
		-- Camera monitoring (critical for cutscenes)
		local lastCameraType = camera.CameraType
		local lastCameraSubject = camera.CameraSubject
		
		task.spawn(function()
			while hrp and hrp.Parent do
				-- Check camera every frame for instant detection
				if camera.CameraType ~= Enum.CameraType.Custom or 
				   camera.CameraSubject ~= humanoid then
					isDisabled = true
					lastCameraType = camera.CameraType
					lastCameraSubject = camera.CameraSubject
				elseif isDisabled and 
				       camera.CameraType == Enum.CameraType.Custom and
				       camera.CameraSubject == humanoid then
					-- Camera returned to normal, wait a bit then re-enable
					task.wait(0.3)
					if camera.CameraType == Enum.CameraType.Custom and
					   camera.CameraSubject == humanoid then
						isDisabled = false
					end
				end
				task.wait(CUTSCENE_CHECK_INTERVAL)
			end
		end)
		
		-- Monitor for constraints (grabs/moves)
		hrp.ChildAdded:Connect(function(child)
			if child:IsA("Weld") or child:IsA("WeldConstraint") or 
			   child:IsA("AlignPosition") or child:IsA("AlignOrientation") or
			   child:IsA("RopeConstraint") or child:IsA("BodyGyro") or
			   child:IsA("BodyPosition") or child:IsA("BodyVelocity") or
			   child:IsA("BodyAngularVelocity") or child:IsA("Attachment") then
				isDisabled = true
				
				-- Re-enable when removed
				child.AncestryChanged:Connect(function()
					if not child:IsDescendantOf(game) then
						task.wait(0.4)
						if humanoid and humanoid.Health > 0 and 
						   not humanoid.PlatformStand and not humanoid.Sit and
						   camera.CameraType == Enum.CameraType.Custom then
							isDisabled = false
						end
					end
				end)
			end
		end)
		
		-- Monitor anchored state (some moves anchor the character)
		hrp:GetPropertyChangedSignal("Anchored"):Connect(function()
			if hrp.Anchored then
				isDisabled = true
				task.spawn(function()
					while hrp.Anchored do task.wait(0.1) end
					task.wait(0.3)
					isDisabled = false
				end)
			end
		end)
		
		-- Network ownership check (if we don't own it, we can't rotate it properly)
		task.spawn(function()
			while hrp and hrp.Parent do
				local canSetNetworkOwner = pcall(function()
					hrp:GetNetworkOwner()
				end)
				if not canSetNetworkOwner then
					-- We don't have network ownership, likely grabbed
					isDisabled = true
				end
				task.wait(0.1)
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

-- Status indicator update
RunService.Heartbeat:Connect(function()
	if isDisabled then
		statusDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	else
		statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
	end
end)

-- INSTANT CFRAME ROTATION with Smart Safety Checks
local lastPosition = nil
local stuckCounter = 0

RunService.RenderStepped:Connect(function()
	if lockTarget and hrp and humanoid and humanoid.Health > 0 then
		-- CRITICAL SAFETY CHECKS - Don't rotate if ANY of these are true
		if isDisabled then
			return
		end
		
		-- Real-time safety checks
		if humanoid.PlatformStand or humanoid.Sit or hrp.Anchored then
			return
		end
		
		-- Camera check (instant detection of cutscenes)
		if camera.CameraType ~= Enum.CameraType.Custom or 
		   camera.CameraSubject ~= humanoid then
			return
		end
		
		-- Check if we're being moved externally (velocity check)
		local velocity = hrp.AssemblyLinearVelocity
		if velocity.Magnitude > 150 then
			-- High velocity = likely grabbed/launched
			return
		end
		
		-- Check if position is stuck (indicates loss of control)
		if lastPosition then
			local posDiff = (hrp.Position - lastPosition).Magnitude
			if posDiff < 0.01 and humanoid.MoveDirection.Magnitude > 0 then
				stuckCounter = stuckCounter + 1
				if stuckCounter > 10 then
					-- Character is stuck, likely grabbed
					return
				end
			else
				stuckCounter = 0
			end
		end
		lastPosition = hrp.Position
		
		-- Check for external constraints
		local hasConstraint = false
		for _, child in ipairs(hrp:GetChildren()) do
			if child:IsA("Constraint") or child:IsA("Weld") or 
			   child:IsA("BodyMover") or child.Name:find("Body") then
				hasConstraint = true
				break
			end
		end
		if hasConstraint then
			return
		end
		
		-- All checks passed - perform INSTANT rotation
		local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
		local targetHum = lockTarget:FindFirstChildWhichIsA("Humanoid")
		
		if targetHRP and targetHum and targetHum.Health > 0 then
			-- Instant lock-on rotation (only Y-axis)
			local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
			local newCFrame = CFrame.new(hrp.Position, lookPos)
			
			-- Preserve Y position exactly to prevent floating
			newCFrame = CFrame.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z) * 
			            (newCFrame - newCFrame.Position)
			
			hrp.CFrame = newCFrame
		else
			unlock()
		end
	end
end)

-- Cleanup on character reset
player.CharacterRemoving:Connect(function()
	unlock()
end)

print("Mobile Lock System loaded! (Instant CFrame - Smart Detection)")
print("Lock stays disabled during: Grabs, Cutscenes, Ragdolls, High velocity")
print("Status: READY - Green dot = Active, Red dot = Disabled")
