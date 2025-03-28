-- EnhancementCalculator.lua
-- A shared module for calculating enhancement success chances
-- Do we need to make a copy of this in server that the server references and leave this accessible for client UI?
-- May need to setup remote event to send info for UI? i.e calculate success chance. Do not want to share calculatiosn with clients

local RuneDefs = game.ReplicatedStorage:FindFirstChild("RuneDefinitionsModule") and 
                 require(game.ReplicatedStorage.RuneDefinitionsModule) or nil

local EnhancementCalculator = {}

-- Base chance calculation function
-- This function calculates the raw base chance without any modifiers
function EnhancementCalculator.CalculateBaseChance(enhancementLevel)
    local baseChance = 1.0 - (enhancementLevel * 0.05)
    -- Cap between 0% and 100%
    return math.max(0, math.min(1, baseChance))
end

-- Calculate Soul Stone bonus based on enhancement level
function EnhancementCalculator.CalculateSoulStoneBonus(enhancementLevel, soulStoneCount)
    -- Formula: Each Soul Stone adds (10% / enhancement level)
    local bonusPerStone = 0.1 / enhancementLevel
    return bonusPerStone * soulStoneCount
end


-- Calculate success chance with all applicable modifiers
-- Parameters:
--   enhancementLevel: The current enhancement level of the tool
--   modifiers: (optional) A table of additional modifiers:
--     modifiers.runeName: Name of rune to apply (server-side only)
--     modifiers.runeBonus: Direct success chance bonus (can be used on client)
--     modifiers.itemBonus: Any bonus from items/consumables
--     modifiers.eventBonus: Any bonus from temporary events
function EnhancementCalculator.CalculateSuccessChance(enhancementLevel, modifiers)
    -- Start with base calculation
    local successChance = EnhancementCalculator.CalculateBaseChance(enhancementLevel)
    
    -- Apply modifiers if provided
    if modifiers then
        -- Apply rune bonus if a rune name is provided and RuneDefs is available
        if modifiers.runeName and RuneDefs then
            local rune = RuneDefs.Runes[modifiers.runeName]
            if rune then
                successChance = successChance + rune.successBonus
            end
        end
        
        -- Apply direct rune bonus if specified
        if modifiers.runeBonus then
            successChance = successChance + modifiers.runeBonus
        end
        
        -- Apply Soul Stone bonus if specified
        if modifiers.soulStoneCount and modifiers.soulStoneCount > 0 then
            local soulStoneBonus = EnhancementCalculator.CalculateSoulStoneBonus(enhancementLevel, modifiers.soulStoneCount)
            successChance = successChance + soulStoneBonus
            
            -- Record the bonus for tooltip etc display purposes
            modifiers.soulStoneBonus = soulStoneBonus
        end
        
        -- Apply item bonus if specified
        if modifiers.itemBonus then
            successChance = successChance + modifiers.itemBonus
        end
        
        -- Apply event bonus if specified
        if modifiers.eventBonus then
            successChance = successChance + modifiers.eventBonus
        end
    end
    
    -- Ensure chance is capped between 0% and 100%
    return math.max(0, math.min(1, successChance))
end


-- Format success chance for display
-- Parameters:
--   successChance: Raw success chance value (0-1)
--   decimalPlaces: Number of decimal places (default: 1)
function EnhancementCalculator.FormatSuccessChance(successChance, decimalPlaces)
    decimalPlaces = decimalPlaces or 1
    local multiplier = 10 ^ decimalPlaces
    local percentage = math.floor(successChance * 100 * multiplier) / multiplier
    return percentage
end

-- Get color based on success chance percentage
function EnhancementCalculator.GetColorForChance(successPercentage)
    if successPercentage >= 80 then
        return Color3.fromRGB(0, 255, 0) -- Green
    elseif successPercentage >= 50 then
        return Color3.fromRGB(255, 255, 0) -- Yellow
    else
        return Color3.fromRGB(255, 0, 0) -- Red
    end
end

return EnhancementCalculator