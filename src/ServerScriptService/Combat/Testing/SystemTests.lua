--[[
    SystemTests.lua
    
    PURPOSE:
    Contains test cases for the core combat systems.
    Verifies that all systems work correctly individually and together.
    
    This is automatically run in Studio mode for development testing.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local TestFramework = require(script.Parent:WaitForChild("TestFramework"))

-- Test cases for combat systems
local testCases = {
    -- Test entity system registration
    TestEntitySystem = function(combatCore)
        local entitySystem = combatCore:GetService("entitySystem")
        if not entitySystem then
            return false, "EntitySystem not found"
        end
        
        -- Check entity existence
        local players = game:GetService("Players"):GetPlayers()
        if #players == 0 then
            return true, "No players to test entity registration"
        end
        
        local player = players[1]
        local entityId = entitySystem:GetEntityId(player)
        
        if not entityId then
            return false, "Player entity not registered"
        end
        
        local entity = entitySystem:GetEntity(entityId)
        if not entity then
            return false, "Could not get entity data"
        end
        
        return true, "EntitySystem functioning correctly"
    end,
    
    -- Test stat system
    TestStatSystem = function(combatCore)
        local entitySystem = combatCore:GetService("entitySystem")
        local statSystem = combatCore:GetService("statSystem")
        
        if not entitySystem or not statSystem then
            return false, "Required systems not found"
        end
        
        -- Check stat retrieval
        local players = game:GetService("Players"):GetPlayers()
        if #players == 0 then
            return true, "No players to test stats"
        end
        
        local player = players[1]
        local entityId = entitySystem:GetEntityId(player)
        
        if not entityId then
            return false, "Player entity not registered"
        end
        
        -- Get a stat value
        local power = statSystem:GetStatValue(entityId, "power")
        if not power or type(power) ~= "number" then
            return false, "Could not get power stat value"
        end
        
        -- Apply a stat modifier
        local modifierId = statSystem:ApplyStatModifier(entityId, {
            id = "TEST_MOD",
            source = "TEST",
            flatModifiers = { power = 5 }
        })
        
        if not modifierId then
            return false, "Failed to apply stat modifier"
        end
        
        -- Get updated stat value
        local newPower = statSystem:GetStatValue(entityId, "power")
        if newPower <= power then
            return false, "Stat modifier did not increase power"
        end
        
        -- Clean up
        statSystem:RemoveStatModifier(entityId, modifierId)
        
        return true, "StatSystem functioning correctly"
    end,
    
    -- Test damage system
    TestDamageSystem = function(combatCore)
        local entitySystem = combatCore:GetService("entitySystem")
        local damageSystem = combatCore:GetService("damageSystem")
        
        if not entitySystem or not damageSystem then
            return false, "Required systems not found"
        end
        
        -- Check damage calculation
        local players = game:GetService("Players"):GetPlayers()
        if #players == 0 then
            return true, "No players to test damage"
        end
        
        local player = players[1]
        local entityId = entitySystem:GetEntityId(player)
        
        if not entityId then
            return false, "Player entity not registered"
        end
        
        -- Get initial health
        local initialHealth = entitySystem:GetAttribute(entityId, "health")
        if not initialHealth or type(initialHealth) ~= "number" then
            return false, "Could not get health attribute"
        end
        
        -- Make sure health is full for test
        entitySystem:SetAttribute(entityId, "health", 100)
        
        -- Calculate damage
        local damageData = damageSystem:CalculateDamage(entityId, entityId, 10, {
            damageType = "physical"
        })
        
        if not damageData or not damageData.amount then
            return false, "Failed to calculate damage"
        end
        
        -- Simple self-damage test (don't actually apply it in real test)
        local testDamage = 5
        local beforeHealth = entitySystem:GetAttribute(entityId, "health")
        
        local success, result = damageSystem:ApplyDamage(entityId, entityId, {
            amount = testDamage,
            damageType = "physical"
        })
        
        if not success then
            return false, "Failed to apply damage"
        end
        
        local afterHealth = entitySystem:GetAttribute(entityId, "health")
        if beforeHealth - afterHealth < testDamage then
            return false, "Damage not applied correctly"
        end
        
        -- Restore health
        entitySystem:SetAttribute(entityId, "health", initialHealth)
        
        return true, "DamageSystem functioning correctly"
    end,
    
    -- Test ability system
    TestAbilitySystem = function(combatCore)
        local entitySystem = combatCore:GetService("entitySystem")
        local abilitySystem = combatCore:GetService("abilitySystem")
        
        if not entitySystem or not abilitySystem then
            return false, "Required systems not found"
        end
        
        -- Check ability grants
        local players = game:GetService("Players"):GetPlayers()
        if #players == 0 then
            return true, "No players to test abilities"
        end
        
        local player = players[1]
        local entityId = entitySystem:GetEntityId(player)
        
        if not entityId then
            return false, "Player entity not registered"
        end
        
        -- Register a test ability if not already granted
        if not abilitySystem:HasAbility(entityId, "SLASH") then
            abilitySystem:GrantAbility(entityId, "SLASH")
        end
        
        -- Check if ability was granted
        if not abilitySystem:HasAbility(entityId, "SLASH") then
            return false, "Failed to grant ability"
        end
        
        -- Get abilities
        local abilities = abilitySystem:GetEntityAbilities(entityId)
        if not abilities or #abilities == 0 then
            return false, "No abilities found"
        end
        
        return true, "AbilitySystem functioning correctly"
    end,
    
    -- Test condition system
    TestConditionSystem = function(combatCore)
        local entitySystem = combatCore:GetService("entitySystem")
        local conditionSystem = combatCore:GetService("conditionSystem")
        
        if not entitySystem or not conditionSystem then
            return false, "Required systems not found"
        end
        
        -- Check condition application
        local players = game:GetService("Players"):GetPlayers()
        if #players == 0 then
            return true, "No players to test conditions"
        end
        
        local player = players[1]
        local entityId = entitySystem:GetEntityId(player)
        
        if not entityId then
            return false, "Player entity not registered"
        end
        
        -- Apply a test condition
        local success, result = conditionSystem:ApplyCondition(entityId, "BURNING", 1, 2, {
            sourceId = entityId
        })
        
        if not success then
            return false, "Failed to apply condition"
        end
        
        -- Check if condition was applied
        if not conditionSystem:HasCondition(entityId, "BURNING") then
            return false, "Condition not properly applied"
        end
        
        -- Clean up
        conditionSystem:RemoveCondition(entityId, "BURNING", true)
        
        return true, "ConditionSystem functioning correctly"
    end,
    
    -- Test system integration
    TestSystemIntegration = function(combatCore)
        local services = combatCore.Services
        
        -- Check that all necessary systems exist
        local requiredSystems = {
            "entitySystem",
            "statSystem",
            "effectSystem",
            "damageSystem",
            "targetSystem",
            "conditionSystem",
            "abilitySystem",
            "eventSystem"
        }
        
        for _, systemName in ipairs(requiredSystems) do
            if not services[systemName] then
                return false, "Missing system: " .. systemName
            end
        end
        
        return true, "All systems properly integrated"
    end
}


task.spawn(function()
    -- Wait a bit for systems to initialize
    wait(3)
    TestFramework:RunTests(testCases)
end)


return testCases
