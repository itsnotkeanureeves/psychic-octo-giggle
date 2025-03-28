-- UIUtilityModule.lua (Client Module)
local UIUtilityModule = {}

-- Services and references
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create or get main ScreenGui (identical to original)
-- not sure why InventoryUI is hardcoded here
function UIUtilityModule.GetOrCreateMainGui()
    local screenGui = playerGui:FindFirstChild("InventoryUI") or Instance.new("ScreenGui")
    screenGui.Name = "InventoryUI"
    screenGui.Parent = playerGui

    local cooldownDisplay = Instance.new("TextLabel")
    cooldownDisplay.Size = UDim2.new(0, 200, 0, 30)
    cooldownDisplay.Position = UDim2.new(0, 0, 0, 0)
    cooldownDisplay.BackgroundColor3 = Color3.new(0, 0, 0)
    cooldownDisplay.BackgroundTransparency = 0.5
    cooldownDisplay.TextColor3 = Color3.new(1, 1, 1)
    cooldownDisplay.Text = "Attack Ready"
    cooldownDisplay.Parent = playerGui
    return screenGui
end

-- UI Element Creation Functions
function UIUtilityModule.CreateFrame(name, size, position, color, parent)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = size
    frame.Position = position
    frame.BackgroundColor3 = color
    frame.Parent = parent
    return frame
end

function UIUtilityModule.CreateButton(name, text, size, position, color, parent)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = text
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color
    button.Parent = parent
    return button
end

function UIUtilityModule.CreateLabel(name, text, size, position, color, parent)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Text = text
    label.Size = size
    label.Position = position
    label.BackgroundColor3 = color
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Parent = parent
    return label
end

return UIUtilityModule