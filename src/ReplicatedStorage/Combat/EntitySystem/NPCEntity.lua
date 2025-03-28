--[[
    NPCEntity.lua
    
    PURPOSE:
    NPC entity implementation providing standardized interface to NPC data.
    Wraps an NPC model instance and exposes a common API shared with PlayerEntity.
    
    USAGE:
    - Created via Entity.from(npcModel) factory function
    - Used by ConditionManager to interact with NPC instances consistently
    - Provides NPC-specific implementations of entity methods
    
    INTEGRATION:
    Part of the EntitySystem that enables unified condition management
    for both Players and NPCs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityModule = require(ReplicatedStorage.Combat.EntitySystem.Entity)
local Entity = EntityModule.Entity
local EntityTypes = EntityModule.EntityTypes

local NPCEntity = setmetatable({}, {__index = Entity})
NPCEntity.__index = NPCEntity

--[[
    Create new NPC entity wrapper.
    
    @param model {Model} - NPC model instance
    @return {NPCEntity} - Initialized entity
]]
function NPCEntity.new(model)
    local self = setmetatable({}, NPCEntity)
    self.model = model
    self.npcId = model:FindFirstChild("NPCId") and model:FindFirstChild("NPCId").Value
    
    -- Get NPC entity instance if available using global adapter
    -- This maintains compatibility with existing NPC system
    if _G.NPC_COMBAT_ADAPTER then
        self.npcInstance = _G.NPC_COMBAT_ADAPTER:GetNPCFromModel(model)
    end
    
    return self
end

--[[
    Get unique identifier for this entity.
    For NPCs, this is their NPCId value or model path as fallback.
    
    @return {string} - Entity ID
]]
function NPCEntity:getId()
    return self.npcId or self.model:GetFullName()
end

--[[
    Get entity type.
    Always returns NPC for NPCEntity.
    
    @return {string} - PLAYER or NPC
]]
function NPCEntity:getType()
    return EntityTypes.NPC
end

--[[
    Get underlying model.
    For NPCs, this returns the Model instance.
    
    @return {Instance} - NPC model
]]
function NPCEntity:getModel()
    return self.model
end

--[[
    Handle condition application notification.
    For NPCs, this delegates to the UI adapter for visualization.
    
    @param conditionId {string} - Applied condition ID
    @param stacks {number} - Stack count
    @param duration {number} - Duration in seconds
    @param params {table} - Additional parameters
]]
function NPCEntity:notifyConditionApplied(conditionId, stacks, duration, params)
    -- Delegate to NPC instance for visualization
    if self.npcInstance then
        -- Use existing NPC UI adapter for visualization
        if _G.NPC_ENTITY_UI_ADAPTER then
            _G.NPC_ENTITY_UI_ADAPTER.UpdateCondition(self.npcInstance, conditionId, stacks)
        end
    end
end

--[[
    Get the humanoid for this NPC.
    Helper method specific to NPCEntity.
    
    @return {Humanoid|nil} - Humanoid or nil if not available
]]
function NPCEntity:getHumanoid()
    if self.model then
        return self.model:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

--[[
    Apply damage to the NPC entity.
    Delegates to the NPC instance if available, otherwise applies direct humanoid damage.
    
    @param amount {number} - Damage amount
    @param damageType {string} - Type of damage
    @param source {Entity} - Source entity causing the damage
    @return {number} - Actual damage applied
]]
function NPCEntity:applyDamage(amount, damageType, source)
    -- Delegate to NPC instance if available
    if self.npcInstance then
        local sourceModel = source and source:getModel()
        local success, damage = pcall(function()
            return self.npcInstance:Damage(amount, sourceModel, damageType, false)
        end)
        
        if success then
            return damage
        end
    end
    
    -- Fallback to direct humanoid damage
    local humanoid = self:getHumanoid()
    if humanoid then
        local previousHealth = humanoid.Health
        humanoid.Health = math.max(0, humanoid.Health - amount)
        return previousHealth - humanoid.Health
    end
    
    return 0
end

--[[
    Get the NPC entity instance.
    Helper method to access the underlying NPC_Entity instance.
    
    @return {NPC_Entity|nil} - NPC instance or nil if not available
]]
function NPCEntity:getNPCInstance()
    return self.npcInstance
end

return NPCEntity
