-- Smart NPC-style POV Auto-Combat (no pathfinding) - Client-only
-- Put this file on your GitHub and run with: loadstring(game:HttpGet("https://raw.githubusercontent.com/<user>/<repo>/main/ai.lua"))()

-- ===== Services =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

-- VirtualInputManager detection (executor-dependent)
local okVIM, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
if not okVIM then VIM = nil end

-- ===== Local player refs (auto-refresh on respawn) =====
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(chr)
    character = chr
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
end)

-- ===== Config / State =====
local AutoCombat = false
local UI = {
    MaxEngageDistance = 40,
    AttackRange = 4.5,
    MoveSpeed = 28,           -- running speed (restore original on disable)
    AggressiveDistance = 4.5,
    DefensiveDistance = 10,
    BackOffDistance = 8,
    BackOffTime = 0.5,
    BlockHitboxRadius = 4.5,  -- hitbox radius around you to detect incoming limb/weapon
    BlockVelocityThreshold = 6, -- part velocity towards you to be considered an incoming hit
    RecheckInterval = 0.08,   -- main loop tick (seconds)
}

local originalWalkSpeed = humanoid.WalkSpeed
local Cooldowns = {}
local KeyTimes = {One=2.5, Two=4, Three=6, Four=8, F=5, G=20, R=3}
local SkillKeys = {"One","Two","Three","Four","F","G"}
local lastSkillUsed = nil
local backOffUntil = 0
local blockingSince = 0
local BlockCooldown = 0.5

-- UI library (try Rayfield; fallback will continue without UI)
local Rayfield
do
    local ok
    ok, Rayfield = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if not ok or not Rayfield then
        -- fail silently; script still works without UI
        Rayfield = nil
        warn("[SmartNPC AI] Rayfield not available — running headless. Use hotkey K to toggle.")
    end
end

-- ===== Helpers =====
local function canCast(key)
    local last = Cooldowns[key]
    if not last then return true end
    return (tick() - last) >= (KeyTimes[key] or 1)
end

local function pressKey(key)
    if not key or not VIM then
        -- If no VIM, we can't simulate key presses from client reliably
        return false
    end
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode[key], false, game)
        task.wait(0.06)
        VIM:SendKeyEvent(false, Enum.KeyCode[key], false, game)
    end)
    return true
end

local function mouseClickCenter()
    if not VIM or not workspace.CurrentCamera then return end
    pcall(function()
        local view = workspace.CurrentCamera.ViewportSize
        local cx, cy = view.X/2, view.Y/2
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(0.03)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
end

-- Get nearest enemy by distance (no camera checks)
local function getNearestEnemy(maxDist)
    local nearest, bestDist = nil, maxDist or UI.MaxEngageDistance
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") then
            local targHRP = plr.Character.HumanoidRootPart
            local mag = (hrp.Position - targHRP.Position).Magnitude
            if mag < bestDist and plr.Character.Humanoid.Health > 0 then
                nearest = plr
                bestDist = mag
            end
        end
    end
    return nearest, bestDist
end

-- Decide an "optimal position" relative to the target based on health/defensive/aggressive
local function getOptimalPosition(targetHRP)
    local targetPos = targetHRP.Position
    local direction = (hrp.Position - targetPos)
    if direction.Magnitude < 0.001 then direction = Vector3.new(0,0,1) end
    local desiredDistance = UI.AggressiveDistance
    local healthPct = (humanoid.Health / humanoid.MaxHealth) * 100
    if healthPct <= 15 then
        desiredDistance = UI.DefensiveDistance + 6
    elseif healthPct <= 30 then
        desiredDistance = UI.DefensiveDistance
    else
        desiredDistance = UI.AggressiveDistance
    end
    return targetPos + direction.Unit * desiredDistance
end

-- Blocking detection: use proximity + part velocity toward you to detect incoming hits (hitbox style)
local function isIncomingHit()
    -- Check all other players' character parts within block radius
    local radius = UI.BlockHitboxRadius
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            for _, part in ipairs(plr.Character:GetDescendants()) do
                if part:IsA("BasePart") and not part.Anchored then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d <= radius then
                        local v = part.AssemblyLinearVelocity or Vector3.new()
                        -- direction from attacker part to our hrp
                        local dirToUs = (hrp.Position - part.Position)
                        if dirToUs.Magnitude > 0.001 then
                            local dot = v:Dot(dirToUs.Unit)
                            -- if part is moving toward us above a threshold => incoming swing/weapon
                            if dot > UI.BlockVelocityThreshold then
                                return true, plr, part
                            end
                        end
                    end
                end
            end
        end
    end
    return false, nil, nil
end

local function tryBlock()
    if (tick() - blockingSince) < BlockCooldown then return false end
    blockingSince = tick()
    -- Block key assumed 'F' for many games — change if your game uses another block key.
    if pressKey("F") then
        return true
    end
    return false
end

-- Attack logic: try prioritized skill usage or fallback to mouse click
local function tryAttack(target, dist)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local tHRP = target.Character.HumanoidRootPart
    local healthPct = (humanoid.Health / humanoid.MaxHealth) * 100

    -- respect backoff timer
    if backOffUntil > tick() then return end

    -- choose skill: prefer melee skills if close; use F/G for ranged or emergency
    if dist <= UI.AttackRange + 0.6 then
        local melee = {"One","Two","Three","Four"}
        for _,k in ipairs(melee) do
            if canCast(k) and lastSkillUsed ~= k then
                pressKey(k)
                Cooldowns[k] = tick()
                lastSkillUsed = k
                task.wait(0.09)
                mouseClickCenter()
                -- short backoff after using ability if low health
                if healthPct <= 35 then
                    backOffUntil = tick() + UI.BackOffTime
                end
                return
            end
        end
        -- fallback: click
        mouseClickCenter()
        lastSkillUsed = nil
        return
    else
        -- mid/long range: try F or G if available
        if canCast("F") then
            pressKey("F"); Cooldowns["F"] = tick(); lastSkillUsed = "F"; return
        end
        if canCast("G") then
            pressKey("G"); Cooldowns["G"] = tick(); lastSkillUsed = "G"; return
        end
    end
end

-- small unstuck helper (teleport-ish fudge to escape geometry)
local lastPos = hrp.Position
local stuckSince = nil
local function detectAndResolveStuck()
    if (hrp.Position - lastPos).Magnitude > 0.4 then
        stuckSince = nil
        lastPos = hrp.Position
        return
    end
    if not stuckSince then
        stuckSince = tick()
    elseif (tick() - stuckSince) > 1.2 then
        -- attempt quick jump + small lateral reposition
        humanoid.Jump = true
        local fudge = CFrame.new(Vector3.new(math.random(-3,3),0,math.random(-3,3)))
        hrp.CFrame = hrp.CFrame * fudge
        stuckSince = nil
        lastPos = hrp.Position
    end
end

-- === Input suppression (make your character act like NPC locally) ===
local boundActionName = "AI_BlockPlayerInputs"
local function blockInputAction(actionName, inputState, inputObject)
    -- sink all configured movement keys while AutoCombat is on
    return Enum.ContextActionResult.Sink
end

local function enableLocalControlOverride()
    -- bind common movement keys so player's inputs won't fight the AI
    ContextActionService:BindAction(boundActionName, blockInputAction, false,
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
        Enum.KeyCode.Space, Enum.KeyCode.LeftShift)
end
local function disableLocalControlOverride()
    pcall(function() ContextActionService:UnbindAction(boundActionName) end)
end

-- ===== Rayfield UI elements (if loaded) =====
local Window, AITab
if Rayfield then
    Window = Rayfield:CreateWindow({
        Name = "Smart NPC POV AI",
        LoadingTitle = "Smart Combat",
        LoadingSubtitle = "NPC-style POV AI",
        ConfigurationSaving = {Enabled = false},
        KeySystem = false,
    })
    AITab = Window:CreateTab("AI Controls", 4483362458)
    AITab:CreateSection("Main")
    AITab:CreateToggle({
        Name = "Enable Auto Combat",
        CurrentValue = AutoCombat,
        Flag = "AutoCombat",
        Callback = function(Value)
            AutoCombat = Value
            if AutoCombat then
                enableLocalControlOverride()
                humanoid.WalkSpeed = UI.MoveSpeed
            else
                disableLocalControlOverride()
                humanoid.WalkSpeed = originalWalkSpeed or 16
            end
            Rayfield:Notify({Title = "AutoCombat", Content = AutoCombat and "✅ ON" or "❌ OFF", Duration = 2})
        end
    })
    AITab:CreateSlider({
        Name = "Max Engage Distance",
        Range = {8,120},
        Increment = 1,
        CurrentValue = UI.MaxEngageDistance,
        Flag = "MaxEngage",
        Callback = function(v) UI.MaxEngageDistance = v end
    })
    AITab:CreateSlider({
        Name = "Move Speed (WS)",
        Range = {8,80},
        Increment = 1,
        CurrentValue = UI.MoveSpeed,
        Flag = "MoveSpeed",
        Callback = function(v) UI.MoveSpeed = v; if AutoCombat then humanoid.WalkSpeed = v end
    })
    AITab:CreateLabel("Hotkey: K to toggle AutoCombat")
end

-- Hotkey fallback: K toggles (if no Rayfield)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        AutoCombat = not AutoCombat
        if AutoCombat then
            enableLocalControlOverride()
            humanoid.WalkSpeed = UI.MoveSpeed
            if Rayfield then Rayfield:Notify({Title="AutoCombat",Content="✅ ON",Duration=2}) end
        else
            disableLocalControlOverride()
            humanoid.WalkSpeed = originalWalkSpeed or 16
            if Rayfield then Rayfield:Notify({Title="AutoCombat",Content="❌ OFF",Duration=2}) end
        end
    end
end)

-- ===== Main loop (no pathfinding) =====
local lastTick = 0
RunService.Heartbeat:Connect(function(dt)
    lastTick = lastTick + dt
    if lastTick < UI.RecheckInterval then return end
    lastTick = 0

    -- ensure character references valid
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    if humanoid.Health <= 0 then return end

    -- keep speed updated while active
    if AutoCombat then
        humanoid.WalkSpeed = UI.MoveSpeed
    end

    if not AutoCombat then
        return
    end

    -- detect incoming hit (hitbox-based)
    local incoming, attacker, hitPart = isIncomingHit()
    if incoming then
        -- immediate blocking attempt
        tryBlock()
    end

    -- Find nearest target
    local target, dist = getNearestEnemy(UI.MaxEngageDistance)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        humanoid:MoveTo(hrp.Position) -- idle
        return
    end

    local tHRP = target.Character.HumanoidRootPart

    -- Movement: move toward an optimal position relative to enemy (no pathfinding)
    local optimal = getOptimalPosition(tHRP)
    humanoid:MoveTo(optimal)

    -- Attack decision
    tryAttack(target, dist)

    -- Unstuck
    detectAndResolveStuck()
end)

-- Final notice
if Rayfield then
    Rayfield:Notify({Title = "Smart NPC AI", Content = "Loaded — toggle with K or Rayfield UI", Duration = 4})
else
    print("[Smart NPC AI] Loaded (no Rayfield). Toggle with K.")
end

-- Cleanup when script stopped (not strictly necessary, but safe)
-- Note: if you reload script you may want to call disableLocalControlOverride() manually to restore controls.
