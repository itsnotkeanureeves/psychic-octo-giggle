--[[
    EntityRegistry.lua
    
    PURPOSE:
    Caches entity wrapper instances to avoid repeated creation.
    Provides a single point of access for entity wrappers with efficient caching.
    
    USAGE:
    - Create a registry with EntityRegistry.new()
    - Use registry:getEntity(target) to get entity wrappers
    - The registry maintains a weak cache to allow garbage collection
    
    INTEGRATION:
    Used by ConditionManager to efficiently create and reuse entity wrappers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityModule = require(ReplicatedStorage.Combat.EntitySystem.Entity)
local Entity = EntityModule.Entity

local EntityRegistry = {}
EntityRegistry.__index = EntityRegistry

--[[
    Create new entity registry.
    
    @return {EntityRegistry} - Initialized registry
]]
function EntityRegistry.new()
    local self = setmetatable({}, EntityRegistry)
    -- Use weak table to allow garbage collection when entities are no longer referenced
    self.entityCache = setmetatable({}, {__mode = "k"})
    return self
end

--[[
    Get or create entity wrapper for target.
    Uses cached instance if available to avoid repeated creation.
    
    @param target {any} - Player or NPC model
    @return {Entity} - Entity wrapper or nil if invalid
]]
function EntityRegistry:getEntity(target)
    -- Fast path: Check cache first
    if self.entityCache[target] then
        return self.entityCache[target]
    end
    
    -- Create new entity wrapper
    local entity = Entity.from(target)
    
    -- Cache entity if valid
    if entity then
        self.entityCache[target] = entity
    end
    
    return entity
end

--[[
    Clear the entity cache.
    Useful during testing or when forcing re-creation of entities.
]]
function EntityRegistry:clearCache()
    self.entityCache = setmetatable({}, {__mode = "k"})
end

--[[
    Get the number of cached entities.
    Useful for debugging and monitoring.
    
    @return {number} - Count of cached entities
]]
function EntityRegistry:getCacheSize()
    local count = 0
    for _, _ in pairs(self.entityCache) do
        count = count + 1
    end
    return count
end

return EntityRegistry
