-- Enhanced Smart POV Auto-Combat with Intelligence Modes
-- Smart Fighter vs Aggressive Rusher behaviors for Jujutsu Shenanigans

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
    -- Reset combat state on respawn
    combatState = "Idle"
    targetHistory = {}
    dangerLevel = 0
end)

-- ===== Rayfield UI (load) =====
local Rayfield
do
    local ok
    ok, Rayfield = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if not ok or not Rayfield then
        pcall(function()
            Rayfield = loadstring(game:HttpGet("https://raw.githack.com/sirius/menu/main/rayfield"))()
        end)
    end
    if not Rayfield then
        warn("[Enhanced AI] Rayfield failed to load. UI will not appear.")
    end
end

-- ===== Enhanced AI Configuration =====
local AutoCombat = false
local UsePathfinding = true

-- Combat Behavior Modes
local CombatMode = "Smart Fighter" -- "Smart Fighter" or "Aggressive Rusher"

-- Smart Fighter Configuration
local SmartConfig = {
    DashDistance = 20,
    MaxEngageDistance = 35,
    AttackRange = 4.5,
    MoveSpeed = 16,
    LeadFactor = 0.25,
    BackOffDistance = 8,
    BackOffTime = 0.6,
    AimSmoothing = 8,
    ReactionTime = 0.15,
    BlockChance = 0.7,
    DodgeChance = 0.6,
    RetreatHealth = 30,
    ComboLength = 3,
    SkillPriority = true,
}

-- Aggressive Fighter Configuration  
local AggressiveConfig = {
    DashDistance = 25,
    MaxEngageDistance = 40,
    AttackRange = 5,
    MoveSpeed = 20,
    LeadFactor = 0.1,
    BackOffDistance = 4,
    BackOffTime = 0.2,
    AimSmoothing = 15,
    ReactionTime = 0.05,
    BlockChance = 0.2,
    DodgeChance = 0.3,
    RetreatHealth = 15,
    ComboLength = 5,
    SkillPriority = false,
}

-- Active configuration (switches based on mode)
local Config = SmartConfig

-- Enhanced Combat Intelligence
local combatState = "Idle" -- Idle, Stalking, Rushing, Attacking, Blocking, Retreating
local targetHistory = {}
local predictedPosition = Vector3.new()
local dangerLevel = 0
local lastStateChange = 0

-- Skill mapping and enhanced cooldowns
local SkillKeys = {"One","Two","Three","Four","F","G"}
local SmartKeyTimes = {One=2.8, Two=4.2, Three=6.5, Four=8.5, F=6, G=25}
local AggressiveKeyTimes = {One=1.8, Two=2.5, Three=4, Four=5.5, F=4, G=18}
local Cooldowns = {}

-- Combat timing
local DashLast = 0
local DashCooldown = 1
local lastAttack = 0
local backOffUntil = 0
local comboCount = 0
local lastComboTime = 0

-- Pathfinding state
local currentPath = nil
local currentWaypoints = {}
local waypointIndex = 1
local pathTarget = nil
local lastPathTime = 0
local RepathInterval = 0.4

-- Movement tracking
local lastPos = hrp.Position
local stuckSince = nil
local StuckThreshold = 1.5

-- ===== Helper Functions =====
local function getCurrentKeyTimes()
    return (CombatMode == "Smart Fighter") and SmartKeyTimes or AggressiveKeyTimes
end

local function canCast(key)
    local last = Cooldowns[key]
    if not last then return true end
    local keyTimes = getCurrentKeyTimes()
    return (tick() - last) >= (keyTimes[key] or 1)
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
        warn("[Enhanced AI] VirtualInputManager not available for key simulation.")
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
    end
end

local function getNearestEnemy(maxDist)
    local nearest, dist = nil, maxDist or Config.MaxEngageDistance
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

-- ===== Enhanced Target Prediction =====
local function updateTargetPrediction(targetHRP)
    if not targetHRP then return end
    
    -- Store target movement history
    local currentTime = tick()
    local currentPos = targetHRP.Position
    
    table.insert(targetHistory, {
        position = currentPos,
        time = currentTime
    })
    
    -- Keep only recent history (last 10 entries)
    if #targetHistory > 10 then
        table.remove(targetHistory, 1)
    end
    
    -- Calculate predicted position based on movement pattern
    if #targetHistory >= 2 then
        local recent = targetHistory[#targetHistory]
        local previous = targetHistory[#targetHistory - 1]
        local velocity = (recent.position - previous.position) / (recent.time - previous.time)
        
        -- Predict future position with lead factor
        local predictionTime = Config.ReactionTime + Config.LeadFactor
        predictedPosition = currentPos + (velocity * predictionTime)
    else
        predictedPosition = currentPos
    end
end

-- ===== Danger Assessment for Smart AI =====
local function assessDangerLevel(target, distance)
    if CombatMode ~= "Smart Fighter" then
        dangerLevel = 0.2 -- Aggressive mode doesn't care much about danger
        return dangerLevel
    end
    
    local danger = 0
    
    -- Distance-based danger
    if distance < 5 then danger = danger + 0.6
    elseif distance < 10 then danger = danger + 0.3
    elseif distance < 15 then danger = danger + 0.1
    
    -- Health-based danger
    local healthPercent = humanoid.Health / humanoid.MaxHealth
    if healthPercent < 0.2 then danger = danger + 0.8
    elseif healthPercent < 0.4 then danger = danger + 0.5
    elseif healthPercent < 0.6 then danger = danger + 0.2
    
    -- Environmental danger (obstacles, walls)
    if target and target.Character then
        local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
        if targetHRP then
            local raycast = workspace:Raycast(hrp.Position, (targetHRP.Position - hrp.Position).Unit * 8)
            if raycast then danger = danger + 0.3 end
        end
    end
    
    dangerLevel = math.min(danger, 1.0)
    return dangerLevel
end

-- ===== Enhanced Combat State Management =====
local function updateCombatState(target, distance)
    if not target then
        combatState = "Idle"
        return
    end
    
    local currentTime = tick()
    assessDangerLevel(target, distance)
    
    -- State transition logic based on combat mode
    if CombatMode == "Smart Fighter" then
        -- Smart Fighter State Logic
        if humanoid.Health < SmartConfig.RetreatHealth then
            combatState = "Retreating"
        elseif dangerLevel > 0.7 and math.random() < SmartConfig.BlockChance then
            combatState = "Blocking"
        elseif dangerLevel > 0.5 and math.random() < SmartConfig.DodgeChance then
            combatState = "Dodging"
        elseif distance > SmartConfig.MaxEngageDistance * 0.7 then
            combatState = "Stalking"
        elseif distance <= SmartConfig.AttackRange + 2 then
            combatState = "Attacking"
        else
            combatState = "Stalking"
        end
    else
        -- Aggressive Fighter State Logic
        if humanoid.Health < AggressiveConfig.RetreatHealth then
            combatState = "Retreating"
        elseif distance > AggressiveConfig.AttackRange + 5 then
            combatState = "Rushing"
        elseif distance <= AggressiveConfig.AttackRange + 2 then
            combatState = "Attacking"
        else
            combatState = "Rushing"
        end
    end
    
    lastStateChange = currentTime
end

-- ===== Enhanced Aim System =====
local function getEnhancedAimPosition(targetHRP)
    if not targetHRP then return hrp.Position end
    
    local basePos = targetHRP.Position
    
    if CombatMode == "Smart Fighter" then
        -- Use predicted position for smart aiming
        local aim = predictedPosition
        -- Adjust for torso targeting (not head)
        aim = Vector3.new(aim.X, basePos.Y + 1.5, aim.Z)
        return aim
    else
        -- Direct aggressive aiming
        local vel = Vector3.new(0,0,0)
        if targetHRP.AssemblyLinearVelocity then 
            vel = targetHRP.AssemblyLinearVelocity 
        end
        local aim = basePos + vel * Config.LeadFactor
        aim = Vector3.new(aim.X, basePos.Y + 1.5, aim.Z)
        return aim
    end
end

local function aimAtTarget(tHRP, dt)
    if not tHRP or not workspace.CurrentCamera then return end
    local aimPos = getEnhancedAimPosition(tHRP)
    local cam = workspace.CurrentCamera
    local cur = cam.CFrame
    local targetCFrame = CFrame.new(cur.Position, aimPos)
    local alpha = math.clamp(Config.AimSmoothing * dt, 0.04, 0.8)
    local newCFrame = cur:Lerp(targetCFrame, alpha)
    pcall(function()
        cam.CFrame = newCFrame
    end)
end

-- ===== Enhanced Attack System =====
local function isInHitRange(targetHRP)
    if not targetHRP then return false end
    local dist = (hrp.Position - targetHRP.Position).Magnitude
    return dist <= (Config.AttackRange + 0.8)
end

local function performSmartCombo(target)
    local keyTimes = getCurrentKeyTimes()
    local maxCombo = Config.ComboLength or 3
    
    -- Smart skill priority: use skills strategically
    if Config.SkillPriority then
        -- Try skills 1-4 in order of availability and effectiveness
        for i = 1, 4 do
            local key = SkillKeys[i]
            if key and canCast(key) and comboCount < maxCombo then
                pressKey(key)
                Cooldowns[key] = tick()
                comboCount = comboCount + 1
                lastComboTime = tick()
                task.wait(0.12)
                mouseClickCenter()
                return true
            end
        end
    end
    
    -- Fallback to basic attack
    if comboCount < maxCombo then
        mouseClickCenter()
        comboCount = comboCount + 1
        lastComboTime = tick()
        return true
    end
    
    return false
end

local function performAggressiveCombo(target)
    local maxCombo = Config.ComboLength or 5
    
    -- Aggressive: spam attacks quickly
    for i = 1, math.min(3, maxCombo - comboCount) do
        mouseClickCenter()
        comboCount = comboCount + 1
        task.wait(0.08)
    end
    
    -- Mix in skills aggressively
    if math.random() < 0.6 then
        for i = 1, 4 do
            local key = SkillKeys[i]
            if key and canCast(key) then
                pressKey(key)
                Cooldowns[key] = tick()
                task.wait(0.06)
                break
            end
        end
    end
    
    lastComboTime = tick()
    return true
end

local function doBackOffFrom(targetHRP)
    if not targetHRP then return end
    local dir = (hrp.Position - targetHRP.Position)
    if dir.Magnitude < 0.001 then dir = Vector3.new(0,0,1) end
    local backpos = hrp.Position + dir.Unit * Config.BackOffDistance
    backOffUntil = tick() + Config.BackOffTime
    humanoid:MoveTo(backpos)
end

local function tryEnhancedAttack(target, dist)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local tHRP = target.Character.HumanoidRootPart

    -- Respect backoff timer
    if backOffUntil > tick() then return end

    -- Reset combo if too much time has passed
    if tick() - lastComboTime > 2 then
        comboCount = 0
    end

    -- Enhanced attack logic based on combat state
    if combatState == "Attacking" and isInHitRange(tHRP) then
        local attackSuccess = false
        
        if CombatMode == "Smart Fighter" then
            attackSuccess = performSmartCombo(target)
        else
            attackSuccess = performAggressiveCombo(target)
        end
        
        if attackSuccess then
            lastAttack = tick()
            -- Smart fighters back off more, aggressive fighters less
            doBackOffFrom(tHRP)
        end
        
    elseif combatState == "Blocking" then
        -- Try to use F key for blocking/countering
        if canCast("F") then
            pressKey("F")
            Cooldowns["F"] = tick()
        end
        
    elseif combatState == "Dodging" then
        -- Evasive movement with possible counter
        local dodgeDirection = Vector3.new(math.random(-1,1), 0, math.random(-1,1)).Unit
        humanoid:MoveTo(hrp.Position + dodgeDirection * 6)
        humanoid.Jump = true
        
        -- Counter-attack after dodge
        task.wait(0.3)
        if isInHitRange(tHRP) then
            mouseClickCenter()
        end
        
    elseif not isInHitRange(tHRP) then
        -- Try ranged/gap-closing skills (F, G)
        for i = 5, #SkillKeys do
            local key = SkillKeys[i]
            if key and canCast(key) then
                pressKey(key)
                Cooldowns[key] = tick()
                lastAttack = tick()
                return
            end
        end
    end
end

-- ===== Enhanced Movement System =====
local function tryDashIfNeeded(dist)
    if dist > Config.DashDistance and dist <= Config.MaxEngageDistance then
        if (tick() - DashLast) >= DashCooldown then
            pressKey("Q")
            DashLast = tick()
        end
    end
end

local function computePathAsync(targetPos)
    if not targetPos then return false end
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentMaxSlope = 35,
    })
    local ok = pcall(function()
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
    if (hrp.Position - wp.Position).Magnitude <= 2.8 then
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

local function executeMovementBehavior(target, tHRP, dist)
    if combatState == "Stalking" then
        -- Smart stalking: use predicted position
        local moveTarget = (CombatMode == "Smart Fighter") and predictedPosition or tHRP.Position
        
        if UsePathfinding then
            local needRepath = false
            if not currentPath then needRepath = true end
            if tick() - lastPathTime > RepathInterval then needRepath = true end
            if pathTarget and (pathTarget - moveTarget).Magnitude > 5 then needRepath = true end

            if needRepath then
                pcall(function() computePathAsync(moveTarget) end)
            end

            if not followPathStep() then
                humanoid:MoveTo(moveTarget)
            end
        else
            humanoid:MoveTo(moveTarget)
        end
        
    elseif combatState == "Rushing" then
        -- Aggressive rushing: direct path to target
        humanoid:MoveTo(tHRP.Position)
        
    elseif combatState == "Retreating" then
        -- Strategic retreat
        local dir = (hrp.Position - tHRP.Position)
        if dir.Magnitude < 0.001 then dir = Vector3.new(0,0,1) end
        local retreatPos = hrp.Position + dir.Unit * 15
        humanoid:MoveTo(retreatPos)
    end
end

local function detectAndResolveStuck()
    local now = tick()
    if (hrp.Position - lastPos).Magnitude > 0.5 then
        stuckSince = nil
        lastPos = hrp.Position
        return
    end

    if not stuckSince then
        stuckSince = now
    elseif (now - stuckSince) > StuckThreshold then
        -- Enhanced unstuck: jump + random direction
        humanoid.Jump = true
        local angle = math.rad(math.random(0,360))
        local offset = Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4)
        humanoid:MoveTo(hrp.Position + offset)
        stuckSince = nil
        lastPos = hrp.Position
    end
end

-- ===== Main Enhanced AI Loop =====
RunService.Heartbeat:Connect(function(dt)
    -- Refresh references if needed
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    if humanoid.Health <= 0 then return end

    -- Apply configuration based on combat mode
    Config = (CombatMode == "Smart Fighter") and SmartConfig or AggressiveConfig
    humanoid.WalkSpeed = Config.MoveSpeed

    if not AutoCombat then
        currentPath = nil
        currentWaypoints = {}
        waypointIndex = 1
        combatState = "Idle"
        return
    end

    -- Find and engage target
    local target, dist = getNearestEnemy(Config.MaxEngageDistance)
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local tHRP = target.Character.HumanoidRootPart

        -- Enhanced AI processing
        updateTargetPrediction(tHRP)
        updateCombatState(target, dist)
        
        -- Enhanced aiming
        aimAtTarget(tHRP, dt)

        -- Enhanced dash logic
        tryDashIfNeeded(dist)

        -- Enhanced movement based on combat state
        executeMovementBehavior(target, tHRP, dist)

        -- Enhanced attack system
        tryEnhancedAttack(target, dist)

        -- Unstuck detection
        detectAndResolveStuck()
    else
        -- No target: idle
        humanoid:MoveTo(hrp.Position)
        currentPath = nil
        currentWaypoints = {}
        waypointIndex = 1
        combatState = "Idle"
    end
end)

-- ===== Enhanced Rayfield UI =====
if Rayfield then
    local Window = Rayfield:CreateWindow({
        Name = "🥊 Enhanced Jujutsu AI",
        LoadingTitle = "Smart Combat AI",
        LoadingSubtitle = "W112ND - Enhanced Intelligence",
        ConfigurationSaving = {Enabled = true, FolderName = "JujutsuAI", FileName = "EnhancedAI"},
        KeySystem = false,
    })
    
    local AITab = Window:CreateTab("🤖 Combat AI", 4483362458)
    local BehaviorTab = Window:CreateTab("🧠 Intelligence", 4483362458)
    local ConfigTab = Window:CreateTab("⚙️ Configuration", 4483362458)
    
    AITab:CreateSection("Main Controls")

    AITab:CreateToggle({
        Name = "🤖 Enable Auto Combat",
        CurrentValue = AutoCombat,
        Flag = "AutoCombat",
        Callback = function(Value)
            AutoCombat = Value
            Rayfield:Notify({
                Title = "Auto Combat",
                Content = AutoCombat and "✅ AI Activated" or "❌ AI Stopped",
                Duration = 2.5
            })
            if not AutoCombat then
                currentPath = nil
                currentWaypoints = {}
                waypointIndex = 1
                backOffUntil = 0
                combatState = "Idle"
            end
        end
    })

    AITab:CreateDropdown({
        Name = "🎭 Combat Behavior",
        Options = {"Smart Fighter", "Aggressive Rusher"},
        CurrentOption = CombatMode,
        Flag = "CombatMode",
        Callback = function(Option)
            CombatMode = Option
            Config = (Option == "Smart Fighter") and SmartConfig or AggressiveConfig
            Rayfield:Notify({
                Title = "Combat Mode",
                Content = "Switched to " .. Option,
                Duration = 2
            })
        end,
    })

    AITab:CreateToggle({
        Name = "🗺️ Use Pathfinding",
        CurrentValue = UsePathfinding,
        Flag = "UsePath",
        Callback = function(Value) UsePathfinding = Value end
    })

    -- Behavior Configuration Tab
    BehaviorTab:CreateSection("🎯 Smart Fighter Settings")

    BehaviorTab:CreateSlider({
        Name = "🧠 Smart Reaction Time",
        Range = {0.05, 0.4},
        Increment = 0.01,
        Suffix = "s",
        CurrentValue = SmartConfig.ReactionTime,
        Flag = "SmartReaction",
        Callback = function(Value) SmartConfig.ReactionTime = Value end
    })

    BehaviorTab:CreateSlider({
        Name = "🛡️ Block Chance (Smart)",
        Range = {0.1, 1.0},
        Increment = 0.05,
        CurrentValue = SmartConfig.BlockChance,
        Flag = "SmartBlock",
        Callback = function(Value) SmartConfig.BlockChance = Value end
    })

    BehaviorTab:CreateSlider({
        Name = "💨 Dodge Chance (Smart)",
        Range = {0.1, 1.0},
        Increment = 0.05,
        CurrentValue = SmartConfig.DodgeChance,
        Flag = "SmartDodge",
        Callback = function(Value) SmartConfig.DodgeChance = Value end
    })

    BehaviorTab:CreateSection("⚔️ Aggressive Fighter Settings")

    BehaviorTab:CreateSlider({
        Name = "⚡ Aggressive Reaction Time",
        Range = {0.01, 0.2},
        Increment = 0.01,
        Suffix = "s",
        CurrentValue = AggressiveConfig.ReactionTime,
        Flag = "AggroReaction",
        Callback = function(Value) AggressiveConfig.ReactionTime = Value end
    })

    BehaviorTab:CreateSlider({
        Name = "🥊 Combo Length (Aggressive)",
        Range = {3, 8},
        Increment = 1,
        CurrentValue = AggressiveConfig.ComboLength,
        Flag = "AggroCombo",
        Callback = function(Value) AggressiveConfig.ComboLength = Value end
    })

    -- Configuration Tab
    ConfigTab:CreateSection("📏 Distance Settings")

    ConfigTab:CreateSlider({
        Name = "🎯 Max Engage Distance",
        Range = {15, 60},
        Increment = 1,
        Suffix = " studs",
        CurrentValue = SmartConfig.MaxEngageDistance,
        Flag = "MaxDist",
        Callback = function(Value) 
            SmartConfig.MaxEngageDistance = Value
            AggressiveConfig.MaxEngageDistance = Value + 5
        end
    })

    ConfigTab:CreateSlider({
        Name = "💨 Dash Distance",
        Range = {8, 35},
        Increment = 1,
        Suffix = " studs", 
        CurrentValue = SmartConfig.DashDistance,
        Flag = "DashDist",
        Callback = function(Value)
            SmartConfig.DashDistance = Value
            AggressiveConfig.DashDistance = Value + 5
        end
    })

    ConfigTab:CreateSlider({
        Name = "⚔️ Attack Range",
        Range = {2, 8},
        Increment = 0.5,
        Suffix = " studs",
        CurrentValue = SmartConfig.AttackRange,
        Flag = "AttackRange",
        Callback = function(Value)
            SmartConfig.AttackRange = Value
            AggressiveConfig.AttackRange = Value + 0.5
        end
    })

    ConfigTab:CreateSection("🏃 Movement Settings")

    ConfigTab:CreateSlider({
        Name = "🚶 Smart Move Speed",
        Range = {12, 25},
        Increment = 1,
        Suffix = " WS",
        CurrentValue = SmartConfig.MoveSpeed,
        Flag = "SmartSpeed",
        Callback = function(Value) SmartConfig.MoveSpeed = Value end
    })

    ConfigTab:CreateSlider({
        Name = "🏃 Aggressive Move Speed", 
        Range = {16, 35},
        Increment = 1,
        Suffix = " WS",
        CurrentValue = AggressiveConfig.MoveSpeed,
        Flag = "AggroSpeed",
        Callback = function(Value) AggressiveConfig.MoveSpeed = Value end
    })

    ConfigTab:CreateSlider({
        Name = "🔮 Lead Factor (Prediction)",
        Range = {0, 0.5},
        Increment = 0.01,
        CurrentValue = SmartConfig.LeadFactor,
        Flag = "LeadFactor",
        Callback = function(Value)
            SmartConfig.LeadFactor = Value
            AggressiveConfig.LeadFactor = Value * 0.4
        end
    })

    -- Manual controls
    AITab:CreateSection("🎮 Manual Controls")

    AITab:CreateButton({
        Name = "💥 Force Ultimate (G)",
        Callback = function()
            pressKey("G")
            Rayfield:Notify({Title = "Manual", Content = "Ultimate [G] Activated", Duration = 2})
        end
    })

    AITab:CreateButton({
        Name = "💨 Force Dash (Q)",
        Callback = function()
            pressKey("Q")
            Rayfield:Notify({Title = "Manual", Content = "Dash [Q] Activated", Duration = 1.5})
        end
    })

    -- Status display
    AITab:CreateLabel("Current State: " .. combatState)
    AITab:CreateLabel("Danger Level: " .. tostring(math.floor(dangerLevel * 100)) .. "%")
    AITab:CreateLabel("Hotkey: K to toggle Combat AI")
end

-- Hotkey toggle
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        AutoCombat = not AutoCombat
        if Rayfield then
            Rayfield:Notify({
                Title = "Auto Combat",
                Content = AutoCombat and "✅ AI Activated (K)" or "❌ AI Stopped (K)",
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
            combatState = "Idle"
        end
    end
end)

-- Final load notification
if Rayfield then
    Rayfield:Notify({
        Title = "🥊 Enhanced AI Loaded",
        Content = "Smart Fighter vs Aggressive Rusher modes ready! Press K to toggle.",
        Duration = 4
    })
else
    print("[Enhanced AI] Loaded without UI. Use hotkey K to toggle Auto Combat.")
        end
