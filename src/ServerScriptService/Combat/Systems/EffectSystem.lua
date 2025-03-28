--[[
    EffectSystem.lua
    
    PURPOSE:
    Provides a framework for executing gameplay effects (damage, healing, utility).
    Integrates with the StatSystem for stat-based calculations.
    
    REGISTERED EFFECTS:
    - APPLY_DAMAGE - Deals immediate damage to a target
    - APPLY_DOT - Applies damage over time
    - APPLY_HEALING - Heals target immediately
    - APPLY_HOT - Applies healing over time
    - APPLY_CONDITION - Applies a condition
    - REMOVE_CONDITION - Removes a condition
    - APPLY_STAT_MODIFIER - Modifies a stat value
    - REMOVE_STAT_MODIFIER - Removes a stat modifier
    - APPLY_KNOCKBACK - Applies knockback force
    - APPLY_PULL - Applies pull force
    - APPLY_TELEPORT - Teleports entity
    
    EXTENDING THE SYSTEM:
    
    To add a new effect:
    1. Add the effect type constant in Constants.lua
    2. Implement the effect function in the appropriate category:
       - Damage effects: damageEffects table
       - Healing effects: healingEffects table
       - Condition effects: conditionEffects table
       - Utility effects: utilityEffects table
       - Movement effects: movementEffects table
    3. Register with RegisterEffectCategory()
    4. Update this documentation header
    
    DESIGN PRINCIPLES:
    - Clean effect registration and execution
    - Stat-based scaling for effect calculations
    - Clear separation of effect types
    - Event-based communication with other systems
    - No circular dependencies
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local Constants = require(SharedPath:WaitForChild("Constants"))
local EffectParameters = require(SharedPath:WaitForChild("EffectParameters"))

local EFFECT = Constants.EFFECT
local CONDITION = Constants.CONDITION
local EVENTS = Constants.EVENTS

-- EffectSystem implementation
local EffectSystem = {}
EffectSystem.__index = EffectSystem

function EffectSystem.new(entitySystem, statSystem, eventSystem)
    local self = setmetatable({}, EffectSystem)
    self.EntitySystem = entitySystem
    self.StatSystem = statSystem
    self.EventSystem = eventSystem
    self.Effects = {}              -- Effect registry
    self.EffectCategories = {}     -- Categories of effects
    
    -- Initialize categories
    for categoryName, _ in pairs(EFFECT.CATEGORIES) do
        self.EffectCategories[categoryName] = {}
    end
    
    -- Initialize with built-in effects
    self:RegisterBuiltInEffects()
    
    return self
end

-- Connect to event system for cross-system communication
function EffectSystem:ConnectEvents(eventSystem)
    -- Publish readiness of this system
    eventSystem:Publish(EVENTS.EFFECT_SYSTEM_READY, {
        effectSystem = self
    })
end

-- Send a request event and get response directly from handler
function EffectSystem:SendEventWithResponse(eventType, data, timeout)
    timeout = timeout or 1 -- Default 1 second timeout (unused in direct approach)
    
    -- Get response handlers
    local responseHandlers = self.EventSystem:GetResponseHandlers(eventType)
    if #responseHandlers == 0 then
        warn("EffectSystem: No response handlers found for event type: " .. eventType)
        return false, { error = "No response handlers available" }
    end
    
    -- Use the first response handler (direct call)
    local success, result
    success, result = pcall(function()
        return responseHandlers[1](data)
    end)
    
    if success then
        return true, result
    else
        warn("EffectSystem: Error in response handler for " .. eventType .. ": " .. tostring(result))
        return false, { error = "Response handler error" }
    end
end

-- Register an effect
function EffectSystem:RegisterEffect(effectId, effectFn)
    if self.Effects[effectId] then
        warn("EffectSystem: Overwriting existing effect: " .. effectId)
    end
    
    self.Effects[effectId] = effectFn
    return true
end

-- Registers a category of effects for organization and filtering
function EffectSystem:RegisterEffectCategory(categoryName, effects)
    -- Ensure category exists
    self.EffectCategories[categoryName] = self.EffectCategories[categoryName] or {}
    
    -- Register effects in the category
    if effects then
        for effectId, effectFn in pairs(effects) do
            self.EffectCategories[categoryName][effectId] = effectFn
            self:RegisterEffect(effectId, effectFn)
        end
    end
    
    return true
end

-- Gets all effects in a category
function EffectSystem:GetEffectsInCategory(categoryName)
    return self.EffectCategories[categoryName] or {}
end

-- Checks if an effect belongs to a category
function EffectSystem:IsEffectInCategory(effectId, categoryName)
    return self.EffectCategories[categoryName] and 
           self.EffectCategories[categoryName][effectId] ~= nil
end

-- Execute an effect
function EffectSystem:ExecuteEffect(effectId, params)
    -- Step 1: Validation
    local effectFn = self.Effects[effectId]
    if not effectFn then
        return false, { error = "Effect not found: " .. effectId }
    end
    
    -- Get parameter category for this effect
    local paramCategory = EffectParameters.GetCategoryForEffectType(effectId)
    
    -- Validate required parameters
    local isValid, errorMessage = EffectParameters.ValidateRequired(params, effectId)
    if not isValid then
        return false, { error = errorMessage }
    end
    
    -- Step 2: Parameter Standardization (adds defaults for missing values)
    local processedParams = params
    if paramCategory then
        processedParams = EffectParameters.MergeWithDefaults(params, paramCategory)
    end
    
    -- Step 3: Execute the effect
    local success, result
    success, result = pcall(function()
        return effectFn(processedParams, self)
    end)
    
    -- Step 4: Handle execution results
    if not success then
        warn("EffectSystem: Error executing effect " .. effectId .. ": " .. tostring(result))
        self.EventSystem:Publish(EVENTS.EFFECT_FAILED, {
            effectId = effectId,
            params = processedParams,
            error = tostring(result)
        })
        return false, { error = "Effect execution failed", details = tostring(result) }
    end
    
    -- Step 5: Publish effect execution event
    self.EventSystem:Publish(EVENTS.EFFECT_EXECUTED, {
        effectId = effectId,
        params = processedParams,
        result = result
    })
    
    return success, result
end

-- Register built-in effects
function EffectSystem:RegisterBuiltInEffects()
    -- DAMAGE CATEGORY
    local damageEffects = {
        [EFFECT.TYPES.APPLY_DAMAGE] = function(params, system)
            -- Create standardized damage request parameters
            local damageRequestParams = EffectParameters.MergeWithDefaults({
                sourceId = params.sourceId,
                targetId = params.targetId,
                amount = params.amount,
                damageType = params.damageType or EFFECT.DAMAGE_TYPES.PHYSICAL,
                isCritical = params.isCritical,
                isPeriodic = params.isPeriodic,
                sourceAbility = params.sourceAbility,
                conditionId = params.conditionId
            }, "DAMAGE")
            
            -- Use event system to communicate with DamageSystem
            return system:SendEventWithResponse(EVENTS.DAMAGE_REQUEST, damageRequestParams)
        end,
        
        [EFFECT.TYPES.APPLY_DOT] = function(params, system)
            -- This is handled through conditions, just route to condition application
            local conditionParams = {
                sourceId = params.sourceId,
                targetId = params.targetId,
                conditionId = params.conditionId or CONDITION.IDS.BURNING, -- Use constant for default
                stacks = params.stacks or 1,
                duration = params.duration or CONDITION.DEFAULT_DURATION,
                data = {
                    sourceId = params.sourceId,
                    damagePerTick = params.damagePerTick or params.amount or 5,
                    tickRate = params.tickRate or CONDITION.DEFAULT_TICK_RATE,
                    damageType = params.damageType or EFFECT.DAMAGE_TYPES.FIRE
                }
            }
            
            return system:ExecuteEffect(EFFECT.TYPES.APPLY_CONDITION, conditionParams)
        end
    }
    
    -- HEALING CATEGORY
    local healingEffects = {
        [EFFECT.TYPES.APPLY_HEALING] = function(params, system)
            -- Create standardized healing request parameters
            local healingRequestParams = EffectParameters.MergeWithDefaults({
                sourceId = params.sourceId,
                targetId = params.targetId,
                amount = params.amount,
                isCritical = params.isCritical,
                isPeriodic = params.isPeriodic,
                sourceAbility = params.sourceAbility,
                conditionId = params.conditionId
            }, "HEALING")
            
            -- Use event system to communicate with DamageSystem
            return system:SendEventWithResponse(EVENTS.HEALING_REQUEST, healingRequestParams)
        end,
        
        [EFFECT.TYPES.APPLY_HOT] = function(params, system)
            -- This is handled through conditions, just route to condition application
            local conditionParams = {
                sourceId = params.sourceId,
                targetId = params.targetId,
                conditionId = params.conditionId or CONDITION.IDS.REGENERATION, -- Use constant for default
                stacks = params.stacks or 1,
                duration = params.duration or CONDITION.DEFAULT_DURATION,
                data = {
                    sourceId = params.sourceId,
                    healingPerTick = params.healingPerTick or params.amount or 5,
                    tickRate = params.tickRate or CONDITION.DEFAULT_TICK_RATE
                }
            }
            
            return system:ExecuteEffect(EFFECT.TYPES.APPLY_CONDITION, conditionParams)
        end
    }
    
    -- CONDITION CATEGORY
    local conditionEffects = {
        [EFFECT.TYPES.APPLY_CONDITION] = function(params, system)
            -- Create standardized condition request parameters
            local conditionRequestParams = {
                requestType = "APPLY", -- Specify the request type
                targetId = params.targetId,
                conditionId = params.conditionId,
                stacks = params.stacks or 1,
                duration = params.duration,
                data = {}
            }
            
            -- Include source ID for damage/healing over time
            conditionRequestParams.data.sourceId = params.sourceId
            
            -- Copy any additional data from params
            if params.data then
                for k, v in pairs(params.data) do
                    conditionRequestParams.data[k] = v
                end
            end
            
            -- Use event system to communicate with ConditionSystem
            return system:SendEventWithResponse(EVENTS.CONDITION_REQUEST, conditionRequestParams)
        end,
        
        [EFFECT.TYPES.REMOVE_CONDITION] = function(params, system)
            -- Create standardized removal request parameters
            local removalRequestParams = {
                requestType = "REMOVE", -- Specify the request type
                targetId = params.targetId,
                conditionId = params.conditionId,
                removeAllStacks = params.removeAllStacks or false
            }
            
            -- Use event system to communicate with ConditionSystem
            return system:SendEventWithResponse(EVENTS.CONDITION_REQUEST, removalRequestParams)
        end
    }
    
    -- UTILITY CATEGORY
    local utilityEffects = {
        [EFFECT.TYPES.APPLY_STAT_MODIFIER] = function(params, system)
            -- Validate the required parameter
            if not params.modifierData then
                return false, { error = "Missing required parameter: modifierData" }
            end
            
            -- Apply stat modifier
            local modifierId = system.StatSystem:ApplyStatModifier(params.targetId, params.modifierData)
            if not modifierId then
                return false, { error = "Failed to apply stat modifier" }
            end
            
            return true, { modifierId = modifierId }
        end,
        
        [EFFECT.TYPES.REMOVE_STAT_MODIFIER] = function(params, system)
            -- Validate the required parameter
            if not params.modifierId then
                return false, { error = "Missing required parameter: modifierId" }
            end
            
            -- Remove stat modifier
            local success = system.StatSystem:RemoveStatModifier(params.targetId, params.modifierId)
            if not success then
                return false, { error = "Failed to remove stat modifier" }
            end
            
            return true, { removed = true }
        end
    }
    
    -- MOVEMENT CATEGORY
    local movementEffects = {
        [EFFECT.TYPES.APPLY_KNOCKBACK] = function(params, system)
            -- Validate required parameters
            if not params.direction or not params.force then
                return false, { error = "Missing required parameters: direction or force" }
            end
            
            local entity = system.EntitySystem:GetEntity(params.targetId)
            if not entity or not entity.rootPart then
                return false, { error = "Invalid target or target has no root part" }
            end
            
            -- Apply knockback as a velocity change
            local rootPart = entity.rootPart
            local knockbackVector = params.direction.Unit * params.force
            
            -- Only apply horizontal knockback
            knockbackVector = Vector3.new(knockbackVector.X, 0, knockbackVector.Z)
            
            -- Apply knockback
            if rootPart:IsA("BasePart") then
                rootPart.Velocity = Vector3.new(knockbackVector.X, rootPart.Velocity.Y, knockbackVector.Z)
            end
            
            return true, { applied = true, force = params.force }
        end,
        
        [EFFECT.TYPES.APPLY_PULL] = function(params, system)
            -- Validate required parameters
            if not params.direction or not params.force then
                return false, { error = "Missing required parameters: direction or force" }
            end
            
            local entity = system.EntitySystem:GetEntity(params.targetId)
            if not entity or not entity.rootPart then
                return false, { error = "Invalid target or target has no root part" }
            end
            
            -- Apply pull (opposite of knockback)
            local rootPart = entity.rootPart
            local pullVector = params.direction.Unit * params.force * -1 -- Inverted direction
            
            -- Only apply horizontal pull
            pullVector = Vector3.new(pullVector.X, 0, pullVector.Z)
            
            -- Apply pull
            if rootPart:IsA("BasePart") then
                rootPart.Velocity = Vector3.new(pullVector.X, rootPart.Velocity.Y, pullVector.Z)
            end
            
            return true, { applied = true, force = params.force }
        end,
        
        [EFFECT.TYPES.APPLY_TELEPORT] = function(params, system)
            -- Validate required parameters
            if not params.position then
                return false, { error = "Missing required parameter: position" }
            end
            
            local entity = system.EntitySystem:GetEntity(params.targetId)
            if not entity or not entity.rootPart then
                return false, { error = "Invalid target or target has no root part" }
            end
            
            -- Apply teleport
            local rootPart = entity.rootPart
            if rootPart:IsA("BasePart") then
                rootPart.CFrame = CFrame.new(params.position)
            end
            
            return true, { applied = true, position = params.position }
        end
    }
    
    -- Register effect categories
    self:RegisterEffectCategory(EFFECT.CATEGORIES.DAMAGE, damageEffects)
    self:RegisterEffectCategory(EFFECT.CATEGORIES.HEALING, healingEffects)
    self:RegisterEffectCategory(EFFECT.CATEGORIES.CONDITION, conditionEffects)
    self:RegisterEffectCategory(EFFECT.CATEGORIES.UTILITY, utilityEffects)
    self:RegisterEffectCategory(EFFECT.CATEGORIES.MOVEMENT, movementEffects)
end

return EffectSystem
