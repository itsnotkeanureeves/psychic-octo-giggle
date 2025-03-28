--[[
    ConditionSystem.lua
    
    PURPOSE:
    Manages buff/debuff conditions applied to entities.
    Handles stacking, duration, periodic effects, and transformations.
    
    DESIGN PRINCIPLES:
    - Clean stack management
    - Efficient tick processing
    - Support for condition interactions
    - Transformation rules
    
    USAGE:
    local ConditionSystem = require(path.to.ConditionSystem)
    local conditionSystem = ConditionSystem.new(entitySystem, statSystem, eventSystem, effectSystem)
    
    -- Apply a condition
    local success, result = conditionSystem:ApplyCondition(targetId, "BURNING", 3, 5, {
        sourceId = sourceId,
        damagePerTick = 10
    })
    
    -- Check if entity has condition
    local hasCondition = conditionSystem:HasCondition(targetId, "BURNING")
    
    -- Remove a condition
    conditionSystem:RemoveCondition(targetId, "BURNING", true)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local Constants = require(SharedPath:WaitForChild("Constants"))

local CONDITION = Constants.CONDITION
local EVENTS = Constants.EVENTS

-- ConditionSystem implementation
local ConditionSystem = {}
ConditionSystem.__index = ConditionSystem

function ConditionSystem.new(entitySystem, statSystem, eventSystem, effectSystem)
    local self = setmetatable({}, ConditionSystem)
    self.EntitySystem = entitySystem
    self.StatSystem = statSystem
    self.EventSystem = eventSystem
    self.EffectSystem = effectSystem
    
    -- Condition storage
    self.Conditions = {} -- Registry of condition definitions
    self.EntityConditions = {} -- entityId -> conditionId -> conditionState
    self.ConditionTimers = {} -- entityId -> conditionId -> timer identifiers
    
    -- Connect to heartbeat for tick processing
    self.HeartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        self:Update(dt)
    end)
    
    -- Clean up conditions when entity is unregistered
    self.EventSystem:Subscribe(EVENTS.ENTITY_UNREGISTERED, function(data)
        self:CleanupEntityConditions(data.entityId)
    end)
    
    -- Note: Definitions will be loaded by DefinitionLoader instead of here
    -- No direct loading in constructor
    
    return self
end

-- Register a condition definition
function ConditionSystem:RegisterCondition(conditionId, conditionData)
    if self.Conditions[conditionId] then
        warn("ConditionSystem: Overwriting existing condition: " .. conditionId)
    end
    
    -- Set default values
    conditionData.maxStacks = conditionData.maxStacks or CONDITION.MAX_STACKS
    conditionData.defaultDuration = conditionData.defaultDuration or CONDITION.DEFAULT_DURATION
    conditionData.stackBehavior = conditionData.stackBehavior or CONDITION.STACK_BEHAVIORS.REFRESH
    conditionData.removeStacksOnExpire = conditionData.removeStacksOnExpire or 1
    conditionData.tickRate = conditionData.tickRate or CONDITION.DEFAULT_TICK_RATE
    
    self.Conditions[conditionId] = conditionData
    return true
end

-- Get condition definition
function ConditionSystem:GetConditionDefinition(conditionId)
    return self.Conditions[conditionId]
end

-- PHASE 3 ENHANCEMENT: Data Inheritance Helper
-- Applies data inheritance rules when refreshing conditions
function ConditionSystem:ApplyDataInheritance(existingCondition, newData, inheritanceRules)
    if not newData then return end
    
    -- If no inheritance rules specified, just merge data
    if not inheritanceRules then
        for key, value in pairs(newData) do
            existingCondition.data[key] = value
        end
        return
    end
    
    -- Apply specific inheritance rules
    for field, rule in pairs(inheritanceRules) do
        if rule == CONDITION.DATA_INHERITANCE.PRESERVE then
            -- Keep original value, do nothing
        elseif rule == CONDITION.DATA_INHERITANCE.LATEST then
            -- Use new value if provided
            if newData[field] ~= nil then
                existingCondition.data[field] = newData[field]
            end
        elseif rule == CONDITION.DATA_INHERITANCE.SUM then
            -- Add values together
            if newData[field] ~= nil then
                existingCondition.data[field] = (existingCondition.data[field] or 0) + newData[field]
            end
        elseif rule == CONDITION.DATA_INHERITANCE.MAX then
            -- Take maximum value
            if newData[field] ~= nil then
                existingCondition.data[field] = math.max(existingCondition.data[field] or 0, newData[field])
            end
        elseif rule == CONDITION.DATA_INHERITANCE.MIN then
            -- Take minimum value
            if newData[field] ~= nil then
                existingCondition.data[field] = math.min(existingCondition.data[field] or 0, newData[field])
            end
        end
    end
    
    -- For fields not specified in rules, use latest value
    for key, value in pairs(newData) do
        if not inheritanceRules[key] then
            existingCondition.data[key] = value
        end
    end
end

-- Apply a condition to an entity
function ConditionSystem:ApplyCondition(targetId, conditionId, stacks, duration, data)
    -- Validate parameters
    if not targetId or not conditionId then
        return false, { error = "Missing target ID or condition ID" }
    end
    
    -- Check if entity exists
    if not self.EntitySystem:EntityExists(targetId) then
        return false, { error = "Target entity does not exist" }
    end
    
    -- Check if condition is defined
    local conditionDef = self:GetConditionDefinition(conditionId)
    if not conditionDef then
        return false, { error = "Condition not defined: " .. conditionId }
    end
    
    -- Default values
    stacks = stacks or 1
    duration = duration or conditionDef.defaultDuration
    data = data or {}
    
    -- Check if entity is alive
    if not self.EntitySystem:IsAlive(targetId) then
        return false, { error = "Cannot apply condition to dead entity" }
    end
    
    -- Check for preventing conditions
    local preventedBy = self:IsPreventedByOtherCondition(targetId, conditionId)
    if preventedBy then
        return false, { error = "Condition prevented by: " .. preventedBy }
    end
    
    -- Initialize storage if needed
    if not self.EntityConditions[targetId] then
        self.EntityConditions[targetId] = {}
    end
    
    if not self.ConditionTimers[targetId] then
        self.ConditionTimers[targetId] = {}
    end
    
    -- Check for existing condition and handle stacking
    local existingCondition = self.EntityConditions[targetId][conditionId]
    local isFirstApplication = false
    local stackCountChanged = false
    
    if existingCondition then
        -- PHASE 3 ENHANCEMENT: Enhanced Stack Behavior Support
        if conditionDef.stackBehavior == CONDITION.STACK_BEHAVIORS.REFRESH then
            -- Refresh duration, keep stack count
            existingCondition.remainingDuration = duration
            
            -- Apply data inheritance
            if conditionDef.dataInheritance then
                self:ApplyDataInheritance(existingCondition, data, conditionDef.dataInheritance)
            else
                -- Default behavior: simply merge data
                for key, value in pairs(data) do
                    existingCondition.data[key] = value
                end
            end
            
        elseif conditionDef.stackBehavior == CONDITION.STACK_BEHAVIORS.ADD then
            -- Add stacks, keep longer duration
            existingCondition.remainingDuration = math.max(existingCondition.remainingDuration, duration)
            
            -- Handle stack limit
            local newStacks = math.min(existingCondition.stacks + stacks, conditionDef.maxStacks)
            stackCountChanged = (newStacks ~= existingCondition.stacks)
            existingCondition.stacks = newStacks
            
            -- Apply data inheritance
            if conditionDef.dataInheritance then
                self:ApplyDataInheritance(existingCondition, data, conditionDef.dataInheritance)
            else
                -- Default behavior: simply merge data
                for key, value in pairs(data) do
                    existingCondition.data[key] = value
                end
            end
            
        elseif conditionDef.stackBehavior == CONDITION.STACK_BEHAVIORS.INDEPENDENT then
            -- In a more advanced implementation, this would create separate instances
            -- For simplicity, we'll treat it as REFRESH for now but mark for future expansion
            
            existingCondition.remainingDuration = duration
            
            -- Handle stack limit
            local newStacks = math.min(existingCondition.stacks + stacks, conditionDef.maxStacks)
            stackCountChanged = (newStacks ~= existingCondition.stacks)
            existingCondition.stacks = newStacks
            
            -- Apply data inheritance
            if conditionDef.dataInheritance then
                self:ApplyDataInheritance(existingCondition, data, conditionDef.dataInheritance)
            else
                -- Default behavior: simply merge data
                for key, value in pairs(data) do
                    existingCondition.data[key] = value
                end
            end
        end
    else
        -- Create new condition state
        isFirstApplication = true
        stackCountChanged = true
        
        self.EntityConditions[targetId][conditionId] = {
            conditionId = conditionId,
            stacks = math.min(stacks, conditionDef.maxStacks),
            remainingDuration = duration,
            tickTimer = conditionDef.tickRate,
            data = table.clone(data) -- Clone to avoid reference issues
        }
        
        existingCondition = self.EntityConditions[targetId][conditionId]
        
        -- PHASE 3 ENHANCEMENT: Complete Condition Interaction Implementation
        -- Check for conditions to remove
        if conditionDef.removes and #conditionDef.removes > 0 then
            for _, removeId in ipairs(conditionDef.removes) do
                if self:HasCondition(targetId, removeId) then
                    self:RemoveCondition(targetId, removeId, true)
                end
            end
        end
    end
    
    -- Call onApply handler
    if conditionDef.handlers and conditionDef.handlers.onApply then
        local applyParams = {
            targetId = targetId,
            sourceId = data.sourceId,
            stacks = existingCondition.stacks,
            duration = existingCondition.remainingDuration,
            data = existingCondition.data,
            isFirstApplication = isFirstApplication,
            stackCountChanged = stackCountChanged
        }
        
        -- Execute handler with error handling
        pcall(function()
            conditionDef.handlers.onApply(applyParams, self)
        end)
    end
    
    -- Set up timers (clear existing ones first)
    self:ClearConditionTimers(targetId, conditionId)
    self:SetupConditionTimers(targetId, conditionId)
    
    -- Publish condition applied event
    self.EventSystem:Publish(EVENTS.CONDITION_APPLIED, {
        targetId = targetId,
        conditionId = conditionId,
        stacks = existingCondition.stacks,
        duration = existingCondition.remainingDuration,
        isFirstApplication = isFirstApplication,
        stackCountChanged = stackCountChanged,
        data = data
    })
    
    -- Check for possible transformation
    self:CheckConditionTransformation(targetId, conditionId)
    
    return true, {
        conditionId = conditionId,
        stacks = existingCondition.stacks,
        duration = existingCondition.remainingDuration
    }
end

-- Remove a condition from an entity
function ConditionSystem:RemoveCondition(targetId, conditionId, removeAllStacks)
    -- Validate parameters
    if not targetId or not conditionId then
        return false, { error = "Missing target ID or condition ID" }
    end
    
    -- Check if entity has this condition
    if not self:HasCondition(targetId, conditionId) then
        return false, { error = "Entity does not have condition: " .. conditionId }
    end
    
    -- Get condition state and definition
    local conditionState = self.EntityConditions[targetId][conditionId]
    local conditionDef = self:GetConditionDefinition(conditionId)
    
    if not conditionDef then
        -- If definition is missing but we have state, just remove it
        self.EntityConditions[targetId][conditionId] = nil
        self:ClearConditionTimers(targetId, conditionId)
        return true
    end
    
    -- Determine how many stacks to remove
    local stacksToRemove = removeAllStacks and conditionState.stacks or 1
    local newStacks = math.max(0, conditionState.stacks - stacksToRemove)
    local fullyRemoved = (newStacks == 0)
    
    -- Update stack count or remove condition
    if fullyRemoved then
        -- Call onRemove handler before removing
        if conditionDef.handlers and conditionDef.handlers.onRemove then
            local removeParams = {
                targetId = targetId,
                stacks = conditionState.stacks,
                data = conditionState.data
            }
            
            -- Execute handler with error handling
            pcall(function()
                conditionDef.handlers.onRemove(removeParams, self)
            end)
        end
        
        -- Remove condition state
        self.EntityConditions[targetId][conditionId] = nil
        
        -- Clear timers
        self:ClearConditionTimers(targetId, conditionId)
        
        -- Publish condition removed event
        self.EventSystem:Publish(EVENTS.CONDITION_REMOVED, {
            targetId = targetId,
            conditionId = conditionId
        })
    else
        -- Update stacks
        conditionState.stacks = newStacks
        
        -- Publish stack removed event
        self.EventSystem:Publish(EVENTS.CONDITION_STACK_REMOVED, {
            targetId = targetId,
            conditionId = conditionId,
            stacks = newStacks,
            stacksRemoved = stacksToRemove
        })
    end
    
    return true, {
        fullyRemoved = fullyRemoved,
        remainingStacks = newStacks
    }
end

-- Check if entity has a condition
function ConditionSystem:HasCondition(targetId, conditionId)
    return self.EntityConditions[targetId] and 
           self.EntityConditions[targetId][conditionId] ~= nil
end

-- Get condition data
function ConditionSystem:GetConditionData(targetId, conditionId)
    if not self:HasCondition(targetId, conditionId) then
        return nil
    end
    
    -- Return a copy to prevent direct modification
    local conditionState = self.EntityConditions[targetId][conditionId]
    return {
        conditionId = conditionId,
        stacks = conditionState.stacks,
        remainingDuration = conditionState.remainingDuration,
        data = table.clone(conditionState.data)
    }
end

-- Get all active conditions for an entity
function ConditionSystem:GetActiveConditions(targetId)
    if not self.EntityConditions[targetId] then
        return {}
    end
    
    local activeConditions = {}
    
    for conditionId, conditionState in pairs(self.EntityConditions[targetId]) do
        table.insert(activeConditions, {
            conditionId = conditionId,
            stacks = conditionState.stacks,
            remainingDuration = conditionState.remainingDuration,
            data = table.clone(conditionState.data)
        })
    end
    
    return activeConditions
end

-- Check if condition is prevented by another condition
function ConditionSystem:IsPreventedByOtherCondition(targetId, conditionId)
    if not self.EntityConditions[targetId] then
        return nil
    end
    
    for existingId, _ in pairs(self.EntityConditions[targetId]) do
        local existingDef = self:GetConditionDefinition(existingId)
        
        if existingDef and existingDef.prevents then
            for _, preventedId in ipairs(existingDef.prevents) do
                if preventedId == conditionId then
                    return existingId
                end
            end
        end
    end
    
    return nil
end

-- Set up condition timers
function ConditionSystem:SetupConditionTimers(targetId, conditionId)
    if not self:HasCondition(targetId, conditionId) then
        return
    end
    
    local conditionState = self.EntityConditions[targetId][conditionId]
    local conditionDef = self:GetConditionDefinition(conditionId)
    
    if not conditionDef then
        return
    end
    
    -- Initialize timer storage
    if not self.ConditionTimers[targetId] then
        self.ConditionTimers[targetId] = {}
    end
    
    if not self.ConditionTimers[targetId][conditionId] then
        self.ConditionTimers[targetId][conditionId] = {}
    end
    
    -- Set up expiration timer
    if conditionState.remainingDuration > 0 then
        local expirationTimer = task.delay(conditionState.remainingDuration, function()
            self:HandleConditionExpiration(targetId, conditionId)
        end)
        
        self.ConditionTimers[targetId][conditionId].expiration = expirationTimer
    end
    
    -- No need to set up tick timer as we use Heartbeat for ticking
end

-- Clear condition timers
function ConditionSystem:ClearConditionTimers(targetId, conditionId)
    if not self.ConditionTimers[targetId] or not self.ConditionTimers[targetId][conditionId] then
        return
    end
    
    -- Cancel expiration timer if exists
    if self.ConditionTimers[targetId][conditionId].expiration then
        -- Add proper error handling around thread cancellation
        pcall(function()
            task.cancel(self.ConditionTimers[targetId][conditionId].expiration)
        end)
        self.ConditionTimers[targetId][conditionId].expiration = nil
    end
    
    -- Clear timer storage
    self.ConditionTimers[targetId][conditionId] = {}
end

-- Handle condition expiration
function ConditionSystem:HandleConditionExpiration(targetId, conditionId)
    if not self:HasCondition(targetId, conditionId) then
        return
    end
    
    local conditionState = self.EntityConditions[targetId][conditionId]
    local conditionDef = self:GetConditionDefinition(conditionId)
    
    if not conditionDef then
        -- If definition is missing, just remove the condition
        self.EntityConditions[targetId][conditionId] = nil
        return
    end
    
    -- Call onExpire handler
    if conditionDef.handlers and conditionDef.handlers.onExpire then
        local expireParams = {
            targetId = targetId,
            stacks = conditionState.stacks,
            data = conditionState.data
        }
        
        -- Execute handler with error handling
        pcall(function()
            conditionDef.handlers.onExpire(expireParams, self)
        end)
    end
    
    -- Remove stacks according to definition
    local stacksToRemove = conditionDef.removeStacksOnExpire or 1
    local newStacks = math.max(0, conditionState.stacks - stacksToRemove)
    
    if newStacks == 0 then
        -- Remove condition entirely
        self:RemoveCondition(targetId, conditionId, true)
    else
        -- Update stacks
        conditionState.stacks = newStacks
        
        -- Reset duration for remaining stacks
        conditionState.remainingDuration = conditionDef.defaultDuration
        
        -- Set up new expiration timer
        self:ClearConditionTimers(targetId, conditionId)
        self:SetupConditionTimers(targetId, conditionId)
        
        -- Publish stack removed event
        self.EventSystem:Publish(EVENTS.CONDITION_STACK_REMOVED, {
            targetId = targetId,
            conditionId = conditionId,
            stacks = newStacks,
            stacksRemoved = stacksToRemove
        })
    end
end

-- Process damage through conditions
function ConditionSystem:ProcessDamage(targetId, damageData)
    -- If entity has no conditions, return original damage
    if not self.EntityConditions[targetId] then
        return damageData
    end
    
    -- Create a copy of damage data to modify
    local processedDamage = table.clone(damageData)
    
    -- Check each condition for damage modification
    for conditionId, conditionState in pairs(self.EntityConditions[targetId]) do
        local conditionDef = self:GetConditionDefinition(conditionId)
        
        if conditionDef and conditionDef.handlers and conditionDef.handlers.onDamaged then
            local damageParams = {
                targetId = targetId,
                sourceId = processedDamage.sourceId,
                amount = processedDamage.amount,
                damageType = processedDamage.damageType,
                isCritical = processedDamage.isCritical,
                stacks = conditionState.stacks,
                data = conditionState.data
            }
            
            -- Execute handler with error handling
            local success, result = pcall(function()
                return conditionDef.handlers.onDamaged(damageParams, self)
            end)
            
            -- Apply modification if handler returned a valid result
            if success and result and result.amount then
                processedDamage.amount = result.amount
                
                -- Optional overrides
                if result.damageType then
                    processedDamage.damageType = result.damageType
                end
                
                if result.isCritical ~= nil then
                    processedDamage.isCritical = result.isCritical
                end
            end
        end
    end
    
    return processedDamage
end

-- Process healing through conditions
function ConditionSystem:ProcessHealing(targetId, healingData)
    -- If entity has no conditions, return original healing
    if not self.EntityConditions[targetId] then
        return healingData
    end
    
    -- Create a copy of healing data to modify
    local processedHealing = table.clone(healingData)
    
    -- Check each condition for healing modification
    for conditionId, conditionState in pairs(self.EntityConditions[targetId]) do
        local conditionDef = self:GetConditionDefinition(conditionId)
        
        if conditionDef and conditionDef.handlers and conditionDef.handlers.onHealed then
            local healParams = {
                targetId = targetId,
                sourceId = processedHealing.sourceId,
                amount = processedHealing.amount,
                isCritical = processedHealing.isCritical,
                stacks = conditionState.stacks,
                data = conditionState.data
            }
            
            -- Execute handler with error handling
            local success, result = pcall(function()
                return conditionDef.handlers.onHealed(healParams, self)
            end)
            
            -- Apply modification if handler returned a valid result
            if success and result and result.amount then
                processedHealing.amount = result.amount
                
                -- Optional overrides
                if result.isCritical ~= nil then
                    processedHealing.isCritical = result.isCritical
                end
            end
        end
    end
    
    return processedHealing
end

-- Check for condition transformation
function ConditionSystem:CheckConditionTransformation(targetId, conditionId)
    if not self:HasCondition(targetId, conditionId) then
        return
    end
    
    local conditionState = self.EntityConditions[targetId][conditionId]
    local conditionDef = self:GetConditionDefinition(conditionId)
    
    if not conditionDef or not conditionDef.transform then
        return
    end
    
    -- Check if transformation is possible
    if conditionDef.transform.condition and conditionDef.transform.targetCondition then
        local shouldTransform = false
        
        -- Execute transform condition check with error handling
        pcall(function()
            shouldTransform = conditionDef.transform.condition({
                targetId = targetId,
                conditionId = conditionId,
                stacks = conditionState.stacks,
                data = conditionState.data
            })
        end)
        
        -- Apply transformation if condition is met
        if shouldTransform then
            local targetCondition = conditionDef.transform.targetCondition
            local preserveStacks = conditionDef.transform.preserveStacks
            local transformData = conditionDef.transform.data or {}
            
            -- Merge current data with transform data
            local mergedData = table.clone(transformData)
            for key, value in pairs(conditionState.data) do
                if mergedData[key] == nil then
                    mergedData[key] = value
                end
            end
            
            -- Source of transformation
            mergedData.transformSourceCondition = conditionId
            
            -- Apply new condition
            local stacks = preserveStacks and conditionState.stacks or 1
            local duration = conditionDef.transform.duration or conditionState.remainingDuration
            
            -- Remove the original condition
            self:RemoveCondition(targetId, conditionId, true)
            
            -- Apply the new condition
            self:ApplyCondition(targetId, targetCondition, stacks, duration, mergedData)
        end
    end
end

-- PHASE 3 ENHANCEMENT: Connect EffectSystem, DamageSystem through events
function ConditionSystem:ConnectEvents(eventSystem)
    -- This is called during CombatCore initialization to set up events
    
    -- Listen for condition-related request events
    eventSystem:SubscribeWithResponse(EVENTS.CONDITION_REQUEST, function(params)
        -- Handle different request types
        if params.requestType == "APPLY" then
            return self:ApplyCondition(
                params.targetId,
                params.conditionId,
                params.stacks,
                params.duration,
                params.data
            )
        elseif params.requestType == "REMOVE" then
            return self:RemoveCondition(
                params.targetId,
                params.conditionId,
                params.removeAll
            )
        elseif params.requestType == "CHECK" then
            return {
                success = true,
                hasCondition = self:HasCondition(params.targetId, params.conditionId)
            }
        elseif params.requestType == "GET_DATA" then
            local data = self:GetConditionData(params.targetId, params.conditionId)
            return {
                success = data ~= nil,
                data = data
            }
        end
        
        return { success = false, error = "Unknown request type" }
    end)
    
    -- Announce system is ready
    eventSystem:Publish(EVENTS.CONDITION_SYSTEM_READY, {})
end

-- Update condition tick timers and processing
function ConditionSystem:Update(dt)
    for targetId, conditions in pairs(self.EntityConditions) do
        if not self.EntitySystem:EntityExists(targetId) then
            self:CleanupEntityConditions(targetId)
            continue
        end
        
        for conditionId, conditionState in pairs(conditions) do
            local conditionDef = self:GetConditionDefinition(conditionId)
            if not conditionDef then
                continue
            end
            
            -- Update remaining duration
            if conditionState.remainingDuration > 0 then
                conditionState.remainingDuration = conditionState.remainingDuration - dt
                
                -- Handle expiration inline rather than relying solely on timer
                if conditionState.remainingDuration <= 0 then
                    task.spawn(function()
                        self:HandleConditionExpiration(targetId, conditionId)
                    end)
                end
            end
            
            -- Update tick timer and process tick if needed
            if conditionDef.handlers and conditionDef.handlers.onTick then
                conditionState.tickTimer = conditionState.tickTimer - dt
                
                if conditionState.tickTimer <= 0 then
                    -- Reset tick timer
                    conditionState.tickTimer = conditionDef.tickRate
                    
                    -- Apply expertise stat to modify tick rate if applicable
                    if conditionState.data and conditionState.data.sourceId then
                        local sourceId = conditionState.data.sourceId
                        local expertise = self.StatSystem:GetStatValue(sourceId, "expertise") / 100
                        
                        -- Expertise can only decrease tick time (increase frequency)
                        if expertise > 1 then
                            conditionState.tickTimer = conditionState.tickTimer / expertise
                        end
                    end
                    
                    -- Process tick
                    local tickParams = {
                        targetId = targetId,
                        conditionId = conditionId,
                        stacks = conditionState.stacks,
                        data = conditionState.data
                    }
                    
                    -- Execute tick handler with error handling
                    task.spawn(function()
                        pcall(function()
                            conditionDef.handlers.onTick(tickParams, self)
                        end)
                    end)
                    
                    -- Publish tick event
                    self.EventSystem:Publish(EVENTS.CONDITION_TICK, {
                        targetId = targetId,
                        conditionId = conditionId,
                        stacks = conditionState.stacks
                    })
                end
            end
        end
    end
end

-- Clean up all conditions for an entity
function ConditionSystem:CleanupEntityConditions(targetId)
    if not self.EntityConditions[targetId] then
        return
    end
    
    -- Cancel all timers
    if self.ConditionTimers[targetId] then
        for conditionId, timers in pairs(self.ConditionTimers[targetId]) do
            for timerType, timer in pairs(timers) do
                if typeof(timer) == "thread" then
                    -- Add proper error handling for thread cancellation
                    pcall(function()
                        task.cancel(timer)
                    end)
                end
            end
        end
    end
    
    -- Clear condition data
    self.EntityConditions[targetId] = nil
    self.ConditionTimers[targetId] = nil
end

-- Clean up when system is destroyed
function ConditionSystem:Destroy()
    -- Disconnect heartbeat
    if self.HeartbeatConnection then
        self.HeartbeatConnection:Disconnect()
        self.HeartbeatConnection = nil
    end
    
    -- Clean up all entity conditions
    for targetId, _ in pairs(self.EntityConditions) do
        self:CleanupEntityConditions(targetId)
    end
end

return ConditionSystem