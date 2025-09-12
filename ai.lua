--[[ Combat Warriors Enhanced Script for Arceus X Mobile ]]

if not game.Players.LocalPlayer.PlayerScripts:FindFirstChild("CW_Loaded") then 
    local data = Instance.new("NumberValue")
    data.Name = "CW_Loaded" 
    data.Parent = game.Players.LocalPlayer.PlayerScripts 
    print("Combat Warriors Enhanced Script Loaded for Mobile")

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
        warn("[CW Script] Rayfield failed to load. UI will not appear. Check network/executor.")
        return
    end
end

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

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
    task.wait(2)
    -- Reapply settings after respawn
    if currentSpeed ~= 16 then
        humanoid.WalkSpeed = currentSpeed
    end
    if infiniteStamina then
        enableInfiniteStamina()
    end
end)

-- Combat Warriors Specific Variables
local autoParry = false
local killAura = false
local autoRevive = false
local antiRagdoll = false
local weaponReach = false
local silentAim = false
local currentSpeed = 16
local parryRange = 20
local killAuraRange = 15
local weaponReachValue = 8
local espEnabled = false
local fullBright = false
local noClip = false
local infiniteStamina = false
local autoStomp = false
local hitboxExpander = false
local hitboxSize = 10

-- Advanced Auto Parry Variables (Mobile Optimized)
local parryQueue = {}
local isProcessingParry = false
local lastParryTime = 0
local parryCooldown = 0.2
local parryPrediction = true
local predictionTime = 0.3

-- Kill Aura Variables
local killAuraTargets = {}
local killAuraConnection = nil
local killAuraDelay = 0.1
local lastAttackTime = 0

-- Auto Revive Variables
local autoReviveConnection = nil
local reviveKey = Enum.KeyCode.R

-- VIM setup for mobile input
local VIM = nil
pcall(function()
    VIM = game:GetService("VirtualInputManager")
end)

-- Mobile Touch Detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Create Main Window
local Window
if Rayfield then
    Window = Rayfield:CreateWindow({
        Name = "Combat Warriors Enhanced",
        LoadingTitle = "Loading CW Script", 
        LoadingSubtitle = "Mobile Optimized - Arceus X Compatible",
        ShowText = "CW Pro Mobile",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "CombatWarriors_Mobile",
            FileName = "Config"
        },
        Discord = {
            Enabled = false,
            Invite = "",
            RememberJoins = true
        },
        KeySystem = false
    })

    -- Mobile Notification
    Rayfield:Notify({
        Title = "Combat Warriors Enhanced",
        Content = "Mobile-optimized script loaded! Advanced Auto Parry ready for Arceus X",
        Duration = 5
    })
end

-- Create Tabs
local CombatTab, PlayerTab, VisualTab, UtilityTab

if Window then
    CombatTab = Window:CreateTab("Combat", 4483362458)
    PlayerTab = Window:CreateTab("Player", 4483362458) 
    VisualTab = Window:CreateTab("Visual", 4483362458)
    UtilityTab = Window:CreateTab("Utility", 4483362458)
end

-- COMBAT FEATURES
if CombatTab then
    CombatTab:CreateSection("Auto Combat System")
    
    -- Advanced Auto Parry Toggle
    CombatTab:CreateToggle({
        Name = "Advanced Auto Parry",
        CurrentValue = false,
        Flag = "AutoParry",
        Callback = function(Value)
            autoParry = Value
            if autoParry then
                startAdvancedAutoParry()
                if Rayfield then
                    Rayfield:Notify({
                        Title = "Auto Parry",
                        Content = "Advanced mobile-friendly auto parry enabled!",
                        Duration = 3
                    })
                end
            else
                stopAdvancedAutoParry()
            end
        end,
    })

    -- Parry Prediction
    CombatTab:CreateToggle({
        Name = "Parry Prediction",
        CurrentValue = true,
        Flag = "ParryPrediction",
        Callback = function(Value)
            parryPrediction = Value
        end,
    })

    -- Parry Range
    CombatTab:CreateSlider({
        Name = "Parry Detection Range",
        Range = {10, 35},
        Increment = 1,
        Suffix = "Studs",
        CurrentValue = 20,
        Flag = "ParryRange",
        Callback = function(Value)
            parryRange = Value
        end,
    })

    -- Prediction Time
    CombatTab:CreateSlider({
        Name = "Prediction Time",
        Range = {0.1, 0.8},
        Increment = 0.1,
        Suffix = "Seconds",
        CurrentValue = 0.3,
        Flag = "PredictionTime",
        Callback = function(Value)
            predictionTime = Value
        end,
    })

    -- Kill Aura Toggle
    CombatTab:CreateToggle({
        Name = "Kill Aura",
        CurrentValue = false,
        Flag = "KillAura",
        Callback = function(Value)
            killAura = Value
            if killAura then
                startKillAura()
                if Rayfield then
                    Rayfield:Notify({
                        Title = "Kill Aura",
                        Content = "Kill aura enabled! Auto-attacking nearby enemies",
                        Duration = 3
                    })
                end
            else
                stopKillAura()
            end
        end,
    })

    -- Kill Aura Range
    CombatTab:CreateSlider({
        Name = "Kill Aura Range",
        Range = {8, 25},
        Increment = 1,
        Suffix = "Studs",
        CurrentValue = 15,
        Flag = "KillAuraRange",
        Callback = function(Value)
            killAuraRange = Value
        end,
    })

    -- Auto Stomp
    CombatTab:CreateToggle({
        Name = "Auto Stomp (Q Key)",
        CurrentValue = false,
        Flag = "AutoStomp",
        Callback = function(Value)
            autoStomp = Value
            if autoStomp then
                startAutoStomp()
            else
                stopAutoStomp()
            end
        end,
    })

    CombatTab:CreateSection("Weapon Modifications")

    -- Hitbox Expander
    CombatTab:CreateToggle({
        Name = "Hitbox Expander",
        CurrentValue = false,
        Flag = "HitboxExpander",
        Callback = function(Value)
            hitboxExpander = Value
            if hitboxExpander then
                enableHitboxExpander()
            else
                disableHitboxExpander()
            end
        end,
    })

    -- Hitbox Size
    CombatTab:CreateSlider({
        Name = "Hitbox Size",
        Range = {5, 20},
        Increment = 1,
        Suffix = "Size",
        CurrentValue = 10,
        Flag = "HitboxSize",
        Callback = function(Value)
            hitboxSize = Value
            if hitboxExpander then
                enableHitboxExpander()
            end
        end,
    })

    -- Weapon Reach
    CombatTab:CreateToggle({
        Name = "Extended Weapon Reach",
        CurrentValue = false,
        Flag = "WeaponReach",
        Callback = function(Value)
            weaponReach = Value
            if weaponReach then
                enableWeaponReach()
            else
                disableWeaponReach()
            end
        end,
    })

    -- Weapon Reach Value
    CombatTab:CreateSlider({
        Name = "Reach Distance",
        Range = {3, 15},
        Increment = 1,
        Suffix = "Studs",
        CurrentValue = 8,
        Flag = "ReachValue",
        Callback = function(Value)
            weaponReachValue = Value
            if weaponReach then
                enableWeaponReach()
            end
        end,
    })

    CombatTab:CreateSection("Survival Features")

    -- Auto Revive
    CombatTab:CreateToggle({
        Name = "Auto Revive (R Key)",
        CurrentValue = false,
        Flag = "AutoRevive",
        Callback = function(Value)
            autoRevive = Value
            if autoRevive then
                startAutoRevive()
            else
                stopAutoRevive()
            end
        end,
    })

    -- Anti Ragdoll
    CombatTab:CreateToggle({
        Name = "Anti Ragdoll",
        CurrentValue = false,
        Flag = "AntiRagdoll",
        Callback = function(Value)
            antiRagdoll = Value
            if antiRagdoll then
                enableAntiRagdoll()
            else
                disableAntiRagdoll()
            end
        end,
    })

    -- Manual Parry Test
    CombatTab:CreateButton({
        Name = "Test Parry (F Key)",
        Callback = function()
            executeParry("Manual Test")
            if Rayfield then
                Rayfield:Notify({
                    Title = "Parry Test",
                    Content = "Manual parry executed!",
                    Duration = 2
                })
            end
        end
    })
end

-- PLAYER FEATURES
if PlayerTab then
    PlayerTab:CreateSection("Movement Enhancement")
    
    -- Speed Hack
    PlayerTab:CreateSlider({
        Name = "Walk Speed",
        Range = {16, 150},
        Increment = 2,
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
        Range = {50, 300},
        Increment = 10,
        Suffix = "Power",
        CurrentValue = 50,
        Flag = "JumpPower",
        Callback = function(Value)
            if character and character:FindFirstChild("Humanoid") then
                character.Humanoid.JumpPower = Value
            end
        end,
    })

    -- Noclip
    PlayerTab:CreateToggle({
        Name = "Noclip",
        CurrentValue = false,
        Flag = "NoClip",
        Callback = function(Value)
            noClip = Value
        end,
    })

    PlayerTab:CreateSection("Stamina & Health")

    -- Infinite Stamina
    PlayerTab:CreateToggle({
        Name = "Infinite Stamina",
        CurrentValue = false,
        Flag = "InfiniteStamina",
        Callback = function(Value)
            infiniteStamina = Value
            if infiniteStamina then
                enableInfiniteStamina()
            else
                disableInfiniteStamina()
            end
        end,
    })

    -- Instant Heal
    PlayerTab:CreateButton({
        Name = "Instant Heal",
        Callback = function()
            instantHeal()
        end
    })

    -- God Mode (Anti Damage)
    PlayerTab:CreateToggle({
        Name = "God Mode",
        CurrentValue = false,
        Flag = "GodMode",
        Callback = function(Value)
            if Value then
                enableGodMode()
            else
                disableGodMode()
            end
        end,
    })

    PlayerTab:CreateSection("Teleportation")

    -- Teleport to Spawn
    PlayerTab:CreateButton({
        Name = "Teleport to Spawn",
        Callback = function()
            teleportToSpawn()
        end
    })

    -- Teleport to Random Player
    PlayerTab:CreateButton({
        Name = "Teleport to Random Player",
        Callback = function()
            teleportToRandomPlayer()
        end
    })

    -- Teleport Behind Target
    PlayerTab:CreateButton({
        Name = "Teleport Behind Nearest Enemy",
        Callback = function()
            teleportBehindNearestEnemy()
        end
    })
end

-- VISUAL FEATURES
if VisualTab then
    VisualTab:CreateSection("Player ESP")
    
    -- Advanced ESP Toggle
    VisualTab:CreateToggle({
        Name = "Advanced Player ESP",
        CurrentValue = false,
        Flag = "ESP",
        Callback = function(Value)
            espEnabled = Value
            if espEnabled then
                enableAdvancedESP()
            else
                disableAdvancedESP()
            end
        end,
    })

    -- Weapon ESP
    VisualTab:CreateToggle({
        Name = "Weapon ESP",
        CurrentValue = false,
        Flag = "WeaponESP",
        Callback = function(Value)
            if Value then
                enableWeaponESP()
            else
                disableWeaponESP()
            end
        end,
    })

    -- Health ESP
    VisualTab:CreateToggle({
        Name = "Health ESP",
        CurrentValue = false,
        Flag = "HealthESP",
        Callback = function(Value)
            if Value then
                enableHealthESP()
            else
                disableHealthESP()
            end
        end,
    })

    VisualTab:CreateSection("World Modifications")

    -- Full Bright
    VisualTab:CreateToggle({
        Name = "Full Bright",
        CurrentValue = false,
        Flag = "FullBright",
        Callback = function(Value)
            fullBright = Value
            if Value then
                Lighting.Brightness = 10
                Lighting.Ambient = Color3.new(1, 1, 1)
                Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
                Lighting.ColorShift_Top = Color3.new(1, 1, 1)
            else
                Lighting.Brightness = 1
                Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
                Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
                Lighting.ColorShift_Top = Color3.new(0, 0, 0)
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
                Lighting.FogStart = 0
            else
                Lighting.FogEnd = 100
                Lighting.FogStart = 15
            end
        end,
    })

    -- Crosshair
    VisualTab:CreateToggle({
        Name = "Mobile Crosshair",
        CurrentValue = false,
        Flag = "Crosshair",
        Callback = function(Value)
            if Value then
                createMobileCrosshair()
            else
                removeMobileCrosshair()
            end
        end,
    })

    -- Damage Indicators
    VisualTab:CreateToggle({
        Name = "Damage Indicators",
        CurrentValue = false,
        Flag = "DamageIndicators",
        Callback = function(Value)
            if Value then
                enableDamageIndicators()
            else
                disableDamageIndicators()
            end
        end,
    })
end

-- UTILITY FEATURES
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

    -- Auto Collect Glory
    UtilityTab:CreateToggle({
        Name = "Auto Collect Glory",
        CurrentValue = false,
        Flag = "AutoGlory",
        Callback = function(Value)
            if Value then
                startAutoGlory()
            else
                stopAutoGlory()
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

    -- Mobile Performance Mode
    UtilityTab:CreateButton({
        Name = "Enable Mobile Performance Mode",
        Callback = function()
            optimizeForMobile()
        end
    })

    -- Low Graphics Mode
    UtilityTab:CreateToggle({
        Name = "Low Graphics Mode",
        CurrentValue = false,
        Flag = "LowGraphics",
        Callback = function(Value)
            setLowGraphics(Value)
        end,
    })

    -- FPS Unlocker (Mobile Compatible)
    UtilityTab:CreateToggle({
        Name = "FPS Boost Mode",
        CurrentValue = false,
        Flag = "FPSBoost",
        Callback = function(Value)
            if Value then
                enableFPSBoost()
            else
                disableFPSBoost()
            end
        end,
    })
end

-- ADVANCED AUTO PARRY SYSTEM (Mobile Optimized)
local parryConnections = {}

function executeParry(reason)
    if (tick() - lastParryTime) < parryCooldown then return end
    
    -- Use coroutine for non-blocking execution
    coroutine.wrap(function()
        if VIM and VIM.SendKeyEvent then
            pcall(function()
                -- Press F key for parry
                VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(0.05) -- Minimal delay
                VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                lastParryTime = tick()
                
                if reason then
                    print("[Auto Parry] Executed:", reason)
                end
            end)
        end
    end)()
end

function detectThreat(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
    
    if not targetHRP or not targetHumanoid or not character or not humanoidRootPart then return false end
    
    local distance = (humanoidRootPart.Position - targetHRP.Position).Magnitude
    if distance > parryRange then return false end
    
    -- Check if target is moving towards us
    local velocity = targetHRP.AssemblyLinearVelocity
    local speed = velocity.Magnitude
    
    if speed > 10 then
        local direction = (humanoidRootPart.Position - targetHRP.Position).Unit
        local velocityDirection = velocity.Unit
        local dotProduct = velocityDirection:Dot(direction)
        
        -- If target is moving towards us with significant speed
        if dotProduct > 0.3 and speed > 15 then
            return true, distance, speed
        end
    end
    
    -- Check for attack animations
    local animator = targetHumanoid:FindFirstChild("Animator")
    if animator then
        local tracks = animator:GetPlayingAnimationTracks()
        for _, track in pairs(tracks) do
            local animName = track.Name:lower()
            if animName:find("attack") or animName:find("swing") or animName:find("slash") then
                return true, distance, speed
            end
        end
    end
    
    return false
end

function startAdvancedAutoParry()
    -- Clear existing connections
    for _, connection in pairs(parryConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    parryConnections = {}
    
    -- Main parry detection loop
    parryConnections[#parryConnections + 1] = RunService.Heartbeat:Connect(function()
        if not autoParry then return end
        if not character or not humanoidRootPart then return end
        
        -- Check all players for threats
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                local isThreat, distance, speed = detectThreat(otherPlayer)
                
                if isThreat then
                    -- Calculate prediction if enabled
                    local delay = 0
                    if parryPrediction and distance and speed then
                        delay = math.max(0, distance / speed - predictionTime)
                    end
                    
                    -- Execute parry with prediction delay
                    if delay > 0 then
                        task.wait(delay)
                    end
                    
                    executeParry("Threat detected: " .. otherPlayer.Name)
                    break -- Only parry once per frame
                end
            end
        end
    end)
end

function stopAdvancedAutoParry()
    for _, connection in pairs(parryConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    parryConnections = {}
end

-- KILL AURA SYSTEM
function startKillAura()
    if killAuraConnection then
        killAuraConnection:Disconnect()
    end
    
    killAuraConnection = RunService.Heartbeat:Connect(function()
        if not killAura then return end
        if not character or not humanoidRootPart then return end
        if (tick() - lastAttackTime) < killAuraDelay then return end
        
        -- Find nearest target
        local nearestTarget = nil
        local nearestDistance = math.huge
        
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                local targetHRP = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetHRP then
                    local distance = (humanoidRootPart.Position - targetHRP.Position).Magnitude
                    if distance <= killAuraRange and distance < nearestDistance then
                        nearestDistance = distance
                        nearestTarget = otherPlayer
                    end
                end
            end
        end
        
        -- Attack nearest target
        if nearestTarget then
            attackTarget(nearestTarget)
            lastAttackTime = tick()
        end
    end)
end

function attackTarget(target)
    if not target or not target.Character then return end
    
    coroutine.wrap(function()
        if VIM then
            pcall(function()
                -- Left click to attack
                VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.wait(0.05)
                VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end
    end)()
end

function stopKillAura()
    if killAuraConnection then
        killAuraConnection:Disconnect()
        killAuraConnection = nil
    end
end

-- AUTO STOMP SYSTEM
local stompConnection = nil
function startAutoStomp()
    if stompConnection then
        stompConnection:Disconnect()
    end
    
    stompConnection = RunService.Heartbeat:Connect(function()
        if not autoStomp then return end
        if not character or not humanoidRootPart then return end
        
        -- Look for downed enemies
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                local targetHumanoid = otherPlayer.Character:FindFirstChild("Humanoid")
                local targetHRP = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
                
                if targetHumanoid and targetHRP then
                    -- Check if target is downed (PlatformStand usually means ragdolled/downed)
                    if targetHumanoid.PlatformStand then
                        local distance = (humanoidRootPart.Position - targetHRP.Position).Magnitude
                        if distance <= 8 then
                            -- Execute stomp (Q key)
                            coroutine.wrap(function()
                                if VIM then
                                    pcall(function()
                                        VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                                        task.wait(0.05)
                                        VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                                    end)
                                end
                            end)()
                            task.wait(0.5) -- Prevent spam
                        end
                    end
                end
            end
        end
    end)
end

function stopAutoStomp()
    if stompConnection then
        stompConnection:Disconnect()
        stompConnection = nil
    end
end

-- AUTO REVIVE SYSTEM
function startAutoRevive()
    if autoReviveConnection then
        autoReviveConnection:Disconnect()
    end
    
    autoReviveConnection = RunService.Heartbeat:Connect(function()
        if not autoRevive then return end
        if not character or not humanoid then return end
        
        -- Check if player is downed
        if humanoid.PlatformStand or humanoid.Health <= 0 then
            -- Execute revive (R key)
            coroutine.wrap(function()
                if VIM then
                    pcall(function()
                        VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                        task.wait(0.1)
                        VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
                    end)
                end
            end)()
            task.wait(1) -- Wait before trying again
        end
    end)
end

function stopAutoRevive()
    if autoReviveConnection then
        autoReviveConnection:Disconnect()
        autoReviveConnection = nil
    end
end

-- HITBOX EXPANDER
function enableHitboxExpander()
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            local targetHRP = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetHRP then
                targetHRP.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                targetHRP.Transparency = 0.8
            end
        end
    end
    
    -- Apply to new players
    Players.PlayerAdded:Connect(function(newPlayer)
        newPlayer.CharacterAdded:Connect(function(newChar)
            if hitboxExpander then
                local targetHRP = newChar:WaitForChild("HumanoidRootPart", 5)
                if targetHRP then
                    targetHRP.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                    targetHRP.Transparency = 0.8
                end
            end
        end)
    end)
end

function disableHitboxExpander()
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            local targetHRP = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetHRP then
                targetHRP.Size = Vector3.new(2, 2, 1)
                targetHRP.Transparency = 1
            end
        end
    end
end

-- WEAPON REACH MODIFIER
function enableWeaponReach()
    if not character then return end
    
    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            local handle = tool:FindFirstChild("Handle")
            if handle then
                -- Modify weapon reach by scaling handle
                local originalSize = handle.Size
                handle.Size = originalSize * Vector3.new(1, 1, weaponReachValue)
            end
        end
    end
end

function disableWeaponReach()
    if not character then return end
    
    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            local handle = tool:FindFirstChild("Handle")
            if handle then
                -- Reset to original size (approximate)
                handle.Size = Vector3.new(1, 1, 4)
            end
        end
    end
end

-- INFINITE STAMINA
local staminaConnections = {}
function enableInfiniteStamina()
    -- Clear existing connections
    for _, conn in pairs(staminaConnections) do
        if conn then conn:Disconnect() end
    end
    staminaConnections = {}
    
    staminaConnections[1] = RunService.Heartbeat:Connect(function()
        if not infiniteStamina then return end
        if not character then return end
        
        -- Look for stamina-related values in character
        for _, obj in pairs(character:GetDescendants()) do
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                if obj.Name:lower():find("stamina") then
                    obj.Value = obj.Value < 100 and 100 or obj.Value
                end
            end
        end
    end)
end

function disableInfiniteStamina()
    for _, conn in pairs(staminaConnections) do
        if conn then conn:Disconnect() end
    end
    staminaConnections = {}
end

-- ANTI RAGDOLL SYSTEM
local ragdollConnection = nil
function enableAntiRagdoll()
    if ragdollConnection then
        ragdollConnection:Disconnect()
    end
    
    ragdollConnection = RunService.Heartbeat:Connect(function()
        if not antiRagdoll then return end
        if not character or not humanoid then return end
        
        -- Prevent ragdoll state
        if humanoid.PlatformStand then
            humanoid.PlatformStand = false
        end
        
        -- Keep character upright
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                local bodyPos = part:FindFirstChild("BodyPosition")
                local bodyAng = part:FindFirstChild("BodyAngularVelocity")
                if bodyPos then bodyPos:Destroy() end
                if bodyAng then bodyAng:Destroy() end
            end
        end
    end)
end

function disableAntiRagdoll()
    if ragdollConnection then
        ragdollConnection:Disconnect()
        ragdollConnection = nil
    end
end

-- GOD MODE SYSTEM
local godModeConnection = nil
local originalHealth = 100

function enableGodMode()
    if not character or not humanoid then return end
    originalHealth = humanoid.MaxHealth
    
    if godModeConnection then
        godModeConnection:Disconnect()
    end
    
    godModeConnection = humanoid.HealthChanged:Connect(function(health)
        if health < originalHealth then
            humanoid.Health = originalHealth
        end
    end)
    
    humanoid.Health = originalHealth
end

function disableGodMode()
    if godModeConnection then
        godModeConnection:Disconnect()
        godModeConnection = nil
    end
end

-- ADVANCED ESP SYSTEM
local espObjects = {}

function enableAdvancedESP()
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            addAdvancedESP(otherPlayer)
        end
    end
    
    -- Handle new players
    Players.PlayerAdded:Connect(function(newPlayer)
        newPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            if espEnabled then
                addAdvancedESP(newPlayer)
            end
        end)
    end)
end

function addAdvancedESP(targetPlayer)
    if not targetPlayer.Character then return end
    
    -- Remove existing ESP
    removeESPFromPlayer(targetPlayer)
    
    local character = targetPlayer.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    
    if not humanoidRootPart or not head then return end
    
    -- Create highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "PlayerESP_" .. targetPlayer.Name
    highlight.Adornee = character
    highlight.FillColor = Color3.new(1, 0, 0)
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
    highlight.Parent = character
    
    -- Create name and distance ESP
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "NameESP_" .. targetPlayer.Name
    billboardGui.Adornee = head
    billboardGui.Size = UDim2.new(0, 200, 0, 100)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = character
    
    -- Name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = targetPlayer.Name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Parent = billboardGui
    
    -- Distance label
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distanceLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = "0 studs"
    distanceLabel.TextColor3 = Color3.new(0, 1, 0)
    distanceLabel.TextScaled = true
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.TextStrokeTransparency = 0
    distanceLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distanceLabel.Parent = billboardGui
    
    -- Store ESP objects
    espObjects[targetPlayer.Name] = {highlight, billboardGui, distanceLabel}
    
    -- Update distance continuously
    task.spawn(function()
        while espEnabled and targetPlayer.Character and humanoidRootPart.Parent do
            if character and humanoidRootPart then
                local distance = math.floor((humanoidRootPart.Position - humanoidRootPart.Position).Magnitude)
                distanceLabel.Text = distance .. " studs"
                
                -- Color code based on distance
                if distance <= 15 then
                    distanceLabel.TextColor3 = Color3.new(1, 0, 0) -- Red - Close
                elseif distance <= 30 then
                    distanceLabel.TextColor3 = Color3.new(1, 1, 0) -- Yellow - Medium
                else
                    distanceLabel.TextColor3 = Color3.new(0, 1, 0) -- Green - Far
                end
            end
            task.wait(0.1)
        end
    end)
end

function removeESPFromPlayer(targetPlayer)
    local espData = espObjects[targetPlayer.Name]
    if espData then
        for _, obj in pairs(espData) do
            if obj and obj.Parent then
                obj:Destroy()
            end
        end
        espObjects[targetPlayer.Name] = nil
    end
end

function disableAdvancedESP()
    for playerName, espData in pairs(espObjects) do
        for _, obj in pairs(espData) do
            if obj and obj.Parent then
                obj:Destroy()
            end
        end
    end
    espObjects = {}
end

-- WEAPON ESP
function enableWeaponESP()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") and not obj.Parent:IsA("Player") and not obj.Parent:IsA("Backpack") then
            addWeaponHighlight(obj)
        end
    end
    
    -- Monitor for new weapons
    Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Tool") and not obj.Parent:IsA("Player") and not obj.Parent:IsA("Backpack") then
            task.wait(0.1)
            addWeaponHighlight(obj)
        end
    end)
end

function addWeaponHighlight(weapon)
    if weapon:FindFirstChild("WeaponESP") then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "WeaponESP"
    highlight.Adornee = weapon
    highlight.FillColor = Color3.new(0, 0, 1)
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = weapon
end

function disableWeaponESP()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj.Name == "WeaponESP" then
            obj:Destroy()
        end
    end
end

-- MOBILE CROSSHAIR
local crosshairGui = nil

function createMobileCrosshair()
    if crosshairGui then
        crosshairGui:Destroy()
    end
    
    crosshairGui = Instance.new("ScreenGui")
    crosshairGui.Name = "MobileCrosshair"
    crosshairGui.Parent = player.PlayerGui
    
    -- Horizontal line
    local hLine = Instance.new("Frame")
    hLine.Size = UDim2.new(0, 20, 0, 2)
    hLine.Position = UDim2.new(0.5, -10, 0.5, -1)
    hLine.BackgroundColor3 = Color3.new(0, 1, 0)
    hLine.BorderSizePixel = 0
    hLine.Parent = crosshairGui
    
    -- Vertical line
    local vLine = Instance.new("Frame")
    vLine.Size = UDim2.new(0, 2, 0, 20)
    vLine.Position = UDim2.new(0.5, -1, 0.5, -10)
    vLine.BackgroundColor3 = Color3.new(0, 1, 0)
    vLine.BorderSizePixel = 0
    vLine.Parent = crosshairGui
    
    -- Center dot
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 4, 0, 4)
    dot.Position = UDim2.new(0.5, -2, 0.5, -2)
    dot.BackgroundColor3 = Color3.new(1, 0, 0)
    dot.BorderSizePixel = 0
    dot.Parent = crosshairGui
    
    -- Make it round
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dot
end

function removeMobileCrosshair()
    if crosshairGui then
        crosshairGui:Destroy()
        crosshairGui = nil
    end
end

-- UTILITY FUNCTIONS
function instantHeal()
    if character and humanoid then
        humanoid.Health = humanoid.MaxHealth
        if Rayfield then
            Rayfield:Notify({
                Title = "Instant Heal",
                Content = "Health restored to maximum!",
                Duration = 2
            })
        end
    end
end

function teleportToSpawn()
    if character and humanoidRootPart then
        -- Common spawn locations in Combat Warriors
        local spawnLocations = {
            CFrame.new(0, 5, 0),
            CFrame.new(50, 5, 0),
            CFrame.new(-50, 5, 0),
            CFrame.new(0, 5, 50),
            CFrame.new(0, 5, -50)
        }
        
        local randomSpawn = spawnLocations[math.random(#spawnLocations)]
        humanoidRootPart.CFrame = randomSpawn
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
        if character and humanoidRootPart then
            humanoidRootPart.CFrame = randomPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(5, 0, 0)
        end
    end
end

function teleportBehindNearestEnemy()
    if not character or not humanoidRootPart then return end
    
    local nearestEnemy = nil
    local nearestDistance = math.huge
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (humanoidRootPart.Position - otherPlayer.Character.HumanoidRootPart.Position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestEnemy = otherPlayer
            end
        end
    end
    
    if nearestEnemy then
        local targetHRP = nearestEnemy.Character.HumanoidRootPart
        local behindPosition = targetHRP.CFrame * CFrame.new(0, 0, 5)
        humanoidRootPart.CFrame = behindPosition
    end
end

-- AUTO GLORY COLLECTION
local gloryConnection = nil

function startAutoGlory()
    if gloryConnection then
        gloryConnection:Disconnect()
    end
    
    gloryConnection = RunService.Heartbeat:Connect(function()
        if not character or not humanoidRootPart then return end
        
        -- Look for glory orbs/coins
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name:lower():find("glory") or obj.Name:lower():find("coin") then
                if obj:IsA("BasePart") then
                    local distance = (humanoidRootPart.Position - obj.Position).Magnitude
                    if distance <= 50 then
                        -- Move towards glory
                        humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, obj.Position)
                        task.wait(0.1)
                    end
                end
            end
        end
    end)
end

function stopAutoGlory()
    if gloryConnection then
        gloryConnection:Disconnect()
        gloryConnection = nil
    end
end

-- ANTI-AFK SYSTEM
local antiAFKConnection = nil

function startAntiAFK()
    antiAFKConnection = task.spawn(function()
        while task.wait(300) do -- Every 5 minutes
            if VIM then
                pcall(function()
                    -- Send random movement input
                    local keys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D}
                    local randomKey = keys[math.random(#keys)]
                    
                    VIM:SendKeyEvent(true, randomKey, false, game)
                    task.wait(0.1)
                    VIM:SendKeyEvent(false, randomKey, false, game)
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

-- PERFORMANCE OPTIMIZATION
function optimizeForMobile()
    -- Reduce render distance
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent ~= character then
            local distance = humanoidRootPart and (humanoidRootPart.Position - obj.Position).Magnitude or 0
            if distance > 100 then
                obj.Transparency = 1
            end
        end
    end
    
    -- Disable unnecessary effects
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
        end
    end
    
    -- Optimize lighting
    Lighting.GlobalShadows = false
    Lighting.Technology = Enum.Technology.Compatibility
    
    if Rayfield then
        Rayfield:Notify({
            Title = "Mobile Optimization",
            Content = "Game optimized for mobile performance!",
            Duration = 3
        })
    end
end

function enableFPSBoost()
    -- Remove visual effects
    for _, obj in pairs(Lighting:GetChildren()) do
        if obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or 
           obj:IsA("DepthOfFieldEffect") or obj:IsA("SunRaysEffect") then
            obj.Enabled = false
        end
    end
    
    -- Set low quality rendering
    settings().Rendering.QualityLevel = 1
    settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
    
    if Rayfield then
        Rayfield:Notify({
            Title = "FPS Boost",
            Content = "FPS boost mode enabled!",
            Duration = 2
        })
    end
end

function disableFPSBoost()
    -- Restore visual effects
    for _, obj in pairs(Lighting:GetChildren()) do
        if obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or 
           obj:IsA("DepthOfFieldEffect") or obj:IsA("SunRaysEffect") then
            obj.Enabled = true
        end
    end
    
    -- Restore quality
    settings().Rendering.QualityLevel = 10
    settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
end

function setLowGraphics(enabled)
    if enabled then
        -- Remove textures and decals
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            elseif obj:IsA("BasePart") then
                obj.Material = Enum.Material.Plastic
            end
        end
    else
        -- Restore textures and decals
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 0
            end
        end
    end
end

-- SERVER HOP FUNCTION
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

-- MAIN UPDATE LOOP
RunService.Heartbeat:Connect(function()
    -- Update character references
    if not character or not character.Parent then
        character = player.Character
        if character then
            humanoid = character:FindFirstChild("Humanoid")
            humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        end
    end
    
    -- Apply speed
    if character and humanoid and humanoid.WalkSpeed ~= currentSpeed then
        humanoid.WalkSpeed = currentSpeed
    end
    
    -- Apply noclip
    if noClip and character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part ~= humanoidRootPart then
                part.CanCollide = false
            end
        end
    end
end)

-- Handle character respawn
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    
    task.wait(2) -- Wait for character to fully load
    
    -- Reapply settings
    if currentSpeed ~= 16 then
        humanoid.WalkSpeed = currentSpeed
    end
    
    -- Re-enable features if they were enabled
    if infiniteStamina then
        enableInfiniteStamina()
    end
    
    if espEnabled then
        task.wait(1)
        enableAdvancedESP()
    end
    
    if hitboxExpander then
        enableHitboxExpander()
    end
    
    if weaponReach then
        enableWeaponReach()
    end
end)

-- Mobile-specific optimizations
if isMobile then
    -- Optimize for mobile devices
    task.spawn(function()
        task.wait(5) -- Wait for game to load
        optimizeForMobile()
    end)
    
    -- Mobile-friendly controls info
    if Rayfield then
        Rayfield:Notify({
            Title = "Mobile Controls",
            Content = "Script optimized for mobile! All features work with touch controls.",
            Duration = 6
        })
    end
end

print("[Combat Warriors Enhanced] Script fully loaded and optimized for mobile!")

end
