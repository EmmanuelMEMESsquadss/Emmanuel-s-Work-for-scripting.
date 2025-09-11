-- Mobile Arceus X Script for Jujutsu Shenanigans
-- Intelligent AI System with Rayfield UI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character, humanoid, hrp

-- Load Rayfield UI Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- AI Intelligence Configuration
local AI_INTELLIGENCE = {
	-- Combat Behaviors
	SMART_MODE = true,
	AGGRESSIVE_MODE = false,
	
	-- Smart AI Settings
	SMART_CONFIG = {
		REACTION_TIME = 0.15,
		COMBO_PREDICTION = true,
		ENVIRONMENTAL_AWARENESS = true,
		DODGE_ANTICIPATION = 0.8,
		BLOCK_TIMING = 0.7,
		RETREAT_HEALTH_THRESHOLD = 30,
		WALL_USAGE = true,
		STAMINA_MANAGEMENT = true,
	},
	
	-- Aggressive AI Settings
	AGGRESSIVE_CONFIG = {
		REACTION_TIME = 0.05,
		COMBO_CONTINUATION = true,
		RUSH_FREQUENCY = 0.9,
		DODGE_ANTICIPATION = 0.4,
		BLOCK_TIMING = 0.3,
		RETREAT_HEALTH_THRESHOLD = 10,
		WALL_USAGE = false,
		STAMINA_MANAGEMENT = false,
	},
	
	-- General Settings (configurable via sliders)
	MAX_LOCK_DISTANCE = 80,
	MIN_COMBAT_DISTANCE = 8,
	MAX_COMBAT_DISTANCE = 25,
	MOVEMENT_SPEED = 16,
	PREDICTION_ACCURACY = 0.75,
	COMBO_TIMING = 0.3,
	DASH_USAGE_RATE = 0.6,
	BLOCK_EFFICIENCY = 0.8,
}

-- Jujutsu Shenanigans Combat States
local CombatState = {
	IDLE = "Idle",
	STALKING = "Stalking", -- Smart behavior
	RUSHING = "Rushing", -- Aggressive behavior
	COMBO_EXECUTING = "ComboExecuting",
	BLOCKING = "Blocking",
	DODGING = "Dodging",
	RETREATING = "Retreating",
	WALL_RUNNING = "WallRunning",
	COUNTER_ATTACKING = "CounterAttacking",
	ABILITY_CASTING = "AbilityCasting"
}

-- AI State Variables
local currentState = CombatState.IDLE
local lockTarget = nil
local isAIEnabled = false
local combatTimer = 0
local lastDashTime = 0
local lastBlockTime = 0
local comboCounter = 0
local predictedTargetPosition = Vector3.new()
local wallRunDirection = 1
local retreatTimer = 0

-- Combat Intelligence Variables
local targetLastPosition = Vector3.new()
local targetVelocity = Vector3.new()
local targetMovementPattern = {}
local dangerLevel = 0
local stamina = 100

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
	
	if humanoid then 
		humanoid.WalkSpeed = AI_INTELLIGENCE.MOVEMENT_SPEED
		humanoid.JumpPower = 50
	end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

-- Create Rayfield UI
local Window = Rayfield:CreateWindow({
	Name = "🥊 Jujutsu Shenanigans AI",
	LoadingTitle = "Battlegrounds AI",
	LoadingSubtitle = "by Advanced Combat System",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "JujutsuAI",
		FileName = "AIConfig"
	},
	Discord = {
		Enabled = false,
	},
	KeySystem = false,
})

-- Main Combat Tab
local CombatTab = Window:CreateTab("⚔️ Combat AI", nil)

-- AI Behavior Section
local BehaviorSection = CombatTab:CreateSection("🧠 AI Behavior")

local BehaviorToggle = CombatTab:CreateToggle({
	Name = "🤖 Enable Combat AI",
	CurrentValue = false,
	Flag = "AIEnabled",
	Callback = function(Value)
		isAIEnabled = Value
		if not Value then
			lockTarget = nil
			currentState = CombatState.IDLE
		end
	end,
})

local BehaviorMode = CombatTab:CreateDropdown({
	Name = "🎭 Combat Behavior",
	Options = {"Smart Fighter", "Aggressive Rusher"},
	CurrentOption = "Smart Fighter",
	Flag = "BehaviorMode",
	Callback = function(Option)
		if Option == "Smart Fighter" then
			AI_INTELLIGENCE.SMART_MODE = true
			AI_INTELLIGENCE.AGGRESSIVE_MODE = false
		else
			AI_INTELLIGENCE.SMART_MODE = false
			AI_INTELLIGENCE.AGGRESSIVE_MODE = true
		end
	end,
})

-- Combat Configuration Section
local ConfigSection = CombatTab:CreateSection("⚙️ Combat Configuration")

local LockDistanceSlider = CombatTab:CreateSlider({
	Name = "🎯 Lock Distance",
	Range = {20, 150},
	Increment = 5,
	CurrentValue = 80,
	Flag = "LockDistance",
	Callback = function(Value)
		AI_INTELLIGENCE.MAX_LOCK_DISTANCE = Value
	end,
})

local CombatDistanceSlider = CombatTab:CreateSlider({
	Name = "⚔️ Combat Distance",
	Range = {5, 40},
	Increment = 1,
	CurrentValue = 25,
	Flag = "CombatDistance",
	Callback = function(Value)
		AI_INTELLIGENCE.MAX_COMBAT_DISTANCE = Value
	end,
})

local ReactionTimeSlider = CombatTab:CreateSlider({
	Name = "⚡ Reaction Speed",
	Range = {0.05, 0.5},
	Increment = 0.01,
	CurrentValue = 0.15,
	Flag = "ReactionTime",
	Callback = function(Value)
		if AI_INTELLIGENCE.SMART_MODE then
			AI_INTELLIGENCE.SMART_CONFIG.REACTION_TIME = Value
		else
			AI_INTELLIGENCE.AGGRESSIVE_CONFIG.REACTION_TIME = Value
		end
	end,
})

local PredictionSlider = CombatTab:CreateSlider({
	Name = "🔮 Movement Prediction",
	Range = {0.1, 1.0},
	Increment = 0.05,
	CurrentValue = 0.75,
	Flag = "Prediction",
	Callback = function(Value)
		AI_INTELLIGENCE.PREDICTION_ACCURACY = Value
	end,
})

local ComboTimingSlider = CombatTab:CreateSlider({
	Name = "🥊 Combo Timing",
	Range = {0.1, 0.8},
	Increment = 0.05,
	CurrentValue = 0.3,
	Flag = "ComboTiming",
	Callback = function(Value)
		AI_INTELLIGENCE.COMBO_TIMING = Value
	end,
})

local DashUsageSlider = CombatTab:CreateSlider({
	Name = "💨 Dash Usage Rate",
	Range = {0.1, 1.0},
	Increment = 0.05,
	CurrentValue = 0.6,
	Flag = "DashUsage",
	Callback = function(Value)
		AI_INTELLIGENCE.DASH_USAGE_RATE = Value
	end,
})

local BlockEfficiencySlider = CombatTab:CreateSlider({
	Name = "🛡️ Block Efficiency",
	Range = {0.1, 1.0},
	Increment = 0.05,
	CurrentValue = 0.8,
	Flag = "BlockEfficiency",
	Callback = function(Value)
		AI_INTELLIGENCE.BLOCK_EFFICIENCY = Value
	end,
})

-- Advanced Settings Tab
local AdvancedTab = Window:CreateTab("🔧 Advanced", nil)

local AdvancedSection = AdvancedTab:CreateSection("🏗️ Advanced Combat")

local WallUsageToggle = AdvancedTab:CreateToggle({
	Name = "🧱 Use Wall Running",
	CurrentValue = true,
	Flag = "WallUsage",
	Callback = function(Value)
		AI_INTELLIGENCE.SMART_CONFIG.WALL_USAGE = Value
		AI_INTELLIGENCE.AGGRESSIVE_CONFIG.WALL_USAGE = Value
	end,
})

local StaminaToggle = AdvancedTab:CreateToggle({
	Name = "🏃 Stamina Management",
	CurrentValue = true,
	Flag = "StaminaManagement",
	Callback = function(Value)
		AI_INTELLIGENCE.SMART_CONFIG.STAMINA_MANAGEMENT = Value
	end,
})

local EnvironmentalToggle = AdvancedTab:CreateToggle({
	Name = "🌍 Environmental Awareness",
	CurrentValue = true,
	Flag = "Environmental",
	Callback = function(Value)
		AI_INTELLIGENCE.SMART_CONFIG.ENVIRONMENTAL_AWARENESS = Value
	end,
})

-- Combat Intelligence Functions
local function getCurrentConfig()
	return AI_INTELLIGENCE.SMART_MODE and AI_INTELLIGENCE.SMART_CONFIG or AI_INTELLIGENCE.AGGRESSIVE_CONFIG
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

local function findNearestTarget()
	if not hrp then return nil end
	local nearest, nearestDist = nil, AI_INTELLIGENCE.MAX_LOCK_DISTANCE
	
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player and pl.Character and isValidTarget(pl.Character) then
			local dist = (hrp.Position - pl.Character.HumanoidRootPart.Position).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearest = pl.Character
			end
		end
	end
	
	return nearest
end

-- Advanced Target Prediction
local function updateTargetPrediction()
	if not lockTarget or not hrp then return end
	
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end
	
	-- Calculate velocity
	local currentPos = targetHRP.Position
	local deltaTime = 0.1
	targetVelocity = (currentPos - targetLastPosition) / deltaTime
	targetLastPosition = currentPos
	
	-- Predict future position
	local predictionTime = getCurrentConfig().REACTION_TIME * AI_INTELLIGENCE.PREDICTION_ACCURACY
	predictedTargetPosition = currentPos + (targetVelocity * predictionTime)
	
	-- Store movement pattern for learning
	table.insert(targetMovementPattern, {
		position = currentPos,
		velocity = targetVelocity,
		timestamp = tick()
	})
	
	-- Keep only recent patterns
	if #targetMovementPattern > 20 then
		table.remove(targetMovementPattern, 1)
	end
end

-- Danger Assessment
local function assessDangerLevel()
	if not lockTarget or not hrp then return 0 end
	
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return 0 end
	
	local distance = (hrp.Position - targetHRP.Position).Magnitude
	local danger = 0
	
	-- Distance-based danger
	if distance < 10 then danger = danger + 0.6
	elseif distance < 20 then danger = danger + 0.3
	
	-- Health-based danger
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if healthPercent < 0.3 then danger = danger + 0.7
	elseif healthPercent < 0.6 then danger = danger + 0.3
	
	-- Environmental danger (walls, obstacles)
	local raycast = workspace:Raycast(hrp.Position, (targetHRP.Position - hrp.Position).Unit * 10)
	if raycast then danger = danger + 0.2 end
	
	return math.min(danger, 1.0)
end

-- Combat Actions
local function performM1Combo()
	if not lockTarget then return end
	
	-- Simulate M1 attacks based on combo timing
	for i = 1, 4 do
		-- Wait for combo timing
		task.wait(AI_INTELLIGENCE.COMBO_TIMING)
		
		if not lockTarget or not isAIEnabled then break end
		
		-- Simulate click for M1
		-- In actual implementation, you'd trigger the M1 attack here
		comboCounter = comboCounter + 1
		
		-- Smart behavior: adjust timing based on target movement
		if AI_INTELLIGENCE.SMART_MODE and targetVelocity.Magnitude > 5 then
			task.wait(0.1) -- Slight delay to account for movement
		end
	end
	
	comboCounter = 0
end

local function performDash()
	if not lockTarget or not hrp then return end
	
	local currentTime = tick()
	if currentTime - lastDashTime < 2 then return end -- Cooldown
	
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end
	
	-- Smart dash: toward predicted position
	-- Aggressive dash: directly at target
	local dashTarget = AI_INTELLIGENCE.SMART_MODE and predictedTargetPosition or targetHRP.Position
	local dashDirection = (dashTarget - hrp.Position).Unit
	
	-- Simulate dash (Q key)
	-- In actual implementation, you'd trigger the dash here
	humanoid:MoveTo(hrp.Position + dashDirection * 15)
	lastDashTime = currentTime
end

local function performBlock()
	if not lockTarget then return end
	
	local currentTime = tick()
	local config = getCurrentConfig()
	
	-- Intelligent blocking based on danger level and timing
	if dangerLevel > config.BLOCK_TIMING and currentTime - lastBlockTime > 1 then
		-- Simulate block (F key)
		-- In actual implementation, you'd trigger the block here
		lastBlockTime = currentTime
		return true
	end
	
	return false
end

local function performWallRun()
	if not getCurrentConfig().WALL_USAGE or not hrp then return end
	
	-- Check for nearby walls
	local directions = {
		Vector3.new(1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, 0, -1)
	}
	
	for _, direction in ipairs(directions) do
		local raycast = workspace:Raycast(hrp.Position, direction * 10)
		if raycast and raycast.Instance then
			-- Wall detected, perform wall run
			local wallNormal = raycast.Normal
			local runDirection = wallNormal:Cross(Vector3.new(0, 1, 0))
			
			humanoid:MoveTo(hrp.Position + runDirection * wallRunDirection * 10)
			humanoid.Jump = true
			
			wallRunDirection = wallRunDirection * -1 -- Alternate direction
			return true
		end
	end
	
	return false
end

-- Intelligent State Management
local function updateCombatState()
	if not lockTarget or not hrp or not isAIEnabled then
		currentState = CombatState.IDLE
		return
	end
	
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	if not targetHRP then
		currentState = CombatState.IDLE
		return
	end
	
	local distance = (hrp.Position - targetHRP.Position).Magnitude
	local config = getCurrentConfig()
	dangerLevel = assessDangerLevel()
	
	-- State transitions based on AI behavior
	if AI_INTELLIGENCE.SMART_MODE then
		-- Smart Fighter Logic
		if dangerLevel > 0.7 and humanoid.Health < config.RETREAT_HEALTH_THRESHOLD then
			currentState = CombatState.RETREATING
		elseif dangerLevel > config.DODGE_ANTICIPATION then
			currentState = math.random() < 0.7 and CombatState.DODGING or CombatState.BLOCKING
		elseif distance > AI_INTELLIGENCE.MAX_COMBAT_DISTANCE then
			currentState = CombatState.STALKING
		elseif distance <= AI_INTELLIGENCE.MIN_COMBAT_DISTANCE then
			currentState = CombatState.COMBO_EXECUTING
		else
			currentState = CombatState.COUNTER_ATTACKING
		end
	else
		-- Aggressive Fighter Logic
		if humanoid.Health < config.RETREAT_HEALTH_THRESHOLD then
			currentState = CombatState.RETREATING
		elseif distance > AI_INTELLIGENCE.MAX_COMBAT_DISTANCE then
			currentState = CombatState.RUSHING
		else
			currentState = math.random() < 0.8 and CombatState.COMBO_EXECUTING or CombatState.DODGING
		end
	end
end

-- Advanced Combat Execution
local function executeSmartCombat()
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end
	
	if currentState == CombatState.STALKING then
		-- Careful approach with environmental usage
		if performWallRun() then return end
		
		local approachPos = predictedTargetPosition + (hrp.Position - targetHRP.Position).Unit * AI_INTELLIGENCE.MAX_COMBAT_DISTANCE
		humanoid:MoveTo(approachPos)
		
		if math.random() < AI_INTELLIGENCE.DASH_USAGE_RATE then
			task.spawn(performDash)
		end
		
	elseif currentState == CombatState.COUNTER_ATTACKING then
		-- Wait for opening, then strike
		if not performBlock() then
			task.spawn(performM1Combo)
		end
		
	elseif currentState == CombatState.RETREATING then
		-- Strategic retreat with wall usage
		local retreatDirection = (hrp.Position - targetHRP.Position).Unit
		local retreatPos = hrp.Position + retreatDirection * 20
		
		if performWallRun() then return end
		humanoid:MoveTo(retreatPos)
		
		if math.random() < 0.8 then
			task.spawn(performDash)
		end
	end
end

local function executeAggressiveCombat()
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end
	
	if currentState == CombatState.RUSHING then
		-- Direct aggressive approach
		humanoid:MoveTo(targetHRP.Position)
		
		if math.random() < 0.9 then
			task.spawn(performDash)
		end
		
	elseif currentState == CombatState.COMBO_EXECUTING then
		-- Continuous combo attacks
		task.spawn(performM1Combo)
		
	elseif currentState == CombatState.RETREATING then
		-- Quick retreat and re-engage
		local retreatDirection = (hrp.Position - targetHRP.Position).Unit
		humanoid:MoveTo(hrp.Position + retreatDirection * 15)
		
		task.wait(1)
		if lockTarget then
			currentState = CombatState.RUSHING
		end
	end
end

-- Main AI Update Function
local function updateAI()
	if not isAIEnabled or not lockTarget then return end
	
	-- Auto-target if no target
	if not lockTarget then
		lockTarget = findNearestTarget()
		if not lockTarget then return end
	end
	
	-- Validate target
	if not isValidTarget(lockTarget) then
		lockTarget = nil
		return
	end
	
	-- Update AI intelligence
	updateTargetPrediction()
	updateCombatState()
	
	-- Execute behavior
	if AI_INTELLIGENCE.SMART_MODE then
		executeSmartCombat()
	else
		executeAggressiveCombat()
	end
	
	-- Handle rotation
	local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
	if targetHRP and currentState ~= CombatState.RETREATING then
		local lookPos = Vector3.new(targetHRP.Position.X, hrp.Position.Y, targetHRP.Position.Z)
		hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(hrp.Position, lookPos), 0.1)
	end
end

-- Auto-targeting system
task.spawn(function()
	while true do
		task.wait(0.5)
		if isAIEnabled and not lockTarget then
			lockTarget = findNearestTarget()
		end
	end
end)

-- Main AI Loop
RunService.Heartbeat:Connect(function()
	if isAIEnabled then
		task.spawn(updateAI)
	end
end)

-- Load saved configuration
Rayfield:LoadConfiguration()
