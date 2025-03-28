--[[
    NPCEntity.lua
    
    PURPOSE:
    Basic NPC entity implementation that works with EntitySystem.
    Provides health tracking and state management for NPCs.
]]

local NPCEntity = {}
NPCEntity.__index = NPCEntity

function NPCEntity.new(model, attributes)
    local self = setmetatable({}, NPCEntity)
    self.model = model
    self.humanoid = model:FindFirstChildOfClass("Humanoid")
    self.rootPart = model:FindFirstChild("HumanoidRootPart")
    self.attributes = attributes or {}
    
    -- Initialize health
    if self.humanoid and attributes then
        if attributes.maxHealth then
            self.humanoid.MaxHealth = attributes.maxHealth
        end
        if attributes.health then
            self.humanoid.Health = attributes.health
        end
    end
    
    return self
end

-- Simple getter for health from the humanoid
function NPCEntity:GetHealth()
    if self.humanoid then
        return self.humanoid.Health
    end
    return self.attributes.health or 0
end

-- Simple getter for max health
function NPCEntity:GetMaxHealth()
    if self.humanoid then
        return self.humanoid.MaxHealth
    end
    return self.attributes.maxHealth or 100
end

-- Simple setter for health
function NPCEntity:SetHealth(value)
    if self.humanoid then
        self.humanoid.Health = value
    end
    self.attributes.health = value
end

return NPCEntity