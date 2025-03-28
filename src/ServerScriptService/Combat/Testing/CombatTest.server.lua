--[[
    CombatTest.server.lua
    
    PURPOSE:
    Test script to validate the combat system.
    Spawns test NPCs and sets up the environment for combat testing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local CombatPath = ServerScriptService.Combat
local SharedPath = ReplicatedStorage.Combat.Shared

-- Get necessary modules
local CombatCore = require(SharedPath.CombatCore)
local NPCSpawner = require(CombatPath.Testing.NPCSpawner)

-- Wait for CombatCore to initialize
local function waitForCombatCore()
    if not CombatCore:IsInitialized() then
        print("[CombatTest] Waiting for CombatCore to initialize...")
        
        -- Wait up to 10 seconds
        local startTime = tick()
        while not CombatCore:IsInitialized() and (tick() - startTime < 10) do
            task.wait(0.5)
        end
        
        if not CombatCore:IsInitialized() then
            warn("[CombatTest] CombatCore initialization timed out")
            return false
        end
    end
    
    return true
end

-- Setup test environment
local function setupTestEnvironment()
    print("[CombatTest] Setting up test environment...")
    
    -- Spawn test NPCs
    local positions = {
        Vector3.new(0, 5, 10),
        Vector3.new(5, 5, 15),
        Vector3.new(-5, 5, 15)
    }
    
    local spawnedNPCs = {}
    
    for i, position in ipairs(positions) do
        local entityId, model = NPCSpawner:CreateTestNPC(position, "Target" .. i)
        if entityId then
            table.insert(spawnedNPCs, {
                entityId = entityId,
                model = model
            })
        end
    end
    
    print("[CombatTest] Spawned", #spawnedNPCs, "test NPCs")
    
    -- Set up player abilities
    local function setupPlayerAbilities(player)
        local entitySystem = CombatCore:GetSystem("entitySystem")
        local abilitySystem = CombatCore:GetSystem("abilitySystem")
        
        if not entitySystem or not abilitySystem then
            warn("[CombatTest] Required systems not found")
            return
        end
        
        -- Register player if needed
        local entityId = entitySystem:GetEntityId(player)
        if not entityId then
            entityId = entitySystem:RegisterPlayer(player)
            print("[CombatTest] Registered player with entity ID:", entityId)
        end
        
        -- Grant test abilities
        abilitySystem:GrantAbility(entityId, "FIREBALL")
        abilitySystem:GrantAbility(entityId, "HEAL")
        
        print("[CombatTest] Granted abilities to player:", player.Name)
    end
    
    -- Set up existing players
    for _, player in ipairs(Players:GetPlayers()) do
        setupPlayerAbilities(player)
    end
    
    -- Set up future players
    Players.PlayerAdded:Connect(function(player)
        setupPlayerAbilities(player)
    end)
    
    print("[CombatTest] Test environment setup complete")
end

-- Run the test
if waitForCombatCore() then
    setupTestEnvironment()
else
    warn("[CombatTest] Could not initialize test environment")
end

print("[CombatTest] Combat test script loaded")
