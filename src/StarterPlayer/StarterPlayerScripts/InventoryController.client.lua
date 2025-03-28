-- InventoryController (Client) - Manages inventory updates and player inputs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local InventoryEvents = require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("InventoryEventsModule"))
local UIController = require(ReplicatedStorage:WaitForChild("UIController"))

-- ✅ Local inventory storage
local inventoryData = {}

-- ✅ Listen for inventory updates from the server
local InventoryUpdateEvent = InventoryEvents.GetInventoryUpdateEvent()
InventoryUpdateEvent.OnClientEvent:Connect(function(newInventory)
	inventoryData = newInventory or {}
	print("[DEBUG] Full Inventory Data Received:", inventoryData)

	-- ✅ Ensure inventory structure is maintained
	if not inventoryData.items then inventoryData.items = {} end
	if not inventoryData.tools then inventoryData.tools = {} end

	-- ✅ Ensure UI properly updates
	UIController.UpdateInventoryUI(inventoryData)
end)

-- ✅ Toggle Inventory UI visibility when the player presses "T"
local inventoryVisible = false
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end  
	if input.KeyCode == Enum.KeyCode.T then
		inventoryVisible = not inventoryVisible
		UIController.SetInventoryUIVisible(inventoryVisible)
	end
end)

-- ✅ Ensure the client gets an inventory update on startup
task.wait(2) -- Small delay to ensure the server has processed the player's inventory
InventoryEvents.GetInventoryUpdateEvent():FireServer() -- ✅ Client requests update if needed
