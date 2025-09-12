--[[ Jujutsu Shenanigans Script for Arceus X Mobile ]]

if not game.Players.LocalPlayer.PlayerScripts:FindFirstChild("Loaded") then 
	local data = Instance.new("NumberValue")
	data.Name = "Loaded" 
	data.Parent = game.Players.LocalPlayer.PlayerScripts 
	print("Jujutsu Shenanigans Script Loaded")

-- Load Rayfield UI Library with error handling
local Rayfield
do
    local ok
    ok, Rayfield = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if not ok or not Rayfield then
        -- fallback attempt
        pcall(function()
            Rayfield = loadstring(game:HttpGet("https://raw.githack.com/sirius/menu/main/rayfield"))()
        end)
    end
    if not Rayfield then
        warn("[JJS Script] Rayfield failed to load. UI will not appear. Check network/executor.")
        return
    end
end

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

-- Player Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Update references on respawn
player.CharacterAdded:Connect(function(chr)
    character = chr
    humanoid = character:WaitForChild("Humanoid")
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
end)

-- Script Variables
local autoBlock = false
local espEnabled = false
local noclip = false
local infJump = false
local fly = false
local currentSpeed = 16
local blockRange = 20
local autoBlockConnection = nil

-- Enhanced Auto Block Variables (Non-freezing)
local blockQueue = {}
local isProcessingBlock = false
local lastBlockTime = 0
local blockCooldown = 0.3

-- VIM setup with better error handling
local VIM = nil
pcall(function()
    VIM = game:GetService("VirtualInputManager")
end)

-- Create Main Window (only if Rayfield loaded successfully)
local Window
if Rayfield then
	Window = Rayfield:CreateWindow({
		Name = "Jujutsu Shenanigans Enhanced",
		LoadingTitle = "Loading JJS Script", 
		LoadingSubtitle = "Mobile Optimized Combat System",
		ShowText = "JJS Pro",
		ConfigurationSaving = {
			Enabled = true,
			FolderName = "JujutsuShenanigans",
			FileName = "Config"
		},
		Discord = {
			Enabled = false,
			Invite = "",
			RememberJoins = true
		},
		KeySystem = false
	})

	-- Notification
	Rayfield:Notify({
		Title = "JJS Enhanced Script",
		Content = "Mobile-optimized script loaded! Non-freezing auto block ready",
		Duration = 4
	})
end

-- Create Tabs (only if Window was created successfully)
local CombatTab, PlayerTab, VisualTab, UtilityTab

if Window then
	CombatTab = Window:CreateTab("Combat", 4483362458)
	PlayerTab = Window:CreateTab("Movement", 4483362458) 
	VisualTab = Window:CreateTab("Visual", 4483362458)
	UtilityTab = Window:CreateTab("Utility", 4483362458)
end

-- COMBAT FEATURES (only if CombatTab exists)
if CombatTab then
	CombatTab:CreateSection("Auto Block System")
	
	-- Auto Block Toggle (Completely Rewritten)
	local AutoBlockToggle = CombatTab:CreateToggle({
		Name = "Non-Freezing Auto Block",
		CurrentValue = false,
		Flag = "AutoBlock",
		Callback = function(Value)
			autoBlock = Value
			if autoBlock then
				startNonFreezingAutoBlock()
				if Rayfield then
					Rayfield:Notify({
						Title = "Auto Block",
						Content = "Mobile-friendly auto block enabled!",
						Duration = 3
					})
				end
			else
				stopNonFreezingAutoBlock()
			end
		end,
	})

	-- Block Range Slider
	CombatTab:CreateSlider({
		Name = "Detection Range",
		Range = {8, 30},
		Increment = 1,
		Suffix = "Studs",
		CurrentValue = 20,
		Flag = "BlockRange",
		Callback = function(Value)
			blockRange = Value
		end,
	})

	-- Block Response Time
	CombatTab:CreateSlider({
		Name = "Response Speed",
		Range = {0.1, 1.0},
		Increment = 0.1,
		Suffix = "Seconds",
		CurrentValue = 0.3,
		Flag = "BlockCooldown",
		Callback = function(Value)
			blockCooldown = Value
		end,
	})

	-- Manual Block Test
	CombatTab:CreateButton({
		Name = "Test Block (Manual)",
		Callback = function()
			queueBlock("Manual Test")
			if Rayfield then
				Rayfield:Notify({
					Title = "Block Test",
					Content = "Testing block function - Should not freeze!",
					Duration = 2
				})
			end
		end
	})
end

-- MOVEMENT FEATURES (only if PlayerTab exists)
if PlayerTab then
	PlayerTab:CreateSection("Movement Enhancements")
	
	-- Speed Hack
	PlayerTab:CreateSlider({
		Name = "Walk Speed",
		Range = {16, 100},
		Increment = 1,
		Suffix = "Speed",
		CurrentValue = 16,
		Flag = "WalkSpeed",
		Callback = function(Value)
			currentSpeed = Value
			if character and character:FindFirstChild("Humanoid") then
				character.Humanoid.WalkSpeed = Value
			end
		end,
	})

	-- Jump Power
	PlayerTab:CreateSlider({
		Name = "Jump Power",
		Range = {50, 200},
		Increment = 5,
		Suffix = "Power",
		CurrentValue = 50,
		Flag = "JumpPower",
		Callback = function(Value)
			if character and character:FindFirstChild("Humanoid") then
				character.Humanoid.JumpPower = Value
			end
		end,
	})

	-- Infinite Jump
	PlayerTab:CreateToggle({
		Name = "Infinite Jump",
		CurrentValue = false,
		Flag = "InfJump",
		Callback = function(Value)
			infJump = Value
		end,
	})

	-- Noclip Toggle
	PlayerTab:CreateToggle({
		Name = "Noclip",
		CurrentValue = false,
		Flag = "Noclip",
		Callback = function(Value)
			noclip = Value
		end,
	})

	-- Fly Toggle
	PlayerTab:CreateToggle({
		Name = "Fly",
		CurrentValue = false,
		Flag = "Fly",
		Callback = function(Value)
			fly = Value
			if fly then
				startFly()
			else
				stopFly()
			end
		end,
	})

	PlayerTab:CreateSection("Quick Teleports")

	-- Teleport to Spawn
	PlayerTab:CreateButton({
		Name = "Teleport to Spawn",
		Callback = function()
			if character and character:FindFirstChild("HumanoidRootPart") then
				character.HumanoidRootPart.CFrame = CFrame.new(0, 50, 0)
			end
		end
	})

	-- Teleport to Random Player
	PlayerTab:CreateButton({
		Name = "Teleport to Random Player",
		Callback = function()
			teleportToRandomPlayer()
		end
	})
end

-- VISUAL FEATURES (only if VisualTab exists)
if VisualTab then
	VisualTab:CreateSection("Player ESP")
	
	-- ESP Toggle
	VisualTab:CreateToggle({
		Name = "Player ESP",
		CurrentValue = false,
		Flag = "ESP",
		Callback = function(Value)
			espEnabled = Value
			if espEnabled then
				enableESP()
			else
				disableESP()
			end
		end,
	})

	-- Highlight All Players
	VisualTab:CreateButton({
		Name = "Highlight All Players",
		Callback = function()
			highlightAllPlayers()
		end
	})

	VisualTab:CreateSection("World Modifications")

	-- Full Bright
	VisualTab:CreateToggle({
		Name = "Full Bright",
		CurrentValue = false,
		Flag = "FullBright",
		Callback = function(Value)
			if Value then
				Lighting.Brightness = 5
				Lighting.Ambient = Color3.new(1, 1, 1)
			else
				Lighting.Brightness = 1
				Lighting.Ambient = Color3.new(0, 0, 0)
			end
		end,
	})

	-- Remove Fog
	VisualTab:CreateToggle({
		Name = "Remove Fog",
		CurrentValue = false,
		Flag = "NoFog",
		Callback = function(Value)
			if Value then
				Lighting.FogEnd = 100000
			else
				Lighting.FogEnd = 100
			end
		end,
	})
end

-- UTILITY FEATURES (only if UtilityTab exists)
if UtilityTab then
	UtilityTab:CreateSection("Game Utilities")

	-- Anti-AFK
	UtilityTab:CreateToggle({
		Name = "Anti-AFK",
		CurrentValue = false,
		Flag = "AntiAFK",
		Callback = function(Value)
			if Value then
				startAntiAFK()
			else
				stopAntiAFK()
			end
		end,
	})

	-- Server Hop
	UtilityTab:CreateButton({
		Name = "Server Hop",
		Callback = function()
			serverHop()
		end
	})

	-- Rejoin Server
	UtilityTab:CreateButton({
		Name = "Rejoin Server",
		Callback = function()
			game:GetService("TeleportService"):Teleport(game.PlaceId, player)
		end
	})

	UtilityTab:CreateSection("Performance")

	-- Remove Lag
	UtilityTab:CreateButton({
		Name = "Optimize Performance",
		Callback = function()
			optimizePerformance()
		end
	})

	-- Remove Textures
	UtilityTab:CreateToggle({
		Name = "Remove Textures (FPS Boost)",
		CurrentValue = false,
		Flag = "NoTextures",
		Callback = function(Value)
			removeTextures(Value)
		end,
	})
end

-- ENHANCED NON-FREEZING AUTO BLOCK SYSTEM
function queueBlock(reason)
	table.insert(blockQueue, {
		time = tick(),
		reason = reason or "Auto Block"
	})
end

function processBlockQueue()
	if isProcessingBlock or #blockQueue == 0 then return end
	if (tick() - lastBlockTime) < blockCooldown then return end
	
	isProcessingBlock = true
	local blockRequest = table.remove(blockQueue, 1)
	
	-- Use coroutine to prevent freezing
	coroutine.wrap(function()
		if VIM and VIM.SendKeyEvent then
			pcall(function()
				-- Super quick block press
				VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
				task.wait(0.05) -- Minimal delay
				VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
			end)
		end
		
		lastBlockTime = tick()
		isProcessingBlock = false
	end)()
end

function startNonFreezingAutoBlock()
	if autoBlockConnection then
		autoBlockConnection:Disconnect()
	end
	
	autoBlockConnection = RunService.Heartbeat:Connect(function()
		if not autoBlock then return end
		
		-- Process block queue first
		processBlockQueue()
		
		local char = player.Character
		if not char or not char:FindFirstChild("HumanoidRootPart") then return end
		
		-- Lightweight enemy detection
		for _, otherPlayer in pairs(Players:GetPlayers()) do
			if otherPlayer ~= player and otherPlayer.Character then
				local otherHRP = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
				if otherHRP then
					local distance = (char.HumanoidRootPart.Position - otherHRP.Position).Magnitude
					
					if distance <= blockRange then
						local velocity = otherHRP.AssemblyLinearVelocity
						local speed = velocity.Magnitude
						
						-- Simple threat detection without complex calculations
						if speed > 12 and distance < blockRange * 0.7 then
							queueBlock("Enemy Approaching")
						end
					end
				end
			end
		end
	end)
end

function stopNonFreezingAutoBlock()
	if autoBlockConnection then
		autoBlockConnection:Disconnect()
		autoBlockConnection = nil
	end
	blockQueue = {}
	isProcessingBlock = false
end

-- FLY SYSTEM
local flyBodyVelocity = nil
local flyBodyAngularVelocity = nil

function startFly()
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	
	flyBodyVelocity = Instance.new("BodyVelocity")
	flyBodyAngularVelocity = Instance.new("BodyAngularVelocity")
	
	flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
	flyBodyVelocity.Parent = character.HumanoidRootPart
	
	flyBodyAngularVelocity.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	flyBodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
	flyBodyAngularVelocity.Parent = character.HumanoidRootPart
	
	-- Fly control loop
	task.spawn(function()
		while fly and character and character:FindFirstChild("HumanoidRootPart") do
			local camera = workspace.CurrentCamera
			local direction = camera.CFrame.LookVector
			
			if humanoid.MoveDirection.Magnitude > 0 then
				flyBodyVelocity.Velocity = direction * currentSpeed
			else
				flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
			end
			
			task.wait(0.1)
		end
	end)
end

function stopFly()
	if flyBodyVelocity then
		flyBodyVelocity:Destroy()
		flyBodyVelocity = nil
	end
	if flyBodyAngularVelocity then
		flyBodyAngularVelocity:Destroy()
		flyBodyAngularVelocity = nil
	end
end

-- ESP FUNCTIONS
function enableESP()
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			addESPToPlayer(otherPlayer)
		end
	end
	
	Players.PlayerAdded:Connect(function(newPlayer)
		if espEnabled then
			newPlayer.CharacterAdded:Connect(function()
				task.wait(1)
				if espEnabled then
					addESPToPlayer(newPlayer)
				end
			end)
		end
	end)
end

function addESPToPlayer(targetPlayer)
	if not targetPlayer.Character then return end
	
	-- Remove existing ESP
	local oldHighlight = targetPlayer.Character:FindFirstChild("PlayerESP")
	local oldBillboard = targetPlayer.Character:FindFirstChild("NameESP")
	if oldHighlight then oldHighlight:Destroy() end
	if oldBillboard then oldBillboard:Destroy() end
	
	-- Add highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "PlayerESP"
	highlight.Adornee = targetPlayer.Character
	highlight.FillColor = Color3.new(1, 0.2, 0.2)
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0
	highlight.Parent = targetPlayer.Character
	
	-- Add name tag
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "NameESP"
	billboardGui.Adornee = targetPlayer.Character:FindFirstChild("Head")
	billboardGui.Size = UDim2.new(0, 200, 0, 50)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.Parent = targetPlayer.Character
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = targetPlayer.Name
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	textLabel.Parent = billboardGui
end

function disableESP()
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer.Character then
			local highlight = otherPlayer.Character:FindFirstChild("PlayerESP")
			local nameTag = otherPlayer.Character:FindFirstChild("NameESP")
			if highlight then highlight:Destroy() end
			if nameTag then nameTag:Destroy() end
		end
	end
end

function highlightAllPlayers()
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			local highlight = Instance.new("Highlight")
			highlight.Adornee = otherPlayer.Character
			highlight.FillColor = Color3.new(0, 1, 0)
			highlight.OutlineColor = Color3.new(1, 1, 1)
			highlight.FillTransparency = 0.5
			highlight.Parent = otherPlayer.Character
		end
	end
end

-- UTILITY FUNCTIONS
function teleportToRandomPlayer()
	local players = {}
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(players, otherPlayer)
		end
	end
	
	if #players > 0 then
		local randomPlayer = players[math.random(#players)]
		if character and character:FindFirstChild("HumanoidRootPart") then
			character.HumanoidRootPart.CFrame = randomPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(5, 0, 0)
		end
	end
end

-- Anti-AFK
local antiAFKConnection = nil
function startAntiAFK()
	antiAFKConnection = task.spawn(function()
		while task.wait(300) do -- Every 5 minutes
			if VIM then
				pcall(function()
					VIM:SendKeyEvent(true, Enum.KeyCode.W, false, game)
					task.wait(0.1)
					VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
				end)
			end
		end
	end)
end

function stopAntiAFK()
	if antiAFKConnection then
		task.cancel(antiAFKConnection)
		antiAFKConnection = nil
	end
end

-- Server Hop
function serverHop()
	local TeleportService = game:GetService("TeleportService")
	local success, result = pcall(function()
		TeleportService:Teleport(game.PlaceId)
	end)
	if not success then
		if Rayfield then
			Rayfield:Notify({
				Title = "Server Hop",
				Content = "Failed to hop servers. Try again.",
				Duration = 3
			})
		end
	end
end

-- Performance Optimization
function optimizePerformance()
	-- Reduce graphics quality
	local lighting = game:GetService("Lighting")
	lighting.GlobalShadows = false
	lighting.FogEnd = 100
	
	-- Remove unnecessary effects
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("ParticleEmitter") then
			obj.Enabled = false
		end
	end
	
	if Rayfield then
		Rayfield:Notify({
			Title = "Performance",
			Content = "Game optimized for better FPS!",
			Duration = 3
		})
	end
end

-- Remove Textures
function removeTextures(enabled)
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			if enabled then
				obj.Material = Enum.Material.Plastic
				obj.Color = Color3.new(0.5, 0.5, 0.5)
			end
		end
		if obj:IsA("Decal") or obj:IsA("Texture") then
			obj.Transparency = enabled and 1 or 0
		end
	end
end

-- Main Update Loop
RunService.Heartbeat:Connect(function()
	-- Update character reference
	if not character or not character.Parent then
		character = player.Character
		if character then
			humanoid = character:FindFirstChild("Humanoid")
			humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		end
	end
	
	-- Apply speed
	if character and humanoid then
		humanoid.WalkSpeed = currentSpeed
	end
	
	-- Apply noclip
	if noclip and character then
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
	if infJump and character and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

-- Character respawn handling
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = newChar:WaitForChild("Humanoid")
	humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
	
	-- Reapply settings
	if currentSpeed ~= 16 then
		humanoid.WalkSpeed = currentSpeed
	end
	
	-- Re-enable ESP if it was enabled
	if espEnabled then
		task.wait(2)
		enableESP()
	end
end)

end
