--[[
    CombatCore.lua
    
    PURPOSE:
    Core module that contains references to all combat subsystems.
    Acts as a central access point for all combat functionality.
    
    DESIGN PRINCIPLES:
    - Centralized system access
    - Layered initialization
    - Explicit dependencies
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Service paths
local CombatPath = ServerScriptService:WaitForChild("Combat")
local SystemsPath = CombatPath:WaitForChild("Systems")
local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")

-- Create the CombatCore module
local CombatCore = {
    -- All combat systems
    Systems = {},
    
    -- Initialization state
    Initialized = false
}

-- Get a specific system
function CombatCore:GetSystem(systemName)
    if not self.Initialized then
        warn("CombatCore: Trying to access system before initialization: " .. systemName)
        return nil
    end
    
    return self.Systems[systemName]
end

-- Get all systems
function CombatCore:GetSystems()
    if not self.Initialized then
        warn("CombatCore: Trying to access systems before initialization")
        return nil
    end
    
    return self.Systems
end

-- Initialize all combat subsystems
function CombatCore:Initialize()
    -- Skip if already initialized
    if self.Initialized then
        return self
    end
    
    ----------------------------------
    -- Layer 1: Foundation Systems
    ----------------------------------
    -- Load and initialize EventSystem first (no dependencies)
    local EventSystem = require(SharedPath:WaitForChild("EventSystem"))
    local eventSystem = EventSystem.new()
    
    -- EntitySystem depends only on EventSystem
    local EntitySystem = require(SystemsPath:WaitForChild("EntitySystem"))
    local entitySystem = EntitySystem.new(eventSystem)
    
    -- StatSystem depends on EntitySystem and EventSystem
    local StatSystem = require(SystemsPath:WaitForChild("StatSystem"))
    local statSystem = StatSystem.new(entitySystem, eventSystem)
    
    ----------------------------------
    -- Layer 2: Fundamental Mechanics
    ----------------------------------
    -- TargetSystem depends on EntitySystem and EventSystem
    local TargetSystem = require(SystemsPath:WaitForChild("TargetSystem"))
    local targetSystem = TargetSystem.new(entitySystem, eventSystem)
    
    -- EffectSystem depends on EntitySystem, StatSystem, EventSystem
    -- (No circular dependency with DamageSystem anymore)
    local EffectSystem = require(SystemsPath:WaitForChild("EffectSystem"))
    local effectSystem = EffectSystem.new(entitySystem, statSystem, eventSystem)
    
    -- DamageSystem depends on EntitySystem, StatSystem, EventSystem, EffectSystem
    local DamageSystem = require(SystemsPath:WaitForChild("DamageSystem"))
    local damageSystem = DamageSystem.new(entitySystem, statSystem, eventSystem, effectSystem)
    
    ----------------------------------
    -- Layer 3: Gameplay Systems
    ----------------------------------
    -- ConditionSystem depends on EntitySystem, StatSystem, EventSystem, EffectSystem
    local ConditionSystem = require(SystemsPath:WaitForChild("ConditionSystem"))
    local conditionSystem = ConditionSystem.new(entitySystem, statSystem, eventSystem, effectSystem)
    
    -- Connect EffectSystem, DamageSystem, and ConditionSystem via EventSystem instead of direct references
    effectSystem:ConnectEvents(eventSystem)
    damageSystem:ConnectEvents(eventSystem)
    conditionSystem:ConnectEvents(eventSystem)
    
    -- AbilitySystem has dependencies on all other systems
    local AbilitySystem = require(SystemsPath:WaitForChild("AbilitySystem"))
    local abilitySystem = AbilitySystem.new(entitySystem, targetSystem, effectSystem, conditionSystem, statSystem, eventSystem)
    
    -- Store all systems
    self.Systems = {
        eventSystem = eventSystem,
        entitySystem = entitySystem,
        statSystem = statSystem,
        targetSystem = targetSystem,
        effectSystem = effectSystem,
        damageSystem = damageSystem,
        conditionSystem = conditionSystem,
        abilitySystem = abilitySystem
    }
    
    -- Mark as initialized
    self.Initialized = true
    
    return self
end

-- Check if the system is initialized
function CombatCore:IsInitialized()
    return self.Initialized
end

return CombatCore