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
						local skills = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four}
						local randomSkill = skills[math.random(#skills)]
						
						local virtualInputManager = game:GetService("VirtualInputManager")
						virtualInputManager:SendKeyEvent(true, randomSkill, false, game)
						task.wait(0.1)
						virtualInputManager:SendKeyEvent(false, randomSkill, false, game)
						
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

end    BlockHitboxRadius = 4.5,  -- hitbox radius around you to detect incoming limb/weapon
    BlockVelocityThreshold = 6, -- part velocity towards you to be considered an incoming hit
    RecheckInterval = 0.08,   -- main loop tick (seconds)
}

local originalWalkSpeed = humanoid.WalkSpeed
local Cooldowns = {}
local KeyTimes = {One=2.5, Two=4, Three=6, Four=8, F=5, G=20, R=3}
local SkillKeys = {"One","Two","Three","Four","F","G"}
local lastSkillUsed = nil
local backOffUntil = 0
local blockingSince = 0
local BlockCooldown = 0.5

-- UI library (try Rayfield; fallback will continue without UI)
local Rayfield
do
    local ok
    ok, Rayfield = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if not ok or not Rayfield then
        -- fail silently; script still works without UI
        Rayfield = nil
        warn("[SmartNPC AI] Rayfield not available — running headless. Use hotkey K to toggle.")
    end
end

-- ===== Helpers =====
local function canCast(key)
    local last = Cooldowns[key]
    if not last then return true end
    return (tick() - last) >= (KeyTimes[key] or 1)
end

local function pressKey(key)
    if not key or not VIM then
        -- If no VIM, we can't simulate key presses from client reliably
        return false
    end
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode[key], false, game)
        task.wait(0.06)
        VIM:SendKeyEvent(false, Enum.KeyCode[key], false, game)
    end)
    return true
end

local function mouseClickCenter()
    if not VIM or not workspace.CurrentCamera then return end
    pcall(function()
        local view = workspace.CurrentCamera.ViewportSize
        local cx, cy = view.X/2, view.Y/2
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(0.03)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
end

-- Get nearest enemy by distance (no camera checks)
local function getNearestEnemy(maxDist)
    local nearest, bestDist = nil, maxDist or UI.MaxEngageDistance
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") then
            local targHRP = plr.Character.HumanoidRootPart
            local mag = (hrp.Position - targHRP.Position).Magnitude
            if mag < bestDist and plr.Character.Humanoid.Health > 0 then
                nearest = plr
                bestDist = mag
            end
        end
    end
    return nearest, bestDist
end

-- Decide an "optimal position" relative to the target based on health/defensive/aggressive
local function getOptimalPosition(targetHRP)
    local targetPos = targetHRP.Position
    local direction = (hrp.Position - targetPos)
    if direction.Magnitude < 0.001 then direction = Vector3.new(0,0,1) end
    local desiredDistance = UI.AggressiveDistance
    local healthPct = (humanoid.Health / humanoid.MaxHealth) * 100
    if healthPct <= 15 then
        desiredDistance = UI.DefensiveDistance + 6
    elseif healthPct <= 30 then
        desiredDistance = UI.DefensiveDistance
    else
        desiredDistance = UI.AggressiveDistance
    end
    return targetPos + direction.Unit * desiredDistance
end

-- Blocking detection: use proximity + part velocity toward you to detect incoming hits (hitbox style)
local function isIncomingHit()
    -- Check all other players' character parts within block radius
    local radius = UI.BlockHitboxRadius
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            for _, part in ipairs(plr.Character:GetDescendants()) do
                if part:IsA("BasePart") and not part.Anchored then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d <= radius then
                        local v = part.AssemblyLinearVelocity or Vector3.new()
                        -- direction from attacker part to our hrp
                        local dirToUs = (hrp.Position - part.Position)
                        if dirToUs.Magnitude > 0.001 then
                            local dot = v:Dot(dirToUs.Unit)
                            -- if part is moving toward us above a threshold => incoming swing/weapon
                            if dot > UI.BlockVelocityThreshold then
                                return true, plr, part
                            end
                        end
                    end
                end
            end
        end
    end
    return false, nil, nil
end

local function tryBlock()
    if (tick() - blockingSince) < BlockCooldown then return false end
    blockingSince = tick()
    -- Block key assumed 'F' for many games — change if your game uses another block key.
    if pressKey("F") then
        return true
    end
    return false
end

-- Attack logic: try prioritized skill usage or fallback to mouse click
local function tryAttack(target, dist)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local tHRP = target.Character.HumanoidRootPart
    local healthPct = (humanoid.Health / humanoid.MaxHealth) * 100

    -- respect backoff timer
    if backOffUntil > tick() then return end

    -- choose skill: prefer melee skills if close; use F/G for ranged or emergency
    if dist <= UI.AttackRange + 0.6 then
        local melee = {"One","Two","Three","Four"}
        for _,k in ipairs(melee) do
            if canCast(k) and lastSkillUsed ~= k then
                pressKey(k)
                Cooldowns[k] = tick()
                lastSkillUsed = k
                task.wait(0.09)
                mouseClickCenter()
                -- short backoff after using ability if low health
                if healthPct <= 35 then
                    backOffUntil = tick() + UI.BackOffTime
                end
                return
            end
        end
        -- fallback: click
        mouseClickCenter()
        lastSkillUsed = nil
        return
    else
        -- mid/long range: try F or G if available
        if canCast("F") then
            pressKey("F"); Cooldowns["F"] = tick(); lastSkillUsed = "F"; return
        end
        if canCast("G") then
            pressKey("G"); Cooldowns["G"] = tick(); lastSkillUsed = "G"; return
        end
    end
end

-- small unstuck helper (teleport-ish fudge to escape geometry)
local lastPos = hrp.Position
local stuckSince = nil
local function detectAndResolveStuck()
    if (hrp.Position - lastPos).Magnitude > 0.4 then
        stuckSince = nil
        lastPos = hrp.Position
        return
    end
    if not stuckSince then
        stuckSince = tick()
    elseif (tick() - stuckSince) > 1.2 then
        -- attempt quick jump + small lateral reposition
        humanoid.Jump = true
        local fudge = CFrame.new(Vector3.new(math.random(-3,3),0,math.random(-3,3)))
        hrp.CFrame = hrp.CFrame * fudge
        stuckSince = nil
        lastPos = hrp.Position
    end
end

-- === Input suppression (make your character act like NPC locally) ===
local boundActionName = "AI_BlockPlayerInputs"
local function blockInputAction(actionName, inputState, inputObject)
    -- sink all configured movement keys while AutoCombat is on
    return Enum.ContextActionResult.Sink
end

local function enableLocalControlOverride()
    -- bind common movement keys so player's inputs won't fight the AI
    ContextActionService:BindAction(boundActionName, blockInputAction, false,
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
        Enum.KeyCode.Space, Enum.KeyCode.LeftShift)
end
local function disableLocalControlOverride()
    pcall(function() ContextActionService:UnbindAction(boundActionName) end)
end

-- ===== Rayfield UI elements (if loaded) =====
local Window, AITab
if Rayfield then
    Window = Rayfield:CreateWindow({
        Name = "Smart NPC POV AI",
        LoadingTitle = "Smart Combat",
        LoadingSubtitle = "NPC-style POV AI",
        ConfigurationSaving = {Enabled = false},
        KeySystem = false,
    })
    AITab = Window:CreateTab("AI Controls", 4483362458)
    AITab:CreateSection("Main")
    AITab:CreateToggle({
        Name = "Enable Auto Combat",
        CurrentValue = AutoCombat,
        Flag = "AutoCombat",
        Callback = function(Value)
            AutoCombat = Value
            if AutoCombat then
                enableLocalControlOverride()
                humanoid.WalkSpeed = UI.MoveSpeed
            else
                disableLocalControlOverride()
                humanoid.WalkSpeed = originalWalkSpeed or 16
            end
            Rayfield:Notify({Title = "AutoCombat", Content = AutoCombat and "✅ ON" or "❌ OFF", Duration = 2})
        end
    })
    AITab:CreateSlider({
        Name = "Max Engage Distance",
        Range = {8,120},
        Increment = 1,
        CurrentValue = UI.MaxEngageDistance,
        Flag = "MaxEngage",
        Callback = function(v) UI.MaxEngageDistance = v end
    })
    AITab:CreateSlider({
        Name = "Move Speed (WS)",
        Range = {8,80},
        Increment = 1,
        CurrentValue = UI.MoveSpeed,
        Flag = "MoveSpeed",
        Callback = function(v) UI.MoveSpeed = v; if AutoCombat then humanoid.WalkSpeed = v end
    })
    AITab:CreateLabel("Hotkey: K to toggle AutoCombat")
end

-- Hotkey fallback: K toggles (if no Rayfield)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        AutoCombat = not AutoCombat
        if AutoCombat then
            enableLocalControlOverride()
            humanoid.WalkSpeed = UI.MoveSpeed
            if Rayfield then Rayfield:Notify({Title="AutoCombat",Content="✅ ON",Duration=2}) end
        else
            disableLocalControlOverride()
            humanoid.WalkSpeed = originalWalkSpeed or 16
            if Rayfield then Rayfield:Notify({Title="AutoCombat",Content="❌ OFF",Duration=2}) end
        end
    end
end)

-- ===== Main loop (no pathfinding) =====
local lastTick = 0
RunService.Heartbeat:Connect(function(dt)
    lastTick = lastTick + dt
    if lastTick < UI.RecheckInterval then return end
    lastTick = 0

    -- ensure character references valid
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    if humanoid.Health <= 0 then return end

    -- keep speed updated while active
    if AutoCombat then
        humanoid.WalkSpeed = UI.MoveSpeed
    end

    if not AutoCombat then
        return
    end

    -- detect incoming hit (hitbox-based)
    local incoming, attacker, hitPart = isIncomingHit()
    if incoming then
        -- immediate blocking attempt
        tryBlock()
    end

    -- Find nearest target
    local target, dist = getNearestEnemy(UI.MaxEngageDistance)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        humanoid:MoveTo(hrp.Position) -- idle
        return
    end

    local tHRP = target.Character.HumanoidRootPart

    -- Movement: move toward an optimal position relative to enemy (no pathfinding)
    local optimal = getOptimalPosition(tHRP)
    humanoid:MoveTo(optimal)

    -- Attack decision
    tryAttack(target, dist)

    -- Unstuck
    detectAndResolveStuck()
end)

-- Final notice
if Rayfield then
    Rayfield:Notify({Title = "Smart NPC AI", Content = "Loaded — toggle with K or Rayfield UI", Duration = 4})
else
    print("[Smart NPC AI] Loaded (no Rayfield). Toggle with K.")
end

-- Cleanup when script stopped (not strictly necessary, but safe)
-- Note: if you reload script you may want to call disableLocalControlOverride() manually to restore controls.
