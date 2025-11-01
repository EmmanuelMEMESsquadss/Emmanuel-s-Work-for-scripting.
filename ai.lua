-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On System - Fixed Camera & Grab Detection

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
local wasDisabled = false

-- Configuration
local MAX_DIST = 100
local ROTATION_SPEED = 0.25 -- Smooth rotation instead of instant
local CHECK_INTERVAL = 0.1

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
	isDisabled = false
	wasDisabled = false
	
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
				[Enum.HumanoidStateType.Climbing] = true,
			}
			
			if disablingStates[newState] then
				isDisabled = true
				wasDisabled = true
			elseif newState == Enum.HumanoidStateType.Running or
			       newState == Enum.HumanoidStateType.Landed or
			       newState == Enum.HumanoidStateType.Jumping or
			       newState == Enum.HumanoidStateType.Freefall then
				-- Small delay before re-enabling
				task.wait(0.2)
				isDisabled = false
			end
		end)
		
		-- Property monitoring
		humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
			isDisabled = humanoid.PlatformStand
			if isDisabled then wasDisabled = true end
		end)
		
		humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
			isDisabled = humanoid.Sit
			if isDisabled then wasDisabled = true end
		end)
		
		-- Monitor WalkSpeed (many grabs set this to 0)
		humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if humanoid.WalkSpeed == 0 and humanoid.Health > 0 then
				isDisabled = true
				wasDisabled = true
			end
		end)
	end
	
	-- Monitor HRP for constraints/welds
	if hrp then
		-- Check for camera manipulation
		local function checkForCutscene()
			if camera.CameraType ~= Enum.CameraType.Custom then
				isDisabled = true
				wasDisabled = true
			end
		end
		
		camera:GetPropertyChangedSignal("CameraType"):Connect(checkForCutscene)
		camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
			if camera.CameraSubject ~= humanoid then
				isDisabled = true
				wasDisabled = true
			end
		end)
		
		-- Monitor for constraints
		hrp.ChildAdded:Connect(function(child)
			if child:IsA("Weld") or child:IsA("WeldConstraint") or 
			   child:IsA("AlignPosition") or child:IsA("AlignOrientation") or
			   child:IsA("RopeConstraint") or child:IsA("BodyGyro") or
			   child:IsA("BodyPosition") or child:IsA("BodyVelocity") then
				isDisabled = true
				wasDisabled = true
				
				-- Re-enable when removed
				child.AncestryChanged:Connect(function()
					if not child:IsDescendantOf(game) then
						task.wait(0.3)
						-- Check if still valid to re-enable
						if humanoid and humanoid.Health > 0 and 
						   not humanoid.PlatformStand and not humanoid.Sit then
							isDisabled = false
						end
					end
				end)
			end
		end)
		
		-- Monitor network ownership changes (common during grabs)
		hrp:GetPropertyChangedSignal("AssemblyLinearVelocity"):Connect(function()
			local vel = hrp.AssemblyLinearVelocity
			-- Extremely high velocity = likely grabbed/launched
			if vel.Magnitude > 200 then
				isDisabled = true
				wasDisabled = true
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

-- FIXED ROTATION SYSTEM - Uses BodyGyro instead of direct CFrame manipulation
local bodyGyro
local lastRotation = tick()

local function createBodyGyro()
	if bodyGyro then bodyGyro:Destroy() end
	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(0, 400000, 0) -- Only Y-axis
	bodyGyro.P = 30000
	bodyGyro.D = 500
	bodyGyro.Parent = hrp
end

local function removeBodyGyro()
	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end
end

-- Smooth rotation loop
RunService.Heartbeat:Connect(function(dt)
	if lockTarget and hrp and humanoid and humanoid.Health > 0 then
		-- CRITICAL: Stop ALL rotation during grabs/cutscenes
		if isDisabled then
			removeBodyGyro()
			return
		end
		
		-- Additional safety checks
		if humanoid.PlatformStand or humanoid.Sit or 
		   camera.CameraType ~= Enum.CameraType.Custom or
		   camera.CameraSubject ~= humanoid then
			removeBodyGyro()
			return
		end
		
		local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
		local targetHum = lockTarget:FindFirstChildWhichIsA("Humanoid")
		
		if targetHRP and targetHum and targetHum.Health > 0 then
			-- Create BodyGyro if needed
			if not bodyGyro or bodyGyro.Parent ~= hrp then
				createBodyGyro()
			end
			
			-- Calculate target direction
			local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
			local targetCFrame = CFrame.new(hrp.Position, lookPos)
			
			-- Smooth interpolation
			local currentCFrame = hrp.CFrame
			local newCFrame = currentCFrame:Lerp(targetCFrame, ROTATION_SPEED)
			
			-- Apply via BodyGyro (network-friendly)
			bodyGyro.CFrame = newCFrame
		else
			unlock()
			removeBodyGyro()
		end
	else
		removeBodyGyro()
	end
end)

-- Cleanup on character reset
player.CharacterRemoving:Connect(function()
	removeBodyGyro()
	unlock()
end)

print("Mobile Lock System loaded! (Fixed Version)")
print("Features: Smooth rotation, grab detection, camera-safe")
