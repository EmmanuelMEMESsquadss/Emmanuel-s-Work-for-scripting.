-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On with Side Dash for JJS

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Only run on mobile
if not UserInputService.TouchEnabled then
	return
end

local player = Players.LocalPlayer
local character, humanoid, hrp

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
	if humanoid then humanoid.AutoRotate = true end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

-- Virtual key press for dash
local function pressKey(key)
	VirtualInputManager:SendKeyEvent(true, key, false, game)
	task.wait(0.05)
	VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function holdKey(key, duration)
	VirtualInputManager:SendKeyEvent(true, key, false, game)
	task.wait(duration)
	VirtualInputManager:SendKeyEvent(false, key, false, game)
end

-- Side dash function
local function sideDash(direction)
	if not hrp or not lockTarget then return end
	
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end
	
	-- Calculate side direction relative to target
	local toTarget = (targetHRP.Position - hrp.Position).Unit
	local rightVector = Vector3.new(-toTarget.Z, 0, toTarget.X) -- Perpendicular vector
	
	local dashDirection
	if direction == "left" then
		dashDirection = -rightVector
	else -- right
		dashDirection = rightVector
	end
	
	-- Face the dash direction
	hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + dashDirection)
	
	task.wait(0.05)
	
	-- Hold W and press Q to dash
	spawn(function()
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
		task.wait(0.05)
		pressKey(Enum.KeyCode.Q)
		task.wait(0.1)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
	end)
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "MobileLockUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 150, 0, 200)
mainFrame.Position = UDim2.new(0.06, 0, 0.7, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = gui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 10)
frameCorner.Parent = mainFrame

-- Lock button
local lockBtn = Instance.new("TextButton")
lockBtn.Size = UDim2.new(1, -10, 0, 45)
lockBtn.Position = UDim2.new(0, 5, 0, 5)
lockBtn.Text = "LOCK"
lockBtn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
lockBtn.TextColor3 = Color3.new(1, 1, 1)
lockBtn.Font = Enum.Font.GothamBold
lockBtn.TextSize = 18
lockBtn.Parent = mainFrame

local lockCorner = Instance.new("UICorner")
lockCorner.CornerRadius = UDim.new(0, 8)
lockCorner.Parent = lockBtn

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -10, 0, 25)
statusLabel.Position = UDim2.new(0, 5, 0, 55)
statusLabel.Text = "Ready"
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.Parent = mainFrame

-- Dash left button
local dashLeftBtn = Instance.new("TextButton")
dashLeftBtn.Size = UDim2.new(0.48, 0, 0, 40)
dashLeftBtn.Position = UDim2.new(0, 5, 0, 85)
dashLeftBtn.Text = "← DASH"
dashLeftBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
dashLeftBtn.TextColor3 = Color3.new(1, 1, 1)
dashLeftBtn.Font = Enum.Font.GothamBold
dashLeftBtn.TextSize = 14
dashLeftBtn.Parent = mainFrame

local dashLeftCorner = Instance.new("UICorner")
dashLeftCorner.CornerRadius = UDim.new(0, 6)
dashLeftCorner.Parent = dashLeftBtn

-- Dash right button
local dashRightBtn = Instance.new("TextButton")
dashRightBtn.Size = UDim2.new(0.48, 0, 0, 40)
dashRightBtn.Position = UDim2.new(0.52, 0, 0, 85)
dashRightBtn.Text = "DASH →"
dashRightBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
dashRightBtn.TextColor3 = Color3.new(1, 1, 1)
dashRightBtn.Font = Enum.Font.GothamBold
dashRightBtn.TextSize = 14
dashRightBtn.Parent = mainFrame

local dashRightCorner = Instance.new("UICorner")
dashRightCorner.CornerRadius = UDim.new(0, 6)
dashRightCorner.Parent = dashRightBtn

-- Dash behind button
local dashBehindBtn = Instance.new("TextButton")
dashBehindBtn.Size = UDim2.new(1, -10, 0, 35)
dashBehindBtn.Position = UDim2.new(0, 5, 0, 130)
dashBehindBtn.Text = "DASH BEHIND"
dashBehindBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
dashBehindBtn.TextColor3 = Color3.new(1, 1, 1)
dashBehindBtn.Font = Enum.Font.GothamBold
dashBehindBtn.TextSize = 14
dashBehindBtn.Parent = mainFrame

local dashBehindCorner = Instance.new("UICorner")
dashBehindCorner.CornerRadius = UDim.new(0, 6)
dashBehindCorner.Parent = dashBehindBtn

-- Forward dash button
local dashForwardBtn = Instance.new("TextButton")
dashForwardBtn.Size = UDim2.new(1, -10, 0, 25)
dashForwardBtn.Position = UDim2.new(0, 5, 0, 170)
dashForwardBtn.Text = "DASH FORWARD"
dashForwardBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
dashForwardBtn.TextColor3 = Color3.new(1, 1, 1)
dashForwardBtn.Font = Enum.Font.Gotham
dashForwardBtn.TextSize = 12
dashForwardBtn.Parent = mainFrame

local dashForwardCorner = Instance.new("UICorner")
dashForwardCorner.CornerRadius = UDim.new(0, 4)
dashForwardCorner.Parent = dashForwardBtn

-- Draggable
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
	local delta = input.Position - dragStart
	mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
		startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

mainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
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
			local d = (hrp.Position - obj.HumanoidRootPart.Position).Magnitude
			if d < dist then
				dist = d
				nearest = obj
			end
		end
	end
	return nearest
end

local function unlock()
	lockTarget = nil
	detachBillboard()
	if humanoid then humanoid.AutoRotate = true end
	lockBtn.Text = "LOCK"
	lockBtn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
	statusLabel.Text = "Ready"
	statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
end

-- Dash behind target
local function dashBehind()
	if not hrp or not lockTarget then return end
	
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end
	
	-- Get direction target is facing and position behind them
	local targetLookVector = targetHRP.CFrame.LookVector
	local behindDirection = -targetLookVector
	
	-- Face behind the target
	hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + behindDirection)
	
	task.wait(0.05)
	
	-- Dash forward (which is behind target)
	spawn(function()
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
		task.wait(0.05)
		pressKey(Enum.KeyCode.Q)
		task.wait(0.1)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
	end)
end

-- Forward dash to target
local function dashForward()
	if not hrp or not lockTarget then return end
	
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end
	
	-- Face target
	local direction = (targetHRP.Position - hrp.Position).Unit
	hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + direction)
	
	task.wait(0.05)
	
	-- Dash
	spawn(function()
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
		task.wait(0.05)
		pressKey(Enum.KeyCode.Q)
		task.wait(0.1)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
	end)
end

-- Button connections
lockBtn.Activated:Connect(function()
	if lockTarget then
		unlock()
	else
		local t = getNearestTarget()
		if t then
			lockTarget = t
			if humanoid then humanoid.AutoRotate = false end
			attachBillboard(t)
			lockBtn.Text = "UNLOCK"
			lockBtn.BackgroundColor3 = Color3.fromRGB(206, 36, 36)
			statusLabel.Text = "Locked: " .. t.Name
			statusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
		else
			lockBtn.Text = "NO TARGET"
			statusLabel.Text = "No enemies nearby"
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			task.delay(1, function()
				if not lockTarget then
					lockBtn.Text = "LOCK"
					statusLabel.Text = "Ready"
					statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
				end
			end)
		end
	end
end)

dashLeftBtn.Activated:Connect(function()
	if lockTarget then
		sideDash("left")
	end
end)

dashRightBtn.Activated:Connect(function()
	if lockTarget then
		sideDash("right")
	end
end)

dashBehindBtn.Activated:Connect(function()
	if lockTarget then
		dashBehind()
	end
end)

dashForwardBtn.Activated:Connect(function()
	if lockTarget then
		dashForward()
	end
end)

-- Rotation loop (YOUR WORKING CODE - UNCHANGED)
RunService.RenderStepped:Connect(function()
	if lockTarget and hrp and humanoid and humanoid.Health > 0 then
		local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
		local targetHum = lockTarget:FindFirstChildWhichIsA("Humanoid")
		if targetHRP and targetHum and targetHum.Health > 0 then
			local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
			hrp.CFrame = CFrame.new(hrp.Position, lookPos)
		else
			unlock()
		end
	end
end)

print("JJS Mobile Lock System loaded!")
print("Features: Lock-On, Side Dash, Dash Behind, Dash Forward")
