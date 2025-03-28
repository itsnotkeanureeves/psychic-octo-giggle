-- RespourceDropTables (Module) - Defines drop table properties consisting of inventory items in ReplicatedStorage

-- local ResourceDropTables = require(ServerScriptService:WaitForChild("GameData"):WaitForChild("DropTables"):WaitForChild("ResourceDropTables"))


local DropTables = {}

-- Define tables with weights as {itemName = weight} pairs
-- reference itemdefinitions.lua for intended rarities
DropTables.Tables = { --Consider focusing this on Resource Node Drop Tables. Create new module for Enemydrops, item/chest/etc drops
    zone_1_ore = {
        {item = "Stone", weight = 1.0},
        {item = "SmallStone", weight = 1.5},  -- More common
        {item = "IronOre", weight = 0.2},      -- Less common
        {item = "SoulStone", weight = 0.1}
    },
    zone_1_wood = {
        {item = "OakLog", weight = 1.0},
        {item = "PineLog", weight = 1.0},
        {item = "BirchLog", weight = 0.8},     
        {item = "SoulStone", weight = 0.1}
    },
}

-- Global event multipliers (applied to all drop tables)
DropTables.EventMultipliers = {
    default = { 
        {default = 1.0 } -- Default event with default multiplier
        -- Add event multipliers here, e.g., "double_iron_weekend" = 2.0
    },  
}

-- Current active event (or "default" if no event is active)
DropTables.CurrentEvent = "default"

function DropTables:GetRandomDrop(tableKey)
    local dropTable = self.Tables[tableKey]
    if not dropTable or #dropTable == 0 then
        return nil
    end
    
    -- Calculate total weight
    local totalWeight = 0
    for _, itemData in ipairs(dropTable) do
        -- Apply event multipliers if applicable
        local effectiveWeight = itemData.weight
        
        -- Apply event-specific multipliers if they exist
        local eventMultipliers = self.EventMultipliers[self.CurrentEvent]
        if eventMultipliers then
            -- Check for item-specific multiplier first
            if eventMultipliers[itemData.item] then
                effectiveWeight = effectiveWeight * eventMultipliers[itemData.item]
            -- If no item-specific multiplier, use the default for this event
            elseif eventMultipliers.default then
                effectiveWeight = effectiveWeight * eventMultipliers.default
            end
        end
        
        -- Store the calculated weight temporarily
        itemData.effectiveWeight = effectiveWeight
        totalWeight = totalWeight + effectiveWeight
    end
    
    -- Pick a random point within the total weight
    local randomPoint = math.random() * totalWeight
    local currentWeight = 0
    
    -- Find which item corresponds to the random point
    for _, itemData in ipairs(dropTable) do
        currentWeight = currentWeight + itemData.effectiveWeight
        if randomPoint <= currentWeight then
            -- Clean up temporary property
            dropTable.effectiveWeight = nil
            return itemData.item
        end
    end
    
    -- Fallback to the last item if something goes wrong
    -- Clean up temporary property
    dropTable.effectiveWeight = nil
    return dropTable[#dropTable].item
end

-- Function to set the current event
function DropTables:SetEvent(eventName)
    if self.EventMultipliers[eventName] then
        self.CurrentEvent = eventName
    else
        -- Create the event if it doesn't exist
        self.EventMultipliers[eventName] = {default = 1.0}
        self.CurrentEvent = eventName
    end
end

-- Function to reset to default (no event)
function DropTables:ResetEvent()
    self.CurrentEvent = "default"
end

-- Function to define an event with specific item multipliers
function DropTables:DefineEvent(eventName, itemMultipliers)
    self.EventMultipliers[eventName] = itemMultipliers or {default = 1.0}
end

-- Function to set a specific item multiplier for the current event
function DropTables:SetItemEventMultiplier(itemName, multiplier)
    if not self.EventMultipliers[self.CurrentEvent] then
        self.EventMultipliers[self.CurrentEvent] = {default = 1.0}
    end
    
    self.EventMultipliers[self.CurrentEvent][itemName] = multiplier
end

return DropTables

--[[
-- Example 2: Define an "Iron Rush Weekend" event
DropTables:DefineEvent("iron_rush_weekend", {
    default = 1.0,      -- Default multiplier for non-specified items
    IronOre = 2.0       -- Iron is 2x more likely
})

-- Example 3: Activate the event
DropTables:SetEvent("iron_rush_weekend")
randomItem = DropTables:GetRandomDrop("zone_1_ore")
print("Random item during Iron Rush event:", randomItem)

-- Example 4: Make a quick adjustment during the event
DropTables:SetItemEventMultiplier("Stone", 0.5) -- Reduce Stone drops by half
randomItem = DropTables:GetRandomDrop("zone_1_ore")
print("Random item after Stone adjustment:", randomItem)

-- Example 5: End the event
DropTables:ResetEvent()
randomItem = DropTables:GetRandomDrop("zone_1_ore")
print("Random item after event ended:", randomItem)
]]--