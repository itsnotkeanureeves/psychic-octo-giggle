--[[
    AbilitySystem.lua
    
    PURPOSE:
    Manages ability registration, validation, cooldowns, and execution.
    Core gameplay system for player and NPC abilities.
    
    DESIGN PRINCIPLES:
    - Data-driven ability definitions
    - Clean validation and execution flow
    - Proper cooldown management
    - Ability chaining for combos
    - Standardized effect types with action verbs (e.g., APPLY_DAMAGE)
    
    USAGE:
    local AbilitySystem = require(path.to.AbilitySystem)
    local abilitySystem = AbilitySystem.new(entitySystem, targetSystem, effectSystem, conditionSystem, eventSystem)
    
    -- Register an ability
    abilitySystem:RegisterAbility("FIREBALL", {
        name = "Fireball",
        description = "Launches a ball of fire at the target",
        castTime = 1.5,
        cooldown = 8,
        resourceCost = { type = "ENERGY", amount = 20 },
        targeting = { type = "SPHERE", range = 10, teamFilter = "ENEMIES" },
        effects = { { type = EFFECT.TYPES.APPLY_DAMAGE, amount = 50, damageType = EFFECT.DAMAGE_TYPES.FIRE } }
    })
    
    -- Request ability execution
    local success = abilitySystem:RequestAbility(entityId, "FIREBALL", targetPosition, targetDirection)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local Constants = require(SharedPath:WaitForChild("Constants"))

local ABILITY = Constants.ABILITY
local EFFECT = Constants.EFFECT
local EVENTS = Constants.EVENTS
local TARGETING = Constants.TARGETING
local LEVEL_SCALING = Constants.LEVEL_SCALING

-- Safe remote event access helper
local function safeGetRemoteEvent(name)
    local remoteEventsFolder = ReplicatedStorage:FindFirstChild("Combat_RemoteEvents")
    if not remoteEventsFolder then
        warn("RemoteEvents folder not found, creating a fallback...")
        remoteEventsFolder = Instance.new("Folder")
        remoteEventsFolder.Name = "Combat_RemoteEvents"
        remoteEventsFolder.Parent = ReplicatedStorage
    end
    
    local event = remoteEventsFolder:FindFirstChild(name)
    if not event then
        warn("RemoteEvent " .. name .. " not found, creating a fallback...")
        event = Instance.new("RemoteEvent")
        event.Name = name
        event.Parent = remoteEventsFolder
    end
    
    return event
end

-- AbilitySystem implementation
local AbilitySystem = {}
AbilitySystem.__index = AbilitySystem

function AbilitySystem.new(entitySystem, targetSystem, effectSystem, conditionSystem, statSystem, eventSystem)
    local self = setmetatable({}, AbilitySystem)
    self.EntitySystem = entitySystem
    self.TargetSystem = targetSystem
    self.EffectSystem = effectSystem
    self.ConditionSystem = conditionSystem
    self.StatSystem = statSystem
    self.EventSystem = eventSystem
    
    -- Storage
    self.Abilities = {} -- Ability definitions
    self.Cooldowns = {} -- entityId -> { abilityId -> cooldownEndTime }
    self.EntityAbilities = {} -- entityId -> { abilityId1, abilityId2, ... }
    self.CastingStates = {} -- entityId -> { abilityId, targetPosition, targetDirection, startTime, endTime }
    self.AbilityChains = {} -- entityId -> { chainId -> { currentPosition, nextAbilityId, timeout, timeoutTime } }
    
    -- Wait for RemoteEvents folder to be created
    local remoteEventsFolder = ReplicatedStorage:WaitForChild("Combat_RemoteEvents", 10)
    
    -- Listen for ability requests from clients
    local abilityRequestEvent
    if remoteEventsFolder then
        abilityRequestEvent = remoteEventsFolder:WaitForChild("Combat_AbilityRequest", 2)
    end
    
    if not abilityRequestEvent then
        warn("AbilitySystem: Combat_AbilityRequest not found, creating fallback")
        abilityRequestEvent = safeGetRemoteEvent("Combat_AbilityRequest")
    end
    
    abilityRequestEvent.OnServerEvent:Connect(function(player, abilityId, targetPosition, targetDirection)
        local entityId = self.EntitySystem:GetEntityId(player)
        if entityId then
            print("[AbilitySystem] Received request for ability " .. abilityId .. " from player " .. player.Name)
            self:RequestAbility(entityId, abilityId, targetPosition, targetDirection)
        else
            warn("[AbilitySystem] Failed to get entityId for player " .. player.Name)
        end
    end)
    
    return self
end

-- Get a specific ability definition
function AbilitySystem:GetAbilityDefinition(abilityId)
    return self.Abilities[abilityId]
end

-- Get all ability definitions
function AbilitySystem:GetAllAbilityDefinitions()
    return self.Abilities
end

-- Register an ability definition
function AbilitySystem:RegisterAbility(abilityId, abilityData)
    if self.Abilities[abilityId] then
        warn("AbilitySystem: Overwriting existing ability: " .. abilityId)
    end
    
    -- Set default values
    abilityData.id = abilityId
    abilityData.cooldown = abilityData.cooldown or ABILITY.DEFAULT_COOLDOWN
    abilityData.castTime = abilityData.castTime or ABILITY.DEFAULT_CAST_TIME
    abilityData.targeting = abilityData.targeting or {
        type = TARGETING.TYPES.SELF,
        teamFilter = TARGETING.TEAM_FILTERS.ALL
    }
    abilityData.effects = abilityData.effects or {}
    
    -- Initialize chain settings if needed
    if abilityData.chain and abilityData.chain.isChained then
        if not abilityData.chain.timeout then
            abilityData.chain.timeout = ABILITY.MAX_CHAIN_TIMEOUT
        end
    end
    
    self.Abilities[abilityId] = abilityData
    return true
end

-- Grant an ability to an entity
function AbilitySystem:GrantAbility(entityId, abilityId)
    -- Check if entity exists
    if not self.EntitySystem:EntityExists(entityId) then
        print("AbilitySystem: Cannot grant ability - Entity does not exist: " .. entityId)
        return false, "Entity does not exist"
    end
    
    -- Check if ability is defined
    if not self.Abilities[abilityId] then
        print("AbilitySystem: Cannot grant ability - Ability not defined: " .. abilityId)
        return false, "Ability not defined: " .. abilityId
    end
    
    -- Initialize entity ability list if needed
    if not self.EntityAbilities[entityId] then
        self.EntityAbilities[entityId] = {}
    end
    
    -- Check if entity already has this ability
    for _, id in ipairs(self.EntityAbilities[entityId]) do
        if id == abilityId then
            return true -- Already has ability
        end
    end
    
    -- Grant the ability
    table.insert(self.EntityAbilities[entityId], abilityId)
    print("AbilitySystem: Granted ability " .. abilityId .. " to entity " .. entityId)
    
    return true
end

-- Remove an ability from an entity
function AbilitySystem:RemoveAbility(entityId, abilityId)
    -- Check if entity has abilities
    if not self.EntityAbilities[entityId] then
        return false, "Entity has no abilities"
    end
    
    -- Find and remove the ability
    for i, id in ipairs(self.EntityAbilities[entityId]) do
        if id == abilityId then
            table.remove(self.EntityAbilities[entityId], i)
            return true
        end
    end
    
    return false, "Entity does not have ability: " .. abilityId
end

-- Check if entity has ability
function AbilitySystem:HasAbility(entityId, abilityId)
    if not self.EntityAbilities[entityId] then
        return false
    end
    
    for _, id in ipairs(self.EntityAbilities[entityId]) do
        if id == abilityId then
            return true
        end
    end
    
    return false
end

-- Get all abilities for an entity
function AbilitySystem:GetEntityAbilities(entityId)
    if not self.EntityAbilities[entityId] then
        return {}
    end
    
    local abilities = {}
    for _, abilityId in ipairs(self.EntityAbilities[entityId]) do
        local abilityDef = self.Abilities[abilityId]
        if abilityDef then
            local abilityCopy = table.clone(abilityDef)
            
            -- Add cooldown information
            if self.Cooldowns[entityId] and self.Cooldowns[entityId][abilityId] then
                local cooldownEnd = self.Cooldowns[entityId][abilityId]
                local remaining = cooldownEnd - time()
                abilityCopy.remainingCooldown = math.max(0, remaining)
            else
                abilityCopy.remainingCooldown = 0
            end
            
            table.insert(abilities, abilityCopy)
        end
    end
    
    return abilities
end

-- Check if ability is on cooldown
function AbilitySystem:IsOnCooldown(entityId, abilityId)
    if not self.Cooldowns[entityId] then
        return false
    end
    
    local cooldownEnd = self.Cooldowns[entityId][abilityId]
    if not cooldownEnd then
        return false
    end
    
    return cooldownEnd > time()
end

-- Get remaining cooldown time
function AbilitySystem:GetRemainingCooldown(entityId, abilityId)
    if not self.Cooldowns[entityId] then
        return 0
    end
    
    local cooldownEnd = self.Cooldowns[entityId][abilityId]
    if not cooldownEnd then
        return 0
    end
    
    local remaining = cooldownEnd - time()
    return math.max(0, remaining)
end

-- Start cooldown for an ability
function AbilitySystem:StartCooldown(entityId, abilityId)
    local abilityDef = self.Abilities[abilityId]
    if not abilityDef then
        return false, "Ability not defined: " .. abilityId
    end
    
    -- Initialize cooldown storage if needed
    if not self.Cooldowns[entityId] then
        self.Cooldowns[entityId] = {}
    end
    
    -- Calculate cooldown duration
    local cooldown = abilityDef.cooldown
    
    -- Apply cooldown reduction if applicable
    -- Can be added later based on entity stats
    
    -- Set cooldown end time
    local cooldownEnd = time() + cooldown
    self.Cooldowns[entityId][abilityId] = cooldownEnd
    
    -- If ability has a cooldown category, apply to all abilities in that category
    if abilityDef.cooldownCategory then
        for id, def in pairs(self.Abilities) do
            if id ~= abilityId and def.cooldownCategory == abilityDef.cooldownCategory then
                self.Cooldowns[entityId][id] = cooldownEnd
            end
        end
    end
    
    -- Publish cooldown event
    self.EventSystem:Publish("ABILITY_COOLDOWN_STARTED", {
        entityId = entityId,
        abilityId = abilityId,
        cooldownDuration = cooldown,
        cooldownEnd = cooldownEnd
    })
    
    return true
end

-- Check if entity is currently casting
function AbilitySystem:IsCasting(entityId)
    return self.CastingStates[entityId] ~= nil
end

-- Get current casting state
function AbilitySystem:GetCastingState(entityId)
    return self.CastingStates[entityId]
end

-- Start casting an ability
function AbilitySystem:StartCasting(entityId, abilityId, targetPosition, targetDirection)
    local abilityDef = self.Abilities[abilityId]
    if not abilityDef then
        return false, "Ability not defined: " .. abilityId
    end
    
    -- Check if cast time is applicable
    if not abilityDef.castTime or abilityDef.castTime <= 0 then
        print("[AbilitySystem] Ability " .. abilityId .. " is instant cast, skipping cast bar")
        return true -- Instant cast, no need to start casting state
    end
    
    -- Check if already casting
    if self:IsCasting(entityId) then
        -- Interrupt current cast if allowed
        local currentCast = self.CastingStates[entityId]
        local currentAbility = self.Abilities[currentCast.abilityId]
        
        if not currentAbility or currentAbility.interruptible then
            self:InterruptCasting(entityId)
        else
            return false, "Already casting non-interruptible ability"
        end
    end
    
    -- Set up casting state
    local castStart = time()
    local castEnd = castStart + abilityDef.castTime
    
    self.CastingStates[entityId] = {
        abilityId = abilityId,
        targetPosition = targetPosition,
        targetDirection = targetDirection,
        startTime = castStart,
        endTime = castEnd
    }
    
    -- Apply casting condition to entity if applicable
    if self.ConditionSystem then
        self.ConditionSystem:ApplyCondition(entityId, "CASTING", 1, abilityDef.castTime, {
            abilityId = abilityId,
            interruptible = abilityDef.interruptible or true
        })
    end
    
    -- Publish cast start event
    self.EventSystem:Publish(EVENTS.ABILITY_CAST_START, {
        entityId = entityId,
        abilityId = abilityId,
        abilityName = abilityDef.name,
        abilityIcon = abilityDef.icon,
        castTime = abilityDef.castTime,
        interruptible = abilityDef.interruptible or true
    })
    
    -- Send cast start info to clients
    local castBarEvent = safeGetRemoteEvent("Combat_CastBarUpdate")
    print("[AbilitySystem] Sending cast start for " .. abilityId .. " to all clients - " .. abilityDef.name .. ", time: " .. abilityDef.castTime)
    castBarEvent:FireAllClients(entityId, 0, abilityDef.name, abilityDef.icon, abilityDef.castTime)
    
    -- Set up cast progress updates
    -- This will update clients about casting progress every 0.1 seconds
    local updateInterval = 0.1
    local totalUpdates = math.floor(abilityDef.castTime / updateInterval)
    
    for i = 1, totalUpdates do
        task.delay(i * updateInterval, function()
            -- Only send update if still casting the same ability
            if self.CastingStates[entityId] and self.CastingStates[entityId].abilityId == abilityId then
                local progress = (i * updateInterval) / abilityDef.castTime
                print("[AbilitySystem] Sending cast progress update: " .. progress)
                castBarEvent:FireAllClients(entityId, progress, abilityDef.name, abilityDef.icon, abilityDef.castTime)
                
                -- Also publish event for local systems
                self.EventSystem:Publish(EVENTS.CAST_PROGRESS_UPDATE, {
                    entityId = entityId,
                    abilityId = abilityId,
                    progress = progress,
                    abilityName = abilityDef.name,
                    abilityIcon = abilityDef.icon,
                    castTime = abilityDef.castTime
                })
            end
        end)
    end
    
    -- Set up cast completion callback
    task.delay(abilityDef.castTime, function()
        -- Only complete if still casting the same ability
        if self.CastingStates[entityId] and self.CastingStates[entityId].abilityId == abilityId then
            self:CompleteCasting(entityId)
        end
    end)
    
    return true
end

-- Complete ability casting
function AbilitySystem:CompleteCasting(entityId)
    -- Check if casting
    local castState = self.CastingStates[entityId]
    if not castState then
        return false, "Not casting"
    end
    
    -- Clear casting state (before execution to avoid recursion issues)
    local abilityId = castState.abilityId
    local targetPosition = castState.targetPosition
    local targetDirection = castState.targetDirection
    self.CastingStates[entityId] = nil
    
    -- Remove casting condition if applicable
    if self.ConditionSystem then
        self.ConditionSystem:RemoveCondition(entityId, "CASTING", true)
    end
    
    -- Publish cast complete event
    self.EventSystem:Publish(EVENTS.ABILITY_CAST_COMPLETE, {
        entityId = entityId,
        abilityId = abilityId
    })
    
    print("[AbilitySystem] Cast completed for " .. abilityId .. ". Executing ability...")
    
    -- Execute the ability
    return self:ExecuteAbility(entityId, abilityId, targetPosition, targetDirection)
end

-- Interrupt ability casting
function AbilitySystem:InterruptCasting(entityId)
    -- Check if casting
    local castState = self.CastingStates[entityId]
    if not castState then
        return false, "Not casting"
    end
    
    -- Clear casting state
    local abilityId = castState.abilityId
    self.CastingStates[entityId] = nil
    
    -- Remove casting condition if applicable
    if self.ConditionSystem then
        self.ConditionSystem:RemoveCondition(entityId, "CASTING", true)
    end
    
    -- Publish cast interrupted event
    self.EventSystem:Publish(EVENTS.ABILITY_CAST_INTERRUPTED, {
        entityId = entityId,
        abilityId = abilityId
    })
    
    print("[AbilitySystem] Cast interrupted for " .. abilityId)
    
    -- Apply a short cooldown for interrupted abilities
    local abilityDef = self.Abilities[abilityId]
    if abilityDef then
        -- Use a fraction of the normal cooldown
        local interruptCooldown = abilityDef.castTime or 1.5
        
        -- Initialize cooldown storage if needed
        if not self.Cooldowns[entityId] then
            self.Cooldowns[entityId] = {}
        end
        
        self.Cooldowns[entityId][abilityId] = time() + interruptCooldown
    end
    
    return true
end

-- Handle ability chain logic
function AbilitySystem:ProcessAbilityChain(entityId, abilityId)
    local abilityDef = self.Abilities[abilityId]
    if not abilityDef or not abilityDef.chain or not abilityDef.chain.isChained then
        return nil -- Not a chain ability
    end
    
    local chainId = abilityDef.chain.chainId
    local position = abilityDef.chain.position
    local nextAbilityId = abilityDef.chain.nextAbilityId
    local timeout = abilityDef.chain.timeout or ABILITY.MAX_CHAIN_TIMEOUT
    
    print("[AbilitySystem] Processing chain ability: " .. abilityId .. 
          ", position: " .. position .. 
          ", chainId: " .. (chainId or "nil") .. 
          ", nextAbility: " .. (nextAbilityId or "nil"))
    
    -- Initialize chain storage if needed
    if not self.AbilityChains[entityId] then
        self.AbilityChains[entityId] = {}
    end
    
    -- Check if this is the start of a new chain
    if position == 1 then
        -- Start new chain
        self.AbilityChains[entityId][chainId] = {
            currentPosition = 1,
            nextAbilityId = nextAbilityId,
            timeout = timeout,
            timeoutTime = time() + timeout
        }
        
        print("[AbilitySystem] Started new chain: " .. chainId .. ", nextAbility: " .. (nextAbilityId or "nil"))
    else
        -- Check if chain exists and is at the correct position
        local chain = self.AbilityChains[entityId][chainId]
        if not chain then
            print("[AbilitySystem] Chain not started: " .. chainId)
            return false, "Chain not started"
        end
        
        if chain.currentPosition ~= position - 1 then
            print("[AbilitySystem] Incorrect chain position: " .. chain.currentPosition .. " vs " .. (position - 1))
            return false, "Incorrect chain position"
        end
        
        if chain.nextAbilityId ~= abilityId then
            print("[AbilitySystem] Incorrect next ability in chain: " .. chain.nextAbilityId .. " vs " .. abilityId)
            return false, "Incorrect next ability in chain"
        end
        
        if chain.timeoutTime < time() then
            print("[AbilitySystem] Chain timed out")
            return false, "Chain timed out"
        end
        
        -- Update chain position
        chain.currentPosition = position
        chain.nextAbilityId = nextAbilityId
        chain.timeoutTime = time() + timeout
        
        print("[AbilitySystem] Continued chain: " .. chainId .. 
              ", position: " .. position .. 
              ", nextAbility: " .. (nextAbilityId or "nil"))
    end
    
    -- If this ability triggers the next in chain, publish event
    if nextAbilityId then
        -- Publish event for chain ability ready
        self.EventSystem:Publish(EVENTS.CHAIN_ABILITY_READY, {
            entityId = entityId,
            chainId = chainId,
            nextAbilityId = nextAbilityId,
            timeout = timeout
        })
        
        -- Update chain UI on client
        local entity = self.EntitySystem:GetEntity(entityId)
        if entity and entity.player then
            local chainUpdateEvent = safeGetRemoteEvent("Combat_ChainAbilityUpdate")
            print("[AbilitySystem] Sending chain update to client: " .. nextAbilityId .. ", timeout: " .. timeout)
            chainUpdateEvent:FireClient(entity.player, nextAbilityId, timeout)
        else
            print("[AbilitySystem] Could not find player for entity: " .. entityId)
        end
        
        -- Set up timeout callback
        task.delay(timeout, function()
            local chain = self.AbilityChains[entityId] and self.AbilityChains[entityId][chainId]
            if chain and chain.nextAbilityId == nextAbilityId then
                -- Publish timeout event
                self.EventSystem:Publish(EVENTS.CHAIN_ABILITY_TIMEOUT, {
                    entityId = entityId,
                    chainId = chainId
                })
                
                -- Clear chain state
                chain.nextAbilityId = nil
                chain.timeoutTime = 0
                
                print("[AbilitySystem] Chain ability timed out: " .. nextAbilityId)
            end
        end)
    end
    
    -- Return chain information
    local chainInfo = {
        chainId = chainId,
        position = position,
        nextAbilityId = nextAbilityId,
        timeout = timeout
    }
    
    print("[AbilitySystem] Returning chain info: " .. 
          "chainId=" .. (chainId or "nil") .. 
          ", position=" .. position .. 
          ", nextAbility=" .. (nextAbilityId or "nil") .. 
          ", timeout=" .. timeout)
    
    return chainInfo
end

-- Check if an ability can be executed
function AbilitySystem:ValidateAbilityRequest(entityId, abilityId)
    -- Check if entity exists
    if not self.EntitySystem:EntityExists(entityId) then
        return false, "Entity does not exist"
    end
    
    -- Check if ability is defined
    if not self.Abilities[abilityId] then
        return false, "Ability not defined: " .. abilityId
    end
    
    -- Check if entity has the ability
    if not self:HasAbility(entityId, abilityId) then
        return false, "Entity does not have ability: " .. abilityId
    end
    
    -- Check if entity is alive
    if not self.EntitySystem:IsAlive(entityId) then
        return false, "Entity is dead"
    end
    
    -- Check if on cooldown
    if self:IsOnCooldown(entityId, abilityId) then
        return false, "Ability is on cooldown"
    end
    
    -- Get ability definition
    local abilityDef = self.Abilities[abilityId]
    
    -- Check if chain ability and validate chain state
    if abilityDef.chain and abilityDef.chain.isChained and abilityDef.chain.position > 1 then
        local chainId = abilityDef.chain.chainId
        
        -- Check if chain is active
        if not self.AbilityChains[entityId] or not self.AbilityChains[entityId][chainId] then
            return false, "Chain not active"
        end
        
        local chain = self.AbilityChains[entityId][chainId]
        
        -- Check chain position
        if chain.currentPosition ~= abilityDef.chain.position - 1 then
            return false, "Incorrect chain position"
        end
        
        -- Check next ability in chain
        if chain.nextAbilityId ~= abilityId then
            return false, "Not the next ability in chain"
        end
        
        -- Check timeout
        if chain.timeoutTime < time() then
            return false, "Chain timed out"
        end
    end
    
    -- Check resource cost if applicable
    if abilityDef.resourceCost then
        local resourceType = abilityDef.resourceCost.type
        local resourceAmount = abilityDef.resourceCost.amount
        
        -- Get current resource value
        local currentResource = self.EntitySystem:GetAttribute(entityId, string.lower(resourceType))
        
        if not currentResource or currentResource < resourceAmount then
            return false, "Insufficient " .. resourceType
        end
    end
    
    return true
end

-- Consume resources for an ability
function AbilitySystem:ConsumeResources(entityId, abilityId)
    local abilityDef = self.Abilities[abilityId]
    if not abilityDef or not abilityDef.resourceCost then
        return true -- No resources to consume
    end
    
    local resourceType = abilityDef.resourceCost.type
    local resourceAmount = abilityDef.resourceCost.amount
    
    -- Get current resource value
    local resourceAttr = string.lower(resourceType)
    local currentResource = self.EntitySystem:GetAttribute(entityId, resourceAttr)
    
    if not currentResource or currentResource < resourceAmount then
        return false, "Insufficient " .. resourceType
    end
    
    -- Consume the resource
    self.EntitySystem:SetAttribute(entityId, resourceAttr, currentResource - resourceAmount)
    
    return true
end

-- Request ability execution (entry point from client)
function AbilitySystem:RequestAbility(entityId, abilityId, targetPosition, targetDirection)
    -- Validate ability request
    local valid, errorMsg = self:ValidateAbilityRequest(entityId, abilityId)
    if not valid then
        print("[AbilitySystem] Invalid request for " .. abilityId .. ": " .. errorMsg)
        -- Send response to client
        local player = self.EntitySystem:GetEntity(entityId).player
        if player then
            local abilityResponseEvent = safeGetRemoteEvent("Combat_AbilityResponse")
            abilityResponseEvent:FireClient(player, abilityId, false, errorMsg)
        end
        return false, errorMsg
    end
    
    -- Get ability definition
    local abilityDef = self.Abilities[abilityId]
    
    -- Consume resources
    local resourceSuccess, resourceError = self:ConsumeResources(entityId, abilityId)
    if not resourceSuccess then
        print("[AbilitySystem] Resource consumption failed for " .. abilityId .. ": " .. resourceError)
        -- Send response to client
        local player = self.EntitySystem:GetEntity(entityId).player
        if player then
            local abilityResponseEvent = safeGetRemoteEvent("Combat_AbilityResponse")
            abilityResponseEvent:FireClient(player, abilityId, false, resourceError)
        end
        return false, resourceError
    end
    
    -- Send positive response to client
    local player = self.EntitySystem:GetEntity(entityId).player
    if player then
        local abilityResponseEvent = safeGetRemoteEvent("Combat_AbilityResponse")
        abilityResponseEvent:FireClient(player, abilityId, true)
    end
    
    print("[AbilitySystem] Ability request validated for " .. abilityId)
    
    -- Check if ability has a cast time
    if abilityDef.castTime and abilityDef.castTime > 0 then
        print("[AbilitySystem] Ability " .. abilityId .. " has cast time: " .. abilityDef.castTime)
        -- Start casting process
        return self:StartCasting(entityId, abilityId, targetPosition, targetDirection)
    else
        -- Execute immediately for instant abilities
        print("[AbilitySystem] Executing instant ability: " .. abilityId)
        return self:ExecuteAbility(entityId, abilityId, targetPosition, targetDirection)
    end
end

-- Execute ability (after validation and casting)
function AbilitySystem:ExecuteAbility(entityId, abilityId, targetPosition, targetDirection)
    -- Get ability definition
    local abilityDef = self.Abilities[abilityId]
    if not abilityDef then
        return false, "Ability not defined: " .. abilityId
    end
    
    -- Get entity information
    local entity = self.EntitySystem:GetEntity(entityId)
    if not entity then
        return false, "Entity does not exist"
    end
    
    print("[AbilitySystem] Executing ability " .. abilityId .. " for entity " .. entityId)
    
    -- Process ability chain if applicable
    local chainInfo = self:ProcessAbilityChain(entityId, abilityId)
    
    -- Get targeting parameters
    local targeting = abilityDef.targeting or {
        type = TARGETING.TYPES.SELF,
        teamFilter = TARGETING.TEAM_FILTERS.ALL
    }
    
    -- Default position and direction
    if not targetPosition and entity.rootPart then
        targetPosition = entity.rootPart.Position
    end
    
    if not targetDirection and entity.rootPart then
        targetDirection = entity.rootPart.CFrame.LookVector
    end
    
    -- Find targets
    local targets = {}
    
    if targeting.type == TARGETING.TYPES.SELF then
        -- Self-targeting only includes the source
        table.insert(targets, {
            entityId = entityId,
            entity = entity,
            position = targetPosition,
            distance = 0
        })
    else
        -- Use TargetSystem to find targets
        targets = self.TargetSystem:GetTargets(entityId, targetPosition, targetDirection, {
            type = targeting.type,
            range = targeting.range,
            angle = targeting.angle,
            width = targeting.width,
            teamFilter = targeting.teamFilter,
            maxTargets = targeting.maxTargets,
            includeSelf = targeting.includeSelf
        })
    end
    
    print("[AbilitySystem] Found " .. #targets .. " targets for " .. abilityId)
    
    -- Apply effects to targets
    local effectResults = {}
    local sourceLevel = self.EntitySystem:GetAttribute(entityId, "level") or 1
    
    for _, target in ipairs(targets) do
        local targetId = target.entityId
        local targetLevel = self.EntitySystem:GetAttribute(targetId, "level") or 1
        
        -- Execute the ability
        for _, effect in ipairs(abilityDef.effects or {}) do
            local effectType = effect.type
            local effectParams = table.clone(effect)
            
            -- Set source and target information
            effectParams.sourceId = entityId
            effectParams.targetId = targetId
            effectParams.sourceAbility = abilityId
            effectParams.sourceLevel = sourceLevel
            effectParams.targetLevel = targetLevel
            
            -- Apply level scaling to damage/healing
            if effectType == EFFECT.TYPES.APPLY_DAMAGE and effectParams.amount then
                local levelDifference = sourceLevel - targetLevel
                local levelScalingFactor = 1 + math.clamp(
                    levelDifference * LEVEL_SCALING.DAMAGE_FACTOR_PER_LEVEL,
                    -LEVEL_SCALING.MAX_LEVEL_MODIFIER,
                    LEVEL_SCALING.MAX_LEVEL_MODIFIER
                )
                effectParams.rawAmount = effectParams.amount
                effectParams.amount = math.floor(effectParams.amount * levelScalingFactor + 0.5)
            end
            
            -- Execute the effect
            local success, result = self.EffectSystem:ExecuteEffect(effectType, effectParams)
            
            if success then
                table.insert(effectResults, {
                    targetId = targetId,
                    effectType = effectType,
                    result = result
                })
                print("[AbilitySystem] Effect " .. effectType .. " executed successfully on target " .. targetId)
            else
                print("[AbilitySystem] Effect execution failed: " .. (result or "unknown error"))
            end
        end
    end
    
    -- Start cooldown
    self:StartCooldown(entityId, abilityId)
    
    -- Publish ability executed event
    self.EventSystem:Publish(EVENTS.ABILITY_EXECUTED, {
        entityId = entityId,
        abilityId = abilityId,
        targets = targets,
        effects = effectResults,
        chainInfo = chainInfo
    })
    
    -- Fire remote event to clients
    local abilityExecutionEvent = safeGetRemoteEvent("Combat_AbilityExecution")
    print("[AbilitySystem] Sending AbilityExecution event to clients: " .. abilityId .. ", with chainInfo: " .. tostring(chainInfo ~= nil))
    abilityExecutionEvent:FireAllClients(entityId, abilityId, targetPosition, targetDirection, targets, chainInfo)
    
    -- Send data to client
    local player = entity.player
    if player then
        local abilityResponseEvent = safeGetRemoteEvent("Combat_AbilityResponse")
        print("[AbilitySystem] Sending AbilityResponse to player with chainInfo: " .. tostring(chainInfo ~= nil))
        abilityResponseEvent:FireClient(player, abilityId, true, nil, {
            chainInfo = chainInfo
        })
    end
    
    print("[AbilitySystem] Ability execution complete for " .. abilityId)
    
    return true, { 
        targets = targets,
        effects = effectResults,
        chainInfo = chainInfo
    }
end

-- Clean up entity data on unregister
function AbilitySystem:CleanupEntityData(entityId)
    self.EntityAbilities[entityId] = nil
    self.Cooldowns[entityId] = nil
    self.CastingStates[entityId] = nil
    self.AbilityChains[entityId] = nil
end

-- Debug: Print all registered abilities
function AbilitySystem:DebugPrintAbilities()
    print("===== Registered Abilities =====")
    
    local count = 0
    for id, ability in pairs(self.Abilities) do
        count = count + 1
        print(string.format("%d. %s (%s): %s", count, id, ability.name, ability.description))
    end
    
    if count == 0 then
        print("No abilities registered!")
    else
        print("Total:", count, "abilities")
    end
    
    return count
end

return AbilitySystem