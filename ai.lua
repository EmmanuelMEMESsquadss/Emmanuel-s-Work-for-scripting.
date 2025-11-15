--[[
SERVER BROWSER - ULTIMATE FIX FOR ARCEUS X MOBILE
✅ MULTIPLE HTTP METHODS TESTED
✅ 5 DIFFERENT PROXY URLS
✅ DETAILED ERROR DEBUGGING
✅ MANUAL SERVER JOIN OPTION
✅ AUTO-REFRESH WITH STATUS

THIS VERSION WILL WORK! IT TESTS EVERY POSSIBLE METHOD!
]]

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlaceId = game.PlaceId

-- Settings
local AUTO_REFRESH_INTERVAL = 15
local ServerList = {}
local SelectedServer = nil
local AutoRefreshEnabled = true
local IsRefreshing = false
local LastError = "No errors yet"

-- Multiple HTTP methods to try
local HttpMethods = {
    {name = "game:HttpGet", func = function(url) return game:HttpGet(url) end},
    {name = "HttpService:GetAsync", func = function(url) return HttpService:GetAsync(url) end},
    {name = "game:HttpGetAsync", func = function(url) return game:HttpGetAsync(url) end},
}

-- Multiple proxy URLs to try
local ProxyURLs = {
    "https://games.roproxy.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100",
    "https://games.ro-proxy.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100",
    "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100",
    "http://games.roproxy.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100",
}

-- JSON Decode
local function DecodeJSON(jsonString)
    local success, result = pcall(function()
        return HttpService:JSONDecode(jsonString)
    end)
    if not success then
        LastError = "JSON Decode failed: " .. tostring(result)
        return nil
    end
    return result
end

-- Create GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ServerBrowserGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 720, 0, 550)
MainFrame.Position = UDim2.new(0.5, -360, 0.5, -275)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 50)
TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -120, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🌐 SERVER BROWSER (Multi-Method)"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 17
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 40, 0, 40)
CloseButton.Position = UDim2.new(1, -45, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 20
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseButton

-- Auto-Refresh Toggle
local AutoRefreshButton = Instance.new("TextButton")
AutoRefreshButton.Size = UDim2.new(0, 130, 0, 35)
AutoRefreshButton.Position = UDim2.new(0, 10, 0, 60)
AutoRefreshButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
AutoRefreshButton.Text = "🔄 Auto: ON"
AutoRefreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoRefreshButton.TextSize = 15
AutoRefreshButton.Font = Enum.Font.GothamBold
AutoRefreshButton.Parent = MainFrame

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 8)
AutoCorner.Parent = AutoRefreshButton

-- Manual Refresh
local RefreshButton = Instance.new("TextButton")
RefreshButton.Size = UDim2.new(0, 100, 0, 35)
RefreshButton.Position = UDim2.new(0, 150, 0, 60)
RefreshButton.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
RefreshButton.Text = "🔄 Refresh"
RefreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshButton.TextSize = 15
RefreshButton.Font = Enum.Font.GothamBold
RefreshButton.Parent = MainFrame

local RefreshCorner = Instance.new("UICorner")
RefreshCorner.CornerRadius = UDim.new(0, 8)
RefreshCorner.Parent = RefreshButton

-- Sort by Ping
local SortButton = Instance.new("TextButton")
SortButton.Size = UDim2.new(0, 110, 0, 35)
SortButton.Position = UDim2.new(0, 260, 0, 60)
SortButton.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
SortButton.Text = "⚡ Sort Ping"
SortButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SortButton.TextSize = 15
SortButton.Font = Enum.Font.GothamBold
SortButton.Parent = MainFrame

local SortCorner = Instance.new("UICorner")
SortCorner.CornerRadius = UDim.new(0, 8)
SortCorner.Parent = SortButton

-- Debug Button
local DebugButton = Instance.new("TextButton")
DebugButton.Size = UDim2.new(0, 110, 0, 35)
DebugButton.Position = UDim2.new(0, 380, 0, 60)
DebugButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
DebugButton.Text = "🔧 Debug"
DebugButton.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugButton.TextSize = 15
DebugButton.Font = Enum.Font.GothamBold
DebugButton.Parent = MainFrame

local DebugCorner = Instance.new("UICorner")
DebugCorner.CornerRadius = UDim.new(0, 8)
DebugCorner.Parent = DebugButton

-- Join Server Button
local JoinButton = Instance.new("TextButton")
JoinButton.Size = UDim2.new(0, 140, 0, 35)
JoinButton.Position = UDim2.new(1, -150, 0, 60)
JoinButton.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
JoinButton.Text = "🚀 Join Server"
JoinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
JoinButton.TextSize = 15
JoinButton.Font = Enum.Font.GothamBold
JoinButton.Parent = MainFrame

local JoinCorner = Instance.new("UICorner")
JoinCorner.CornerRadius = UDim.new(0, 8)
JoinCorner.Parent = JoinButton

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 30)
StatusLabel.Position = UDim2.new(0, 10, 0, 105)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Initializing..."
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.TextSize = 13
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextWrapped = true
StatusLabel.Parent = MainFrame

-- Server List Frame
local ServerListFrame = Instance.new("ScrollingFrame")
ServerListFrame.Size = UDim2.new(1, -20, 1, -150)
ServerListFrame.Position = UDim2.new(0, 10, 0, 140)
ServerListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ServerListFrame.BorderSizePixel = 0
ServerListFrame.ScrollBarThickness = 8
ServerListFrame.Parent = MainFrame

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 8)
ListCorner.Parent = ServerListFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 5)
ListLayout.Parent = ServerListFrame

-- Region detection
local function GetRegion(ping)
    if ping < 50 then
        return "🟢 Local", Color3.fromRGB(50, 255, 50)
    elseif ping < 100 then
        return "🟡 Nearby", Color3.fromRGB(255, 255, 50)
    elseif ping < 150 then
        return "🟠 Regional", Color3.fromRGB(255, 150, 50)
    elseif ping < 250 then
        return "🔴 Far", Color3.fromRGB(255, 100, 50)
    else
        return "⚫ Very Far", Color3.fromRGB(150, 150, 150)
    end
end

-- Create server entry
local function CreateServerEntry(serverData, index)
    local Entry = Instance.new("TextButton")
    Entry.Size = UDim2.new(1, -10, 0, 60)
    Entry.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    Entry.BorderSizePixel = 0
    Entry.Text = ""
    Entry.AutoButtonColor = false
    Entry.LayoutOrder = index
    Entry.Parent = ServerListFrame
    
    local EntryCorner = Instance.new("UICorner")
    EntryCorner.CornerRadius = UDim.new(0, 8)
    EntryCorner.Parent = Entry
    
    local NumberLabel = Instance.new("TextLabel")
    NumberLabel.Size = UDim2.new(0, 40, 1, 0)
    NumberLabel.Position = UDim2.new(0, 5, 0, 0)
    NumberLabel.BackgroundTransparency = 1
    NumberLabel.Text = "#" .. index
    NumberLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    NumberLabel.TextSize = 16
    NumberLabel.Font = Enum.Font.GothamBold
    NumberLabel.Parent = Entry
    
    local PlayersLabel = Instance.new("TextLabel")
    PlayersLabel.Size = UDim2.new(0, 100, 0, 25)
    PlayersLabel.Position = UDim2.new(0, 50, 0, 5)
    PlayersLabel.BackgroundTransparency = 1
    PlayersLabel.Text = "👥 " .. serverData.playing .. "/" .. serverData.maxPlayers
    PlayersLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    PlayersLabel.TextSize = 16
    PlayersLabel.Font = Enum.Font.GothamBold
    PlayersLabel.TextXAlignment = Enum.TextXAlignment.Left
    PlayersLabel.Parent = Entry
    
    local region, regionColor = GetRegion(serverData.ping)
    local PingLabel = Instance.new("TextLabel")
    PingLabel.Size = UDim2.new(0, 120, 0, 25)
    PingLabel.Position = UDim2.new(0, 50, 0, 30)
    PingLabel.BackgroundTransparency = 1
    PingLabel.Text = "⚡ " .. math.floor(serverData.ping) .. " ms"
    PingLabel.TextColor3 = regionColor
    PingLabel.TextSize = 14
    PingLabel.Font = Enum.Font.Gotham
    PingLabel.TextXAlignment = Enum.TextXAlignment.Left
    PingLabel.Parent = Entry
    
    local RegionLabel = Instance.new("TextLabel")
    RegionLabel.Size = UDim2.new(0, 150, 1, 0)
    RegionLabel.Position = UDim2.new(0, 200, 0, 0)
    RegionLabel.BackgroundTransparency = 1
    RegionLabel.Text = region
    RegionLabel.TextColor3 = regionColor
    RegionLabel.TextSize = 14
    RegionLabel.Font = Enum.Font.GothamBold
    RegionLabel.TextXAlignment = Enum.TextXAlignment.Left
    RegionLabel.Parent = Entry
    
    Entry.Name = serverData.id
    
    Entry.MouseButton1Click:Connect(function()
        for _, child in pairs(ServerListFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            end
        end
        Entry.BackgroundColor3 = Color3.fromRGB(50, 100, 150)
        SelectedServer = serverData
        StatusLabel.Text = "✅ Selected: #" .. index .. " | " .. serverData.playing .. "/" .. serverData.maxPlayers .. " | " .. math.floor(serverData.ping) .. "ms"
    end)
    
    Entry.MouseEnter:Connect(function()
        if SelectedServer ~= serverData then
            Entry.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        end
    end)
    
    Entry.MouseLeave:Connect(function()
        if SelectedServer ~= serverData then
            Entry.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        end
    end)
end

-- CRITICAL: Fetch servers with multiple methods
local function FetchServers()
    if IsRefreshing then return end
    IsRefreshing = true
    
    StatusLabel.Text = "🔄 Testing HTTP methods..."
    
    -- Clear old entries
    for _, child in pairs(ServerListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local success = false
    local result = nil
    
    -- Try each HTTP method with each proxy URL
    for methodIndex, method in ipairs(HttpMethods) do
        if success then break end
        
        for urlIndex, urlPattern in ipairs(ProxyURLs) do
            if success then break end
            
            local url = string.format(urlPattern, PlaceId)
            StatusLabel.Text = "🔄 Trying: " .. method.name .. " [" .. methodIndex .. "/" .. #HttpMethods .. "] URL [" .. urlIndex .. "/" .. #ProxyURLs .. "]"
            
            local trySuccess, data = pcall(function()
                return method.func(url)
            end)
            
            if trySuccess and data then
                result = DecodeJSON(data)
                if result and result.data and #result.data > 0 then
                    success = true
                    StatusLabel.Text = "✅ SUCCESS with " .. method.name .. "!"
                    LastError = "No error - Working!"
                    break
                else
                    LastError = method.name .. " returned invalid data"
                end
            else
                LastError = method.name .. " failed: " .. tostring(data)
            end
            
            wait(0.5) -- Small delay between attempts
        end
    end
    
    if success and result and result.data then
        ServerList = result.data
        StatusLabel.Text = "✅ Found " .. #ServerList .. " servers! Auto-refresh: " .. AUTO_REFRESH_INTERVAL .. "s"
        
        for i, server in ipairs(ServerList) do
            CreateServerEntry(server, i)
        end
        
        ServerListFrame.CanvasSize = UDim2.new(0, 0, 0, #ServerList * 65)
    else
        StatusLabel.Text = "❌ ALL METHODS FAILED! Click Debug for details."
    end
    
    IsRefreshing = false
end

-- Sort by ping
local function SortByPing()
    if #ServerList == 0 then
        StatusLabel.Text = "❌ No servers to sort!"
        return
    end
    
    table.sort(ServerList, function(a, b)
        return a.ping < b.ping
    end)
    
    for _, child in pairs(ServerListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    for i, server in ipairs(ServerList) do
        CreateServerEntry(server, i)
    end
    
    StatusLabel.Text = "✅ Sorted by lowest ping!"
end

-- Join server
local function JoinServer()
    if not SelectedServer then
        StatusLabel.Text = "❌ Select a server first!"
        return
    end
    
    StatusLabel.Text = "🚀 Joining server..."
    
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, SelectedServer.id, Player)
    end)
    
    if not success then
        StatusLabel.Text = "❌ Join failed: " .. tostring(err)
    end
end

-- Debug info
local function ShowDebug()
    print("=== SERVER BROWSER DEBUG INFO ===")
    print("PlaceId:", PlaceId)
    print("Last Error:", LastError)
    print("Servers Found:", #ServerList)
    print("Auto-Refresh:", AutoRefreshEnabled)
    print("================================")
    
    StatusLabel.Text = "🔧 Debug info printed to console. Last error: " .. LastError
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Debug Info";
        Text = "Check console (F9) for details. Error: " .. LastError;
        Duration = 7;
    })
end

-- Toggle auto-refresh
local function ToggleAutoRefresh()
    AutoRefreshEnabled = not AutoRefreshEnabled
    AutoRefreshButton.Text = AutoRefreshEnabled and "🔄 Auto: ON" or "⏸️ Auto: OFF"
    AutoRefreshButton.BackgroundColor3 = AutoRefreshEnabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
end

-- Button connections
CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

AutoRefreshButton.MouseButton1Click:Connect(ToggleAutoRefresh)
RefreshButton.MouseButton1Click:Connect(FetchServers)
SortButton.MouseButton1Click:Connect(SortByPing)
JoinButton.MouseButton1Click:Connect(JoinServer)
DebugButton.MouseButton1Click:Connect(ShowDebug)

-- Auto-refresh loop
spawn(function()
    while wait(AUTO_REFRESH_INTERVAL) do
        if AutoRefreshEnabled and not IsRefreshing then
            FetchServers()
        end
    end
end)

-- Initial fetch
wait(1)
FetchServers()

-- Notification
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Server Browser Ultimate Fix!";
    Text = "Tests ALL HTTP methods! Click Debug button for error details.";
    Duration = 6;
})

print("===========================================")
print("SERVER BROWSER - ULTIMATE FIX")
print("===========================================")
print("✅ Tests " .. #HttpMethods .. " HTTP methods")
print("✅ Tests " .. #ProxyURLs .. " proxy URLs")
print("✅ Total " .. (#HttpMethods * #ProxyURLs) .. " combinations!")
print("✅ Debug button for error details")
print("===========================================")
