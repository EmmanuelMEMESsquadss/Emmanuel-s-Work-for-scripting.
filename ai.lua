-- Dual Lock-On System for Roblox Battlegrounds Games
-- Features: CamLock, AimLock/PSLock, Asian Server Targeting, Rayfield UI

-- Check if already loaded
if game.Players.LocalPlayer.PlayerScripts:FindFirstChild("DualLockOn_Loaded") then 
    return
end

local loadedMarker = Instance.new("BoolValue")
loadedMarker.Name = "DualLockOn_Loaded"
loadedMarker.Parent = game.Players.LocalPlayer.PlayerScripts

print("[Dual Lock-On] Starting load...")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Stats = game:GetService("Stats")
local Camera = workspace.CurrentCamera

-- Player Variables
local player = Players.LocalPlayer
local character, humanoid, hrp

-- Mobile Detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Lock-On System Variables
local lockTarget = nil
local lockBillboard = nil
local lockConnections = {}

-- Lock Types
local LOCK_TYPES = {
    NONE = 0,
    CAMLOCK = 1,
    AIMLOCK = 2
}

local currentLockType = LOCK_TYPES.NONE

-- Camera System Variables
local originalCameraType = Camera.CameraType
local originalCameraSubject = Camera.CameraSubject

-- Configuration
local Config = {
    -- Lock Settings
    MaxLockDistance = 75,
    LockSmoothness = 0.2,
    PredictionStrength = 0.15,
    TargetSwitchCooldown = 0.3,
    
    -- CamLock Settings
    CamLockSmoothness = 0.15,
    CamLockOffset = Vector3.new(0, 2, 0),
    
    -- AimLock Settings  
    AimLockSmoothness = 0.25,
    AimLockPrediction = 0.2,
    AimLockFOV = 200,
    
    -- Visual Settings
    ShowTargetIndicator = true,
    IndicatorColor = Color3.new(1, 0.3, 0.3),
    
    -- Performance
    UpdateRate = 60 -- Hz
}

-- State Variables
local lastTargetSwitchTime = 0
local targetValidationEnabled = true

-- Setup character function
local function setupCharacter(char)
    character = char
    if not character then return end
    
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
    
    print("[Dual Lock-On] Character setup complete")
end

-- Initialize character
if player.Character then 
    setupCharacter(player.Character) 
end
player.CharacterAdded:Connect(setupCharacter)

-- Load Rayfield UI
local Rayfield = nil
local Window = nil

local function loadRayfield()
    local success = false
    local attempts = 0
    local maxAttempts = 3
    
    while not success and attempts < maxAttempts do
        attempts = attempts + 1
        print("[Dual Lock-On] Rayfield load attempt " .. attempts)
        
        success = pcall(function()
            if attempts == 1 then
                Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
            elseif attempts == 2 then
                Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source"))()
            else
                -- Fallback
                Rayfield = loadstring(game:HttpGet("https://raw.githack.com/sirius/menu/main/rayfield"))()
            end
        end)
        
        if not success then
            task.wait(1)
        end
    end
    
    return success
end

-- Asian Server Detection and Hopping System
local ServerHopper = {}

function ServerHopper:getCurrentPing()
    local networkStats = Stats.Network.ServerStatsItem
    if networkStats and networkStats["Data Ping"] then
        return networkStats["Data Ping"]:GetValue()
    end
    return 999
end

function ServerHopper:isAsianTimeZone()
    local currentHour = tonumber(os.date("%H"))
    local utcHour = tonumber(os.date("!%H"))
    local timezoneOffset = currentHour - utcHour
    
    -- Normalize timezone offset
    if timezoneOffset > 12 then
        timezoneOffset = timezoneOffset - 24
    elseif timezoneOffset < -12 then
        timezoneOffset = timezoneOffset + 24
    end
    
    -- Asian timezones: UTC+4 to UTC+12
    return timezoneOffset >= 4 and timezoneOffset <= 12
end

function ServerHopper:detectServerRegion()
    local ping = self:getCurrentPing()
    local isAsianTZ = self:isAsianTimeZone()
    
    -- Try to get IP geolocation
    local success, result = pcall(function()
        return HttpService:GetAsync("https://ipapi.co/json/", true)
    end)
    
    if success then
        local data = HttpService:JSONDecode(result)
        local country = data.country_code
        
        -- Asian countries
        local asianCountries = {
            "SG", "JP", "KR", "HK", "TW", "TH", "MY", "ID", 
            "PH", "VN", "IN", "CN", "AU", "NZ"
        }
        
        for _, code in ipairs(asianCountries) do
            if country == code then
                return "Asian", ping
            end
        end
    end
    
    -- Fallback detection based on ping and timezone
    if isAsianTZ and ping < 150 then
        return "Likely Asian", ping
    elseif ping < 80 then
        return "Low Latency", ping
    else
        return "Unknown", ping
    end
end

function ServerHopper:isOptimalAsianServer()
    local region, ping = self:detectServerRegion()
    return (region == "Asian" or region == "Likely Asian") and ping < 120
end

function ServerHopper:hopToAsianServer()
    local currentRegion, currentPing = self:detectServerRegion()
    
    print(string.format("[Server Hop] Current: %s (Ping: %dms)", currentRegion, currentPing))
    
    if self:isOptimalAsianServer() then
        print("[Server Hop] Already on optimal Asian server")
        if Window and Rayfield then
            Rayfield:Notify({
                Title = "Server Status",
                Content = "Already on optimal Asian server!",
                Duration = 3
            })
        end
        return
    end
    
    print("[Server Hop] Searching for Asian servers...")
    
    if Window and Rayfield then
        Rayfield:Notify({
            Title = "Server Hopping",
            Content = "Searching for Asian servers...",
            Duration = 3
        })
    end
    
    -- Multi-hop strategy for better Asian server discovery
    local hopAttempts = 0
    local maxHops = 15
    
    local function performHop()
        hopAttempts = hopAttempts + 1
        
        if hopAttempts > maxHops then
            print("[Server Hop] Max attempts reached")
            return
        end
        
        local success, err = pcall(function()
            -- Rapid successive teleports increase chance of Asian server
            for i = 1, 2 do
                TeleportService:Teleport(game.PlaceId, player)
                if i == 1 then task.wait(0.1) end
            end
        end)
        
        if not success then
            print("[Server Hop] Hop failed: " .. tostring(err))
            task.wait(2)
            performHop()
        end
    end
    
    performHop()
end

function ServerHopper:regularServerHop()
    local success, err = pcall(function()
        TeleportService:Teleport(game.PlaceId, player)
    end)
    
    if not success then
        warn("[Server Hop] Regular hop failed: " .. tostring(err))
    end
end

function ServerHopper:rejoinServer()
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
    end)
    
    if not success then
        warn("[Server Hop] Rejoin failed: " .. tostring(err))
    end
end

-- Target Management System
local TargetManager = {}

function TargetManager:isValidTarget(model)
    if not model or not model:IsA("Model") then return false end
    local targetHumanoid = model:FindFirstChildWhichIsA("Humanoid")
    local targetHRP = model:FindFirstChild("HumanoidRootPart")
    
    if not targetHumanoid or not targetHRP or targetHumanoid.Health <= 0 then return false end
    if model == character then return false end
    
    local targetPlayer = Players:GetPlayerFromCharacter(model)
    if targetPlayer == player then return false end
    
    -- Distance check
    if hrp then
        local distance = (hrp.Position - targetHRP.Position).Magnitude
        if distance > Config.MaxLockDistance then return false end
    end
    
    return true
end

function TargetManager:getNearestTarget()
    if not hrp then return nil end
    
    local nearest, nearestDist = nil, Config.MaxLockDistance
    
    -- Check players first
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character and self:isValidTarget(targetPlayer.Character) then
            local distance = (hrp.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
            if distance < nearestDist then
                nearestDist = distance
                nearest = targetPlayer.Character
            end
        end
    end
    
    -- Check NPCs in workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and self:isValidTarget(obj) then
            local distance = (hrp.Position - obj.HumanoidRootPart.Position).Magnitude
            if distance < nearestDist then
                nearestDist = distance
                nearest = obj
            end
        end
    end
    
    return nearest, nearestDist
end

function TargetManager:getAllValidTargets()
    local targets = {}
    
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character and self:isValidTarget(targetPlayer.Character) then
            local distance = (hrp.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
            table.insert(targets, {
                character = targetPlayer.Character,
                player = targetPlayer,
                distance = distance
            })
        end
    end
    
    -- Sort by distance
    table.sort(targets, function(a, b)
        return a.distance < b.distance
    end)
    
    return targets
end

function TargetManager:switchToNextTarget()
    if tick() - lastTargetSwitchTime < Config.TargetSwitchCooldown then return end
    lastTargetSwitchTime = tick()
    
    local validTargets = self:getAllValidTargets()
    if #validTargets <= 1 then return end
    
    local currentIndex = 1
    if lockTarget then
        for i, target in ipairs(validTargets) do
            if target.character == lockTarget then
                currentIndex = i
                break
            end
        end
    end
    
    local nextIndex = (currentIndex % #validTargets) + 1
    local newTarget = validTargets[nextIndex]
    
    if newTarget then
        lockTarget = newTarget.character
        self:attachBillboard(newTarget.character)
        
        local targetName = newTarget.player and newTarget.player.Name or "NPC"
        print("[Lock-On] Switched to:", targetName)
        
        if Window and Rayfield then
            Rayfield:Notify({
                Title = "Target Switch",
                Content = "Locked onto: " .. targetName,
                Duration = 2
            })
        end
    end
end

function TargetManager:detachBillboard()
    if lockBillboard then
        lockBillboard:Destroy()
        lockBillboard = nil
    end
end

function TargetManager:attachBillboard(model)
    self:detachBillboard()
    
    if not Config.ShowTargetIndicator then return end
    
    local targetHRP = model:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 140, 0, 50)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Parent = targetHRP
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = Config.IndicatorColor
    mainFrame.BackgroundTransparency = 0.4
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = bb
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.IndicatorColor
    stroke.Thickness = 2
    stroke.Parent = mainFrame
    
    local lockTypeText = currentLockType == LOCK_TYPES.CAMLOCK and "CAM LOCK" or "AIM LOCK"
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = lockTypeText
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Parent = mainFrame
    
    lockBillboard = bb
    
    -- Animate billboard
    local tween = TweenService:Create(mainFrame, 
        TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {BackgroundTransparency = 0.7}
    )
    tween:Play()
end

-- Lock System Core
local LockSystem = {}

function LockSystem:getPredictedPosition(targetHRP)
    if not targetHRP then return hrp.Position end
    
    local velocity = targetHRP.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
    local prediction = currentLockType == LOCK_TYPES.CAMLOCK and Config.PredictionStrength or Config.AimLockPrediction
    
    return targetHRP.Position + (velocity * prediction)
end

function LockSystem:updateCamLock(dt)
    if not lockTarget or not hrp then return end
    
    local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
    if not targetHRP then 
        self:unlock("Target lost HRP")
        return 
    end
    
    local targetHumanoid = lockTarget:FindFirstChildWhichIsA("Humanoid")
    if not targetHumanoid or targetHumanoid.Health <= 0 then
        self:unlock("Target died")
        return
    end
    
    -- Character rotation
    if humanoid and not humanoid.PlatformStand then
        humanoid.AutoRotate = false
        
        local lookDirection = (targetHRP.Position - hrp.Position)
        lookDirection = Vector3.new(lookDirection.X, 0, lookDirection.Z).Unit
        
        if lookDirection.Magnitude > 0 then
            local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + lookDirection)
            hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, Config.CamLockSmoothness * 4)
        end
    end
    
    -- Camera control
    local targetPos = self:getPredictedPosition(targetHRP) + Config.CamLockOffset
    local currentCFrame = Camera.CFrame
    local targetCFrame = CFrame.lookAt(currentCFrame.Position, targetPos)
    
    Camera.CFrame = currentCFrame:Lerp(targetCFrame, Config.CamLockSmoothness)
end

function LockSystem:updateAimLock(dt)
    if not lockTarget or not hrp then return end
    
    local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
    if not targetHRP then 
        self:unlock("Target lost HRP")
        return 
    end
    
    local targetHumanoid = lockTarget:FindFirstChildWhichIsA("Humanoid")
    if not targetHumanoid or targetHumanoid.Health <= 0 then
        self:unlock("Target died")
        return
    end
    
    -- Only camera control, no character rotation
    local targetPos = self:getPredictedPosition(targetHRP)
    local currentCFrame = Camera.CFrame
    local targetCFrame = CFrame.lookAt(currentCFrame.Position, targetPos)
    
    Camera.CFrame = currentCFrame:Lerp(targetCFrame, Config.AimLockSmoothness)
end

function LockSystem:startLock(lockType)
    if currentLockType ~= LOCK_TYPES.NONE then
        self:unlock("Switching lock type")
    end
    
    local target, distance = TargetManager:getNearestTarget()
    if not target then
        print("[Lock-On] No valid targets found")
        return false
    end
    
    lockTarget = target
    currentLockType = lockType
    
    -- Store original camera settings
    originalCameraType = Camera.CameraType
    originalCameraSubject = Camera.CameraSubject
    
    -- Set camera to scriptable
    Camera.CameraType = Enum.CameraType.Scriptable
    
    -- Attach visual indicator
    TargetManager:attachBillboard(target)
    
    -- Start appropriate update loop
    if lockType == LOCK_TYPES.CAMLOCK then
        lockConnections.update = RunService.RenderStepped:Connect(function(dt)
            self:updateCamLock(dt)
        end)
        print("[Lock-On] CamLock activated")
    elseif lockType == LOCK_TYPES.AIMLOCK then
        lockConnections.update = RunService.RenderStepped:Connect(function(dt)
            self:updateAimLock(dt)
        end)
        print("[Lock-On] AimLock activated")
    end
    
    -- Target validation
    if targetValidationEnabled then
        lockConnections.validation = RunService.Heartbeat:Connect(function()
            if lockTarget and not TargetManager:isValidTarget(lockTarget) then
                self:unlock("Target became invalid")
            end
        end)
    end
    
    local targetPlayer = Players:GetPlayerFromCharacter(target)
    local targetName = targetPlayer and targetPlayer.Name or "NPC"
    local lockTypeName = lockType == LOCK_TYPES.CAMLOCK and "CamLock" or "AimLock"
    
    if Window and Rayfield then
        Rayfield:Notify({
            Title = lockTypeName .. " Activated",
            Content = "Locked onto: " .. targetName,
            Duration = 3
        })
    end
    
    return true
end

function LockSystem:unlock(reason)
    currentLockType = LOCK_TYPES.NONE
    lockTarget = nil
    
    -- Disconnect all connections
    for _, connection in pairs(lockConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    lockConnections = {}
    
    -- Remove billboard
    TargetManager:detachBillboard()
    
    -- Restore camera
    Camera.CameraType = originalCameraType
    if originalCameraSubject then
        Camera.CameraSubject = originalCameraSubject
    end
    
    -- Restore character
    if humanoid then
        humanoid.AutoRotate = true
    end
    
    if reason then
        print("[Lock-On] Unlocked:", reason)
    end
    
    if Window and Rayfield then
        Rayfield:Notify({
            Title = "Lock Disabled",
            Content = reason or "Manual unlock",
            Duration = 2
        })
    end
end

function LockSystem:toggleCamLock()
    if currentLockType == LOCK_TYPES.CAMLOCK then
        self:unlock("Manual toggle")
    else
        self:startLock(LOCK_TYPES.CAMLOCK)
    end
end

function LockSystem:toggleAimLock()
    if currentLockType == LOCK_TYPES.AIMLOCK then
        self:unlock("Manual toggle")
    else
        self:startLock(LOCK_TYPES.AIMLOCK)
    end
end

-- Create Rayfield UI
if loadRayfield() and Rayfield then
    print("[Dual Lock-On] Rayfield loaded successfully")
    
    Window = Rayfield:CreateWindow({
        Name = "Dual Lock-On System",
        LoadingTitle = "Dual Lock-On Pro",
        LoadingSubtitle = "CamLock & AimLock System",
        ShowText = "Lock-On Pro v2.0",
        ConfigurationSaving = {
            Enabled = false
        },
        Discord = {
            Enabled = false
        },
        KeySystem = false
    })
    
    -- Lock Controls Tab
    local LockTab = Window:CreateTab("Lock Controls", 4483362458)
    
    LockTab:CreateSection("Lock Types")
    
    LockTab:CreateButton({
        Name = "Toggle CamLock",
        Callback = function()
            LockSystem:toggleCamLock()
        end
    })
    
    LockTab:CreateButton({
        Name = "Toggle AimLock",
        Callback = function()
            LockSystem:toggleAimLock()
        end
    })
    
    LockTab:CreateButton({
        Name = "Switch Target",
        Callback = function()
            if currentLockType ~= LOCK_TYPES.NONE then
                TargetManager:switchToNextTarget()
            else
                Rayfield:Notify({
                    Title = "Error",
                    Content = "No active lock to switch target!",
                    Duration = 2
                })
            end
        end
    })
    
    LockTab:CreateButton({
        Name = "Unlock All",
        Callback = function()
            LockSystem:unlock("Manual unlock")
        end
    })
    
    LockTab:CreateSection("Lock Settings")
    
    LockTab:CreateSlider({
        Name = "Max Lock Distance",
        Range = {30, 150},
        Increment = 5,
        Suffix = " studs",
        CurrentValue = Config.MaxLockDistance,
        Callback = function(Value)
            Config.MaxLockDistance = Value
        end,
    })
    
    LockTab:CreateSlider({
        Name = "CamLock Smoothness",
        Range = {0.05, 0.5},
        Increment = 0.05,
        CurrentValue = Config.CamLockSmoothness,
        Callback = function(Value)
            Config.CamLockSmoothness = Value
        end,
    })
    
    LockTab:CreateSlider({
        Name = "AimLock Smoothness",
        Range = {0.05, 0.5},
        Increment = 0.05,
        CurrentValue = Config.AimLockSmoothness,
        Callback = function(Value)
            Config.AimLockSmoothness = Value
        end,
    })
    
    LockTab:CreateSlider({
        Name = "Prediction Strength",
        Range = {0, 0.5},
        Increment = 0.05,
        CurrentValue = Config.PredictionStrength,
        Callback = function(Value)
            Config.PredictionStrength = Value
        end,
    })
    
    LockTab:CreateToggle({
        Name = "Show Target Indicator",
        CurrentValue = Config.ShowTargetIndicator,
        Callback = function(Value)
            Config.ShowTargetIndicator = Value
        end,
    })
    
    -- Server Management Tab
    local ServerTab = Window:CreateTab("Server Management", 4483362458)
    
    ServerTab:CreateSection("Asian Server Targeting")
    
    -- Current server info display
    local serverInfoLabel = ServerTab:CreateLabel("Checking server info...")
    
    -- Update server info
    task.spawn(function()
        while true do
            local region, ping = ServerHopper:detectServerRegion()
            local isOptimal = ServerHopper:isOptimalAsianServer()
            local status = isOptimal and "Optimal" or "Suboptimal"
            
            serverInfoLabel:Set(string.format("Region: %s | Ping: %dms | Status: %s", 
                region, math.floor(ping), status))
            
            task.wait(5)
        end
    end)
    
    ServerTab:CreateButton({
        Name = "Find Asian Server",
        Callback = function()
            ServerHopper:hopToAsianServer()
        end
    })
    
    ServerTab:CreateButton({
        Name = "Regular Server Hop",
        Callback = function()
            ServerHopper:regularServerHop()
        end
    })
    
    ServerTab:CreateButton({
        Name = "Rejoin Current Server",
        Callback = function()
            ServerHopper:rejoinServer()
        end
    })
    
    ServerTab:CreateSection("Performance")
    
    ServerTab:CreateToggle({
        Name = "Target Validation",
        CurrentValue = targetValidationEnabled,
        Callback = function(Value)
            targetValidationEnabled = Value
        end,
    })
    
    ServerTab:CreateSlider({
        Name = "Update Rate",
        Range = {30, 120},
        Increment = 10,
        Suffix = " Hz",
        CurrentValue = Config.UpdateRate,
        Callback = function(Value)
            Config.UpdateRate = Value
        end,
    })
    
    -- Status display
    local StatusTab = Window:CreateTab("Status", 4483362458)
    
    local statusLabel = StatusTab:CreateLabel("System Status: Ready")
    local targetLabel = StatusTab:CreateLabel("Target: None")
    local lockTypeLabel = StatusTab:CreateLabel("Lock Type: None")
    
    -- Update status
    task.spawn(function()
        while true do
            local lockTypeText = "None"
            if currentLockType == LOCK_TYPES.CAMLOCK then
                lockTypeText = "CamLock"
            elseif currentLockType == LOCK_TYPES.AIMLOCK then
                lockTypeText = "AimLock"
            end
            
            local targetText = "None"
            if lockTarget then
                local targetPlayer = Players:GetPlayerFromCharacter(lockTarget)
                targetText = targetPlayer and targetPlayer.Name or "NPC"
            end
            
            statusLabel:Set("System Status: " .. (currentLockType ~= LOCK_TYPES.NONE and "Active" or "Ready"))
            targetLabel:Set("Target: " .. targetText)
            lockTypeLabel:Set("Lock Type: " .. lockTypeText)
            
            task.wait(1)
        end
    end)
    
    print("[Dual Lock-On] UI loaded successfully")
else
    print("[Dual Lock-On] Rayfield failed to load")
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.T then
        LockSystem:toggleCamLock()
    elseif input.KeyCode == Enum.KeyCode.Y then
        LockSystem:toggleAimLock()
    elseif input.KeyCode == Enum.KeyCode.G then
        if currentLockType ~= LOCK_TYPES.NONE then
            TargetManager:switchToNextTarget()
        end
    elseif input.KeyCode == Enum.KeyCode.H then
        ServerHopper:hopToAsianServer()
    elseif input.KeyCode == Enum.KeyCode.J then
        ServerHopper:regularServerHop()
    end
end)

-- Handle respawn
player.CharacterAdded:Connect(function(newChar)
    task.wait(1)
    setupCharacter(newChar)
    
    if currentLockType ~= LOCK_TYPES.NONE then
        LockSystem:unlock("Character respawned")
    end
    
    task.wait(2)
    originalCameraSubject = Camera.CameraSubject
    originalCameraType = Camera.CameraType
end)

-- Final initialization
print("[Dual Lock-On] System fully loaded!")
print("Controls:")
print("T - Toggle CamLock")
print("Y - Toggle AimLock") 
print("G - Switch Target")
print("H - Find Asian Server")
print("J - Regular Server Hop")

-- Show load notification
if Window and Rayfield then
    Rayfield:Notify({
        Title = "Dual Lock-On System",
        Content = "System loaded! CamLock & AimLock ready.",
        Duration = 5
    })
end

-- Show current server info
task.wait(2)
local region, ping = ServerHopper:detectServerRegion()
print(string.format("Current Server - Region: %s, Ping: %dms", region, math.floor(ping)))
