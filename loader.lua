-- Honey Bun Hub: one entry point for every supported game.
local base = "https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-hub/main/"
-- Immutable safe farm revision: a cached main URL must not revive teleport routing.
local safeFarmBase = "https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-hub/3356fd1/"
-- Add future games here by universe ID (game.GameId).
local games = {
    [873703865] = "games/westbound.lua",
}
local current = {name = "UNIVERSAL", description = "No game-specific features added yet."}
local path = games[game.GameId]
if path then
    local ok, result = pcall(function()
        local source = game:HttpGet(base .. path .. "?refresh=" .. tostring(DateTime.now().UnixTimestampMillis), false)
        local chunk, message = loadstring(source)
        assert(chunk, message)
        return chunk()
    end)
    if ok and type(result) == "table" and type(result.name) == "string"
        and type(result.description) == "string" then
        current = result
    else
        warn("Honey Bun Hub: game module failed to load", result)
        current.description = "Game module unavailable. Run the loader to retry."
    end
end

local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
for _, name in ipairs({"ShiftMenu", "HoneyBunHub"}) do
    local old = playerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

local gui = Instance.new("ScreenGui")
gui.Name = "HoneyBunHub"
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -24, 0.5, 0)
panel.Size = UDim2.new(1, -48, 0.78, 0)
panel.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
panel.BorderSizePixel = 0
panel.Parent = gui
local limits = Instance.new("UISizeConstraint", panel)
limits.MaxSize = Vector2.new(520, 760)
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local border = Instance.new("UIStroke", panel)
border.Color = Color3.fromRGB(48, 48, 48)

local function text(parent, value, position, size, fontSize, shade)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = size
    label.Font = Enum.Font.Gotham
    label.Text = value
    label.TextSize = fontSize
    label.TextColor3 = Color3.fromRGB(shade, shade, shade)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

text(panel, "HONEY BUN HUB · SAFE 2", UDim2.fromOffset(28, 26), UDim2.new(1, -100, 0, 24), 18, 240).Font = Enum.Font.GothamMedium
text(panel, current.name, UDim2.fromOffset(28, 55), UDim2.new(1, -56, 0, 20), 10, 110)

local hide = Instance.new("TextButton")
hide.Position = UDim2.new(1, -60, 0, 23)
hide.Size = UDim2.fromOffset(32, 32)
hide.BackgroundTransparency = 1
hide.Text = "âˆ’"
hide.TextSize = 24
hide.TextColor3 = Color3.fromRGB(160, 160, 160)
hide.Font = Enum.Font.Gotham
hide.Parent = panel

local line = Instance.new("Frame", panel)
line.Position = UDim2.fromOffset(28, 96)
line.Size = UDim2.new(1, -56, 0, 1)
line.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
line.BorderSizePixel = 0
local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.Position = UDim2.fromOffset(28, 112)
tabs.Size = UDim2.new(1, -170, 0, 32)
tabs.BackgroundTransparency = 1
tabs.Parent = panel
local tabLayout = Instance.new("UIListLayout", tabs)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
local espTab = Instance.new("TextButton")
espTab.Name = "ESP"
espTab.Size = UDim2.fromOffset(72, 32)
espTab.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
espTab.BorderSizePixel = 0
espTab.Text = "ESP"
espTab.TextColor3 = Color3.fromRGB(20, 20, 20)
espTab.TextSize = 12
espTab.Font = Enum.Font.GothamMedium
espTab.AutoButtonColor = false
espTab.Parent = tabs
Instance.new("UICorner", espTab).CornerRadius = UDim.new(0, 6)
local farmTab
if type(current.farmPath)=="string" then
    farmTab=espTab:Clone()
    farmTab.Name,farmTab.Text,farmTab.LayoutOrder="Farm","FARM",1
    farmTab.BackgroundColor3,farmTab.TextColor3=Color3.fromRGB(30,30,30),Color3.fromRGB(200,200,200)
    farmTab.Parent=tabs
end

local content = Instance.new("ScrollingFrame")
content.Name = "ESPPage"
content.Position = UDim2.fromOffset(28, 160)
content.Size = UDim2.new(1, -56, 1, -238)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 2
content.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90)
content.CanvasSize = UDim2.fromOffset(0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.Parent = panel
local layout = Instance.new("UIListLayout", content)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
local farmContent, farmCleanup, farmMounted, farmLoading, farmNotice
if farmTab then
    farmContent=content:Clone()
    farmContent.Name,farmContent.Visible,farmContent.Parent="FarmPage",false,panel
end
local function selectPage(farm)
    content.Visible=not farm
    if farmContent then farmContent.Visible=farm end
    espTab.BackgroundColor3=Color3.fromRGB(farm and 30 or 235,farm and 30 or 235,farm and 30 or 235)
    espTab.TextColor3=Color3.fromRGB(farm and 200 or 20,farm and 200 or 20,farm and 200 or 20)
    if farmTab then
        farmTab.BackgroundColor3=farm and Color3.fromRGB(235,235,235) or Color3.fromRGB(30,30,30)
        farmTab.TextColor3=farm and Color3.fromRGB(20,20,20) or Color3.fromRGB(200,200,200)
    end
end
espTab.Activated:Connect(function()
    selectPage(false)
end)
if farmTab then
    farmTab.Activated:Connect(function()
        selectPage(true)
        if farmMounted or farmLoading then return end
        farmLoading=true
        if farmNotice then farmNotice:Destroy();farmNotice=nil end
        local ok,result=pcall(function()
            local source=game:HttpGet(safeFarmBase..current.farmPath,false)
            assert(source:find("Nearby targets only",1,true) and not source:find("root.CFrame = target.part.CFrame",1,true),"Outdated farm blocked; rerun the latest loader")
            assert(gui.Parent and farmContent.Parent,"Hub was closed during farm loading")
            local chunk,message=loadstring(source);assert(chunk,message)
            local mount=chunk();assert(type(mount)=="function","Farm module unavailable")
            local stop=mount(farmContent);assert(type(stop)=="function","Farm setup failed")
            return stop
        end)
        farmLoading=false
        if not gui.Parent then if ok then result() end;return end
        if ok then farmCleanup=result;farmMounted=true else
            warn("Honey Bun Hub: farm menu failed to load",result)
            farmNotice=text(farmContent,"Farm could not load. Click FARM to retry.",UDim2.fromOffset(0,0),UDim2.new(1,-8,0,42),12,170)
            farmNotice.TextWrapped=true
        end
    end)
end


local refresh = Instance.new("TextButton")
refresh.Position = UDim2.new(1, -126, 0, 112)
refresh.Size = UDim2.fromOffset(98, 32)
refresh.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
refresh.BorderSizePixel = 0
refresh.Text = "Refresh"
refresh.TextColor3 = Color3.fromRGB(220, 220, 220)
refresh.TextSize = 12
refresh.Font = Enum.Font.GothamMedium
refresh.Parent = panel
Instance.new("UICorner", refresh).CornerRadius = UDim.new(0, 6)

local refreshing = false
refresh.Activated:Connect(function()
    if refreshing then return end
    refreshing = true
    if farmCleanup then farmCleanup(); farmCleanup=nil end
    refresh.Text = "Refreshing..."
    local ok, message = pcall(function()
        local stamp = tostring(DateTime.now().UnixTimestampMillis)
        local revisionUrl = "https://api.github.com/repos/noahkcarmstrong-ops/honey-bun-hub/commits/main?refresh=" .. stamp
        local revision = game:GetService("HttpService"):JSONDecode(game:HttpGet(revisionUrl, false))
        local sha = revision and revision.sha
        assert(type(sha) == "string" and #sha == 40 and sha:match("^%x+$"), "GitHub did not return a valid update revision")
        local url = "https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-hub/" .. sha .. "/loader.lua"
        local source = game:HttpGet(url, false)
        local chunk, compileError = loadstring(source)
        assert(chunk, compileError)
        chunk()
    end)
    if not ok then
        warn("Honey Bun Hub: refresh failed", message)
        if refresh.Parent then
            refresh.Text = "Retry refresh"
        end
    end
    refreshing = false
end)

local footerLine = line:Clone()
footerLine.Position = UDim2.new(0, 28, 1, -64)
footerLine.Parent = panel
text(panel, "RIGHT SHIFT", UDim2.new(0, 28, 1, -48), UDim2.fromOffset(110, 24), 10, 190)
local hint = text(panel, "Show / hide", UDim2.new(0, 140, 1, -48), UDim2.new(1, -168, 0, 24), 11, 105)
hint.TextXAlignment = Enum.TextXAlignment.Right

hide.Activated:Connect(function() panel.Visible = false end)
local connection = Input.InputBegan:Connect(function(key)
    if Input:GetFocusedTextBox() then return end
    if key.KeyCode == Enum.KeyCode.RightShift then
        panel.Visible = not panel.Visible
    end
end)
local cleanup
gui.Destroying:Connect(function()
    connection:Disconnect()
    if cleanup then cleanup() end
    if farmCleanup then farmCleanup() end
end)

if type(current.mount) == "function" then
    local ok, result = pcall(current.mount, content)
    if ok and type(result) == "function" then
        cleanup = result
    elseif not ok then
        warn("Honey Bun Hub: game menu failed to load", result)
        text(content, "Game menu failed to load. Refresh to retry.",
            UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 40), 12, 170).TextWrapped = true
    end
end
