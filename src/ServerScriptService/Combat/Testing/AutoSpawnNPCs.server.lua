--[[
    AutoSpawnNPCs.server.lua
    
    PURPOSE:
    Automatically spawns test NPCs when the game starts for combat testing.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatPath = ServerScriptService:WaitForChild("Combat")
local TestingPath = CombatPath:WaitForChild("Testing")
local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")

-- Wait for combat system to initialize
local function waitForCombatSystem()
    local CombatCore = require(SharedPath:WaitForChild("CombatCore"))
    
    local startTime = tick()
    local timeout = 10 -- seconds
    
    while not CombatCore:IsInitialized() and (tick() - startTime) < timeout do
        task.wait(0.5)
        print("Waiting for combat system to initialize...")
    end
    
    if not CombatCore:IsInitialized() then
        warn("Combat system did not initialize within timeout")
        return false
    end
    
    return true
end

-- Get or create a spawn location
local function getSpawnLocation()
    local spawnLocation = workspace:FindFirstChild("SpawnLocation")
    if spawnLocation then
        return spawnLocation.Position + Vector3.new(0, 5, 10) -- Offset from spawn
    else
        return Vector3.new(0, 10, 0) -- Default position
    end
end

-- Spawn test NPCs
local function spawnTestNPCs()
    print("AutoSpawnNPCs: Attempting to spawn test NPCs...")
    
    -- Wait for combat system to be ready
    if not waitForCombatSystem() then
        warn("AutoSpawnNPCs: Combat system not ready, cannot spawn NPCs")
        return
    end
    
    -- Load NPC spawner
    local NPCSpawner = require(TestingPath:WaitForChild("NPCSpawner"))
    
    -- Get spawn position
    local spawnPos = getSpawnLocation()
    
    -- Spawn a variety of NPCs for testing
    print("AutoSpawnNPCs: Spawning test NPCs...")
    
    -- Spawn warriors in a circle
    NPCSpawner:SpawnMultiple("Warrior", spawnPos, 3, 8)
    
    -- Spawn mages in a circle
    NPCSpawner:SpawnMultiple("Mage", spawnPos + Vector3.new(0, 0, 15), 2, 5)
    
    print("AutoSpawnNPCs: Test NPCs spawned successfully")
end

-- Add a slight delay to ensure everything is loaded
task.delay(5, spawnTestNPCs)
