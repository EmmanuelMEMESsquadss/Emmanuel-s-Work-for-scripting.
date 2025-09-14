--[[ Universal Battlegrounds Lock-On Script - Mobile Optimized for Arceus X ]]

-- Check if already loaded
if game.Players.LocalPlayer.PlayerScripts:FindFirstChild("MobileLockOn_Loaded") then 
    return
end

local loadedMarker = Instance.new("BoolValue")
loadedMarker.Name = "MobileLockOn_Loaded"
loadedMarker.Parent = game.Players.LocalPlayer.PlayerScripts

print("[Mobile Lock-On] Starting load...")

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Player Variables
local player = Players.LocalPlayer
local character, humanoid, hrp

-- Mobile detection
local isMobile = UserInputService.TouchEnabled

-- Lock-On System Variables
local lockTarget = nil
local lockBillboard = nil
local isLocked = false
local lockConnection = nil
local cameraConnection = nil
local targetValidationConnection = nil

-- Camera System Variables
local originalCameraType = Camera.CameraType
local originalCameraSubject = Camera.CameraSubject
local cameraOffset = Vector3.new(0, 5, 10)
local smoothingFactor = 0.12

-- Configuration
local MAX_LOCK_DISTANCE = 60
local TARGET_SWITCH_COOLDOWN = 0.5
local lastTargetSwitchTime = 0

-- Character state tracking
local isRagdolled = false
local isGrabbed = false
local wasAutoRotateEnabled = true

-- Setup character function
local function setupCharacter(char)
    character = char
    if not character then return end
    
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
    
    if humanoid then 
        wasAutoRotateEnabled = humanoid.AutoRotate
        
        -- Monitor character states
        humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
            isRagdolled = humanoid.PlatformStand
        end)
        
        humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
            isGrabbed = humanoid.Sit
        end)
    end
end

-- Initialize character
if player.Character then 
    setupCharacter(player.Character) 
end
player.CharacterAdded:Connect(setupCharacter)

-- Load Rayfield with better error handling and fallbacks
local Rayfield = nil
local Window = nil

-- Try to load Rayfield
local function loadRayfield()
    local success = false
    local attempts = 0
    local maxAttempts = 3
    
    while not success and attempts < maxAttempts do
        attempts = attempts + 1
        print("[Mobile Lock-On] Rayfield load attempt " .. attempts)
        
        success = pcall(function()
            if attempts == 1 then
                Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
            elseif attempts == 2 then
                Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source"))()
            else
                -- Final fallback
                Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/robloxscriptsnet/unfair-hub/main/rblxhub4mobile"))()
            end
        end)
        
        if not success then
            task.wait(1)
        end
    end
    
    return success
end

-- Load UI
if loadRayfield() and Rayfield then
    print("[Mobile Lock-On] Rayfield loaded successfully")
    
    -- Create Main Window with mobile-optimized settings
    Window = Rayfield:CreateWindow({
        Name = "Mobile Lock-On System",
        LoadingTitle = "Mobile Lock-On Loading", 
        LoadingSubtitle = "Arceus X Optimized",
        ShowText = "Lock-On Pro Mobile",
        ConfigurationSaving = {
            Enabled = false  -- Disabled for mobile stability
        },
        Discord = {
            Enabled = false
        },
        KeySystem = false
    })
    
    -- Create Tabs
    local LockTab = Window:CreateTab("Lock-On", 4483362458)
    local UtilityTab = Window:CreateTab("Utility", 4483362458)
    
    -- LOCK-ON TAB
    LockTab:CreateSection("Lock-On Controls")
    
    -- Enable/Disable Lock System
    LockTab:CreateToggle({
        Name = "Enable Lock-On System",
        CurrentValue = true,
        Callback = function(Value)
            if not Value and isLocked then
                unlock("System disabled")
            end
        end,
    })
    
    -- Lock Distance
    LockTab:CreateSlider({
        Name = "Lock Distance",
        Range = {20, 100},
        Increment = 5,
        Suffix = "Studs",
        CurrentValue = 60,
        Callback = function(Value)
            MAX_LOCK_DISTANCE = Value
        end,
    })
    
    -- Camera Settings
    LockTab:CreateSection("Camera Settings")
    
    LockTab:CreateSlider({
        Name = "Camera Smoothing",
        Range = {0.05, 0.25},
        Increment = 0.05,
        Suffix = "",
        CurrentValue = 0.12,
        Callback = function(Value)
            smoothingFactor = Value
        end,
    })
    
    -- Mobile Controls
    LockTab:CreateSection("Mobile Controls")
    
    LockTab:CreateButton({
        Name = "Lock Nearest Target",
        Callback = function()
            toggleLock()
        end
    })
    
    LockTab:CreateButton({
        Name = "Switch Target", 
        Callback = function()
            switchToNextTarget()
        end
    })
    
    -- UTILITY TAB
    UtilityTab:CreateSection("Server Management")
    
    -- Server hopping functions with improved Asian server targeting
    local function getCurrentServerPing()
        local stats = game:GetService("Stats")
        local network = stats.Network
        local serverStats = network.ServerStatsItem
        
        if serverStats and serverStats["Data Ping"] then
            return serverStats["Data Ping"]:GetValue()
        end
        return 999 -- High default if can't detect
    end
    
    local function isAsianTimeZone()
        local timezone = os.date("%z")
        -- Asian timezones are typically +05:30 to +09:00
        local hour = tonumber(timezone:sub(1, 3))
        return hour and hour >= 5 and hour <= 9
    end
    
    local function serverHop()
        TeleportService:Teleport(game.PlaceId)
    end
    
    local function hopToAsianServer()
        local attempts = 0
        local maxAttempts = 8
        local initialPing = getCurrentServerPing()
        
        print("[Server Hop] Current ping: " .. initialPing .. "ms")
        print("[Server Hop] Attempting to find Asian server...")
        
        -- Use coroutine for non-blocking execution
        coroutine.wrap(function()
            while attempts < maxAttempts do
                attempts = attempts + 1
                
                -- Multiple rapid teleports to increase chances
                for i = 1, 2 do
                    local success, error = pcall(function()
                        TeleportService:Teleport(game.PlaceId)
                    end)
                    
                    if not success then
                        print("[Server Hop] Attempt " .. attempts .. " failed: " .. tostring(error))
                    end
                    
                    if i == 1 then task.wait(0.1) end
                end
                
                task.wait(0.2)
            end
        end)()
        
        if Window and Rayfield then
            Rayfield:Notify({
                Title = "Asian Server Search",
                Content = "Attempting " .. maxAttempts .. " hops to find Asian server...",
                Duration = 3
            })
        end
    end
    
    UtilityTab:CreateButton({
        Name = "Server Hop (Asian Priority)",
        Callback = function()
            hopToAsianServer()
        end
    })
    
    UtilityTab:CreateButton({
        Name = "Regular Server Hop",
        Callback = function()
            serverHop()
        end
    })
    
    UtilityTab:CreateButton({
        Name = "Rejoin Server",
        Callback = function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
        end
    })
    
    -- Mobile Performance
    UtilityTab:CreateSection("Mobile Performance")
    
    UtilityTab:CreateToggle({
        Name = "Performance Mode",
        CurrentValue = isMobile,
        Callback = function(Value)
            if Value then
                -- Optimize for mobile
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                for _, effect in pairs(game.Lighting:GetChildren()) do
                    if effect:IsA("BloomEffect") or effect:IsA("BlurEffect") then
                        effect.Enabled = false
                    end
                end
            else
                settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            end
        end,
    })
    
    print("[Mobile Lock-On] UI loaded successfully")
else
    print("[Mobile Lock-On] Rayfield failed to load, using mobile buttons only")
end

-- MOBILE GUI SYSTEM (Always create for mobile)
local mobileGui = nil

local function createMobileGUI()
    if mobileGui then mobileGui:Destroy() end
    
    mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "MobileLockOnGUI"
    mobileGui.ResetOnSpawn = false
    mobileGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Main lock button
    local lockButton = Instance.new("TextButton")
    lockButton.Name = "LockButton"
    lockButton.Size = UDim2.new(0, 70, 0, 70)
    lockButton.Position = UDim2.new(0.88, 0, 0.65, 0)
    lockButton.Text = "🎯"
    lockButton.TextSize = 28
    lockButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
    lockButton.TextColor3 = Color3.new(1, 1, 1)
    lockButton.BorderSizePixel = 0
    lockButton.Font = Enum.Font.GothamBold
    lockButton.Parent = mobileGui
    
    -- Lock button styling
    local lockCorner = Instance.new("UICorner")
    lockCorner.CornerRadius = UDim.new(0, 12)
    lockCorner.Parent = lockButton
    
    local lockStroke = Instance.new("UIStroke")
    lockStroke.Color = Color3.new(0, 1, 0)
    lockStroke.Thickness = 2
    lockStroke.Parent = lockButton
    
    -- Switch button
    local switchButton = Instance.new("TextButton")
    switchButton.Name = "SwitchButton"
    switchButton.Size = UDim2.new(0, 55, 0, 55)
    switchButton.Position = UDim2.new(0.88, 0, 0.52, 0)
    switchButton.Text = "🔄"
    switchButton.TextSize = 22
    switchButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    switchButton.TextColor3 = Color3.new(1, 1, 1)
    switchButton.BorderSizePixel = 0
    switchButton.Font = Enum.Font.GothamBold
    switchButton.Parent = mobileGui
    
    -- Switch button styling
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(0, 10)
    switchCorner.Parent = switchButton
    
    local switchStroke = Instance.new("UIStroke")
    switchStroke.Color = Color3.new(0.5, 0.5, 0.5)
    switchStroke.Thickness = 1
    switchStroke.Parent = switchButton
    
    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(0, 120, 0, 25)
    statusLabel.Position = UDim2.new(0.85, 0, 0.45, 0)
    statusLabel.Text = "Ready"
    statusLabel.TextSize = 16
    statusLabel.BackgroundColor3 = Color3.new(0, 0, 0)
    statusLabel.BackgroundTransparency = 0.3
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
    statusLabel.BorderSizePixel = 0
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = mobileGui
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = statusLabel
    
    -- Button functionality
    lockButton.Activated:Connect(function()
        toggleLock()
    end)
    
    switchButton.Activated:Connect(function()
        if isLocked then
            switchToNextTarget()
        end
    end)
    
    -- Update button states
    local function updateButtonStates()
        if isLocked then
            lockButton.Text = "🔓"
            lockButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
            lockStroke.Color = Color3.new(1, 0, 0)
            switchButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
            switchStroke.Color = Color3.new(0, 1, 0)
        else
            lockButton.Text = "🎯"
            lockButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
            lockStroke.Color = Color3.new(0, 1, 0)
            switchButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
            switchStroke.Color = Color3.new(0.5, 0.5, 0.5)
        end
    end
    
    -- Update status
    task.spawn(function()
        while mobileGui and mobileGui.Parent do
            if isLocked and lockTarget then
                local targetPlayer = Players:GetPlayerFromCharacter(lockTarget)
                local targetName = targetPlayer and targetPlayer.Name or "NPC"
                statusLabel.Text = "Locked: " .. targetName
            else
                statusLabel.Text = "Ready"
            end
            updateButtonStates()
            task.wait(0.5)
        end
    end)
    
    -- Make buttons draggable
    local function makeDraggable(button)
        local dragging = false
        local dragInput, dragStart, startPos
        
        local function update(input)
            local delta = input.Position - dragStart
            button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
        
        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = button.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or 
               input.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    update(input)
                end
            end
        end)
    end
    
    makeDraggable(lockButton)
    makeDraggable(switchButton)
    makeDraggable(statusLabel)
    
    return mobileGui
end

-- Always create mobile GUI
createMobileGUI()

-- LOCK-ON SYSTEM FUNCTIONS

-- Detach billboard
local function detachBillboard()
    if lockBillboard then
        lockBillboard:Destroy()
        lockBillboard = nil
    end
end

-- Create billboard
local function attachBillboard(model)
    detachBillboard()
    local targetHRP = model:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 40)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = targetHRP
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "LOCKED ON"
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 0.3, 0.3)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Parent = bb
    
    lockBillboard = bb
end

-- Target validation
local function isValidTarget(model)
    if not model or not model:IsA("Model") then return false end
    local targetHumanoid = model:FindFirstChildWhichIsA("Humanoid")
    local targetHRP = model:FindFirstChild("HumanoidRootPart")
    
    if not targetHumanoid or not targetHRP or targetHumanoid.Health <= 0 then return false end
    if model == character then return false end
    
    local targetPlayer = Players:GetPlayerFromCharacter(model)
    if targetPlayer == player then return false end
    
    if hrp then
        local distance = (hrp.Position - targetHRP.Position).Magnitude
        if distance > MAX_LOCK_DISTANCE then return false end
    end
    
    return true
end

-- Get nearest target
local function getNearestTarget()
    if not hrp then return nil end
    
    local nearest, nearestDist = nil, MAX_LOCK_DISTANCE
    
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character and isValidTarget(targetPlayer.Character) then
            local dist = (hrp.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = targetPlayer.Character
            end
        end
    end
    
    return nearest
end

-- Camera update function
local function updateCamera()
    if not lockTarget or not hrp or not lockTarget:FindFirstChild("HumanoidRootPart") then 
        return 
    end
    
    local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
    local targetHumanoid = lockTarget:FindFirstChildWhichIsA("Humanoid")
    
    if not targetHRP or not targetHumanoid or targetHumanoid.Health <= 0 then
        unlock("Target became invalid")
        return
    end
    
    -- Handle character rotation (only when not ragdolled)
    if not isRagdolled and not isGrabbed and humanoid then
        humanoid.AutoRotate = false
        local lookDirection = (targetHRP.Position - hrp.Position)
        lookDirection = Vector3.new(lookDirection.X, 0, lookDirection.Z).Unit
        
        if lookDirection.Magnitude > 0 then
            local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + lookDirection)
            hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, smoothingFactor * 3)
        end
    end
    
    -- Camera positioning
    local targetPos = targetHRP.Position
    local myPos = hrp.Position
    local midPoint = (myPos + targetPos) / 2
    local distance = (myPos - targetPos).Magnitude
    
    -- Dynamic camera positioning
    local cameraHeight = 5 + math.min(distance * 0.1, 3)
    local cameraDistance = 8 + math.min(distance * 0.2, 5)
    
    local cameraPos = midPoint + Vector3.new(0, cameraHeight, cameraDistance)
    local targetCFrame = CFrame.lookAt(cameraPos, midPoint)
    
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothingFactor)
end

-- Switch target
function switchToNextTarget()
    if tick() - lastTargetSwitchTime < TARGET_SWITCH_COOLDOWN then return end
    lastTargetSwitchTime = tick()
    
    if not hrp then return end
    
    local validTargets = {}
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character and isValidTarget(targetPlayer.Character) then
            table.insert(validTargets, targetPlayer.Character)
        end
    end
    
    if #validTargets <= 1 then return end
    
    local currentIndex = 1
    if lockTarget then
        for i, target in ipairs(validTargets) do
            if target == lockTarget then
                currentIndex = i
                break
            end
        end
    end
    
    local nextIndex = (currentIndex % #validTargets) + 1
    local newTarget = validTargets[nextIndex]
    
    if newTarget then
        lockTarget = newTarget
        attachBillboard(newTarget)
    end
end

-- Unlock function
function unlock(reason)
    isLocked = false
    lockTarget = nil
    detachBillboard()
    
    if lockConnection then
        lockConnection:Disconnect()
        lockConnection = nil
    end
    
    if cameraConnection then
        cameraConnection:Disconnect() 
        cameraConnection = nil
    end
    
    if targetValidationConnection then
        targetValidationConnection:Disconnect()
        targetValidationConnection = nil
    end
    
    -- Restore camera
    Camera.CameraType = originalCameraType
    if originalCameraSubject then
        Camera.CameraSubject = originalCameraSubject
    end
    
    -- Restore character
    if humanoid then
        humanoid.AutoRotate = wasAutoRotateEnabled
    end
    
    if reason then
        print("[Lock-On] Unlocked:", reason)
    end
end

-- Lock function
function lock()
    if not hrp then return false end
    
    local target = getNearestTarget()
    if not target then
        print("[Lock-On] No valid targets found")
        return false
    end
    
    lockTarget = target
    isLocked = true
    attachBillboard(target)
    
    -- Store original camera settings
    originalCameraType = Camera.CameraType
    originalCameraSubject = Camera.CameraSubject
    
    -- Set up camera
    Camera.CameraType = Enum.CameraType.Scriptable
    
    -- Main update connections
    lockConnection = RunService.Heartbeat:Connect(updateCamera)
    
    targetValidationConnection = RunService.Heartbeat:Connect(function()
        if lockTarget and not isValidTarget(lockTarget) then
            unlock("Target became invalid")
        end
    end)
    
    print("[Lock-On] Locked onto target")
    return true
end

-- Toggle lock
function toggleLock()
    if isLocked then
        unlock("Manual unlock")
    else
        lock()
    end
end

-- PC keybinds (if not mobile)
if not isMobile then
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.T then
            toggleLock()
        elseif input.KeyCode == Enum.KeyCode.Y then
            if isLocked then
                switchToNextTarget()
            end
        end
    end)
end

-- Handle respawn
player.CharacterAdded:Connect(function(newChar)
    setupCharacter(newChar)
    if isLocked then
        unlock("Character respawned")
    end
    task.wait(2)
    originalCameraSubject = Camera.CameraSubject
    
    -- Recreate mobile GUI
    if isMobile then
        createMobileGUI()
    end
end)

-- Final loading message
print("[Mobile Lock-On] Script loaded successfully!")
print("Mobile: " .. (isMobile and "YES - Touch buttons available" or "NO - Use T/Y keys"))
print("UI: " .. (Window and "Rayfield loaded" or "Mobile-only mode"))

-- Notification
if Window and Rayfield then
    Rayfield:Notify({
        Title = "Mobile Lock-On System",
        Content = "System loaded successfully! Use mobile buttons or UI controls.",
        Duration = 5
    })
end
