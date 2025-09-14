--[[ Universal Battlegrounds Lock-On Script with Rayfield UI ]]

if not game.Players.LocalPlayer.PlayerScripts:FindFirstChild("LockOn_Loaded") then 
    local data = Instance.new("NumberValue")
    data.Name = "LockOn_Loaded" 
    data.Parent = game.Players.LocalPlayer.PlayerScripts 
    print("Universal Battlegrounds Lock-On Script Loaded")

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
        warn("[Lock-On Script] Rayfield failed to load. UI will not appear.")
        return
    end
end

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

-- Advanced Lock-On System Variables
local lockTarget = nil
local lockBillboard = nil
local isLocked = false
local lockConnection = nil
local cameraConnection = nil
local targetValidationConnection = nil

-- Camera System Variables
local originalCameraType = Camera.CameraType
local originalCameraSubject = Camera.CameraSubject
local cameraOffset = Vector3.new(0, 2, 8)
local cameraHeight = 5
local smoothingFactor = 0.15

-- Lock-On Configuration
local MAX_LOCK_DISTANCE = 60
local CAMERA_FOLLOW_SPEED = 0.1
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
    end
    
    -- Monitor character state changes
    if humanoid then
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

-- Create Main Window
local Window = Rayfield:CreateWindow({
    Name = "Universal Lock-On System",
    LoadingTitle = "Loading Lock-On Script", 
    LoadingSubtitle = "Universal Battlegrounds Compatible",
    ShowText = "Lock-On Pro",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "UniversalLockOn",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false
})

-- Create Tabs
local LockOnTab = Window:CreateTab("Lock-On System", 4483362458)
local UtilityTab = Window:CreateTab("Utility", 4483362458)

-- Lock-On Tab Features
LockOnTab:CreateSection("Lock-On Controls")

-- Main Lock Toggle
local lockToggle = LockOnTab:CreateToggle({
    Name = "Enable Lock-On System",
    CurrentValue = false,
    Flag = "MainLockToggle",
    Callback = function(Value)
        if Value then
            enableLockOnSystem()
        else
            disableLockOnSystem()
        end
    end,
})

-- Lock Distance Slider
LockOnTab:CreateSlider({
    Name = "Lock Distance",
    Range = {20, 100},
    Increment = 5,
    Suffix = "Studs",
    CurrentValue = 60,
    Flag = "LockDistance",
    Callback = function(Value)
        MAX_LOCK_DISTANCE = Value
    end,
})

-- Camera Settings
LockOnTab:CreateSection("Camera Settings")

-- Camera Height Slider
LockOnTab:CreateSlider({
    Name = "Camera Height",
    Range = {0, 10},
    Increment = 1,
    Suffix = "Height",
    CurrentValue = 5,
    Flag = "CameraHeight", 
    Callback = function(Value)
        cameraHeight = Value
    end,
})

-- Camera Distance Slider
LockOnTab:CreateSlider({
    Name = "Camera Distance",
    Range = {5, 15},
    Increment = 1,
    Suffix = "Distance",
    CurrentValue = 8,
    Flag = "CameraDistance",
    Callback = function(Value)
        cameraOffset = Vector3.new(0, 2, Value)
    end,
})

-- Camera Smoothing
LockOnTab:CreateSlider({
    Name = "Camera Smoothing",
    Range = {0.05, 0.3},
    Increment = 0.05,
    Suffix = "Speed",
    CurrentValue = 0.15,
    Flag = "CameraSmoothing",
    Callback = function(Value)
        smoothingFactor = Value
    end,
})

-- Advanced Options
LockOnTab:CreateSection("Advanced Options")

-- Show Target Health
LockOnTab:CreateToggle({
    Name = "Show Target Health",
    CurrentValue = true,
    Flag = "ShowHealth",
    Callback = function(Value)
        -- Will be handled in billboard creation
    end,
})

-- Predict Target Movement
LockOnTab:CreateToggle({
    Name = "Predict Target Movement",
    CurrentValue = false,
    Flag = "PredictMovement",
    Callback = function(Value)
        -- Prediction logic will be handled in camera update
    end,
})

-- Manual Lock Controls
LockOnTab:CreateButton({
    Name = "Lock Nearest Target (T Key)",
    Callback = function()
        toggleLock()
    end
})

LockOnTab:CreateButton({
    Name = "Switch Target (Y Key)", 
    Callback = function()
        switchToNextTarget()
    end
})

-- Utility Tab Features  
UtilityTab:CreateSection("Server Management")

-- Server Hop Function (Asian Servers Priority) - From your original code
local function serverHop()
    local TeleportService = game:GetService("TeleportService")
    local success, result = pcall(function()
        TeleportService:Teleport(game.PlaceId)
    end)
    if not success then
        Rayfield:Notify({
            Title = "Server Hop Failed",
            Content = "Failed to hop servers. Try again.",
            Duration = 3
        })
    end
end

-- Asian Server Targeting Function
local function hopToAsianServer()
    local Http = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    
    local success = pcall(function()
        -- Try to get server list and filter for Asian regions
        local gameId = game.PlaceId
        
        -- Note: This is a simplified version. The actual implementation would need
        -- to use the specific game's server API if available
        local servers = {}
        
        -- For now, we'll just do multiple hops to increase chances of Asian server
        for i = 1, 3 do
            TeleportService:Teleport(gameId)
            task.wait(0.1)
        end
    end)
    
    if not success then
        Rayfield:Notify({
            Title = "Asian Server Hop Failed",
            Content = "Could not target Asian servers, using regular hop...",
            Duration = 3
        })
        serverHop()
    else
        Rayfield:Notify({
            Title = "Asian Server Hop",
            Content = "

-- LOCK-ON SYSTEM FUNCTIONS

-- Detach billboard from target
local function detachBillboard()
    if lockBillboard then
        lockBillboard:Destroy()
        lockBillboard = nil
    end
end

-- Create enhanced billboard with health display
local function attachBillboard(model)
    detachBillboard()
    local targetHRP = model:FindFirstChild("HumanoidRootPart")
    local targetHumanoid = model:FindFirstChildWhichIsA("Humanoid")
    if not targetHRP then return end
    
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 200, 0, 60)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Parent = targetHRP
    
    -- Main lock indicator
    local lockLabel = Instance.new("TextLabel")
    lockLabel.Size = UDim2.new(1, 0, 0.5, 0)
    lockLabel.Position = UDim2.new(0, 0, 0, 0)
    lockLabel.BackgroundTransparency = 1
    lockLabel.Text = "🎯 LOCKED ON"
    lockLabel.TextScaled = true
    lockLabel.Font = Enum.Font.GothamBold
    lockLabel.TextColor3 = Color3.new(1, 0.2, 0.2)
    lockLabel.TextStrokeTransparency = 0
    lockLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    lockLabel.Parent = bb
    
    -- Health display
    if targetHumanoid and Rayfield.Flags.ShowHealth.CurrentValue then
        local healthLabel = Instance.new("TextLabel")
        healthLabel.Size = UDim2.new(1, 0, 0.5, 0)
        healthLabel.Position = UDim2.new(0, 0, 0.5, 0)
        healthLabel.BackgroundTransparency = 1
        healthLabel.Text = math.floor(targetHumanoid.Health) .. "/" .. math.floor(targetHumanoid.MaxHealth)
        healthLabel.TextScaled = true
        healthLabel.Font = Enum.Font.Gotham
        healthLabel.TextColor3 = Color3.new(0, 1, 0)
        healthLabel.TextStrokeTransparency = 0
        healthLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        healthLabel.Parent = bb
        
        -- Update health continuously
        task.spawn(function()
            while bb.Parent and targetHumanoid.Parent do
                healthLabel.Text = math.floor(targetHumanoid.Health) .. "/" .. math.floor(targetHumanoid.MaxHealth)
                
                -- Color based on health percentage
                local healthPercent = targetHumanoid.Health / targetHumanoid.MaxHealth
                if healthPercent > 0.7 then
                    healthLabel.TextColor3 = Color3.new(0, 1, 0) -- Green
                elseif healthPercent > 0.3 then
                    healthLabel.TextColor3 = Color3.new(1, 1, 0) -- Yellow
                else
                    healthLabel.TextColor3 = Color3.new(1, 0, 0) -- Red
                end
                
                task.wait(0.1)
            end
        end)
    end
    
    -- Animate the lock indicator
    task.spawn(function()
        while bb.Parent do
            TweenService:Create(lockLabel, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
                TextColor3 = Color3.new(1, 0.5, 0.5)
            }):Play()
            task.wait(0.5)
            TweenService:Create(lockLabel, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
                TextColor3 = Color3.new(1, 0.2, 0.2)
            }):Play()
            task.wait(0.5)
        end
    end)
    
    lockBillboard = bb
end

-- Enhanced target validation
local function isValidTarget(model)
    if not model or not model:IsA("Model") then return false end
    local targetHumanoid = model:FindFirstChildWhichIsA("Humanoid")
    local targetHRP = model:FindFirstChild("HumanoidRootPart")
    
    if not targetHumanoid or not targetHRP or targetHumanoid.Health <= 0 then return false end
    if model == character then return false end
    
    local targetPlayer = Players:GetPlayerFromCharacter(model)
    if targetPlayer == player then return false end
    
    -- Check if target is too far
    if hrp then
        local distance = (hrp.Position - targetHRP.Position).Magnitude
        if distance > MAX_LOCK_DISTANCE then return false end
    end
    
    return true
end

-- Get nearest valid target
local function getNearestTarget()
    if not hrp then return nil end
    
    local nearest, nearestDist = nil, MAX_LOCK_DISTANCE
    
    -- Check all players first
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character and isValidTarget(targetPlayer.Character) then
            local dist = (hrp.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = targetPlayer.Character
            end
        end
    end
    
    -- Check NPCs/other models if no players found
    if not nearest then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and isValidTarget(obj) then
                local dist = (hrp.Position - obj.HumanoidRootPart.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = obj
                end
            end
        end
    end
    
    return nearest
end

-- Advanced camera system with smooth following
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
    
    -- Handle different character states
    local shouldFollowCamera = true
    
    if isRagdolled or isGrabbed then
        -- During ragdoll or grab, prioritize camera following over character rotation
        shouldFollowCamera = true
        if humanoid then
            humanoid.AutoRotate = false -- Prevent weird standing ragdoll
        end
    else
        -- Normal state - allow character rotation
        if humanoid then
            humanoid.AutoRotate = false -- We'll handle rotation manually
        end
        
        -- Rotate character to face target (only when not ragdolled)
        if not isRagdolled and not isGrabbed then
            local lookDirection = (targetHRP.Position - hrp.Position)
            lookDirection = Vector3.new(lookDirection.X, 0, lookDirection.Z).Unit
            
            local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + lookDirection)
            hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, smoothingFactor * 2)
        end
    end
    
    -- Advanced camera positioning
    if shouldFollowCamera then
        local targetPos = targetHRP.Position
        local myPos = hrp.Position
        
        -- Prediction for moving targets
        if Rayfield.Flags.PredictMovement.CurrentValue then
            local targetVelocity = targetHRP.AssemblyLinearVelocity
            if targetVelocity.Magnitude > 5 then
                targetPos = targetPos + (targetVelocity * 0.2) -- Predict 0.2 seconds ahead
            end
        end
        
        -- Calculate camera position
        local midPoint = (myPos + targetPos) / 2
        local direction = (targetPos - myPos).Unit
        local rightVector = direction:Cross(Vector3.new(0, 1, 0))
        
        -- Position camera to show both player and target
        local distance = (myPos - targetPos).Magnitude
        local dynamicOffset = math.min(distance * 0.3, cameraOffset.Z)
        
        local cameraPos = midPoint + Vector3.new(0, cameraHeight + distance * 0.1, 0) - direction * dynamicOffset
        
        -- Smooth camera movement
        local currentCFrame = Camera.CFrame
        local targetCFrame = CFrame.lookAt(cameraPos, midPoint)
        
        Camera.CFrame = currentCFrame:Lerp(targetCFrame, CAMERA_FOLLOW_SPEED)
        
        -- Ensure camera shows both characters
        local newDistance = (cameraPos - midPoint).Magnitude
        if newDistance < 10 then
            Camera.CFrame = CFrame.lookAt(midPoint + Vector3.new(0, 8, 8), midPoint)
        end
    end
end

-- Switch to next available target
function switchToNextTarget()
    if tick() - lastTargetSwitchTime < TARGET_SWITCH_COOLDOWN then return end
    lastTargetSwitchTime = tick()
    
    if not hrp then return end
    
    local validTargets = {}
    
    -- Collect all valid targets
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character and isValidTarget(targetPlayer.Character) then
            table.insert(validTargets, targetPlayer.Character)
        end
    end
    
    if #validTargets <= 1 then return end
    
    -- Find current target index and switch to next
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
        
        Rayfield:Notify({
            Title = "Target Switched",
            Content = "Locked onto new target",
            Duration = 1.5
        })
    end
end

-- Main unlock function
function unlock(reason)
    isLocked = false
    lockTarget = nil
    detachBillboard()
    
    -- Disconnect all lock-related connections
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
    
    -- Restore character rotation
    if humanoid then
        humanoid.AutoRotate = wasAutoRotateEnabled
    end
    
    -- Update UI
    lockToggle:Set(false)
    
    if reason then
        print("[Lock-On] Unlocked:", reason)
    end
end

-- Main lock function
function lock()
    if not hrp then return false end
    
    local target = getNearestTarget()
    if not target then
        Rayfield:Notify({
            Title = "No Target",
            Content = "No valid targets in range",
            Duration = 2
        })
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
    
    -- Main update loop
    lockConnection = RunService.Heartbeat:Connect(updateCamera)
    
    -- Target validation loop
    targetValidationConnection = RunService.Heartbeat:Connect(function()
        if lockTarget and not isValidTarget(lockTarget) then
            unlock("Target became invalid")
        end
    end)
    
    Rayfield:Notify({
        Title = "Target Locked",
        Content = "Locked onto target successfully",
        Duration = 2
    })
    
    return true
end

-- Toggle lock function
function toggleLock()
    if isLocked then
        unlock("Manual unlock")
    else
        if not lock() then
            -- If lock failed, ensure toggle is off
            lockToggle:Set(false)
        end
    end
end

-- Enable the entire lock-on system
function enableLockOnSystem()
    -- Set up keybinds
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
    
    Rayfield:Notify({
        Title = "Lock-On System",
        Content = "Press T to lock, Y to switch targets",
        Duration = 4
    })
end

-- Disable the entire lock-on system
function disableLockOnSystem()
    unlock("System disabled")
end

-- Handle character respawn
player.CharacterAdded:Connect(function(newChar)
    setupCharacter(newChar)
    
    -- If we were locked, unlock on respawn
    if isLocked then
        unlock("Character respawned")
    end
    
    task.wait(2) -- Wait for character to fully load
    
    -- Update original camera subject
    originalCameraSubject = Camera.CameraSubject
end)

-- Cleanup on script end
game:BindToClose(function()
    unlock("Game closing")
end)

-- Performance optimization for mobile/low-end devices
UtilityTab:CreateSection("Performance Settings")

UtilityTab:CreateToggle({
    Name = "Performance Mode",
    CurrentValue = false,
    Flag = "PerformanceMode",
    Callback = function(Value)
        if Value then
            -- Reduce visual effects for better performance
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            for _, effect in pairs(game.Lighting:GetChildren()) do
                if effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or 
                   effect:IsA("ColorCorrectionEffect") or effect:IsA("DepthOfFieldEffect") then
                    effect.Enabled = false
                end
            end
        else
            -- Restore visual effects
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            for _, effect in pairs(game.Lighting:GetChildren()) do
                if effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or 
                   effect:IsA("ColorCorrectionEffect") or effect:IsA("DepthOfFieldEffect") then
                    effect.Enabled = true
                end
            end
        end
    end,
})

-- Mobile touch support detection
UtilityTab:CreateSection("Mobile Support")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

if isMobile then
    -- Create mobile-friendly lock button
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "MobileLockOnGUI"
    mobileGui.ResetOnSpawn = false
    mobileGui.Parent = player:WaitForChild("PlayerGui")
    
    local lockButton = Instance.new("TextButton")
    lockButton.Size = UDim2.new(0, 80, 0, 80)
    lockButton.Position = UDim2.new(0.85, 0, 0.7, 0)
    lockButton.Text = "🎯"
    lockButton.TextSize = 30
    lockButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    lockButton.TextColor3 = Color3.new(1, 1, 1)
    lockButton.BorderSizePixel = 0
    lockButton.Parent = mobileGui
    
    -- Rounded corners
    local corner1 = Instance.new("UICorner")
    corner1.CornerRadius = UDim.new(0, 12)
    corner1.Parent = lockButton
    
    -- Switch button
    local switchButton = Instance.new("TextButton")
    switchButton.Size = UDim2.new(0, 60, 0, 60)
    switchButton.Position = UDim2.new(0.85, 0, 0.55, 0)
    switchButton.Text = "🔄"
    switchButton.TextSize = 24
    switchButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    switchButton.TextColor3 = Color3.new(1, 1, 1)
    switchButton.BorderSizePixel = 0
    switchButton.Parent = mobileGui
    
    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(0, 10)
    corner2.Parent = switchButton
    
    -- Mobile button functionality
    lockButton.Activated:Connect(function()
        toggleLock()
        lockButton.Text = isLocked and "🔓" or "🎯"
    end)
    
    switchButton.Activated:Connect(function()
        if isLocked then
            switchToNextTarget()
        end
    end)
    
    -- Draggable mobile buttons
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
    
    Rayfield:Notify({
        Title = "Mobile Mode Detected",
        Content = "Mobile buttons added! Drag to reposition.",
        Duration = 5
    })
end

-- Enhanced keybind system for PC
if not isMobile then
    UtilityTab:CreateSection("Keybind Settings")
    
    UtilityTab:CreateKeybind({
        Name = "Toggle Lock-On",
        CurrentKeybind = "T",
        HoldToInteract = false,
        Flag = "LockToggleKeybind",
        Callback = function()
            toggleLock()
        end,
    })
    
    UtilityTab:CreateKeybind({
        Name = "Switch Target",
        CurrentKeybind = "Y", 
        HoldToInteract = false,
        Flag = "SwitchTargetKeybind",
        Callback = function()
            if isLocked then
                switchToNextTarget()
            end
        end,
    })
end

-- Debug information
LockOnTab:CreateSection("Debug Info")

local debugLabel = LockOnTab:CreateLabel("Status: System Ready")

-- Update debug info
task.spawn(function()
    while task.wait(1) do
        if lockTarget then
            local targetName = "Unknown"
            local targetPlayer = Players:GetPlayerFromCharacter(lockTarget)
            if targetPlayer then
                targetName = targetPlayer.Name
            end
            debugLabel:Set("Status: Locked on " .. targetName)
        else
            debugLabel:Set("Status: No Target")
        end
    end
end)

-- Final initialization message
task.wait(1)
Rayfield:Notify({
    Title = "Universal Lock-On System",
    Content = "System loaded! " .. (isMobile and "Use mobile buttons to lock." or "Press T to lock, Y to switch."),
    Duration = 6
})

print("[Universal Battlegrounds Lock-On] Script loaded successfully!")
print("Controls: " .. (isMobile and "Mobile buttons available" or "T = Toggle Lock, Y = Switch Target"))
print("Features: Advanced camera, target switching, health display, mobile support")

                end
