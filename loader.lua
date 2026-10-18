-- Honey Bun Hub: one entry point for every supported game.
local base = "https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-hub/main/"
-- Add future games here by universe ID (game.GameId).
local games = {
    [873703865] = "games/westbound.lua",
}
local current = {name = "UNIVERSAL", description = "No game-specific features added yet."}
local path = games[game.GameId]
if path then
    local ok, result = pcall(function()
        local source = game:HttpGet(base .. path, false)
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

text(panel, "HONEY BUN HUB", UDim2.fromOffset(28, 26), UDim2.new(1, -100, 0, 24), 18, 240).Font = Enum.Font.GothamMedium
text(panel, current.name, UDim2.fromOffset(28, 55), UDim2.new(1, -56, 0, 20), 10, 110)

local hide = Instance.new("TextButton")
hide.Position = UDim2.new(1, -60, 0, 23)
hide.Size = UDim2.fromOffset(32, 32)
hide.BackgroundTransparency = 1
hide.Text = "−"
hide.TextSize = 24
hide.TextColor3 = Color3.fromRGB(160, 160, 160)
hide.Font = Enum.Font.Gotham
hide.Parent = panel

local line = Instance.new("Frame", panel)
line.Position = UDim2.fromOffset(28, 96)
line.Size = UDim2.new(1, -56, 0, 1)
line.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
line.BorderSizePixel = 0
text(panel, "OVERVIEW", UDim2.fromOffset(28, 120), UDim2.new(1, -56, 0, 20), 11, 120)


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
gui.Destroying:Connect(function() connection:Disconnect() end)
