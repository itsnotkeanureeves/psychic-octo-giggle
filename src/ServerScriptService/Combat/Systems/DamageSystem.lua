--[[
    DamageSystem.lua
    
    PURPOSE:
    Handles damage and healing calculations and application to entities.
    Integrates with StatSystem for stat-based damage scaling.
    
    DESIGN PRINCIPLES:
    - Clean separation of calculation and application
    - Stat-based damage and healing
    - Critical hit determination
    - Defence mitigation
    - Level-based scaling
    - Event-based communication with other systems
    - No circular dependencies
    - Standardized effect types with action verbs (e.g., APPLY_DAMAGE)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local Constants = require(SharedPath:WaitForChild("Constants"))

local STAT = Constants.STAT
local EFFECT = Constants.EFFECT
local EVENTS = Constants.EVENTS
local LEVEL_SCALING = Constants.LEVEL_SCALING

-- DamageSystem implementation
local DamageSystem = {}
DamageSystem.__index = DamageSystem

function DamageSystem.new(entitySystem, statSystem, eventSystem, effectSystem)
    local self = setmetatable({}, DamageSystem)
    self.EntitySystem = entitySystem
    self.StatSystem = statSystem
    self.EventSystem = eventSystem
    self.ConditionSystem = nil -- Will be set via events
    
    return self
end

-- Connect to event system for cross-system communication
function DamageSystem:ConnectEvents(eventSystem)
    -- Register response handlers for direct communication
    eventSystem:SubscribeWithResponse(EVENTS.DAMAGE_REQUEST, function(data)
        local success, result = self:ApplyDamage(
            data.sourceId,
            data.targetId,
            {
                amount = data.amount,
                damageType = data.damageType,
                isCritical = data.isCritical,
                isPeriodic = data.isPeriodic,
                sourceAbility = data.sourceAbility,
                conditionId = data.conditionId
            }
        )
        
        return {
            success = success,
            result = result
        }
    end)
    
    -- Register healing response handler
    eventSystem:SubscribeWithResponse(EVENTS.HEALING_REQUEST, function(data)
        local success, result = self:ApplyHealing(
            data.sourceId,
            data.targetId,
            {
                amount = data.amount,
                isCritical = data.isCritical,
                isPeriodic = data.isPeriodic,
                sourceAbility = data.sourceAbility,
                conditionId = data.conditionId
            }
        )
        
        return {
            success = success,
            result = result
        }
    end)
    
    -- Subscribe to condition system events
    eventSystem:Subscribe(EVENTS.CONDITION_SYSTEM_READY, function(data)
        self.ConditionSystem = data.conditionSystem
    end)
    
    -- Publish readiness of this system
    eventSystem:Publish(EVENTS.DAMAGE_SYSTEM_READY, {
        damageSystem = self
    })
end

-- Calculate damage based on source and target stats
function DamageSystem:CalculateDamage(sourceId, targetId, baseDamage, options)
    options = options or {}
    
    -- Default values
    local damageType = options.damageType or EFFECT.DAMAGE_TYPES.PHYSICAL
    local isCritical = options.isCritical or false
    local ignoreDefence = options.ignoreDefence or false
    local isPeriodic = options.isPeriodic or false
    local sourceAbility = options.sourceAbility
    local conditionId = options.conditionId
    
    -- Get source and target entities
    local sourceEntity = self.EntitySystem:GetEntity(sourceId)
    local targetEntity = self.EntitySystem:GetEntity(targetId)
    
    if not sourceEntity or not targetEntity then
        return { amount = baseDamage, isCritical = isCritical }
    end
    
    -- Get entity levels
    local sourceLevel = self.EntitySystem:GetAttribute(sourceId, "level") or 1
    local targetLevel = self.EntitySystem:GetAttribute(targetId, "level") or 1
    
    -- Calculate level difference scaling
    local levelDifference = sourceLevel - targetLevel
    local levelScalingFactor = 1 + math.clamp(
        levelDifference * LEVEL_SCALING.DAMAGE_FACTOR_PER_LEVEL,
        -LEVEL_SCALING.MAX_LEVEL_MODIFIER,
        LEVEL_SCALING.MAX_LEVEL_MODIFIER
    )
    
    -- Get relevant stats
    local powerStat = isPeriodic and STAT.FOCUS or STAT.POWER
    local power = self.StatSystem:GetStatValue(sourceId, powerStat) or 10 -- Default to 10 if nil
    local defense = ignoreDefence and 0 or (self.StatSystem:GetStatValue(targetId, STAT.DEFENSE) or 5) -- Default to 5 if nil
    
    -- Adjust defense effectiveness based on level difference
    local defenseEffectiveness = 1
    if not ignoreDefence and levelDifference < 0 then
        -- When target is higher level than source, defense is more effective
        defenseEffectiveness = 1 + math.min(
            -levelDifference * LEVEL_SCALING.DEFENSE_FACTOR_PER_LEVEL,
            LEVEL_SCALING.MAX_LEVEL_MODIFIER
        )
        defense = defense * defenseEffectiveness
    end
    
    -- Calculate power scaling (every 10 power adds 10% damage)
    local powerMultiplier = 1 + (power * 0.01)
    
    -- Apply damage calculation formula
    local calculatedDamage = baseDamage * powerMultiplier
    
    -- Apply level scaling to damage
    calculatedDamage = calculatedDamage * levelScalingFactor
    
    -- Apply critical hit if specified or determined by precision
    if not isCritical and sourceEntity and not isPeriodic then
        local precision = self.StatSystem:GetStatValue(sourceId, STAT.PRECISION) or 5 -- Default to 5% crit chance
        local critChance = precision / 100
        isCritical = math.random() < critChance
    end
    
    -- Apply critical damage multiplier if critical
    if isCritical then
        local ferocity = (self.StatSystem:GetStatValue(sourceId, STAT.FEROCITY) or 150) / 100 -- Default to 150% crit damage
        calculatedDamage = calculatedDamage * ferocity
    end
    
    -- Apply defense mitigation (diminishing returns formula)
    -- Formula: Damage Reduction = defense / (defense + K * targetLevel)
    -- Where K is a constant that scales with level
    local defenseDenominator = LEVEL_SCALING.DEFENSE_DENOMINATOR_BASE * 
                              (targetLevel ^ LEVEL_SCALING.DEFENSE_DENOMINATOR_MULTIPLIER)
                              
    local defenseFactor = defense / (defense + defenseDenominator)
    local damageReduction = math.min(LEVEL_SCALING.MAX_DEFENSE_MITIGATION, defenseFactor)
    
    if not ignoreDefence then
        calculatedDamage = calculatedDamage * (1 - damageReduction)
    end
    
    -- Round to nearest integer
    calculatedDamage = math.floor(calculatedDamage + 0.5)
    
    -- Ensure minimum damage (always at least 1 damage if not fully mitigated)
    calculatedDamage = math.max(1, calculatedDamage)
    
    -- Create damage data structure
    local damageData = {
        amount = calculatedDamage,
        rawAmount = baseDamage,
        damageType = damageType,
        isCritical = isCritical,
        sourceId = sourceId,
        sourceLevel = sourceLevel,
        targetLevel = targetLevel,
        levelScalingFactor = levelScalingFactor,
        sourceAbility = sourceAbility,
        isPeriodic = isPeriodic,
        conditionId = conditionId,
        defenseReduction = damageReduction
    }
    
    return damageData
end

-- Apply damage to target
function DamageSystem:ApplyDamage(sourceId, targetId, damageData)
    -- Validate parameters
    if not targetId then
        return false, { error = "Missing target ID" }
    end
    
    -- Ensure we have a complete damage data structure
    if not damageData.amount then
        damageData = self:CalculateDamage(sourceId, targetId, damageData.rawAmount or 10, damageData)
    end
    
    -- Check if target exists and is alive
    if not self.EntitySystem:IsAlive(targetId) then
        return false, { error = "Target is already dead" }
    end
    
    -- Process damage through condition system if available
    local finalDamage = damageData.amount
    if self.ConditionSystem then
        local processedDamage = self.ConditionSystem:ProcessDamage(targetId, damageData)
        if processedDamage and processedDamage.amount then
            finalDamage = processedDamage.amount
        end
    end
    
    -- Get entity to apply damage to
    local entity = self.EntitySystem:GetEntity(targetId)
    if not entity then
        return false, { error = "Entity not found" }
    end
    
    -- Apply damage to health
    local currentHealth = self.EntitySystem:GetAttribute(targetId, "health") or 100
    local maxHealth = self.EntitySystem:GetAttribute(targetId, "maxHealth") or 100
    
    -- Apply damage
    local newHealth = math.max(0, currentHealth - finalDamage)
    
    -- Update health attribute
    self.EntitySystem:SetAttribute(targetId, "health", newHealth)
    
    -- Update the humanoid health if present
    if entity.humanoid then
        entity.humanoid.Health = (newHealth / maxHealth) * entity.humanoid.MaxHealth
    end
    
    -- Publish damage event
    self.EventSystem:Publish(EVENTS.DAMAGE_DEALT, {
        sourceId = sourceId,
        targetId = targetId,
        amount = finalDamage,
        damageType = damageData.damageType,
        isCritical = damageData.isCritical,
        isPeriodic = damageData.isPeriodic,
        isKillingBlow = (newHealth <= 0),
        sourceAbility = damageData.sourceAbility,
        conditionId = damageData.conditionId,
        sourceLevel = damageData.sourceLevel,
        targetLevel = damageData.targetLevel
    })
    
    -- Handle entity death
    if newHealth <= 0 then
        if entity.humanoid then
            entity.humanoid.Health = 0
        end
    end
    
    return true, {
        damage = finalDamage,
        newHealth = newHealth,
        isCritical = damageData.isCritical,
        isKillingBlow = (newHealth <= 0)
    }
end

-- Calculate healing amount
function DamageSystem:CalculateHealing(sourceId, targetId, baseHealing, options)
    options = options or {}
    
    -- Default values
    local isCritical = options.isCritical or false
    local sourceAbility = options.sourceAbility
    local isPeriodic = options.isPeriodic or false
    local conditionId = options.conditionId
    
    -- Get source and target entities
    local sourceEntity = self.EntitySystem:GetEntity(sourceId)
    local targetEntity = self.EntitySystem:GetEntity(targetId)
    
    if not sourceEntity or not targetEntity then
        return { amount = baseHealing, isCritical = isCritical }
    end
    
    -- Get entity levels
    local sourceLevel = self.EntitySystem:GetAttribute(sourceId, "level") or 1
    local targetLevel = self.EntitySystem:GetAttribute(targetId, "level") or 1
    
    -- Calculate level scaling (healing is less affected by level difference)
    local levelDifference = sourceLevel - targetLevel
    local levelScalingFactor = 1 + math.clamp(
        levelDifference * LEVEL_SCALING.DAMAGE_FACTOR_PER_LEVEL * 0.5, -- Half effect for healing
        -LEVEL_SCALING.MAX_LEVEL_MODIFIER * 0.5,
        LEVEL_SCALING.MAX_LEVEL_MODIFIER * 0.5
    )
    
    -- Get healing power stat
    local healingPower = self.StatSystem:GetStatValue(sourceId, STAT.HEALING_POWER) or 10
    
    -- Calculate healing power scaling (every 10 healing power adds 10% healing)
    local powerMultiplier = 1 + (healingPower * 0.01)
    
    -- Apply healing calculation formula
    local calculatedHealing = baseHealing * powerMultiplier * levelScalingFactor
    
    -- Apply critical healing if applicable
    if isCritical then
        local ferocity = (self.StatSystem:GetStatValue(sourceId, STAT.FEROCITY) or 150) / 100
        calculatedHealing = calculatedHealing * ferocity
    elseif not isPeriodic then
        -- Check for critical based on precision
        local precision = self.StatSystem:GetStatValue(sourceId, STAT.PRECISION) or 5
        local critChance = precision / 100
        
        if math.random() < critChance then
            isCritical = true
            local ferocity = (self.StatSystem:GetStatValue(sourceId, STAT.FEROCITY) or 150) / 100
            calculatedHealing = calculatedHealing * ferocity
        end
    end
    
    -- Round to nearest integer
    calculatedHealing = math.floor(calculatedHealing + 0.5)
    
    -- Create healing data structure
    local healingData = {
        amount = calculatedHealing,
        rawAmount = baseHealing,
        isCritical = isCritical,
        sourceId = sourceId,
        sourceLevel = sourceLevel,
        targetLevel = targetLevel,
        levelScalingFactor = levelScalingFactor,
        sourceAbility = sourceAbility,
        isPeriodic = isPeriodic,
        conditionId = conditionId
    }
    
    return healingData
end

-- Apply healing to target
function DamageSystem:ApplyHealing(sourceId, targetId, healingData)
    -- Validate parameters
    if not targetId then
        return false, { error = "Missing target ID" }
    end
    
    -- Ensure we have a complete healing data structure
    if not healingData.amount then
        healingData = self:CalculateHealing(sourceId, targetId, healingData.rawAmount or 10, healingData)
    end
    
    -- Check if target exists and is alive
    if not self.EntitySystem:IsAlive(targetId) then
        return false, { error = "Cannot heal dead target" }
    end
    
    -- Process healing through condition system if available
    local finalHealing = healingData.amount
    if self.ConditionSystem then
        local processedHealing = self.ConditionSystem:ProcessHealing(targetId, healingData)
        if processedHealing and processedHealing.amount then
            finalHealing = processedHealing.amount
        end
    end
    
    -- Get entity
    local entity = self.EntitySystem:GetEntity(targetId)
    if not entity then
        return false, { error = "Entity not found" }
    end
    
    -- Apply healing to health, up to max health
    local currentHealth = self.EntitySystem:GetAttribute(targetId, "health") or 0
    local maxHealth = self.EntitySystem:GetAttribute(targetId, "maxHealth") or 100
    local newHealth = math.min(maxHealth, currentHealth + finalHealing)
    
    -- Update health
    self.EntitySystem:SetAttribute(targetId, "health", newHealth)
    
    -- Update humanoid health if present
    if entity.humanoid then
        entity.humanoid.Health = (newHealth / maxHealth) * entity.humanoid.MaxHealth
    end
    
    -- Publish healing event
    self.EventSystem:Publish(EVENTS.HEALING_APPLIED, {
        sourceId = sourceId,
        targetId = targetId,
        amount = finalHealing,
        isCritical = healingData.isCritical,
        isPeriodic = healingData.isPeriodic,
        sourceAbility = healingData.sourceAbility,
        conditionId = healingData.conditionId,
        sourceLevel = healingData.sourceLevel,
        targetLevel = healingData.targetLevel
    })
    
    return true, {
        healing = finalHealing,
        newHealth = newHealth,
        isCritical = healingData.isCritical
    }
end

return DamageSystem
