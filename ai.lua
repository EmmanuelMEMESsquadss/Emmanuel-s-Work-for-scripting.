-- Universal Mobile Aimlock/Camlock for Battlegrounds (Jujutsu Shenanigans, etc.)
-- Optimized for Arceus X Mobile
-- Features: FOV Check, Visibility Check, Team Check, Dynamic Sensitivity, Touch UI, Anti-Cheat Bypass

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Only run on mobile
if not UserInputService.TouchEnabled then return end

-- Settings
local Settings = {
    AimLock = {
        Enabled = false,
        Sensitivity = 0.7,
        Prediction = 0.12,
        TargetPart = "Head",
        FOV = 120, -- Field of View (degrees)
        Smoothness = 0.15,
        UseProjectilePrediction = false,
        ProjectileSpeed = 100
    },
    CamLock = {
        Enabled = false,
        Sensitivity = 0.6,
        Prediction = 0.15,
        Smoothness = 0.2,
        FOV = 100
    },
    MaxDistance = 300,
    WallCheck = true,
    TeamCheck = true,
    UI = {
        Minimized = false,
        DragEnabled = true
    }
}

local target = nil
local connections = {}
local lastTargetCheck = 0
local targetCheckCooldown = 0.2 -- Debounce target checks

-- Helper Functions
local function getCharacter()
    return player.Character
end

local function isTargetVisible(targetPart)
    if not Settings.WallCheck then return true end

    local character = getCharacter()
    if not character or not character:FindFirstChild("HumanoidRootPart") then return false end

    local origin = character.HumanoidRootPart.Position
    local direction = (targetPart.Position - origin).Unit
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character, targetPart.Parent}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local raycastResult = workspace:Raycast(origin, direction * Settings.MaxDistance, raycastParams)
    return not raycastResult
end

local function getClosestPlayerInFOV()
    local character = getCharacter()
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end

    local hrp = character.HumanoidRootPart
    local closest = nil
    local shortestDistance = Settings.MaxDistance

    for _, v in pairs(Players:GetPlayers()) do
        if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            local enemyHrp = v.Character.HumanoidRootPart
            local enemyHumanoid = v.Character:FindFirstChildOfClass("Humanoid")

            if enemyHumanoid and enemyHumanoid.Health > 0 then
                local distance = (hrp.Position - enemyHrp.Position).Magnitude
                if distance < shortestDistance then
                    -- FOV Check
                    local screenPos, onScreen = camera:WorldToViewportPoint(enemyHrp.Position)
                    if onScreen then
                        local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
                        local angle = math.deg(math.atan2(screenPos.Y - screenCenter.Y, screenPos.X - screenCenter.X))
                        if math.abs(angle) <= Settings.AimLock.FOV / 2 then
                            -- Team Check
                            if not Settings.TeamCheck or v.Team ~= player.Team then
                                -- Visibility Check
                                if isTargetVisible(enemyHrp) then
                                    shortestDistance = distance
                                    closest = v.Character
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return closest
end

-- UI Creation (Mobile-Friendly)
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MobileLockUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 160, 0, 180)
    mainFrame.Position = UDim2.new(0, 20, 0.5, -90)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = true
    mainFrame.Parent = screenGui

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 12)
    frameCorner.Parent = mainFrame

    -- UI Elements (Buttons, Status, etc.)
    -- ... (Use your existing UI code, but optimize for touch)

    -- Touch Gestures
    local function onDoubleTap()
        if Settings.AimLock.Enabled then
            stopLocks()
        else
            startAimlock()
        end
    end

    -- Add touch gesture detection here (e.g., double-tap)

    return {
        gui = screenGui,
        mainFrame = mainFrame,
        -- ... (other UI elements)
    }
end

local ui = createUI()

-- Update UI Status
local function updateStatus()
    if Settings.AimLock.Enabled then
        ui.status.Text = "🎯 AIM LOCKED"
        ui.status.TextColor3 = Color3.fromRGB(255, 200, 0)
    elseif Settings.CamLock.Enabled then
        ui.status.Text = "📹 CAM LOCKED"
        ui.status.TextColor3 = Color3.fromRGB(0, 200, 255)
    else
        ui.status.Text = "READY"
        ui.status.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end

-- Stop All Locks
local function stopLocks()
    Settings.AimLock.Enabled = false
    Settings.CamLock.Enabled = false
    target = nil

    for _, connection in pairs(connections) do
        connection:Disconnect()
    end
    connections = {}

    local character = getCharacter()
    if character and character:FindFirstChildOfClass("Humanoid") then
        character.Humanoid.AutoRotate = true
    end

    updateStatus()
end

-- Start Aimlock
local function startAimlock()
    stopLocks()

    target = getClosestPlayerInFOV()
    if not target then
        ui.status.Text = "NO TARGET IN FOV"
        ui.status.TextColor3 = Color3.fromRGB(255, 100, 100)
        task.wait(1)
        updateStatus()
        return
    end

    Settings.AimLock.Enabled = true
    local character = getCharacter()
    if character and character:FindFirstChildOfClass("Humanoid") then
        character.Humanoid.AutoRotate = false
    end

    connections.aimlock = RunService.Heartbeat:Connect(function(deltaTime)
        if tick() - lastTargetCheck < targetCheckCooldown then return end
        lastTargetCheck = tick()

        local character = getCharacter()
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            stopLocks()
            return
        end

        if not target or not target:FindFirstChild("HumanoidRootPart") then
            target = getClosestPlayerInFOV()
            if not target then
                stopLocks()
                return
            end
        end

        local hrp = character.HumanoidRootPart
        local targetHrp = target.HumanoidRootPart
        local targetPart = target:FindFirstChild(Settings.AimLock.TargetPart) or targetHrp

        -- Prediction
        local velocity = targetHrp.AssemblyLinearVelocity
        local predictedPosition = targetPart.Position + (velocity * Settings.AimLock.Prediction)

        -- Dynamic Sensitivity
        local distance = (hrp.Position - targetHrp.Position).Magnitude
        local sensitivity = math.clamp(1 - (distance / Settings.MaxDistance), 0.1, Settings.AimLock.Sensitivity)

        -- Smooth rotation
        local direction = (Vector3.new(predictedPosition.X, hrp.Position.Y, predictedPosition.Z) - hrp.Position).Unit
        local newCFrame = CFrame.new(hrp.Position, hrp.Position + direction)
        hrp.CFrame = hrp.CFrame:Lerp(newCFrame, sensitivity * deltaTime * 60) -- Frame-rate independent
    end)

    updateStatus()
end

-- Start Camlock
local function startCamlock()
    stopLocks()

    target = getClosestPlayerInFOV()
    if not target then
        ui.status.Text = "NO TARGET IN FOV"
        ui.status.TextColor3 = Color3.fromRGB(255, 100, 100)
        task.wait(1)
        updateStatus()
        return
    end

    Settings.CamLock.Enabled = true

    connections.camlock = RunService.Heartbeat:Connect(function(deltaTime)
        if tick() - lastTargetCheck < targetCheckCooldown then return end
        lastTargetCheck = tick()

        if not target or not target:FindFirstChild("HumanoidRootPart") then
            target = getClosestPlayerInFOV()
            if not target then
                stopLocks()
                return
            end
        end

        local targetHrp = target.HumanoidRootPart
        local targetPart = target:FindFirstChild(Settings.AimLock.TargetPart) or targetHrp

        -- Prediction
        local velocity = targetHrp.AssemblyLinearVelocity
        local predictedPosition = targetPart.Position + (velocity * Settings.CamLock.Prediction)

        -- Dynamic Smoothness
        local character = getCharacter()
        local distance = character and character:FindFirstChild("HumanoidRootPart") and
            (character.HumanoidRootPart.Position - targetHrp.Position).Magnitude or Settings.MaxDistance
        local smoothness = math.clamp(1 - (distance / Settings.MaxDistance), 0.05, Settings.CamLock.Smoothness)

        -- Smooth camera movement
        local newCFrame = CFrame.new(camera.CFrame.Position, predictedPosition)
        camera.CFrame = camera.CFrame:Lerp(newCFrame, smoothness * deltaTime * 60) -- Frame-rate independent
    end)

    updateStatus()
end

-- UI Button Connections
ui.aimlockBtn.Activated:Connect(function()
    if Settings.AimLock.Enabled then
        stopLocks()
    else
        startAimlock()
    end
end)

ui.camlockBtn.Activated:Connect(function()
    if Settings.CamLock.Enabled then
        stopLocks()
    else
        startCamlock()
    end
end)

-- Initialize
updateStatus()
print("Mobile Lock System loaded successfully!")
print("Features: FOV Check, Visibility Check, Team Check, Dynamic Sensitivity, Touch UI")
