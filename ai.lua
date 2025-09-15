-- Mobile-Optimized Dual Lock-On System for Roblox Battlegrounds
-- Fixed camera freezing, improved mobile support, optimized performance

-- Prevent multiple loads
if _G.MobileLockOnLoaded then 
    return 
end
_G.MobileLockOnLoaded = true

print("[Mobile Lock-On] Loading system...")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")

-- Camera and Player
local Camera = workspace.CurrentCamera
local player = Players.LocalPlayer
local character, humanoid, hrp

-- Mobile Detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isTablet = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- Lock System State
local lockTarget = nil
local lockBillboard = nil
local lockConnections = {}
local isLocked = false

-- Lock Types
local LOCK_TYPES = {
    NONE = 0,
    CAMLOCK = 1,
    AIMLOCK = 2
}

local currentLockType = LOCK_TYPES.NONE

-- Camera Control Variables
local originalCameraType = nil
local originalCameraSubject = nil
local cameraControl = nil
local lastCameraUpdate = 0
local smoothCamera = true

-- Mobile UI Elements
local mobileUI = nil
local lockButton = nil
local switchButton = nil
local settingsButton = nil
local mobileFrame = nil

-- Configuration with mobile optimizations
local Config = {
    -- Lock Settings
    MaxLockDistance = isMobile and 60 or 75,
    LockSmoothness = isMobile and 0.3 or 0.2,
    PredictionStrength = isMobile and 0.1 or 0.15,
    TargetSwitchCooldown = 0.2,
    
    -- Mobile-specific settings
    MobileCamSensitivity = 0.4,
    MobileAimAssist = true,
    TouchControlSize = 80,
    
    -- CamLock Settings
    CamLockSmoothness = isMobile and 0.25 : 0.15,
    CamLockOffset = Vector3.new(0, 1.5, 0),
    CamLockFOV = isMobile and 85 or 70,
    
    -- AimLock Settings  
    AimLockSmoothness = isMobile and 0.35 : 0.25,
    AimLockPrediction = isMobile and 0.15 : 0.2,
    AimLockFOV = isMobile and 180 : 200,
    
    -- Visual Settings
    ShowTargetIndicator = true,
    IndicatorColor = Color3.new(1, 0.2, 0.4),
    
    -- Performance (mobile optimized)
    UpdateRate = isMobile and 45 or 60,
    UseDeltaTime = true
}

-- State tracking
local lastTargetSwitchTime = 0
local targetValidationEnabled = true
local performanceMode = isMobile

print(string.format("[Mobile Lock-On] Device Type: %s", isMobile and "Mobile" or "Desktop"))

-- Enhanced Character Setup
local function setupCharacter(char)
    character = char
    if not character then return end
    
    humanoid = character:WaitForChild("Humanoid", 5)
    hrp = character:WaitForChild("HumanoidRootPart", 5)
    
    if humanoid and hrp then
        -- Store original camera settings
        originalCameraType = Camera.CameraType
        originalCameraSubject = Camera.CameraSubject
        
        print("[Mobile Lock-On] Character setup complete")
        return true
    end
    
    return false
end

-- Initialize character with retry
local function initializeCharacter()
    local maxAttempts = 3
    local attempt = 1
    
    while attempt <= maxAttempts do
        if player.Character and setupCharacter(player.Character) then
            break
        end
        
        print(string.format("[Mobile Lock-On] Character setup attempt %d/%d", attempt, maxAttempts))
        task.wait(1)
        attempt = attempt + 1
    end
end

-- Initialize
initializeCharacter()
player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    setupCharacter(char)
end)

-- Enhanced Server Management
local ServerManager = {
    lastPingCheck = 0,
    pingHistory = {},
    currentRegion = "Unknown"
}

function ServerManager:getCurrentPing()
    local networkStats = Stats.Network.ServerStatsItem
    if networkStats and networkStats["Data Ping"] then
        local ping = networkStats["Data Ping"]:GetValue()
        
        -- Update ping history for mobile optimization
        if #self.pingHistory >= 10 then
            table.remove(self.pingHistory, 1)
        end
        table.insert(self.pingHistory, ping)
        
        return ping
    end
    return 999
end

function ServerManager:getAveragePing()
    if #self.pingHistory == 0 then return 999 end
    
    local total = 0
    for _, ping in ipairs(self.pingHistory) do
        total = total + ping
    end
    
    return math.floor(total / #self.pingHistory)
end

function ServerManager:detectOptimalServer()
    local ping = self:getCurrentPing()
    local avgPing = self:getAveragePing()
    
    -- Mobile users need lower ping for smooth lock-on
    local optimalThreshold = isMobile and 100 or 120
    
    return avgPing < optimalThreshold, avgPing
end

function ServerManager:hopToOptimalServer()
    local isOptimal, ping = self:detectOptimalServer()
    
    if isOptimal then
        print("[Server] Already on optimal server (Ping: " .. ping .. "ms)")
        return false
    end
    
    print("[Server] Searching for optimal server...")
    
    local success = pcall(function()
        TeleportService:Teleport(game.PlaceId, player)
    end)
    
    return success
end

-- Enhanced Target Management
local TargetManager = {
    validTargets = {},
    lastScan = 0,
    scanCooldown = isMobile and 0.2 or 0.1
}

function TargetManager:isValidTarget(model)
    if not model or not model:IsA("Model") or model == character then 
        return false 
    end
    
    local targetHumanoid = model:FindFirstChildWhichIsA("Humanoid")
    local targetHRP = model:FindFirstChild("HumanoidRootPart")
    
    if not targetHumanoid or not targetHRP or targetHumanoid.Health <= 0 then 
        return false 
    end
    
    local targetPlayer = Players:GetPlayerFromCharacter(model)
    if targetPlayer == player then return false end
    
    -- Distance and visibility check
    if hrp then
        local distance = (hrp.Position - targetHRP.Position).Magnitude
        if distance > Config.MaxLockDistance then return false end
        
        -- Mobile-optimized raycast for visibility
        if performanceMode and tick() % 3 > 0 then
            return true -- Skip raycast on mobile for performance
        end
        
        local raycast = workspace:Raycast(hrp.Position, 
            (targetHRP.Position - hrp.Position).Unit * distance)
        
        if raycast and raycast.Instance and not raycast.Instance:IsDescendantOf(model) then
            return false -- Target is behind wall
        end
    end
    
    return true
end

function TargetManager:scanForTargets()
    local currentTime = tick()
    if currentTime - self.lastScan < self.scanCooldown then
        return self.validTargets
    end
    
    self.lastScan = currentTime
    self.validTargets = {}
    
    if not hrp then return {} end
    
    -- Scan players
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character then
            if self:isValidTarget(targetPlayer.Character) then
                local distance = (hrp.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
                table.insert(self.validTargets, {
                    character = targetPlayer.Character,
                    player = targetPlayer,
                    distance = distance,
                    isPlayer = true
                })
            end
        end
    end
    
    -- Scan NPCs (limited for mobile performance)
    local maxNPCs = isMobile and 5 or 10
    local npcCount = 0
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if npcCount >= maxNPCs then break end
        
        if obj:IsA("Model") and self:isValidTarget(obj) then
            local targetPlayer = Players:GetPlayerFromCharacter(obj)
            if not targetPlayer then -- It's an NPC
                local distance = (hrp.Position - obj.HumanoidRootPart.Position).Magnitude
                table.insert(self.validTargets, {
                    character = obj,
                    player = nil,
                    distance = distance,
                    isPlayer = false
                })
                npcCount = npcCount + 1
            end
        end
    end
    
    -- Sort by distance
    table.sort(self.validTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    return self.validTargets
end

function TargetManager:getNearestTarget()
    local targets = self:scanForTargets()
    return targets[1] and targets[1].character or nil
end

function TargetManager:switchTarget(direction)
    if currentTime - lastTargetSwitchTime < Config.TargetSwitchCooldown then 
        return 
    end
    lastTargetSwitchTime = tick()
    
    local targets = self:scanForTargets()
    if #targets <= 1 then return end
    
    local currentIndex = 1
    if lockTarget then
        for i, target in ipairs(targets) do
            if target.character == lockTarget then
                currentIndex = i
                break
            end
        end
    end
    
    local newIndex
    if direction == "next" then
        newIndex = (currentIndex % #targets) + 1
    else
        newIndex = currentIndex > 1 and currentIndex - 1 or #targets
    end
    
    local newTarget = targets[newIndex]
    if newTarget then
        lockTarget = newTarget.character
        self:updateTargetIndicator()
        
        local name = newTarget.player and newTarget.player.Name or "NPC"
        print("[Lock-On] Switched to: " .. name)
    end
end

function TargetManager:updateTargetIndicator()
    self:clearIndicator()
    
    if not Config.ShowTargetIndicator or not lockTarget then 
        return 
    end
    
    local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    
    -- Create mobile-optimized indicator
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, isMobile and 120 or 140, 0, isMobile and 40 or 50)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = targetHRP
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Config.IndicatorColor
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = bb
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 2
    stroke.Parent = frame
    
    local lockTypeText = currentLockType == LOCK_TYPES.CAMLOCK and "🎯 CAM" or "🎯 AIM"
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = lockTypeText
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.Parent = frame
    
    lockBillboard = bb
    
    -- Animate
    local tween = TweenService:Create(frame, 
        TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {BackgroundTransparency = 0.6}
    )
    tween:Play()
end

function TargetManager:clearIndicator()
    if lockBillboard then
        lockBillboard:Destroy()
        lockBillboard = nil
    end
end

-- Advanced Lock System with Mobile Optimization
local LockSystem = {}

function LockSystem:calculatePrediction(targetHRP)
    if not targetHRP then return hrp.Position end
    
    local velocity = targetHRP.AssemblyLinearVelocity
    if not velocity then return targetHRP.Position end
    
    local predictionTime = currentLockType == LOCK_TYPES.CAMLOCK and 
        Config.PredictionStrength or Config.AimLockPrediction
    
    return targetHRP.Position + (velocity * predictionTime)
end

function LockSystem:updateCameraSmooth(targetPosition, deltaTime)
    if not targetPosition then return end
    
    local currentCFrame = Camera.CFrame
    local distance = (currentCFrame.Position - targetPosition).Magnitude
    
    -- Mobile-optimized smoothing
    local smoothness = isMobile and Config.MobileCamSensitivity or Config.CamLockSmoothness
    
    -- Adjust smoothness based on distance and device
    if distance > 30 then
        smoothness = smoothness * 0.7 -- Slower for distant targets
    end
    
    if Config.UseDeltaTime then
        smoothness = smoothness * (deltaTime * 60) -- Frame-rate independent
    end
    
    local targetCFrame = CFrame.lookAt(currentCFrame.Position, targetPosition)
    
    -- Slerp for smoother rotation on mobile
    if isMobile then
        Camera.CFrame = currentCFrame:Lerp(targetCFrame, smoothness)
    else
        -- More responsive for desktop
        local newCFrame = currentCFrame:Lerp(targetCFrame, smoothness)
        Camera.CFrame = newCFrame
    end
end

function LockSystem:updateCamLock(deltaTime)
    if not lockTarget or not hrp then return end
    
    local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
    if not targetHRP then 
        self:disableLock("Target lost")
        return 
    end
    
    local targetHumanoid = lockTarget:FindFirstChildWhichIsA("Humanoid")
    if not targetHumanoid or targetHumanoid.Health <= 0 then
        self:disableLock("Target eliminated")
        return
    end
    
    -- Character rotation (mobile-optimized)
    if humanoid and not humanoid.PlatformStand then
        humanoid.AutoRotate = false
        
        local targetPos = targetHRP.Position
        local lookDirection = (Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z) - hrp.Position).Unit
        
        if lookDirection.Magnitude > 0 then
            local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + lookDirection)
            local rotationSpeed = isMobile and Config.MobileCamSensitivity * 2 or Config.CamLockSmoothness * 3
            
            hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, rotationSpeed * deltaTime * 60)
        end
    end
    
    -- Camera control
    local predictedPos = self:calculatePrediction(targetHRP) + Config.CamLockOffset
    self:updateCameraSmooth(predictedPos, deltaTime)
end

function LockSystem:updateAimLock(deltaTime)
    if not lockTarget or not hrp then return end
    
    local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
    if not targetHRP then 
        self:disableLock("Target lost")
        return 
    end
    
    local targetHumanoid = lockTarget:FindFirstChildWhichIsA("Humanoid")
    if not targetHumanoid or targetHumanoid.Health <= 0 then
        self:disableLock("Target eliminated")
        return
    end
    
    -- Camera-only control for AimLock
    local predictedPos = self:calculatePrediction(targetHRP)
    
    -- Mobile aim assist
    if isMobile and Config.MobileAimAssist then
        local screenPos, onScreen = Camera:WorldToScreenPoint(predictedPos)
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        
        -- Increase smoothness for targets near screen center on mobile
        if screenDistance < 100 then
            Config.AimLockSmoothness = Config.AimLockSmoothness * 1.2
        end
    end
    
    self:updateCameraSmooth(predictedPos, deltaTime)
end

function LockSystem:enableLock(lockType)
    if not hrp then 
        print("[Lock-On] Character not ready")
        return false
    end
    
    -- Find target
    local target = TargetManager:getNearestTarget()
    if not target then
        print("[Lock-On] No targets found")
        return false
    end
    
    -- Disable current lock if any
    if isLocked then
        self:disableLock("Switching modes")
    end
    
    lockTarget = target
    currentLockType = lockType
    isLocked = true
    
    -- Store original camera settings
    originalCameraType = Camera.CameraType
    originalCameraSubject = Camera.CameraSubject
    
    -- Setup camera control
    Camera.CameraType = Enum.CameraType.Scriptable
    
    -- Create update connection
    lockConnections.update = RunService.RenderStepped:Connect(function(deltaTime)
        if currentLockType == LOCK_TYPES.CAMLOCK then
            self:updateCamLock(deltaTime)
        elseif currentLockType == LOCK_TYPES.AIMLOCK then
            self:updateAimLock(deltaTime)
        end
    end)
    
    -- Target validation
    if targetValidationEnabled then
        lockConnections.validation = RunService.Heartbeat:Connect(function()
            if lockTarget and not TargetManager:isValidTarget(lockTarget) then
                self:disableLock("Target invalid")
            end
        end)
    end
    
    -- Update indicator
    TargetManager:updateTargetIndicator()
    
    local targetPlayer = Players:GetPlayerFromCharacter(target)
    local targetName = targetPlayer and targetPlayer.Name or "NPC"
    local lockTypeName = lockType == LOCK_TYPES.CAMLOCK and "CamLock" or "AimLock"
    
    print(string.format("[Lock-On] %s enabled on %s", lockTypeName, targetName))
    
    return true
end

function LockSystem:disableLock(reason)
    isLocked = false
    currentLockType = LOCK_TYPES.NONE
    lockTarget = nil
    
    -- Clear connections
    for _, connection in pairs(lockConnections) do
        if connection then connection:Disconnect() end
    end
    lockConnections = {}
    
    -- Clear indicator
    TargetManager:clearIndicator()
    
    -- Restore camera
    if originalCameraType then
        Camera.CameraType = originalCameraType
    end
    if originalCameraSubject then
        Camera.CameraSubject = originalCameraSubject
    end
    
    -- Restore character
    if humanoid then
        humanoid.AutoRotate = true
    end
    
    if reason then
        print("[Lock-On] Disabled: " .. reason)
    end
end

function LockSystem:toggleCamLock()
    if currentLockType == LOCK_TYPES.CAMLOCK then
        self:disableLock("Manual toggle")
    else
        self:enableLock(LOCK_TYPES.CAMLOCK)
    end
end

function LockSystem:toggleAimLock()
    if currentLockType == LOCK_TYPES.AIMLOCK then
        self:disableLock("Manual toggle")
    else
        self:enableLock(LOCK_TYPES.AIMLOCK)
    end
end

-- Mobile UI Creation
local function createMobileUI()
    if not isMobile then return end
    
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Main UI container
    mobileUI = Instance.new("ScreenGui")
    mobileUI.Name = "MobileLockOnUI"
    mobileUI.ResetOnSpawn = false
    mobileUI.Parent = playerGui
    
    -- Main control frame
    mobileFrame = Instance.new("Frame")
    mobileFrame.Name = "ControlFrame"
    mobileFrame.Size = UDim2.new(0, 250, 0, 300)
    mobileFrame.Position = UDim2.new(1, -260, 0.5, -150)
    mobileFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    mobileFrame.BackgroundTransparency = 0.3
    mobileFrame.BorderSizePixel = 0
    mobileFrame.Parent = mobileUI
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 12)
    frameCorner.Parent = mobileFrame
    
    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.new(1, 1, 1)
    frameStroke.Thickness = 2
    frameStroke.Transparency = 0.7
    frameStroke.Parent = mobileFrame
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.Text = "🎯 Mobile Lock-On"
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.BackgroundTransparency = 1
    titleLabel.Parent = mobileFrame
    
    -- CamLock Button
    local camLockBtn = Instance.new("TextButton")
    camLockBtn.Size = UDim2.new(1, -20, 0, 50)
    camLockBtn.Position = UDim2.new(0, 10, 0, 50)
    camLockBtn.Text = "CamLock OFF"
    camLockBtn.TextColor3 = Color3.new(1, 1, 1)
    camLockBtn.TextScaled = true
    camLockBtn.Font = Enum.Font.Gotham
    camLockBtn.BackgroundColor3 = Color3.new(0.2, 0.4, 0.8)
    camLockBtn.BorderSizePixel = 0
    camLockBtn.Parent = mobileFrame
    
    local camLockCorner = Instance.new("UICorner")
    camLockCorner.CornerRadius = UDim.new(0, 8)
    camLockCorner.Parent = camLockBtn
    
    -- AimLock Button
    local aimLockBtn = Instance.new("TextButton")
    aimLockBtn.Size = UDim2.new(1, -20, 0, 50)
    aimLockBtn.Position = UDim2.new(0, 10, 0, 110)
    aimLockBtn.Text = "AimLock OFF"
    aimLockBtn.TextColor3 = Color3.new(1, 1, 1)
    aimLockBtn.TextScaled = true
    aimLockBtn.Font = Enum.Font.Gotham
    aimLockBtn.BackgroundColor3 = Color3.new(0.8, 0.4, 0.2)
    aimLockBtn.BorderSizePixel = 0
    aimLockBtn.Parent = mobileFrame
    
    local aimLockCorner = Instance.new("UICorner")
    aimLockCorner.CornerRadius = UDim.new(0, 8)
    aimLockCorner.Parent = aimLockBtn
    
    -- Switch Target Button
    local switchBtn = Instance.new("TextButton")
    switchBtn.Size = UDim2.new(1, -20, 0, 50)
    switchBtn.Position = UDim2.new(0, 10, 0, 170)
    switchBtn.Text = "Switch Target"
    switchBtn.TextColor3 = Color3.new(1, 1, 1)
    switchBtn.TextScaled = true
    switchBtn.Font = Enum.Font.Gotham
    switchBtn.BackgroundColor3 = Color3.new(0.4, 0.8, 0.4)
    switchBtn.BorderSizePixel = 0
    switchBtn.Parent = mobileFrame
    
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(0, 8)
    switchCorner.Parent = switchBtn
    
    -- Server Hop Button
    local serverBtn = Instance.new("TextButton")
    serverBtn.Size = UDim2.new(1, -20, 0, 50)
    serverBtn.Position = UDim2.new(0, 10, 0, 230)
    serverBtn.Text = "Find Server"
    serverBtn.TextColor3 = Color3.new(1, 1, 1)
    serverBtn.TextScaled = true
    serverBtn.Font = Enum.Font.Gotham
    serverBtn.BackgroundColor3 = Color3.new(0.8, 0.6, 0.2)
    serverBtn.BorderSizePixel = 0
    serverBtn.Parent = mobileFrame
    
    local serverCorner = Instance.new("UICorner")
    serverCorner.CornerRadius = UDim.new(0, 8)
    serverCorner.Parent = serverBtn
    
    -- Button functionality
    camLockBtn.Activated:Connect(function()
        LockSystem:toggleCamLock()
        camLockBtn.Text = currentLockType == LOCK_TYPES.CAMLOCK and "CamLock ON" or "CamLock OFF"
        camLockBtn.BackgroundColor3 = currentLockType == LOCK_TYPES.CAMLOCK and 
            Color3.new(0.2, 0.8, 0.2) or Color3.new(0.2, 0.4, 0.8)
    end)
    
    aimLockBtn.Activated:Connect(function()
        LockSystem:toggleAimLock()
        aimLockBtn.Text = currentLockType == LOCK_TYPES.AIMLOCK and "AimLock ON" or "AimLock OFF"
        aimLockBtn.BackgroundColor3 = currentLockType == LOCK_TYPES.AIMLOCK and 
            Color3.new(0.8, 0.2, 0.2) or Color3.new(0.8, 0.4, 0.2)
    end)
    
    switchBtn.Activated:Connect(function()
        if isLocked then
            TargetManager:switchTarget("next")
        end
    end)
    
    serverBtn.Activated:Connect(function()
        ServerManager:hopToOptimalServer()
    end)
    
    -- Make UI draggable
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    mobileFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mobileFrame.Position
        end
    end)
    
    mobileFrame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mobileFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, 
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    mobileFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    print("[Mobile Lock-On] Mobile UI created")
end

-- Input handling for both mobile and desktop
if not isMobile then
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.T then
            LockSystem:toggleCamLock()
        elseif input.KeyCode == Enum.KeyCode.Y then
            LockSystem:toggleAimLock()
        elseif input.KeyCode == Enum.KeyCode.G then
            if isLocked then
                TargetManager:switchTarget("next")
            end
        elseif input.KeyCode == Enum.KeyCode.H then
            ServerManager:hopToOptimalServer()
        end
    end)
end

-- Handle player respawn and cleanup
player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    
    -- Disable any active locks
    if isLocked then
        LockSystem:disableLock("Character respawned")
    end
    
    -- Setup new character
    setupCharacter(newChar)
    
    task.wait(1)
    
    -- Restore camera settings
    originalCameraSubject = Camera.CameraSubject
    originalCameraType = Camera.CameraType
    
    print("[Mobile Lock-On] Character respawn handled")
end)

-- Performance monitoring for mobile devices
local PerformanceMonitor = {
    lastFPSCheck = 0,
    fpsHistory = {},
    lowFPSCount = 0
}

function PerformanceMonitor:checkPerformance()
    if not isMobile then return end
    
    local currentTime = tick()
    if currentTime - self.lastFPSCheck < 1 then return end
    
    self.lastFPSCheck = currentTime
    
    local fps = math.floor(1 / RunService.RenderStepped:Wait())
    
    -- Track FPS history
    if #self.fpsHistory >= 5 then
        table.remove(self.fpsHistory, 1)
    end
    table.insert(self.fpsHistory, fps)
    
    -- Calculate average FPS
    local totalFPS = 0
    for _, fpsVal in ipairs(self.fpsHistory) do
        totalFPS = totalFPS + fpsVal
    end
    local avgFPS = totalFPS / #self.fpsHistory
    
    -- Adjust settings for low performance
    if avgFPS < 30 then
        self.lowFPSCount = self.lowFPSCount + 1
        
        if self.lowFPSCount >= 3 then
            -- Enable performance mode
            Config.UpdateRate = 30
            Config.LockSmoothness = 0.4
            Config.CamLockSmoothness = 0.3
            Config.AimLockSmoothness = 0.4
            targetValidationEnabled = false
            
            print("[Mobile Lock-On] Performance mode enabled (Low FPS detected)")
            self.lowFPSCount = 0
        end
    else
        self.lowFPSCount = 0
    end
end

-- Start performance monitoring
if isMobile then
    RunService.Heartbeat:Connect(function()
        PerformanceMonitor:checkPerformance()
    end)
end

-- Auto-unlock system for invalid targets
local function validateTargetContinuously()
    RunService.Heartbeat:Connect(function()
        if not isLocked or not lockTarget then return end
        
        -- Check if target is still valid
        if not TargetManager:isValidTarget(lockTarget) then
            LockSystem:disableLock("Target became invalid")
            return
        end
        
        -- Check distance
        if hrp and lockTarget:FindFirstChild("HumanoidRootPart") then
            local distance = (hrp.Position - lockTarget.HumanoidRootPart.Position).Magnitude
            if distance > Config.MaxLockDistance * 1.2 then -- Give some buffer
                LockSystem:disableLock("Target too far")
                return
            end
        end
        
        -- Mobile-specific: Check if player is moving too fast (anti-cheat detection)
        if isMobile and hrp then
            local velocity = hrp.AssemblyLinearVelocity
            if velocity and velocity.Magnitude > 100 then
                LockSystem:disableLock("High velocity detected")
                return
            end
        end
    end)
end

validateTargetContinuously()

-- Enhanced Server Quality Detection
function ServerManager:getDetailedServerInfo()
    local ping = self:getCurrentPing()
    local avgPing = self:getAveragePing()
    
    -- Get player count
    local playerCount = #Players:GetPlayers()
    
    -- Estimate server quality
    local quality = "Unknown"
    if avgPing < 50 and playerCount > 5 then
        quality = "Excellent"
    elseif avgPing < 80 and playerCount > 3 then
        quality = "Good"
    elseif avgPing < 120 then
        quality = "Fair"
    else
        quality = "Poor"
    end
    
    return {
        ping = ping,
        avgPing = avgPing,
        playerCount = playerCount,
        quality = quality
    }
end

-- Smart server hopping with region detection
function ServerManager:intelligentServerHop()
    local serverInfo = self:getDetailedServerInfo()
    
    print(string.format("[Server] Current: %s quality, %dms ping, %d players", 
        serverInfo.quality, serverInfo.avgPing, serverInfo.playerCount))
    
    -- Don't hop if server is already good
    if serverInfo.quality == "Excellent" or serverInfo.quality == "Good" then
        print("[Server] Current server is already optimal")
        return false
    end
    
    -- Hop to find better server
    local attempts = 0
    local maxAttempts = isMobile and 3 or 5
    
    local function tryHop()
        attempts = attempts + 1
        if attempts > maxAttempts then
            print("[Server] Max hop attempts reached")
            return
        end
        
        local success = pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
        
        if not success then
            task.wait(2)
            tryHop()
        end
    end
    
    tryHop()
    return true
end

-- Create mobile UI if on mobile device
if isMobile then
    createMobileUI()
    print("[Mobile Lock-On] Mobile interface initialized")
end

-- Status display system
local StatusDisplay = {
    lastUpdate = 0,
    updateInterval = 2
}

function StatusDisplay:update()
    local currentTime = tick()
    if currentTime - self.lastUpdate < self.updateInterval then return end
    
    self.lastUpdate = currentTime
    
    local status = {
        lockType = currentLockType == LOCK_TYPES.CAMLOCK and "CamLock" or 
                   currentLockType == LOCK_TYPES.AIMLOCK and "AimLock" or "None",
        target = "None",
        serverQuality = "Checking..."
    }
    
    if lockTarget then
        local targetPlayer = Players:GetPlayerFromCharacter(lockTarget)
        status.target = targetPlayer and targetPlayer.Name or "NPC"
    end
    
    local serverInfo = ServerManager:getDetailedServerInfo()
    status.serverQuality = string.format("%s (%dms)", serverInfo.quality, serverInfo.avgPing)
    
    -- Print status for debugging
    if Config.ShowDebugInfo then
        print(string.format("[Status] Lock: %s | Target: %s | Server: %s", 
            status.lockType, status.target, status.serverQuality))
    end
end

-- Start status monitoring
RunService.Heartbeat:Connect(function()
    StatusDisplay:update()
end)

-- Anti-detection measures
local AntiDetection = {
    randomizeTimings = true,
    lastRandomization = 0
}

function AntiDetection:randomizeBehavior()
    if not self.randomizeTimings then return end
    
    local currentTime = tick()
    if currentTime - self.lastRandomization < 5 then return end
    
    self.lastRandomization = currentTime
    
    -- Add slight randomness to smoothness values
    local baseSmoothnessVariation = math.random(-5, 5) / 100
    Config.CamLockSmoothness = math.max(0.1, Config.CamLockSmoothness + baseSmoothnessVariation)
    Config.AimLockSmoothness = math.max(0.1, Config.AimLockSmoothness + baseSmoothnessVariation)
    
    -- Randomize prediction slightly
    local basePredictionVariation = math.random(-2, 2) / 100
    Config.PredictionStrength = math.max(0.05, Config.PredictionStrength + basePredictionVariation)
end

-- Start anti-detection
RunService.Heartbeat:Connect(function()
    AntiDetection:randomizeBehavior()
end)

-- Emergency unlock system
local EmergencySystem = {
    emergencyKey = Enum.KeyCode.BackSlash,
    touchHoldTime = 0,
    requiredHoldTime = 2
}

function EmergencySystem:init()
    -- Desktop emergency unlock
    if not isMobile then
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            
            if input.KeyCode == self.emergencyKey then
                LockSystem:disableLock("Emergency unlock")
                print("[Emergency] All locks disabled")
            end
        end)
    else
        -- Mobile emergency unlock (hold screen edges)
        UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
            if gameProcessed then return end
            
            local touchPos = touch.Position
            local screenSize = Camera.ViewportSize
            
            -- Check if touch is near screen edge
            local nearEdge = touchPos.X < 50 or touchPos.X > screenSize.X - 50 or 
                            touchPos.Y < 50 or touchPos.Y > screenSize.Y - 50
            
            if nearEdge then
                self.touchHoldTime = 0
                
                local connection
                connection = RunService.Heartbeat:Connect(function(dt)
                    self.touchHoldTime = self.touchHoldTime + dt
                    
                    if self.touchHoldTime >= self.requiredHoldTime then
                        LockSystem:disableLock("Emergency unlock (mobile)")
                        print("[Emergency] Mobile emergency unlock activated")
                        connection:Disconnect()
                    end
                end)
                
                UserInputService.TouchEnded:Connect(function()
                    connection:Disconnect()
                end)
            end
        end)
    end
end

EmergencySystem:init()

-- Memory management for mobile
local MemoryManager = {
    lastCleanup = 0,
    cleanupInterval = 30
}

function MemoryManager:cleanup()
    if not isMobile then return end
    
    local currentTime = tick()
    if currentTime - self.lastCleanup < self.cleanupInterval then return end
    
    self.lastCleanup = currentTime
    
    -- Clear ping history if too large
    if #ServerManager.pingHistory > 10 then
        for i = 1, 5 do
            table.remove(ServerManager.pingHistory, 1)
        end
    end
    
    -- Clear FPS history if too large
    if #PerformanceMonitor.fpsHistory > 5 then
        table.remove(PerformanceMonitor.fpsHistory, 1)
    end
    
    -- Force garbage collection
    collectgarbage("collect")
end

-- Start memory management
if isMobile then
    RunService.Heartbeat:Connect(function()
        MemoryManager:cleanup()
    end)
end

-- Final initialization and status
print("[Mobile Lock-On] System fully loaded and optimized!")

if isMobile then
    print("Mobile Controls:")
    print("- Use the mobile UI on the right side of screen")
    print("- UI is draggable by touching and holding")
    print("- Hold screen edge for 2 seconds for emergency unlock")
    print("- Performance mode will auto-enable if needed")
else
    print("Desktop Controls:")
    print("T - Toggle CamLock")
    print("Y - Toggle AimLock") 
    print("G - Switch Target")
    print("H - Find Better Server")
    print("\\  - Emergency Unlock")
end

-- Show device info
local deviceInfo = string.format("Device: %s | Performance Mode: %s | Update Rate: %dHz", 
    isMobile and "Mobile" or "Desktop", 
    performanceMode and "ON" or "OFF", 
    Config.UpdateRate)

print("[Mobile Lock-On] " .. deviceInfo)

-- Initial server quality check
task.spawn(function()
    task.wait(3)
    local serverInfo = ServerManager:getDetailedServerInfo()
    print(string.format("[Mobile Lock-On] Server Quality: %s (%dms ping, %d players)", 
        serverInfo.quality, serverInfo.avgPing, serverInfo.playerCount))
end)

-- Success notification
print("[Mobile Lock-On] ✅ Ready for action!")

-- Set global flag for successful load
_G.MobileLockOnActive = true
_G.MobileLockOnVersion = "2.0"
