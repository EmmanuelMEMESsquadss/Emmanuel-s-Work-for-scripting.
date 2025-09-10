-- Smart POV Auto-Combat (Rayfield) | Final improved ai.lua
-- For your own testing / your own game only (POV automation)

-- ===== Services =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local VIM = (pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager")) or nil
local TweenService = game:GetService("TweenService")

-- ===== Local player =====
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

-- Update references on respawn
player.CharacterAdded:Connect(function(chr)
    character = chr
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
end)

-- ===== Rayfield UI (load) =====
local Rayfield
do
    local ok
    ok, Rayfield = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if not ok or not Rayfield then
        -- fallback attempt: raw.githack mirror (some executors)
        pcall(function()
            Rayfield = loadstring(game:HttpGet("https://raw.githack.com/sirius/menu/main/rayfield"))()
        end)
    end
    if not Rayfield then
        warn("[Smart POV AI] Rayfield failed to load. UI will not appear. Check network/executor.")
    end
end

-- ===== Configuration / State =====
local AutoCombat = false
local UsePathfinding = true
local DashDistance = 18          -- prefer dash when target further than this
local MaxEngageDistance = 30
local AttackRange = 4
local MoveSpeed = 16
local LeadFactor = 0.15
local RepathInterval = 0.55
local AimSmoothing = 10          -- higher = snappier camera
local BackOffDistance = 6       -- how far to back off after hitting
local BackOffTime = 0.45
local StuckThreshold = 1.2

-- Skill mapping and cooldowns
local SkillKeys = {"One","Two","Three","Four","F","G"} -- 1..4 normal, F alt, G ultimate
local KeyTimes = {One=2.5, Two=4, Three=6, Four=8, F=5, G=20}
local Cooldowns = {}

-- Misc cooldowns
local DashLast = 0
local DashCooldown = 1.2

-- UI proxy (live values)
local UI = {
    DashDistance = DashDistance,
    MaxEngageDistance = MaxEngageDistance,
    AttackRange = AttackRange,
    UsePathfinding = UsePathfinding,
    MoveSpeed = MoveSpeed,
    LeadFactor = LeadFactor,
    BackOffDistance = BackOffDistance,
    BackOffTime = BackOffTime,
    AimSmoothing = AimSmoothing,
}

-- ===== Helpers =====
local function canCast(key)
    local last = Cooldowns[key]
    if not last then return true end
    return (tick() - last) >= (KeyTimes[key] or 1)
end

local function pressKey(key)
    if not key then return end
    if VIM and VIM.SendKeyEvent then
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode[key], false, game)
            task.wait(0.06)
            VIM:SendKeyEvent(false, Enum.KeyCode[key], false, game)
        end)
    else
        -- can't simulate key; warn once
        warn("[Smart POV AI] VirtualInputManager not available. Key press won't be simulated in this executor.")
    end
end

local function mouseClickCenter()
    if VIM and VIM.SendMouseButtonEvent and workspace.CurrentCamera then
        pcall(function()
            local view = workspace.CurrentCamera.ViewportSize
            local cx, cy = view.X/2, view.Y/2
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            task.wait(0.03)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
        end)
    else
        warn("[Smart POV AI] VirtualInputManager mouse event not available.")
    end
end

local function getNearestEnemy(maxDist)
    local nearest, dist = nil, maxDist or UI.MaxEngageDistance
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") then
            local targHRP = plr.Character.HumanoidRootPart
            local mag = (hrp.Position - targHRP.Position).Magnitude
            if mag < dist and plr.Character.Humanoid.Health > 0 then
                nearest, dist = plr, mag
            end
        end
    end
    return nearest, dist
end

local function getAimPosition(targetHRP)
    if not targetHRP then return hrp.Position end
    local vel = Vector3.new(0,0,0)
    if targetHRP.AssemblyLinearVelocity then vel = targetHRP.AssemblyLinearVelocity end
    local aim = targetHRP.Position + vel * UI.LeadFactor
    -- reduce vertical bias to avoid head-only focus
    aim = Vector3.new(aim.X, targetHRP.Position.Y + 1.5, aim.Z)
    return aim
end

local function isInHitRange(targetHRP)
    if not targetHRP then return false end
    local dist = (hrp.Position - targetHRP.Position).Magnitude
    return dist <= (UI.AttackRange + 0.6)
end

-- ===== Pathfinding state =====
local currentPath = nil
local currentWaypoints = {}
local waypointIndex = 1
local pathTarget = nil
local lastPathTime = 0
local lastPos = hrp.Position
local stuckSince = nil

local function computePathAsync(targetPos)
    if not targetPos then return false end
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentMaxSlope = 30,
    })
    local ok, err = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)
    if not ok then return false end
    if path.Status == Enum.PathStatus.Success then
        currentPath = path
        currentWaypoints = path:GetWaypoints()
        waypointIndex = 1
        pathTarget = targetPos
        lastPathTime = tick()
        return true
    else
        currentPath = nil
        currentWaypoints = {}
        waypointIndex = 1
        return false
    end
end

local function followPathStep()
    if not currentPath or #currentWaypoints == 0 then return false end
    local wp = currentWaypoints[waypointIndex]
    if not wp then return false end

    if wp.Action == Enum.PathWaypointAction.Jump then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    humanoid:MoveTo(wp.Position)
    if (hrp.Position - wp.Position).Magnitude <= 2.5 then
        waypointIndex = waypointIndex + 1
        if waypointIndex > #currentWaypoints then
            currentPath = nil
            currentWaypoints = {}
            waypointIndex = 1
            return true
        end
    end
    return true
end

local function simpleChase(targetPos)
    humanoid:MoveTo(targetPos)
end

local function detectAndResolveStuck()
    local now = tick()
    if (hrp.Position - lastPos).Magnitude > 0.45 then
        stuckSince = nil
        lastPos = hrp.Position
        return
    end

    if not stuckSince then
        stuckSince = now
    elseif (now - stuckSince) > StuckThreshold then
        -- small jump + short sidestep (non-teleport)
        humanoid.Jump = true
        local angle = math.rad(math.random(0,360))
        local offset = Vector3.new(math.cos(angle)*3, 0, math.sin(angle)*3)
        local tryPos = hrp.Position + offset
        -- attempt MoveTo to new nearby position
        humanoid:MoveTo(tryPos)
        stuckSince = nil
        lastPos = hrp.Position
    end
end

local function tryDashIfNeeded(dist)
    if not UI.DashDistance then return end
    if dist > UI.DashDistance and dist <= UI.MaxEngageDistance then
        if (tick() - DashLast) >= DashCooldown then
            pressKey("Q")
            DashLast = tick()
        end
    end
end

-- Attack state / hit-and-run
local lastAttack = 0
local backOffUntil = 0

local function doBackOffFrom(targetHRP)
    if not targetHRP then return end
    local dir = (hrp.Position - targetHRP.Position)
    if dir.Magnitude < 0.001 then dir = Vector3.new(0,0,1) end
    local backpos = hrp.Position + dir.Unit * (UI.BackOffDistance or BackOffDistance)
    backOffUntil = tick() + (UI.BackOffTime or BackOffTime)
    humanoid:MoveTo(backpos)
end

local function tryAttack(target, dist)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local tHRP = target.Character.HumanoidRootPart

    -- if in forced backoff, don't attack
    if backOffUntil > tick() then
        return
    end

    -- If in hit range -> use melee skills + M1
    if isInHitRange(tHRP) then
        -- prefer using normal moveset 1-4 first when available
        for i=1,4 do
            local key = SkillKeys[i]
            if key and canCast(key) then
                pressKey(key)
                Cooldowns[key] = tick()
                lastAttack = tick()
                task.wait(0.09)
                mouseClickCenter()
                -- trigger backoff (hit and run)
                doBackOffFrom(tHRP)
                return
            end
        end

        -- fallback primary attack click
        mouseClickCenter()
        lastAttack = tick()
        doBackOffFrom(tHRP)
    else
        -- not in melee range: try to cast ranged / gap-closing skills (F, G)
        for i=5, #SkillKeys do
            local key = SkillKeys[i]
            if key and canCast(key) then
                pressKey(key)
                Cooldowns[key] = tick()
                -- after ranged, try to close distance slightly
                lastAttack = tick()
                return
            end
        end
    end
end

local function aimAtTarget(tHRP, dt)
    if not tHRP or not workspace.CurrentCamera then return end
    local aimPos = getAimPosition(tHRP)
    local cam = workspace.CurrentCamera
    local cur = cam.CFrame
    local targetCFrame = CFrame.new(cur.Position, aimPos)
    local alpha = math.clamp((UI.AimSmoothing or AimSmoothing) * dt, 0.04, 0.7)
    local newCFrame = cur:Lerp(targetCFrame, alpha)
    pcall(function()
        cam.CFrame = newCFrame
    end)
end

-- ===== Main AI heartbeat loop =====
RunService.Heartbeat:Connect(function(dt)
    -- refresh references if respawn occurred
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    if humanoid.Health <= 0 then return end

    -- apply live UI values to local variables for behavior
    humanoid.WalkSpeed = UI.MoveSpeed or MoveSpeed

    if not AutoCombat then
        -- reset path while idle
        currentPath = nil
        currentWaypoints = {}
        waypointIndex = 1
        return
    end

    -- find target
    local target, dist = getNearestEnemy(UI.MaxEngageDistance)
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local tHRP = target.Character.HumanoidRootPart

        -- camera smoothing aim
        pcall(aimAtTarget, tHRP, dt)

        -- dash logic
        tryDashIfNeeded(dist)

        -- movement / pathfinding / chase (repath occasionally)
        if UI.UsePathfinding then
            local needRepath = false
            if not currentPath then needRepath = true end
            if tick() - lastPathTime > RepathInterval then needRepath = true end
            if pathTarget and (pathTarget - tHRP.Position).Magnitude > 6 then needRepath = true end

            if needRepath then
                lastPathTime = tick()
                -- compute async but not block; small pcall
                pcall(function() computePathAsync(tHRP.Position) end)
            end

            if currentPath and #currentWaypoints > 0 then
                followPathStep()
            else
                simpleChase(tHRP.Position)
            end
        else
            simpleChase(tHRP.Position)
        end

        -- attack behavior
        tryAttack(target, dist)

        -- unstuck detection
        detectAndResolveStuck()
    else
        -- no valid target: stop moving and clear path
        humanoid:MoveTo(hrp.Position)
        currentPath = nil
        currentWaypoints = {}
        waypointIndex = 1
    end
end)

-- ===== Rayfield UI Elements (if available) =====
if Rayfield then
    local Window = Rayfield:CreateWindow({
        Name = "Smart POV AI",
        LoadingTitle = "Smart Combat",
        LoadingSubtitle = "W112ND - POV",
        ConfigurationSaving = {Enabled = false},
        KeySystem = false,
    })
    local AITab = Window:CreateTab("AI", 4483362458)
    AITab:CreateSection("Main Controls")

    AITab:CreateToggle({
        Name = "Enable Auto Combat",
        CurrentValue = AutoCombat,
        Flag = "AutoCombat",
        Callback = function(Value)
            AutoCombat = Value
            Rayfield:Notify({
                Title = "Auto Combat",
                Content = AutoCombat and "✅ Activated" or "❌ Stopped",
                Duration = 2
            })
            if not AutoCombat then
                -- reset movement state
                currentPath = nil
                currentWaypoints = {}
                waypointIndex = 1
                backOffUntil = 0
            end
        end
    })

    AITab:CreateToggle({
        Name = "Use Pathfinding",
        CurrentValue = UI.UsePathfinding,
        Flag = "UsePath",
        Callback = function(Value) UI.UsePathfinding = Value end
    })

    AITab:CreateSlider({
        Name = "Max Engage Distance",
        Range = {8, 60},
        Increment = 1,
        Suffix = "studs",
        CurrentValue = UI.MaxEngageDistance,
        Flag = "MaxDist",
        Callback = function(Value) UI.MaxEngageDistance = Value end
    })

    AITab:CreateSlider({
        Name = "Dash Distance",
        Range = {6, 40},
        Increment = 1,
        Suffix = "studs",
        CurrentValue = UI.DashDistance,
        Flag = "DashDist",
        Callback = function(Value) UI.DashDistance = Value end
    })

    AITab:CreateSlider({
        Name = "Attack Range",
        Range = {1, 10},
        Increment = 0.5,
        Suffix = "studs",
        CurrentValue = UI.AttackRange,
        Flag = "AttackRange",
        Callback = function(Value) UI.AttackRange = Value end
    })

    AITab:CreateSlider({
        Name = "Move Speed",
        Range = {8, 40},
        Increment = 1,
        Suffix = "WS",
        CurrentValue = UI.MoveSpeed,
        Flag = "MoveSpeed",
        Callback = function(Value) UI.MoveSpeed = Value end
    })

    AITab:CreateSlider({
        Name = "Lead Factor (predictive aim)",
        Range = {0, 1},
        Increment = 0.01,
        CurrentValue = UI.LeadFactor,
        Flag = "LeadFactor",
        Callback = function(Value) UI.LeadFactor = Value end
    })

    AITab:CreateSlider({
        Name = "BackOff Distance",
        Range = {2, 12},
        Increment = 0.5,
        CurrentValue = UI.BackOffDistance,
        Flag = "BackOff",
        Callback = function(Value) UI.BackOffDistance = Value end
    })

    AITab:CreateSlider({
        Name = "BackOff Time",
        Range = {0.15, 1.2},
        Increment = 0.05,
        CurrentValue = UI.BackOffTime,
        Flag = "BackOffTime",
        Callback = function(Value) UI.BackOffTime = Value end
    })

    AITab:CreateButton({
        Name = "Force Cast Ultimate (G)",
        Callback = function()
            pressKey("G")
            Rayfield:Notify({Title = "Manual", Content = "Forced Ultimate [G]", Duration = 2})
        end
    })

    AITab:CreateLabel("Hotkey: K to toggle Auto Combat")
end

-- hotkey for quick toggling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        AutoCombat = not AutoCombat
        if Rayfield then
            Rayfield:Notify({
                Title = "Auto Combat",
                Content = AutoCombat and "✅ Activated (Hotkey)" or "❌ Stopped (Hotkey)",
                Duration = 2
            })
        else
            print("AutoCombat:", AutoCombat)
        end
        if not AutoCombat then
            currentPath = nil
            currentWaypoints = {}
            waypointIndex = 1
            backOffUntil = 0
        end
    end
end)

-- final load notice
if Rayfield then
    Rayfield:Notify({
        Title = "Loaded",
        Content = "Smart POV AI ready. Tweak sliders and enable Auto Combat.",
        Duration = 4
    })
else
    print("[Smart POV AI] Loaded without Rayfield UI. Use hotkey K to toggle Auto Combat.")
end
