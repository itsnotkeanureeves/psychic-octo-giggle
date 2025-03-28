-- InventoryManager (ModuleScript) - Manages player inventories in memory in ServerScriptService
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Players             = game:GetService("Players")
local HttpService         = game:GetService("HttpService") -- Needed for UUID generation in creating player specific items
local RemoteEventModules = game:GetService("ReplicatedStorage").RemoteEventModules

-- Require shared modules
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("GameData"):WaitForChild("Definitions"):WaitForChild("ItemDefinitionsModule"))
local ToolDefinitions = require(ReplicatedStorage:WaitForChild("GameData"):WaitForChild("Definitions"):WaitForChild("ToolDefinitionsModule"))
local InventoryEvents = require(RemoteEventModules:WaitForChild("InventoryEventsModule"))
local DebugUtil       = require(ReplicatedStorage:WaitForChild("DebugUtil"))



-- Table to hold inventories: key = Player, value = inventory structure
local inventories = {}

local InventoryManager = {}

-- Initialize remote references
local InventoryUpdate = InventoryEvents.GetInventoryUpdateEvent()
local ItemAdded = InventoryEvents.GetItemAddedEvent()

-- Create an inventory for a new player and give starter tools
function InventoryManager:CreateInventory(player: Player)
    inventories[player] = {
        items = {},
        tools = {},
        activeTools = {}
    }

    -- Get starter set tools
    local starterTools = ToolDefinitions.giveToolSet(player, "Starter Set")
    for toolName, toolData in pairs(starterTools) do
        -- Generate unique UUID to be used as the tool's identity
        local uuid = HttpService:GenerateGUID(false)
        
        -- Clone the tool data
        local newTool = table.clone(toolData)
        
        -- Set displayName to the original tool name
        newTool.displayName = toolData.baseName
        
        -- Store the tool using UUID as the key (not as a property)
        inventories[player].tools[uuid] = newTool
    end

	self:AddItem(player, "SoulStone", 10)
    DebugUtil:Log("Created inventory for " .. player.Name .. " with starter tools")
    
    InventoryUpdate:FireClient(player, inventories[player]) -- UI updates on game start
    
    return inventories[player]
end
-- Remove a player's inventory (cleanup on leave)
function InventoryManager:RemoveInventory(player: Player)
    -- Ensure data is saved before removing from memory
    local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))
    PlayerDataManager:SaveData(player, true)

	inventories[player] = nil
	DebugUtil:Log("Removed inventory for " .. player.Name)
end

-- Get a player's inventory
function InventoryManager:GetInventory(player: Player)
	return inventories[player]
end

-- Add an item to a player's inventory
function InventoryManager:AddItem(player: Player, itemName: string, amount: number)
	local inv = inventories[player]
	if not inv then return false end

	inv.items[itemName] = (inv.items[itemName] or 0) + amount
	DebugUtil:Log(player.Name .. " received " .. amount .. "x " .. itemName)

    -- Fire both events - general inventory update and specific item added for itemnotification
    InventoryUpdate:FireClient(player, inv)
    ItemAdded:FireClient(player, itemName, amount)
	return true
end

-- Add a tool to the player's inventory
function InventoryManager:AddTool(player: Player, toolName: string)
	local inv = inventories[player]
	if not inv then return false end

	local toolData = ToolDefinitions.Tools[toolName]
	if not toolData then return false end

	-- ✅ Ensure the tool gets a unique, persistent ID
	local newTool = table.clone(toolData)
	newTool.toolId = HttpService:GenerateGUID(false) -- Generate a unique tool ID
	newTool.displayName = newTool.baseName -- Start with base name as the display name

	inv.tools[newTool.toolId] = newTool -- Store using toolId
	
	DebugUtil:Log(player.Name .. " received tool: " .. toolName .. " (ID: " .. newTool.toolId .. ")")
	return newTool.toolId
end

-- Enhance a player's tool
function InventoryManager:EnhanceTool(player: Player, toolId: string, success: boolean)
	local inv = inventories[player]
	
	if not inv then
		DebugUtil:Log("ERROR: EnhanceTool failed - inventory not found for " .. player.Name)
		return false, "No inventory found."
	end

	local tool = inv.tools[toolId]
	
	if not tool then
		DebugUtil:Log("ERROR: " .. player.Name .. " tried enhancing a non-existent tool (ID: " .. toolId .. ")")
		return false, "Tool not found."
	end


	if success then
		tool.enhancementLevel = tool.enhancementLevel + 1

		-- ✅ Ensure tool keeps the same toolId
		local newToolName = tool.baseName .. " +" .. tool.enhancementLevel .. " (" .. player.Name .. ")"
		tool.displayName = newToolName -- Store display name separately

		DebugUtil:Log(player.Name .. " successfully enhanced " .. newToolName .. " (ID: " .. toolId .. ")")
	else
		tool.durability = math.max(tool.durability - 1, 0)
		DebugUtil:Log(player.Name .. " failed enhancement. Durability of " .. toolId .. " now is " .. tool.durability)
	end

	InventoryUpdate:FireClient(player, inv)
	return true, success and "Enhancement succeeded!" or "Enhancement failed. Durability lost."
end

-- Set active tool for a specific type
function InventoryManager:SetActiveTool(player: Player, toolId: string)
	local inv = inventories[player]
	if not inv then return false, "Inventory not found." end

	local tool = inv.tools[toolId]
	if not tool then return false, "Tool not found." end

	local toolType = tool.toolType
	if not toolType then return false, "Invalid tool type." end

	-- Store by unique toolId
	inv.activeTools[toolType] = toolId
	DebugUtil:Log(player.Name .. " set active tool for " .. toolType .. " to " .. toolId)

	InventoryUpdate:FireClient(player, inv)

	return true, "Tool set successfully."
end

return InventoryManager
