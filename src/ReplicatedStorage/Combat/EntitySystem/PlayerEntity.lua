--[[
    PlayerEntity.lua
    
    PURPOSE:
    Player entity implementation providing standardized interface to player data.
    Wraps a Roblox Player instance and exposes a common API shared with NPCEntity.
    
    USAGE:
    - Created via Entity.from(player) factory function
    - Used by ConditionManager to interact with Player instances consistently
    - Provides player-specific implementations of entity methods
    
    INTEGRATION:
    Part of the EntitySystem that enables unified condition management
    for both Players and NPCs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityModule = require(ReplicatedStorage.Combat.EntitySystem.Entity)
local Entity = EntityModule.Entity
local EntityTypes = EntityModule.EntityTypes

local PlayerEntity = setmetatable({}, {__index = Entity})
PlayerEntity.__index = PlayerEntity

--[[
    Create new player entity wrapper.
    
    @param player {Player} - Roblox Player instance
    @return {PlayerEntity} - Initialized entity
]]
function PlayerEntity.new(player)
    local self = setmetatable({}, PlayerEntity)
    self.player = player
    return self
end

--[[
    Get unique identifier for this entity.
    For players, this is their UserId as a string.
    
    @return {string} - Entity ID
]]
function PlayerEntity:getId()
    return tostring(self.player.UserId)
end

--[[
    Get entity type.
    Always returns PLAYER for PlayerEntity.
    
    @return {string} - PLAYER or NPC
]]
function PlayerEntity:getType()
    return EntityTypes.PLAYER
end

--[[
    Get underlying model.
    For players, this returns the Player instance.
    
    @return {Instance} - Player instance
]]
function PlayerEntity:getModel()
    return self.player
end

--[[
    Handle condition application notification.
    For players, this triggers client-side notification if needed.
    
    @param conditionId {string} - Applied condition ID
    @param stacks {number} - Stack count
    @param duration {number} - Duration in seconds
    @param params {table} - Additional parameters
]]
function PlayerEntity:notifyConditionApplied(conditionId, stacks, duration, params)
    -- This is a hook for player-specific notification logic
    -- Could fire a remote event to show UI effects, play sounds, etc.
    -- Currently a no-op as this would be implemented based on game requirements
end

--[[
    Get the character model for this player.
    Helper method specific to PlayerEntity.
    
    @return {Model|nil} - Character model or nil if not available
]]
function PlayerEntity:getCharacter()
    return self.player.Character
end

--[[
    Get the humanoid for this player.
    Helper method specific to PlayerEntity.
    
    @return {Humanoid|nil} - Humanoid or nil if not available
]]
function PlayerEntity:getHumanoid()
    local character = self:getCharacter()
    if character then
        return character:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

--[[
    Apply damage to the player entity.
    
    @param amount {number} - Damage amount
    @param damageType {string} - Type of damage
    @param source {Entity} - Source entity causing the damage
    @return {number} - Actual damage applied
]]
function PlayerEntity:applyDamage(amount, damageType, source)
    local humanoid = self:getHumanoid()
    if not humanoid then
        return 0
    end
    
    local previousHealth = humanoid.Health
    humanoid.Health = math.max(0, humanoid.Health - amount)
    
    return previousHealth - humanoid.Health
end

return PlayerEntity
