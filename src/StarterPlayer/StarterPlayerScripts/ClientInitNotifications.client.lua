-- ClientInitNotifications.lua (Client)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function InitItemNotifications()
    local success, result = pcall(function()
        -- Make sure InventoryEventsModule is loaded first
        require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("InventoryEventsModule"))
        local ItemNotificationModule = require(ReplicatedStorage:WaitForChild("ItemNotificationModule"))
        return ItemNotificationModule:Initialize()
    end)
    
    if not success then
        warn("Failed to initialize item notifications:", result)
    end
end

-- Initialize when the player is ready
game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
    task.spawn(InitItemNotifications)
end)

-- Also try to initialize immediately in case character is already loaded
if game:GetService("Players").LocalPlayer.Character then
    task.spawn(InitItemNotifications)
end