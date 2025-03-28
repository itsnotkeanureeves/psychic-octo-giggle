--[[
    NPCAdapter.lua
    
    PURPOSE:
    Bridges EntitySystem and NPCEntity instances.
    Manages NPC creation and state tracking.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local CombatPath = ServerScriptService.Combat
local NPCEntity = require(CombatPath.Systems.NPCEntity)

local NPCAdapter = {}
NPCAdapter.__index = NPCAdapter

function NPCAdapter.new(entitySystem, eventSystem)
    local self = setmetatable({}, NPCAdapter)
    self.EntitySystem = entitySystem
    self.EventSystem = eventSystem
    self.NPCModels = {} -- Map of model -> NPCEntity
    
    return self
end

-- Create a new NPC entity and track it
function NPCAdapter:CreateNPC(model, attributes)
    local npcEntity = NPCEntity.new(model, attributes)
    self.NPCModels[model] = npcEntity
    return npcEntity
end

-- Retrieve NPC entity for a model
function NPCAdapter:GetNPCFromModel(model)
    return self.NPCModels[model]
end

return NPCAdapter