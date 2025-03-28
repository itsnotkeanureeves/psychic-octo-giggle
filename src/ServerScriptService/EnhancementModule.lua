-- EnhancementModule (Module) - Handles tool enhancement logic.
local ToolDefs = require(game.ReplicatedStorage:WaitForChild("GameData"):WaitForChild("Definitions"):WaitForChild("ToolDefinitionsModule"))
local RuneDefs = require(game.ReplicatedStorage.RuneDefinitionsModule)
local InventoryManager = require(game.ServerScriptService.InventoryManager)
local DebugUtil = require(game.ReplicatedStorage.DebugUtil)
local EnhancementCalculator = require(game.ReplicatedStorage.EnhancementCalculator)

local EnhancementModule = {}

-- this function checks for enhancement failure or success. InventoryManager updates the tool details.
function EnhancementModule.AttemptEnhancement(player, toolName, runeName, modifiers)
    local inventory = InventoryManager:GetInventory(player)
    if not inventory then
        DebugUtil:Log("ERROR: Inventory not found for " .. player.Name)
        return false, "No inventory found."
    end
    
    -- Ensure the player has the tool
    local tool = inventory.tools[toolName]
    if not tool then
        DebugUtil:Log("ERROR: " .. player.Name .. " tried enhancing without owning " .. toolName)
        return false, "Tool not found."
    end
    
    -- Initialize modifiers if not provided
    modifiers = modifiers or {}
    
    -- Apply rune bonus if used
    local usedRune = nil
    if runeName then
        usedRune = RuneDefs.Runes[runeName]
        if usedRune then
            modifiers.runeName = runeName
            InventoryManager:AddItem(player, runeName, -1)  -- Remove rune
        end
    end
    
    -- Calculate enhancement success chance using the centralized calculator
    local successChance = EnhancementCalculator.CalculateSuccessChance(tool.enhancementLevel, modifiers)
    
    -- Enhancement attempt
    local success = math.random() < successChance
    
    -- Call `EnhanceTool()` in InventoryManager to update the inventory properly
    return InventoryManager:EnhanceTool(player, toolName, success)
end

return EnhancementModule