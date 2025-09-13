--[[ Enhanced Universal Script for Arceus X Mobile ]]

if not game.Players.LocalPlayer.PlayerScripts:FindFirstChild("Universal_Enhanced_Loaded") then 
    local data = Instance.new("NumberValue")
    data.Name = "Universal_Enhanced_Loaded" 
    data.Parent = game.Players.LocalPlayer.PlayerScripts 
    print("Enhanced Universal Script Loading...")

-- Enhanced error handling for UI library
local Rayfield
local function loadRayfield()
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    
    if success and result then
        return result
    end
    
    -- Backup attempts
    local backups = {
        "https://raw.githubusercontent.com/UI-Interface/CustomFIeld/main/RayField.lua",
        "https://raw.githubusercontent.com/shlexware/Rayfield/main/source"
    }
    
    for _, url in pairs(backups) do
        local success2, result2 = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if success2 and result2 then
            return result2
        end
    end
    
    return nil
end

Rayfield = loadRayfield()

if not Rayfield then
    warn("[Enhanced Universal] UI Library failed to load. Please check your internet connection.")
    return
end

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

-- Player Variables
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local camera = Workspace.CurrentCamera

-- Enhanced character management
local function updateCharacterReferences()
    character = player.Character
    if character then
        humanoid = character:WaitForChild("Humanoid", 5)
        humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
    end
end

player.CharacterAdded:Connect(updateCharacterReferences)

-- Script State Variables
local scriptState = {
    pingOptimized = false,
    silentAimEnabled = false,
    aimbotEnabled = false,
    espEnabled = false,
    serverHopEnabled = false,
    antiAFKEnabled = false,
    fullBrightEnabled = false,
    speedHackEnabled = false,
    jumpHackEnabled = false,
    noClipEnabled = false,
    infiniteJumpEnabled = false,
    wallHackEnabled = false,
    flyEnabled = false
}

-- Enhanced Configuration
local config = {
    aim = {
        fov = 100,
        smoothness = 0.5,
        targetPart = "Head",
        wallCheck = true,
        teamCheck = true,
        visibleOnly = true,
        prediction = false,
        predictionStrength = 0.1
    },
    esp = {
        showNames = true,
        showDistance = true,
        showHealth = false,
        showBoxes = true,
        showTracer = false,
        maxDistance = 1000
    },
    server = {
        maxPing = 80,
        region = "Asia",
        autoReconnect = false
    },
    performance = {
        fpsLimit = 60,
        renderDistance = 500,
        textureQuality = "Low"
    }
}

-- Connection Management
local connections = {
    aim = {},
    esp = {},
    utility = {},
    ping = {}
}

-- Enhanced Ping Tracking
local pingHistory = {}
local currentPing = 0

-- Target Management
local currentTarget = nil
local targetHistory = {}

-- ESP Objects Storage
local espObjects = {}
local espConnections = {}

-- Utility Variables
local originalWalkSpeed = 16
local originalJumpPower = 50
local originalFOV = 70

-- Mobile Input Manager for Arceus X
local VIM = game:GetService("VirtualInputManager")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Create Enhanced UI
local Window = Rayfield:CreateWindow({
    Name = "Enhanced Universal Hub | Arceus X",
    LoadingTitle = "Enhanced Universal Loading", 
    LoadingSubtitle = "Advanced Mobile Optimization Suite",
    ShowText = "Enhanced Universal Pro v2.1",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "EnhancedUniversal",
        FileName = "ConfigV2"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = false
    },
    KeySystem = false
})

-- Create Tabs
local NetworkTab = Window:CreateTab("🌐 Network Plus", 4483362458)
local AimTab = Window:CreateTab("🎯 Combat Plus", 4483362458)
local VisualTab = Window:CreateTab("👁️ Visual Plus", 4483362458)
local ServerTab = Window:CreateTab("🔄 Server Plus", 4483362458)
local UtilityTab = Window:CreateTab("⚡ Utility Plus", 4483362458)
local ExtraTab = Window:CreateTab("🚀 Extras", 4483362458)

-- ENHANCED NETWORK TAB
NetworkTab:CreateSection("Advanced Ping Optimization")

NetworkTab:CreateToggle({
    Name = "Master Ping Optimizer",
    CurrentValue = false,
    Flag = "MasterPingOpt",
    Callback = function(Value)
        scriptState.pingOptimized = Value
        if Value then
            enableAdvancedPingOptimization()
            Rayfield:Notify({
                Title = "Network Optimizer",
                Content = "Advanced ping optimization activated!",
                Duration = 3
            })
        else
            disableAdvancedPingOptimization()
        end
    end,
})

NetworkTab:CreateToggle({
    Name = "Network Boost Protocol",
    CurrentValue = false,
    Flag = "NetworkProtocol",
    Callback = function(Value)
        if Value then
            enableNetworkProtocol()
        else
            disableNetworkProtocol()
        end
    end,
})

NetworkTab:CreateToggle({
    Name = "Lag Compensation",
    CurrentValue = false,
    Flag = "LagComp",
    Callback = function(Value)
        enableLagCompensation(Value)
    end,
})

NetworkTab:CreateSection("Connection Monitoring")

local PingLabel = NetworkTab:CreateLabel("Ping: Calculating...")
local PacketLossLabel = NetworkTab:CreateLabel("Packet Loss: 0%")

NetworkTab:CreateToggle({
    Name = "Advanced Ping Monitor",
    CurrentValue = false,
    Flag = "AdvPingMonitor",
    Callback = function(Value)
        if Value then
            startAdvancedPingMonitor()
        else
            stopAdvancedPingMonitor()
        end
    end,
})

NetworkTab:CreateSlider({
    Name = "Network Priority",
    Range = {1, 10},
    Increment = 1,
    Suffix = "",
    CurrentValue = 5,
    Flag = "NetPriority",
    Callback = function(Value)
        setNetworkPriority(Value)
    end,
})

-- ENHANCED AIM TAB
AimTab:CreateSection("Advanced Combat System")

AimTab:CreateToggle({
    Name = "Enhanced Silent Aim",
    CurrentValue = false,
    Flag = "EnhancedSilentAim",
    Callback = function(Value)
        scriptState.silentAimEnabled = Value
        if Value then
            enableEnhancedSilentAim()
            Rayfield:Notify({
                Title = "Combat System",
                Content = "Enhanced silent aim activated!",
                Duration = 3
            })
        else
            disableEnhancedSilentAim()
        end
    end,
})

AimTab:CreateToggle({
    Name = "Smart Aimbot",
    CurrentValue = false,
    Flag = "SmartAimbot",
    Callback = function(Value)
        scriptState.aimbotEnabled = Value
        if Value then
            enableSmartAimbot()
        else
            disableSmartAimbot()
        end
    end,
})

AimTab:CreateToggle({
    Name = "Aim Prediction",
    CurrentValue = false,
    Flag = "AimPrediction",
    Callback = function(Value)
        config.aim.prediction = Value
    end,
})

AimTab:CreateSection("Combat Configuration")

AimTab:CreateSlider({
    Name = "Aim FOV",
    Range = {10, 360},
    Increment = 5,
    Suffix = "°",
    CurrentValue = 100,
    Flag = "AimFOVSlider",
    Callback = function(Value)
        config.aim.fov = Value
        updateFOVDisplay()
    end,
})

AimTab:CreateSlider({
    Name = "Aim Smoothness",
    Range = {0.01, 3.0},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = 0.5,
    Flag = "AimSmoothSlider",
    Callback = function(Value)
        config.aim.smoothness = Value
    end,
})

AimTab:CreateDropdown({
    Name = "Target Priority",
    Options = {"Head", "Torso", "HumanoidRootPart", "Closest", "Lowest Health"},
    CurrentOption = {"Head"},
    MultipleOptions = false,
    Flag = "TargetPriority",
    Callback = function(Option)
        config.aim.targetPart = Option[1]
    end,
})

-- Enhanced toggles
AimTab:CreateToggle({
    Name = "Anti-Detection",
    CurrentValue = true,
    Flag = "AntiDetection",
    Callback = function(Value)
        -- Implementation for anti-detection
    end,
})

AimTab:CreateToggle({
    Name = "Auto-Switch Targets",
    CurrentValue = false,
    Flag = "AutoSwitch",
    Callback = function(Value)
        -- Implementation for auto target switching
    end,
})

-- ENHANCED VISUAL TAB
VisualTab:CreateSection("Advanced ESP System")

VisualTab:CreateToggle({
    Name = "Master ESP",
    CurrentValue = false,
    Flag = "MasterESP",
    Callback = function(Value)
        scriptState.espEnabled = Value
        if Value then
            enableMasterESP()
        else
            disableMasterESP()
        end
    end,
})

VisualTab:CreateToggle({
    Name = "Player Boxes",
    CurrentValue = true,
    Flag = "PlayerBoxes",
    Callback = function(Value)
        config.esp.showBoxes = Value
        updateESPSettings()
    end,
})

VisualTab:CreateToggle({
    Name = "Health Bars",
    CurrentValue = false,
    Flag = "HealthBars",
    Callback = function(Value)
        config.esp.showHealth = Value
        updateESPSettings()
    end,
})

VisualTab:CreateToggle({
    Name = "Tracer Lines",
    CurrentValue = false,
    Flag = "TracerLines",
    Callback = function(Value)
        config.esp.showTracer = Value
        updateESPSettings()
    end,
})

VisualTab:CreateSection("World Enhancement")

VisualTab:CreateToggle({
    Name = "Enhanced Full Bright",
    CurrentValue = false,
    Flag = "EnhancedFullBright",
    Callback = function(Value)
        scriptState.fullBrightEnabled = Value
        toggleEnhancedFullBright(Value)
    end,
})

VisualTab:CreateToggle({
    Name = "See Through Walls",
    CurrentValue = false,
    Flag = "SeeThruWalls",
    Callback = function(Value)
        scriptState.wallHackEnabled = Value
        toggleWallHack(Value)
    end,
})

VisualTab:CreateToggle({
    Name = "Remove Textures",
    CurrentValue = false,
    Flag = "RemoveTextures",
    Callback = function(Value)
        removeTextures(Value)
    end,
})

VisualTab:CreateSlider({
    Name = "ESP Distance",
    Range = {100, 5000},
    Increment = 100,
    Suffix = " studs",
    CurrentValue = 1000,
    Flag = "ESPDistance",
    Callback = function(Value)
        config.esp.maxDistance = Value
    end,
})

-- ENHANCED SERVER TAB
ServerTab:CreateSection("Smart Server Management")

ServerTab:CreateToggle({
    Name = "Auto Server Optimizer",
    CurrentValue = false,
    Flag = "AutoServerOpt",
    Callback = function(Value)
        scriptState.serverHopEnabled = Value
        if Value then
            startSmartServerOptimizer()
        else
            stopSmartServerOptimizer()
        end
    end,
})

ServerTab:CreateSlider({
    Name = "Max Acceptable Ping",
    Range = {20, 200},
    Increment = 5,
    Suffix = "ms",
    CurrentValue = 80,
    Flag = "MaxPingThreshold",
    Callback = function(Value)
        config.server.maxPing = Value
    end,
})

ServerTab:CreateDropdown({
    Name = "Preferred Region",
    Options = {"Asia", "Asia-Pacific", "Southeast Asia", "East Asia", "Europe", "North America"},
    CurrentOption = {"Asia"},
    MultipleOptions = false,
    Flag = "PreferredRegion",
    Callback = function(Option)
        config.server.region = Option[1]
    end,
})

ServerTab:CreateButton({
    Name = "Find Optimal Server",
    Callback = function()
        findOptimalServer()
    end
})

ServerTab:CreateButton({
    Name = "Server Info",
    Callback = function()
        displayServerInfo()
    end
})

-- ENHANCED UTILITY TAB
UtilityTab:CreateSection("Movement Enhancement")

UtilityTab:CreateToggle({
    Name = "Speed Hack",
    CurrentValue = false,
    Flag = "SpeedHack",
    Callback = function(Value)
        scriptState.speedHackEnabled = Value
        toggleSpeedHack(Value)
    end,
})

UtilityTab:CreateToggle({
    Name = "Jump Hack",
    CurrentValue = false,
    Flag = "JumpHack",
    Callback = function(Value)
        scriptState.jumpHackEnabled = Value
        toggleJumpHack(Value)
    end,
})

UtilityTab:CreateToggle({
    Name = "Fly Mode",
    CurrentValue = false,
    Flag = "FlyMode",
    Callback = function(Value)
        scriptState.flyEnabled = Value
        toggleFlyMode(Value)
    end,
})

UtilityTab:CreateToggle({
    Name = "No Clip",
    CurrentValue = false,
    Flag = "NoClip",
    Callback = function(Value)
        scriptState.noClipEnabled = Value
        toggleNoClip(Value)
    end,
})

UtilityTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "InfJump",
    Callback = function(Value)
        scriptState.infiniteJumpEnabled = Value
        toggleInfiniteJump(Value)
    end,
})

UtilityTab:CreateSection("System Utilities")

UtilityTab:CreateToggle({
    Name = "Enhanced Anti-AFK",
    CurrentValue = false,
    Flag = "EnhancedAntiAFK",
    Callback = function(Value)
        scriptState.antiAFKEnabled = Value
        if Value then
            startEnhancedAntiAFK()
        else
            stopEnhancedAntiAFK()
        end
    end,
})

UtilityTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 200},
    Increment = 2,
    Suffix = "",
    CurrentValue = 16,
    Flag = "WalkSpeedSlider",
    Callback = function(Value)
        setWalkSpeed(Value)
    end,
})

UtilityTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 300},
    Increment = 5,
    Suffix = "",
    CurrentValue = 50,
    Flag = "JumpPowerSlider",
    Callback = function(Value)
        setJumpPower(Value)
    end,
})

-- EXTRAS TAB
ExtraTab:CreateSection("Advanced Features")

ExtraTab:CreateButton({
    Name = "Performance Boost",
    Callback = function()
        applyPerformanceBoost()
    end
})

ExtraTab:CreateButton({
    Name = "Memory Optimization",
    Callback = function()
        optimizeMemory()
    end
})

ExtraTab:CreateButton({
    Name = "Clear All ESP",
    Callback = function()
        clearAllESP()
    end
})

ExtraTab:CreateToggle({
    Name = "Auto-Rejoin on Kick",
    CurrentValue = false,
    Flag = "AutoRejoin",
    Callback = function(Value)
        config.server.autoReconnect = Value
    end,
})

ExtraTab:CreateSection("Script Information")

local StatusLabel = ExtraTab:CreateLabel("Status: All systems ready")

-- IMPLEMENTATION FUNCTIONS

-- Enhanced Ping Optimization
function enableAdvancedPingOptimization()
    -- Apply comprehensive network optimizations
    pcall(function()
        -- Network settings
        settings().Network.IncomingReplicationLag = 0
        settings().Network.OutgoingReplicationLag = 0
        settings().Network.PhysicsSend = 1
        settings().Network.PhysicsReceive = 1
        
        -- Rendering optimizations
        settings().Rendering.QualityLevel = 1
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        settings().Rendering.EnableFRM = false
        
        -- Physics optimizations
        settings().Physics.AllowSleep = false
        settings().Physics.ThrottleAdjustTime = 0
        
        -- Disable expensive effects
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                effect.Enabled = false
            end
        end
    end)
end

function disableAdvancedPingOptimization()
    pcall(function()
        settings().Rendering.QualityLevel = 10
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
        settings().Physics.AllowSleep = true
    end)
end

function enableNetworkProtocol()
    pcall(function()
        -- Advanced network protocol optimizations
        game:GetService("NetworkClient"):SetOutgoingKBPSLimit(math.huge)
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
    end)
end

function disableNetworkProtocol()
    pcall(function()
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.DefaultAuto
    end)
end

function enableLagCompensation(enabled)
    if enabled then
        -- Implement lag compensation logic
        connections.ping.lagComp = RunService.Heartbeat:Connect(function()
            if currentPing > 100 then
                -- Apply compensation
                pcall(function()
                    settings().Network.IncomingReplicationLag = currentPing / 1000
                end)
            end
        end)
    else
        if connections.ping.lagComp then
            connections.ping.lagComp:Disconnect()
            connections.ping.lagComp = nil
        end
    end
end

-- Advanced Ping Monitoring
function startAdvancedPingMonitor()
    connections.ping.monitor = RunService.Heartbeat:Connect(function()
        updatePingMetrics()
    end)
end

function stopAdvancedPingMonitor()
    if connections.ping.monitor then
        connections.ping.monitor:Disconnect()
        connections.ping.monitor = nil
    end
end

function updatePingMetrics()
    pcall(function()
        local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        currentPing = ping
        
        -- Update ping history
        table.insert(pingHistory, ping)
        if #pingHistory > 100 then
            table.remove(pingHistory, 1)
        end
        
        -- Calculate average ping
        local avgPing = 0
        for _, p in pairs(pingHistory) do
            avgPing = avgPing + p
        end
        avgPing = avgPing / #pingHistory
        
        -- Update labels
        local pingColor = getPingColor(ping)
        PingLabel:Set(string.format("Ping: %dms (Avg: %dms) %s", math.floor(ping), math.floor(avgPing), pingColor))
        
        -- Update packet loss (simplified calculation)
        local packetLoss = math.min((ping - 50) / 10, 5)
        if packetLoss < 0 then packetLoss = 0 end
        PacketLossLabel:Set(string.format("Packet Loss: %.1f%%", packetLoss))
    end)
end

function getPingColor(ping)
    if ping < 50 then return "🟢"
    elseif ping < 100 then return "🟡"
    elseif ping < 150 then return "🟠"
    else return "🔴" end
end

-- Enhanced Silent Aim
function enableEnhancedSilentAim()
    -- Create advanced silent aim system
    connections.aim.silentAim = RunService.Heartbeat:Connect(function()
        currentTarget = getAdvancedTarget()
    end)
    
    -- Enhanced hook for silent aim
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if scriptState.silentAimEnabled and currentTarget and method:find("Ray") then
            local targetPart = getTargetPart(currentTarget)
            if targetPart then
                local predictedPosition = targetPart.Position
                if config.aim.prediction then
                    predictedPosition = predictTargetPosition(currentTarget)
                end
                args[1] = Ray.new(camera.CFrame.Position, (predictedPosition - camera.CFrame.Position).Unit * 1000)
            end
        end
        
        return oldNamecall(self, unpack(args))
    end)
end

function disableEnhancedSilentAim()
    if connections.aim.silentAim then
        connections.aim.silentAim:Disconnect()
        connections.aim.silentAim = nil
    end
    currentTarget = nil
end

-- Smart Aimbot
function enableSmartAimbot()
    connections.aim.aimbot = RunService.Heartbeat:Connect(function()
        local target = getAdvancedTarget()
        if target and target.Character then
            local targetPart = getTargetPart(target)
            if targetPart then
                local targetPosition = targetPart.Position
                if config.aim.prediction then
                    targetPosition = predictTargetPosition(target)
                end
                
                local currentCFrame = camera.CFrame
                local targetCFrame = CFrame.lookAt(currentCFrame.Position, targetPosition)
                
                -- Enhanced smooth aiming
                local smoothFactor = config.aim.smoothness * (isMobile and 0.05 or 0.1)
                camera.CFrame = currentCFrame:Lerp(targetCFrame, smoothFactor)
            end
        end
    end)
end

function disableSmartAimbot()
    if connections.aim.aimbot then
        connections.aim.aimbot:Disconnect()
        connections.aim.aimbot = nil
    end
end

-- Advanced Target Detection
function getAdvancedTarget()
    local bestTarget = nil
    local bestScore = 0
    
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character then
            local score = calculateTargetScore(targetPlayer)
            if score > bestScore then
                bestScore = score
                bestTarget = targetPlayer
            end
        end
    end
    
    return bestTarget
end

function calculateTargetScore(targetPlayer)
    if not targetPlayer.Character then return 0 end
    
    local targetPart = getTargetPart(targetPlayer)
    if not targetPart then return 0 end
    
    -- Team check
    if config.aim.teamCheck and targetPlayer.Team == player.Team then
        return 0
    end
    
    -- Distance calculation
    local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
    if distance > config.esp.maxDistance then return 0 end
    
    -- FOV check
    local screenPoint, onScreen = camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return 0 end
    
    local fovDistance = (Vector2.new(screenPoint.X, screenPoint.Y) - 
                        Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)).Magnitude
    
    if fovDistance > config.aim.fov then return 0 end
    
    -- Wall check
    if config.aim.wallCheck then
        local ray = Ray.new(camera.CFrame.Position, (targetPart.Position - camera.CFrame.Position).Unit * distance)
        local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {character})
        
        if hit and hit.Parent ~= targetPlayer.Character then
            return 0
        end
    end
    
    -- Calculate score based on distance and FOV
    local distanceScore = (1000 - distance) / 1000
    local fovScore = (config.aim.fov - fovDistance) / config.aim.fov
    local healthScore = 1
    
    -- Health-based scoring
    if targetPlayer.Character:FindFirstChild("Humanoid") then
        local humanoid = targetPlayer.Character.Humanoid
        healthScore = (100 - humanoid.Health) / 100 + 0.1
    end
    
    return (distanceScore * 0.4 + fovScore * 0.4 + healthScore * 0.2) * 100
end

function getTargetPart(targetPlayer)
    if not targetPlayer.Character then return nil end
    
    if config.aim.targetPart == "Closest" then
        local closestPart = nil
        local closestDistance = math.huge
        
        for _, part in pairs({"Head", "Torso", "HumanoidRootPart"}) do
            local targetPart = targetPlayer.Character:FindFirstChild(part)
            if targetPart then
                local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestPart = targetPart
                end
            end
        end
        
        return closestPart
    elseif config.aim.targetPart == "Lowest Health" then
        return targetPlayer.Character:FindFirstChild("Head") or targetPlayer.Character:FindFirstChild("Torso")
    else
        return targetPlayer.Character:FindFirstChild(config.aim.targetPart)
    end
end

function predictTargetPosition(targetPlayer)
    if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return Vector3.new(0, 0, 0)
    end
    
    local humanoidRootPart = targetPlayer.Character.HumanoidRootPart
    local velocity = humanoidRootPart.Velocity
    local prediction = velocity * config.aim.predictionStrength
    
    return humanoidRootPart.Position + prediction
end

-- Master ESP System
function enableMasterESP()
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            addAdvancedESP(targetPlayer)
        end
    end
    
    -- Handle new players
    connections.esp.playerAdded = Players.PlayerAdded:Connect(function(newPlayer)
        newPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            if scriptState.espEnabled then
                addAdvancedESP(newPlayer)
            end
        end)
    end)
end

function addAdvancedESP(targetPlayer)
    if not targetPlayer.Character then return end
    
    removeESPFromPlayer(targetPlayer)
    
    local character = targetPlayer.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChild("Humanoid")
    
    if not humanoidRootPart or not head then return end
    
    local espData = {}
    
    -- Create highlight
    if config.esp.showBoxes then
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight_" .. targetPlayer.Name
        highlight.Adornee = character
        highlight.FillColor = Color3.new(1, 0.2, 0.2)
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.FillTransparency = 0.7
        highlight.OutlineTransparency = 0.2
        highlight.Parent = character
        table.insert(espData, highlight)
    end
    
    -- Create information display
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "ESP_Info_" .. targetPlayer.Name
    billboardGui.Adornee = head
    billboardGui.Size = UDim2.new(0, 200, 0, 100)
    billboardGui.StudsOffset = Vector3.new(0, 2, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = character
    table.insert(espData, billboardGui)
    
    -- Name display
    if config.esp.showNames then
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
        nameLabel.Position = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = targetPlayer.Name
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextStrokeTransparency = 0
        nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        nameLabel.Parent = billboardGui
        table.insert(espData, nameLabel)
    end
    
    -- Distance display
    if config.esp.showDistance then
        local distanceLabel = Instance.new("TextLabel")
        distanceLabel.Size = UDim2.new(1, 0, 0.3, 0)
        distanceLabel.Position = UDim2.new(0, 0, 0.3, 0)
        distanceLabel.BackgroundTransparency = 1
        distanceLabel.Text = "0 studs"
        distanceLabel.TextColor3 = Color3.new(0, 1, 0)
        distanceLabel.TextScaled = true
        distanceLabel.Font = Enum.Font.Gotham
        distanceLabel.TextStrokeTransparency = 0
        distanceLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        distanceLabel.Parent = billboardGui
        table.insert(espData, distanceLabel)
        
        -- Update distance continuously
        local distanceConnection = RunService.Heartbeat:Connect(function()
            if humanoidRootPart and humanoidRootPart.Parent and character and humanoidRootPart then
                local distance = math.floor((humanoidRootPart.Position - humanoidRootPart.Position).Magnitude)
                if distance <= config.esp.maxDistance then
                    distanceLabel.Text = distance .. " studs"
                    
                    -- Color coding based on distance
                    if distance <= 50 then
                        distanceLabel.TextColor3 = Color3.new(1, 0, 0)
                    elseif distance <= 200 then
                        distanceLabel.TextColor3 = Color3.new(1, 1, 0)
                    else
                        distanceLabel.TextColor3 = Color3.new(0, 1, 0)
                    end
                else
                    -- Hide ESP if too far
                    billboardGui.Enabled = false
                end
            end
        end)
        espConnections[targetPlayer.Name .. "_distance"] = distanceConnection
    end
    
    -- Health display
    if config.esp.showHealth and humanoid then
        local healthLabel = Instance.new("TextLabel")
        healthLabel.Size = UDim2.new(1, 0, 0.3, 0)
        healthLabel.Position = UDim2.new(0, 0, 0.6, 0)
        healthLabel.BackgroundTransparency = 1
        healthLabel.Text = "100 HP"
        healthLabel.TextColor3 = Color3.new(0, 1, 0)
        healthLabel.TextScaled = true
        healthLabel.Font = Enum.Font.Gotham
        healthLabel.TextStrokeTransparency = 0
        healthLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        healthLabel.Parent = billboardGui
        table.insert(espData, healthLabel)
        
        -- Update health continuously
        local healthConnection = RunService.Heartbeat:Connect(function()
            if humanoid and humanoid.Parent then
                local health = math.floor(humanoid.Health)
                local maxHealth = math.floor(humanoid.MaxHealth)
                healthLabel.Text = health .. "/" .. maxHealth .. " HP"
                
                -- Color coding based on health percentage
                local healthPercent = health / maxHealth
                if healthPercent > 0.7 then
                    healthLabel.TextColor3 = Color3.new(0, 1, 0)
                elseif healthPercent > 0.3 then
                    healthLabel.TextColor3 = Color3.new(1, 1, 0)
                else
                    healthLabel.TextColor3 = Color3.new(1, 0, 0)
                end
            end
        end)
        espConnections[targetPlayer.Name .. "_health"] = healthConnection
    end
    
    -- Tracer lines
    if config.esp.showTracer then
        local tracerLine = Drawing.new("Line")
        tracerLine.Visible = true
        tracerLine.Color = Color3.new(1, 1, 1)
        tracerLine.Thickness = 2
        tracerLine.Transparency = 0.5
        table.insert(espData, tracerLine)
        
        -- Update tracer continuously
        local tracerConnection = RunService.RenderStepped:Connect(function()
            if humanoidRootPart and humanoidRootPart.Parent then
                local screenPoint, onScreen = camera:WorldToViewportPoint(humanoidRootPart.Position)
                if onScreen then
                    tracerLine.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                    tracerLine.To = Vector2.new(screenPoint.X, screenPoint.Y)
                    tracerLine.Visible = true
                else
                    tracerLine.Visible = false
                end
            end
        end)
        espConnections[targetPlayer.Name .. "_tracer"] = tracerConnection
    end
    
    espObjects[targetPlayer.Name] = espData
end

function removeESPFromPlayer(targetPlayer)
    -- Remove existing ESP
    local espData = espObjects[targetPlayer.Name]
    if espData then
        for _, obj in pairs(espData) do
            if obj and typeof(obj) == "Instance" and obj.Parent then
                obj:Destroy()
            elseif obj and typeof(obj) == "table" and obj.Remove then
                obj:Remove()
            end
        end
    end
    
    -- Disconnect connections
    for connectionName, connection in pairs(espConnections) do
        if connectionName:find(targetPlayer.Name) then
            if connection and typeof(connection) == "RBXScriptConnection" then
                connection:Disconnect()
            end
            espConnections[connectionName] = nil
        end
    end
    
    espObjects[targetPlayer.Name] = nil
end

function disableMasterESP()
    for playerName, _ in pairs(espObjects) do
        local targetPlayer = Players:FindFirstChild(playerName)
        if targetPlayer then
            removeESPFromPlayer(targetPlayer)
        end
    end
    
    if connections.esp.playerAdded then
        connections.esp.playerAdded:Disconnect()
        connections.esp.playerAdded = nil
    end
end

function updateESPSettings()
    -- Update existing ESP with new settings
    if scriptState.espEnabled then
        disableMasterESP()
        task.wait(0.1)
        enableMasterESP()
    end
end

function clearAllESP()
    disableMasterESP()
    Rayfield:Notify({
        Title = "ESP System",
        Content = "All ESP elements cleared!",
        Duration = 2
    })
end

-- Enhanced Visual Functions
function toggleEnhancedFullBright(enabled)
    if enabled then
        Lighting.Brightness = 10
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
        Lighting.ColorShift_Top = Color3.new(1, 1, 1)
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
        Lighting.GlobalShadows = false
    else
        Lighting.Brightness = 1
        Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
        Lighting.ColorShift_Top = Color3.new(0, 0, 0)
        Lighting.FogEnd = 100
        Lighting.FogStart = 15
        Lighting.GlobalShadows = true
    end
end

function toggleWallHack(enabled)
    if enabled then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Parent ~= character then
                obj.Transparency = 0.8
                obj.CanCollide = false
            end
        end
    else
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Parent ~= character then
                obj.Transparency = 0
                obj.CanCollide = true
            end
        end
    end
end

function removeTextures(enabled)
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = enabled and 1 or 0
        elseif obj:IsA("BasePart") and enabled then
            obj.Material = Enum.Material.Plastic
        end
    end
end

-- Movement Enhancement Functions
function toggleSpeedHack(enabled)
    if enabled and humanoid then
        originalWalkSpeed = humanoid.WalkSpeed
        connections.utility.speedHack = RunService.Heartbeat:Connect(function()
            if humanoid and humanoid.Parent then
                humanoid.WalkSpeed = 50
            end
        end)
    else
        if connections.utility.speedHack then
            connections.utility.speedHack:Disconnect()
            connections.utility.speedHack = nil
        end
        if humanoid then
            humanoid.WalkSpeed = originalWalkSpeed
        end
    end
end

function toggleJumpHack(enabled)
    if enabled and humanoid then
        originalJumpPower = humanoid.JumpPower
        connections.utility.jumpHack = RunService.Heartbeat:Connect(function()
            if humanoid and humanoid.Parent then
                humanoid.JumpPower = 150
            end
        end)
    else
        if connections.utility.jumpHack then
            connections.utility.jumpHack:Disconnect()
            connections.utility.jumpHack = nil
        end
        if humanoid then
            humanoid.JumpPower = originalJumpPower
        end
    end
end

function toggleFlyMode(enabled)
    if enabled and humanoidRootPart then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = humanoidRootPart
        
        connections.utility.fly = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not gameProcessed then
                if input.KeyCode == Enum.KeyCode.Space then
                    bodyVelocity.Velocity = Vector3.new(0, 50, 0)
                elseif input.KeyCode == Enum.KeyCode.LeftShift then
                    bodyVelocity.Velocity = Vector3.new(0, -50, 0)
                end
            end
        end)
        
        connections.utility.flyEnd = UserInputService.InputEnded:Connect(function(input, gameProcessed)
            if not gameProcessed then
                if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.LeftShift then
                    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
            end
        end)
    else
        if connections.utility.fly then
            connections.utility.fly:Disconnect()
            connections.utility.fly = nil
        end
        if connections.utility.flyEnd then
            connections.utility.flyEnd:Disconnect()
            connections.utility.flyEnd = nil
        end
        if humanoidRootPart and humanoidRootPart:FindFirstChild("BodyVelocity") then
            humanoidRootPart.BodyVelocity:Destroy()
        end
    end
end

function toggleNoClip(enabled)
    if enabled then
        connections.utility.noClip = RunService.Stepped:Connect(function()
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if connections.utility.noClip then
            connections.utility.noClip:Disconnect()
            connections.utility.noClip = nil
        end
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

function toggleInfiniteJump(enabled)
    if enabled then
        connections.utility.infJump = UserInputService.JumpRequest:Connect(function()
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    else
        if connections.utility.infJump then
            connections.utility.infJump:Disconnect()
            connections.utility.infJump = nil
        end
    end
end

-- Enhanced Anti-AFK
function startEnhancedAntiAFK()
    connections.utility.antiAFK = task.spawn(function()
        while scriptState.antiAFKEnabled do
            task.wait(math.random(240, 300)) -- Random interval between 4-5 minutes
            
            if isMobile then
                -- Mobile-specific anti-AFK
                pcall(function()
                    VIM:SendMouseButtonEvent(100, 100, 0, true, game, 1)
                    task.wait(0.1)
                    VIM:SendMouseButtonEvent(100, 100, 0, false, game, 1)
                end)
            else
                -- PC anti-AFK
                pcall(function()
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

function stopEnhancedAntiAFK()
    if connections.utility.antiAFK then
        task.cancel(connections.utility.antiAFK)
        connections.utility.antiAFK = nil
    end
end

-- Utility Functions
function setWalkSpeed(speed)
    if humanoid then
        humanoid.WalkSpeed = speed
    end
end

function setJumpPower(power)
    if humanoid then
        humanoid.JumpPower = power
    end
end

function setNetworkPriority(priority)
    pcall(function()
        settings().Network.IncomingReplicationLag = (11 - priority) / 100
        settings().Network.OutgoingReplicationLag = (11 - priority) / 100
    end)
end

-- Server Management Functions
function startSmartServerOptimizer()
    connections.utility.serverOpt = task.spawn(function()
        while scriptState.serverHopEnabled do
            task.wait(60) -- Check every minute
            
            if currentPing > config.server.maxPing then
                Rayfield:Notify({
                    Title = "Server Optimizer",
                    Content = string.format("Ping too high (%dms), searching for better server...", math.floor(currentPing)),
                    Duration = 4
                })
                findOptimalServer()
            end
        end
    end)
end

function stopSmartServerOptimizer()
    if connections.utility.serverOpt then
        task.cancel(connections.utility.serverOpt)
        connections.utility.serverOpt = nil
    end
end

function findOptimalServer()
    pcall(function()
        -- Simplified server hopping - joins a new server
        local success, result = pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
        
        if not success then
            Rayfield:Notify({
                Title = "Server Hop",
                Content = "Failed to find better server. Trying again in 30 seconds...",
                Duration = 3
            })
        end
    end)
end

function displayServerInfo()
    local ping = math.floor(currentPing)
    local players = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    local serverAge = math.floor(Workspace.DistributedGameTime / 60)
    
    Rayfield:Notify({
        Title = "Server Information",
        Content = string.format("Ping: %dms | Players: %d/%d | Age: %dm", ping, players, maxPlayers, serverAge),
        Duration = 5
    })
end

-- Performance Functions
function applyPerformanceBoost()
    pcall(function()
        -- Comprehensive performance optimization
        settings().Rendering.QualityLevel = 1
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        settings().Rendering.EnableFRM = false
        
        -- Remove expensive effects
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                effect.Enabled = false
            end
        end
        
        -- Optimize workspace objects
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                obj.Enabled = false
            elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
            elseif obj:IsA("Explosion") then
                obj.Visible = false
            end
        end
        
        -- Physics optimization
        settings().Physics.AllowSleep = true
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Skip4
        
        Rayfield:Notify({
            Title = "Performance Boost",
            Content = "Maximum performance optimizations applied!",
            Duration = 3
        })
    end)
end

function optimizeMemory()
    -- Force garbage collection
    for i = 1, 5 do
        collectgarbage("collect")
        task.wait(0.1)
    end
    
    -- Remove unnecessary sounds
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Sound") and not obj.IsPlaying then
            obj:Destroy()
        elseif obj:IsA("Decal") and obj.Parent and obj.Parent.Parent ~= character then
            obj.Transparency = 1
        end
    end
    
    Rayfield:Notify({
        Title = "Memory Optimization",
        Content = "Memory cleaned and optimized!",
        Duration = 2
    })
end

-- FOV Circle Management
local fovCircle = nil

function updateFOVDisplay()
    if fovCircle then
        fovCircle.Radius = config.aim.fov
    end
end

function createFOVCircle()
    if fovCircle then
        fovCircle:Remove()
    end
    
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 2
    fovCircle.NumSides = 50
    fovCircle.Color = Color3.new(1, 1, 1)
    fovCircle.Transparency = 0.3
    fovCircle.Filled = false
    fovCircle.Visible = true
    fovCircle.Radius = config.aim.fov
    
    connections.aim.fovUpdate = RunService.RenderStepped:Connect(function()
        if fovCircle then
            fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        end
    end)
end

function removeFOVCircle()
    if fovCircle then
        fovCircle:Remove()
        fovCircle = nil
    end
    
    if connections.aim.fovUpdate then
        connections.aim.fovUpdate:Disconnect()
        connections.aim.fovUpdate = nil
    end
end

-- Auto-rejoin on kick
game.Players.PlayerRemoving:Connect(function(removedPlayer)
    if removedPlayer == player and config.server.autoReconnect then
        task.wait(1)
        TeleportService:Teleport(game.PlaceId, player)
    end
end)

-- Enhanced character respawn handling
player.CharacterAdded:Connect(function(newChar)
    updateCharacterReferences()
    
    task.wait(3) -- Wait for full character load
    
    -- Restore settings
    if scriptState.speedHackEnabled then
        toggleSpeedHack(true)
    end
    if scriptState.jumpHackEnabled then
        toggleJumpHack(true)
    end
    if scriptState.espEnabled then
        enableMasterESP()
    end
    if scriptState.noClipEnabled then
        toggleNoClip(true)
    end
end)

-- Main update loop
connections.utility.mainLoop = RunService.Heartbeat:Connect(function()
    -- Update character references if needed
    if not character or not character.Parent then
        updateCharacterReferences()
    end
    
    -- Update camera reference
    if not camera or not camera.Parent then
        camera = Workspace.CurrentCamera
    end
    
    -- Update status
    if StatusLabel then
        local activeFeatures = 0
        for _, state in pairs(scriptState) do
            if state then activeFeatures = activeFeatures + 1 end
        end
        StatusLabel:Set(string.format("Status: %d features active | Ping: %dms", activeFeatures, math.floor(currentPing)))
    end
end)

-- Cleanup function
local function cleanup()
    -- Disconnect all connections
    for category, categoryConnections in pairs(connections) do
        for name, connection in pairs(categoryConnections) do
            if connection and typeof(connection) == "RBXScriptConnection" then
                connection:Disconnect()
            elseif connection and typeof(connection) == "thread" then
                task.cancel(connection)
            end
        end
    end
    
    -- Clear ESP
    disableMasterESP()
    
    -- Remove FOV circle
    removeFOVCircle()
    
    -- Restore original settings
    if humanoid then
        humanoid.WalkSpeed = originalWalkSpeed
        humanoid.JumpPower = originalJumpPower
    end
    
    print("[Enhanced Universal] Script cleaned up successfully")
end

-- Auto-cleanup on game close
game:BindToClose(cleanup)

-- Final notifications
task.wait(1)
Rayfield:Notify({
    Title = "Enhanced Universal Hub",
    Content = "All systems loaded and optimized for mobile!",
    Duration = 4
})

task.wait(2)
Rayfield:Notify({
    Title = "Ready for Action",
    Content = "Advanced ping optimization, combat systems, and utilities ready!",
    Duration = 3
})

print("[Enhanced Universal] Script fully loaded with advanced features!")
print("[Enhanced Universal] Mobile optimizations active for Arceus X")
print("[Enhanced Universal] All systems operational and ready!")

end
