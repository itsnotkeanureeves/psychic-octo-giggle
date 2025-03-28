-- ItemNotificationModule.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ItemRarityModule = require(game:GetService("ReplicatedStorage"):WaitForChild("GameData"):WaitForChild("Definitions"):WaitForChild("ItemRarityDefinitionsModule"))
local InventoryEventsModule = require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("InventoryEventsModule"))

local ItemNotificationModule = {}
local notificationQueue = {}
local processingQueue = false

function ItemNotificationModule:InitializeGUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    if playerGui:FindFirstChild("ItemNotifications") then 
        return playerGui:FindFirstChild("ItemNotifications") 
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ItemNotifications"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    
    local container = Instance.new("Frame")
    container.Name = "NotificationContainer"
    container.Size = UDim2.new(0, 200, 0, 300)
    container.Position = UDim2.new(0.8, 0, 0.7, 0)
    container.BackgroundTransparency = 1
    container.Parent = screenGui
    
    return screenGui
end

function ItemNotificationModule:CreateNotification(itemName, amount)
    local player = Players.LocalPlayer
    local gui = self:InitializeGUI()
    local container = gui.NotificationContainer
    
    -- Get rarity properties for this item
    local rarityProps = ItemRarityModule:GetRarityPropertiesForItem(itemName)
    
    -- Create notification label
    local notification = Instance.new("TextLabel")
    notification.Name = "ItemNotification"
    notification.Size = UDim2.new(0, 200, 0, 40)
    notification.Position = UDim2.new(0, 0, 1, 0) -- Start at bottom
    notification.BackgroundTransparency = 0.7
    notification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    notification.TextColor3 = rarityProps.color
    notification.TextStrokeTransparency = 0.5
    notification.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    notification.Font = Enum.Font.GothamBold
    notification.TextSize = 16 * rarityProps.scale
    notification.Text = amount > 1 and (itemName .. " x" .. amount) or itemName
    notification.TextXAlignment = Enum.TextXAlignment.Center
    notification.TextYAlignment = Enum.TextYAlignment.Center
    notification.BorderSizePixel = 0
    notification.Parent = container
    
    -- Animate the notification
    local floatUpInfo = TweenInfo.new(
        rarityProps.displayTime * 0.8,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )
    
    local fadeOutInfo = TweenInfo.new(
        rarityProps.displayTime * 0.3,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out,
        0, false, rarityProps.displayTime * 0.7
    )
    
    local floatUpGoal = {
        Position = UDim2.new(0, 0, 0, 0)
    }
    
    local fadeOutGoal = {
        TextTransparency = 1,
        BackgroundTransparency = 1
    }
    
    local floatUpTween = TweenService:Create(notification, floatUpInfo, floatUpGoal)
    local fadeOutTween = TweenService:Create(notification, fadeOutInfo, fadeOutGoal)
    
    floatUpTween:Play()
    fadeOutTween:Play()
    
    -- Clean up after animation finishes
    fadeOutTween.Completed:Connect(function()
        notification:Destroy()
    end)
end

function ItemNotificationModule:QueueNotification(itemName, amount)
    table.insert(notificationQueue, {itemName = itemName, amount = amount})
    
    if not processingQueue then
        self:ProcessQueue()
    end
end

function ItemNotificationModule:ProcessQueue()
    processingQueue = true
    
    while #notificationQueue > 0 do
        local notification = table.remove(notificationQueue, 1)
        self:CreateNotification(notification.itemName, notification.amount)
        task.wait(0.1) -- Small delay between notifications
    end
    
    processingQueue = false
end


--[[Possibly unecessary 
function ItemNotificationModule:HandleInventoryUpdate(...)
    local args = {...}
    
    -- Try to detect the format of the data
    if #args >= 2 and type(args[2]) == "table" then
        -- Assumed format: (inventoryData, changes)
        local changes = args[2]
        for itemName, changeData in pairs(changes) do
            if type(changeData) == "table" and changeData.added and changeData.added > 0 then
                self:QueueNotification(itemName, changeData.added)
            end
        end
    elseif #args == 1 and type(args[1]) == "table" then
        -- Format might be a direct changes list
        local data = args[1]
        for itemName, amount in pairs(data) do
            if type(amount) == "number" and amount > 0 then
                self:QueueNotification(itemName, amount)
            elseif type(amount) == "table" and amount.added and amount.added > 0 then
                self:QueueNotification(itemName, amount.added)
            end
        end
    end
end
]]--

-- In ItemNotificationModule:Initialize() add a new event listener
function ItemNotificationModule:Initialize()

    -- Add listener for the specific ItemAdded event
    local itemAddedEvent = InventoryEventsModule.GetItemAddedEvent()
    itemAddedEvent.OnClientEvent:Connect(function(itemName, amount)
        -- Direct notification
        self:QueueNotification(itemName, amount)
    end)
    
    return self
end

return ItemNotificationModule
