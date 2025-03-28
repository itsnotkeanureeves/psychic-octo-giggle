-- UIController.lua (Client Module - Main entry point) for inventory and enhancement
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryEventsModule = require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("InventoryEventsModule"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load utility module that has reusable functions 
local UIUtilityModule = require(ReplicatedStorage:WaitForChild("UIUtilityModule"))
local InventoryUIModule = require(ReplicatedStorage:WaitForChild("InventoryUIModule"))
local EnhancementUIModule = require(ReplicatedStorage:WaitForChild("EnhancementUIModule"))

-- Initialize modules
local inventoryUI = InventoryUIModule.Initialize()
local enhancementUI = EnhancementUIModule.Initialize()

-- Create the main controller with same interface as original
local UIController = {}

-- Expose the tool slots table from inventory module (maintaining original interface)
UIController.toolSlots = inventoryUI.toolSlots

-- Store the selected tool for enhancement (maintaining original interface)
UIController.selectedTool = enhancementUI.selectedTool

-- Expose functions from modules (maintaining original interface)
UIController.InitializeToolSlots = inventoryUI.InitializeToolSlots
UIController.UpdateToolSelectionUI = inventoryUI.UpdateToolSelectionUI
UIController.UpdateInventoryUI = inventoryUI.UpdateInventoryUI
UIController.SetInventoryUIVisible = inventoryUI.SetInventoryUIVisible
UIController.UpdateToolList = enhancementUI.UpdateToolList
UIController.ToggleEnhancementUI = enhancementUI.ToggleEnhancementUI
UIController.EnhanceSelectedTool = enhancementUI.EnhanceSelectedTool

-- Connect inventory updates to enhancement module
inventoryUI.OnToolsUpdated.Event:Connect(function(tools)
    enhancementUI.UpdateToolList(tools)
end)

-- Listen for inventory updates
InventoryEventsModule.GetInventoryUpdateEvent().OnClientEvent:Connect(function(invData)
    print("[DEBUG] Inventory Update Received:", invData)
    UIController.UpdateInventoryUI(invData)
    UIController.UpdateToolSelectionUI(invData)
end)

-- Initialize tool slots (identical to original)
UIController.InitializeToolSlots()

return UIController