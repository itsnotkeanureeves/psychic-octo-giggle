--[[
    ClientCombatCoreSetup.client.lua
    
    PURPOSE:
    Central initialization point for client-side combat systems.
    Initializes all client subsystems and establishes connections between them.
    
    DESIGN PRINCIPLES:
    - No global state (_G variables)
    - Clear dependency injection
    - Explicit system initialization order
    - Clean event handling
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Service paths
local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local SystemsPath = script.Parent.Parent:WaitForChild("Systems")
local ControllersPath = script.Parent.Parent:WaitForChild("Controllers")
local UIPath = script.Parent.Parent:WaitForChild("UI")

-- Logging utilities
local function log(message)
    print("[ClientCombatCore] " .. message)
end

local function warn(message)
    warn("[ClientCombatCore] " .. message)
end

local function logError(message)
    error("[ClientCombatCore] " .. message)
end

-- Create a CombatCore object
local ClientCombatCore = {}

-- Initialize all client combat subsystems
function ClientCombatCore:Initialize()
    log("Beginning client combat system initialization...")
    
    -- Wait for character
    if not LocalPlayer.Character then
        log("Waiting for character...")
        LocalPlayer.CharacterAdded:Wait()
    end
    
    -- Load shared modules from ReplicatedStorage
    log("Loading shared modules...")
    local EventSystem = require(SharedPath:WaitForChild("EventSystem"))
    local Constants = require(SharedPath:WaitForChild("Constants"))
    
    -- Initialize EventSystem first as it's a core dependency
    log("Initializing client EventSystem...")
    local eventSystem = EventSystem.new()
    
    -- Wait for RemoteEvents folder with improved timeout handling
    log("Waiting for RemoteEvents...")
    local startTime = tick()
    local maxWaitTime = 10 -- seconds
    
    local remoteEvents
    repeat
        remoteEvents = ReplicatedStorage:FindFirstChild("Combat_RemoteEvents")
        if not remoteEvents then
            task.wait(0.1)
        end
    until remoteEvents or (tick() - startTime > maxWaitTime)
    
    if not remoteEvents then
        warn("RemoteEvents folder not found after " .. maxWaitTime .. " seconds, some functionality may be limited")
    end
    
    -- Initialize FeedbackSystem
    log("Initializing FeedbackSystem...")
    local FeedbackSystem = require(SystemsPath:WaitForChild("FeedbackSystem"))
    local feedbackSystem = FeedbackSystem.new(eventSystem)
    
    -- Initialize AbilityController
    log("Initializing AbilityController...")
    local AbilityController = require(ControllersPath:WaitForChild("AbilityController"))
    local abilityController = AbilityController.new()
    
    -- Initialize AbilityBarUI
    log("Initializing AbilityBarUI...")
    local AbilityBarUI = require(UIPath:WaitForChild("AbilityBarUI"))
    local abilityBarUI = AbilityBarUI.new({})
    
    -- Phase 4: Initialize CastBarUI
    log("Initializing CastBarUI...")
    local CastBarUI = require(UIPath:WaitForChild("CastBarUI"))
    local castBarUI = CastBarUI.new(eventSystem)
    
    -- Connect UI to controller
    abilityController:SetUIController(abilityBarUI)
    
    -- Initialize AbilityController after UI instances are created
    abilityController:Initialize(nil, eventSystem)
    
    -- Create service registry for dependency injection
    local services = {
        eventSystem = eventSystem,
        feedbackSystem = feedbackSystem,
        abilityController = abilityController,
        abilityBarUI = abilityBarUI,
        castBarUI = castBarUI -- Phase 4: Add CastBarUI to services
    }
    
    -- Export the services for other client modules
    self.Services = services
    
    -- Listen for character changes
    LocalPlayer.CharacterAdded:Connect(function(character)
        log("Character added, updating systems...")
        -- Update systems with new character reference
    end)
    
    -- PHASE 4: Ensure critical remote events exist
    if remoteEvents then
        -- Check critical Phase 4 remote events
        local criticalEvents = {
            "Combat_AbilityExecution",
            "Combat_CastBarUpdate",
            "Combat_ChainAbilityUpdate"
        }
        
        for _, eventName in ipairs(criticalEvents) do
            if not remoteEvents:FindFirstChild(eventName) then
                warn("Critical remote event missing: " .. eventName)
            end
        end
        
        -- PHASE 4: Explicit connection to AbilityExecution event for chain info
        local abilityExecutionEvent = remoteEvents:WaitForChild("Combat_AbilityExecution", 2)
        if abilityExecutionEvent then
            log("Connected to Combat_AbilityExecution event")
            abilityExecutionEvent.OnClientEvent:Connect(function(entityId, abilityId, targetPosition, targetDirection, targets, chainInfo)
                -- Process chain info if provided
                if chainInfo then
                    log("Received chain info from execution event for ability: " .. abilityId)
                    abilityController:HandleChainInfo(chainInfo)
                end
            end)
        else
            warn("Failed to connect to Combat_AbilityExecution event")
        end
        
        -- Listen for ability updates from server
        local abilityUpdateEvent = remoteEvents:WaitForChild("Combat_PlayerAbilities")
        abilityUpdateEvent.OnClientEvent:Connect(function(abilities)
            log("Received ability update from server")
            self:HandleAbilityUpdate(abilities, abilityController)
        end)
        
        -- Request abilities from server (this will trigger when the server responds)
        log("Requesting abilities from server")
        abilityUpdateEvent:FireServer("REQUEST_ABILITIES")
    else
        warn("Cannot connect to remote events - RemoteEvents folder not found")
    end
    
    -- Mark the system as initialized
    log("Client combat system initialization complete!")
    self.IsInitialized = true
    
    -- Set an attribute on script for other systems to check
    script:SetAttribute("ClientCombatSystemInitialized", true)
    
    return self
end

-- Handle ability update from server
function ClientCombatCore:HandleAbilityUpdate(abilities, abilityController)
    if not abilities or #abilities == 0 then
        log("No abilities received from server")
        return
    end
    
    log("Received " .. #abilities .. " abilities from server")
    
    -- Update controller with abilities
    abilityController:UpdateAbilities(abilities)
    
    -- Assign abilities to slots
    local slotAssignments = {
        [1] = "FIREBALL",
        [2] = "HEAL",
        [3] = "SLASH",
        [4] = "WHIRLWIND",
        [5] = "TRIPLE_SLASH" -- Add TRIPLE_SLASH for chain ability testing
    }
    
    -- Find and assign abilities to slots
    for slot, abilityId in pairs(slotAssignments) do
        -- Check if this ability exists in the received abilities
        for _, ability in ipairs(abilities) do
            if ability.id == abilityId then
                abilityController:AssignAbilityToSlot(slot, abilityId)
                log("Assigned " .. abilityId .. " to slot " .. slot)
                break
            end
        end
    end
    
    log("Ability assignment complete")
end

-- Get a specific service
function ClientCombatCore:GetService(serviceName)
    if not self.Services or not self.Services[serviceName] then
        return nil
    end
    
    return self.Services[serviceName]
end

-- Start the initialization process
local clientCombatCore = ClientCombatCore:Initialize()

-- Expose the core for other client scripts
return clientCombatCore