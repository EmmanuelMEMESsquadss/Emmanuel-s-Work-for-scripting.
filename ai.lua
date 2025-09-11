-- Smart NPC-style POV Combat (no pathfinding)
-- For private testing only. Controls YOUR character to behave like an NPC bot.
-- Features: state machine, hitbox-based blocking, hit-and-run, no camera dependence.

-- ===== Services =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VIM = (pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager")) or nil

-- ===== Local player refs =====
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(chr)
    character = chr
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
end)

-- ===== UI (try Rayfield, fallback) =====
local Rayfield
do
    local ok
    ok, Rayfield = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if not ok or not Rayfield then
        -- sometimes raw.githack or raw.githubusercontent mirrors help; try one fallback quietly
        pcall(function()
            Rayfield = loadstring(game:HttpGet("https://raw.githack.com/sirius/menu/main/rayfield"))()
        end)
    end
end

-- ===== Config (tweakable) =====
local AutoCombat = false

local UI = {
    MaxEngageDistance = 35,   -- overall detection radius
    AttackRange = 4.5,        -- melee hit range
    AggressiveDistance = 5.0, -- desired distance when healthy
    DefensiveDistance = 9.0,  -- desired distance when low health
    BackOffDistance = 8.0,    -- how far to back off after attack
    BackOffTime = 0.55,       -- how long to stay backing off
    MoveSpeed = 16,           -- humanoid walk speed used
    DashKey = "Q",            -- dash key (press via VIM)
    BlockKey = "F",           -- block key
    UltKey = "G",             -- ultimate
    LeadFactor = 0.15,        -- predictive aiming factor (used for aim logic if needed)
    HealthThreshold = 35,     -- percent -> defensive mode
    CriticalHealth = 14,      -- percent -> retreat mode
    BlockDistance = 7.0,      -- how close enemy hitbox must be to consider blocking
    BlockVelocityThreshold = 10, -- enemy velocity magnitude threshold suggesting attack
    BlockHoldTime = 0.35,     -- hold block for this long when triggered
    StuckThreshold = 1.1,     -- seconds to consider stuck
}

-- Skill cooldowns and tracking
local SkillKeys = {"One","Two","Three","Four","F","G","R","Q"}
local KeyTimes = {One=2.5, Two=4, Three=6, Four=8, F=5, G=22, R=3, Q=0.5}
local Cooldowns = {}

-- ===== Helpers =====
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
            VIM:SendKeyEvent(true, Enum.KeyCode[key], false, game)
            task.wait(0.06)
            VIM:SendKeyEvent(false, Enum.KeyCode[key], false, game)
        end)
    else
        -- fallback: notify user that their executor may not simulate keypresses
        -- (we don't error; attacks may still work with mouseClick fallback)
        warn("[SmartNPC] VIM not available — key '"..tostring(key).."' may not fire on this executor.")
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
        -- fallback: try to fire a Mouse1 event if your executor exposes one — we warn instead.
        warn("[SmartNPC] Mouse click simulation unavailable.")
    end
end

-- get nearest enemy player within maxDist
local function getNearestEnemy(maxDist)
    maxDist = maxDist or UI.MaxEngageDistance
    local best, bestDist = nil, maxDist + 0.01
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl.Character:FindFirstChild("Humanoid") then
            local targHRP = pl.Character.HumanoidRootPart
            local hum = pl.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local d = (hrp.Position - targHRP.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = pl
                end
            end
        end
    end
    return best, bestDist
end

-- Find likely attack parts in the enemy: name heuristics (hitbox, weapon, attack)
local function getAttackParts(character)
    local parts = {}
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = obj.Name:lower()
            if n:find("hit") or n:find("hurt") or n:find("atk") or n:find("weapon") or n:find("attack") then
                table.insert(parts, obj)
            end
        end
    end
    return parts
end

-- Is there an attack part near our HRP? (direct hitbox detection)
local function anyAttackPartNear(enemy, radius)
    radius = radius or UI.BlockDistance
    if not enemy or not enemy.Character then return false end
    local parts = getAttackParts(enemy.Character)
    for _, p in ipairs(parts) do
        if p and p:IsA("BasePart") and p.Position then
            if (hrp.Position - p.Position).Magnitude <= radius then
                return true, p
            end
        end
    end
    return false, nil
end

-- Aggressive incoming movement detection: enemy HRP velocity pointing toward us & speed > threshold
local function isEnemyRushing(enemy)
    if not enemy or not enemy.Character then return false end
    local eHRP = enemy.Character:FindFirstChild("HumanoidRootPart")
    if not eHRP then return false end
    local vel = eHRP.AssemblyLinearVelocity or Vector3.new()
    local speed = vel.Magnitude
    if speed < UI.BlockVelocityThreshold then return false end
    -- compute projection of velocity onto vector to us (positive means moving toward us)
    local toUs = (hrp.Position - eHRP.Position)
    if toUs.Magnitude < 0.1 then return true end
    local proj = (vel:Dot(toUs.Unit))
    return proj > (UI.BlockVelocityThreshold * 0.35) -- some tolerance
end

local function getHealthPercent()
    if not humanoid or not humanoid.Health or not humanoid.MaxHealth then return 100 end
    return (humanoid.Health / math.max(1, humanoid.MaxHealth)) * 100
end

-- choose an optimal desired position relative to the target
local function getOptimalPosition(targetHRP)
    if not targetHRP then return hrp.Position end
    local health = getHealthPercent()
    local desiredDistance = UI.AggressiveDistance
    if health <= UI.CriticalHealth then
        desiredDistance = UI.BackOffDistance + 2
    elseif health <= UI.HealthThreshold then
        desiredDistance = UI.DefensiveDistance
    else
        desiredDistance = UI.AggressiveDistance
    end

    -- direction from target to us (we want to stand at desiredDistance in that direction)
    local dir = (hrp.Position - targetHRP.Position)
    if dir.Magnitude < 0.5 then
        dir = Vector3.new(0,0,1)
    end
    local pos = targetHRP.Position + dir.Unit * desiredDistance
    -- keep feet level (Y) to target HRP
    pos = Vector3.new(pos.X, targetHRP.Position.Y, pos.Z)
    return pos
end

-- select a skill for situation
local lastSkillUsed = nil
local function selectSkill(dist, healthPct)
    -- emergency ultimate if critical
    if healthPct <= UI.CriticalHealth and canCast("G") then return "G" end
    -- at close range: use the normal 1-4 moveset (prefer ones not used recently)
    if dist <= UI.AttackRange + 0.5 then
        for _, k in ipairs({"One","Two","Three","Four"}) do
            if canCast(k) and lastSkillUsed ~= k then
                return k
            end
        end
        -- if all same used, fall back to One if available
        if canCast("One") then return "One" end
    end
    -- mid/long range: try F or R
    if dist > UI.AttackRange and canCast("F") then return "F" end
    if canCast("R") then return "R" end
    return nil
end

-- Back off behavior
local backOffUntil = 0
local function doBackOffFrom(targetHRP)
    if not targetHRP then return end
    local dir = (hrp.Position - targetHRP.Position)
    if dir.Magnitude < 0.001 then dir = Vector3.new(0,0,1) end
    local backDist = math.max(3, UI.BackOffDistance)
    local backpos = hrp.Position + dir.Unit * backDist
    backOffUntil = now() + (UI.BackOffTime or 0.5)
    humanoid:MoveTo(backpos)
end

-- Stuck detection & resolve
local lastPos = hrp.Position
local stuckSince = nil
local lastUnstuck = 0
local function detectAndResolveStuck()
    local t = now()
    if (hrp.Position - lastPos).Magnitude > 0.45 then
        stuckSince = nil
        lastPos = hrp.Position
        return
    end
    if not stuckSince then stuckSince = t return end
    if (t - stuckSince) > UI.StuckThreshold then
        -- try dash escape if available
        if canCast(UI.DashKey) and (t - lastUnstuck) > 1.2 then
            pressKey(UI.DashKey)
            recordCast(UI.DashKey)
            lastUnstuck = t
        else
            humanoid.Jump = true
            local angle = math.rad(math.random(0,360))
            local offset = Vector3.new(math.cos(angle)*4, 0, math.sin(angle)*4)
            humanoid:MoveTo(hrp.Position + offset)
        end
        stuckSince = nil
        lastPos = hrp.Position
    end
end

-- Blocking action
local lastBlockTime = 0
local function triggerBlock()
    if (now() - lastBlockTime) < 0.15 then return end
    if canCast(UI.BlockKey) then
        pressKey(UI.BlockKey)
        recordCast(UI.BlockKey)
        lastBlockTime = now()
    end
end

-- Attack execution
local function performAttack(target, dist)
    if not target or not target.Character then return end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end
    local hp = getHealthPercent()

    -- select skill
    local sk = selectSkill(dist, hp)
    if sk then
        pressKey(sk)
        recordCast(sk)
        lastSkillUsed = sk
        -- slight wait for animation then click center to confirm
        task.wait(0.09)
        mouseClickCenter()
        -- back off if low or used heavy skill
        if hp <= UI.HealthThreshold or sk == "G" then
            doBackOffFrom(tHRP)
        end
        return true
    end

    -- fallback: if in hit range, click M1
    if dist <= UI.AttackRange + 0.4 then
        mouseClickCenter()
        if getHealthPercent() <= UI.HealthThreshold then
            doBackOffFrom(tHRP)
        end
        return true
    end

    return false
end

-- ===== State Machine variables =====
local state = "Idle" -- Idle, Chase, Attack, Block, BackOff, Retreat
local currentTarget = nil
local lastTargetDist = math.huge
local blockHoldUntil = 0

-- ===== Main loop (single Heartbeat connection) =====
RunService.Heartbeat:Connect(function(dt)
    -- refresh sanity references
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        -- wait for char to exist next tick
        return
    end

    -- update humanoid speed live
    humanoid.WalkSpeed = UI.MoveSpeed

    -- reset early if disabled
    if not AutoCombat then
        state = "Idle"
        currentTarget = nil
        humanoid:MoveTo(hrp.Position)
        return
    end

    if humanoid.Health <= 0 then
        -- dead -> do nothing
        state = "Idle"
        return
    end

    -- choose target
    local tgt, d = getNearestEnemy(UI.MaxEngageDistance)
    currentTarget = tgt
    local dist = d or math.huge

    -- health states
    local hpct = getHealthPercent()
    local retreatMode = (hpct <= UI.CriticalHealth)
    local defensiveMode = (hpct <= UI.HealthThreshold) and not retreatMode

    -- emergency retreat behavior
    if retreatMode and currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild("HumanoidRootPart") then
        local tHRP = currentTarget.Character.HumanoidRootPart
        local away = hrp.Position + (hrp.Position - tHRP.Position).Unit * (UI.BackOffDistance + 6)
        humanoid:MoveTo(away)
        state = "Retreat"
        -- attempt dash if available
        if canCast(UI.DashKey) then
            pressKey(UI.DashKey)
            recordCast(UI.DashKey)
        end
        detectAndResolveStuck()
        return
    end

    -- If we have a target inside engage distance:
    if currentTarget and dist <= UI.MaxEngageDistance then
        local tHRP = currentTarget.Character and currentTarget.Character:FindFirstChild("HumanoidRootPart")
        if not tHRP then
            state = "Idle"
            return
        end

        -- 1) Block detection: prefer hitbox-based detection when possible
        local attackPartNearby, victimPart = anyAttackPartNear(currentTarget, UI.BlockDistance)
        local rushing = isEnemyRushing(currentTarget)
        if attackPartNearby or rushing then
            -- Enter block state and hold for BlockHoldTime
            triggerBlock()
            blockHoldUntil = now() + UI.BlockHoldTime
            state = "Block"
            -- we still try to step back a little to avoid followup
            humanoid:MoveTo(hrp.Position + (hrp.CFrame.LookVector * -1.5))
            detectAndResolveStuck()
            return
        end

        -- If still in Block hold window, keep blocking/moving slightly
        if now() < blockHoldUntil then
            state = "Block"
            -- keep a small back-move to avoid follow-up
            humanoid:MoveTo(hrp.Position + (hrp.CFrame.LookVector * -1.2))
            detectAndResolveStuck()
            return
        end

        -- 2) BackOff window: if recently backed off, wait until backOffUntil
        if now() < backOffUntil then
            state = "BackOff"
            detectAndResolveStuck()
            return
        end

        -- 3) When within attack range => attempt attack
        if dist <= UI.AttackRange + 0.6 then
            local ok = performAttack(currentTarget, dist)
            if ok then
                state = "Attack"
                detectAndResolveStuck()
                return
            else
                -- can't attack (cooldowns) -> small reposition
                local opt = getOptimalPosition(tHRP)
                humanoid:MoveTo(opt)
                state = "Chase"
                detectAndResolveStuck()
                return
            end
        end

        -- 4) Not in attack range -> chase to optimal position
        local optimalPos = getOptimalPosition(tHRP)
        humanoid:MoveTo(optimalPos)
        state = "Chase"
        detectAndResolveStuck()
        return
    else
        -- No target found: idle
        state = "Idle"
        humanoid:MoveTo(hrp.Position)
        detectAndResolveStuck()
        return
    end
end)

-- ===== UI + hotkeys =====
local function setUpUI()
    if not Rayfield then
        print("[SmartNPC] Rayfield not loaded; using hotkey K to toggle AutoCombat. Tweak variables in script.")
        return
    end

    local Window = Rayfield:CreateWindow({
        Name = "Smart NPC POV AI",
        LoadingTitle = "Smart NPC Combat",
        LoadingSubtitle = "POV AI - no pathfinding",
        ConfigurationSaving = {Enabled = false},
        KeySystem = false,
    })

    local Tab = Window:CreateTab("Combat AI", 4483362458)
    Tab:CreateSection("Main Controls")
    Tab:CreateToggle({
        Name = "Enable Auto Combat",
        CurrentValue = AutoCombat,
        Flag = "AutoCombat",
        Callback = function(val)
            AutoCombat = val
            Rayfield:Notify({Title = "SmartNPC", Content = AutoCombat and "✅ Activated" or "❌ Stopped", Duration = 2})
            if not AutoCombat then
                -- reset movement & state
                humanoid:MoveTo(hrp.Position)
                state = "Idle"
                backOffUntil = 0
            end
        end
    })

    Tab:CreateSlider({Name="Max Engage Distance", Range={8,80}, Increment=1, CurrentValue=UI.MaxEngageDistance, Callback=function(v) UI.MaxEngageDistance=v end})
    Tab:CreateSlider({Name="Attack Range", Range={1,12}, Increment=0.5, CurrentValue=UI.AttackRange, Callback=function(v) UI.AttackRange=v end})
    Tab:CreateSlider({Name="Aggressive Distance", Range={1,12}, Increment=0.5, CurrentValue=UI.AggressiveDistance, Callback=function(v) UI.AggressiveDistance=v end})
    Tab:CreateSlider({Name="Defensive Distance", Range={4,20}, Increment=0.5, CurrentValue=UI.DefensiveDistance, Callback=function(v) UI.DefensiveDistance=v end})
    Tab:CreateSlider({Name="BackOff Distance", Range={2,18}, Increment=0.5, CurrentValue=UI.BackOffDistance, Callback=function(v) UI.BackOffDistance=v end})
    Tab:CreateSlider({Name="Health Threshold (Defensive %)", Range={5,80}, Increment=1, CurrentValue=UI.HealthThreshold, Callback=function(v) UI.HealthThreshold=v end})
    Tab:CreateSlider({Name="Critical Health (Retreat %)", Range={2,50}, Increment=1, CurrentValue=UI.CriticalHealth, Callback=function(v) UI.CriticalHealth=v end})
    Tab:CreateSlider({Name="Block Distance", Range={2,16}, Increment=0.5, CurrentValue=UI.BlockDistance, Callback=function(v) UI.BlockDistance=v end})
    Tab:CreateSlider({Name="Block Speed Threshold", Range={2,40}, Increment=0.5, CurrentValue=UI.BlockVelocityThreshold, Callback=function(v) UI.BlockVelocityThreshold=v end})
    Tab:CreateSection("Manual Controls")
    Tab:CreateButton({Name="Force Block (F)", Callback=function() pressKey("F"); Rayfield:Notify({Title="Manual", Content="Block pressed", Duration=1}) end})
    Tab:CreateButton({Name="Force Dash (Q)", Callback=function() pressKey("Q"); Rayfield:Notify({Title="Manual", Content="Dash pressed", Duration=1}) end})
    Tab:CreateButton({Name="Force Ult (G)", Callback=function() pressKey("G"); Rayfield:Notify({Title="Manual", Content="Ult pressed", Duration=1}) end})
    Tab:CreateLabel("Hotkey: K toggles Auto Combat")
end

setUpUI()

-- hotkey K toggles
UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.KeyCode == Enum.KeyCode.K then
        AutoCombat = not AutoCombat
        if Rayfield then
            Rayfield:Notify({Title="SmartNPC", Content=AutoCombat and "✅ Activated (Hotkey)" or "❌ Stopped (Hotkey)", Duration=2})
        else
            print("[SmartNPC] AutoCombat:", AutoCombat)
        end
        if not AutoCombat then
            humanoid:MoveTo(hrp.Position)
            state = "Idle"
            backOffUntil = 0
        end
    end
end)

print("[SmartNPC] Loaded. Use K to toggle AutoCombat. Rayfield:", Rayfield ~= nil)
