--[[
    EntityStateLock.lua
    
    PURPOSE:
    Provides a lightweight locking mechanism to prevent concurrent modifications
    to entity state. Helps avoid race conditions when multiple systems attempt to
    modify entity conditions simultaneously.
    
    USAGE:
    - Use EntityStateLock.acquire(entityId, operation) to acquire a lock
    - Use EntityStateLock.release(entityId) to release a lock
    - Use EntityStateLock.withLock(entityId, operation, callback) to execute code with a lock
    
    INTEGRATION:
    Used by ConditionManager to ensure thread safety for condition operations.
]]

local EntityStateLock = {}

-- Track locks by entity ID
local entityLocks = {}

--[[
    Acquire lock with timeout.
    
    @param entityId {string} - Entity identifier
    @param operation {string} - Operation name for debugging
    @param timeout {number} - Lock timeout in seconds
    @return {boolean} - Whether lock was acquired
]]
function EntityStateLock.acquire(entityId, operation, timeout)
    timeout = timeout or 0.5 -- Default timeout
    
    -- Fast path: No existing lock
    if not entityLocks[entityId] then
        entityLocks[entityId] = {
            operation = operation,
            time = tick()
        }
        return true
    end
    
    -- Check for stale lock
    local lockInfo = entityLocks[entityId]
    if tick() - lockInfo.time > timeout then
        -- Release stale lock and warn
        warn("[EntityStateLock] Stale lock detected for entity", entityId, 
             "from operation", lockInfo.operation, "after", timeout, "seconds")
        
        -- Take over with new lock
        entityLocks[entityId] = {
            operation = operation,
            time = tick()
        }
        return true
    end
    
    return false
end

--[[
    Release lock.
    
    @param entityId {string} - Entity identifier
]]
function EntityStateLock.release(entityId)
    entityLocks[entityId] = nil
end

--[[
    Execute function with lock.
    Automatically acquires lock, executes callback, and releases lock.
    
    @param entityId {string} - Entity identifier
    @param operation {string} - Operation name
    @param callback {function} - Function to execute with lock
    @return {boolean, any} - Success flag and operation result
]]
function EntityStateLock.withLock(entityId, operation, callback)
    if not EntityStateLock.acquire(entityId, operation) then
        return false, "Lock acquisition failed for " .. operation
    end
    
    local success, result = pcall(callback)
    
    EntityStateLock.release(entityId)
    
    return success, result
end

--[[
    Check if entity is currently locked.
    Useful for debugging and avoiding deadlocks.
    
    @param entityId {string} - Entity identifier
    @return {boolean} - Whether entity is locked
]]
function EntityStateLock.isLocked(entityId)
    return entityLocks[entityId] ~= nil
end

--[[
    Get active lock information.
    Useful for debugging lock issues.
    
    @param entityId {string} - Entity identifier
    @return {table|nil} - Lock information or nil if not locked
]]
function EntityStateLock.getLockInfo(entityId)
    local lockInfo = entityLocks[entityId]
    if not lockInfo then
        return nil
    end
    
    -- Return a copy to prevent modification
    return {
        operation = lockInfo.operation,
        time = lockInfo.time,
        duration = tick() - lockInfo.time
    }
end

return EntityStateLock
