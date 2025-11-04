-- MobileLockOn_Improved.lua
-- Full improved aim-lock with robust grab/weld/camera recovery handling
-- Paste into StarterPlayerScripts (LocalScript)
--
-- Key features:
--  - Robust grab/constraint detection (Weld, WeldConstraint, Motor6D, Align*, Rod, Hinge, BallSocket, attachments)
--  - Camera-safe rotation: don't fight Scriptable cameras or when CameraSubject != your Humanoid
--  - Camera recovery: restore CameraSubject + CameraType gracefully after a grab/finisher
--  - Optional AlignOrientation fallback to let physics orient the body instead of teleporting HRP each frame
--  - Predictive aiming option and smoothing
--  - Detailed debug logging (toggleable)
--
-- Important: use this only as an admin tool in your own places. Don't use to interfere with other people's games.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ONLY RUN ON CLIENT MOBILE (as original)
if not UserInputService.TouchEnabled then
    -- If you want to test in Studio with keyboard, set this true for dev testing:
    -- return
end

-- ==========================
-- Config (tweak as needed)
-- ==========================
local CONFIG = {
    MAX_DIST = 100,
    CAMERA_SMOOTH = true,
    CAMERA_SMOOTH_ALPHA = 0.6, -- lerp factor per frame for camera
    AIM_PREDICTION = true,
    PREDICTION_FACTOR = 0.125, -- seconds to lead
    USE_ALIGN_ORIENTATION = true, -- if true, creates an AlignOrientation when locking to avoid HRP teleporting
    ALIGN_MAX_TORQUE = 500000, -- AlignOrientation setting
    ALIGN_RESPONSIVENESS = 50, -- AlignOrientation responsiveness
    GRAB_DEBOUNCE_AFTER_REMOVAL = 0.25,
    CAMERA_RESTORE_DELAY = 0.45, -- seconds to wait after grab ends before forcing camera back
    LOGGING = false, -- set true for verbose logs in Studio
}

local function log(...)
    if CONFIG.LOGGING then
        print("[LockOnImproved]", ...)
    end
end

-- ==========================
-- State
-- ==========================
local character, humanoid, hrp
local isDisabled = false -- set when grabbed/ragdoll/constraints/etc
local lockTarget = nil
local lockBillboard = nil
local alignOrientation = nil -- optional physics align used while locked
local usingAlign = false
local camera = workspace.CurrentCamera
local camResetting = false
local lastConstraintTick = 0
local constraintConnections = {} -- holds connections to constraints we watch
local watchedParts = {} -- parts we are currently watching (keyed by instance)
local debugHistory = {} -- circular log for diagnostics (small)

-- Keep a set of constraint types that we'll consider "grab-like"
local constraintClassWhitelist = {
    ["Weld"] = true,
    ["WeldConstraint"] = true,
    ["Motor6D"] = true,
    ["AlignPosition"] = true,
    ["AlignOrientation"] = true,
    ["RodConstraint"] = true,
    ["BallSocketConstraint"] = true,
    ["HingeConstraint"] = true,
    ["Attachment"] = true,
    ["SpringConstraint"] = true,
    ["RopeConstraint"] = true,
}

-- Utility: safe pcall wrapper
local function safe(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        log("Error in safe pcall:", a)
        return nil
    end
    return a, b, c
end

-- ==========================
-- Setup character references and detection
-- ==========================
local function clearConstraintWatches()
    for _, conn in ipairs(constraintConnections) do
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        elseif conn and conn.disconnect then
            pcall(function() conn:disconnect() end)
        end
    end
    constraintConnections = {}
    watchedParts = {}
end

local function markConstraintRemoval()
    lastConstraintTick = tick()
    task.delay(CONFIG.GRAB_DEBOUNCE_AFTER_REMOVAL, function()
        if tick() - lastConstraintTick >= CONFIG.GRAB_DEBOUNCE_AFTER_REMOVAL then
            isDisabled = false
        end
    end)
end

-- Watch a BasePart for children added/removed + Anchored changes
local function watchPartForConstraints(part)
    if not part or watchedParts[part] then return end
    watchedParts[part] = true

    -- ChildAdded
    local connA = part.ChildAdded:Connect(function(child)
        if child and constraintClassWhitelist[child.ClassName] then
            log("Constraint added on HRP:", child.ClassName)
            isDisabled = true
            -- watch removal via AncestryChanged (some constraints are reparented/destroyed)
            local aconn
            aconn = child.AncestryChanged:Connect(function(_, parent)
                if not child:IsDescendantOf(game) then
                    log("Constraint removed (AncestryChanged):", child.ClassName)
                    markConstraintRemoval()
                    if aconn then aconn:Disconnect() end
                end
            end)
            table.insert(constraintConnections, aconn)
        end
    end)
    table.insert(constraintConnections, connA)

    -- ChildRemoved (in case removal triggers immediately)
    local connR = part.ChildRemoved:Connect(function(child)
        if child and constraintClassWhitelist[child.ClassName] then
            log("Constraint removed (ChildRemoved):", child.ClassName)
            markConstraintRemoval()
        end
    end)
    table.insert(constraintConnections, connR)

    -- Property change: Anchored
    if part:IsA("BasePart") then
        local connAnch = part:GetPropertyChangedSignal("Anchored"):Connect(function()
            if part.Anchored then
                log("HRP became Anchored")
                isDisabled = true
            else
                log("HRP un-anchored, scheduling re-enable")
                markConstraintRemoval()
            end
        end)
        table.insert(constraintConnections, connAnch)
    end
end

-- Also watch entire character descendants for Motor6D welds that may connect to other models
local function watchCharacterForMotor6D(c)
    if not c then return end
    for _, desc in ipairs(c:GetDescendants()) do
        if desc and desc:IsA("Motor6D") then
            -- if Motor6D's Part0/Part1 point to other characters / non-ancestor parts, treat as grab
            local conn = desc.AncestryChanged:Connect(function()
                -- quick detection: if Motor6D parent changes or if the motor connects to some external part
                if desc.Part1 and not desc.Part1:IsDescendantOf(c) then
                    log("Motor6D connected external:", desc.Name)
                    isDisabled = true
                end
            end)
            table.insert(constraintConnections, conn)
        end
    end
end

local function setupCharacter(char)
    clearConstraintWatches()
    character = char
    humanoid = safe(function() return char:WaitForChild("Humanoid", 5) end)
    hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
    isDisabled = false
    usingAlign = false

    if humanoid then
        -- Ensure AutoRotate is true by default
        humanoid.AutoRotate = true

        -- Watch important humanoid signals
        local sc = humanoid.StateChanged:Connect(function(oldState, newState)
            log("Humanoid state changed:", oldState.Name, "->", newState.Name)
            -- treat ragdoll and similar as disabled
            if newState == Enum.HumanoidStateType.Physics or
               newState == Enum.HumanoidStateType.Ragdoll or
               newState == Enum.HumanoidStateType.FallingDown or
               newState == Enum.HumanoidStateType.PlatformStanding or
               newState == Enum.HumanoidStateType.Dead then
                isDisabled = true
            elseif newState == Enum.HumanoidStateType.Running or
                   newState == Enum.HumanoidStateType.Landed or
                   newState == Enum.HumanoidStateType.Jumping or
                   newState == Enum.HumanoidStateType.GettingUp or
                   newState == Enum.HumanoidStateType.Freefall then
                -- re-enable only if no constraints flagged
                task.delay(0.05, function()
                    if not humanoid.PlatformStand and not humanoid.Sit then
                        -- keep disabled if constraints were recently added
                        if tick() - lastConstraintTick > CONFIG.GRAB_DEBOUNCE_AFTER_REMOVAL then
                            isDisabled = false
                        end
                    end
                end)
            end
        end)
        table.insert(constraintConnections, sc)

        -- PlatformStand / Sit toggles
        local connPS = humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
            log("PlatformStand changed:", humanoid.PlatformStand)
            isDisabled = humanoid.PlatformStand or isDisabled
        end)
        table.insert(constraintConnections, connPS)

        local connSit = humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
            log("Sit changed:", humanoid.Sit)
            if humanoid.Sit then
                isDisabled = true
            else
                task.delay(0.05, function()
                    if not humanoid.PlatformStand then
                        isDisabled = false
                    end
                end)
            end
        end)
        table.insert(constraintConnections, connSit)
    end

    -- Watch HRP constraints and anchored
    if hrp then
        watchPartForConstraints(hrp)
    end

    -- Watch whole character for Motor6Ds hooking into external parts
    watchCharacterForMotor6D(char)
end

-- Character lifecycle
if player.Character then
    setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)
player.CharacterRemoving:Connect(function()
    clearConstraintWatches()
    character, humanoid, hrp = nil, nil, nil
    isDisabled = true
end)

-- ==========================
-- UI (kept similar to your original)
-- ==========================
local gui = Instance.new("ScreenGui")
gui.Name = "LockOnUI_Improved"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 110, 0, 50)
btn.Position = UDim2.new(0.06, 0, 0.8, 0)
btn.Text = "LOCK"
btn.BackgroundColor3 = Color3.fromRGB(36, 137, 206)
btn.TextColor3 = Color3.fromRGB(1,1,1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 20
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

-- Draggable button (unchanged)
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
    if dragging and input == dragInput then updateDrag(input) end
end)

-- ==========================
-- Lock target utilities
-- ==========================
local function detachBillboard()
    if lockBillboard then
        lockBillboard:Destroy()
        lockBillboard = nil
    end
end

local function attachBillboard(model)
    detachBillboard()
    if not model then return end
    local targetHrp = model:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 40)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = targetHrp
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "LOCKED"
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 80, 80)
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

-- Efficient nearest target scanning (caches players and workspace models periodically)
local cachedNonPlayerModels = {}
local lastCacheTick = 0
local CACHE_INTERVAL = 0.5

local function refreshModelCache()
    cachedNonPlayerModels = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and isValidTarget(obj) and not Players:GetPlayerFromCharacter(obj) then
            table.insert(cachedNonPlayerModels, obj)
        end
    end
    lastCacheTick = tick()
end

local function getNearestTarget()
    if not hrp then return nil end
    if tick() - lastCacheTick > CACHE_INTERVAL then refreshModelCache() end
    local nearest, bestDist = nil, CONFIG.MAX_DIST
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= player and pl.Character and isValidTarget(pl.Character) then
            local ok, targetPart = pcall(function() return pl.Character:FindFirstChild("HumanoidRootPart") end)
            if ok and targetPart then
                local d = (hrp.Position - targetPart.Position).Magnitude
                if d < bestDist then
                    nearest = pl.Character
                    bestDist = d
                end
            end
        end
    end
    for _, obj in ipairs(cachedNonPlayerModels) do
        if isValidTarget(obj) then
            local targetHrp = obj:FindFirstChild("HumanoidRootPart")
            if targetHrp then
                local d = (hrp.Position - targetHrp.Position).Magnitude
                if d < bestDist then
                    nearest = obj
                    bestDist = d
                end
            end
        end
    end
    return nearest
end

-- ==========================
-- AlignOrientation helper (physics friendly rotation)
-- ==========================
local function createAlignOrientation()
    if not hrp then return end
    if alignOrientation and alignOrientation.Parent then return end
    usingAlign = true
    alignOrientation = Instance.new("AlignOrientation")
    alignOrientation.Name = "LockAlignOrientation"
    alignOrientation.MaxTorque = CONFIG.ALIGN_MAX_TORQUE
    alignOrientation.Responsiveness = CONFIG.ALIGN_RESPONSIVENESS
    alignOrientation.RigidityEnabled = true
    local attachment0 = Instance.new("Attachment")
    attachment0.Name = "LockAttach0"
    attachment0.Parent = hrp
    local attachment1 = Instance.new("Attachment")
    attachment1.Name = "LockAttach1"
    attachment1.Parent = hrp
    alignOrientation.Attachment0 = attachment0
    alignOrientation.Attachment1 = attachment1
    alignOrientation.Parent = hrp
    -- Keep attachments at hrp origin; we'll set target orientation by moving attachment1 relative to world orientation
    attachment0.CFrame = CFrame.new()
    attachment1.CFrame = CFrame.new()
    log("Created AlignOrientation on HRP")
end

local function destroyAlignOrientation()
    if alignOrientation then
        pcall(function() alignOrientation:Destroy() end)
        alignOrientation = nil
    end
    -- Remove possible attachments
    if hrp then
        local a0 = hrp:FindFirstChild("LockAttach0")
        local a1 = hrp:FindFirstChild("LockAttach1")
        if a0 then a0:Destroy() end
        if a1 then a1:Destroy() end
    end
    usingAlign = false
    log("Destroyed AlignOrientation")
end

-- ==========================
-- Camera helpers
-- ==========================
local function cameraAllowsRotation()
    camera = workspace.CurrentCamera
    if not camera then return false end
    -- If camera is Scriptable or subject is not our humanoid, don't try to control HRP or camera aggressively
    if camera.CameraType ~= Enum.CameraType.Custom then
        -- some finishers set Scriptable - pause rotation until camera returns
        return false
    end
    if not humanoid then return false end
    local subject = camera.CameraSubject
    if not subject then return false end
    -- require subject to be our humanoid to be safe
    if subject ~= humanoid then
        return false
    end
    return true
end

local function restoreCameraToHumanoidAsync()
    if camResetting or not camera or not humanoid then return end
    camResetting = true
    task.spawn(function()
        task.wait(CONFIG.CAMERA_RESTORE_DELAY)
        if camera and humanoid and camera.CameraSubject ~= humanoid and camera.CameraType == Enum.CameraType.Custom then
            log("Restoring CameraSubject to humanoid")
            camera.CameraSubject = humanoid
            camera.CameraType = Enum.CameraType.Custom
        end
        camResetting = false
    end)
end

-- ==========================
-- Main rotation logic (safe)
-- ==========================
local lastSafeRotationTick = 0

-- Utility: raycast visibility check
local function targetVisible(targetModel)
    if not camera or not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return false end
    local targetPart = targetModel.HumanoidRootPart
    local origin = camera.CFrame.Position
    local dir = targetPart.Position - origin
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = workspace:Raycast(origin, dir, rayParams)
    if not result then
        return true
    end
    -- if ray hit part that is descendant of targetModel, consider visible
    if result.Instance and result.Instance:IsDescendantOf(targetModel) then
        return true
    end
    return false
end

-- Compute predicted position of target head/center
local function computeAimPosition(targetModel)
    local thrp = targetModel:FindFirstChild("HumanoidRootPart")
    if not thrp then return nil end
    local basePos = thrp.Position
    if CONFIG.AIM_PREDICTION and thrp.AssemblyLinearVelocity then
        local vel = thrp.AssemblyLinearVelocity
        local pred = basePos + vel * CONFIG.PREDICTION_FACTOR
        return pred
    end
    return basePos
end

-- Primary safe rotation loop (RenderStepped)
RunService.RenderStepped:Connect(function(dt)
    camera = workspace.CurrentCamera
    if not character or not humanoid or not hrp then return end

    -- Update status dot
    if isDisabled then
        statusDot.BackgroundColor3 = Color3.fromRGB(255,80,80)
    else
        statusDot.BackgroundColor3 = Color3.fromRGB(100,255,100)
    end

    -- If camera is not safe (scriptable / subject switched), do not rotate HRP or camera; just try to restore camera later
    if not cameraAllowsRotation() then
        lastSafeRotationTick = tick()
        -- attempt camera recovery only if we detect camera subject changed and we appear stable
        if not camResetting and (not humanoid.PlatformStand and not humanoid.Sit and not isDisabled) then
            restoreCameraToHumanoidAsync()
        end
        return
    end

    -- Skip rotation when grabbed or ragdolled
    if isDisabled or humanoid.PlatformStand or humanoid.Sit then
        lastSafeRotationTick = tick()
        return
    end

    -- If no lock target, nothing to do
    if not lockTarget then
        -- optionally maintain AlignOrientation destroyed
        if usingAlign then
            destroyAlignOrientation()
        end
        return
    end

    -- Validate target
    local targetHRP = lockTarget:FindFirstChild("HumanoidRootPart")
    local targetHum = lockTarget:FindFirstChildWhichIsA("Humanoid")
    if not targetHRP or not targetHum or targetHum.Health <= 0 then
        -- unlock gracefully
        log("Target invalid or dead; unlocking")
        lockTarget = nil
        detachBillboard()
        if usingAlign then destroyAlignOrientation() end
        return
    end

    -- distance check
    if (hrp.Position - targetHRP.Position).Magnitude > CONFIG.MAX_DIST then
        log("Target out of range; unlocking")
        lockTarget = nil
        detachBillboard()
        if usingAlign then destroyAlignOrientation() end
        return
    end

    -- target visibility check (optional)
    if not targetVisible(lockTarget) then
        -- if target behind wall, don't rotate (keeps lock but don't aim through walls)
        log("Target not visible; pausing rotation")
        return
    end

    -- compute aim position (prediction)
    local aimPos = computeAimPosition(lockTarget) or targetHRP.Position
    -- keep aimed at target at the same Y as HRP to avoid pitching weirdly
    local lookPos = Vector3.new(aimPos.X, hrp.Position.Y, aimPos.Z)

    -- preferred method: rotate camera to look at target (safe visual-only)
    if camera and camera.CameraType == Enum.CameraType.Custom and camera.CameraSubject == humanoid then
        local camPos = camera.CFrame.Position
        local desiredCamCF = CFrame.new(camPos, lookPos)
        if CONFIG.CAMERA_SMOOTH then
            camera.CFrame = camera.CFrame:Lerp(desiredCamCF, math.clamp(CONFIG.CAMERA_SMOOTH_ALPHA * dt * 60, 0, 1))
        else
            camera.CFrame = desiredCamCF
        end
    end

    -- If you must rotate the player body: prefer AlignOrientation to let physics handle it instead of teleporting HRP
    if CONFIG.USE_ALIGN_ORIENTATION then
        -- ensure align exists
        if not usingAlign then
            createAlignOrientation()
        end
        if alignOrientation and alignOrientation.Attachment1 then
            -- set Attachment1.TargetOrientation so orientation tends toward facing 'lookPos'
            -- compute desired rotation so hrp faces lookPos
            local desiredCf = CFrame.new(hrp.Position, lookPos)
            -- We need to set the Attachment1.CFrame relative to hrp so AlignOrientation forces orientation to desiredCf
            -- tricky: compute rotation delta from hrp.CFrame to desiredCf
            local delta = hrp.CFrame:ToObjectSpace(desiredCf)
            -- Attachments are local to HRP: set Attachment1.CFrame to delta rotation
            alignOrientation.Attachment1.CFrame = CFrame.new() * delta - CFrame.new(delta.Position) -- keep only rotation
            -- Slight safety: do not change HRP.CFrame directly here
        end
    else
        -- direct HRP teleport fallback (less recommended, keep small smoothing)
        local desired = CFrame.new(hrp.Position, lookPos)
        -- small lerp for smoother rotation: combine positions and slerp rotations
        local current = hrp.CFrame
        local r0 = current - current.Position
        local r1 = desired - desired.Position
        local alpha = math.clamp(20 * dt, 0, 1)
        local newR = r0:Lerp(r1, alpha)
        hrp.CFrame = CFrame.new(hrp.Position) * newR
    end

    lastSafeRotationTick = tick()
end)

-- ==========================
-- Button logic (toggle lock)
-- ==========================
btn.Activated:Connect(function()
    if lockTarget then
        log("Manual unlock")
        lockTarget = nil
        detachBillboard()
        destroyAlignOrientation()
        btn.Text = "LOCK"
        btn.BackgroundColor3 = Color3.fromRGB(36,137,206)
        if humanoid then humanoid.AutoRotate = true end
    else
        local t = getNearestTarget()
        if t then
            lockTarget = t
            attachBillboard(t)
            btn.Text = "UNLOCK"
            btn.BackgroundColor3 = Color3.fromRGB(206,36,36)
            log("Locked onto target:", t:GetFullName())
            if CONFIG.USE_ALIGN_ORIENTATION then
                createAlignOrientation()
            else
                if humanoid then humanoid.AutoRotate = false end
            end
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

-- ==========================
-- Additional camera & humanoid watchers to ensure recovery after grabs/cutscenes
-- ==========================
-- If camera type or subject changes, we attempt to detect and restore when appropriate
local lastCameraType = camera and camera.CameraType or nil
RunService.Heartbeat:Connect(function()
    camera = workspace.CurrentCamera
    if not camera then return end
    if lastCameraType ~= camera.CameraType then
        log("CameraType changed:", tostring(lastCameraType), "->", tostring(camera.CameraType))
        -- if camera changed away from Custom (cutscene), then when it returns we'll try to restore smoothly
        if camera.CameraType ~= Enum.CameraType.Custom then
            -- we won't fight scriptable cams
            lastSafeRotationTick = tick()
        else
            -- camera returned to Custom; try to restore CameraSubject after delay
            restoreCameraToHumanoidAsync()
        end
        lastCameraType = camera.CameraType
    end
end)

-- Ensure when humanoid 'gets up' we try to restore camera + re-enable
if humanoid then
    humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.GettingUp or newState == Enum.HumanoidStateType.Running then
            task.defer(function()
                if camera and humanoid and camera.CameraSubject ~= humanoid and camera.CameraType == Enum.CameraType.Custom then
                    camera.CameraSubject = humanoid
                    camera.CameraType = Enum.CameraType.Custom
                    log("Restored camera subject after state change")
                end
            end)
        end
    end)
end

-- ==========================
-- Diagnostics: optional reproduction logger
-- ==========================
local function pushDebug(msg)
    if #debugHistory > 512 then
        table.remove(debugHistory, 1)
    end
    table.insert(debugHistory, {t = tick(), m = tostring(msg)})
end

-- Example developer console command to dump debug history
-- (in Studio you can call from the command bar)
local function dumpDebug()
    for _, v in ipairs(debugHistory) do
        print(("[%0.3f] %s"):format(v.t, v.m))
    end
end

-- ==========================
-- (Optional) Server handshake / recommended server change notes
-- ==========================
-- NOTE: If your server applies the "grab" by welding the victim's HRP to another object or changing
-- network ownership, you should coordinate using a RemoteEvent to inform clients of the grab start/end.
-- Example (pseudocode):
--  Server: OnGrabStart(victim) -> RemoteEvent:FireClient(victim, "GrabStart")
--  Server: OnGrabEnd(victim)   -> RemoteEvent:FireClient(victim, "GrabEnd")
-- Client: RemoteEvent.OnClientEvent:Connect(function(kind)
--     if kind == "GrabStart" then isDisabled = true end
--     if kind == "GrabEnd"   then isDisabled = false; restoreCameraToHumanoidAsync() end
-- end)
--
-- This is more reliable than trying to infer every single constraint change on the client.

-- ==========================
-- Print loaded
-- ==========================
print("Mobile LockOn Improved loaded (grab/camera-safe). Config:", CONFIG)

-- END OF SCRIPT
