-- Enhanced POV Auto-Combat (No Pathfinding) | JJK testing AI (client-side)
-- Features:
--  - No Pathfinding (removed)
--  - Hitbox-like predictive blocking
--  - State machine: aggressive / attack / backoff / circle / defensive / retreat / stuck
--  - Camera-independent (doesn't rely on you looking at target)
--  - Dash/sidestep unstuck instead of spam-jumping
--  - Optional Rayfield UI (won't abort if Rayfield fails)
-- Put into your executor and test in your own environment.

-- ===== Services =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VIM = (pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager")) or nil

-- ===== Local player refs (auto-updates on respawn) =====
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(chr)
    character = chr
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
end)

-- ===== Try load Rayfield but do NOT return if it fails =====
local Rayfield = nil
do
    local ok
    ok, Rayfield = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if not ok or not Rayfield then
        -- Try alternate raw mirror (may or may not exist)
        pcall(function()
            Rayfield = loadstring(game:HttpGet("https://raw.githack.com/sirius/menu/main/rayfield"))()
        end)
    end
    if not Rayfield then
        warn("[POV AI] Rayfield UI failed to load. Script will continue without UI.")
    end
end

-- ===== CONFIG (change these if needed) =====
local AutoCombat = false
local UsePathfinding = false -- explicitly removed pathfinding
local MaxEngageDistance = 35
local AttackRange = 4.5
local MoveSpeed = 16
local LeadFactor = 0.12          -- for predictive blocking/aim
local RepathInterval = 0.6       -- unused but kept for compatibility
local StuckThreshold = 1.1
local DashCooldown = 1.0

-- Blocking / defensive parameters
local HealthThreshold = 30       -- % to go defensive
local CriticalHealth = 12        -- % to retreat entirely
local BlockWindow = 0.35         -- seconds: if predicted collision in < this -> block
local BlockRange = 8             -- distance to consider block
local RetreatDistance = 20
local BackOffDistance = 8
local BackOffTime = 0.6
local CircleDuration = 1.0       -- seconds to circle after backoff
local CircleRadius = 4.0
local CircleSpeed = 14

-- Skill mapping
local SkillKeys = {"One","Two","Three","Four","F","G"} -- F used for block, G ultimate, Q dash
local KeyTimes = {One=2.5, Two=4, Three=6, Four=8, F=0.8, G=20, Q=1.0}
local Cooldowns = {}

-- ===== STATE =====
local AIState = "idle"     -- idle, approach, attack, backoff, circle, defensive, retreat, stuck
local targetPlayer = nil
local targetDist = math.huge
local lastPos = hrp.Position
local stuckSince = nil
local backOffUntil = 0
local circleUntil = 0
local lastAttack = 0
local lastDash = 0

-- ===== HELPERS =====
local function now() return tick() end

local function canCast(key)
    local last = Cooldowns[key]
    if not last then return true end
    return (now() - last) >= (KeyTimes[key] or 1)
end

local function recordCast(key)
    Cooldowns[key] = now()
end

local function pressKey(key)
    if not key then return end
    if VIM and VIM.SendKeyEvent then
        pcall(function()
            local code = Enum.KeyCode[key] or Enum.KeyCode.Unknown
            VIM:SendKeyEvent(true, code, false, game)
            task.wait(0.06)
            VIM:SendKeyEvent(false, code, false, game)
        end)
    else
        warn("[POV AI] VirtualInputManager not available; key simulation may not work.")
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
        warn("[POV AI] VIM mouse event not available or no camera.")
    end
end

-- Returns nearest player within maxDist. Also returns their distance.
local function getNearestEnemy(maxDist)
    maxDist = maxDist or MaxEngageDistance
    local nearest = nil
    local bestDist = maxDist + 1
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") then
            local hr = plr.Character.HumanoidRootPart
            local hum = plr.Character.Humanoid
            if hum and hum.Health > 0 then
                local d = (hrp.Position - hr.Position).Magnitude
                if d < bestDist and d <= maxDist then
                    bestDist = d
                    nearest = plr
                end
            end
        end
    end
    return nearest, bestDist
end

local function getHealthPercent()
    if not humanoid or humanoid.MaxHealth == 0 then return 100 end
    return (humanoid.Health / humanoid.MaxHealth) * 100
end

-- Predictive "hitbox" check: if enemy is moving towards us and is likely to intersect our HRP soon.
-- This is our hitbox-like blocking detection (doesn't require camera).
local function predictIncomingHit(enemyPlr)
    if not enemyPlr or not enemyPlr.Character or not enemyPlr.Character:FindFirstChild("HumanoidRootPart") then return false end
    local eHRP = enemyPlr.Character.HumanoidRootPart
    local rel = hrp.Position - eHRP.Position
    local relDist = rel.Magnitude
    if relDist > BlockRange then return false end

    local eVel = Vector3.new(0,0,0)
    if eHRP.AssemblyLinearVelocity then eVel = eHRP.AssemblyLinearVelocity end
    local relVel = eVel -- since our local movement small relative

    local speed = relVel.Magnitude
    if speed < 1.0 then return false end

    -- Project time to collision (approx)
    local approachSpeed = math.max(0.001, relVel:Dot(rel.Unit) * -1) -- component towards us
    if approachSpeed <= 0 then return false end
    local timeToContact = relDist / approachSpeed
    if timeToContact <= BlockWindow then
        -- also check facing: is enemy roughly facing us?
        local eLook = eHRP.CFrame.LookVector
        local toUs = (hrp.Position - eHRP.Position).Unit
        local facingDot = eLook:Dot(toUs)
        if facingDot > 0.35 then
            return true
        end
    end
    return false
end

-- Try block immediately (F key used for block by default)
local function tryBlock()
    if canCast("F") then
        pressKey("F")
        recordCast("F")
        return true
    end
    return false
end

-- Attack decision: pick an available skill given distance and health
local lastSkillUsed = nil
local function chooseSkill(distance)
    local hp = getHealthPercent()
    -- Emergency / escape ultimate
    if hp <= CriticalHealth and canCast("G") then return "G" end

    -- If close, prefer melee keys in a cycle
    if distance <= AttackRange + 0.5 then
        for _, k in ipairs({"One","Two","Three","Four"}) do
            if canCast(k) and lastSkillUsed ~= k then
                return k
            end
        end
    else
        -- mid-range: F (range skill) or special fallback
        if canCast("F") then return "F" end
        if canCast("One") then return "One" end
    end
    return nil
end

local function doBackOffFromTarget(tHRP)
    if not tHRP then return end
    local dir = (hrp.Position - tHRP.Position)
    if dir.Magnitude < 0.1 then dir = Vector3.new(0,0,1) end
    local backDist = BackOffDistance
    local backpos = hrp.Position + dir.Unit * backDist
    backOffUntil = now() + BackOffTime
    humanoid:MoveTo(Vector3.new(backpos.X, hrp.Position.Y, backpos.Z))
    -- small dash as escape if available
    if (now() - lastDash) >= DashCooldown and canCast("Q") then
        pressKey("Q"); recordCast("Q"); lastDash = now()
    end
end

local function startCircleAround(tHRP)
    if not tHRP then return end
    circleUntil = now() + CircleDuration
    -- set a temporary faster walk speed for circle
    humanoid.WalkSpeed = CircleSpeed
    -- we'll compute positions during the main loop
end

-- Sidestep to escape / unstuck
local function sidestepEscape()
    if (now() - lastDash) >= DashCooldown and canCast("Q") then
        pressKey("Q"); recordCast("Q"); lastDash = now()
        return
    end
    -- fallback small lateral move
    local angle = math.rad(math.random(0,360))
    local offset = Vector3.new(math.cos(angle)*3, 0, math.sin(angle)*3)
    humanoid:MoveTo(hrp.Position + offset)
end

-- Clean reset states
local function resetStates()
    AIState = "idle"
    targetPlayer = nil
    targetDist = math.huge
    stuckSince = nil
    backOffUntil = 0
    circleUntil = 0
    lastAttack = 0
    lastSkillUsed = nil
    humanoid.WalkSpeed = MoveSpeed
end

-- Attack execution: press skill, then click center to try to register hit
local function executeAttack(skillKey, tHRP)
    if not skillKey then return end
    pressKey(skillKey)
    recordCast(skillKey)
    lastSkillUsed = skillKey
    lastAttack = now()

    -- slight wait for animation
    task.wait(0.08)
    mouseClickCenter()
    -- after attack, we want to back off a bit if melee or if low health
    if skillKey == "G" or getHealthPercent() <= HealthThreshold then
        if tHRP then doBackOffFromTarget(tHRP) end
        startCircleAround(tHRP)
    else
        -- for normal melee, small chance to back off-and-strike again
        doBackOffFromTarget(tHRP)
    end
end

-- ===== Main AI loop (no pathfinding) =====
RunService.Heartbeat:Connect(function(dt)
    -- maintain refs
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    if not humanoid or humanoid.Health <= 0 then return end

    -- update movement speed base
    humanoid.WalkSpeed = MoveSpeed

    -- find nearest target
    local targ, dist = getNearestEnemy(MaxEngageDistance)
    targetPlayer = targ
    targetDist = dist or math.huge

    -- health states
    local healthPct = getHealthPercent()
    local isCritical = healthPct <= CriticalHealth
    local isDefensive = healthPct <= HealthThreshold

    -- unstuck detection
    if (hrp.Position - lastPos).Magnitude > 0.45 then
        stuckSince = nil
        lastPos = hrp.Position
    else
        if not stuckSince then stuckSince = now() end
        if stuckSince and (now() - stuckSince) > StuckThreshold then
            AIState = "stuck"
        end
    end

    -- check for incoming hits and block by hitbox-like detection
    if targetPlayer and predictIncomingHit(targetPlayer) then
        tryBlock()
    end

    -- if AI disabled, reset and skip behavior
    if not AutoCombat then
        resetStates()
        return
    end

    -- state transitions & actions
    if AIState == "stuck" then
        -- try dash/sidestep to unstuck
        sidestepEscape()
        stuckSince = nil
        AIState = "idle"
    end

    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local tHRP = targetPlayer.Character.HumanoidRootPart

        -- forced retreat when critical
        if isCritical then
            AIState = "retreat"
            local retreatDir = (hrp.Position - tHRP.Position)
            if retreatDir.Magnitude < 0.1 then retreatDir = Vector3.new(0,0,1) end
            local retreatPos = hrp.Position + retreatDir.Unit * RetreatDistance
            humanoid:MoveTo(Vector3.new(retreatPos.X, hrp.Position.Y, retreatPos.Z))
            -- dash once to help escape
            if (now() - lastDash) >= DashCooldown and canCast("Q") then
                pressKey("Q"); recordCast("Q"); lastDash = now()
            end
            return
        end

        -- Defensive mode: maintain distance and block more
        if isDefensive then
            AIState = "defensive"
            -- maintain DefensiveDistance (use BackOffDistance)
            local desired = BackOffDistance + 2
            if targetDist < desired then
                -- move backward from target
                local movePos = hrp.Position + (hrp.Position - tHRP.Position).Unit * (desired - targetDist + 0.5)
                humanoid:MoveTo(Vector3.new(movePos.X, hrp.Position.Y, movePos.Z))
            else
                -- small strafe to avoid being predictable
                local perp = Vector3.new(-(tHRP.Position - hrp.Position).Z, 0, (tHRP.Position - hrp.Position).X).Unit
                local strafeTarget = hrp.Position + perp * 2
                humanoid:MoveTo(Vector3.new(strafeTarget.X, hrp.Position.Y, strafeTarget.Z))
            end

            -- attempt opportunistic skills from distance
            if canCast("F") and targetDist <= 12 then
                executeAttack("F", tHRP)
            end

            return
        end

        -- Normal aggressive logic
        -- If currently in backoff period, keep backing off and possibly circle
        if backOffUntil > now() then
            -- keep moving to previously set MoveTo (do nothing, MoveTo will continue)
            if circleUntil > now() then
                -- circle movement: compute a point on circle around target
                local dir = (hrp.Position - tHRP.Position)
                if dir.Magnitude < 0.1 then dir = Vector3.new(0,0,1) end
                local base = tHRP.Position + dir.Unit * (CircleRadius + 1)
                -- rotate around target slightly based on time
                local angle = (now() % 6) * 2.0
                local offset = Vector3.new(math.cos(angle)*CircleRadius, 0, math.sin(angle)*CircleRadius)
                humanoid:MoveTo(Vector3.new(base.X + offset.X, hrp.Position.Y, base.Z + offset.Z))
            end
            return
        end

        -- If close enough, attempt attack
        if targetDist <= AttackRange + 0.6 then
            AIState = "attack"
            local skill = chooseSkill(targetDist)
            if skill then
                executeAttack(skill, tHRP)
                -- set a backoff window after an attack
                backOffUntil = now() + BackOffTime
                circleUntil = now() + CircleDuration
                return
            else
                -- no skill available, fallback to M1 clicking
                mouseClickCenter()
                lastAttack = now()
                backOffUntil = now() + (BackOffTime * 0.6)
                circleUntil = now() + (CircleDuration * 0.6)
                return
            end
        else
            -- not in range => approach but with smarter movement
            AIState = "approach"
            -- desired approach distance: a bit more aggressive than AttackRange so we get inside quickly
            local desiredDistance = AttackRange * 0.9
            -- compute a position that's desiredDistance from the target along the vector from target to us
            local dir = (hrp.Position - tHRP.Position)
            if dir.Magnitude < 0.1 then dir = Vector3.new(0,0,1) end
            local approachPos = tHRP.Position + dir.Unit * desiredDistance
            humanoid:MoveTo(Vector3.new(approachPos.X, hrp.Position.Y, approachPos.Z))
            -- close-gap dash if far
            if targetDist > (AttackRange + 6) and (now() - lastDash) >= DashCooldown and canCast("Q") then
                pressKey("Q"); recordCast("Q"); lastDash = now()
            end
            return
        end
    else
        -- no target found: idle roam or stand still
        AIState = "idle"
        humanoid:MoveTo(hrp.Position)
        return
    end
end)

-- ===== UI (optional Rayfield) =====
local uiWindow
if Rayfield then
    uiWindow = Rayfield:CreateWindow({
        Name = "POV Combat AI (No Pathfinding)",
        LoadingTitle = "POV AI",
        LoadingSubtitle = "Testing AI - POV",
        ConfigurationSaving = {Enabled = false},
        KeySystem = false,
    })
    local tab = uiWindow:CreateTab("AI", 4483362458)
    tab:CreateSection("Main Controls")
    tab:CreateToggle({
        Name = "Enable Auto Combat",
        CurrentValue = AutoCombat,
        Flag = "AutoCombat",
        Callback = function(Value)
            AutoCombat = Value
            if AutoCombat then
                Rayfield:Notify({Title = "POV AI", Content = "✅ Auto Combat Enabled", Duration = 2})
            else
                resetStates()
                Rayfield:Notify({Title = "POV AI", Content = "❌ Auto Combat Disabled", Duration = 2})
            end
        end
    })
    tab:CreateSlider({
        Name = "Max Engage Distance",
        Range = {6, 120},
        Increment = 1,
        Suffix = "studs",
        CurrentValue = MaxEngageDistance,
        Flag = "MaxDist",
        Callback = function(Value) MaxEngageDistance = Value end
    })
    tab:CreateSlider({
        Name = "Attack Range",
        Range = {1, 12},
        Increment = 0.5,
        Suffix = "studs",
        CurrentValue = AttackRange,
        Flag = "AttackRange",
        Callback = function(Value) AttackRange = Value end
    })
    tab:CreateSlider({
        Name = "BackOff Distance",
        Range = {2, 16},
        Increment = 0.5,
        Suffix = "studs",
        CurrentValue = BackOffDistance,
        Flag = "BackOffDistance",
        Callback = function(Value) BackOffDistance = Value end
    })
    tab:CreateSlider({
        Name = "Health Threshold (Defensive)",
        Range = {5, 80},
        Increment = 1,
        Suffix = "%",
        CurrentValue = HealthThreshold,
        Flag = "HealthThreshold",
        Callback = function(Value) HealthThreshold = Value end
    })
    tab:CreateSlider({
        Name = "Critical Health (Retreat)",
        Range = {1, 40},
        Increment = 1,
        Suffix = "%",
        CurrentValue = CriticalHealth,
        Flag = "CriticalHealth",
        Callback = function(Value) CriticalHealth = Value end
    })
    tab:CreateSection("Manual Controls")
    tab:CreateButton({
        Name = "Force Block (F)",
        Callback = function() pressKey("F"); recordCast("F") end
    })
    tab:CreateButton({
        Name = "Force Dash (Q)",
        Callback = function() pressKey("Q"); recordCast("Q") end
    })
    tab:CreateLabel("Hotkey: K to toggle Auto Combat")
end

-- ===== Hotkey =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.K then
        AutoCombat = not AutoCombat
        if Rayfield then
            Rayfield:Notify({Title = "POV AI", Content = AutoCombat and "✅ Toggled ON" or "❌ Toggled OFF", Duration = 2})
        else
            print("[POV AI] AutoCombat toggled:", AutoCombat)
        end
        if not AutoCombat then
            resetStates()
        end
    end
end)

-- ===== Final notice =====
if Rayfield then
    Rayfield:Notify({Title = "POV AI Loaded", Content = "No-path AI initialized. K toggles combat.", Duration = 4})
else
    print("[POV AI] Loaded without Rayfield. Press K to toggle AutoCombat.")
end
