--[[
    CombatCoreSetup.server.lua
    
    Server-side initialization script for the combat system.
    Initializes the CombatCore module and sets up all necessary game objects.
    
    IMPORTANT: This script must run AFTER RemoteEventSetup.server.lua
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Service paths
local CombatPath = ServerScriptService:WaitForChild("Combat")
local CorePath = CombatPath:WaitForChild("Core")
local SystemsPath = CombatPath:WaitForChild("Systems")
local ReplicatedCombatPath = ReplicatedStorage:WaitForChild("Combat")
local SharedPath = ReplicatedCombatPath:WaitForChild("Shared")

-- Logging utilities
local function log(message)
    print("[CombatCoreSetup] " .. message)
end

local function warn(message)
    warn("[CombatCoreSetup] " .. message)
end

local function logError(message)
    error("[CombatCoreSetup] " .. message)
end

-- Ensure RemoteEventSetup has run
local function waitForRemoteEvents()
    log("Waiting for RemoteEventSetup to complete...")
    
    -- Get the RemoteEventSetup script
    local remoteEventSetupScript = CorePath:WaitForChild("RemoteEventSetup")
    
    -- Wait for the initialization flag
    local maxWaitTime = 10 -- seconds
    local startTime = os.clock()
    
    while not remoteEventSetupScript:GetAttribute("RemoteEventsInitialized") do
        if os.clock() - startTime > maxWaitTime then
            logError("Timed out waiting for RemoteEventSetup")
            return false
        end
        task.wait(0.1)
    end
    
    -- Wait for the RemoteEvents folder
    local remoteEventsFolder = ReplicatedStorage:WaitForChild("Combat_RemoteEvents", 5)
    if not remoteEventsFolder then
        logError("RemoteEvents folder not found")
        return false
    end
    
    -- Verify all required events exist
    local requiredEvents = {
        "Combat_AbilityRequest",
        "Combat_AbilityResponse",
        "Combat_AbilityExecution",
        "Combat_AbilityCast",
        "Combat_ConditionUpdate",
        "Combat_DamageEvent",
        "Combat_StatUpdate",
        "Combat_PlayerAbilities",
        "Combat_ChainAbilityUpdate",  -- Phase 4
        "Combat_CastBarUpdate"        -- Phase 4
    }
    
    for _, eventName in ipairs(requiredEvents) do
        if not remoteEventsFolder:FindFirstChild(eventName) then
            logError("Required RemoteEvent not found: " .. eventName)
            return false
        end
    end
    
    log("All RemoteEvents verified")
    return true
end

-- Get ability details for client
local function getAbilityDetailsForClient(abilitySystem, entityId)
    local abilities = {}
    
    -- Get granted abilities for the entity
    local entityAbilities = abilitySystem.EntityAbilities[entityId] or {}
    
    -- For each granted ability, get the full definition
    for _, abilityId in ipairs(entityAbilities) do
        local abilityDef = abilitySystem:GetAbilityDefinition(abilityId)
        if abilityDef then
            -- Create a simplified version with only what the client needs
            table.insert(abilities, {
                id = abilityDef.id,
                name = abilityDef.name,
                description = abilityDef.description,
                cooldown = abilityDef.cooldown,
                castTime = abilityDef.castTime,
                icon = abilityDef.icon,
                category = abilityDef.category
            })
        end
    end
    
    return abilities
end

-- Send abilities to player
local function sendAbilitiesToPlayer(player, abilitySystem, entitySystem)
    local entityId = entitySystem:GetEntityId(player)
    if not entityId then return end
    
    local playerAbilities = getAbilityDetailsForClient(abilitySystem, entityId)
    local abilityEvent = ReplicatedStorage:WaitForChild("Combat_RemoteEvents"):WaitForChild("Combat_PlayerAbilities")
    
    abilityEvent:FireClient(player, playerAbilities)
    log("Sent abilities to player: " .. player.Name)
end

-- Handle player added
local function handlePlayerAdded(player, entitySystem, abilitySystem)
    log("Player added: " .. player.Name)
    
    -- Register the player with entity system
    local entityId = entitySystem:RegisterPlayer(player)
    
    if not entityId then
        warn("Failed to register player: " .. player.Name)
        return
    end
    
    log("Registered player as entity: " .. entityId)
    
    -- Auto-grant basic abilities to players
    local abilities = {
        "SLASH",
        "FIREBALL",
        "HEAL",
        "TRIPLE_SLASH",
        "WHIRLWIND"
    }
    
    for _, abilityId in ipairs(abilities) do
        local success = abilitySystem:GrantAbility(entityId, abilityId)
        if success then
            log("Granted ability " .. abilityId .. " to player: " .. player.Name)
        else
            warn("Failed to grant ability " .. abilityId .. " to player: " .. player.Name)
            
            -- Check if ability exists
            if not abilitySystem:GetAbilityDefinition(abilityId) then
                warn("Ability definition not found: " .. abilityId)
            end
        end
    end
    
    -- Send abilities to player
    sendAbilitiesToPlayer(player, abilitySystem, entitySystem)
end

-- Main initialization function
local function initializeCombatSystem()
    log("Starting combat system initialization...")
    
    -- Wait for RemoteEvents to be fully initialized
    if not waitForRemoteEvents() then
        logError("Failed to initialize combat system due to missing RemoteEvents")
        return
    end
    
    -- Load NPCAdapter
    local NPCAdapter = require(SystemsPath:WaitForChild("NPCAdapter"))
    
    -- Load the CombatCore module
    local CombatCore = require(SharedPath:WaitForChild("CombatCore"))
    
    -- IMPORTANT: Load the DefinitionLoader first
    log("Loading ability and condition definitions...")
    local DefinitionLoader = require(CorePath:WaitForChild("DefinitionLoader"))
    
    -- Initialize the core systems
    log("Initializing CombatCore module...")
    CombatCore:Initialize()
    
    -- Now load all definitions into the initialized systems
    DefinitionLoader:LoadAllDefinitions(CombatCore)
    
    -- Get initialized systems
    local systems = CombatCore:GetSystems()
    local entitySystem = systems.entitySystem
    local abilitySystem = systems.abilitySystem
    local conditionSystem = systems.conditionSystem
    local statSystem = systems.statSystem
    local eventSystem = systems.eventSystem
    
    if not entitySystem then
        logError("EntitySystem not initialized!")
        return
    end
    
    if not abilitySystem then
        logError("AbilitySystem not initialized!")
        return
    end
    
    -- Initialize NPCAdapter
    log("Initializing NPCAdapter...")
    local npcAdapter = NPCAdapter.new(entitySystem, eventSystem)
    
    -- Add the npcAdapter to the systems table directly
    systems.npcAdapter = npcAdapter
    
    -- Connect the NPCAdapter to the EntitySystem
    entitySystem:SetNPCAdapter(npcAdapter)
    log("NPCAdapter connected to EntitySystem")
    
    -- Print all registered abilities
    abilitySystem:DebugPrintAbilities()
    
    -- Set up player added/removed handlers
    Players.PlayerAdded:Connect(function(player)
        handlePlayerAdded(player, entitySystem, abilitySystem)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        local entityId = entitySystem:GetEntityId(player)
        if entityId then
            -- Clean up any abilities, conditions, etc.
            if abilitySystem then abilitySystem:CleanupEntityData(entityId) end
            if conditionSystem then conditionSystem:CleanupEntityConditions(entityId) end
            if statSystem then statSystem:CleanupEntityStats(entityId) end
            
            -- Finally unregister the entity
            entitySystem:UnregisterPlayer(player)
            log("Unregistered player: " .. player.Name)
        end
    end)
    
    -- Handle ability update requests from clients
    local abilityEvent = ReplicatedStorage:WaitForChild("Combat_RemoteEvents"):WaitForChild("Combat_PlayerAbilities")
    abilityEvent.OnServerEvent:Connect(function(player, request)
        if request == "REQUEST_ABILITIES" then
            sendAbilitiesToPlayer(player, abilitySystem, entitySystem)
        end
    end)
    
    -- Register existing players
    for _, player in ipairs(Players:GetPlayers()) do
        handlePlayerAdded(player, entitySystem, abilitySystem)
    end
    
    -- Set an attribute on script for backward compatibility
    script:SetAttribute("CombatSystemInitialized", true)
    
    log("Combat system initialization complete!")
end

-- Start the initialization process
initializeCombatSystem()
