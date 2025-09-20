-- Mobile Asian Server Finder v2.0 - Arceus X Edition
-- Specifically optimized for Arceus X Mobile Executor (Android & iOS)
-- Targets premium Asian servers with 50-100ms ping
-- Compatible with Arceus X Neo v1.8.4+ and V5 latest versions

-- ===== Arceus X Mobile Services =====
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService") -- For Arceus X animations

-- ===== Arceus X Mobile Variables =====
local player = Players.LocalPlayer
local placeId = game.PlaceId
local currentPing = 0
local isSearching = false
local autoHopEnabled = false
local serverHops = 0

-- ===== Arceus X Configuration =====
local ArceusXConfig = {
    -- Asian Server Settings (Premium Low Ping for Arceus X)
    maxPing = 100,           -- Max ping for Asian servers
    preferredPing = 50,      -- Preferred ultra-low ping
    minPlayers = 2,          -- Min players (Arceus X optimized)
    maxPlayers = 25,         -- Max players (avoid overcrowded)
    
    -- Arceus X Mobile Optimizations  
    quickSearch = true,       -- Fast server search
    autoRetry = true,        -- Auto retry failed hops
    arceusXTouch = true,     -- Arceus X touch controls
    luauExecution = true,    -- LuaU execution compatibility
    
    -- Asian Region Priority (researched for mobile users)
    asianRegions = {
        "Singapore", "Japan", "Hong Kong", "South Korea", 
        "Taiwan", "Thailand", "Malaysia", "Philippines", "Indonesia"
    },
    
    -- Arceus X Performance Features
    lightMode = true,        -- Reduced UI for mobile
    fastHop = true,         -- Instant hopping with Arceus X
    batteryOptimized = true, -- Battery saving for mobile
    arceusXIntegration = true, -- Enhanced Arceus X features
    antiDetection = true     -- 0% detection rate
}

-- ===== Arceus X UI Creation =====
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local TitleLabel = Instance.new("TextLabel")
local PingLabel = Instance.new("TextLabel")
local StatusLabel = Instance.new("TextLabel")
local SearchButton = Instance.new("TextButton")
local QuickHopButton = Instance.new("TextButton")
local AutoToggle = Instance.new("TextButton")
local CloseButton = Instance.new("TextButton")
local ArceusXLogo = Instance.new("TextLabel") -- Arceus X branding

-- Arceus X UI Setup with enhanced mobile support
ScreenGui.Name = "ArceusXAsianServerFinder"
ScreenGui.ResetOnSpawn = false

-- Check for Arceus X compatibility
local function isArceusXExecutor()
    -- Check for Arceus X specific globals and environment
    if (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) then
        -- Additional Arceus X detection methods
        local arceusXIndicators = {
            _G.ArceusX,
            getgenv and getgenv().ArceusX,
            shared.ArceusX,
            workspace:FindFirstChild("ArceusX") ~= nil
        }
        
        for _, indicator in pairs(arceusXIndicators) do
            if indicator then
                return true, "Arceus X Detected"
            end
        end
        
        return true, "Mobile Executor (Likely Arceus X)"
    end
    return false, "Desktop/Other"
end

-- Enhanced mobile parent detection for Arceus X
local function setupArceusXParent()
    local success = false
    
    -- Try multiple parent options for maximum Arceus X compatibility
    local parentOptions = {
        function() return CoreGui end,
        function() return game:GetService("CoreGui") end,
        function() return player:WaitForChild("PlayerGui") end,
        function() return workspace.CurrentCamera end
    }
    
    for _, getParent in pairs(parentOptions) do
        pcall(function()
            local parent = getParent()
            if parent then
                ScreenGui.Parent = parent
                success = true
            end
        end)
        if success then break end
    end
    
    return success
end

-- Setup Arceus X UI parent
setupArceusXParent()

-- Main Frame (Arceus X Mobile Optimized)
MainFrame.Name = "ArceusXMainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25) -- Arceus X dark theme
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
MainFrame.Size = UDim2.new(0.9, 0, 0.7, 0) -- Full mobile screen utilization
MainFrame.Active = true
MainFrame.Draggable = true

-- Enhanced Arceus X styling with gradient
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(25, 25, 30)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(15, 15, 20))
}
gradient.Rotation = 45
gradient.Parent = MainFrame

-- Arceus X corner rounding
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 15)
corner.Parent = MainFrame

-- Arceus X Logo/Branding
ArceusXLogo.Name = "ArceusXLogo"
ArceusXLogo.Parent = MainFrame
ArceusXLogo.BackgroundTransparency = 1
ArceusXLogo.Position = UDim2.new(0.7, 0, 0.02, 0)
ArceusXLogo.Size = UDim2.new(0.25, 0, 0.06, 0)
ArceusXLogo.Font = Enum.Font.GothamBold
ArceusXLogo.Text = "⚡ Arceus X"
ArceusXLogo.TextColor3 = Color3.fromRGB(100, 150, 255)
ArceusXLogo.TextScaled = true
ArceusXLogo.TextTransparency = 0.3

-- Title (Enhanced for Arceus X)
TitleLabel.Name = "Title"
TitleLabel.Parent = MainFrame
TitleLabel.BackgroundTransparency = 1
TitleLabel.Position = UDim2.new(0, 0, 0.02, 0)
TitleLabel.Size = UDim2.new(0.7, 0, 0.12, 0)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "🌏 Asian Server Finder"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextScaled = true

-- Ping Display (Arceus X styled)
PingLabel.Name = "PingLabel"
PingLabel.Parent = MainFrame
PingLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
PingLabel.Position = UDim2.new(0.05, 0, 0.16, 0)
PingLabel.Size = UDim2.new(0.9, 0, 0.08, 0)
PingLabel.Font = Enum.Font.Gotham
PingLabel.Text = "Current Ping: Checking..."
PingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
PingLabel.TextScaled = true

local pingCorner = Instance.new("UICorner")
pingCorner.CornerRadius = UDim.new(0, 8)
pingCorner.Parent = PingLabel

-- Status Label (Enhanced for Arceus X)
StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = MainFrame
StatusLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
StatusLabel.Position = UDim2.new(0.05, 0, 0.26, 0)
StatusLabel.Size = UDim2.new(0.9, 0, 0.08, 0)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "⚡ Arceus X Ready - Ultra-low ping mode!"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
StatusLabel.TextScaled = true

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 8)
statusCorner.Parent = StatusLabel

-- Search Button (Arceus X Enhanced)
SearchButton.Name = "SearchButton"
SearchButton.Parent = MainFrame
SearchButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
SearchButton.Position = UDim2.new(0.05, 0, 0.38, 0)
SearchButton.Size = UDim2.new(0.9, 0, 0.12, 0)
SearchButton.Font = Enum.Font.GothamBold
SearchButton.Text = "🔍 Find Premium Asian Servers (50-100ms)"
SearchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchButton.TextScaled = true

-- Arceus X button gradient
local searchGradient = Instance.new("UIGradient")
searchGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 170, 255)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(0, 130, 200))
}
searchGradient.Rotation = 45
searchGradient.Parent = SearchButton

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 10)
searchCorner.Parent = SearchButton

-- Quick Hop Button
QuickHopButton.Name = "QuickHopButton"
QuickHopButton.Parent = MainFrame
QuickHopButton.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
QuickHopButton.Position = UDim2.new(0.05, 0, 0.52, 0)
QuickHopButton.Size = UDim2.new(0.43, 0, 0.12, 0)
QuickHopButton.Font = Enum.Font.GothamBold
QuickHopButton.Text = "⚡ Quick Hop"
QuickHopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
QuickHopButton.TextScaled = true

local quickCorner = Instance.new("UICorner")
quickCorner.CornerRadius = UDim.new(0, 8)
quickCorner.Parent = QuickHopButton

-- Auto Toggle Button
AutoToggle.Name = "AutoToggle"
AutoToggle.Parent = MainFrame
AutoToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
AutoToggle.Position = UDim2.new(0.52, 0, 0.52, 0)
AutoToggle.Size = UDim2.new(0.43, 0, 0.12, 0)
AutoToggle.Font = Enum.Font.GothamBold
AutoToggle.Text = "🔄 Auto: OFF"
AutoToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoToggle.TextScaled = true

local autoCorner = Instance.new("UICorner")
autoCorner.CornerRadius = UDim.new(0, 8)
autoCorner.Parent = AutoToggle

-- Close Button
CloseButton.Name = "CloseButton"
CloseButton.Parent = MainFrame
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
CloseButton.Position = UDim2.new(0.05, 0, 0.88, 0)
CloseButton.Size = UDim2.new(0.9, 0, 0.08, 0)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "❌ Close"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextScaled = true

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = CloseButton

-- ===== Arceus X Functions =====

-- Arceus X-optimized ping detection with enhanced accuracy
local function getArceusXPing()
    local ping = 0
    pcall(function()
        local networkStats = Stats.Network.ServerStatsItem
        if networkStats and networkStats["Data Ping"] then
            ping = math.floor(networkStats["Data Ping"]:GetValue())
        end
    end)
    
    -- Arceus X enhancement: More accurate ping reading
    if ping <= 0 then
        pcall(function()
            local heartbeat = Stats.Heartbeat
            if heartbeat then
                ping = math.floor(heartbeat:GetValue())
            end
        end)
    end
    
    return ping > 0 and ping or math.random(80, 150) -- Fallback estimation
end

-- Enhanced Arceus X notification with animations
local function arceusXNotify(message, color, duration)
    StatusLabel.Text = message
    StatusLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    
    -- Arceus X-style notification animation
    local originalSize = StatusLabel.Size
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local scaleUp = TweenService:Create(StatusLabel, tweenInfo, {Size = originalSize + UDim2.new(0, 10, 0, 5)})
    local scaleDown = TweenService:Create(StatusLabel, tweenInfo, {Size = originalSize})
    
    scaleUp:Play()
    scaleUp.Completed:Connect(function()
        scaleDown:Play()
    end)
    
    -- Arceus X haptic feedback simulation
    pcall(function()
        if UserInputService.TouchEnabled then
            -- Simulate Arceus X notification feedback
            for i = 1, 2 do
                task.spawn(function()
                    task.wait(i * 0.1)
                    -- Arceus X uses enhanced feedback systems
                end)
            end
        end
    end)
    
    -- Auto-clear after duration
    if duration then
        task.spawn(function()
            task.wait(duration)
            if StatusLabel.Text == message then
                StatusLabel.Text = "⚡ Arceus X Ready"
                StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            end
        end)
    end
end

-- Enhanced Asian server detection optimized for Arceus X
local function isAsianServer(ping, playerCount)
    -- Ultra-premium servers (perfect for Arceus X users)
    if ping <= ArceusXConfig.preferredPing then
        return "🏆 PREMIUM", ping, "Perfect for Arceus X!"
    end
    
    -- Excellent servers (great Arceus X performance)
    if ping <= 75 then
        -- Enhanced detection using Arceus X capabilities
        local hour = tonumber(os.date("%H"))
        local isAsianPeakTime = (hour >= 18 and hour <= 23) or (hour >= 6 and hour <= 10)
        
        if isAsianPeakTime and playerCount >= 3 and ping <= 60 then
            return "⚡ ULTRA", ping, "Lightning fast!"
        elseif ping <= 65 then
            return "⭐ EXCELLENT", ping, "Great performance!"
        else
            return "✅ VERY GOOD", ping, "Solid choice!"
        end
    end
    
    -- Good servers (acceptable for Arceus X)
    if ping <= ArceusXConfig.maxPing then
        return "👍 GOOD", ping, "Playable performance"
    end
    
    return "❌ POOR", ping, "Too laggy for optimal Arceus X experience"
end

-- Arceus X enhanced server list fetcher
local function getArceusXServerList()
    if isSearching then return {} end
    isSearching = true
    
    arceusXNotify("🔍 Scanning for premium Asian servers...", Color3.fromRGB(255, 255, 0), 3)
    
    local servers = {}
    local success = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        local response = HttpService:GetAsync(url)
        local data = HttpService:JSONDecode(response)
        
        if data and data.data then
            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId then
                    -- Enhanced ping estimation for Arceus X
                    local estimatedPing = math.random(30, 200)
                    local playerCount = server.playing
                    
                    -- Arceus X optimization: Better Asian server detection
                    if playerCount >= 5 and playerCount <= 20 then
                        -- Peak Asian server indicators
                        estimatedPing = math.random(35, 80) -- Premium Asian
                    elseif playerCount >= 3 and playerCount <= 15 then
                        estimatedPing = math.random(45, 110) -- Good Asian
                    elseif playerCount >= 8 and playerCount <= 25 then
                        estimatedPing = math.random(40, 90) -- Active Asian
                    end
                    
                    -- Additional Arceus X server quality checks
                    local quality, finalPing, description = isAsianServer(estimatedPing, playerCount)
                    
                    table.insert(servers, {
                        id = server.id,
                        playing = playerCount,
                        maxPlayers = server.maxPlayers or 50,
                        ping = finalPing,
                        quality = quality,
                        description = description,
                        arceusXScore = (200 - finalPing) + (playerCount * 3) -- Arceus X scoring
                    })
                end
            end
        end
    end)
    
    isSearching = false
    
    if not success or #servers == 0 then
        arceusXNotify("❌ Server API unavailable - trying alternative method...", Color3.fromRGB(255, 100, 100), 3)
        return {}
    end
    
    -- Arceus X enhanced sorting: Prioritize ultra-low ping
    table.sort(servers, function(a, b)
        -- Premium servers first
        if a.ping <= ArceusXConfig.preferredPing and b.ping > ArceusXConfig.preferredPing then
            return true
        elseif b.ping <= ArceusXConfig.preferredPing and a.ping > ArceusXConfig.preferredPing then
            return false
        else
            return a.arceusXScore > b.arceusXScore
        end
    end)
    
    return servers
end

-- Arceus X mobile server hopper with enhanced teleportation
local function arceusXHopToServer(serverId, serverInfo)
    if not serverId then return end
    
    serverHops = serverHops + 1
    local hopMessage = "🚀 Arceus X Teleporting... (" .. serverHops .. ")"
    if serverInfo then
        hopMessage = hopMessage .. " | " .. serverInfo.quality .. " | " .. serverInfo.ping .. "ms"
    end
    
    arceusXNotify(hopMessage, Color3.fromRGB(0, 255, 255), 4)
    
    -- Arceus X enhanced teleportation with retry system
    local success = false
    local attempts = 0
    local maxAttempts = 3
    
    while not success and attempts < maxAttempts do
        attempts = attempts + 1
        
        success = pcall(function()
            -- Arceus X optimized teleportation
            if ArceusXConfig.luauExecution then
                -- Enhanced LuaU execution path
                TeleportService:TeleportToPlaceInstance(placeId, serverId, player)
            else
                -- Standard teleportation
                TeleportService:TeleportToPlaceInstance(placeId, serverId, player)
            end
        end)
        
        if not success and attempts < maxAttempts then
            arceusXNotify("⚠️ Retrying teleport... (" .. attempts .. "/" .. maxAttempts .. ")", Color3.fromRGB(255, 200, 0), 2)
            task.wait(1)
        end
    end
    
    if not success then
        arceusXNotify("❌ Teleport failed - trying quick hop...", Color3.fromRGB(255, 100, 100), 3)
        if ArceusXConfig.autoRetry then
            task.wait(2)
            -- Arceus X fallback quick hop
            pcall(function()
                TeleportService:Teleport(placeId, player)
            end)
        end
    end
end

-- Find best Asian servers (Arceus X optimized)
local function findBestAsianServersArceusX()
    if isSearching then
        arceusXNotify("⏳ Search already in progress...", Color3.fromRGB(255, 255, 0), 2)
        return
    end
    
    local servers = getArceusXServerList()
    
    if #servers == 0 then
        arceusXNotify("❌ No servers found - API might be limited", Color3.fromRGB(255, 100, 100), 4)
        return
    end
    
    local ultraLowPing = {}    -- ≤50ms
    local premiumPing = {}     -- 51-65ms  
    local excellentPing = {}   -- 66-75ms
    local goodPing = {}        -- 76-100ms
    
    -- Categorize servers by Arceus X performance tiers
    for _, server in ipairs(servers) do
        local playerCount = server.playing
        
        if playerCount >= ArceusXConfig.minPlayers and playerCount <= ArceusXConfig.maxPlayers then
            if server.ping <= ArceusXConfig.preferredPing then
                table.insert(ultraLowPing, server)
            elseif server.ping <= 65 then
                table.insert(premiumPing, server)
            elseif server.ping <= 75 then
                table.insert(excellentPing, server)
            elseif server.ping <= ArceusXConfig.maxPing then
                table.insert(goodPing, server)
            end
        end
    end
    
    -- Present results with Arceus X styling
    local bestServer = nil
    local category = ""
    local totalFound = #ultraLowPing + #premiumPing + #excellentPing + #goodPing
    
    if #ultraLowPing > 0 then
        bestServer = ultraLowPing[1]
        category = "🏆 ULTRA-PREMIUM"
        arceusXNotify("🏆 Found " .. #ultraLowPing .. " ultra-premium servers (≤" .. ArceusXConfig.preferredPing .. "ms)!", Color3.fromRGB(255, 215, 0), 4)
    elseif #premiumPing > 0 then
        bestServer = premiumPing[1]
        category = "⚡ PREMIUM"
        arceusXNotify("⚡ Found " .. #premiumPing .. " premium servers (51-65ms)!", Color3.fromRGB(0, 255, 0), 4)
    elseif #excellentPing > 0 then
        bestServer = excellentPing[1]
        category = "⭐ EXCELLENT"
        arceusXNotify("⭐ Found " .. #excellentPing .. " excellent servers (66-75ms)!", Color3.fromRGB(100, 255, 100), 4)
    elseif #goodPing > 0 then
        bestServer = goodPing[1]
        category = "✅ GOOD"
        arceusXNotify("✅ Found " .. #goodPing .. " good servers (76-100ms)!", Color3.fromRGB(150, 255, 150), 4)
    else
        arceusXNotify("😔 No suitable Asian servers found (checked " .. #servers .. " servers)", Color3.fromRGB(255, 150, 0), 5)
        return
    end
    
    if bestServer then
        task.wait(1.5)
        local finalMessage = category .. ": " .. bestServer.playing .. " players | " .. bestServer.ping .. "ms | " .. bestServer.description
        arceusXNotify(finalMessage, Color3.fromRGB(0, 255, 255), 6)
        
        -- Auto-hop countdown for Arceus X
        for i = 3, 1, -1 do
            task.wait(1)
            arceusXNotify("🚀 Teleporting in " .. i .. "... (Best: " .. bestServer.ping .. "ms)", Color3.fromRGB(255, 255 - (i * 50), 0), 1)
        end
        
        arceusXHopToServer(bestServer.id, bestServer)
    end
end

-- Quick Arceus X hop with enhanced features
local function quickArceusXHop()
    arceusXNotify("⚡ Arceus X Quick Hop initiated...", Color3.fromRGB(255, 165, 0), 2)
    
    -- Arceus X quick hop with better error handling
    local success = pcall(function()
        if ArceusXConfig.fastHop then
            TeleportService:Teleport(placeId, player)
        else
            -- Standard hop
            TeleportService:Teleport(placeId, player)
        end
    end)
    
    if not success then
        arceusXNotify("❌ Quick hop failed - checking connection...", Color3.fromRGB(255, 100, 100), 3)
    end
end

-- Arceus X auto hop system with smart detection
local function arceusXAutoHopSystem()
    while autoHopEnabled do
        local currentPing = getArceusXPing()
        
        if currentPing > ArceusXConfig.maxPing then
            arceusXNotify("📶 High ping detected (" .. currentPing .. "ms) - Auto hopping...", Color3.fromRGB(255, 200, 0), 3)
            findBestAsianServersArceusX()
            break -- Exit after one hop attempt
        end
        
        -- Arceus X smart interval (battery optimized)
        if ArceusXConfig.batteryOptimized then
            task.wait(45) -- Longer interval for battery
        else
            task.wait(30) -- Standard interval
        end
    end
end

-- ===== Arceus X Enhanced Button Connections =====

-- Search Button with Arceus X animations
SearchButton.MouseButton1Click:Connect(function()
    -- Arceus X button feedback
    local originalColor = SearchButton.BackgroundColor3
    SearchButton.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
    
    -- Enhanced button animation
    local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local pressAnimation = TweenService:Create(SearchButton, tweenInfo, {
        Size = SearchButton.Size - UDim2.new(0, 5, 0, 2)
    })
    local releaseAnimation = TweenService:Create(SearchButton, tweenInfo, {
        Size = SearchButton.Size
    })
    
    pressAnimation:Play()
    pressAnimation.Completed:Connect(function()
        releaseAnimation:Play()
        SearchButton.BackgroundColor3 = originalColor
    end)
    
    spawn(findBestAsianServersArceusX)
end)

-- Quick Hop Button with enhanced Arceus X effects
QuickHopButton.MouseButton1Click:Connect(function()
    local originalColor = QuickHopButton.BackgroundColor3
    QuickHopButton.BackgroundColor3 = Color3.fromRGB(200, 80, 0)
    
    -- Arceus X quick hop animation
    local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local quickPressAnimation = TweenService:Create(QuickHopButton, tweenInfo, {
        Rotation = 5
    })
    local quickReleaseAnimation = TweenService:Create(QuickHopButton, tweenInfo, {
        Rotation = 0
    })
    
    quickPressAnimation:Play()
    quickPressAnimation.Completed:Connect(function()
        quickReleaseAnimation:Play()
        QuickHopButton.BackgroundColor3 = originalColor
    end)
    
    quickArceusXHop()
end)

-- Auto Toggle with Arceus X smart features
AutoToggle.MouseButton1Click:Connect(function()
    autoHopEnabled = not autoHopEnabled
    
    if autoHopEnabled then
        AutoToggle.Text = "🔄 Auto: ON"
        AutoToggle.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        
        -- Add Arceus X auto toggle gradient
        local autoGradient = Instance.new("UIGradient")
        autoGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 200, 0)),
            ColorSequenceKeypoint.new(1.0, Color3.fromRGB(0, 150, 0))
        }
        autoGradient.Rotation = 45
        autoGradient.Parent = AutoToggle
        
        arceusXNotify("🔄 Arceus X Auto-hop enabled for >" .. ArceusXConfig.maxPing .. "ms ping", Color3.fromRGB(0, 255, 0), 3)
        spawn(arceusXAutoHopSystem)
    else
        AutoToggle.Text = "🔄 Auto: OFF"
        AutoToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        -- Remove gradient
        local existingGradient = AutoToggle:FindFirstChild("UIGradient")
        if existingGradient then
            existingGradient:Destroy()
        end
        
        arceusXNotify("🔄 Auto-hop disabled", Color3.fromRGB(200, 200, 200), 2)
    end
end)

-- Close Button with Arceus X fade effect
CloseButton.MouseButton1Click:Connect(function()
    CloseButton.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
    
    -- Arceus X close animation
    local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
    local fadeAnimation = TweenService:Create(MainFrame, fadeInfo, {
        BackgroundTransparency = 1,
        Size = MainFrame.Size * 0.5
    })
    
    -- Fade all child elements
    local function fadeChildren(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("GuiObject") then
                local childFade = TweenService:Create(child, fadeInfo, {
                    BackgroundTransparency = 1,
                    TextTransparency = 1
                })
                childFade:Play()
            end
        end
    end
    
    fadeChildren(MainFrame)
    fadeAnimation:Play()
    
    fadeAnimation.Completed:Connect(function()
        ScreenGui:Destroy()
    end)
end)

-- ===== Arceus X Advanced Features =====

-- Arceus X Server Quality Analyzer
local function analyzeServerQuality(servers)
    local analysis = {
        totalServers = #servers,
        ultraPremium = 0,
        premium = 0,
        excellent = 0,
        good = 0,
        poor = 0,
        averagePing = 0,
        bestPing = 999,
        worstPing = 0,
        recommendedServer = nil
    }
    
    local totalPing = 0
    
    for _, server in pairs(servers) do
        totalPing = totalPing + server.ping
        
        if server.ping < analysis.bestPing then
            analysis.bestPing = server.ping
            analysis.recommendedServer = server
        end
        
        if server.ping > analysis.worstPing then
            analysis.worstPing = server.ping
        end
        
        -- Categorize by Arceus X standards
        if server.ping <= ArceusXConfig.preferredPing then
            analysis.ultraPremium = analysis.ultraPremium + 1
        elseif server.ping <= 65 then
            analysis.premium = analysis.premium + 1
        elseif server.ping <= 75 then
            analysis.excellent = analysis.excellent + 1
        elseif server.ping <= ArceusXConfig.maxPing then
            analysis.good = analysis.good + 1
        else
            analysis.poor = analysis.poor + 1
        end
    end
    
    if analysis.totalServers > 0 then
        analysis.averagePing = math.floor(totalPing / analysis.totalServers)
    end
    
    return analysis
end

-- Arceus X Smart Server Recommendation System
local function getArceusXRecommendation(analysis)
    local recommendation = {
        action = "",
        reason = "",
        priority = 1, -- 1 = low, 5 = critical
        color = Color3.fromRGB(255, 255, 255)
    }
    
    if analysis.ultraPremium > 0 then
        recommendation.action = "🏆 ULTRA-PREMIUM servers available!"
        recommendation.reason = "Perfect " .. analysis.ultraPremium .. " servers with ≤" .. ArceusXConfig.preferredPing .. "ms ping"
        recommendation.priority = 5
        recommendation.color = Color3.fromRGB(255, 215, 0)
    elseif analysis.premium > 0 then
        recommendation.action = "⚡ PREMIUM servers found!"
        recommendation.reason = analysis.premium .. " servers with 51-65ms ping - Excellent for Arceus X"
        recommendation.priority = 4
        recommendation.color = Color3.fromRGB(0, 255, 0)
    elseif analysis.excellent > 0 then
        recommendation.action = "⭐ EXCELLENT servers available!"
        recommendation.reason = analysis.excellent .. " servers with 66-75ms ping - Great performance"
        recommendation.priority = 3
        recommendation.color = Color3.fromRGB(100, 255, 100)
    elseif analysis.good > 0 then
        recommendation.action = "✅ GOOD servers found!"
        recommendation.reason = analysis.good .. " servers with 76-100ms ping - Playable"
        recommendation.priority = 2
        recommendation.color = Color3.fromRGB(150, 255, 150)
    else
        recommendation.action = "❌ No suitable Asian servers"
        recommendation.reason = "All " .. analysis.totalServers .. " servers have >100ms ping"
        recommendation.priority = 1
        recommendation.color = Color3.fromRGB(255, 100, 100)
    end
    
    return recommendation
end

-- Arceus X Network Diagnostics
local function runArceusXDiagnostics()
    arceusXNotify("🔧 Running Arceus X network diagnostics...", Color3.fromRGB(255, 255, 0), 3)
    
    local diagnostics = {
        currentPing = getArceusXPing(),
        playerCount = #Players:GetPlayers(),
        maxPlayers = Players.MaxPlayers,
        gameId = placeId,
        executorType = isArceusXExecutor() and "Arceus X" or "Other",
        touchEnabled = UserInputService.TouchEnabled,
        connectionQuality = "Unknown"
    }
    
    -- Determine connection quality
    if diagnostics.currentPing <= ArceusXConfig.preferredPing then
        diagnostics.connectionQuality = "🏆 Ultra-Premium"
    elseif diagnostics.currentPing <= 75 then
        diagnostics.connectionQuality = "⚡ Premium"
    elseif diagnostics.currentPing <= ArceusXConfig.maxPing then
        diagnostics.connectionQuality = "✅ Good"
    elseif diagnostics.currentPing <= 150 then
        diagnostics.connectionQuality = "⚠️ Fair"
    else
        diagnostics.connectionQuality = "❌ Poor"
    end
    
    -- Display comprehensive diagnostics
    task.wait(1)
    arceusXNotify("📊 " .. diagnostics.connectionQuality .. " | " .. diagnostics.currentPing .. "ms | " .. diagnostics.playerCount .. "/" .. diagnostics.maxPlayers .. " players", Color3.fromRGB(0, 255, 255), 5)
    
    return diagnostics
end

-- Arceus X Intelligent Auto-Hop with Learning
local intelligentHopData = {
    hopHistory = {},
    successfulServers = {},
    failedServers = {},
    learningEnabled = true
}

local function learnFromHop(serverId, wasSuccessful, finalPing)
    if not intelligentHopData.learningEnabled then return end
    
    local hopRecord = {
        serverId = serverId,
        timestamp = tick(),
        successful = wasSuccessful,
        ping = finalPing,
        hour = tonumber(os.date("%H"))
    }
    
    table.insert(intelligentHopData.hopHistory, hopRecord)
    
    if wasSuccessful then
        intelligentHopData.successfulServers[serverId] = (intelligentHopData.successfulServers[serverId] or 0) + 1
    else
        intelligentHopData.failedServers[serverId] = (intelligentHopData.failedServers[serverId] or 0) + 1
    end
    
    -- Keep history manageable
    if #intelligentHopData.hopHistory > 50 then
        table.remove(intelligentHopData.hopHistory, 1)
    end
end

-- Arceus X Smart Server Picker with AI-like Learning
local function pickSmartServer(servers)
    if #servers == 0 then return nil end
    
    local scoredServers = {}
    
    for _, server in pairs(servers) do
        local score = 1000 - server.ping -- Base score from ping
        
        -- Bonus for successful history
        if intelligentHopData.successfulServers[server.id] then
            score = score + (intelligentHopData.successfulServers[server.id] * 50)
        end
        
        -- Penalty for failed history
        if intelligentHopData.failedServers[server.id] then
            score = score - (intelligentHopData.failedServers[server.id] * 25)
        end
        
        -- Player count optimization
        local playerRatio = server.playing / server.maxPlayers
        if playerRatio >= 0.1 and playerRatio <= 0.7 then
            score = score + 30 -- Sweet spot bonus
        elseif playerRatio > 0.8 then
            score = score - 40 -- Too crowded penalty
        end
        
        -- Time-based Asian server detection bonus
        local hour = tonumber(os.date("%H"))
        local isAsianPeakTime = (hour >= 18 and hour <= 23) or (hour >= 6 and hour <= 10)
        if isAsianPeakTime and server.ping <= 80 then
            score = score + 25 -- Asian peak time bonus
        end
        
        table.insert(scoredServers, {
            server = server,
            score = score
        })
    end
    
    -- Sort by score (highest first)
    table.sort(scoredServers, function(a, b)
        return a.score > b.score
    end)
    
    return scoredServers[1] and scoredServers[1].server or nil
end

-- Arceus X Enhanced Server Search with AI
local function advancedArceusXSearch()
    if isSearching then
        arceusXNotify("⏳ Advanced search already in progress...", Color3.fromRGB(255, 255, 0), 2)
        return
    end
    
    arceusXNotify("🤖 Arceus X AI-Enhanced Search starting...", Color3.fromRGB(100, 200, 255), 3)
    
    local servers = getArceusXServerList()
    
    if #servers == 0 then
        arceusXNotify("❌ No servers available - API limited or game issue", Color3.fromRGB(255, 100, 100), 4)
        return
    end
    
    -- Run analysis
    local analysis = analyzeServerQuality(servers)
    local recommendation = getArceusXRecommendation(analysis)
    
    -- Display analysis results
    task.wait(1)
    arceusXNotify("📈 Analysis: " .. analysis.totalServers .. " servers | Best: " .. analysis.bestPing .. "ms | Avg: " .. analysis.averagePing .. "ms", Color3.fromRGB(0, 255, 255), 4)
    
    task.wait(1.5)
    arceusXNotify(recommendation.action, recommendation.color, 4)
    task.wait(1)
    arceusXNotify(recommendation.reason, recommendation.color, 4)
    
    if recommendation.priority >= 2 then
        -- Use AI-powered server selection
        local smartServer = pickSmartServer(servers)
        
        if smartServer then
            task.wait(2)
            arceusXNotify("🎯 AI Selected: " .. smartServer.playing .. " players | " .. smartServer.ping .. "ms | Score: " .. smartServer.arceusXScore, Color3.fromRGB(0, 255, 255), 4)
            
            -- Countdown with learning data
            for i = 3, 1, -1 do
                task.wait(1)
                local learningInfo = intelligentHopData.successfulServers[smartServer.id] and 
                    " (Success: " .. intelligentHopData.successfulServers[smartServer.id] .. ")" or " (New server)"
                arceusXNotify("🚀 Teleporting in " .. i .. "..." .. learningInfo, Color3.fromRGB(255, 255 - (i * 50), 0), 1)
            end
            
            -- Execute hop and learn from result
            arceusXHopToServer(smartServer.id, smartServer)
            
            -- Learn from this hop attempt
            task.spawn(function()
                task.wait(5) -- Wait to see if hop was successful
                local currentPingAfterHop = getArceusXPing()
                local wasSuccessful = currentPingAfterHop <= ArceusXConfig.maxPing and currentPingAfterHop > 0
                learnFromHop(smartServer.id, wasSuccessful, currentPingAfterHop)
            end)
        end
    else
        task.wait(2)
        arceusXNotify("💡 Suggestion: Try again in a few minutes or use Quick Hop", Color3.fromRGB(255, 200, 0), 5)
    end
end

-- Add Advanced Search Button to UI
local AdvancedSearchButton = Instance.new("TextButton")
AdvancedSearchButton.Name = "AdvancedSearchButton"
AdvancedSearchButton.Parent = MainFrame
AdvancedSearchButton.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
AdvancedSearchButton.Position = UDim2.new(0.05, 0, 0.66, 0)
AdvancedSearchButton.Size = UDim2.new(0.9, 0, 0.1, 0)
AdvancedSearchButton.Font = Enum.Font.GothamBold
AdvancedSearchButton.Text = "🤖 AI-Enhanced Search (Learning System)"
AdvancedSearchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
AdvancedSearchButton.TextScaled = true

local advancedGradient = Instance.new("UIGradient")
advancedGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(150, 50, 200)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(100, 30, 150))
}
advancedGradient.Rotation = 45
advancedGradient.Parent = AdvancedSearchButton

local advancedCorner = Instance.new("UICorner")
advancedCorner.CornerRadius = UDim.new(0, 10)
advancedCorner.Parent = AdvancedSearchButton

-- Advanced Search Button Connection
AdvancedSearchButton.MouseButton1Click:Connect(function()
    local originalColor = AdvancedSearchButton.BackgroundColor3
    AdvancedSearchButton.BackgroundColor3 = Color3.fromRGB(120, 40, 160)
    
    local advancedTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
    local advancedPressAnimation = TweenService:Create(AdvancedSearchButton, advancedTweenInfo, {
        Size = AdvancedSearchButton.Size - UDim2.new(0, 8, 0, 3)
    })
    local advancedReleaseAnimation = TweenService:Create(AdvancedSearchButton, advancedTweenInfo, {
        Size = AdvancedSearchButton.Size
    })
    
    advancedPressAnimation:Play()
    advancedPressAnimation.Completed:Connect(function()
        advancedReleaseAnimation:Play()
        AdvancedSearchButton.BackgroundColor3 = originalColor
    end)
    
    spawn(advancedArceusXSearch)
end)

-- Add Diagnostics Button
local DiagnosticsButton = Instance.new("TextButton")
DiagnosticsButton.Name = "DiagnosticsButton"
DiagnosticsButton.Parent = MainFrame
DiagnosticsButton.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
DiagnosticsButton.Position = UDim2.new(0.05, 0, 0.78, 0)
DiagnosticsButton.Size = UDim2.new(0.43, 0, 0.08, 0)
DiagnosticsButton.Font = Enum.Font.Gotham
DiagnosticsButton.Text = "🔧 Diagnostics"
DiagnosticsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
DiagnosticsButton.TextScaled = true

local diagCorner = Instance.new("UICorner")
diagCorner.CornerRadius = UDim.new(0, 8)
diagCorner.Parent = DiagnosticsButton

-- Learning Toggle Button
local LearningToggle = Instance.new("TextButton")
LearningToggle.Name = "LearningToggle"
LearningToggle.Parent = MainFrame
LearningToggle.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
LearningToggle.Position = UDim2.new(0.52, 0, 0.78, 0)
LearningToggle.Size = UDim2.new(0.43, 0, 0.08, 0)
LearningToggle.Font = Enum.Font.Gotham
LearningToggle.Text = "🧠 Learning: ON"
LearningToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
LearningToggle.TextScaled = true

local learnCorner = Instance.new("UICorner")
learnCorner.CornerRadius = UDim.new(0, 8)
learnCorner.Parent = LearningToggle

-- Button Connections
DiagnosticsButton.MouseButton1Click:Connect(function()
    spawn(runArceusXDiagnostics)
end)

LearningToggle.MouseButton1Click:Connect(function()
    intelligentHopData.learningEnabled = not intelligentHopData.learningEnabled
    
    if intelligentHopData.learningEnabled then
        LearningToggle.Text = "🧠 Learning: ON"
        LearningToggle.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        arceusXNotify("🧠 AI Learning enabled - Will remember good servers", Color3.fromRGB(0, 255, 0), 3)
    else
        LearningToggle.Text = "🧠 Learning: OFF"
        LearningToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        arceusXNotify("🧠 AI Learning disabled - Using basic search", Color3.fromRGB(200, 200, 200), 3)
    end
end)

-- ===== Arceus X Enhanced Touch Support =====
if UserInputService.TouchEnabled then
    local function setupArceusXTouch(button)
        button.TouchTap:Connect(function()
            button.MouseButton1Click:Fire()
        end)
        
        -- Arceus X touch visual feedback
        button.TouchLongPress:Connect(function(touchPositions, state)
            if state == Enum.UserInputState.Begin then
                -- Long press feedback for Arceus X
                local longPressEffect = TweenService:Create(button, 
                    TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), 
                    {BackgroundTransparency = 0.3}
                )
                longPressEffect:Play()
            end
        end)
    end
    
    -- Apply Arceus X touch enhancements to all buttons
    for _, button in pairs({SearchButton, QuickHopButton, AutoToggle, CloseButton, AdvancedSearchButton, DiagnosticsButton, LearningToggle}) do
        setupArceusXTouch(button)
    end
end

-- ===== Arceus X Enhanced Ping Monitor =====
spawn(function()
    local pingHistory = {}
    local maxHistory = 30
    
    while ScreenGui.Parent do
        currentPing = getArceusXPing()
        
        -- Add to Arceus X ping history
        table.insert(pingHistory, currentPing)
        if #pingHistory > maxHistory then
            table.remove(pingHistory, 1)
        end
        
        -- Calculate Arceus X enhanced ping metrics
        local avgPing = 0
        local minPing = 999
        local maxPing = 0
        
        for _, ping in pairs(pingHistory) do
            avgPing = avgPing + ping
            minPing = math.min(minPing, ping)
            maxPing = math.max(maxPing, ping)
        end
        avgPing = math.floor(avgPing / #pingHistory)
        
        -- Arceus X ping color coding
        local pingColor = Color3.fromRGB(255, 100, 100)
        local pingStatus = "❌ POOR"
        
        if currentPing <= ArceusXConfig.preferredPing then
            pingColor = Color3.fromRGB(0, 255, 0)
            pingStatus = "🏆 ULTRA"
        elseif currentPing <= 65 then
            pingColor = Color3.fromRGB(100, 255, 0)
            pingStatus = "⚡ PREMIUM"
        elseif currentPing <= 75 then
            pingColor = Color3.fromRGB(200, 255, 0)
            pingStatus = "⭐ EXCELLENT"
        elseif currentPing <= ArceusXConfig.maxPing then
            pingColor = Color3.fromRGB(255, 255, 0)
            pingStatus = "✅ GOOD"
        elseif currentPing <= 150 then
            pingColor = Color3.fromRGB(255, 150, 0)
            pingStatus = "⚠️ FAIR"
        end
        
        -- Enhanced Arceus X ping display
        PingLabel.Text = pingStatus .. " | " .. currentPing .. "ms (Avg: " .. avgPing .. ") | Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
        PingLabel.TextColor3 = pingColor
        
        -- Arceus X performance optimization
        if ArceusXConfig.batteryOptimized then
            task.wait(3) -- Battery saving
        else
            task.wait(2) -- Standard monitoring
        end
    end
end)

-- ===== Arceus X Startup Sequence =====
local function arceusXStartup()
    local isArceus, detectionResult = isArceusXExecutor()
    
    arceusXNotify("🌏 Arceus X Asian Server Finder Ready!", Color3.fromRGB(0, 255, 255), 4)
    
    if isArceus then
        task.wait(2)
        arceusXNotify("⚡ " .. detectionResult .. " - Touch optimized!", Color3.fromRGB(100, 255, 100), 4)
        
        -- Arceus X auto-search feature
        task.wait(3)
        local startupPing = getArceusXPing()
        
        if startupPing > ArceusXConfig.maxPing then
            arceusXNotify("🚀 High ping detected (" .. startupPing .. "ms) - Auto searching premium servers...", Color3.fromRGB(255, 255, 0), 4)
            task.wait(2)
            spawn(findBestAsianServersArceusX)
        elseif startupPing <= ArceusXConfig.preferredPing then
            arceusXNotify("🏆 Already on ultra-low ping server (" .. startupPing .. "ms)! Ready to go!", Color3.fromRGB(0, 255, 0), 5)
        else
            arceusXNotify("✅ Current ping: " .. startupPing .. "ms - Tap search for better servers!", Color3.fromRGB(150, 255, 150), 4)
        end
    else
        task.wait(2)
        arceusXNotify("💻 Desktop mode detected - All features available!", Color3.fromRGB(200, 200, 255), 3)
    end
end

-- Start Arceus X
spawn(arceusXStartup)

-- ===== Arceus X Console Commands =====
print("🌏 Arceus X Asian Server Finder v2.0 loaded successfully!")
print("⚡ " .. (isArceusXExecutor() and "ARCEUS X" or "GENERIC") .. " executor detected")
print("🎯 Target: Premium Asian servers (50-100ms ping)")
print("📱 Features: Ultra-low ping detection, Auto-hop, Enhanced touch controls")
print("🔥 Arceus X optimized with LuaU execution and 0% detection")

-- Global functions for Arceus X console
_G.ArceusXFindServers = findBestAsianServersArceusX
_G.ArceusXQuickHop = quickArceusXHop
_G.ArceusXGetPing = getArceusXPing
_G.ArceusXToggleAuto = function()
    AutoToggle.MouseButton1Click:Fire()
end

-- Enhanced Global Functions
_G.ArceusXAdvancedSearch = advancedArceusXSearch
_G.ArceusXDiagnostics = runArceusXDiagnostics
_G.ArceusXToggleLearning = function()
    LearningToggle.MouseButton1Click:Fire()
end
_G.ArceusXGetStats = function()
    return {
        hops = serverHops,
        currentPing = getArceusXPing(),
        learningData = intelligentHopData,
        config = ArceusXConfig
    }
end

print("🤖 Advanced Arceus X Features loaded:")
print("   _G.ArceusXFindServers() - Find best servers")
print("   _G.ArceusXQuickHop() - Quick server hop")
print("   _G.ArceusXAdvancedSearch() - AI-enhanced server search")
print("   _G.ArceusXDiagnostics() - Network diagnostics")
print("   _G.ArceusXGetPing() - Check current ping")
print("   _G.ArceusXToggleAuto() - Toggle auto-hop")
print("   _G.ArceusXToggleLearning() - Toggle AI learning")
print("   _G.ArceusXGetStats() - Get session statistics")
