--[[ Jujutsu Shenanigans Script for Arceus X Mobile ]]

if not game.Players.LocalPlayer.PlayerScripts:FindFirstChild("Loaded") then 
	local data = Instance.new("NumberValue")
	data.Name = "Loaded" 
	data.Parent = game.Players.LocalPlayer.PlayerScripts 
	print("Jujutsu Shenanigans Script Loaded")

-- Load Rayfield UI Library
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Player Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Script Variables
local autoBlock = false
local autoParry = false
local autoCombo = false
local autoSkills = false
local espEnabled = false
local speedHack = false
local noclip = false
local infJump = false
local currentSpeed = 16
local blockRange = 20
local comboDelay = 0.1
local autoBlockConnection = nil

-- Create Main Window
local Window = Rayfield:CreateWindow({
	Name = "Jujutsu Shenanigans Script",
	LoadingTitle = "Loading JJS Script",
	LoadingSubtitle = "By Script Developer",
	ShowText = "JJS Enhanced",
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
	Title = "Jujutsu Shenanigans Script",
	Content = "Script loaded successfully! Features: Auto Block, ESP, Combat Assistance",
	Duration = 5
})

-- Create Tabs
local CombatTab = Window:CreateTab("Combat", 4483362458)
local PlayerTab = Window:CreateTab("Player", 4483362458) 
local VisualTab = Window:CreateTab("Visual", 4483362458)
local MiscTab = Window:CreateTab("Miscellaneous", 4483362458)

-- COMBAT FEATURES

-- Auto Block Toggle
local AutoBlockToggle = CombatTab:CreateToggle({
	Name = "Auto Block (Incoming Attack Detector)",
	CurrentValue = false,
	Flag = "AutoBlock",
	Callback = function(Value)
		autoBlock = Value
		if autoBlock then
			startAutoBlock()
		else
			stopAutoBlock()
		end
	end,
})

-- Block Range Slider
CombatTab:CreateSlider({
	Name = "Auto Block Range",
	Range = {5, 50},
	Increment = 1,
	Suffix = "Studs",
	CurrentValue = 20,
	Flag = "BlockRange",
	Callback = function(Value)
		blockRange = Value
	end,
})

-- Auto Parry Toggle
CombatTab:CreateToggle({
	Name = "Auto Parry",
	CurrentValue = false,
	Flag = "AutoParry",
	Callback = function(Value)
		autoParry = Value
	end,
})

-- Auto Combo Toggle
CombatTab:CreateToggle({
	Name = "Auto M1 Combo",
	CurrentValue = false,
	Flag = "AutoCombo",
	Callback = function(Value)
		autoCombo = Value
		if autoCombo then
			startAutoCombo()
		end
	end,
})

-- Combo Delay Slider
CombatTab:CreateSlider({
	Name = "Combo Delay",
	Range = {0.05, 1},
	Increment = 0.05,
	Suffix = "Seconds",
	CurrentValue = 0.1,
	Flag = "ComboDelay",
	Callback = function(Value)
		comboDelay = Value
	end,
})

-- Auto Skills Toggle
CombatTab:CreateToggle({
	Name = "Auto Skills (1,2,3,4)",
	CurrentValue = false,
	Flag = "AutoSkills",
	Callback = function(Value)
		autoSkills = Value
		if autoSkills then
			startAutoSkills()
		end
	end,
})

-- PLAYER FEATURES

-- Speed Hack
PlayerTab:CreateSlider({
	Name = "Walk Speed",
	Range = {16, 200},
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

-- VISUAL FEATURES

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

-- Highlight Enemies Button
VisualTab:CreateButton({
	Name = "Highlight All Players",
	Callback = function()
		highlightPlayers()
	end
})

-- MISC FEATURES

-- Teleport to Players
MiscTab:CreateButton({
	Name = "Teleport to Random Player",
	Callback = function()
		teleportToRandomPlayer()
	end
})

-- Remove Debounces
MiscTab:CreateButton({
	Name = "Remove Skill Cooldowns",
	Callback = function()
		removeSkillCooldowns()
	end
})

-- Anti-Lag
MiscTab:CreateButton({
	Name = "Optimize Game Performance",
	Callback = function()
		optimizePerformance()
	end
})

-- FUNCTIONS

-- Auto Block Function
function startAutoBlock()
	if autoBlockConnection then
		autoBlockConnection:Disconnect()
	end
	
	autoBlockConnection = RunService.Heartbeat:Connect(function()
		if not autoBlock then return end
		
		local char = player.Character
		if not char or not char:FindFirstChild("HumanoidRootPart") then return end
		
		-- Check for nearby players attacking
		for _, otherPlayer in pairs(Players:GetPlayers()) do
			if otherPlayer ~= player and otherPlayer.Character then
				local otherChar = otherPlayer.Character
				local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
				local otherHumanoid = otherChar:FindFirstChild("Humanoid")
				
				if otherHRP and otherHumanoid then
					local distance = (char.HumanoidRootPart.Position - otherHRP.Position).Magnitude
					
					-- Check if player is close enough and potentially attacking
					if distance <= blockRange then
						-- Check if they're facing us and moving towards us
						local direction = (char.HumanoidRootPart.Position - otherHRP.Position).Unit
						local lookDirection = otherHRP.CFrame.LookVector
						local facingUs = direction:Dot(-lookDirection) > 0.7
						
						if facingUs and otherHumanoid.MoveDirection.Magnitude > 0 then
							-- Trigger block (F key)
							performBlock()
						end
					end
				end
			end
		end
	end)
end

function stopAutoBlock()
	if autoBlockConnection then
		autoBlockConnection:Disconnect()
		autoBlockConnection = nil
	end
end

function performBlock()
	-- Simulate F key press for blocking
	local virtualInputManager = game:GetService("VirtualInputManager")
	virtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
	task.wait(0.1)
	virtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
end

-- Auto Combo Function
function startAutoCombo()
	task.spawn(function()
		while autoCombo do
			if character and character:FindFirstChild("HumanoidRootPart") then
				-- Find nearest player
				local nearestPlayer = findNearestPlayer()
				if nearestPlayer and nearestPlayer.Character then
					local distance = (character.HumanoidRootPart.Position - nearestPlayer.Character.HumanoidRootPart.Position).Magnitude
					if distance <= 10 then
						-- Perform M1 combo (Left Click)
						mouse1click()
						task.wait(comboDelay)
					end
				end
			end
			task.wait(0.1)
		end
	end)
end

-- Auto Skills Function
function startAutoSkills()
	task.spawn(function()
		while autoSkills do
			if character and character:FindFirstChild("HumanoidRootPart") then
				local nearestPlayer = findNearestPlayer()
				if nearestPlayer and nearestPlayer.Character then
					local distance = (character.HumanoidRootPart.Position - nearestPlayer.Character.HumanoidRootPart.Position).Magnitude
					if distance <= 15 then
						-- Use skills 1-4 randomly
						local skills = {"One", "Two", "Three", "Four"}
						local randomSkill = skills[math.random(#skills)]
						
						if VIM and VIM.SendKeyEvent then
							pcall(function()
								VIM:SendKeyEvent(true, Enum.KeyCode[randomSkill], false, game)
								task.wait(0.1)
								VIM:SendKeyEvent(false, Enum.KeyCode[randomSkill], false, game)
							end)
						end
						
						task.wait(2) -- Cooldown between skills
					end
				end
			end
			task.wait(1)
		end
	end)
end

-- ESP Functions
function enableESP()
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			addESPToPlayer(otherPlayer)
		end
	end
	
	-- Add ESP to new players
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
	
	local highlight = Instance.new("Highlight")
	highlight.Name = "PlayerESP"
	highlight.Adornee = targetPlayer.Character
	highlight.FillColor = Color3.new(1, 0, 0)
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.5
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

-- ESP Functions (Kept - These are useful)
function enableESP()
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			addESPToPlayer(otherPlayer)
		end
	end
	
	-- Add ESP to new players
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
	
	local highlight = Instance.new("Highlight")
	highlight.Name = "PlayerESP"
	highlight.Adornee = targetPlayer.Character
	highlight.FillColor = Color3.new(1, 0, 0)
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.5
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

-- Utility Functions
function findNearestPlayer()
	if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
	
	local nearestPlayer = nil
	local shortestDistance = math.huge
	
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (character.HumanoidRootPart.Position - otherPlayer.Character.HumanoidRootPart.Position).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				nearestPlayer = otherPlayer
			end
		end
	end
	
	return nearestPlayer
end

function highlightPlayers()
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			local highlight = Instance.new("Highlight")
			highlight.Adornee = otherPlayer.Character
			highlight.FillColor = Color3.new(0, 1, 0)
			highlight.OutlineColor = Color3.new(1, 1, 1)
			highlight.Parent = otherPlayer.Character
		end
	end
end

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

function removeSkillCooldowns()
	-- This function attempts to remove skill cooldowns by manipulating client-side values
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		for _, gui in pairs(playerGui:GetDescendants()) do
			if gui:IsA("Frame") and gui.Name:lower():find("cooldown") then
				gui.Visible = false
			end
		end
	end
end

function optimizePerformance()
	-- Reduce graphics quality for better performance
	local lighting = game:GetService("Lighting")
	lighting.GlobalShadows = false
	lighting.FogEnd = 100
	
	-- Disable unnecessary effects
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
			obj.Enabled = false
		end
	end
	
	Rayfield:Notify({
		Title = "Performance",
		Content = "Game optimized for better performance!",
		Duration = 3
	})
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
	
	-- Apply speed hack
	if character and humanoid and speedHack then
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
	
	-- Reapply speed if needed
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
