--[[
    StatSystem.lua
    
    PURPOSE:
    Manages entity stats, including base values, modifiers, and conversion
    from rating-based stats to gameplay effects.
    
    DESIGN PRINCIPLES:
    - Clear separation of base stats and modifiers
    - Support for both flat and percentage modifiers
    - Diminishing returns for rating-based stats
    - Efficient recalculation with dirty flags
    - Level-based stat scaling
    
    USAGE:
    local StatSystem = require(path.to.StatSystem)
    local statSystem = StatSystem.new(entitySystem, eventSystem)
    
    -- Register entity stats
    statSystem:RegisterEntityStats(entityId, { power = 15, focus = 12 })
    
    -- Apply stat modifiers
    local modifierId = statSystem:ApplyStatModifier(entityId, {
        id = "GEAR_BONUS",
        source = "ITEM",
        flatModifiers = { power = 5 },
        percentModifiers = { maxHealth = 110 }, -- 110% = +10%
        duration = nil -- Permanent
    })
    
    -- Get final stat values
    local power = statSystem:GetStatValue(entityId, "power") -- Base + modifiers
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local Constants = require(SharedPath:WaitForChild("Constants"))

local STAT = Constants.STAT
local EVENTS = Constants.EVENTS
local LEVEL_SCALING = Constants.LEVEL_SCALING

-- StatSystem implementation
local StatSystem = {}
StatSystem.__index = StatSystem

function StatSystem.new(entitySystem, eventSystem)
    local self = setmetatable({}, StatSystem)
    self.EntitySystem = entitySystem
    self.EventSystem = eventSystem
    self.StatModifiers = {} -- entityId -> { modifierId -> modifierData }
    self.NextModifierId = 1
    self.DirtyStats = {} -- entityId -> { statName -> true }
    self.CachedStats = {} -- entityId -> { statName -> calculatedValue }
    
    -- Subscribe to events
    self.EventSystem:Subscribe(EVENTS.ENTITY_UNREGISTERED, function(data)
        self:CleanupEntityStats(data.entityId)
    end)
    
    return self
end

-- Generate a unique modifier ID
function StatSystem:GenerateModifierId()
    local modifierId = "mod_" .. self.NextModifierId
    self.NextModifierId = self.NextModifierId + 1
    return modifierId
end

-- Register base stats for an entity
function StatSystem:RegisterEntityStats(entityId, baseStats)
    -- Validate entity
    if not self.EntitySystem:EntityExists(entityId) then
        return false, "Entity does not exist"
    end
    
    -- Apply stats as attributes
    for statName, value in pairs(baseStats) do
        self.EntitySystem:SetAttribute(entityId, statName, value)
    end
    
    -- Initialize stat tracking for this entity
    if not self.StatModifiers[entityId] then
        self.StatModifiers[entityId] = {}
    end
    
    if not self.DirtyStats[entityId] then
        self.DirtyStats[entityId] = {}
    end
    
    if not self.CachedStats[entityId] then
        self.CachedStats[entityId] = {}
    end
    
    -- Mark all stats as dirty
    for statName, _ in pairs(baseStats) do
        self:MarkStatAsDirty(entityId, statName)
    end
    
    return true
end

-- Apply a stat modifier to an entity
function StatSystem:ApplyStatModifier(entityId, modifierData)
    -- Validate entity
    if not self.EntitySystem:EntityExists(entityId) then
        return nil, "Entity does not exist"
    end
    
    -- Validate modifier data
    if not modifierData.id then
        modifierData.id = self:GenerateModifierId()
    end
    
    -- Ensure entity has modifier tracking
    if not self.StatModifiers[entityId] then
        self.StatModifiers[entityId] = {}
    end
    
    -- Store the modifier
    self.StatModifiers[entityId][modifierData.id] = modifierData
    
    -- Mark affected stats as dirty
    if modifierData.flatModifiers then
        for statName, _ in pairs(modifierData.flatModifiers) do
            self:MarkStatAsDirty(entityId, statName)
        end
    end
    
    if modifierData.percentModifiers then
        for statName, _ in pairs(modifierData.percentModifiers) do
            self:MarkStatAsDirty(entityId, statName)
        end
    end
    
    -- Set up expiration timer if needed
    if modifierData.duration and modifierData.duration > 0 then
        task.delay(modifierData.duration, function()
            self:RemoveStatModifier(entityId, modifierData.id)
        end)
    end
    
    -- Publish event
    self.EventSystem:Publish(EVENTS.STAT_MODIFIER_ADDED, {
        entityId = entityId,
        modifierId = modifierData.id,
        modifierData = modifierData
    })
    
    return modifierData.id
end

-- Remove a stat modifier
function StatSystem:RemoveStatModifier(entityId, modifierId)
    -- Check if entity has modifiers
    local entityModifiers = self.StatModifiers[entityId]
    if not entityModifiers then
        return false, "Entity has no modifiers"
    end
    
    -- Check if modifier exists
    local modifier = entityModifiers[modifierId]
    if not modifier then
        return false, "Modifier not found"
    end
    
    -- Mark affected stats as dirty before removing
    if modifier.flatModifiers then
        for statName, _ in pairs(modifier.flatModifiers) do
            self:MarkStatAsDirty(entityId, statName)
        end
    end
    
    if modifier.percentModifiers then
        for statName, _ in pairs(modifier.percentModifiers) do
            self:MarkStatAsDirty(entityId, statName)
        end
    end
    
    -- Remove the modifier
    entityModifiers[modifierId] = nil
    
    -- Publish event
    self.EventSystem:Publish(EVENTS.STAT_MODIFIER_REMOVED, {
        entityId = entityId,
        modifierId = modifierId
    })
    
    return true
end

-- Mark a stat as dirty (needs recalculation)
function StatSystem:MarkStatAsDirty(entityId, statName)
    if not self.DirtyStats[entityId] then
        self.DirtyStats[entityId] = {}
    end
    
    self.DirtyStats[entityId][statName] = true
    
    -- Clear cache
    if self.CachedStats[entityId] then
        self.CachedStats[entityId][statName] = nil
    end
end

-- Calculate final stat value with all modifiers
function StatSystem:CalculateFinalStatValue(entityId, statName)
    -- Check if we have a valid cached value
    if self.CachedStats[entityId] and self.CachedStats[entityId][statName] and 
       not (self.DirtyStats[entityId] and self.DirtyStats[entityId][statName]) then
        return self.CachedStats[entityId][statName]
    end
    
    -- Get base stat value
    local baseStat = self.EntitySystem:GetAttribute(entityId, statName) or 0
    
    -- Apply level scaling to base stats if applicable
    local entityLevel = self.EntitySystem:GetAttribute(entityId, "level") or 1
    if entityLevel > 1 and self:IsScalableStat(statName) then
        -- Apply level scaling multiplier
        local levelMultiplier = 1 + (entityLevel - 1) * LEVEL_SCALING.STAT_MULTIPLIER_PER_LEVEL
        baseStat = baseStat * levelMultiplier
    end
    
    -- If no modifiers, return base value
    if not self.StatModifiers[entityId] then
        return baseStat
    end
    
    -- Calculate modifiers
    local flatBonus = 0
    local percentMultiplier = 100 -- 100% = no change
    
    for _, modifier in pairs(self.StatModifiers[entityId]) do
        -- Add flat bonuses
        if modifier.flatModifiers and modifier.flatModifiers[statName] then
            flatBonus = flatBonus + modifier.flatModifiers[statName]
        end
        
        -- Add percentage multipliers
        if modifier.percentModifiers and modifier.percentModifiers[statName] then
            percentMultiplier = percentMultiplier + (modifier.percentModifiers[statName] - 100)
        end
    end
    
    -- Apply modifiers
    local finalValue = (baseStat + flatBonus) * (percentMultiplier / 100)
    
    -- Cache the result
    if not self.CachedStats[entityId] then
        self.CachedStats[entityId] = {}
    end
    self.CachedStats[entityId][statName] = finalValue
    
    -- Clear dirty flag
    if self.DirtyStats[entityId] then
        self.DirtyStats[entityId][statName] = nil
    end
    
    return finalValue
end

-- Check if stat should scale with level
function StatSystem:IsScalableStat(statName)
    -- List of stats that scale with level
    local scalableStats = {
        [STAT.POWER] = true,
        [STAT.DEFENSE] = true,
        [STAT.FOCUS] = true,
        [STAT.HEALING_POWER] = true,
        [STAT.MAX_HEALTH] = true,
        [STAT.MAX_ENERGY] = true
    }
    
    return scalableStats[statName] or false
end

-- Get current value for a specific stat
function StatSystem:GetStatValue(entityId, statName)
    return self:CalculateFinalStatValue(entityId, statName)
end

-- Get all stats for an entity
function StatSystem:GetEntityStats(entityId)
    local entity = self.EntitySystem:GetEntity(entityId)
    if not entity then
        return nil, "Entity does not exist"
    end
    
    local stats = {}
    for statName, _ in pairs(entity.attributes) do
        stats[statName] = self:GetStatValue(entityId, statName)
    end
    
    return stats
end

-- Update entity level
function StatSystem:SetEntityLevel(entityId, level)
    if not self.EntitySystem:EntityExists(entityId) then
        return false, "Entity does not exist"
    end
    
    -- Validate level
    level = math.max(1, math.floor(level))
    
    -- Get current level
    local currentLevel = self.EntitySystem:GetAttribute(entityId, "level") or 1
    
    -- Only update if level changed
    if level == currentLevel then
        return true
    end
    
    -- Update level attribute
    self.EntitySystem:SetAttribute(entityId, "level", level)
    
    -- Mark all stats as dirty since level affects scaling
    local entity = self.EntitySystem:GetEntity(entityId)
    for statName, _ in pairs(entity.attributes) do
        if self:IsScalableStat(statName) then
            self:MarkStatAsDirty(entityId, statName)
        end
    end
    
    return true
end

-- Convert rating to effect value (for percentage stats)
function StatSystem:ConvertRatingToEffect(rating, statName, entityId)
    local targetLevel = 1
    
    -- Get entity level if provided
    if entityId then
        targetLevel = self.EntitySystem:GetAttribute(entityId, "level") or 1
    end
    
    -- Only handle rating-based stats
    local ratingConstants = STAT.DIMINISHING_RETURNS[statName]
    if not ratingConstants then
        return rating -- Not a rating-based stat
    end
    
    -- Get constants for this stat
    local baseValue = ratingConstants.BASE_VALUE
    
    -- Rating per percent scales with level
    local ratingPerPercent = ratingConstants.RATING_PER_PERCENT * 
                            (1 + (targetLevel - 1) * LEVEL_SCALING.RATING_INCREASE_PER_LEVEL)
                            
    local softCap = ratingConstants.SOFT_CAP
    local hardCap = ratingConstants.HARD_CAP
    
    -- Convert rating to effect
    local effect = baseValue + (rating / ratingPerPercent)
    
    -- Apply diminishing returns if soft cap exists
    if softCap and effect > softCap then
        if hardCap then
            -- Curve between soft and hard cap
            local overCap = effect - softCap
            local maxOverCap = hardCap - softCap
            local diminishedOverCap = maxOverCap * (1 - math.exp(-overCap / maxOverCap))
            effect = softCap + diminishedOverCap
        else
            -- Simple falloff after soft cap
            local overCap = effect - softCap
            effect = softCap + overCap * 0.5
        end
    end
    
    return effect
end

-- Get entity level
function StatSystem:GetEntityLevel(entityId)
    return self.EntitySystem:GetAttribute(entityId, "level") or 1
end

-- Calculate level-scaled stat value
function StatSystem:GetLevelScaledStatValue(baseValue, level, statName)
    -- Default level scaling
    local scaleFactor = 1 + (level - 1) * LEVEL_SCALING.STAT_MULTIPLIER_PER_LEVEL
    
    -- Apply scaling
    return baseValue * scaleFactor
end

-- Cleanup when entity is unregistered
function StatSystem:CleanupEntityStats(entityId)
    self.StatModifiers[entityId] = nil
    self.DirtyStats[entityId] = nil
    self.CachedStats[entityId] = nil
end

return StatSystem
