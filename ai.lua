-- LocalScript (StarterPlayerScripts)
-- Mobile Lock-On (PlayStation-style) with grab/ragdoll detection

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Only run on mobile
if not UserInputService.TouchEnabled then
    return
end

local player = Players.LocalPlayer
local character, humanoid, hrp
local isDisabled = false

-- Constraint / weld detection variables
local constraintWatchConnections = {}

local function clearConstraintWatches()
    for _, conn in ipairs(constraintWatchConnections) do
        conn:Disconnect()
    end
    constraintWatchConnections = {}
end

local function watchConstraintsOn(part)
    if not part then return end
    -- watch additions
    local connA = part.ChildAdded:Connect(function(child)
        if child:IsA("Weld") or child:IsA("WeldConstraint")
           or child:IsA("AlignPosition") or child:IsA("AlignOrientation")
           or child:IsA("RodConstraint") or child:IsA("BallSocketConstraint")
           or child:IsA("HingeConstraint") or child:IsA("Motor6D") then
            isDisabled = true
            -- watch removal
            local connRem = child.AncestryChanged:Connect(function(_, parent)
                if not child:IsDescendantOf(game) then
                    task.delay(0.2, function()
                        isDisabled = false
                    end)
                    connRem:Disconnect()
                end
            end)
            table.insert(constraintWatchConnections, connRem)
        end
    end)
    table.insert(constraintWatchConnections, connA)
    -- watch anchored
    if part:IsA("BasePart") then
        local connAnch = part:GetPropertyChangedSignal("Anchored"):Connect(function()
            if part.Anchored then
                isDisabled = true
            else
                task.delay(0.2, function()
                    if not part.Anchored then
                        isDisabled = false
                    end
                end)
            end
        end)
        table.insert(constraintWatchConnections, connAnch)
    end
end

local function setupCharacter(char)
    clearConstraintWatches()
    character = char
    humanoid = char:WaitForChild("Humanoid")
    hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
    isDisabled = false

    if humanoid then
        humanoid.AutoRotate = true
        humanoid.StateChanged:Connect(function(old, new)
            if new == Enum.HumanoidStateType.Physics
               or new == Enum.HumanoidStateType.Ragdoll
               or new == Enum.HumanoidStateType.FallingDown
               or new == Enum.HumanoidStateType.PlatformStanding
               or new == Enum.HumanoidStateType.Dead then
                isDisabled = true
            elseif new == Enum.HumanoidStateType.Running
               or new == Enum.HumanoidStateType.Landed
               or new == Enum.HumanoidStateType.Jumping
               or new == Enum.HumanoidStateType.Freefall
               or new == Enum.HumanoidStateType.GettingUp then
                if not humanoid.PlatformStand and not humanoid.Sit then
                    isDisabled = false
                end
            end
        end)

        humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
            if humanoid.PlatformStand then
                isDisabled = true
            else
                task.delay(0.1, function()
                    if not humanoid.PlatformStand then
                        isDisabled = false
                    end
                end)
            end
        end)

        humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
            if humanoid.Sit then
                isDisabled = true
            else
                task.delay(0.1, function()
                    if not humanoid.PlatformStand then
                        isDisabled = false
                    end
                end)
            end
        end)
    end

    if hrp then
        watchConstraintsOn(hrp)
    end
end

if player.Character then
    setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

-- GUI setup (your button)
local gui = Instance.new("ScreenGui")
gui.Name = "LockOnUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 110, 0, 50)
btn.Position = UDim2.new(0.06, 0, 0.8, 0)
btn.Text = "LOCK"
btn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
btn.TextColor3 = Color3.new(1,1,1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 20
btn.Active = true
btn.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0,8)
corner.Parent = btn

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0,8,0,8)
statusDot.Position = UDim2.new(1, -12, 0, 4)
statusDot.BackgroundColor3 = Color3.fromRGB(100,255,100)
statusDot.BorderSizePixel = 0
statusDot.Parent = btn

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(0.5,0)
dotCorner.Parent = statusDot

-- Draggable button
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
    local delta = input.Position - dragStart
    btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                             startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = btn.Position
        dragInput = input
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        updateDrag(input)
    end
end)

-- Target lock logic
local MAX_DIST = 100
local lockTarget = nil
local lockBillboard = nil

local function detachBillboard()
    if lockBillboard then
        lockBillboard:Destroy()
        lockBillboard = nil
    end
end

local function attachBillboard(model)
    detachBillboard()
    local targetHrp = model:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0,120,0,40)
    bb.StudsOffset = Vector3.new(0,3.2,0)
    bb.AlwaysOnTop = true
    bb.Parent = targetHrp
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = "LOCKED"
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255,80,80)
    label.Parent = bb
    lockBillboard = bb
end

local function isValidTarget(model)
    if not model or not model:IsA("Model") then return false end
    local hum = model:FindFirstChildWhichIsA("Humanoid")
    local part = model:FindFirstChild("HumanoidRootPart")
    if not hum or not part or hum.Health <= 0 then return false end
    if model == character then return false end
    if Players:GetPlayerFromCharacter(model) == player then return false end
    return true
end

local function getNearestTarget()
    if not hrp then return nil end
    local nearest, dist = nil, MAX_DIST
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= player and pl.Character and isValidTarget(pl.Character) then
            local ok, part = pcall(function() return pl.Character.HumanoidRootPart end)
            if ok and part then
                local d = (hrp.Position - part.Position).Magnitude
                if d < dist then
                    dist = d
                    nearest = pl.Character
                end
            end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and isValidTarget(obj) and not Players:GetPlayerFromCharacter(obj) then
            local targetHrp = obj:FindFirstChild("HumanoidRootPart")
            if targetHrp then
                local d = (hrp.Position - targetHrp.Position).Magnitude
                if d < dist then
                    dist = d
                    nearest = obj
                end
            end
        end
    end
    return nearest
end

-- PlayStation-style lock parameters
local orbitDistance = 8
local orbitHeight = 2.5
local orbitSpeed = 2.5

local freeCamera = true

local function enterLockMode(target)
    lockTarget = target
    freeCamera = false
    if humanoid then humanoid.AutoRotate = false end
    attachBillboard(target)
    btn.Text = "UNLOCK"
    btn.BackgroundColor3 = Color3.fromRGB(206,36,36)
end

local function exitLockMode()
    lockTarget = nil
    freeCamera = true
    if humanoid then humanoid.AutoRotate = true end
    detachBillboard()
    btn.Text = "LOCK"
    btn.BackgroundColor3 = Color3.fromRGB(36,137,206)
    -- optionally reset camera type if you changed it
    local cam = workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Custom
end

btn.Activated:Connect(function()
    if lockTarget then
        exitLockMode()
    else
        local t = getNearestTarget()
        if t then
            enterLockMode(t)
        else
            btn.Text = "NO TARGET"
            task.delay(1, function()
                if not lockTarget then
                    btn.Text = "LOCK"
                end
            end)
        end
    end
end)

-- Status dot update
spawn(function()
    while true do
        task.wait(0.1)
        if isDisabled then
            statusDot.BackgroundColor3 = Color3.fromRGB(255,80,80)
        else
            statusDot.BackgroundColor3 = Color3.fromRGB(100,255,100)
        end
    end
end)

-- Camera & movement loop
local camera = workspace.CurrentCamera
RunService.RenderStepped:Connect(function(dt)
    camera = workspace.CurrentCamera
    if not character or not humanoid or not hrp or humanoid.Health <= 0 then
        return
    end

    if lockTarget and not isDisabled then
        local targetHrp = lockTarget:FindFirstChild("HumanoidRootPart")
        local targetHum = lockTarget:FindFirstChildWhichIsA("Humanoid")
        if not targetHrp or not targetHum or targetHum.Health <= 0 then
            exitLockMode()
            return
        end

        -- Ensure within max distance
        if (hrp.Position - targetHrp.Position).Magnitude > MAX_DIST then
            exitLockMode()
            return
        end

        -- Player orientation: face the target
        local lookPos = Vector3.new(targetHrp.Position.X, hrp.Position.Y, targetHrp.Position.Z)
        hrp.CFrame = CFrame.new(hrp.Position, lookPos)

        -- Camera position: behind the player, orbit logic
        local backDir = hrp.CFrame.LookVector * -orbitDistance
        local desiredCamPos = hrp.Position + backDir + Vector3.new(0, orbitHeight, 0)
        local camLookAt = targetHrp.Position
        camera.CFrame = CFrame.new(desiredCamPos, camLookAt)

        -- Optionally: allow orbit via joystick/touch sideways movement
        local moveDir = humanoid.MoveDirection -- relative to world
        if moveDir.Magnitude > 0 then
            -- apply small orbit rotation around target
            local horizontal = Vector3.new(moveDir.X,0,moveDir.Z).Unit
            if horizontal.Magnitude > 0 then
                local sign = math.sign(hrp.CFrame.LookVector:Dot(horizontal))
                local angle = sign * orbitSpeed * dt
                -- rotate hrp around target
                local radiusVec = hrp.Position - targetHrp.Position
                local newPos = targetHrp.Position + (radiusVec * CFrame.Angles(0, angle, 0)).p
                hrp.CFrame = CFrame.new(newPos, Vector3.new(targetHrp.Position.X, newPos.Y, targetHrp.Position.Z))
            end
        end

    elseif freeCamera then
        -- Do nothing special – normal free camera / player control
    end
end)

print("Mobile PS-Style Lock-On System loaded!")
