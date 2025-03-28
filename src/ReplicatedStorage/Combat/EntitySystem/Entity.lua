--[[
    Entity.lua
    
    PURPOSE:
    Base entity interface providing unified access to player and NPC data.
    Serves as the foundation for the entity abstraction layer, allowing
    combat systems to interact with any entity type through a consistent API.
    
    USAGE:
    - Use Entity.from(target) to create the appropriate entity wrapper.
    - Call entity methods like getId(), getType(), getModel() for consistent access.
    - Entity wrappers abstract away the differences between Players and NPCs.
    
    INTEGRATION:
    This module is part of the EntitySystem that enables unified condition
    management for both Players and NPCs.
]]

local EntityTypes = {
    PLAYER = "PLAYER",
    NPC = "NPC"
}

local Entity = {}
Entity.__index = Entity

--[[
    Create appropriate entity wrapper based on instance type.
    This is the primary factory function for creating entity wrappers.
    
    @param target {Instance} - Player or NPC model
    @return {Entity} - Entity wrapper or nil if invalid
]]
function Entity.from(target)
    if typeof(target) == "Instance" then
        if target:IsA("Player") then
            local PlayerEntity = require(script.Parent.PlayerEntity)
            return PlayerEntity.new(target)
        elseif target:IsA("Model") and target:FindFirstChild("EntityType") 
               and target:FindFirstChild("EntityType").Value == "NPC" then
            local NPCEntity = require(script.Parent.NPCEntity)
            return NPCEntity.new(target)
        end
    end
    return nil
end

--[[
    Get unique identifier for this entity.
    Must be implemented by derived classes.
    
    @return {string} - Entity ID
]]
function Entity:getId()
    error("Entity:getId() must be implemented by derived classes")
end

--[[
    Get entity type (PLAYER or NPC).
    Must be implemented by derived classes.
    
    @return {string} - Entity type constant
]]
function Entity:getType()
    error("Entity:getType() must be implemented by derived classes")
end

--[[
    Get underlying model or player instance.
    Must be implemented by derived classes.
    
    @return {Instance} - Player or model
]]
function Entity:getModel()
    error("Entity:getModel() must be implemented by derived classes")
end

--[[
    Handle condition application notification.
    Must be implemented by derived classes.
    
    @param conditionId {string} - Applied condition ID
    @param stacks {number} - Stack count
    @param duration {number} - Duration in seconds
    @param params {table} - Additional parameters
]]
function Entity:notifyConditionApplied(conditionId, stacks, duration, params)
    error("Entity:notifyConditionApplied() must be implemented by derived classes")
end

return {
    Entity = Entity,
    EntityTypes = EntityTypes
}
