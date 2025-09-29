-- LocalScript (StarterPlayerScripts)
-- WORKING Mobile Aimbot/Camlock with Minimizable UI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Only run on mobile
if not UserInputService.TouchEnabled then
    return
end

-- Settings
local Settings = {
    AimLock = {
        Enabled = false,
        Sensitivity = 0.8,
        Prediction = 0.15,
        TargetPart = "Head"
    },
    CamLock = {
        Enabled = false,
        Sensitivity = 0.7,
        Prediction = 0.18,
        Smoothness = 0.25
    },
    MaxDistance = 200,
    WallCheck = false,
    TeamCheck = false
}

local target = nil
local connections = {}

-- Target functions
local function getCharacter()
    return player.Character
end

local function getClosestPlayer()
    local character = getCharacter()
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

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
                    if not Settings.TeamCheck or v.Team ~= player.Team then
                        shortestDistance = distance
                        closest = v.Character
                    end
                end
            end
        end
    end

    return closest
end

-- Create the minimizable UI
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MobileLockUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    -- Small circular button (minimized state)
    local miniButton = Instance.new("TextButton")
    miniButton.Name = "MiniButton"
    miniButton.Size = UDim2.new(0, 50, 0, 50)
    miniButton.Position = UDim2.new(0, 20, 0.5, -25)
    miniButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    miniButton.BorderSizePixel = 0
    miniButton.Text = "🎯"
    miniButton.TextColor3 = Color3.new(1, 1, 1)
    miniButton.TextSize = 20
    miniButton.Font = Enum.Font.GothamBold
    miniButton.Visible = false
    miniButton.Parent = screenGui

    local miniCorner = Instance.new("UICorner")
    miniCorner.CornerRadius = UDim.new(0.5, 0)
    miniCorner.Parent = miniButton

    local miniStroke = Instance.new("UIStroke")
    miniStroke.Color = Color3.fromRGB(100, 100, 100)
    miniStroke.Thickness = 2
    miniStroke.Parent = miniButton

    -- Main frame (expanded state)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 150, 0, 180)
    mainFrame.Position = UDim2.new(0, 20, 0.5, -90)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = true
    mainFrame.Parent = screenGui

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 12)
    frameCorner.Parent = mainFrame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(80, 80, 80)
    frameStroke.Thickness = 1
    frameStroke.Parent = mainFrame

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 35)
    header.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header

    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0.5, 0)
    headerFix.Position = UDim2.new(0, 0, 0.5, 0)
    headerFix.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 1, 0)
    title.Position = UDim2.new(0, 5, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "LOCK"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 25, 0, 25)
    minimizeBtn.Position = UDim2.new(1, -30, 0, 5)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.new(1, 1, 1)
    minimizeBtn.TextSize = 16
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.Parent = header

    local minimizeBtnCorner = Instance.new("UICorner")
    minimizeBtnCorner.CornerRadius = UDim.new(0.5, 0)
    minimizeBtnCorner.Parent = minimizeBtn

    -- Status
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -10, 0, 20)
    status.Position = UDim2.new(0, 5, 0, 40)
    status.BackgroundTransparency = 1
    status.Text = "READY"
    status.TextColor3 = Color3.fromRGB(100, 255, 100)
    status.TextSize = 12
    status.Font = Enum.Font.Gotham
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.Parent = mainFrame

    -- Aimlock button
    local aimlockBtn = Instance.new("TextButton")
    aimlockBtn.Size = UDim2.new(1, -10, 0, 40)
    aimlockBtn.Position = UDim2.new(0, 5, 0, 65)
    aimlockBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    aimlockBtn.BorderSizePixel = 0
    aimlockBtn.Text = "AIMLOCK"
    aimlockBtn.TextColor3 = Color3.new(1, 1, 1)
    aimlockBtn.TextSize = 14
    aimlockBtn.Font = Enum.Font.GothamBold
    aimlockBtn.Parent = mainFrame

    local aimlockCorner = Instance.new("UICorner")
    aimlockCorner.CornerRadius = UDim.new(0, 8)
    aimlockCorner.Parent = aimlockBtn

    -- Camlock button
    local camlockBtn = Instance.new("TextButton")
    camlockBtn.Size = UDim2.new(1, -10, 0, 40)
    camlockBtn.Position = UDim2.new(0, 5, 0, 110)
    camlockBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    camlockBtn.BorderSizePixel = 0
    camlockBtn.Text = "CAMLOCK"
    camlockBtn.TextColor3 = Color3.new(1, 1, 1)
    camlockBtn.TextSize = 14
    camlockBtn.Font = Enum.Font.GothamBold
    camlockBtn.Parent = mainFrame

    local camlockCorner = Instance.new("UICorner")
    camlockCorner.CornerRadius = UDim.new(0, 8)
    camlockCorner.Parent = camlockBtn

    -- Minimize/Maximize functionality
    local isMinimized = false

    local function minimize()
        if isMinimized then return end
        isMinimized = true
        
        local shrinkTween = TweenService:Create(
            mainFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            {Size = UDim2.new(0, 0, 0, 0)}
        )
        
        shrinkTween:Play()
        shrinkTween.Completed:Wait()
        
        mainFrame.Visible = false
        miniButton.Visible = true
        miniButton.Size = UDim2.new(0, 0, 0, 0)
        
        local growTween = TweenService:Create(
            miniButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 50, 0, 50)}
        )
        
        growTween:Play()
    end

    local function maximize()
        if not isMinimized then return end
        isMinimized = false
        
        local shrinkTween = TweenService:Create(
            miniButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            {Size = UDim2.new(0, 0, 0, 0)}
        )
        
        shrinkTween:Play()
        shrinkTween.Completed:Wait()
        
        miniButton.Visible = false
        mainFrame.Visible = true
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        
        local growTween = TweenService:Create(
            mainFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 150, 0, 180)}
        )
        
        growTween:Play()
    end

    minimizeBtn.Activated:Connect(minimize)
    miniButton.Activated:Connect(maximize)

    return {
        gui = screenGui,
        mainFrame = mainFrame,
        miniButton = miniButton,
        status = status,
        aimlockBtn = aimlockBtn,
        camlockBtn = camlockBtn
    }
end

local ui = createUI()

-- Update UI status
local function updateStatus()
    if Settings.AimLock.Enabled then
        ui.status.Text = "🎯 AIM LOCKED"
        ui.status.TextColor3 = Color3.fromRGB(255, 200, 0)
        ui.aimlockBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
        ui.camlockBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    elseif Settings.CamLock.Enabled then
        ui.status.Text = "📹 CAM LOCKED"
        ui.status.TextColor3 = Color3.fromRGB(0, 200, 255)
        ui.camlockBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        ui.aimlockBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    else
        ui.status.Text = "READY"
        ui.status.TextColor3 = Color3.fromRGB(100, 255, 100)
        ui.aimlockBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        ui.camlockBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
end

-- Stop all locks
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

-- Start aimlock
local function startAimlock()
    stopLocks()
    
    target = getClosestPlayer()
    if not target then
        ui.status.Text = "NO TARGET"
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

    connections.aimlock = RunService.RenderStepped:Connect(function()
        local character = getCharacter()
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            stopLocks()
            return
        end

        if not target or not target:FindFirstChild("HumanoidRootPart") then
            target = getClosestPlayer()
            if not target then
                stopLocks()
                return
            end
        end

        local hrp = character.HumanoidRootPart
        local targetHrp = target.HumanoidRootPart
        local targetPart = target:FindFirstChild(Settings.AimLock.TargetPart) or targetHrp

        -- Calculate prediction
        local velocity = targetHrp.AssemblyLinearVelocity
        local predictedPosition = targetPart.Position + (velocity * Settings.AimLock.Prediction)

        -- Fast, responsive rotation
        local direction = (Vector3.new(predictedPosition.X, hrp.Position.Y, predictedPosition.Z) - hrp.Position).Unit
        local newCFrame = CFrame.new(hrp.Position, hrp.Position + direction)
        
        -- Much faster lock-on with instant snap for close targets
        local distance = (hrp.Position - targetHrp.Position).Magnitude
        local sensitivity = distance < 50 and 1 or Settings.AimLock.Sensitivity
        
        hrp.CFrame = hrp.CFrame:Lerp(newCFrame, sensitivity)
    end)

    updateStatus()
end

-- Start camlock
local function startCamlock()
    stopLocks()
    
    target = getClosestPlayer()
    if not target then
        ui.status.Text = "NO TARGET"
        ui.status.TextColor3 = Color3.fromRGB(255, 100, 100)
        task.wait(1)
        updateStatus()
        return
    end

    Settings.CamLock.Enabled = true

    connections.camlock = RunService.RenderStepped:Connect(function()
        if not target or not target:FindFirstChild("HumanoidRootPart") then
            target = getClosestPlayer()
            if not target then
                stopLocks()
                return
            end
        end

        local targetHrp = target.HumanoidRootPart
        local targetPart = target:FindFirstChild(Settings.AimLock.TargetPart) or targetHrp

        -- Calculate prediction
        local velocity = targetHrp.AssemblyLinearVelocity
        local predictedPosition = targetPart.Position + (velocity * Settings.CamLock.Prediction)

        -- Fast, responsive camera movement
        local newCFrame = CFrame.new(camera.CFrame.Position, predictedPosition)
        
        -- Distance-based sensitivity for instant snap on close targets
        local character = getCharacter()
        if character and character:FindFirstChild("HumanoidRootPart") then
            local distance = (character.HumanoidRootPart.Position - targetHrp.Position).Magnitude
            local smoothness = distance < 50 and 1 or Settings.CamLock.Smoothness
            camera.CFrame = camera.CFrame:Lerp(newCFrame, smoothness)
        else
            camera.CFrame = camera.CFrame:Lerp(newCFrame, Settings.CamLock.Smoothness)
        end
    end)

    updateStatus()
end

-- Button connections
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

-- Make UI draggable
local dragging = false
local dragInput, mousePos, framePos

local function updateDrag(input)
    local delta = input.Position - mousePos
    ui.mainFrame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
end

ui.mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        mousePos = input.Position
        framePos = ui.mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch and dragging then
        updateDrag(input)
    end
end)

-- Initialize
updateStatus()

print("Mobile Lock System loaded successfully!")
print("Features: Minimizable UI, Working Aimlock, Working Camlock")
