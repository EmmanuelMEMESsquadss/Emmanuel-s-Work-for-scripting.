--[[ Enhanced Jujutsu Shenanigans AI with Smart/Aggressive modes ]]
if not game.Players.LocalPlayer.PlayerScripts:FindFirstChild("Loaded") then
	local data = Instance.new("NumberValue")
	data.Name = "Loaded"
	data.Parent = game.Players.LocalPlayer.PlayerScripts
	print("Loaded Scripts")

	-- Rayfield UI
	local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

	-- Services & core refs
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local PathfindingService = game:GetService("PathfindingService")
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
	local workspace = game:GetService("Workspace")

	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local hrp = character:WaitForChild("HumanoidRootPart")

	-- Enhanced AI Configuration for Jujutsu Shenanigans
	local AI_CONFIG = {
		-- Behavior Settings
		SMART_MODE = true,
		
		-- Smart Fighter Configuration
		SMART_SETTINGS = {
			REACTION_TIME = 0.15,
			RETREAT_HEALTH = 30,
			BLOCK_TIMING = 0.7,
			DODGE_CHANCE = 0.6,
			WALL_USAGE = true,
			COMBO_PREDICTION = true,
		},
		
		-- Aggressive Fighter Configuration
		AGGRESSIVE_SETTINGS = {
			REACTION_TIME = 0.05,
			RETREAT_HEALTH = 10,
			BLOCK_TIMING = 0.3,
			DODGE_CHANCE = 0.2,
			WALL_USAGE = false,
			COMBO_PREDICTION = false,
		},
		
		-- Combat Intelligence
		PREDICTION_ACCURACY = 0.75,
		DASH_USAGE = 0.6,
		ENVIRONMENTAL_AWARENESS = true,
	}

	-- Combat States
	local CombatState = {
		IDLE = "Idle",
		STALKING = "Stalking",
		RUSHING = "Rushing",
		ATTACKING = "Attacking",
		BLOCKING = "Blocking", 
		DODGING = "Dodging",
		RETREATING = "Retreating"
	}

	-- Known remote name patterns for Jujutsu Shenanigans
	local KNOWN_ATTACK_REMOTE_PATTERNS = { 
		"attack", "melee", "hit", "skill", "ability", "cast", "fire", "dash", "block", "combo", "m1", "special"
	}

	-- Create main window
	local Window = Rayfield:CreateWindow({
		Name = "🥊 Jujutsu Shenanigans AI",
		LoadingTitle = "Loading Combat AI",
		LoadingSubtitle = "Enhanced Battlegrounds AI",
		ShowText = "JS AI",
		ConfigurationSaving = {
			Enabled = true,
			FolderName = "JujutsuAI", 
			FileName = "CombatAI"
		},
		Discord = {
			Enabled = false,
		},
		KeySystem = false
	})

	Rayfield:Notify({
		Title = "🤖 Combat AI Loaded",
		Content = "Smart & Aggressive fighting modes ready!",
		Duration = 3
	})

	-- Tabs
	local Tab = Window:CreateTab("Universal", 4483362458)
	local AiTab = Window:CreateTab("🤖 Combat AI", 4483362458) 
	local IntelligenceTab = Window:CreateTab("🧠 Intelligence", 4483362458)

	-- Universal controls
	local noclip = false
	local speed = 16
	Tab:CreateToggle({
		Name = "Noclip",
		CurrentValue = false,
		Flag = "Nocliping",
		Callback = function(Value)
			noclip = Value
		end,
	})
	Tab:CreateSlider({
		Name = "Speed",
		Range = {1, 100},
		Increment = 1,
		Suffix = "Speed",
		CurrentValue = 16,
		Flag = "UserSpeed",
		Callback = function(Value)
			speed = Value
			if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
				pcall(function()
					player.Character:WaitForChild("Humanoid").WalkSpeed = Value
				end)
			end
		end,
	})
	Tab:CreateToggle({
		Name = "Xray (visual)",
		CurrentValue = false,
		Flag = "Xray",
		Callback = function(Value)
			for _,v in pairs(workspace:GetDescendants()) do
				if v:IsA("BasePart") then
					v.LocalTransparencyModifier = Value and 0.5 or 0
				end
			end
		end,
	})

	-- Enhanced AI variables
	local aiEnabled = false
	local aiRange = 25
	local approachDistance = 8  -- Combat distance for Jujutsu Shenanigans
	local attackCooldown = 0.3   -- Faster for battlegrounds
	local useAdvancedCombat = true
	local usePathfinding = true
	local combatBehavior = "Smart Fighter" -- or "Aggressive Rusher"

	local aiTarget
	local lastAttackTick = 0
	local currentCombatState = CombatState.IDLE
	local targetMovementHistory = {}
	local predictedPosition = Vector3.new()
	local dangerLevel = 0
	local lastDashTime = 0
	local comboCounter = 0

	-- Enhanced AI Tab
	AiTab:CreateToggle({
		Name = "🤖 Enable Combat AI",
		CurrentValue = false,
		Flag = "AIEnable",
		Callback = function(val)
			aiEnabled = val
			if val then
				Rayfield:Notify({Title="AI", Content="Combat AI Activated!", Duration=2})
			else
				currentCombatState = CombatState.IDLE
				aiTarget = nil
			end
		end
	})

	AiTab:CreateDropdown({
		Name = "🎭 Fighting Style",
		Options = {"Smart Fighter", "Aggressive Rusher"},
		CurrentOption = "Smart Fighter",
		Flag = "FightingStyle",
		Callback = function(Option)
			combatBehavior = Option
			AI_CONFIG.SMART_MODE = (Option == "Smart Fighter")
			Rayfield:Notify({Title="AI", Content="Style: " .. Option, Duration=2})
		end,
	})

	AiTab:CreateSlider({
		Name = "🎯 Detection Range",
		Range = {10, 60},
		Increment = 2,
		CurrentValue = aiRange,
		Flag = "AIRange",
		Callback = function(v) aiRange = v end
	})

	AiTab:CreateSlider({
		Name = "⚔️ Combat Distance", 
		Range = {3, 15},
		Increment = 1,
		CurrentValue = approachDistance,
		Flag = "CombatDistance",
		Callback = function(v) approachDistance = v end
	})

	AiTab:CreateSlider({
		Name = "⚡ Attack Speed",
		Range = {0.1, 1.0},
		Increment = 0.05,
		CurrentValue = attackCooldown,
		Flag = "AttackSpeed",
		Callback = function(v) attackCooldown = v end
	})

	AiTab:CreateToggle({
		Name = "🧠 Advanced Combat",
		CurrentValue = useAdvancedCombat,
		Flag = "AdvancedCombat",
		Callback = function(v) 
			useAdvancedCombat = v
			AI_CONFIG.ENVIRONMENTAL_AWARENESS = v
		end
	})

	-- Intelligence Configuration Tab
	IntelligenceTab:CreateSection("🎯 Prediction Settings")

	IntelligenceTab:CreateSlider({
		Name = "🔮 Movement Prediction",
		Range = {0.1, 1.0},
		Increment = 0.05,
		CurrentValue = AI_CONFIG.PREDICTION_ACCURACY,
		Flag = "PredictionAccuracy",
		Callback = function(v) AI_CONFIG.PREDICTION_ACCURACY = v end
	})

	IntelligenceTab:CreateSlider({
		Name = "💨 Dash Usage Rate",
		Range = {0.1, 1.0},
		Increment = 0.05,
		CurrentValue = AI_CONFIG.DASH_USAGE,
		Flag = "DashUsage", 
		Callback = function(v) AI_CONFIG.DASH_USAGE = v end
	})

	IntelligenceTab:CreateSection("🥊 Combat Behavior")

	IntelligenceTab:CreateSlider({
		Name = "⚡ Smart Reaction Time",
		Range = {0.05, 0.5},
		Increment = 0.01,
		CurrentValue = AI_CONFIG.SMART_SETTINGS.REACTION_TIME,
		Flag = "SmartReaction",
		Callback = function(v) AI_CONFIG.SMART_SETTINGS.REACTION_TIME = v end
	})

	IntelligenceTab:CreateSlider({
		Name = "🔥 Aggressive Reaction Time", 
		Range = {0.01, 0.3},
		Increment = 0.01,
		CurrentValue = AI_CONFIG.AGGRESSIVE_SETTINGS.REACTION_TIME,
		Flag = "AggressiveReaction",
		Callback = function(v) AI_CONFIG.AGGRESSIVE_SETTINGS.REACTION_TIME = v end
	})

	IntelligenceTab:CreateSlider({
		Name = "🛡️ Block Timing (Smart)",
		Range = {0.1, 1.0},
		Increment = 0.05,
		CurrentValue = AI_CONFIG.SMART_SETTINGS.BLOCK_TIMING,
		Flag = "BlockTiming",
		Callback = function(v) AI_CONFIG.SMART_SETTINGS.BLOCK_TIMING = v end
	})

	IntelligenceTab:CreateToggle({
		Name = "🧱 Environmental Usage",
		CurrentValue = AI_CONFIG.ENVIRONMENTAL_AWARENESS,
		Flag = "Environmental",
		Callback = function(v) AI_CONFIG.ENVIRONMENTAL_AWARENESS = v end
	})

	-- Target selection button
	AiTab:CreateButton({
		Name = "🎯 Lock Nearest Target",
		Callback = function()
			local found, d = getNearestPlayerWithin(aiRange)
			if found then
				aiTarget = found
				Rayfield:Notify({Title="🎯 Target", Content=("Locked: %s (%.1f studs)"):format(found.Name, d), Duration=3})
			else
				Rayfield:Notify({Title="❌ No Target", Content="No valid enemies in range", Duration=2})
			end
		end
	})

	-- Character/respawn handling
	local function refreshCharacterRefs()
		character = player.Character or player.CharacterAdded:Wait()
		humanoid = character:WaitForChild("Humanoid")
		hrp = character:WaitForChild("HumanoidRootPart")
	end
	player.CharacterAdded:Connect(function() task.wait(0.1); refreshCharacterRefs() end)

	-- Enhanced target finding with intelligence
	function getNearestPlayerWithin(range)
		local best, bestDist = nil, math.huge
		if not hrp then return nil end
		for _,plr in pairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					local targetHRP = plr.Character:FindFirstChild("HumanoidRootPart")
					if targetHRP then
						local d = (targetHRP.Position - hrp.Position).Magnitude
						if d < bestDist and d <= range then
							best = plr; bestDist = d
						end
					end
				end
			end
		end
		return best, bestDist
	end

	-- Enhanced movement prediction
	local function updateTargetPrediction(targetPlayer)
		if not targetPlayer or not targetPlayer.Character then return end
		
		local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not targetHRP then return end
		
		-- Store movement history
		local currentPos = targetHRP.Position
		table.insert(targetMovementHistory, {pos = currentPos, time = tick()})
		
		-- Keep only recent history  
		if #targetMovementHistory > 10 then
			table.remove(targetMovementHistory, 1)
		end
		
		-- Calculate predicted position
		if #targetMovementHistory >= 2 then
			local recent = targetMovementHistory[#targetMovementHistory]
			local previous = targetMovementHistory[#targetMovementHistory - 1]
			local velocity = (recent.pos - previous.pos) / (recent.time - previous.time)
			
			local reactionTime = AI_CONFIG.SMART_MODE and AI_CONFIG.SMART_SETTINGS.REACTION_TIME or AI_CONFIG.AGGRESSIVE_SETTINGS.REACTION_TIME
			predictedPosition = currentPos + (velocity * reactionTime * AI_CONFIG.PREDICTION_ACCURACY)
		else
			predictedPosition = currentPos
		end
	end

	-- Danger assessment for smart AI
	local function assessDanger(targetPlayer)
		if not targetPlayer or not targetPlayer.Character then return 0 end
		
		local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not targetHRP or not hrp then return 0 end
		
		local distance = (hrp.Position - targetHRP.Position).Magnitude
		local healthPercent = humanoid.Health / humanoid.MaxHealth
		
		local danger = 0
		
		-- Distance danger
		if distance < 5 then danger = danger + 0.7
		elseif distance < 10 then danger = danger + 0.4
		elseif distance < 15 then danger = danger + 0.2
		
		-- Health danger
		if healthPercent < 0.2 then danger = danger + 0.8
		elseif healthPercent < 0.5 then danger = danger + 0.4
		
		-- Environmental dangers (walls, obstacles)
		if AI_CONFIG.ENVIRONMENTAL_AWARENESS then
			local raycast = workspace:Raycast(hrp.Position, (targetHRP.Position - hrp.Position).Unit * 8)
			if raycast then danger = danger + 0.3 end
		end
		
		return math.min(danger, 1.0)
	end

	-- Enhanced combat state management
	local function updateCombatState(targetPlayer)
		if not targetPlayer or not targetPlayer.Character then 
			currentCombatState = CombatState.IDLE
			return
		end
		
		local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not targetHRP then return end
		
		local distance = (hrp.Position - targetHRP.Position).Magnitude
		dangerLevel = assessDanger(targetPlayer)
		
		local config = AI_CONFIG.SMART_MODE and AI_CONFIG.SMART_SETTINGS or AI_CONFIG.AGGRESSIVE_SETTINGS
		
		if AI_CONFIG.SMART_MODE then
			-- Smart Fighter Logic
			if humanoid.Health < config.RETREAT_HEALTH then
				currentCombatState = CombatState.RETREATING
			elseif dangerLevel > config.BLOCK_TIMING and math.random() < 0.6 then
				currentCombatState = CombatState.BLOCKING
			elseif dangerLevel > config.DODGE_CHANCE and math.random() < 0.4 then
				currentCombatState = CombatState.DODGING
			elseif distance > approachDistance + 3 then
				currentCombatState = CombatState.STALKING
			elseif distance <= approachDistance then
				currentCombatState = CombatState.ATTACKING
			else
				currentCombatState = CombatState.STALKING
			end
		else
			-- Aggressive Fighter Logic
			if humanoid.Health < config.RETREAT_HEALTH then
				currentCombatState = CombatState.RETREATING
			elseif distance > approachDistance + 5 then
				currentCombatState = CombatState.RUSHING
			elseif distance <= approachDistance then
				currentCombatState = CombatState.ATTACKING
			else
				currentCombatState = CombatState.RUSHING
			end
		end
	end

	-- Face target with smooth rotation
	local function faceTarget(targetPos, smoothing)
		if not hrp or not targetPos then return end
		smoothing = smoothing or 0.1
		
		local myPos = hrp.Position
		local lookDirection = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
		local targetCFrame = CFrame.new(myPos, lookDirection)
		
		pcall(function()
			hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, smoothing)
		end)
	end

	-- Enhanced attack system
	local function performEnhancedAttack(targetPlayer)
		if not targetPlayer or not targetPlayer.Character then return end
		
		local now = tick()
		if now - lastAttackTick < attackCooldown then return end
		lastAttackTick = now
		
		local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not targetHRP then return end
		
		-- Face predicted position for smart mode
		local facePos = AI_CONFIG.SMART_MODE and predictedPosition or targetHRP.Position
		faceTarget(facePos, 0.15)
		
		-- Enhanced attack sequence
		if useAdvancedCombat then
			-- Try combo system for Jujutsu Shenanigans
			comboCounter = comboCounter + 1
			
			-- M1 combo simulation
			for i = 1, (AI_CONFIG.SMART_MODE and 3 or 4) do
				-- Try tool activation
				local tool = character:FindFirstChildOfClass("Tool") or player.Backpack:FindFirstChildOfClass("Tool")
				if tool then
					pcall(function() tool:Activate() end)
				end
				
				-- Fire attack remotes
				for _,obj in ipairs(game:GetDescendants()) do
					if obj:IsA("RemoteEvent") then
						local lname = obj.Name:lower()
						for _,pattern in ipairs(KNOWN_ATTACK_REMOTE_PATTERNS) do
							if lname:find(pattern) then
								pcall(function()
									obj:FireServer(targetPlayer)
									obj:FireServer(targetHRP)
								end)
								break
							end
						end
					end
				end
				
				-- Combo timing
				if i < (AI_CONFIG.SMART_MODE and 3 or 4) then
					task.wait(0.15)
				end
			end
			
			-- Reset combo after sequence
			if comboCounter >= 4 then
				comboCounter = 0
			end
		else
			-- Basic attack
			local tool = character:FindFirstChildOfClass("Tool")
			if tool then
				pcall(function() tool:Activate() end)
			end
		end
	end

	-- Enhanced dash system
	local function performDash(targetPlayer)
		local now = tick()
		if now - lastDashTime < 1.5 then return end -- Dash cooldown
		
		if math.random() > AI_CONFIG.DASH_USAGE then return end
		
		local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not targetHRP then return end
		
		-- Dash toward predicted position
		local dashTarget = AI_CONFIG.SMART_MODE and predictedPosition or targetHRP.Position
		local direction = (dashTarget - hrp.Position).Unit
		
		-- Try dash remotes
		for _,obj in ipairs(game:GetDescendants()) do
			if obj:IsA("RemoteEvent") and obj.Name:lower():find("dash") then
				pcall(function() obj:FireServer() end)
				break
			end
		end
		
		-- Movement dash
		humanoid:MoveTo(hrp.Position + direction * 12)
		lastDashTime = now
	end

	-- Advanced pathfinding movement
	local function moveToPositionAdvanced(targetPos, stopDistance, usePrediction)
		stopDistance = stopDistance or 2
		if not humanoid or not hrp then return end
		
		local finalTarget = usePrediction and predictedPosition or targetPos
