--[[
    FeedbackTypes.lua
    
    PURPOSE:
    Defines standardized feedback types and constants for the feedback system.
    This centralization ensures consistency across all visual feedback.
    
    USAGE:
    Local FeedbackTypes = require(ReplicatedStorage.Combat.FeedbackTypes)
    
    -- Access feedback type constants
    local floatingValueType = FeedbackTypes.FEEDBACK_TYPE.FLOATING_VALUE
    
    -- Access status text constants
    local blockedText = FeedbackTypes.STATUS_TEXT.BLOCKED
    
    -- Access damage color
    local fireColor = FeedbackTypes.DAMAGE_COLORS.fire
]]

-- Feedback type identifiers
local FEEDBACK_TYPE = {
    FLOATING_VALUE = "floatingValue",
    STATUS_TEXT = "statusText",
    CHARACTER_FLASH = "characterFlash"
}

-- Status text constants
local STATUS_TEXT = {
    IMMUNE = "IMMUNE",
    BLOCKED = "BLOCKED",
    EVADED = "EVADED",
    CRITICAL = "CRITICAL",
    CONDITION_ADDED = "CONDITION_ADDED",
    CONDITION_REMOVED = "CONDITION_REMOVED"
}

-- Color mappings for damage types
local DAMAGE_COLORS = {
    physical = Color3.fromRGB(255, 0, 0),    -- Red
    fire = Color3.fromRGB(255, 100, 0),      -- Orange
    ice = Color3.fromRGB(100, 200, 255),     -- Light blue
    nature = Color3.fromRGB(0, 200, 0),      -- Green
    lightning = Color3.fromRGB(220, 220, 0)  -- Yellow
}

return {
    FEEDBACK_TYPE = FEEDBACK_TYPE,
    STATUS_TEXT = STATUS_TEXT,
    DAMAGE_COLORS = DAMAGE_COLORS
}
