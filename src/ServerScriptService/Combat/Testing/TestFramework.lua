--[[
    TestFramework.lua
    
    PURPOSE:
    Provides a framework for testing the combat system functionality.
    Handles test running, result reporting, and test case organization.
    
    DESIGN PRINCIPLES:
    - Clean test interface
    - Isolated test cases
    - Descriptive reporting
    
    USAGE:
    local TestFramework = require(script.Parent.TestFramework)
    
    -- Define a test suite
    local testCases = {
        TestDamageCalculation = function(combatCore)
            -- Test implementation
            local entitySystem = combatCore:GetService("entitySystem")
            local damageSystem = combatCore:GetService("damageSystem")
            
            -- Test code here
            return true, "Damage calculation test passed"
        end
    }
    
    -- Run the tests
    TestFramework:RunTests(testCases)
]]

local ServerScriptService = game:GetService("ServerScriptService")

-- Initialize the TestFramework
local TestFramework = {}

-- Get CombatCore reference
function TestFramework:GetCombatCore()
    local CombatPath = ServerScriptService:FindFirstChild("Combat")
    if not CombatPath then
        warn("TestFramework: Combat folder not found")
        return nil
    end
    
    local CorePath = CombatPath:FindFirstChild("Core")
    if not CorePath then
        warn("TestFramework: Combat/Core folder not found")
        return nil
    end
    
    local CombatCoreScript = CorePath:FindFirstChild("CombatCore.server")
    if not CombatCoreScript then
        CombatCoreScript = CorePath:FindFirstChild("CombatCore")
    end
    
    if not CombatCoreScript then
        warn("TestFramework: CombatCore script not found")
        return nil
    end
    
    -- Wait for CombatCore to initialize
    if not CombatCoreScript:GetAttribute("CombatSystemInitialized") then
        warn("TestFramework: CombatCore not initialized yet, waiting...")
        local startTime = tick()
        local timeout = 10 -- seconds
        
        while not CombatCoreScript:GetAttribute("CombatSystemInitialized") do
            if tick() - startTime > timeout then
                warn("TestFramework: Timed out waiting for CombatCore initialization")
                return nil
            end
            task.wait(0.1)
        end
    end
    
    -- Get reference to CombatCore
    local success, combatCore = pcall(function()
        return require(CombatCoreScript)
    end)
    
    if not success or not combatCore or not combatCore.Services then
        warn("TestFramework: Failed to load CombatCore:", combatCore)
        return nil
    end
    
    print("TestFramework: Successfully loaded CombatCore")
    return combatCore
end

-- Run a single test case
function TestFramework:RunTest(testName, testFunction)
    print("Running test: " .. testName)
    
    -- Get CombatCore reference
    local combatCore = self:GetCombatCore()
    if not combatCore then
        print("[FAIL] " .. testName .. " - Could not access CombatCore")
        return false
    end
    
    -- Run the test with error handling
    local success, result = pcall(function()
        return testFunction(combatCore)
    end)
    
    if not success then
        print("[FAIL] " .. testName .. " - Error: " .. tostring(result))
        return false
    end
    
    -- Check test result
    if type(result) == "table" then
        local testPassed = result[1] or false
        local message = result[2] or ""
        
        if testPassed then
            print("[PASS] " .. testName .. " - " .. message)
        else
            print("[FAIL] " .. testName .. " - " .. message)
        end
        
        return testPassed
    else
        -- Simple boolean result
        if result then
            print("[PASS] " .. testName)
        else
            print("[FAIL] " .. testName)
        end
        
        return result
    end
end

-- Run a set of tests
function TestFramework:RunTests(testCases)
    print("\n--- STARTING COMBAT SYSTEM TESTS ---\n")
    
    local passCount = 0
    local failCount = 0
    
    for testName, testFunction in pairs(testCases) do
        if self:RunTest(testName, testFunction) then
            passCount = passCount + 1
        else
            failCount = failCount + 1
        end
    end
    
    print("\n--- TEST RESULTS ---")
    print("Passed: " .. passCount)
    print("Failed: " .. failCount)
    print("Total:  " .. (passCount + failCount))
    print("\n")
    
    return passCount, failCount
end

return TestFramework
