--[[
    EntitySystem.lua
    
    PURPOSE:
    Provides a unified interface for interacting with game entities (players and NPCs).
    Creates an abstraction layer that allows the combat system to work with any entity type
    through a consistent API.
    
    USAGE:
    local EntitySystem = require(ReplicatedStorage.Combat.Shared.EntitySystem)
    
    -- Initialize the system
    EntitySystem:Initialize({eventSystem = EventSystem})
    
    -- Get an entity by instance (player or NPC model)
    local entity = EntitySystem:GetEntityFromInstance(player)
    
    -- Get an entity by ID
    local entity = EntitySystem:GetEntity("ENTITY_ID")
    
    -- Check entity attributes
    local health = EntitySystem:GetAttribute(entityId, "health")
    EntitySystem:SetAttribute(entityId, "health", newHealth)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(script.Parent.Constants)
local Types = require(ReplicatedStorage.Combat.Types.CombatTypes)

local EntitySystem = {}
local EventSystem

-- Private variables
local entities = {} -- Stores all active entities by ID
local instanceToId = {} -- Maps instances to entity IDs for quick lookup

-- Forward declarations for entity implementations
local PlayerEntity
local NPCEntity

--[[
    Initialize the EntitySystem with dependencies.
    
    @param services {table} - Dependencies like eventSystem
]]
function EntitySystem:Initialize(services)
    EventSystem = services.eventSystem or error("EventSystem is required")
    
    -- We'll initialize the entity implementations here once they're created
    -- This allows us to keep the implementations in separate files for cleaner organization
    PlayerEntity = require(script.Parent.Parent.EntitySystem.PlayerEntity)
    NPCEntity = require(script.Parent.Parent.EntitySystem.NPCEntity)
    
    -- Set up any event listeners
    EventSystem:on(Constants.Events.ENTITY_DIED, function(params)
        self:HandleEntityDied(params.entityId)
    end)
    
    print("EntitySystem initialized")
end

--[[
    Register an entity with the system.
    
    @param entity {table} - Entity data
    @return {string} - Entity ID
]]
function EntitySystem:RegisterEntity(entity)
    if not entity or not entity.id then
        error("Entity must have an ID")
    end
    
    entities[entity.id] = entity
    
    -- If the entity has an instance, map it for quick lookup
    if entity.instance then
        instanceToId[entity.instance] = entity.id
    end
    
    return entity.id
end

--[[
    Remove an entity from the system.
    
    @param entityId {string} - Entity ID
    @return {boolean} - True if entity was removed
]]
function EntitySystem:UnregisterEntity(entityId)
    local entity = entities[entityId]
    if not entity then
        return false
    end
    
    -- Remove instance mapping if it exists
    if entity.instance then
        instanceToId[entity.instance] = nil
    end
    
    entities[entityId] = nil
    return true
end

--[[
    Get an entity by ID.
    
    @param entityId {string} - Entity ID
    @return {table} - Entity data or nil if not found
]]
function EntitySystem:GetEntity(entityId)
    return entities[entityId]
end

--[[
    Create and register an entity from a Roblox instance.
    
    @param instance {Instance} - Player or model instance
    @return {table} - Entity data or nil if invalid
]]
function EntitySystem:GetEntityFromInstance(instance)
    -- Check for existing entity first
    if instanceToId[instance] then
        return entities[instanceToId[instance]]
    end
    
    -- Create new entity based on instance type
    local entity
    if instance:IsA("Player") then
        entity = PlayerEntity.new(instance)
    elseif instance:IsA("Model") and instance:FindFirstChild("EntityType") 
           and instance:FindFirstChild("EntityType").Value == "NPC" then
        entity = NPCEntity.new(instance)
    else
        return nil
    end
    
    -- Register and return the entity
    self:RegisterEntity(entity)
    return entity
end

--[[
    Check if an entity exists.
    
    @param entityId {string} - Entity ID
    @return {boolean} - True if entity exists
]]
function EntitySystem:IsValid(entityId)
    return entities[entityId] ~= nil
end

--[[
    Get an entity attribute value.
    
    @param entityId {string} - Entity ID
    @param attributeName {string} - Attribute name
    @return {any} - Attribute value or nil if not found
]]
function EntitySystem:GetAttribute(entityId, attributeName)
    local entity = entities[entityId]
    if not entity or not entity.attributes then
        return nil
    end
    
    return entity.attributes[attributeName]
end

--[[
    Set an entity attribute value.
    
    @param entityId {string} - Entity ID
    @param attributeName {string} - Attribute name
    @param value {any} - New attribute value
    @return {boolean} - True if attribute was set
]]
function EntitySystem:SetAttribute(entityId, attributeName, value)
    local entity = entities[entityId]
    if not entity or not entity.attributes then
        return false
    end
    
    local oldValue = entity.attributes[attributeName]
    entity.attributes[attributeName] = value
    
    -- Trigger event for attribute change
    EventSystem:trigger(Constants.Events.STAT_CHANGED, {
        entityId = entityId,
        attributeName = attributeName,
        oldValue = oldValue,
        newValue = value
    })
    
    return true
end

--[[
    Handle entity death event.
    
    @param entityId {string} - Entity ID
]]
function EntitySystem:HandleEntityDied(entityId)
    local entity = entities[entityId]
    if not entity then
        return
    end
    
    -- Update alive state
    entity.attributes.isAlive = false
    
    -- Additional death handling could go here
end

--[[
    Get the team of an entity.
    
    @param entityId {string} - Entity ID
    @return {string} - Team ID or nil if not found
]]
function EntitySystem:GetTeam(entityId)
    local entity = entities[entityId]
    if not entity then
        return nil
    end
    
    return entity.team
end

--[[
    Check if two entities are on the same team.
    
    @param entity1Id {string} - First entity ID
    @param entity2Id {string} - Second entity ID
    @return {boolean} - True if entities are on the same team
]]
function EntitySystem:AreOnSameTeam(entity1Id, entity2Id)
    local team1 = self:GetTeam(entity1Id)
    local team2 = self:GetTeam(entity2Id)
    
    -- If either entity doesn't have a team, they can't be on the same team
    if not team1 or not team2 then
        return false
    end
    
    return team1 == team2
end

--[[
    Get all entities matching a filter function.
    
    @param filterFn {function} - Function that takes an entity and returns true if it matches
    @return {table} - Array of matching entities
]]
function EntitySystem:GetEntities(filterFn)
    local result = {}
    
    for id, entity in pairs(entities) do
        if not filterFn or filterFn(entity) then
            table.insert(result, entity)
        end
    end
    
    return result
end

--[[
    Get all entity IDs.
    
    @return {table} - Array of entity IDs
]]
function EntitySystem:GetAllEntityIds()
    local ids = {}
    
    for id, _ in pairs(entities) do
        table.insert(ids, id)
    end
    
    return ids
end

--[[
    Clear all entities from the system.
    Mainly used for testing and server resets.
    
    @return {number} - Number of entities cleared
]]
function EntitySystem:ClearAllEntities()
    local count = 0
    
    for id, _ in pairs(entities) do
        count = count + 1
    end
    
    entities = {}
    instanceToId = {}
    
    return count
end

return EntitySystem
