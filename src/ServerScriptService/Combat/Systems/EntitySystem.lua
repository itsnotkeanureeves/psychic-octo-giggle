--[[
    EntitySystem.lua
    
    PURPOSE:
    Provides a unified entity abstraction layer for interacting with players and NPCs.
    Maintains a registry of all combat entities and provides a consistent API for access.
    
    DESIGN PRINCIPLES:
    - Unified entity interface
    - Consistent attribute access
    - No global state
    - Efficient entity lookup
    
    USAGE:
    local EntitySystem = require(path.to.EntitySystem)
    local entitySystem = EntitySystem.new(eventSystem)
    
    -- Register entities
    local entityId = entitySystem:RegisterPlayer(player)
    local npcEntityId = entitySystem:RegisterNPC(npcModel)
    
    -- Get entities
    local entity = entitySystem:GetEntity(entityId)
    
    -- Access attributes
    local health = entitySystem:GetAttribute(entityId, "health")
    entitySystem:SetAttribute(entityId, "health", health - 10)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local Constants = require(SharedPath:WaitForChild("Constants"))

local ENTITY_TYPES = Constants.ENTITY_TYPES
local EVENTS = Constants.EVENTS
local DEFAULT_STATS = Constants.STAT.DEFAULTS

-- EntitySystem implementation
local EntitySystem = {}
EntitySystem.__index = EntitySystem

function EntitySystem.new(eventSystem)
    local self = setmetatable({}, EntitySystem)
    self.Entities = {} -- Map of entityId to entity data
    self.PlayerEntities = {} -- Map of player to entityId 
    self.NPCEntities = {} -- Map of model to entityId
    self.NextEntityId = 1 -- For generating unique entity IDs
    self.EventSystem = eventSystem
    self.NPCAdapter = nil -- Reference to NPC adapter (set by NPC system)
    
    return self
end

-- Set NPC adapter (called from NPC system)
function EntitySystem:SetNPCAdapter(adapter)
    self.NPCAdapter = adapter
    
    -- Now check for any NPCs that were registered before adapter was set
    if self.NPCEntities then
        for npcModel, entityId in pairs(self.NPCEntities) do
            if self.Entities[entityId] and not self.Entities[entityId].npcEntity then
                -- Try to get NPC entity using the adapter
                if adapter and adapter.GetNPCFromModel then
                    local npcEntity = adapter:GetNPCFromModel(npcModel)
                    if npcEntity then
                        self.Entities[entityId].npcEntity = npcEntity
                    end
                end
            end
        end
    end
end

-- Generate a unique entity ID
function EntitySystem:GenerateEntityId()
    local entityId = "entity_" .. self.NextEntityId
    self.NextEntityId = self.NextEntityId + 1
    return entityId
end

-- Register a player as an entity
function EntitySystem:RegisterPlayer(player)
    if self.PlayerEntities[player] then
        return self.PlayerEntities[player]
    end
    
    local entityId = self:GenerateEntityId()
    
    -- Initialize the player's character
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    -- Create entity data structure
    local entity = {
        id = entityId,
        type = ENTITY_TYPES.PLAYER,
        name = player.Name,
        player = player,
        character = character,
        humanoid = humanoid,
        rootPart = rootPart,
        attributes = table.clone(DEFAULT_STATS), -- Start with default attributes
        team = player.Team and player.Team.Name or "Neutral",
    }
    
    -- Store the entity
    self.Entities[entityId] = entity
    self.PlayerEntities[player] = entityId
    
    -- Handle character changes
    player.CharacterAdded:Connect(function(newCharacter)
        self:UpdatePlayerCharacter(entityId, newCharacter)
    end)
    
    -- Publish entity registered event
    self.EventSystem:Publish(EVENTS.ENTITY_REGISTERED, {
        entityId = entityId,
        entityType = ENTITY_TYPES.PLAYER,
        name = player.Name
    })
    
    return entityId
end

-- Update a player's character reference
function EntitySystem:UpdatePlayerCharacter(entityId, character)
    local entity = self.Entities[entityId]
    if not entity then return end
    
    entity.character = character
    entity.humanoid = character:WaitForChild("Humanoid")
    entity.rootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Set up humanoid died event
    entity.humanoid.Died:Connect(function()
        self.EventSystem:Publish(EVENTS.ENTITY_DIED, {
            entityId = entityId,
            entity = entity
        })
    end)
end

-- Register an NPC as an entity
function EntitySystem:RegisterNPC(model)
    if self.NPCEntities[model] then
        return self.NPCEntities[model]
    end
    
    local entityId = self:GenerateEntityId()
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local rootPart = model:FindFirstChild("HumanoidRootPart")
    
    -- Get NPC name and team
    local name = model.Name
    local team = "Monster"
    
    -- Check for team/faction attribute
    local factionValue = model:FindFirstChild("Faction")
    if factionValue and factionValue:IsA("StringValue") then
        team = factionValue.Value
    end
    
    -- Get level if available
    local level = 1
    local levelValue = model:FindFirstChild("Level")
    if levelValue and levelValue:IsA("IntValue") then
        level = levelValue.Value
    end
    
    -- Create entity data structure
    local entity = {
        id = entityId,
        type = ENTITY_TYPES.NPC,
        name = name,
        model = model,
        humanoid = humanoid,
        rootPart = rootPart,
        attributes = table.clone(DEFAULT_STATS), -- Start with default attributes
        team = team,
        npcEntity = nil, -- Will be set if NPC adapter is available
    }
    
    -- Update level
    entity.attributes.level = level
    
    -- Try to get NPC entity using adapter if available
    if self.NPCAdapter and self.NPCAdapter.GetNPCFromModel then
        entity.npcEntity = self.NPCAdapter:GetNPCFromModel(model)
    end
    
    -- Store the entity
    self.Entities[entityId] = entity
    self.NPCEntities[model] = entityId
    
    -- Set up humanoid died event
    if humanoid then
        humanoid.Died:Connect(function()
            self.EventSystem:Publish(EVENTS.ENTITY_DIED, {
                entityId = entityId,
                entity = entity
            })
        end)
    end
    
    -- Publish entity registered event
    self.EventSystem:Publish(EVENTS.ENTITY_REGISTERED, {
        entityId = entityId,
        entityType = ENTITY_TYPES.NPC,
        name = name
    })
    
    return entityId
end

-- Unregister a player entity
function EntitySystem:UnregisterPlayer(player)
    local entityId = self.PlayerEntities[player]
    if not entityId then return end
    
    -- Publish entity unregistered event
    self.EventSystem:Publish(EVENTS.ENTITY_UNREGISTERED, {
        entityId = entityId,
        entityType = ENTITY_TYPES.PLAYER,
        name = player.Name
    })
    
    -- Remove from storage
    self.Entities[entityId] = nil
    self.PlayerEntities[player] = nil
end

-- Unregister an NPC entity
function EntitySystem:UnregisterNPC(model)
    local entityId = self.NPCEntities[model]
    if not entityId then return end
    
    -- Publish entity unregistered event
    self.EventSystem:Publish(EVENTS.ENTITY_UNREGISTERED, {
        entityId = entityId,
        entityType = ENTITY_TYPES.NPC,
        name = model.Name
    })
    
    -- Remove from storage
    self.Entities[entityId] = nil
    self.NPCEntities[model] = nil
end

-- Get entity by ID
function EntitySystem:GetEntity(entityId)
    return self.Entities[entityId]
end

-- Get entity ID from player or model
function EntitySystem:GetEntityId(instance)
    if typeof(instance) == "Instance" then
        if instance:IsA("Player") then
            return self.PlayerEntities[instance]
        elseif instance:IsA("Model") then
            return self.NPCEntities[instance]
        end
    elseif typeof(instance) == "string" then
        return self.Entities[instance] and instance or nil
    end
    return nil
end

-- Check if entity exists
function EntitySystem:EntityExists(entityId)
    return self.Entities[entityId] ~= nil
end

-- Get entity attribute
function EntitySystem:GetAttribute(entityId, attributeName)
    local entity = self.Entities[entityId]
    if not entity then return nil end
    
    -- Special case for NPCs with linked NPC entity
    if entity.type == ENTITY_TYPES.NPC and entity.npcEntity and 
       attributeName == "health" and entity.humanoid then
        -- Use humanoid health for NPCs
        return entity.humanoid.Health
    end
    
    if entity.type == ENTITY_TYPES.NPC and entity.npcEntity and 
       attributeName == "maxHealth" and entity.humanoid then
        -- Use humanoid max health for NPCs
        return entity.humanoid.MaxHealth
    end
    
    return entity.attributes[attributeName]
end

-- Set entity attribute
function EntitySystem:SetAttribute(entityId, attributeName, value)
    if not self:EntityExists(entityId) then return false end
    
    local entity = self.Entities[entityId]
    local oldValue = entity.attributes[attributeName]
    
    -- Special case for NPCs with linked NPC entity
    if entity.type == ENTITY_TYPES.NPC and entity.humanoid and attributeName == "health" then
        -- Update humanoid health directly
        entity.humanoid.Health = value
        
        -- Publish stat changed event
        if value ~= oldValue then
            self.EventSystem:Publish(EVENTS.STAT_CHANGED, {
                entityId = entityId,
                entity = entity, 
                attributeName = attributeName,
                oldValue = oldValue,
                newValue = value
            })
            
            -- Check for death
            if value <= 0 and oldValue > 0 then
                self.EventSystem:Publish(EVENTS.ENTITY_DIED, {
                    entityId = entityId,
                    entity = entity
                })
            end
        end
        
        return true
    end
    
    -- Regular attribute update
    entity.attributes[attributeName] = value
    
    -- Publish attribute changed event
    if oldValue ~= value then
        -- Publish both events for backward compatibility
        self.EventSystem:Publish(EVENTS.STAT_CHANGED, {
            entityId = entityId,
            entity = entity, 
            attributeName = attributeName,
            oldValue = oldValue,
            newValue = value
        })
        
        self.EventSystem:Publish(EVENTS.ENTITY_ATTRIBUTE_CHANGED, {
            entityId = entityId,
            attributeName = attributeName,
            oldValue = oldValue,
            newValue = value
        })
        
        -- Special handling for health
        if attributeName == "health" and value <= 0 and oldValue > 0 then
            self.EventSystem:Publish(EVENTS.ENTITY_DIED, {
                entityId = entityId,
                entity = entity
            })
        end
    end
    
    return true
end

-- Get all entities
function EntitySystem:GetAllEntities()
    return self.Entities
end

-- Get team relationship between entities
function EntitySystem:GetTeamRelationship(entityId1, entityId2)
    local entity1 = self.Entities[entityId1]
    local entity2 = self.Entities[entityId2]
    
    if not entity1 or not entity2 then
        return "Neutral"
    end
    
    if entity1.team == entity2.team then
        return "Friendly"
    else
        return "Hostile"
    end
end

-- Check if entity is alive
function EntitySystem:IsAlive(entityId)
    local entity = self.Entities[entityId]
    if not entity then return false end
    
    -- Check humanoid health for NPCs
    if entity.type == ENTITY_TYPES.NPC and entity.humanoid then
        return entity.humanoid.Health > 0
    end
    
    -- Fall back to attribute
    return entity.attributes.health > 0
end

-- PHASE 2 ENHANCEMENT: Additional Entity Type Checking Methods

-- Determines if the entity is a player entity
function EntitySystem:IsPlayer(entityId)
    local entity = self:GetEntity(entityId)
    return entity and entity.type == ENTITY_TYPES.PLAYER
end

-- Determines if the entity is an NPC entity
function EntitySystem:IsNPC(entityId)
    local entity = self:GetEntity(entityId)
    return entity and entity.type == ENTITY_TYPES.NPC
end

-- Returns the entity type (PLAYER or NPC)
function EntitySystem:GetEntityType(entityId)
    local entity = self:GetEntity(entityId)
    return entity and entity.type
end

-- Checks if entity is stunned and cannot act
function EntitySystem:IsStunned(entityId)
    return self:GetAttribute(entityId, "isStunned") == true
end

-- Checks if entity is invulnerable to damage
function EntitySystem:IsInvulnerable(entityId)
    return self:GetAttribute(entityId, "isInvulnerable") == true
end

-- Checks if the entity is valid for operations
function EntitySystem:IsValid(entityId)
    local entity = self:GetEntity(entityId)
    if not entity then
        return false
    end
    
    -- Entity exists but needs additional validation
    if entity.type == ENTITY_TYPES.PLAYER then
        -- Player entity valid if player is still connected
        return entity.player and entity.player.Parent ~= nil
    elseif entity.type == ENTITY_TYPES.NPC then
        -- NPC entity valid if model still exists
        return entity.model and entity.model.Parent ~= nil
    end
    
    return false
end

-- Get the entity's position in world space
function EntitySystem:GetEntityPosition(entityId)
    local entity = self:GetEntity(entityId)
    if not entity or not entity.rootPart then 
        return nil
    end
    
    return entity.rootPart.Position
end

-- Get the entity's forward direction
function EntitySystem:GetEntityLookDirection(entityId)
    local entity = self:GetEntity(entityId)
    if not entity or not entity.rootPart then
        return nil
    end
    
    -- Default to CFrame.LookVector if available
    return entity.rootPart.CFrame.LookVector
end

return EntitySystem