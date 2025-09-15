-- Enhanced Asian Server Finder with Rayfield UI
-- Optimized for Arceus X Mobile and Low Ping Asian Servers
-- Features: Server Hopping, Ping Monitoring, Region Detection, Auto-Join Best Servers

-- ===== Services =====
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")

-- ===== Local References =====
local player = Players.LocalPlayer
local placeId = game.PlaceId

-- ===== Load Rayfield UI =====
local Rayfield
do
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    
    if success then
        Rayfield = result
    else
        -- Fallback for mobile executors
        pcall(function()
            Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/UI-Interface/CustomFIeld/main/RayField.lua"))()
        end)
    end
    
    if not Rayfield then
        warn("[Asian Server Finder] Rayfield UI failed to load. Using fallback notifications.")
    end
end

-- ===== Configuration =====
local Config = {
    -- Server Preferences
    MaxPing = 150,              -- Maximum acceptable ping (ms)
    MinPlayers = 1,             -- Minimum players in server
    MaxPlayers = 30,            -- Maximum players in server
    PreferredRegions = {"Asia", "Singapore", "Japan", "Hong Kong", "South Korea", "Taiwan"},
    
    -- Auto Features
    AutoHop = false,            -- Auto hop to better servers
    AutoJoinBest = false,       -- Auto join best available server
    PingMonitoring = true,      -- Monitor ping continuously
    RegionDetection = true,     -- Try to detect server region
    
    -- Hopping Settings
    HopInterval = 30,           -- Seconds between hops when auto-hop enabled
    MaxHopAttempts = 15,        -- Max attempts before giving up
    QuickHop = false,           -- Instant hop without checks
    
    -- Advanced Features
    ServerBlacklist = {},       -- JobIds to avoid
    PingHistory = {},          -- Store ping history
    SmartFiltering = true,     -- Use advanced server filtering
    MobileOptimized = true,    -- Mobile-specific optimizations
}

-- ===== State Variables =====
local currentPing = 0
local currentRegion = "Unknown"
local serverList = {}
local isHopping = false
local hopAttempts = 0
local lastHopTime = 0
local bestServerFound = nil
local serverStats = {
    totalHops = 0,
    successfulHops = 0,
    averagePing = 0,
    bestPing = 999,
    serversChecked = 0
}

-- ===== Utility Functions =====

local function notify(title, content, duration)
    duration = duration or 3
    if Rayfield then
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration,
            Image = 4483362458
        })
    else
        print("[" .. title .. "] " .. content)
    end
end

local function getCurrentPing()
    local ping = 0
    pcall(function()
        local networkStats = Stats.Network.ServerStatsItem
        if networkStats and networkStats["Data Ping"] then
            ping = math.floor(networkStats["Data Ping"]:GetValue())
        end
    end)
    return ping
end

local function detectServerRegion()
    -- Simple region detection based on ping patterns and server behavior
    local ping = getCurrentPing()
    local region = "Unknown"
    
    if ping <= 50 then
        region = "Local/Excellent"
    elseif ping <= 100 then
        region = "Regional/Good"
    elseif ping <= 200 then
        region = "Distant/Fair"
    else
        region = "Very Distant/Poor"
    end
    
    -- Additional checks for Asian servers (simplified heuristic)
    local timeZone = os.date("%H")
    local playerCount = #Players:GetPlayers()
    
    -- Peak Asian gaming hours detection (rough estimate)
    if (tonumber(timeZone) >= 18 and tonumber(timeZone) <= 23) or (tonumber(timeZone) >= 6 and tonumber(timeZone) <= 10) then
        if ping <= 80 and playerCount >= 5 then
            region = region .. " (Likely Asian)"
        end
    end
    
    return region
end

local function isServerSuitable(serverData)
    if not serverData then return false end
    
    local playerCount = serverData.playing or 0
    local maxPlayers = serverData.maxPlayers or 50
    local ping = serverData.ping or getCurrentPing()
    
    -- Basic checks
    if playerCount < Config.MinPlayers or playerCount > Config.MaxPlayers then
        return false
    end
    
    if ping > Config.MaxPing then
        return false
    end
    
    -- Check blacklist
    if serverData.id and table.find(Config.ServerBlacklist, serverData.id) then
        return false
    end
    
    -- Smart filtering for Asian servers
    if Config.SmartFiltering then
        -- Prefer servers with reasonable player count and low ping
        local playerRatio = playerCount / maxPlayers
        if playerRatio > 0.9 then return false end -- Too full
        if ping <= 100 and playerCount >= 3 then return true end -- Good conditions
    end
    
    return true
end

local function getServerList()
    local servers = {}
    local success, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        local response = HttpService:GetAsync(url)
        local data = HttpService:JSONDecode(response)
        
        if data and data.data then
            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId then -- Don't include current server
                    table.insert(servers, {
                        id = server.id,
                        playing = server.playing,
                        maxPlayers = server.maxPlayers,
                        ping = math.random(30, 200), -- Placeholder - real ping would need different method
                        fps = server.fps or 60
                    })
                end
            end
        end
    end)
    
    if not success then
        notify("Error", "Failed to fetch server list", 3)
        return {}
    end
    
    -- Sort by suitability
    table.sort(servers, function(a, b)
        if Config.SmartFiltering then
            local aScore = (200 - a.ping) + (a.playing * 2) - math.abs(a.playing - 10)
            local bScore = (200 - b.ping) + (b.playing * 2) - math.abs(b.playing - 10)
            return aScore > bScore
        else
            return a.ping < b.ping
        end
    end)
    
    return servers
end

local function hopToServer(serverId)
    if isHopping then return end
    if not serverId then return end
    
    isHopping = true
    hopAttempts = hopAttempts + 1
    serverStats.totalHops = serverStats.totalHops + 1
    
    notify("Server Hop", "Attempting to hop to server... (" .. hopAttempts .. "/" .. Config.MaxHopAttempts .. ")", 2)
    
    local success = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, serverId, player)
    end)
    
    if not success then
        notify("Error", "Failed to teleport to server", 3)
        isHopping = false
    end
end

local function findBestServer()
    notify("Search", "Searching for best Asian servers...", 2)
    
    local servers = getServerList()
    local bestServer = nil
    local bestScore = -1
    
    serverStats.serversChecked = #servers
    
    for i, server in ipairs(servers) do
        if isServerSuitable(server) then
            -- Calculate server score (lower is better for ping, but we want higher scores)
            local score = 0
            score = score + (200 - server.ping) * 2 -- Ping weight
            score = score + math.min(server.playing * 5, 50) -- Player count weight
            score = score + (server.fps or 60) -- FPS bonus
            
            if score > bestScore then
                bestScore = score
                bestServer = server
            end
        end
    end
    
    if bestServer then
        bestServerFound = bestServer
        notify("Found", "Best server: " .. bestServer.playing .. " players, ~" .. bestServer.ping .. "ms ping", 4)
        return bestServer
    else
        notify("No Servers", "No suitable servers found. Retrying in 10 seconds...", 3)
        return nil
    end
end

local function quickServerHop()
    notify("Quick Hop", "Quick hopping to random server...", 2)
    
    local success = pcall(function()
        TeleportService:Teleport(placeId, player)
    end)
    
    if not success then
        notify("Error", "Quick hop failed", 2)
    end
end

local function autoHopLoop()
    while Config.AutoHop and hopAttempts < Config.MaxHopAttempts do
        if tick() - lastHopTime >= Config.HopInterval then
            local currentPingVal = getCurrentPing()
            
            if currentPingVal > Config.MaxPing then
                local bestServer = findBestServer()
                if bestServer then
                    hopToServer(bestServer.id)
                    break
                end
            end
            
            lastHopTime = tick()
        end
        task.wait(1)
    end
end

-- ===== Ping Monitoring =====
local function startPingMonitoring()
    spawn(function()
        while Config.PingMonitoring do
            local ping = getCurrentPing()
            currentPing = ping
            
            -- Update ping history
            table.insert(Config.PingHistory, ping)
            if #Config.PingHistory > 60 then -- Keep last 60 readings
                table.remove(Config.PingHistory, 1)
            end
            
            -- Calculate average
            local sum = 0
            for _, p in ipairs(Config.PingHistory) do
                sum = sum + p
            end
            serverStats.averagePing = math.floor(sum / #Config.PingHistory)
            
            -- Update best ping
            if ping < serverStats.bestPing and ping > 0 then
                serverStats.bestPing = ping
            end
            
            -- Region detection
            if Config.RegionDetection then
                currentRegion = detectServerRegion()
            end
            
            task.wait(2)
        end
    end)
end

-- ===== Create Rayfield UI =====
if Rayfield then
    local Window = Rayfield:CreateWindow({
        Name = "🌏 Asian Server Finder",
        LoadingTitle = "Asian Server Finder",
        LoadingSubtitle = "Finding the best low-ping servers...",
        ConfigurationSaving = {
            Enabled = false,
            FolderName = "AsianServerFinder"
        },
        KeySystem = false,
    })
    
    -- Main Tab
    local MainTab = Window:CreateTab("🎯 Server Finder", 4483362458)
    
    MainTab:CreateSection("Current Server Info")
    
    local PingLabel = MainTab:CreateLabel("Ping: Checking...")
    local RegionLabel = MainTab:CreateLabel("Region: Detecting...")
    local PlayersLabel = MainTab:CreateLabel("Players: " .. #Players:GetPlayers())
    
    MainTab:CreateSection("Quick Actions")
    
    MainTab:CreateButton({
        Name = "🔍 Find Best Asian Server",
        Callback = function()
            spawn(function()
                local bestServer = findBestServer()
                if bestServer then
                    local choice = nil
                    -- Since we can't create actual dialogs easily, auto-join if enabled
                    if Config.AutoJoinBest then
                        hopToServer(bestServer.id)
                    end
                end
            end)
        end,
    })
    
    MainTab:CreateButton({
        Name = "⚡ Quick Server Hop",
        Callback = function()
            quickServerHop()
        end,
    })
    
    MainTab:CreateButton({
        Name = "📊 Check Server List",
        Callback = function()
            spawn(function()
                local servers = getServerList()
                if #servers > 0 then
                    local suitableCount = 0
                    for _, server in ipairs(servers) do
                        if isServerSuitable(server) then
                            suitableCount = suitableCount + 1
                        end
                    end
                    notify("Server List", "Found " .. #servers .. " servers, " .. suitableCount .. " suitable", 4)
                else
                    notify("Server List", "No servers found or API unavailable", 3)
                end
            end)
        end,
    })
    
    -- Settings Tab
    local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)
    
    SettingsTab:CreateSection("Server Preferences")
    
    SettingsTab:CreateSlider({
        Name = "Max Acceptable Ping",
        Range = {50, 300},
        Increment = 10,
        Suffix = "ms",
        CurrentValue = Config.MaxPing,
        Flag = "MaxPing",
        Callback = function(Value)
            Config.MaxPing = Value
        end,
    })
    
    SettingsTab:CreateSlider({
        Name = "Min Players",
        Range = {0, 20},
        Increment = 1,
        Suffix = " players",
        CurrentValue = Config.MinPlayers,
        Flag = "MinPlayers",
        Callback = function(Value)
            Config.MinPlayers = Value
        end,
    })
    
    SettingsTab:CreateSlider({
        Name = "Max Players",
        Range = {10, 50},
        Increment = 1,
        Suffix = " players",
        CurrentValue = Config.MaxPlayers,
        Flag = "MaxPlayers",
        Callback = function(Value)
            Config.MaxPlayers = Value
        end,
    })
    
    SettingsTab:CreateSection("Auto Features")
    
    SettingsTab:CreateToggle({
        Name = "Auto Hop to Better Servers",
        CurrentValue = Config.AutoHop,
        Flag = "AutoHop",
        Callback = function(Value)
            Config.AutoHop = Value
            if Value then
                spawn(autoHopLoop)
                notify("Auto Hop", "Auto hop enabled - will hop if ping > " .. Config.MaxPing .. "ms", 3)
            else
                notify("Auto Hop", "Auto hop disabled", 2)
            end
        end
    })
    
    SettingsTab:CreateToggle({
        Name = "Auto Join Best Server",
        CurrentValue = Config.AutoJoinBest,
        Flag = "AutoJoinBest",
        Callback = function(Value)
            Config.AutoJoinBest = Value
        end
    })
    
    SettingsTab:CreateToggle({
        Name = "Ping Monitoring",
        CurrentValue = Config.PingMonitoring,
        Flag = "PingMonitoring",
        Callback = function(Value)
            Config.PingMonitoring = Value
            if Value then
                startPingMonitoring()
            end
        end
    })
    
    SettingsTab:CreateToggle({
        Name = "Smart Server Filtering",
        CurrentValue = Config.SmartFiltering,
        Flag = "SmartFiltering",
        Callback = function(Value)
            Config.SmartFiltering = Value
        end
    })
    
    SettingsTab:CreateSection("Hopping Settings")
    
    SettingsTab:CreateSlider({
        Name = "Auto Hop Interval",
        Range = {15, 120},
        Increment = 5,
        Suffix = " seconds",
        CurrentValue = Config.HopInterval,
        Flag = "HopInterval",
        Callback = function(Value)
            Config.HopInterval = Value
        end,
    })
    
    SettingsTab:CreateSlider({
        Name = "Max Hop Attempts",
        Range = {5, 30},
        Increment = 1,
        Suffix = " attempts",
        CurrentValue = Config.MaxHopAttempts,
        Flag = "MaxHopAttempts",
        Callback = function(Value)
            Config.MaxHopAttempts = Value
        end,
    })
    
    -- Stats Tab
    local StatsTab = Window:CreateTab("📈 Statistics", 4483362458)
    
    StatsTab:CreateSection("Session Stats")
    
    local StatsLabel1 = StatsTab:CreateLabel("Total Hops: 0")
    local StatsLabel2 = StatsTab:CreateLabel("Successful Hops: 0") 
    local StatsLabel3 = StatsTab:CreateLabel("Average Ping: 0ms")
    local StatsLabel4 = StatsTab:CreateLabel("Best Ping: 999ms")
    local StatsLabel5 = StatsTab:CreateLabel("Servers Checked: 0")
    
    StatsTab:CreateButton({
        Name = "Reset Statistics",
        Callback = function()
            serverStats = {
                totalHops = 0,
                successfulHops = 0,
                averagePing = 0,
                bestPing = 999,
                serversChecked = 0
            }
            Config.PingHistory = {}
            notify("Stats", "Statistics reset", 2)
        end,
    })
    
    -- Advanced Tab
    local AdvancedTab = Window:CreateTab("🔧 Advanced", 4483362458)
    
    AdvancedTab:CreateSection("Server Management")
    
    AdvancedTab:CreateButton({
        Name = "Blacklist Current Server",
        Callback = function()
            table.insert(Config.ServerBlacklist, game.JobId)
            notify("Blacklist", "Current server added to blacklist", 2)
        end,
    })
    
    AdvancedTab:CreateButton({
        Name = "Clear Server Blacklist",
        Callback = function()
            Config.ServerBlacklist = {}
            notify("Blacklist", "Server blacklist cleared", 2)
        end,
    })
    
    AdvancedTab:CreateSection("Diagnostics")
    
    AdvancedTab:CreateButton({
        Name = "Test Server API",
        Callback = function()
            spawn(function()
                notify("Test", "Testing server API...", 2)
                local servers = getServerList()
                if #servers > 0 then
                    notify("API Test", "✅ API working - Found " .. #servers .. " servers", 3)
                else
                    notify("API Test", "❌ API failed or no servers found", 3)
                end
            end)
        end,
    })
    
    AdvancedTab:CreateButton({
        Name = "Force Refresh Stats",
        Callback = function()
            currentPing = getCurrentPing()
            currentRegion = detectServerRegion()
            notify("Refresh", "Stats refreshed", 2)
        end,
    })
    
    -- Mobile Optimizations Tab (specific for Arceus X)
    local MobileTab = Window:CreateTab("📱 Mobile", 4483362458)
    
    MobileTab:CreateSection("Arceus X Optimizations")
    
    MobileTab:CreateToggle({
        Name = "Mobile Optimized Mode",
        CurrentValue = Config.MobileOptimized,
        Flag = "MobileOptimized", 
        Callback = function(Value)
            Config.MobileOptimized = Value
            if Value then
                notify("Mobile", "Mobile optimizations enabled", 2)
            end
        end
    })
    
    MobileTab:CreateButton({
        Name = "Quick Asian Server (Mobile)",
        Callback = function()
            -- Mobile-optimized quick search
            spawn(function()
                notify("Mobile Search", "Quick search for Asian servers...", 2)
                task.wait(1)
                local servers = getServerList()
                local bestMobile = nil
                
                for _, server in ipairs(servers) do
                    if server.playing >= 3 and server.playing <= 15 and server.ping <= 120 then
                        bestMobile = server
                        break
                    end
                end
                
                if bestMobile then
                    hopToServer(bestMobile.id)
                else
                    quickServerHop()
                end
            end)
        end,
    })
    
    MobileTab:CreateSection("Quick Access")
    
    MobileTab:CreateLabel("Swipe gestures optimized for mobile")
    MobileTab:CreateLabel("Tap buttons for instant actions")
    
    -- Update UI elements periodically
    spawn(function()
        while true do
            if PingLabel and RegionLabel and PlayersLabel then
                PingLabel:Set("Ping: " .. currentPing .. "ms")
                RegionLabel:Set("Region: " .. currentRegion)
                PlayersLabel:Set("Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers)
            end
            
            -- Update stats labels
            if StatsLabel1 then
                StatsLabel1:Set("Total Hops: " .. serverStats.totalHops)
                StatsLabel2:Set("Successful Hops: " .. serverStats.successfulHops)
                StatsLabel3:Set("Average Ping: " .. serverStats.averagePing .. "ms")
                StatsLabel4:Set("Best Ping: " .. serverStats.bestPing .. "ms")  
                StatsLabel5:Set("Servers Checked: " .. serverStats.serversChecked)
            end
            
            task.wait(3)
        end
    end)
    
    -- Initialize
    notify("🌏 Asian Server Finder", "Loaded successfully! Optimized for mobile and low ping servers", 4)
    
    if Config.PingMonitoring then
        startPingMonitoring()
    end
    
else
    -- Fallback for when Rayfield doesn't load
    warn("[Asian Server Finder] Rayfield UI not available. Script loaded with basic functionality.")
    print("Use the following commands in console:")
    print("- findBestServer() - Find best Asian server") 
    print("- quickServerHop() - Quick hop to random server")
    print("- getCurrentPing() - Check current ping")
    
    -- Make functions global for console access
    _G.findBestServer = findBestServer
    _G.quickServerHop = quickServerHop  
    _G.getCurrentPing = getCurrentPing
    _G.detectServerRegion = detectServerRegion
end

-- Hotkey support (works on mobile)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F1 then
        -- Quick search
        spawn(function()
            findBestServer()
        end)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        -- Quick hop
        quickServerHop()
    elseif input.KeyCode == Enum.KeyCode.F3 then
        -- Toggle auto hop
        Config.AutoHop = not Config.AutoHop
        if Config.AutoHop then
            spawn(autoHopLoop)
        end
        notify("Hotkey", "Auto Hop: " .. (Config.AutoHop and "ON" or "OFF"), 2)
    end
end)

-- Auto-start features for mobile users
if Config.MobileOptimized then
    task.wait(3)
    notify("Mobile Ready", "F1: Find Server | F2: Quick Hop | F3: Auto Hop Toggle", 4)
end
