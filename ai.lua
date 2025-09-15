-- Arceus X Mobile Lock-On System v3.0
-- 100% Mobile Optimized for Battlegrounds Games
-- Fixed UI compatibility issues with mobile executors

-- Prevent multiple loads
if getgenv().ArceusLockOnLoaded then 
    return
end
getgenv().ArceusLockOnLoaded = true

print("🎯 [Arceus Lock-On] Loading mobile system...")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")

-- Player and Camera
local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local character, humanoid, hrp

-- Mobile-only verification
local isMobile = UserInputService.TouchEnabled
if not isMobile then
    warn("⚠️ This script is mobile-only!")
    return
end

-- Lock System State
local lockTarget = nil
local lockIndicator = nil
local isLocking = false
local lockType = "NONE" -- CAMLOCK, AIMLOCK, NONE

-- Camera Control
local originalCameraSubject = nil
local cameraConnection = nil

-- Mobile UI Variables
local mobileUI = nil
local mainFrame = nil
local isUIVisible = true
local isDragging = false

-- Configuration (Mobile Optimized)
local Config = {
    -- Lock Settings
    maxDistance = 65,
    smoothness = 0.35,
    prediction = 0.12,
    
    -- Mobile Camera Settings
    camLockSmooth = 0.28,
    aimLockSmooth = 0.32,
    rotationSpeed = 0.25,
    
    -- Visual
    showIndicator = true,
    indicatorColor = Color3.new(1, 0.1, 0.4),
    
    -- Performance
    updateRate = 40, -- Lower for mobile
    scanRate = 0.15,
}

-- Target Management
local targets = {}
local currentTargetIndex = 1
local lastScanTime = 0
local lastSwitchTime = 0

print("📱 [Arceus Lock-On] Mobile device detected")

-- Enhanced Character Setup
local function setupCharacter()
    character = player.Character
    if not character then return false end
    
    humanoid = character:FindFirstChildWhichIsA("Humanoid")
    hrp = character:FindFirstChild("HumanoidRootPart")
    
    if humanoid and hrp then
        originalCameraSubject = Camera.CameraSubject
        print("✅ [Arceus Lock-On] Character ready")
        return true
    end
    
    return false
end

-- Character initialization with retry
local function initCharacter()
    local attempts = 0
    local maxAttempts = 5
    
    while attempts < maxAttempts do
        if player.Character and setupCharacter() then
            return true
        end
        attempts = attempts + 1
        wait(0.5)
    end
    
    warn("❌ [Arceus Lock-On] Failed to setup character")
    return false
end

-- Initialize character
initCharacter()
player.CharacterAdded:Connect(function()
    wait(1)
    setupCharacter()
    if isLocking then
        disableLock("Character respawned")
    end
end)

-- Target Validation
local function isValidTarget(target)
    if not target or target == character then return false end
    
    local targetHumanoid = target:FindFirstChildWhichIsA("Humanoid")
    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    
    if not targetHumanoid or not targetHRP then return false end
    if targetHumanoid.Health <= 0 then return false end
    
    -- Distance check
    if hrp then
        local distance = (hrp.Position - targetHRP.Position).Magnitude
        if distance > Config.maxDistance then return false end
    end
    
    -- Player check
    local targetPlayer = Players:GetPlayerFromCharacter(target)
    if targetPlayer == player then return false end
    
    return true
end

-- Target Scanning (Mobile Optimized)
local function scanTargets()
    local currentTime = tick()
    if currentTime - lastScanTime < Config.scanRate then
        return targets
    end
    
    lastScanTime = currentTime
    targets = {}
    
    if not hrp then return targets end
    
    -- Scan players only for mobile performance
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character then
            if isValidTarget(targetPlayer.Character) then
                local distance = (hrp.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
                table.insert(targets, {
                    character = targetPlayer.Character,
                    player = targetPlayer,
                    distance = distance
                })
            end
        end
    end
    
    -- Sort by distance
    table.sort(targets, function(a, b)
        return a.distance < b.distance
    end)
    
    return targets
end

-- Get Nearest Target
local function getNearestTarget()
    local validTargets = scanTargets()
    if #validTargets > 0 then
        return validTargets[1].character
    end
    return nil
end

-- Target Indicator
local function createIndicator(target)
    if lockIndicator then
        lockIndicator:Destroy()
        lockIndicator = nil
    end
    
    if not Config.showIndicator or not target then return end
    
    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 35)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = targetHRP
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Config.indicatorColor
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = billboard
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 2
    stroke.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = lockType == "CAMLOCK" and "🎯 CAM" or "🎯 AIM"
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0
    label.Parent = frame
    
    lockIndicator = billboard
    
    -- Pulse animation
    local tween = TweenService:Create(frame, 
        TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {BackgroundTransparency = 0.5}
    )
    tween:Play()
end

-- Camera Control Functions
local function getPredictedPosition(targetHRP)
    if not targetHRP then return nil end
    
    local velocity = targetHRP.AssemblyLinearVelocity or Vector3.new()
    return targetHRP.Position + (velocity * Config.prediction)
end

local function updateCamLock()
    if not lockTarget or not hrp then return end
    
    local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
    if not targetHRP then 
        disableLock("Target lost HRP")
        return 
    end
    
    -- Validate target
    if not isValidTarget(lockTarget) then
        disableLock("Target invalid")
        return
    end
    
    -- Character rotation
    if humanoid and not humanoid.PlatformStand then
        humanoid.AutoRotate = false
        local targetPos = targetHRP.Position
        local direction = (Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z) - hrp.Position).Unit
        
        if direction.Magnitude > 0 then
            local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + direction)
            hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, Config.rotationSpeed)
        end
    end
    
    -- Camera control
    local predictedPos = getPredictedPosition(targetHRP)
    if predictedPos then
        local currentCFrame = Camera.CFrame
        local targetCFrame = CFrame.lookAt(currentCFrame.Position, predictedPos + Vector3.new(0, 1.5, 0))
        Camera.CFrame = currentCFrame:Lerp(targetCFrame, Config.camLockSmooth)
    end
end

local function updateAimLock()
    if not lockTarget or not hrp then return end
    
    local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
    if not targetHRP then 
        disableLock("Target lost HRP")
        return 
    end
    
    -- Validate target
    if not isValidTarget(lockTarget) then
        disableLock("Target invalid")
        return
    end
    
    -- Camera-only control
    local predictedPos = getPredictedPosition(targetHRP)
    if predictedPos then
        local currentCFrame = Camera.CFrame
        local targetCFrame = CFrame.lookAt(currentCFrame.Position, predictedPos)
        Camera.CFrame = currentCFrame:Lerp(targetCFrame, Config.aimLockSmooth)
    end
end

-- Lock System Functions
function enableLock(type)
    if not hrp then 
        print("❌ Character not ready")
        return false
    end
    
    local target = getNearestTarget()
    if not target then
        print("❌ No targets found")
        return false
    end
    
    if isLocking then
        disableLock("Switching modes")
    end
    
    lockTarget = target
    lockType = type
    isLocking = true
    
    Camera.CameraSubject = hrp
    
    if type == "CAMLOCK" then
        cameraConnection = RunService.RenderStepped:Connect(updateCamLock)
    elseif type == "AIMLOCK" then
        cameraConnection = RunService.RenderStepped:Connect(updateAimLock)
    end
    
    createIndicator(target)
    
    local targetPlayer = Players:GetPlayerFromCharacter(target)
    local targetName = targetPlayer and targetPlayer.Name or "NPC"
    print(string.format("🎯 %s enabled on %s", type, targetName))
    
    return true
end

function disableLock(reason)
    isLocking = false
    lockType = "NONE"
    lockTarget = nil
    
    if cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
    
    if lockIndicator then
        lockIndicator:Destroy()
        lockIndicator = nil
    end
    
    if originalCameraSubject then
        Camera.CameraSubject = originalCameraSubject
    end
    
    if humanoid then
        humanoid.AutoRotate = true
    end
    
    if reason then
        print("🔓 Lock disabled: " .. reason)
    end
end

function switchTarget()
    if not isLocking then return end
    
    local currentTime = tick()
    if currentTime - lastSwitchTime < 0.3 then return end
    lastSwitchTime = currentTime
    
    local validTargets = scanTargets()
    if #validTargets <= 1 then return end
    
    -- Find current target index
    local currentIndex = 1
    for i, target in ipairs(validTargets) do
        if target.character == lockTarget then
            currentIndex = i
            break
        end
    end
    
    -- Switch to next target
    local nextIndex = (currentIndex % #validTargets) + 1
    local newTarget = validTargets[nextIndex]
    
    if newTarget then
        lockTarget = newTarget.character
        createIndicator(newTarget.character)
        
        local name = newTarget.player and newTarget.player.Name or "NPC"
        print("🔄 Switched to: " .. name)
    end
end

-- Server Management (Mobile Optimized)
local function getCurrentPing()
    local networkStats = Stats.Network.ServerStatsItem
    if networkStats and networkStats["Data Ping"] then
        return networkStats["Data Ping"]:GetValue()
    end
    return 999
end

local function hopToNewServer()
    local currentPing = getCurrentPing()
    print("🌐 Current ping: " .. math.floor(currentPing) .. "ms")
    
    if currentPing < 80 then
        print("✅ Server already optimal")
        return
    end
    
    print("🔄 Hopping to better server...")
    pcall(function()
        TeleportService:Teleport(game.PlaceId, player)
    end)
end

-- Mobile UI Creation (Arceus X Compatible)
local function createMobileUI()
    -- Try different parent methods for better compatibility
    local parentGui
    
    -- Method 1: Try CoreGui first (works with most executors)
    local success1 = pcall(function()
        parentGui = CoreGui
    end)
    
    -- Method 2: Fall back to PlayerGui
    if not success1 then
        pcall(function()
            parentGui = player:WaitForChild("PlayerGui")
        end)
    end
    
    -- Method 3: Last resort - direct creation
    if not parentGui then
        parentGui = game:GetService("StarterGui")
    end
    
    -- Create main UI
    mobileUI = Instance.new("ScreenGui")
    mobileUI.Name = "ArceusLockOnMobile"
    mobileUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    mobileUI.IgnoreGuiInset = true
    mobileUI.Parent = parentGui
    
    -- Main container frame
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainContainer"
    mainFrame.Size = UDim2.new(0, 200, 0, 320)
    mainFrame.Position = UDim2.new(1, -210, 0.5, -160)
    mainFrame.BackgroundColor3 = Color3.new(0.05, 0.05, 0.05)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = mobileUI
    
    -- Frame styling
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.new(1, 0.2, 0.4)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.new(1, 0.2, 0.4)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🎯 Arceus Lock-On"
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = titleBar
    
    -- Button container
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(1, -20, 1, -60)
    buttonContainer.Position = UDim2.new(0, 10, 0, 50)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = mainFrame
    
    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
    buttonLayout.Padding = UDim.new(0, 10)
    buttonLayout.Parent = buttonContainer
    
    -- Function to create styled buttons
    local function createButton(name, text, color, layoutOrder)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.new(1, 0, 0, 45)
        button.BackgroundColor3 = color
        button.BorderSizePixel = 0
        button.Text = text
        button.TextColor3 = Color3.new(1, 1, 1)
        button.TextScaled = true
        button.Font = Enum.Font.Gotham
        button.LayoutOrder = layoutOrder
        button.Parent = buttonContainer
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button
        
        local buttonStroke = Instance.new("UIStroke")
        buttonStroke.Color = Color3.new(1, 1, 1)
        buttonStroke.Thickness = 1
        buttonStroke.Transparency = 0.8
        buttonStroke.Parent = button
        
        return button
    end
    
    -- Create buttons
    local camLockBtn = createButton("CamLockBtn", "CamLock OFF", Color3.new(0.2, 0.4, 0.8), 1)
    local aimLockBtn = createButton("AimLockBtn", "AimLock OFF", Color3.new(0.8, 0.4, 0.2), 2)
    local switchBtn = createButton("SwitchBtn", "Switch Target", Color3.new(0.4, 0.8, 0.2), 3)
    local serverBtn = createButton("ServerBtn", "Find Server", Color3.new(0.8, 0.6, 0.2), 4)
    local hideBtn = createButton("HideBtn", "Hide UI", Color3.new(0.6, 0.6, 0.6), 5)
    
    -- Status display
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(1, 0, 0, 40)
    statusFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    statusFrame.BackgroundTransparency = 0.3
    statusFrame.BorderSizePixel = 0
    statusFrame.LayoutOrder = 6
    statusFrame.Parent = buttonContainer
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = statusFrame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 1, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: Ready"
    statusLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = statusFrame
    
    -- Button Functions
    camLockBtn.Activated:Connect(function()
        if lockType == "CAMLOCK" then
            disableLock("Manual disable")
            camLockBtn.Text = "CamLock OFF"
            camLockBtn.BackgroundColor3 = Color3.new(0.2, 0.4, 0.8)
        else
            if enableLock("CAMLOCK") then
                camLockBtn.Text = "CamLock ON"
                camLockBtn.BackgroundColor3 = Color3.new(0.2, 0.8, 0.2)
                aimLockBtn.Text = "AimLock OFF"
                aimLockBtn.BackgroundColor3 = Color3.new(0.8, 0.4, 0.2)
            end
        end
    end)
    
    aimLockBtn.Activated:Connect(function()
        if lockType == "AIMLOCK" then
            disableLock("Manual disable")
            aimLockBtn.Text = "AimLock OFF"
            aimLockBtn.BackgroundColor3 = Color3.new(0.8, 0.4, 0.2)
        else
            if enableLock("AIMLOCK") then
                aimLockBtn.Text = "AimLock ON"
                aimLockBtn.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
                camLockBtn.Text = "CamLock OFF"
                camLockBtn.BackgroundColor3 = Color3.new(0.2, 0.4, 0.8)
            end
        end
    end)
    
    switchBtn.Activated:Connect(function()
        switchTarget()
    end)
    
    serverBtn.Activated:Connect(function()
        hopToNewServer()
    end)
    
    hideBtn.Activated:Connect(function()
        if isUIVisible then
            mainFrame.Visible = false
            isUIVisible = false
            
            -- Create show button
            local showBtn = Instance.new("TextButton")
            showBtn.Size = UDim2.new(0, 60, 0, 60)
            showBtn.Position = UDim2.new(1, -70, 0, 10)
            showBtn.BackgroundColor3 = Color3.new(1, 0.2, 0.4)
            showBtn.BorderSizePixel = 0
            showBtn.Text = "🎯"
            showBtn.TextColor3 = Color3.new(1, 1, 1)
            showBtn.TextScaled = true
            showBtn.Font = Enum.Font.GothamBold
            showBtn.Parent = mobileUI
            
            local showCorner = Instance.new("UICorner")
            showCorner.CornerRadius = UDim.new(1, 0)
            showCorner.Parent = showBtn
            
            showBtn.Activated:Connect(function()
                mainFrame.Visible = true
                isUIVisible = true
                showBtn:Destroy()
            end)
        end
    end)
    
    -- Status updater
    spawn(function()
        while mobileUI and mobileUI.Parent do
            local status = "Ready"
            if isLocking then
                local targetName = "Unknown"
                if lockTarget then
                    local targetPlayer = Players:GetPlayerFromCharacter(lockTarget)
                    targetName = targetPlayer and targetPlayer.Name or "NPC"
                end
                status = lockType .. " on " .. targetName
            end
            
            statusLabel.Text = "Status: " .. status
            wait(1)
        end
    end)
    
    print("✅ [Arceus Lock-On] Mobile UI created successfully")
end

-- Create UI after small delay for better compatibility
spawn(function()
    wait(0.5)
    createMobileUI()
end)

-- Emergency unlock (touch screen edges for 2 seconds)
local touchStart = 0
UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
    if gameProcessed then return end
    
    local pos = touch.Position
    local screenSize = Camera.ViewportSize
    
    -- Check if touch is near screen corners
    local nearCorner = (pos.X < 80 and pos.Y < 80) or 
                      (pos.X > screenSize.X - 80 and pos.Y < 80) or
                      (pos.X < 80 and pos.Y > screenSize.Y - 80) or
                      (pos.X > screenSize.X - 80 and pos.Y > screenSize.Y - 80)
    
    if nearCorner then
        touchStart = tick()
        local connection
        connection = RunService.Heartbeat:Connect(function()
            if tick() - touchStart >= 2 then
                disableLock("Emergency unlock")
                print("🚨 Emergency unlock activated")
                connection:Disconnect()
            end
        end)
        
        UserInputService.TouchEnded:Connect(function()
            connection:Disconnect()
        end)
    end
end)

-- Performance monitor
local lastFPSCheck = 0
local lowFPSCounter = 0

spawn(function()
    while true do
        wait(2)
        
        local currentTime = tick()
        if currentTime - lastFPSCheck >= 2 then
            lastFPSCheck = currentTime
            
            local fps = math.floor(1 / RunService.RenderStepped:Wait())
            
            if fps < 25 then
                lowFPSCounter = lowFPSCounter + 1
                
                if lowFPSCounter >= 3 then
                    -- Enable ultra performance mode
                    Config.updateRate = 30
                    Config.smoothness = 0.4
                    Config.scanRate = 0.2
                    print("⚡ Ultra performance mode enabled")
                    lowFPSCounter = 0
                end
            else
                lowFPSCounter = 0
            end
        end
    end
end)

-- Cleanup on game leaving
game:GetService("Players").PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == player then
        if isLocking then
            disableLock("Player leaving")
        end
        if mobileUI then
            mobileUI:Destroy()
        end
    end
end)

-- Final initialization
print("🎯 [Arceus Lock-On] System fully loaded!")
print("📱 Mobile optimized for Arceus X")
print("🎮 Touch the UI buttons to control lock-on")
print("🚨 Hold screen corners for 2 seconds for emergency unlock")

-- Show current device stats
spawn(function()
    wait(1)
    local ping = getCurrentPing()
    print("📊 Device Stats:")
    print("   • Ping: " .. math.floor(ping) .. "ms")
    print("   • Platform: Mobile")
    print("   • Executor: Arceus X Compatible")
    print("   • Lock System: Ready")
end)

getgenv().ArceusLockOnActive = true
getgenv().ArceusLockOnVersion = "3.0"

print("✅ [Arceus Lock-On] Ready for battle!")
