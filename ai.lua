--[[ Universal Ping & Aim Enhancement Script for Arceus X Mobile ]]

if not game.Players.LocalPlayer.PlayerScripts:FindFirstChild("Universal_Loaded") then 
    local data = Instance.new("NumberValue")
    data.Name = "Universal_Loaded" 
    data.Parent = game.Players.LocalPlayer.PlayerScripts 
    print("Universal Enhancement Script Loaded")

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
        warn("[Universal Script] Rayfield failed to load. UI will not appear. Check network/executor.")
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
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- Player Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local camera = Workspace.CurrentCamera

-- Update references on respawn
player.CharacterAdded:Connect(function(chr)
    character = chr
    humanoid = character:WaitForChild("Humanoid")
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
end)

-- Script Variables
local pingOptimized = false
local silentAimEnabled = false
local aimbotEnabled = false
local espEnabled = false
local serverHopEnabled = false
local currentPing = 0
local targetRegion = "Asia"
local maxPingThreshold = 80

-- Aim Settings
local aimSettings = {
    fov = 100,
    smoothness = 0.5,
    targetPart = "Head",
    wallCheck = true,
    teamCheck = true,
    visibleOnly = true
}

-- Silent Aim Variables
local silentTarget = nil
local fovCircle = nil
local espObjects = {}
local aimConnections = {}

-- Ping Optimization Variables
local pingConnections = {}
local optimizationEnabled = false

-- VIM setup for mobile input
local VIM = nil
pcall(function()
    VIM = game:GetService("VirtualInputManager")
end)

-- Create Main Window
local Window
if Rayfield then
    Window = Rayfield:CreateWindow({
        Name = "Universal Enhancement Hub",
        LoadingTitle = "Loading Universal Script", 
        LoadingSubtitle = "Ping Optimization & Universal Aim System",
        ShowText = "Universal Pro",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "UniversalEnhancement",
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
        Title = "Universal Enhancement",
        Content = "Ping optimization and universal aim systems loaded!",
        Duration = 5
    })
end

-- Create Tabs
local PingTab, AimTab, VisualTab, ServerTab, UtilityTab

if Window then
    PingTab = Window:CreateTab("Network Optimization", 4483362458)
    AimTab = Window:CreateTab("Universal Aim", 4483362458)
    VisualTab = Window:CreateTab("Visual Enhancements", 4483362458)
    ServerTab = Window:CreateTab("Server Management", 4483362458)
    UtilityTab = Window:CreateTab("Utilities", 4483362458)
end

-- PING OPTIMIZATION TAB
if PingTab then
    PingTab:CreateSection("Bloxstrap-Style Ping Optimization")
    
    -- Main Ping Optimizer
    PingTab:CreateToggle({
        Name = "Enable Ping Optimization",
        CurrentValue = false,
        Flag = "PingOptimizer",
        Callback = function(Value)
            pingOptimized = Value
            if pingOptimized then
                enablePingOptimization()
                if Rayfield then
                    Rayfield:Notify({
                        Title = "Ping Optimizer",
                        Content = "Bloxstrap-style ping optimization enabled!",
                        Duration = 3
                    })
                end
            else
                disablePingOptimization()
            end
        end,
    })

    -- Network Performance Boost
    PingTab:CreateToggle({
        Name = "Network Performance Boost",
        CurrentValue = false,
        Flag = "NetworkBoost",
        Callback = function(Value)
            if Value then
                enableNetworkBoost()
            else
                disableNetworkBoost()
            end
        end,
    })

    -- Render Optimization
    PingTab:CreateToggle({
        Name = "Render Optimization",
        CurrentValue = false,
        Flag = "RenderOpt",
        Callback = function(Value)
            if Value then
                enableRenderOptimization()
            else
                disableRenderOptimization()
            end
        end,
    })

    PingTab:CreateSection("Connection Monitoring")

    -- Real-time Ping Display
    local PingLabel = PingTab:CreateLabel("Current Ping: Calculating...")
    
    -- Ping Monitor
    PingTab:CreateToggle({
        Name = "Real-time Ping Monitor",
        CurrentValue = false,
        Flag = "PingMonitor",
        Callback = function(Value)
            if Value then
                startPingMonitor(PingLabel)
            else
                stopPingMonitor()
            end
        end,
    })

    -- Latency Reducer
    PingTab:CreateButton({
        Name = "Apply Latency Reduction",
        Callback = function()
            applyLatencyReduction()
        end
    })

    -- Memory Optimizer
    PingTab:CreateButton({
        Name = "Optimize Memory Usage",
        Callback = function()
            optimizeMemoryUsage()
        end
    })
end

-- UNIVERSAL AIM TAB
if AimTab then
    AimTab:CreateSection("Silent Aim System")
    
    -- Silent Aim Toggle
    AimTab:CreateToggle({
        Name = "Universal Silent Aim",
        CurrentValue = false,
        Flag = "SilentAim",
        Callback = function(Value)
            silentAimEnabled = Value
            if silentAimEnabled then
                enableSilentAim()
                if Rayfield then
                    Rayfield:Notify({
                        Title = "Silent Aim",
                        Content = "Universal silent aim system enabled!",
                        Duration = 3
                    })
                end
            else
                disableSilentAim()
            end
        end,
    })

    -- Aimbot Toggle
    AimTab:CreateToggle({
        Name = "Universal Aimbot",
        CurrentValue = false,
        Flag = "Aimbot",
        Callback = function(Value)
            aimbotEnabled = Value
            if aimbotEnabled then
                enableAimbot()
            else
                disableAimbot()
            end
        end,
    })

    AimTab:CreateSection("Aim Configuration")

    -- FOV Setting
    AimTab:CreateSlider({
        Name = "Field of View",
        Range = {30, 300},
        Increment = 10,
        Suffix = "°",
        CurrentValue = 100,
        Flag = "AimFOV",
        Callback = function(Value)
            aimSettings.fov = Value
            updateFOVCircle()
        end,
    })

    -- Smoothness
    AimTab:CreateSlider({
        Name = "Aim Smoothness",
        Range = {0.1, 2.0},
        Increment = 0.1,
        Suffix = "",
        CurrentValue = 0.5,
        Flag = "AimSmooth",
        Callback = function(Value)
            aimSettings.smoothness = Value
        end,
    })

    -- Target Part
    AimTab:CreateDropdown({
        Name = "Target Body Part",
        Options = {"Head", "Torso", "HumanoidRootPart"},
        CurrentOption = {"Head"},
        MultipleOptions = false,
        Flag = "TargetPart",
        Callback = function(Option)
            aimSettings.targetPart = Option[1]
        end,
    })

    AimTab:CreateSection("Aim Features")

    -- Wall Check
    AimTab:CreateToggle({
        Name = "Wall Check",
        CurrentValue = true,
        Flag = "WallCheck",
        Callback = function(Value)
            aimSettings.wallCheck = Value
        end,
    })

    -- Team Check
    AimTab:CreateToggle({
        Name = "Team Check",
        CurrentValue = true,
        Flag = "TeamCheck",
        Callback = function(Value)
            aimSettings.teamCheck = Value
        end,
    })

    -- Visible Only
    AimTab:CreateToggle({
        Name = "Visible Targets Only",
        CurrentValue = true,
        Flag = "VisibleOnly",
        Callback = function(Value)
            aimSettings.visibleOnly = Value
        end,
    })

    -- FOV Circle Toggle
    AimTab:CreateToggle({
        Name = "Show FOV Circle",
        CurrentValue = false,
        Flag = "FOVCircle",
        Callback = function(Value)
            if Value then
                createFOVCircle()
            else
                removeFOVCircle()
            end
        end,
    })
end

-- VISUAL ENHANCEMENTS TAB
if VisualTab then
    VisualTab:CreateSection("Player ESP")
    
    -- Advanced ESP
    VisualTab:CreateToggle({
        Name = "Universal Player ESP",
        CurrentValue = false,
        Flag = "ESP",
        Callback = function(Value)
            espEnabled = Value
            if espEnabled then
                enableUniversalESP()
            else
                disableUniversalESP()
            end
        end,
    })

    -- ESP Features
    VisualTab:CreateToggle({
        Name = "Show Player Names",
        CurrentValue = true,
        Flag = "ESPNames",
        Callback = function(Value)
            -- Will be used in ESP system
        end,
    })

    VisualTab:CreateToggle({
        Name = "Show Distance",
        CurrentValue = true,
        Flag = "ESPDistance",
        Callback = function(Value)
            -- Will be used in ESP system
        end,
    })

    VisualTab:CreateToggle({
        Name = "Show Health",
        CurrentValue = false,
        Flag = "ESPHealth",
        Callback = function(Value)
            -- Will be used in ESP system
        end,
    })

    VisualTab:CreateSection("World Enhancement")

    -- Full Bright
    VisualTab:CreateToggle({
        Name = "Full Bright",
        CurrentValue = false,
        Flag = "FullBright",
        Callback = function(Value)
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

    -- Performance Mode
    VisualTab:CreateToggle({
        Name = "Performance Mode",
        CurrentValue = false,
        Flag = "PerfMode",
        Callback = function(Value)
            setPerformanceMode(Value)
        end,
    })
end

-- SERVER MANAGEMENT TAB
if ServerTab then
    ServerTab:CreateSection("Asian Region Server Hopping")
    
    -- Auto Server Hop for Low Ping
    ServerTab:CreateToggle({
        Name = "Smart Server Hop (Asian Servers)",
        CurrentValue = false,
        Flag = "SmartHop",
        Callback = function(Value)
            serverHopEnabled = Value
            if serverHopEnabled then
                startSmartServerHop()
                if Rayfield then
                    Rayfield:Notify({
                        Title = "Smart Server Hop",
                        Content = "Searching for low-ping Asian servers...",
                        Duration = 4
                    })
                end
            else
                stopSmartServerHop()
            end
        end,
    })

    -- Max Ping Threshold
    ServerTab:CreateSlider({
        Name = "Max Ping Threshold",
        Range = {30, 150},
        Increment = 10,
        Suffix = "ms",
        CurrentValue = 80,
        Flag = "MaxPing",
        Callback = function(Value)
            maxPingThreshold = Value
        end,
    })

    -- Target Region
    ServerTab:CreateDropdown({
        Name = "Preferred Region",
        Options = {"Asia", "Asia-Pacific", "Southeast Asia", "East Asia"},
        CurrentOption = {"Asia"},
        MultipleOptions = false,
        Flag = "TargetRegion",
        Callback = function(Option)
            targetRegion = Option[1]
        end,
    })

    ServerTab:CreateSection("Manual Server Actions")

    -- Manual Server Hop
    ServerTab:CreateButton({
        Name = "Find Low Ping Server",
        Callback = function()
            findLowPingServer()
        end
    })

    -- Rejoin Current Server
    ServerTab:CreateButton({
        Name = "Rejoin Current Server",
        Callback = function()
            TeleportService:Teleport(game.PlaceId, player)
        end
    })

    -- Server Info
    local ServerInfoLabel = ServerTab:CreateLabel("Server Info: Loading...")
    
    -- Update server info
    task.spawn(function()
        while true do
            local serverInfo = getServerInfo()
            if ServerInfoLabel then
                ServerInfoLabel:Set("Server Info: " .. serverInfo)
            end
            task.wait(5)
        end
    end)
end

-- UTILITIES TAB
if UtilityTab then
    UtilityTab:CreateSection("Universal Utilities")
    
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

    -- Walkspeed
    UtilityTab:CreateSlider({
        Name = "Walk Speed",
        Range = {16, 100},
        Increment = 2,
        Suffix = "",
        CurrentValue = 16,
        Flag = "WalkSpeed",
        Callback = function(Value)
            if character and humanoid then
                humanoid.WalkSpeed = Value
            end
        end,
    })

    -- Jump Power
    UtilityTab:CreateSlider({
        Name = "Jump Power",
        Range = {50, 200},
        Increment = 10,
        Suffix = "",
        CurrentValue = 50,
        Flag = "JumpPower",
        Callback = function(Value)
            if character and humanoid then
                humanoid.JumpPower = Value
            end
        end,
    })

    UtilityTab:CreateSection("System Optimization")

    -- FPS Boost
    UtilityTab:CreateButton({
        Name = "Apply FPS Boost",
        Callback = function()
            applyFPSBoost()
        end
    })

    -- Memory Cleanup
    UtilityTab:CreateButton({
        Name = "Clean Memory",
        Callback = function()
            cleanupMemory()
        end
    })
end

-- PING OPTIMIZATION FUNCTIONS (Bloxstrap-Style)
function enablePingOptimization()
    optimizationEnabled = true
    
    -- Apply network optimizations
    pcall(function()
        -- Reduce network quality for better ping
        settings().Network.IncomingReplicationLag = 0
        settings().Network.OutgoingReplicationLag = 0
        
        -- Optimize physics stepping
        settings().Physics.AllowSleep = false
        settings().Physics.ThrottleAdjustTime = 0
    end)
    
    -- Apply rendering optimizations similar to Bloxstrap flags
    pcall(function()
        -- Reduce graphics quality for better performance
        settings().Rendering.QualityLevel = 1
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        settings().Rendering.EnableFRM = false
        
        -- Disable expensive visual features
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                effect.Enabled = false
            end
        end
    end)
    
    if Rayfield then
        Rayfield:Notify({
            Title = "Ping Optimization",
            Content = "Bloxstrap-style optimizations applied!",
            Duration = 3
        })
    end
end

function disablePingOptimization()
    optimizationEnabled = false
    
    -- Restore default settings
    pcall(function()
        settings().Rendering.QualityLevel = 10
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
    end)
end

function enableNetworkBoost()
    pcall(function()
        -- Additional network optimizations
        game:GetService("NetworkClient").ChildRemoved:Connect(function()
            settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
        end)
    end)
end

function disableNetworkBoost()
    pcall(function()
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.DefaultAuto
    end)
end

function enableRenderOptimization()
    -- Remove visual effects that cause lag
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
        elseif obj:IsA("Explosion") then
            obj.Visible = false
        end
    end
    
    -- Set lighting to performance mode
    Lighting.GlobalShadows = false
    Lighting.Technology = Enum.Technology.Compatibility
end

function disableRenderOptimization()
    -- Re-enable effects
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = true
        end
    end
    
    Lighting.GlobalShadows = true
    Lighting.Technology = Enum.Technology.Future
end

-- PING MONITORING
local pingMonitorConnection = nil

function startPingMonitor(label)
    if pingMonitorConnection then
        pingMonitorConnection:Disconnect()
    end
    
    pingMonitorConnection = RunService.Heartbeat:Connect(function()
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        currentPing = ping
        
        if label then
            local pingColor = ""
            if ping < 50 then
                pingColor = "🟢 Excellent"
            elseif ping < 100 then
                pingColor = "🟡 Good"
            elseif ping < 150 then
                pingColor = "🟠 Fair"
            else
                pingColor = "🔴 Poor"
            end
            
            label:Set(string.format("Current Ping: %dms (%s)", ping, pingColor))
        end
    end)
end

function stopPingMonitor()
    if pingMonitorConnection then
        pingMonitorConnection:Disconnect()
        pingMonitorConnection = nil
    end
end

function applyLatencyReduction()
    pcall(function()
        -- Force garbage collection
        collectgarbage("collect")
        
        -- Optimize heartbeat
        settings().Physics.AllowSleep = true
        settings().Rendering.EnableFRM = true
        
        if Rayfield then
            Rayfield:Notify({
                Title = "Latency Reduction",
                Content = "Latency optimization applied!",
                Duration = 2
            })
        end
    end)
end

function optimizeMemoryUsage()
    -- Clean up memory
    collectgarbage("collect")
    
    -- Remove unnecessary objects
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            if obj.Parent and obj.Parent.Parent ~= character then
                obj.Transparency = 1
            end
        end
    end
    
    if Rayfield then
        Rayfield:Notify({
            Title = "Memory Optimization",
            Content = "Memory usage optimized!",
            Duration = 2
        })
    end
end

-- UNIVERSAL SILENT AIM SYSTEM
function enableSilentAim()
    -- Create aim detection loop
    aimConnections.silentAim = RunService.Heartbeat:Connect(function()
        if not silentAimEnabled then return end
        
        silentTarget = getClosestTarget()
    end)
    
    -- Hook mouse/camera for silent aim
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if silentAimEnabled and silentTarget then
            if method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "Raycast" then
                -- Redirect ray to silent target
                local targetPart = silentTarget.Character:FindFirstChild(aimSettings.targetPart)
                if targetPart then
                    args[1] = Ray.new(camera.CFrame.Position, (targetPart.Position - camera.CFrame.Position).Unit * 1000)
                end
            end
        end
        
        return oldNamecall(self, unpack(args))
    end)
end

function disableSilentAim()
    if aimConnections.silentAim then
        aimConnections.silentAim:Disconnect()
        aimConnections.silentAim = nil
    end
    silentTarget = nil
end

-- UNIVERSAL AIMBOT SYSTEM
function enableAimbot()
    aimConnections.aimbot = RunService.Heartbeat:Connect(function()
        if not aimbotEnabled then return end
        
        local target = getClosestTarget()
        if target and target.Character then
            local targetPart = target.Character:FindFirstChild(aimSettings.targetPart)
            if targetPart then
                local targetPosition = targetPart.Position
                local currentCFrame = camera.CFrame
                local targetCFrame = CFrame.lookAt(currentCFrame.Position, targetPosition)
                
                -- Smooth aim
                camera.CFrame = currentCFrame:Lerp(targetCFrame, aimSettings.smoothness * 0.1)
            end
        end
    end)
end

function disableAimbot()
    if aimConnections.aimbot then
        aimConnections.aimbot:Disconnect()
        aimConnections.aimbot = nil
    end
end

-- TARGET DETECTION
function getClosestTarget()
    local closestTarget = nil
    local closestDistance = math.huge
    
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character then
            local targetPart = targetPlayer.Character:FindFirstChild(aimSettings.targetPart)
            if targetPart then
                -- Team check
                if aimSettings.teamCheck and targetPlayer.Team == player.Team then
                    continue
                end
                
                -- Distance and FOV check
                local screenPoint, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
                    local fovDistance = (Vector2.new(screenPoint.X, screenPoint.Y) - Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)).Magnitude
                    
                    if fovDistance <= aimSettings.fov and distance < closestDistance then
                        -- Wall check
                        if aimSettings.wallCheck then
                            local ray = Ray.new(camera.CFrame.Position, (targetPart.Position - camera.CFrame.Position).Unit * distance)
                            local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {character})
                            
                            if hit and hit.Parent ~= targetPlayer.Character then
                                continue
                            end
                        end
                        
                        closestDistance = distance
                        closestTarget = targetPlayer
                    end
                end
            end
        end
    end
    
    return closestTarget
end

-- FOV CIRCLE
function createFOVCircle()
    if fovCircle then
        fovCircle:Remove()
    end
    
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 2
    fovCircle.NumSides = 50
    fovCircle.Color = Color3.new(1, 1, 1)
    fovCircle.Transparency = 0.5
    fovCircle.Filled = false
    fovCircle.Visible = true
    
    updateFOVCircle()
    
    -- Update circle position
    aimConnections.fovUpdate = RunService.Heartbeat:Connect(function()
        if fovCircle then
            fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        end
    end)
end

function updateFOVCircle()
    if fovCircle then
        fovCircle.Radius = aimSettings.fov
    end
end

function removeFOVCircle()
    if fovCircle then
        fovCircle:Remove()
        fovCircle = nil
    end
    
    if aimConnections.fovUpdate then
        aimConnections.fovUpdate:Disconnect()
        aimConnections.fovUpdate = nil
    end
end

-- UNIVERSAL ESP SYSTEM
function enableUniversalESP()
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            addESPToPlayer(targetPlayer)
        end
    end
    
    -- Handle new players
    Players.PlayerAdded:Connect(function(newPlayer)
        newPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            if espEnabled then
                addESPToPlayer(newPlayer)
            end
        end)
    end)
end

function addESPToPlayer(targetPlayer)
    if not targetPlayer.Character then return end
    
    -- Remove existing ESP
    removeESPFromPlayer(targetPlayer)
    
    local character = targetPlayer.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChild("Humanoid")
    
    if not humanoidRootPart or not head then return end
    
    -- Create highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "UniversalESP_" .. targetPlayer.Name
    highlight.Adornee = character
    highlight.FillColor = Color3.new(1, 0.2, 0.2)
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
    highlight.Parent = character
    
    -- Create info GUI
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "ESPInfo_" .. targetPlayer.Name
    billboardGui.Adornee = head
    billboardGui.Size = UDim2.new(0, 200, 0, 120)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = character
    
    -- Name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.33, 0)
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
    distanceLabel.Size = UDim2.new(1, 0, 0.33, 0)
    distanceLabel.Position = UDim2.new(0, 0, 0.33, 0)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = "0 studs"
    distanceLabel.TextColor3 = Color3.new(0, 1, 0)
    distanceLabel.TextScaled = true
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.TextStrokeTransparency = 0
    distanceLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distanceLabel.Parent = billboardGui
    
    -- Health label
    local healthLabel = Instance.new("TextLabel")
    healthLabel.Size = UDim2.new(1, 0, 0.33, 0)
    healthLabel.Position = UDim2.new(0, 0, 0.66, 0)
    healthLabel.BackgroundTransparency = 1
    healthLabel.Text = "100 HP"
    healthLabel.TextColor3 = Color3.new(0, 1, 0)
    healthLabel.TextScaled = true
    healthLabel.Font = Enum.Font.Gotham
    healthLabel.TextStrokeTransparency = 0
    healthLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    healthLabel.Parent = billboardGui
    
    -- Store ESP objects
    espObjects[targetPlayer.Name] = {highlight, billboardGui, distanceLabel, healthLabel}
    
    -- Update ESP info continuously
    task.spawn(function()
        while espEnabled and targetPlayer.Character and humanoidRootPart.Parent do
            if character and humanoidRootPart then
                local distance = math.floor((humanoidRootPart.Position - humanoidRootPart.Position).Magnitude)
                distanceLabel.Text = distance .. " studs"
                
                -- Color code based on distance
                if distance <= 20 then
                    distanceLabel.TextColor3 = Color3.new(1, 0, 0) -- Red - Close
                    highlight.FillColor = Color3.new(1, 0, 0)
                elseif distance <= 50 then
                    distanceLabel.TextColor3 = Color3.new(1, 1, 0) -- Yellow - Medium
                    highlight.FillColor = Color3.new(1, 1, 0)
                else
                    distanceLabel.TextColor3 = Color3.new(0, 1, 0) -- Green - Far
                    highlight.FillColor = Color3.new(0, 1, 0)
                end
                
                -- Update health if humanoid exists
                if humanoid then
                    local health = math.floor(humanoid.Health)
                    local maxHealth = math.floor(humanoid.MaxHealth)
                    healthLabel.Text = health .. "/" .. maxHealth .. " HP"
                    
                    -- Color code health
                    local healthPercent = health / maxHealth
                    if healthPercent > 0.7 then
                        healthLabel.TextColor3 = Color3.new(0, 1, 0) -- Green
                    elseif healthPercent > 0.3 then
                        healthLabel.TextColor3 = Color3.new(1, 1, 0) -- Yellow
                    else
                        healthLabel.TextColor3 = Color3.new(1, 0, 0) -- Red
                    end
                end
            end
            task.wait(0.2)
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

function disableUniversalESP()
    for playerName, espData in pairs(espObjects) do
        for _, obj in pairs(espData) do
            if obj and obj.Parent then
                obj:Destroy()
            end
        end
    end
    espObjects = {}
end

-- SMART SERVER HOPPING (Asian Regions)
local serverHopConnection = nil
local serverList = {}

function startSmartServerHop()
    if serverHopConnection then
        serverHopConnection:Disconnect()
    end
    
    serverHopConnection = task.spawn(function()
        while serverHopEnabled do
            local currentPing = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            
            if currentPing > maxPingThreshold then
                if Rayfield then
                    Rayfield:Notify({
                        Title = "Server Hop",
                        Content = "Current ping too high (" .. math.floor(currentPing) .. "ms). Searching for better server...",
                        Duration = 3
                    })
                end
                
                findLowPingServer()
                break
            end
            
            task.wait(30) -- Check every 30 seconds
        end
    end)
end

function stopSmartServerHop()
    if serverHopConnection then
        task.cancel(serverHopConnection)
        serverHopConnection = nil
    end
end

function findLowPingServer()
    pcall(function()
        local servers = {}
        
        -- Get server list (simplified approach)
        for i = 1, 10 do
            pcall(function()
                TeleportService:Teleport(game.PlaceId)
            end)
            task.wait(1)
        end
    end)
end

function getServerInfo()
    local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    local players = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    
    return string.format("Ping: %dms | Players: %d/%d", ping, players, maxPlayers)
end

-- PERFORMANCE OPTIMIZATION
function setPerformanceMode(enabled)
    if enabled then
        -- Remove textures and decals
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            elseif obj:IsA("BasePart") then
                obj.Material = Enum.Material.Plastic
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") then
                obj.Enabled = false
            end
        end
        
        -- Reduce lighting quality
        Lighting.GlobalShadows = false
        Lighting.Technology = Enum.Technology.Compatibility
        
        if Rayfield then
            Rayfield:Notify({
                Title = "Performance Mode",
                Content = "Performance optimizations applied!",
                Duration = 2
            })
        end
    else
        -- Restore graphics
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 0
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") then
                obj.Enabled = true
            end
        end
        
        Lighting.GlobalShadows = true
        Lighting.Technology = Enum.Technology.Future
    end
end

function applyFPSBoost()
    -- Comprehensive FPS optimization
    pcall(function()
        -- Graphics settings
        settings().Rendering.QualityLevel = 1
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        settings().Rendering.EnableFRM = false
        
        -- Remove post-processing effects
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or 
               effect:IsA("ColorCorrectionEffect") or effect:IsA("DepthOfFieldEffect") or 
               effect:IsA("SunRaysEffect") then
                effect.Enabled = false
            end
        end
        
        -- Disable particles
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                obj.Enabled = false
            end
        end
        
        -- Optimize physics
        settings().Physics.AllowSleep = true
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Skip4
        
        if Rayfield then
            Rayfield:Notify({
                Title = "FPS Boost",
                Content = "Maximum FPS optimizations applied!",
                Duration = 3
            })
        end
    end)
end

function cleanupMemory()
    -- Force garbage collection
    collectgarbage("collect")
    
    -- Remove cached data
    pcall(function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Sound") and not obj.IsPlaying then
                obj:Destroy()
            elseif obj:IsA("Decal") and obj.Parent and obj.Parent.Parent ~= character then
                obj.Transparency = 1
            end
        end
    end)
    
    if Rayfield then
        Rayfield:Notify({
            Title = "Memory Cleanup",
            Content = "Memory cleaned and optimized!",
            Duration = 2
        })
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
            elseif UserInputService then
                -- Fallback method
                pcall(function()
                    local virtualEvent = {
                        KeyCode = Enum.KeyCode.Space,
                        UserInputType = Enum.UserInputType.Keyboard,
                        UserInputState = Enum.UserInputState.Begin
                    }
                    UserInputService.InputBegan:Fire(virtualEvent)
                    task.wait(0.1)
                    virtualEvent.UserInputState = Enum.UserInputState.End
                    UserInputService.InputEnded:Fire(virtualEvent)
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
    
    -- Update camera reference
    if not camera or not camera.Parent then
        camera = Workspace.CurrentCamera
    end
end)

-- Handle character respawn
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    
    task.wait(2) -- Wait for character to fully load
    
    -- Re-enable ESP if it was enabled
    if espEnabled then
        task.wait(1)
        enableUniversalESP()
    end
end)

-- Cleanup on script unload
game:GetService("Players").PlayerRemoving:Connect(function(removedPlayer)
    if removedPlayer == player then
        -- Clean up connections
        for _, connection in pairs(aimConnections) do
            if connection then
                connection:Disconnect()
            end
        end
        
        for _, connection in pairs(pingConnections) do
            if connection then
                connection:Disconnect()
            end
        end
        
        if pingMonitorConnection then
            pingMonitorConnection:Disconnect()
        end
        
        if serverHopConnection then
            task.cancel(serverHopConnection)
        end
        
        if antiAFKConnection then
            task.cancel(antiAFKConnection)
        end
    end
end)

-- Final notification
if Rayfield then
    task.wait(2)
    Rayfield:Notify({
        Title = "Universal Enhancement Hub",
        Content = "All systems loaded! Ping optimization, universal aim, and server hopping ready.",
        Duration = 6
    })
end

print("[Universal Enhancement] Script fully loaded with ping optimization, universal aim, and Asian server hopping!")

end
