-- InventoryEvents (Server) - Handles inventory-related events and player inventory lifecycle in ServerScriptService
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Updated: Use the new module from ServerScriptService
local InventoryEventsModule = require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("InventoryEventsModule"))
local InventoryManager = require(ServerScriptService:WaitForChild("InventoryManager"))
local DebugUtil = require(ReplicatedStorage:WaitForChild("DebugUtil"))

-- Get the events
local InventoryUpdateEvent = InventoryEventsModule.GetInventoryUpdateEvent()
local SetActiveToolEvent = InventoryEventsModule.GetSetActiveToolEvent()
local ItemAddedEvent = InventoryEventsModule.GetItemAddedEvent()

-- Helper: Send the player's current inventory to their client
local function sendInventoryToClient(player)
    local inv = InventoryManager:GetInventory(player) or {}
    InventoryUpdateEvent:FireClient(player, inv)
    DebugUtil:Log("Sent inventory update to " .. player.Name)
end

-- Player added: initialize inventory and send initial state
Players.PlayerAdded:Connect(function(player)
    InventoryManager:CreateInventory(player)
    -- ✅ Explicitly send the player's full inventory immediately
    task.wait(1) -- Small delay to ensure inventory is set before sending
    local inv = InventoryManager:GetInventory(player) or {}
    InventoryUpdateEvent:FireClient(player, inv)
    DebugUtil:Log("[SERVER] Sent initial inventory update to " .. player.Name)
end)

-- In case players are already in game (e.g., during server script reload), initialize them
for _, player in ipairs(Players:GetPlayers()) do
    InventoryManager:CreateInventory(player)
    sendInventoryToClient(player)
end

-- Player removing: clean up their inventory data
Players.PlayerRemoving:Connect(function(player)
    InventoryManager:RemoveInventory(player)
end)

-- Listen for tool selection requests from the UI
SetActiveToolEvent.OnServerEvent:Connect(function(player, toolName)
    local success, message = InventoryManager:SetActiveTool(player, toolName)

    if success then
        DebugUtil:Log("[SERVER] " .. player.Name .. " successfully set active tool: " .. toolName)
    else
        DebugUtil:Log("[ERROR SERVER] Failed to set active tool for " .. player.Name .. ": " .. message)
    end
end)