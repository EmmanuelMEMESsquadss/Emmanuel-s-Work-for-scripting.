-- Enhanced Smart POV Auto-Combat (Rayfield) | JJK Battlegrounds AI
-- Improved with health awareness, defensive mechanics, and better combat AI

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
        warn("[Enhanced JJK AI] Rayfield failed to load. UI will not appear. Check network/executor.")
    end
end

-- ===== Enhanced Configuration / State =====
local AutoCombat = false
local UsePathfinding = true
local DashDistance = 18          -- prefer dash when target further than this
local MaxEngageDistance = 35
local AttackRange = 4.5
local MoveSpeed = 16
local LeadFactor = 0.15
local RepathInterval = 0.55
local AimSmoothing = 12          -- higher = snappier camera
local BackOffDistance = 8       -- how far to back off after hitting
local BackOffTime = 0.6
local StuckThreshold = 1.2

-- New Enhanced Features
local HealthThreshold = 30       -- health % to start defensive behavior
local CriticalHealth = 15        -- health % for emergency retreat
local BlockChance = 0.7          -- chance to block incoming attacks
local CounterAttackDelay = 0.3   -- delay before counter attacking
local DefensiveDistance = 12     -- distance to maintain when low health
local AggressiveDistance = 6     -- close distance when healthy
local RetreatDistance = 20       -- distance to retreat when critical health

-- Advanced Skill Usage
local SkillKeys = {"One","Two","Three","Four","F","G","R"} -- Added R for special
local KeyTimes = {One=2.5, Two=4, Three=6, Four=8, F=5, G=20, R=3}
local Cooldowns = {}

-- Enhanced Combat State
local DashLast = 0
local DashCooldown = 1.2
local BlockLast = 0
local BlockCooldown = 0.8
local lastEnemyAttack = 0
local inDefensiveMode = false
local retreatMode = false
local lastHealthCheck = 100

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
    HealthThreshold = HealthThreshold,
    CriticalHealth = CriticalHealth,
    BlockChance = BlockChance,
    DefensiveDistance = DefensiveDistance,
    AggressiveDistance = AggressiveDistance,
}

-- ===== Enhanced Helpers =====
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
        warn("[Enhanced JJK AI] VirtualInputManager not available. Key press won't be simulated in this executor.")
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
        warn("[Enhanced JJK AI] VirtualInputManager mouse event not available.")
    end
end

-- Enhanced enemy detection with threat assessment
local function getNearestEnemy(maxDist)
    local nearest, dist = nil, maxDist or UI.MaxEngageDistance
    local mostDangerous = nil
    local dangerScore = 0
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") then
            local targHRP = plr.Character.HumanoidRootPart
            local targHum = plr.Character.Humanoid
            local mag = (hrp.Position - targHRP.Position).Magnitude
            
            if mag < dist and targHum.Health > 0 then
                -- Calculate threat score based on distance and health
                local threatScore = (100 - mag) + (targHum.Health * 0.5)
                
                if mag < dist then
                    nearest, dist = plr, mag
                end
                
                if threatScore > dangerScore then
                    mostDangerous = plr
                    dangerScore = threatScore
                end
            end
        end
    end
    
    return nearest, dist, mostDangerous
end

-- Enhanced health monitoring
local function getHealthPercentage()
    if not humanoid then return 100 end
    return (humanoid.Health / humanoid.MaxHealth) * 100
end

local function shouldRetreat()
    local healthPct = getHealthPercentage()
    return healthPct <= UI.CriticalHealth
end

local function shouldBeDefensive()
    local healthPct = getHealthPercentage()
    return healthPct <= UI.HealthThreshold
end

-- Enhanced blocking system
local function shouldBlock(enemy)
    if not enemy or not enemy.Character then return false end
    
    local enemyHRP = enemy.Character:FindFirstChild("HumanoidRootPart")
    if not enemyHRP then return false end
    
    local distance = (hrp.Position - enemyHRP.Position).Magnitude
    local enemyVelocity = enemyHRP.AssemblyLinearVelocity.Magnitude
    
    -- Block if enemy is close and moving fast (likely attacking)
    if distance < 8 and enemyVelocity > 10 then
        return math.random() < UI.BlockChance
    end
    
    return false
end

local function tryBlock()
    if (tick() - BlockLast) >= BlockCooldown then
        pressKey("F")  -- Block key
        BlockLast = tick()
        return true
    end
    return false
end

-- Enhanced predictive aim with enemy behavior analysis
local function getAimPosition(targetHRP)
    if not targetHRP then return hrp.Position end
    local vel = Vector3.new(0,0,0)
    if targetHRP.AssemblyLinearVelocity then vel = targetHRP.AssemblyLinearVelocity end
    
    -- Enhanced prediction based on enemy velocity and our health
    local predictionMultiplier = shouldBeDefensive() and 0.1 or UI.LeadFactor
    local aim = targetHRP.Position + vel * predictionMultiplier
    
    -- Adjust aim height based on combat situation
    local heightOffset = inDefensiveMode and 0.5 or 1.5
    aim = Vector3.new(aim.X, targetHRP.Position.Y + heightOffset, aim.Z)
    return aim
end

local function isInHitRange(targetHRP)
    if not targetHRP then return false end
    local dist = (hrp.Position - targetHRP.Position).Magnitude
    local range = inDefensiveMode and (UI.AttackRange - 0.5) or (UI.AttackRange + 0.6)
    return dist <= range
end

-- ===== Enhanced Pathfinding with Combat Awareness =====
local currentPath = nil
local currentWaypoints = {}
local waypointIndex = 1
local pathTarget = nil
local lastPathTime = 0
local lastPos = hrp.Position
local stuckSince = nil

local function computePathAsync(targetPos)
    if not targetPos then return false end
    
    -- Adjust path computation based on health and combat state
    local agentRadius = inDefensiveMode and 3 or 2
    local path = PathfindingService:CreatePath({
        AgentRadius = agentRadius,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentMaxSlope = 30,
        WaypointSpacing = inDefensiveMode and 6 or 4,
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

-- Enhanced movement with combat positioning
local function followPathStep()
    if not currentPath or #currentWaypoints == 0 then return false end
    local wp = currentWaypoints[waypointIndex]
    if not wp then return false end

    if wp.Action == Enum.PathWaypointAction.Jump then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    humanoid:MoveTo(wp.Position)
    local threshold = inDefensiveMode and 3.5 or 2.5
    if (hrp.Position - wp.Position).Magnitude <= threshold then
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

-- Smart positioning based on health and combat state
local function getOptimalPosition(targetHRP)
    if not targetHRP then return hrp.Position end
    
    local healthPct = getHealthPercentage()
    local desiredDistance
    
    if retreatMode or healthPct <= UI.CriticalHealth then
        desiredDistance = RetreatDistance
    elseif inDefensiveMode or healthPct <= UI.HealthThreshold then
        desiredDistance = UI.DefensiveDistance
    else
        desiredDistance = UI.AggressiveDistance
    end
    
    local direction = (hrp.Position - targetHRP.Position).Unit
    return targetHRP.Position + (direction * desiredDistance)
end

local function simpleChase(targetHRP)
    local optimalPos = getOptimalPosition(targetHRP)
    humanoid:MoveTo(optimalPos)
end

-- Enhanced stuck detection with combat awareness
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
        -- Enhanced unstuck with dash if available
        if (now - DashLast) >= DashCooldown then
            pressKey("Q")  -- Dash to escape
            DashLast = now
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

-- Enhanced dash usage with tactical awareness
local function tryDashIfNeeded(dist, enemy)
    if not UI.DashDistance then return end
    
    local shouldDash = false
    
    -- Dash for gap closing
    if dist > UI.DashDistance and dist <= UI.MaxEngageDistance and not inDefensiveMode then
        shouldDash = true
    end
    
    -- Emergency dash when low health and enemy too close
    if retreatMode and dist < 8 then
        shouldDash = true
    end
    
    -- Dash to escape combos
    if enemy and enemy.Character then
        local enemyVel = enemy.Character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude
        if enemyVel > 15 and dist < 6 then
            shouldDash = true
        end
    end
    
    if shouldDash and (tick() - DashLast) >= DashCooldown then
        pressKey("Q")
        DashLast = tick()
    end
end

-- Enhanced attack system with skill prioritization
local lastAttack = 0
local backOffUntil = 0
local lastSkillUsed = ""

local function getOptimalSkill(distance, healthPct, inCombat)
    -- Prioritize skills based on situation
    if healthPct <= UI.CriticalHealth then
        -- Defensive/escape skills when critical
        if canCast("G") then return "G" end  -- Ultimate for emergency
        if canCast("R") then return "R" end  -- Special ability
    end
    
    if distance <= UI.AttackRange then
        -- Close range combat
        local meleeSkills = {"One", "Two", "Three", "Four"}
        for _, skill in ipairs(meleeSkills) do
            if canCast(skill) and lastSkillUsed ~= skill then
                return skill
            end
        end
    else
        -- Mid-long range
        if canCast("F") and distance > 6 then return "F" end
        if canCast("R") then return "R" end
    end
    
    return nil
end

local function doBackOffFrom(targetHRP)
    if not targetHRP then return end
    local dir = (hrp.Position - targetHRP.Position)
    if dir.Magnitude < 0.001 then dir = Vector3.new(0,0,1) end
    
    local backDistance = inDefensiveMode and (UI.BackOffDistance + 2) or UI.BackOffDistance
    local backpos = hrp.Position + dir.Unit * backDistance
    backOffUntil = tick() + (UI.BackOffTime or BackOffTime)
    humanoid:MoveTo(backpos)
end

-- Enhanced attack logic with better decision making
local function tryAttack(target, dist)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local tHRP = target.Character.HumanoidRootPart
    local healthPct = getHealthPercentage()

    -- Don't attack if in forced backoff or retreating
    if backOffUntil > tick() or retreatMode then
        return
    end

    -- Try blocking if enemy is aggressive
    if shouldBlock(target) then
        if tryBlock() then
            task.wait(0.2)
            return
        end
    end

    -- Get optimal skill for current situation
    local bestSkill = getOptimalSkill(dist, healthPct, true)
    
    if bestSkill then
        -- Use the selected skill
        pressKey(bestSkill)
        Cooldowns[bestSkill] = tick()
        lastSkillUsed = bestSkill
        lastAttack = tick()
        
        task.wait(0.1)
        mouseClickCenter()
        
        -- Conditional backoff based on health
        if healthPct <= UI.HealthThreshold or bestSkill == "G" then
            doBackOffFrom(tHRP)
        end
        
    elseif isInHitRange(tHRP) and not inDefensiveMode then
        -- Fallback M1 attack
        mouseClickCenter()
        lastAttack = tick()
        
        if healthPct <= UI.HealthThreshold then
            doBackOffFrom(tHRP)
        end
    end
end

-- Enhanced camera control with combat awareness
local function aimAtTarget(tHRP, dt)
    if not tHRP or not workspace.CurrentCamera then return end
    
    local aimPos = getAimPosition(tHRP)
    local cam = workspace.CurrentCamera
    local cur = cam.CFrame
    local targetCFrame = CFrame.new(cur.Position, aimPos)
    
    -- Adjust aiming speed based on combat state
    local aimSpeed = inDefensiveMode and (UI.AimSmoothing * 0.7) or UI.AimSmoothing
    local alpha = math.clamp(aimSpeed * dt, 0.04, 0.8)
    local newCFrame = cur:Lerp(targetCFrame, alpha)
    
    pcall(function()
        cam.CFrame = newCFrame
    end)
end

-- ===== Enhanced Main AI Loop =====
RunService.Heartbeat:Connect(function(dt)
    -- Refresh references if respawn occurred
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    if humanoid.Health <= 0 then return end

    -- Update combat state based on health
    local healthPct = getHealthPercentage()
    inDefensiveMode = shouldBeDefensive()
    retreatMode = shouldRetreat()
    
    -- Apply live UI values
    humanoid.WalkSpeed = retreatMode and (UI.MoveSpeed + 4) or UI.MoveSpeed

    if not AutoCombat then
        -- Reset states when disabled
        currentPath = nil
        currentWaypoints = {}
        waypointIndex = 1
        inDefensiveMode = false
        retreatMode = false
        return
    end

    -- Enhanced enemy detection
    local target, dist, dangerousEnemy = getNearestEnemy(UI.MaxEngageDistance)
    
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local tHRP = target.Character.HumanoidRootPart

        -- Enhanced camera aiming
        pcall(aimAtTarget, tHRP, dt)

        -- Enhanced dash logic
        tryDashIfNeeded(dist, target)

        -- Smart movement based on health and situation
        if retreatMode then
            -- Emergency retreat
            local retreatPos = hrp.Position + (hrp.Position - tHRP.Position).Unit * RetreatDistance
            humanoid:MoveTo(retreatPos)
            
        elseif UI.UsePathfinding then
            -- Enhanced pathfinding
            local needRepath = false
            if not currentPath then needRepath = true end
            if tick() - lastPathTime > RepathInterval then needRepath = true end
            if pathTarget and (pathTarget - tHRP.Position).Magnitude > 8 then needRepath = true end

            if needRepath then
                lastPathTime = tick()
                local targetPos = getOptimalPosition(tHRP)
                pcall(function() computePathAsync(targetPos) end)
            end

            if currentPath and #currentWaypoints > 0 then
                followPathStep()
            else
                simpleChase(tHRP)
            end
        else
            simpleChase(tHRP)
        end

        -- Enhanced attack behavior (only if not retreating)
        if not retreatMode then
            tryAttack(target, dist)
        end

        -- Enhanced unstuck detection
        detectAndResolveStuck()
        
    else
        -- No valid target: stop and reset
        humanoid:MoveTo(hrp.Position)
        currentPath = nil
        currentWaypoints = {}
        waypointIndex = 1
        inDefensiveMode = false
        retreatMode = false
    end
end)

-- ===== Enhanced Rayfield UI =====
if Rayfield then
    local Window = Rayfield:CreateWindow({
        Name = "Enhanced JJK Combat AI",
        LoadingTitle = "Enhanced Smart Combat",
        LoadingSubtitle = "W112ND - JJK POV AI v2.0",
        ConfigurationSaving = {Enabled = false},
        KeySystem = false,
    })
    
    local AITab = Window:CreateTab("Combat AI", 4483362458)
    AITab:CreateSection("Main Controls")

    AITab:CreateToggle({
        Name = "Enable Auto Combat",
        CurrentValue = AutoCombat,
        Flag = "AutoCombat",
        Callback = function(Value)
            AutoCombat = Value
            Rayfield:Notify({
                Title = "Enhanced Combat AI",
                Content = AutoCombat and "✅ AI Activated" or "❌ AI Stopped",
                Duration = 2
            })
            if not AutoCombat then
                currentPath = nil
                currentWaypoints = {}
                waypointIndex = 1
                backOffUntil = 0
                inDefensiveMode = false
                retreatMode = false
            end
        end
    })

    AITab:CreateToggle({
        Name = "Use Smart Pathfinding",
        CurrentValue = UI.UsePathfinding,
        Flag = "UsePath",
        Callback = function(Value) UI.UsePathfinding = Value end
    })

    AITab:CreateSection("Combat Settings")

    AITab:CreateSlider({
        Name = "Max Engage Distance",
        Range = {10, 60},
        Increment = 1,
        Suffix = "studs",
        CurrentValue = UI.MaxEngageDistance,
        Flag = "MaxDist",
        Callback = function(Value) UI.MaxEngageDistance = Value end
    })

    AITab:CreateSlider({
        Name = "Attack Range",
        Range = {2, 12},
        Increment = 0.5,
        Suffix = "studs",
        CurrentValue = UI.AttackRange,
        Flag = "AttackRange",
        Callback = function(Value) UI.AttackRange = Value end
    })

    AITab:CreateSlider({
        Name = "Dash Distance Trigger",
        Range = {6, 40},
        Increment = 1,
        Suffix = "studs",
        CurrentValue = UI.DashDistance,
        Flag = "DashDist",
        Callback = function(Value) UI.DashDistance = Value end
    })

    AITab:CreateSection("Health & Defense")

    AITab:CreateSlider({
        Name = "Health Threshold (Defensive Mode)",
        Range = {10, 80},
        Increment = 5,
        Suffix = "%",
        CurrentValue = UI.HealthThreshold,
        Flag = "HealthThreshold",
        Callback = function(Value) UI.HealthThreshold = Value end
    })

    AITab:CreateSlider({
        Name = "Critical Health (Retreat Mode)",
        Range = {5, 50},
        Increment = 5,
        Suffix = "%",
        CurrentValue = UI.CriticalHealth,
        Flag = "CriticalHealth",
        Callback = function(Value) UI.CriticalHealth = Value end
    })

    AITab:CreateSlider({
        Name = "Block Chance",
        Range = {0, 1},
        Increment = 0.1,
        CurrentValue = UI.BlockChance,
        Flag = "BlockChance",
        Callback = function(Value) UI.BlockChance = Value end
    })

    AITab:CreateSection("Movement & Positioning")

    AITab:CreateSlider({
        Name = "Movement Speed",
        Range = {8, 50},
        Increment = 1,
        Suffix = "WS",
        CurrentValue = UI.MoveSpeed,
        Flag = "MoveSpeed",
        Callback = function(Value) UI.MoveSpeed = Value end
    })

    AITab:CreateSlider({
        Name = "Defensive Distance",
        Range = {6, 20},
        Increment = 1,
        Suffix = "studs",
        CurrentValue = UI.DefensiveDistance,
        Flag = "DefensiveDistance",
        Callback = function(Value) UI.DefensiveDistance = Value end
    })

    AITab:CreateSlider({
        Name = "Aggressive Distance",
        Range = {2, 12},
        Increment = 0.5,
        Suffix = "studs",
        CurrentValue = UI.AggressiveDistance,
        Flag = "AggressiveDistance",
        Callback = function(Value) UI.AggressiveDistance = Value end
    })

    AITab:CreateSlider({
        Name = "Predictive Aim Factor",
        Range = {0, 0.5},
        Increment = 0.01,
        CurrentValue = UI.LeadFactor,
        Flag = "LeadFactor",
        Callback = function(Value) UI.LeadFactor = Value end
    })

    AITab:CreateSlider({
        Name = "Camera Smoothing",
        Range = {5, 25},
        Increment = 1,
        CurrentValue = UI.AimSmoothing,
        Flag = "AimSmoothing",
        Callback = function(Value) UI.AimSmoothing = Value end
    })

    AITab:CreateSection("Manual Controls")

    AITab:CreateButton({
        Name = "Emergency Block",
        Callback = function()
            pressKey("F")
            Rayfield:Notify({Title = "Manual", Content = "Emergency Block [F]", Duration = 1.5})
        end
    })

    AITab:CreateButton({
        Name = "Force Ultimate",
        Callback = function()
            pressKey("G")
            Rayfield:Notify({Title = "Manual", Content = "Ultimate Cast [G]", Duration = 2})
        end
    })

    AITab:CreateButton({
        Name = "Emergency Dash",
        Callback = function()
            pressKey("Q")
            Rayfield:Notify({Title = "Manual", Content = "Emergency Dash [Q]", Duration = 1.5})
        end
    })

    AITab:CreateLabel("Hotkey: K to toggle Auto Combat")
    AITab:CreateLabel("AI adapts based on your health!")
end

-- Enhanced hotkey system
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        AutoCombat = not AutoCombat
        if Rayfield then
            Rayfield:Notify({
                Title = "Enhanced Combat AI",
                Content = AutoCombat and "✅ AI Activated (Hotkey)" or "❌ AI Stopped (Hotkey)",
                Duration = 2
            })
        else
            print("Enhanced AutoCombat:", AutoCombat)
        end
        if not AutoCombat then
            currentPath = nil
            currentWaypoints = {}
            waypointIndex = 1
            backOffUntil = 0
            inDefensiveMode = false
            retreatMode = false
        end
    end
end)

-- Final enhanced load notice
if Rayfield then
    Rayfield:Notify({
        Title = "Enhanced JJK AI Loaded",
        Content = "🔥 Smart combat with health awareness, blocking, and tactical positioning!",
        Duration = 5
    })
else
    print("[Enhanced JJK AI] Loaded without Rayfield UI. Use hotkey K to toggle Auto Combat.")
end
