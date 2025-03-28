--[[
    EffectParameters.lua
    
    PURPOSE:
    Defines standardized parameter structures for different effect types.
    Provides validation and helper functions for effect parameters.
    
    DESIGN PRINCIPLES:
    - Single source of truth for parameter structure
    - Promotes consistency across the effect system
    - Simplifies parameter validation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local Constants = require(SharedPath:WaitForChild("Constants"))

local EFFECT = Constants.EFFECT

local EffectParameters = {}

-- Base parameters for all effects
EffectParameters.BASE = {
    sourceId = nil,      -- Source entity
    targetId = nil,      -- Target entity
    sourceAbility = nil  -- Source ability (if applicable)
}

-- Damage effect parameters
EffectParameters.DAMAGE = {
    amount = 0,             -- Base damage amount
    damageType = "physical", -- Damage type
    isCritical = false,     -- Is critical hit
    isPeriodic = false,     -- Is DoT damage
    conditionId = nil       -- Associated condition
}

-- Healing effect parameters
EffectParameters.HEALING = {
    amount = 0,           -- Base healing amount
    isCritical = false,   -- Is critical heal
    isPeriodic = false,   -- Is HoT healing
    conditionId = nil     -- Associated condition
}

-- Utility effect parameters
EffectParameters.UTILITY = {
    duration = 0,        -- Effect duration
    strength = 1,        -- Effect strength
    statName = nil,      -- Affected stat
    statValue = 0        -- Stat change value
}

-- Condition application parameters
EffectParameters.CONDITION = {
    conditionId = nil,   -- Condition identifier
    stacks = 1,          -- Number of stacks to apply
    duration = nil,      -- Duration (nil = use default)
    data = {}            -- Custom condition data
}

-- Movement effect parameters
EffectParameters.MOVEMENT = {
    direction = nil,     -- Movement direction
    force = 0,           -- Force amount
    duration = 0,        -- Effect duration
    blockMovement = false -- Whether to block other movement
}

-- Create parameter merge helper (adds defaults for missing values)
function EffectParameters.MergeWithDefaults(params, categoryName)
    if not params then return nil end
    
    local categoryTemplate = EffectParameters[categoryName]
    if not categoryTemplate then return params end
    
    local merged = {}
    
    -- Copy base parameters
    for field, value in pairs(EffectParameters.BASE) do
        merged[field] = params[field] ~= nil and params[field] or value
    end
    
    -- Copy category-specific parameters
    for field, value in pairs(categoryTemplate) do
        merged[field] = params[field] ~= nil and params[field] or value
    end
    
    -- Copy any additional custom parameters
    for field, value in pairs(params) do
        if merged[field] == nil then
            merged[field] = value
        end
    end
    
    return merged
end

-- Get parameter category for effect type
function EffectParameters.GetCategoryForEffectType(effectType)
    if effectType == EFFECT.TYPES.APPLY_DAMAGE or effectType == EFFECT.TYPES.APPLY_DOT then
        return "DAMAGE"
    elseif effectType == EFFECT.TYPES.APPLY_HEALING or effectType == EFFECT.TYPES.APPLY_HOT then
        return "HEALING"
    elseif effectType == EFFECT.TYPES.APPLY_STAT_MODIFIER or effectType == EFFECT.TYPES.REMOVE_STAT_MODIFIER then
        return "UTILITY"
    elseif effectType == EFFECT.TYPES.APPLY_KNOCKBACK or effectType == EFFECT.TYPES.APPLY_PULL or effectType == EFFECT.TYPES.APPLY_TELEPORT then
        return "MOVEMENT"
    elseif effectType == EFFECT.TYPES.APPLY_CONDITION or effectType == EFFECT.TYPES.REMOVE_CONDITION then
        return "CONDITION"
    else
        return nil
    end
end

-- Validate required parameters
function EffectParameters.ValidateRequired(params, effectType)
    if not params then
        return false, "No parameters provided"
    end
    
    -- Basic validation for all effects
    if not params.targetId then
        return false, "Missing required parameter: targetId"
    end
    
    -- Type-specific validation
    if effectType == EFFECT.TYPES.APPLY_DAMAGE or effectType == EFFECT.TYPES.APPLY_DOT then
        if not params.amount or params.amount <= 0 then
            return false, "Invalid damage amount"
        end
        
    elseif effectType == EFFECT.TYPES.APPLY_HEALING or effectType == EFFECT.TYPES.APPLY_HOT then
        if not params.amount or params.amount <= 0 then
            return false, "Invalid healing amount"
        end
        
    elseif effectType == EFFECT.TYPES.APPLY_CONDITION then
        if not params.conditionId then
            return false, "Missing required parameter: conditionId"
        end
        
    elseif effectType == EFFECT.TYPES.REMOVE_CONDITION then
        if not params.conditionId then
            return false, "Missing required parameter: conditionId"
        end
        
    elseif effectType == EFFECT.TYPES.APPLY_KNOCKBACK then
        if not params.direction or not params.force then
            return false, "Missing required parameter: direction or force"
        end
    end
    
    return true, nil
end

return EffectParameters
