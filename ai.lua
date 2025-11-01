-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On with Ragdoll/Grab Detection (Improved)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Only run on mobile
if not UserInputService.TouchEnabled then
	return
end

local player = Players.LocalPlayer
local character, humanoid, hrp
local isRagdolled = false -- We still use this from your original script

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
	if humanoid then 
		humanoid.AutoRotate = true 
		
		-- Detect ragdoll state (your original, good logic)
		humanoid.StateChanged:Connect(function(oldState, newState)
			if newState == Enum.HumanoidStateType.Physics or 
			   newState == Enum.HumanoidStateType.Ragdoll or
			   newState == Enum.HumanoidStateType.FallingDown then
				isRagdolled = true
			else
				isRagdolled = false
			end
		end)
	end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

-- GUI (Your original code, no changes)
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

-- Draggable (Your original code, no changes)
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

-- Billboard functions (Your original code, no changes)
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
	-- Small change: Check for player check *within* the character check
	local targetPlayer = Players:GetPlayerFromCharacter(model)
	if targetPlayer and targetPlayer == player then return false end
	return true
end

-- =================================================================
-- -- [IMPROVEMENT 1] -- More efficient target finding
-- =================================================================
-- This function is much faster than using workspace:GetDescendants()
local function getNearestTarget()
	if not hrp then return end
	
	local nearest, dist = nil, MAX_DIST
	local checkedModels = {} -- To avoid checking the same model multiple times
	checkedModels[character] = true -- Don't target self
	
	-- 1. Check other players first (often the highest priority)
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player and pl.Character and isValidTarget(pl.Character) then
			checkedModels[pl.Character] = true -- Add to checked list
			local targetHrp = pl.Character:FindFirstChild("HumanoidRootPart")
			if targetHrp then
				local d = (hrp.Position - targetHrp.Position).Magnitude
				if d < dist then
					dist = d
					nearest = pl.Character
				end
			end
		end
	end

	-- 2. Check other NPCs/entities using an efficient sphere check
	-- We use GetPartsInSphere, which is much faster than GetDescendants
	local partsInSphere = workspace:GetPartsInSphere(hrp.Position, MAX_DIST)
	for _, part in ipairs(partsInSphere) do
		-- Find the model root
		local model = part:FindFirstAncestorOfClass("Model")
		
		-- Check if we have a model, it's not already checked, and it's a valid target
		if model and not checkedModels[model] and isValidTarget(model) then
			checkedModels[model] = true -- Mark as checked
			
			local targetHrp = model:FindFirstChild("HumanoidRootPart")
			if targetHrp then
				local d = (hrp.Position - targetHrp.Position).Magnitude
				if d < dist then
					dist = d
					nearest = model
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

-- Button logic (Your original code, no changes)
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


-- =================================================================
-- -- [IMPROVEMENT 2] -- Better detection for grabs/stuns
-- =================================================================
local function isPlayerIncapacitated()
	if isRagdolled then return true end -- From your existing StateChanged logic
	if not hrp or not humanoid then return true end -- Can't rotate if we don't have these
	
	-- 1. Check if HumanoidRootPart is anchored (common for grabs)
	if hrp.Anchored then return true end
	
	-- 2. Check if player is in PlatformStand (common for stuns)
	if humanoid.PlatformStand then return true end
	
	-- 3. ADD YOUR OWN CHECKS HERE!
	-- Many games use Attributes or BoolValues to signal a stun.
	-- If you know the name, you can check for it.
	-- Example:
	-- if character:GetAttribute("Stunned") == true then return true end
	-- or
	-- if character:FindFirstChild("IsGrabbed") then return true end
	
	return false
end

-- Rotation loop (Now uses the new isPlayerIncapacitated function)
RunService.RenderStepped:Connect(function()
	if lockTarget and hrp and humanoid and humanoid.Health > 0 then
		
		-- MODIFIED LINE: Check using our new, broader function
		-- STOP ROTATING IF RAGDOLLED/GRABBED/STUNNED
		if isPlayerIncapacitated() then
			return -- Skip rotation, keep lock but don't rotate
		end
		
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

print("Mobile Lock System loaded!")
print("Features: Lock-On with Ragdoll/Grab Detection (Improved)")
