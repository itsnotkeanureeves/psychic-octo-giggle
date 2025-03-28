--[[
    DefinitionLoader.lua
    
    Loads all ability and condition definitions from the ReplicatedStorage
    and registers them with the appropriate systems.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Path configuration
local CombatPath = ReplicatedStorage:WaitForChild("Combat")
local DefinitionsPath = CombatPath:WaitForChild("Definitions")
local AbilityDefinitionsPath = DefinitionsPath:WaitForChild("AbilityDefinitions")
local ConditionDefinitionsPath = DefinitionsPath:WaitForChild("ConditionDefinitions")

-- The DefinitionLoader module
local DefinitionLoader = {}

-- Load ability definitions and register them with AbilitySystem
function DefinitionLoader:LoadAbilityDefinitions(abilitySystem)
    if not abilitySystem then
        warn("DefinitionLoader: AbilitySystem is nil, cannot load ability definitions")
        return false
    end
    
    local loadedCount = 0
    local failedCount = 0
    
    -- Load from BasicAbilities module
    local BasicAbilitiesModule = AbilityDefinitionsPath:FindFirstChild("BasicAbilities")
    
    if not BasicAbilitiesModule then
        warn("DefinitionLoader: BasicAbilities.lua not found in AbilityDefinitions folder")
        return false
    end
    
    -- Load ability definitions from BasicAbilities module
    local success, abilityDefs = pcall(function()
        return require(BasicAbilitiesModule)
    end)
    
    if not success or not abilityDefs then
        warn("DefinitionLoader: Failed to load BasicAbilities module: " .. tostring(abilityDefs))
        return false
    end
    
    -- Register each ability
    for id, abilityDef in pairs(abilityDefs) do
        -- Make sure each ability has its ID set
        abilityDef.id = abilityDef.id or id
        
        -- Register the ability
        local regSuccess = abilitySystem:RegisterAbility(abilityDef.id, abilityDef)
        
        if regSuccess then
            loadedCount = loadedCount + 1
        else
            warn("DefinitionLoader: Failed to register ability: " .. (abilityDef.id or id))
            failedCount = failedCount + 1
        end
    end
    
    print("DefinitionLoader: Loaded " .. loadedCount .. " abilities with " .. failedCount .. " failures")
    return loadedCount > 0
end

-- Load condition definitions and register them with ConditionSystem
function DefinitionLoader:LoadConditionDefinitions(conditionSystem)
    if not conditionSystem then
        warn("DefinitionLoader: ConditionSystem is nil, cannot load condition definitions")
        return false
    end
    
    local loadedCount = 0
    local failedCount = 0
    
    -- Load from BasicConditions module
    local BasicConditionsModule = ConditionDefinitionsPath:FindFirstChild("BasicConditions")
    
    if not BasicConditionsModule then
        warn("DefinitionLoader: BasicConditions.lua not found in ConditionDefinitions folder")
        return false
    end
    
    -- Load condition definitions from BasicConditions module
    local success, conditionDefs = pcall(function()
        return require(BasicConditionsModule)
    end)
    
    if not success or not conditionDefs then
        warn("DefinitionLoader: Failed to load BasicConditions module: " .. tostring(conditionDefs))
        return false
    end
    
    -- Initialize the module with the EffectSystem reference
    if conditionDefs.Initialize then
        conditionDefs:Initialize(conditionSystem.EffectSystem)
    end
    
    -- Register each condition
    for id, conditionDef in pairs(conditionDefs) do
        -- Skip non-definition entries in the module (like the Initialize function)
        if typeof(conditionDef) == "table" and conditionDef.name then
            -- Register the condition
            local regSuccess = conditionSystem:RegisterCondition(id, conditionDef)
            
            if regSuccess then
                loadedCount = loadedCount + 1
            else
                warn("DefinitionLoader: Failed to register condition: " .. id)
                failedCount = failedCount + 1
            end
        end
    end
    
    print("DefinitionLoader: Loaded " .. loadedCount .. " conditions with " .. failedCount .. " failures")
    return loadedCount > 0
end

-- Load all definitions
function DefinitionLoader:LoadAllDefinitions(combatCore)
    if not combatCore then
        warn("DefinitionLoader: CombatCore is nil, cannot load definitions")
        return false
    end
    
    local abilitySystem = combatCore:GetSystem("abilitySystem")
    local conditionSystem = combatCore:GetSystem("conditionSystem")
    
    if not abilitySystem then
        warn("DefinitionLoader: AbilitySystem not found in CombatCore")
        return false
    end
    
    if not conditionSystem then
        warn("DefinitionLoader: ConditionSystem not found in CombatCore")
        return false
    end
    
    local abilitiesLoaded = self:LoadAbilityDefinitions(abilitySystem)
    local conditionsLoaded = self:LoadConditionDefinitions(conditionSystem)
    
    print("DefinitionLoader: Finished loading all definitions")
    return abilitiesLoaded and conditionsLoaded
end

return DefinitionLoader