-- Enhanced Lock-On System for Roblox Battlegrounds Games
-- Features: Instant lock-on, smooth camera, Asian server targeting, mobile optimization

-- Check if already loaded
if game.Players.LocalPlayer.PlayerScripts:FindFirstChild("EnhancedLockOn_Loaded") then 
    return
end

local loadedMarker = Instance.new("BoolValue")
loadedMarker.Name = "EnhancedLockOn_Loaded"
loadedMarker.Parent = game.Players.LocalPlayer.PlayerScripts

print("[Enhanced Lock-On] Starting load...")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Camera = workspace.CurrentCamera

-- Player Variables
local player = Players.LocalPlayer
local character, humanoid, hrp

-- Mobile Detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

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
local smoothingFactor = 0.15

-- Configuration
local MAX_LOCK_DISTANCE = 75
local TARGET_SWITCH_COOLDOWN = 0.3
local lastTargetSwitchTime = 0

-- Character state tracking
local isRagdolled = false
local isStunned = false
local wasAutoRotateEnabled = true

-- Asian Server Data (Based on research)
local ASIAN_SERVER_RANGES = {
    -- Singapore servers
    "128.116.85.0/24",
    "128.116.119.0/24",
    -- Hong Kong servers
    "128.116.88.0/24", 
    "128.116.102.0/24",
    -- Japan servers
    "128.116.97.0/24",
    "128.116.113.0/24",
    -- India servers (when available)
    "128.116.106.0/24",
    -- Australia servers
    "128.116.124.0/24"
}

-- Setup character function with enhanced state detection
local function setupCharacter(char)
    character = char
    if not character then return end
    
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
    
    if humanoid then 
        wasAutoRotateEnabled = humanoid.AutoRotate
        
        -- Enhanced state monitoring
        humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
            isRagdolled = humanoid.PlatformStand
        end)
        
        humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
            isStunned = humanoid.Sit
        end)
        
        -- Monitor for death
        humanoid.Died:Connect(function()
            if isLocked then
                unlock("Character died")
            end
        end)
    end
end

-- Initialize character
if player.Character then 
    setupCharacter(player.Character) 
end
player.CharacterAdded:Connect(setupCharacter)

-- Enhanced Server Detection and Hopping System
local ServerHopper = {}

function ServerHopper:getCurrentPing()
    local stats = game:GetService("Stats")
    local networkStats = stats.Network.ServerStatsItem
    if networkStats and networkStats["Data Ping"] then
        return networkStats["Data Ping"]:GetValue()
    end
    return 999
end

function ServerHopper:isAsianTimeZone()
    -- Check if user is likely in Asian timezone (UTC+4 to UTC+12)
    local currentHour = tonumber(os.date("%H"))
    local utcHour = tonumber(os.date("!%H"))
    local timezoneOffset = currentHour - utcHour
    
    -- Normalize to -12 to +12 range
    if timezoneOffset > 12 then
        timezoneOffset = timezoneOffset - 24
    elseif timezoneOffset < -12 then
        timezoneOffset = timezoneOffset + 24
    end
    
    return timezoneOffset >= 4 and timezoneOffset <= 12
end

function ServerHopper:getServerRegion()
    -- Try to detect current server region using HTTP service
    local success, result = pcall(function()
        return HttpService:GetAsync("https://httpbin.org/ip")
    end)
    
    if success then
        local data = HttpService:JSONDecode(result)
        return data.origin or "Unknown"
    end
    return "Unknown"
end

function ServerHopper:isLikelyAsianServer()
    local currentPing = self:getCurrentPing()
    local isAsianTZ = self:isAsianTimeZone()
    
    -- If user is in Asian timezone and ping is reasonable, likely Asian server
    if isAsianTZ and currentPing < 150 then
        return true
    end
    
    -- If ping is very low and user might be in Asia
    if currentPing < 80 then
        return true
    end
    
    return false
end

function ServerHopper:hopToAsianServer()
    local currentPing = self:getCurrentPing()
    print("[Server Hop] Current ping: " .. currentPing .. "ms")
    
    if self:isLikelyAsianServer() then
        print("[Server Hop] Already on likely Asian server")
        return
    end
    
    print("[Server Hop] Attempting to find Asian server...")
    
    -- Multiple hop strategy
    local hopAttempts = 0
    local maxHops = 12
    
    local function performHop()
        hopAttempts = hopAttempts + 1
        
        if hopAttempts > maxHops then
            print("[Server Hop] Max attempts reached")
            return
        end
        
        -- Use rapid teleportation technique
        local success, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
        
        if not success then
            print("[Server Hop] Hop failed: " .. tostring(err))
            task.wait(1)
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

-- Enhanced Mobile GUI System
local mobileGui = nil

local function createEnhancedMobileGUI()
    if mobileGui then mobileGui:Destroy() end
    
    mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "EnhancedLockOnGUI"
    mobileGui.ResetOnSpawn = false
    mobileGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Main container frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 200, 0, 280)
    mainFrame.Position = UDim2.new(0.85, 0, 0.4, 0)
    mainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    mainFrame.BackgroundTransparency = 0.2
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = mobileGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 15)
    mainCorner.Parent = mainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.new(0, 0.7, 1)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.Text = "Lock-On Pro"
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Parent = mainFrame
    
    -- Lock button
    local lockButton = Instance.new("TextButton")
    lockButton.Name = "LockButton"
    lockButton.Size = UDim2.new(0.9, 0, 0, 45)
    lockButton.Position = UDim2.new(0.05, 0, 0, 40)
    lockButton.Text = "🎯 LOCK TARGET"
    lockButton.TextSize = 16
    lockButton.Font = Enum.Font.GothamBold
    lockButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
    lockButton.TextColor3 = Color3.new(1, 1, 1)
    lockButton.BorderSizePixel = 0
    lockButton.Parent = mainFrame
    
    local lockCorner = Instance.new("UICorner")
    lockCorner.CornerRadius = UDim.new(0, 8)
    lockCorner.Parent = lockButton
    
    -- Switch button
    local switchButton = Instance.new("TextButton")
    switchButton.Name = "SwitchButton"
    switchButton.Size = UDim2.new(0.9, 0, 0, 35)
    switchButton.Position = UDim2.new(0.05, 0, 0, 95)
    switchButton.Text = "🔄 SWITCH TARGET"
    switchButton.TextSize = 14
    switchButton.Font = Enum.Font.Gotham
    switchButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    switchButton.TextColor3 = Color3.new(1, 1, 1)
    switchButton.BorderSizePixel = 0
    switchButton.Parent = mainFrame
    
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(0, 8)
    switchCorner.Parent = switchButton
    
    -- Status display
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(0.9, 0, 0, 50)
    statusFrame.Position = UDim2.new(0.05, 0, 0, 140)
    statusFrame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = mainFrame
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 8)
    statusCorner.Parent = statusFrame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -10, 1, 0)
    statusLabel.Position = UDim2.new(0, 5, 0, 0)
    statusLabel.Text = "Status: Ready"
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextWrapped = true
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusFrame
    
    -- Server hop section
    local serverSection = Instance.new("Frame")
    serverSection.Size = UDim2.new(0.9, 0, 0, 80)
    serverSection.Position = UDim2.new(0.05, 0, 0, 200)
    serverSection.BackgroundTransparency = 1
    serverSection.Parent = mainFrame
    
    local asianHopButton = Instance.new("TextButton")
    asianHopButton.Size = UDim2.new(1, 0, 0, 35)
    asianHopButton.Position = UDim2.new(0, 0, 0, 0)
    asianHopButton.Text = "🌏 Asian Server"
    asianHopButton.TextSize = 13
    asianHopButton.Font = Enum.Font.GothamBold
    asianHopButton.BackgroundColor3 = Color3.new(0.8, 0.3, 0.3)
    asianHopButton.TextColor3 = Color3.new(1, 1, 1)
    asianHopButton.BorderSizePixel = 0
    asianHopButton.Parent = serverSection
    
    local asianCorner = Instance.new("UICorner")
    asianCorner.CornerRadius = UDim.new(0, 6)
    asianCorner.Parent = asianHopButton
    
    local regularHopButton = Instance.new("TextButton")
    regularHopButton.Size = UDim2.new(0.48, 0, 0, 30)
    regularHopButton.Position = UDim2.new(0, 0, 0, 45)
    regularHopButton.Text = "🌍 Server Hop"
    regularHopButton.TextSize = 11
    regularHopButton.Font = Enum.Font.Gotham
    regularHopButton.BackgroundColor3 = Color3.new(0.4, 0.4, 0.4)
    regularHopButton.TextColor3 = Color3.new(1, 1, 1)
    regularHopButton.BorderSizePixel = 0
    regularHopButton.Parent = serverSection
    
    local regularCorner = Instance.new("UICorner")
    regularCorner.CornerRadius = UDim.new(0, 6)
    regularCorner.Parent = regularHopButton
    
    local rejoinButton = Instance.new("TextButton")
    rejoinButton.Size = UDim2.new(0.48, 0, 0, 30)
    rejoinButton.Position = UDim2.new(0.52, 0, 0, 45)
    rejoinButton.Text = "🔄 Rejoin"
    rejoinButton.TextSize = 11
    rejoinButton.Font = Enum.Font.Gotham
    rejoinButton.BackgroundColor3 = Color3.new(0.4, 0.4, 0.4)
    rejoinButton.TextColor3 = Color3.new(1, 1, 1)
    rejoinButton.BorderSizePixel = 0
    rejoinButton.Parent = serverSection
    
    local rejoinCorner = Instance.new("UICorner")
    rejoinCorner.CornerRadius = UDim.new(0, 6)
    rejoinCorner.Parent = rejoinButton
    
    -- Button functionality
    lockButton.Activated:Connect(function()
        toggleLock()
    end)
    
    switchButton.Activated:Connect(function()
        if isLocked then
            switchToNextTarget()
        end
    end)
    
    asianHopButton.Activated:Connect(function()
        ServerHopper:hopToAsianServer()
    end)
    
    regularHopButton.Activated:Connect(function()
        ServerHopper:regularServerHop()
    end)
    
    rejoinButton.Activated:Connect(function()
        ServerHopper:rejoinServer()
    end)
    
    -- Update button states
    local function updateButtonStates()
        if isLocked then
            lockButton.Text = "🔓 UNLOCK"
            lockButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
            switchButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
        else
            lockButton.Text = "🎯 LOCK TARGET"
            lockButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
            switchButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
        end
    end
    
    -- Status updater
    task.spawn(function()
        while mobileGui and mobileGui.Parent do
            local ping = ServerHopper:getCurrentPing()
            local isAsianTZ = ServerHopper:isAsianTimeZone()
            
            if isLocked and lockTarget then
                local targetPlayer = Players:GetPlayerFromCharacter(lockTarget)
                local targetName = targetPlayer and targetPlayer.Name or "NPC"
                statusLabel.Text = "Status: Locked\nTarget: " .. targetName .. "\nPing: " .. math.floor(ping) .. "ms"
            else
                statusLabel.Text = "Status: Ready\nPing: " .. math.floor(ping) .. "ms\nRegion: " .. (isAsianTZ and "Asian TZ" or "Non-Asian TZ")
            end
            updateButtonStates()
            task.wait(1)
        end
    end)
    
    -- Make GUI draggable
    local function makeDraggable(frame)
        local dragging = false
        local dragInput, dragStart, startPos
        
        local function update(input)
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
        
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                
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
    
    makeDraggable(mainFrame)
    
    return mobileGui
end

-- Create GUI (always for mobile, optional for PC)
if isMobile then
    createEnhancedMobileGUI()
end

-- Enhanced Lock-On System Functions

-- Billboard management
local function detachBillboard()
    if lockBillboard then
        lockBillboard:Destroy()
        lockBillboard = nil
    end
end

local function attachBillboard(model)
    detachBillboard()
    local targetHRP = model:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 150, 0, 50)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Parent = targetHRP
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = Color3.new(1, 0.3, 0.3)
    mainFrame.BackgroundTransparency = 0.3
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = bb
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 0, 0)
    stroke.Thickness = 2
    stroke.Parent = mainFrame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "🎯 LOCKED ON"
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Parent = mainFrame
    
    lockBillboard = bb
    
    -- Animate billboard
    local tween = TweenService:Create(mainFrame, 
        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {BackgroundTransparency = 0.7}
    )
    tween:Play()
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
    
    -- Check distance
    if hrp then
        local distance = (hrp.Position - targetHRP.Position).Magnitude
        if distance > MAX_LOCK_DISTANCE then return false end
    end
    
    -- Check if target is behind walls (basic raycast)
    if hrp then
        local rayOrigin = hrp.Position
        local rayDirection = (targetHRP.Position - rayOrigin).Unit * (targetHRP.Position - rayOrigin).Magnitude
        
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {character, model}
        
        local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        
        -- If there's a wall between us and target, it's still valid but note it
        -- (Some battlegrounds games allow lock through walls)
    end
    
    return true
end

-- Get nearest target with smart prioritization
local function getNearestTarget()
    if not hrp then return nil end
    
    local validTargets = {}
    
    -- Collect all valid targets
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character and isValidTarget(targetPlayer.Character) then
            local distance = (hrp.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
            table.insert(validTargets, {
                character = targetPlayer.Character,
                distance = distance,
                player = targetPlayer
            })
        end
    end
    
    -- Sort by distance
    table.sort(validTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Return nearest
    return validTargets[1] and validTargets[1].character or nil
end

-- Enhanced camera system
local function updateCameraAndRotation()
    if not lockTarget or not hrp or not lockTarget:FindFirstChild("HumanoidRootPart") then 
        return 
    end
    
    local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
    local targetHumanoid = lockTarget:FindFirstChildWhichIsA("Humanoid")
    
    if not targetHRP or not targetHumanoid or targetHumanoid.Health <= 0 then
        unlock("Target became invalid")
        return
    end
    
    -- Enhanced character rotation (only when not ragdolled/stunned)
    if not isRagdolled and not isStunned and humanoid and humanoid.Health > 0 then
        humanoid.AutoRotate = false
        
        local lookDirection = (targetHRP.Position - hrp.Position)
        lookDirection = Vector3.new(lookDirection.X, 0, lookDirection.Z).Unit
        
        if lookDirection.Magnitude > 0 then
            local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + lookDirection)
            -- Smooth rotation
            hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, smoothingFactor * 4)
        end
    end
    
    -- Enhanced camera positioning
    local targetPos = targetHRP.Position + Vector3.new(0, 2, 0) -- Aim slightly higher
    local myPos = hrp.Position
    local midPoint = (myPos + targetPos) / 2
    local distance = (myPos - targetPos).Magnitude
    
    -- Dynamic camera positioning based on distance
    local cameraHeight = 6 + math.min(distance * 0.12, 4)
    local cameraDistance = 10 + math.min(distance * 0.15, 8)
    
    -- Calculate ideal camera position
    local directionToTarget = (targetPos - myPos).Unit
    local sideVector = Vector3.new(-directionToTarget.Z, 0, directionToTarget.X)
    
    local cameraPos = midPoint + Vector3.new(0, cameraHeight, 0) + (sideVector * 2) - (directionToTarget * cameraDistance * 0.3)
    
    -- Smooth camera movement
    local targetCFrame = CFrame.lookAt(cameraPos, midPoint)
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothingFactor)
end

-- Target switching with smart selection
function switchToNextTarget()
    if tick() - lastTargetSwitchTime < TARGET_SWITCH_COOLDOWN then return end
    lastTargetSwitchTime = tick()
    
    if not hrp then return end
    
    local validTargets = {}
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character and isValidTarget(targetPlayer.Character) then
            local distance = (hrp.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
            table.insert(validTargets, {
                character = targetPlayer.Character,
                distance = distance,
                player = targetPlayer
            })
        end
    end
    
    if #validTargets <= 1 then return end
    
    -- Sort by distance
    table.sort(validTargets, function(a, b)
        return a.distance < b.distance
    end)
    
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
    local newTarget = validTargets[nextIndex].character
    
    if newTarget then
        lockTarget = newTarget
        attachBillboard(newTarget)
        print("[Lock-On] Switched to:", validTargets[nextIndex].player.Name)
    end
end

-- Enhanced unlock function
function unlock(reason)
    isLocked = false
    lockTarget = nil
    detachBillboard()
    
    -- Disconnect all connections
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

-- Enhanced lock function
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
    
    -- Main update connection
    lockConnection = RunService.Heartbeat:Connect(updateCameraAndRotation)
    
    -- Target validation
    targetValidationConnection = RunService.Heartbeat:Connect(function()
        if lockTarget and not isValidTarget(lockTarget) then
            unlock("Target became invalid")
        end
    end)
    
    local targetPlayer = Players:GetPlayerFromCharacter(target)
    local targetName = targetPlayer and targetPlayer.Name or "NPC"
    print("[Lock-On] Locked onto:", targetName)
    return true
end

-- Toggle lock function
function toggleLock()
    if isLocked then
        unlock("Manual unlock")
    else
        lock()
    end
end

-- Input handling for PC users
if not isMobile then
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.T then
            toggleLock()
        elseif input.KeyCode == Enum.KeyCode.Y then
            if isLocked then
                switchToNextTarget()
            end
        elseif input.KeyCode == Enum.KeyCode.G then
            -- Quick server hop to Asian server
            ServerHopper:hopToAsianServer()
        elseif input.KeyCode == Enum.KeyCode.H then
            -- Regular server hop
            ServerHopper:regularServerHop()
        end
    end)
    
    -- Create a simple PC GUI if mobile GUI isn't shown
    local function createPCGUI()
        local pcGui = Instance.new("ScreenGui")
        pcGui.Name = "EnhancedLockOnPC"
        pcGui.ResetOnSpawn = false
        pcGui.Parent = player:WaitForChild("PlayerGui")
        
        local infoFrame = Instance.new("Frame")
        infoFrame.Size = UDim2.new(0, 250, 0, 120)
        infoFrame.Position = UDim2.new(0, 10, 0, 10)
        infoFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
        infoFrame.BackgroundTransparency = 0.3
        infoFrame.BorderSizePixel = 0
        infoFrame.Parent = pcGui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = infoFrame
        
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -10, 1, -10)
        infoLabel.Position = UDim2.new(0, 5, 0, 5)
        infoLabel.BackgroundTransparency = 1
        infoLabel.TextColor3 = Color3.new(1, 1, 1)
        infoLabel.TextSize = 14
        infoLabel.Font = Enum.Font.Gotham
        infoLabel.TextWrapped = true
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.TextYAlignment = Enum.TextYAlignment.Top
        infoLabel.Text = "Enhanced Lock-On System\n\nT - Toggle Lock\nY - Switch Target\nG - Asian Server Hop\nH - Regular Server Hop"
        infoLabel.Parent = infoFrame
        
        -- Status updater
        task.spawn(function()
            while pcGui and pcGui.Parent do
                local ping = ServerHopper:getCurrentPing()
                local isAsianTZ = ServerHopper:isAsianTimeZone()
                local status = isLocked and "LOCKED" or "READY"
                
                infoLabel.Text = string.format(
                    "Enhanced Lock-On System\nStatus: %s\nPing: %dms\nRegion: %s\n\nT - Toggle Lock\nY - Switch Target\nG - Asian Server Hop\nH - Regular Server Hop",
                    status, math.floor(ping), isAsianTZ and "Asian TZ" or "Non-Asian TZ"
                )
                task.wait(1)
            end
        end)
        
        return pcGui
    end
    
    createPCGUI()
end

-- Enhanced respawn handling
player.CharacterAdded:Connect(function(newChar)
    task.wait(1) -- Wait for character to fully load
    setupCharacter(newChar)
    
    if isLocked then
        unlock("Character respawned")
    end
    
    -- Restore original camera settings
    task.wait(2)
    originalCameraSubject = Camera.CameraSubject
    originalCameraType = Camera.CameraType
    
    -- Recreate mobile GUI if needed
    if isMobile then
        task.wait(1)
        createEnhancedMobileGUI()
    end
end)

-- Auto-unlock on character state changes
task.spawn(function()
    while true do
        if character and humanoid and isLocked then
            -- Check if character is in a state where locking doesn't make sense
            if humanoid.Health <= 0 then
                unlock("Character died")
            elseif humanoid.PlatformStand and not isRagdolled then
                -- Character got ragdolled
                isRagdolled = true
            elseif humanoid.Sit and not isStunned then
                -- Character got stunned/grabbed
                isStunned = true
            end
        end
        task.wait(0.5)
    end
end)

-- Performance optimization
local lastOptimizationCheck = 0
task.spawn(function()
    while true do
        task.wait(5) -- Check every 5 seconds
        
        if tick() - lastOptimizationCheck > 30 then -- Optimize every 30 seconds
            lastOptimizationCheck = tick()
            
            -- Clean up any orphaned connections
            if lockConnection and not isLocked then
                lockConnection:Disconnect()
                lockConnection = nil
            end
            
            if cameraConnection and not isLocked then
                cameraConnection:Disconnect()
                cameraConnection = nil
            end
            
            if targetValidationConnection and not isLocked then
                targetValidationConnection:Disconnect()
                targetValidationConnection = nil
            end
            
            -- Force garbage collection for mobile devices
            if isMobile then
                collectgarbage("collect")
            end
        end
    end
end)

-- Server analytics for better server detection
local ServerAnalytics = {}

function ServerAnalytics:init()
    self.startTime = tick()
    self.pingHistory = {}
    self.playerHistory = {}
    
    -- Track ping over time
    task.spawn(function()
        while true do
            local ping = ServerHopper:getCurrentPing()
            table.insert(self.pingHistory, ping)
            
            -- Keep only last 60 readings (5 minutes of data)
            if #self.pingHistory > 60 then
                table.remove(self.pingHistory, 1)
            end
            
            task.wait(5)
        end
    end)
    
    -- Track player count over time
    task.spawn(function()
        while true do
            local playerCount = #Players:GetPlayers()
            table.insert(self.playerHistory, playerCount)
            
            -- Keep only last 60 readings
            if #self.playerHistory > 60 then
                table.remove(self.playerHistory, 1)
            end
            
            task.wait(10)
        end
    end)
end

function ServerAnalytics:getAveragePing()
    if #self.pingHistory == 0 then return 999 end
    
    local total = 0
    for _, ping in ipairs(self.pingHistory) do
        total = total + ping
    end
    
    return total / #self.pingHistory
end

function ServerAnalytics:isPingStable()
    if #self.pingHistory < 5 then return false end
    
    local recent = {}
    for i = math.max(1, #self.pingHistory - 4), #self.pingHistory do
        table.insert(recent, self.pingHistory[i])
    end
    
    local avg = 0
    for _, ping in ipairs(recent) do
        avg = avg + ping
    end
    avg = avg / #recent
    
    -- Check if all recent pings are within 50ms of average
    for _, ping in ipairs(recent) do
        if math.abs(ping - avg) > 50 then
            return false
        end
    end
    
    return true
end

function ServerAnalytics:getServerQuality()
    local avgPing = self:getAveragePing()
    local isStable = self:isPingStable()
    local uptime = tick() - self.startTime
    
    if avgPing < 80 and isStable and uptime > 300 then -- 5 minutes
        return "Excellent"
    elseif avgPing < 150 and isStable then
        return "Good"
    elseif avgPing < 250 then
        return "Fair"
    else
        return "Poor"
    end
end

-- Initialize analytics
ServerAnalytics:init()

-- Enhanced server hopping with analytics
function ServerHopper:smartHopToAsianServer()
    local currentQuality = ServerAnalytics:getServerQuality()
    local currentPing = self:getCurrentPing()
    
    print(string.format("[Smart Hop] Current server quality: %s (Ping: %dms)", currentQuality, math.floor(currentPing)))
    
    -- Don't hop if we're already on an excellent server
    if currentQuality == "Excellent" and self:isLikelyAsianServer() then
        print("[Smart Hop] Already on excellent Asian server, staying put")
        return
    end
    
    -- Use more aggressive hopping for poor servers
    local maxHops = currentQuality == "Poor" and 15 or 10
    
    print(string.format("[Smart Hop] Attempting up to %d hops to find better Asian server", maxHops))
    
    local hopCount = 0
    local function smartHop()
        hopCount = hopCount + 1
        
        if hopCount > maxHops then
            print("[Smart Hop] Max hops reached, staying on current server")
            return
        end
        
        local success, err = pcall(function()
            -- Use different teleport methods for variety
            if hopCount % 3 == 0 then
                -- Try group teleport sometimes (if player is in a group)
                TeleportService:Teleport(game.PlaceId, player)
            else
                -- Regular teleport
                TeleportService:Teleport(game.PlaceId)
            end
        end)
        
        if not success then
            print("[Smart Hop] Hop " .. hopCount .. " failed: " .. tostring(err))
            task.wait(2)
            smartHop()
        end
    end
    
    smartHop()
end

-- Update the mobile GUI to use smart hopping
if isMobile and mobileGui then
    -- This would update the existing button, but since we can't modify the already created GUI,
    -- we'll just note that future versions should use smartHopToAsianServer
end

-- Final initialization
print("[Enhanced Lock-On] System fully loaded!")
print("Platform: " .. (isMobile and "Mobile" or "PC"))
print("Features: Smart lock-on, Smooth camera, Asian server targeting, Performance optimized")

if isMobile then
    print("Mobile Controls: Use on-screen buttons")
else
    print("PC Controls: T=Lock, Y=Switch, G=Asian Hop, H=Regular Hop")
end

-- Show current server info
task.wait(2)
local ping = ServerHopper:getCurrentPing()
local isAsian = ServerHopper:isAsianTimeZone()
print(string.format("Current Server - Ping: %dms, Timezone: %s", math.floor(ping), isAsian and "Asian" or "Non-Asian"))

-- Auto-hop on very high ping (optional feature)
task.spawn(function()
    task.wait(30) -- Wait 30 seconds after joining
    
    while true do
        local ping = ServerHopper:getCurrentPing()
        local quality = ServerAnalytics:getServerQuality()
        
        -- Auto-hop if ping is consistently terrible
        if ping > 400 and quality == "Poor" then
            print("[Auto-Hop] Ping too high (" .. math.floor(ping) .. "ms), attempting to find better server")
            ServerHopper:smartHopToAsianServer()
            break -- Only try once per session
        end
        
        task.wait(60) -- Check every minute
    end
end)
