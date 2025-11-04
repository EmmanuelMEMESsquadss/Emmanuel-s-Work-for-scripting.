-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On with Advanced Grab/Ragdoll Detection (Improved camera-safe version)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Only run on mobile
if not UserInputService.TouchEnabled then
	return
end

local player = Players.LocalPlayer
local character, humanoid, hrp
local isDisabled = false
local constraintWatchConnections = {}
local lastConstraintRemovedTick = 0

local function clearConstraintWatches()
	for _, conn in pairs(constraintWatchConnections) do
		if conn and conn.Disconnect then
			conn:Disconnect()
		end
	end
	constraintWatchConnections = {}
end

local function onConstraintRemoved(child)
	-- small debounce to avoid instant re-enable during quick transitions
	lastConstraintRemovedTick = tick()
	task.delay(0.25, function()
		-- only re-enable if no active flags
		if tick() - lastConstraintRemovedTick >= 0.25 then
			isDisabled = false
		end
	end)
end

local function watchConstraintsOn(part)
	if not part then return end
	-- watch child added/removed for many constraint types and Motor6D (grab welds)
	local connAdd = part.ChildAdded:Connect(function(child)
		if child:IsA("Weld") or child:IsA("WeldConstraint")
			or child:IsA("AlignPosition") or child:IsA("AlignOrientation")
			or child:IsA("RopeConstraint") or child:IsA("RodConstraint")
			or child:IsA("BallSocketConstraint") or child:IsA("HingeConstraint")
			or child:IsA("Attachment") or child:IsA("SpringConstraint")
			or child:IsA("Motor6D") then

			isDisabled = true
			-- watch ancestry to detect removal
			local aconn
			aconn = child.AncestryChanged:Connect(function(_, parent)
				if not child:IsDescendantOf(game) then
					onConstraintRemoved(child)
					if aconn then aconn:Disconnect() end
				end
			end)
		end
	end)
	table.insert(constraintWatchConnections, connAdd)

	-- watch direct removals as well (in case constraint already present when we start)
	local connRem = part.ChildRemoved:Connect(function(child)
		if child:IsA("Weld") or child:IsA("WeldConstraint")
			or child:IsA("AlignPosition") or child:IsA("AlignOrientation")
			or child:IsA("RopeConstraint") or child:IsA("RodConstraint")
			or child:IsA("BallSocketConstraint") or child:IsA("HingeConstraint")
			or child:IsA("Attachment") or child:IsA("SpringConstraint")
			or child:IsA("Motor6D") then

			onConstraintRemoved(child)
		end
	end)
	table.insert(constraintWatchConnections, connRem)
end

local function setupCharacter(char)
	clearConstraintWatches()

	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")

	if humanoid then 
		humanoid.AutoRotate = true 
		
		-- Detect ragdoll/grab through state changes
		humanoid.StateChanged:Connect(function(oldState, newState)
			-- when these states occur we treat player as incapacitated
			if newState == Enum.HumanoidStateType.Physics or 
			   newState == Enum.HumanoidStateType.Ragdoll or
			   newState == Enum.HumanoidStateType.FallingDown or
			   newState == Enum.HumanoidStateType.PlatformStanding or
			   newState == Enum.HumanoidStateType.Dead then
				isDisabled = true
			elseif newState == Enum.HumanoidStateType.Running or
			       newState == Enum.HumanoidStateType.Landed or
			       newState == Enum.HumanoidStateType.Jumping or
				   newState == Enum.HumanoidStateType.GettingUp or
				   newState == Enum.HumanoidStateType.Freefall then
				-- only re-enable if no other flags (constraint/PlatformStand) present
				if not humanoid.PlatformStand and not humanoid.Sit then
					isDisabled = false
				end
			end
		end)
		
		-- Detect PlatformStand changes (common grab method)
		humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
			if humanoid.PlatformStand then
				isDisabled = true
			else
				-- small delay allows other signals to settle
				task.delay(0.1, function()
					if not humanoid.PlatformStand and not humanoid.Sit then
						isDisabled = false
					end
				end)
			end
		end)
		
		-- Detect Sit changes (some grabs use this)
		humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
			if humanoid.Sit then
				isDisabled = true
			else
				task.delay(0.1, function()
					if not humanoid.PlatformStand then
						isDisabled = false
					end
				end)
			end
		end)
	end
	
	-- Monitor for welds/constraints added to HRP (grab detection)
	if hrp then
		watchConstraintsOn(hrp)
		-- also detect if HRP becomes anchored (rare) or gets destroyed
		hrp:GetPropertyChangedSignal("Anchored"):Connect(function()
			if hrp.Anchored then
				isDisabled = true
			else
				task.delay(0.1, function()
					if not hrp.Anchored then isDisabled = false end
				end)
			end
		end)
	end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)
player.CharacterRemoving:Connect(function()
	clearConstraintWatches()
	character, humanoid, hrp = nil, nil, nil
	isDisabled = true
end)

-- GUI (unchanged)
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
local MAX_DIST = 100
local lockTarget, lockBillboard
local camera = workspace.CurrentCamera

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
			local ok, targetPart = pcall(function() return pl.Character.HumanoidRootPart end)
			if ok and targetPart then
				local d = (hrp.Position - targetPart.Position).Magnitude
				if d < dist then
					dist = d
					nearest = pl.Character
				end
			end
		end
	end
	-- Check other models in workspace (be careful not to duplicate players)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and isValidTarget(obj) and not Players:GetPlayerFromCharacter(obj) then
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

-- Update status indicator
spawn(function()
	while true do
		wait(0.1)
		if isDisabled then
			statusDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80) -- Red when disabled
		else
			statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100) -- Green when active
		end
	end
end)

-- Rotation loop - camera-safe instant mode with optional smoothing
local SMOOTH = false -- set true to enable small smoothing (recommended if camera snapping is still noticeable)
local SMOOTH_SPEED = 0.55 -- 0..1, closer to 1 = faster

-- Helper: return true if camera is free for us to rotate character safely
local function cameraAllowsRotation()
	if not camera or not humanoid then return false end
	-- If camera is Scriptable or CameraType is not Custom, some other script likely controls the camera (finishers/cutscenes).
	-- Also check camera's CameraSubject: if it's not our humanoid, avoid rotating HRP.
	local camType = camera.CameraType
	local subject = camera.CameraSubject
	if camType ~= Enum.CameraType.Custom then
		return false
	end
	-- subject can be Instance or nil; check if subject is our humanoid (or model's Torso)
	if subject and subject:IsA("Humanoid") and subject == humanoid then
		return true
	end
	-- In some setups the CameraSubject may be the character model or HRP; prefer to be conservative
	-- If CameraSubject is not our humanoid, skip rotating to avoid fights with camera
	return false
end

local lastSafeRotationTick = 0

RunService.RenderStepped:Connect(function(dt)
	-- Update camera reference (in case of camera swapping)
	camera = workspace.CurrentCamera

	if not lockTarget or not hrp or not humanoid or humanoid.Health <= 0 then
		return
	end

	-- If we're flagged disabled by grab/ragdoll/etc, don't rotate
	if isDisabled then
		lastSafeRotationTick = tick()
		return
	end

	-- If humanoid is in PlatformStand or Sit, don't rotate
	if humanoid.PlatformStand or humanoid.Sit then
		lastSafeRotationTick = tick()
		return
	end

	-- If target is invalid or dead, unlock
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	local targetHum = lockTarget:FindFirstChildWhichIsA("Humanoid")
	if not targetHRP or not targetHum or targetHum.Health <= 0 then
		unlock()
		return
	end

	-- If target got too far, unlock
	if (hrp.Position - targetHRP.Position).Magnitude > MAX_DIST then
		unlock()
		return
	end

	-- If camera is currently not in a free state (scriptable or different subject), pause rotation to avoid camera fight
	if not cameraAllowsRotation() then
		-- keep lock but do not alter orientation while camera in control of something else
		lastSafeRotationTick = tick()
		return
	end

	-- If the last safepause was very recent, optionally smooth re-enable to prevent snaps
	if SMOOTH and tick() - lastSafeRotationTick < 0.25 then
		-- apply smoothing towards desired orientation
		local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
		local desiredCFrame = CFrame.new(hrp.Position, lookPos)
		-- slerp-like using CFrame: interpolate rotation only
		local current = hrp.CFrame
		local r0 = current - current.Position
		local r1 = desiredCFrame - desiredCFrame.Position
		local tlerp = SMOOTH_SPEED * math.clamp(dt * 60, 0, 1)
		local newRot = r0:Lerp(r1, tlerp)
		hrp.CFrame = CFrame.new(hrp.Position) * newRot
	else
		-- instant rotation (keeps position; sets orientation to face target)
		local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
		hrp.CFrame = CFrame.new(hrp.Position, lookPos)
	end
end)

print("Mobile Lock System (camera-safe) loaded!")
print("Features: Lock-On with Advanced Grab/Ragdoll Detection, camera-aware rotation pause")
