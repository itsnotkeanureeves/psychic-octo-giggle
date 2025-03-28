--[[
    ClientCombatCore.lua
    
    PURPOSE:
    Client-side module for accessing combat systems.
    Provides a central point for client scripts to access combat functionality.
    
    DESIGN PRINCIPLES:
    - Clean separation between initialization and access
    - Consistent interface with server CombatCore
    - Simple system access pattern
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Module paths
local ReplicatedCombat = ReplicatedStorage:WaitForChild("Combat")
local SharedPath = ReplicatedCombat:WaitForChild("Shared")
local RemoteEvents = ReplicatedStorage:WaitForChild("Combat_RemoteEvents")

-- Create the ClientCombatCore module
local ClientCombatCore = {
    -- Client-side systems
    Systems = {},
    
    -- Initialization state
    Initialized = false
}

-- Get a specific system
function ClientCombatCore:GetSystem(systemName)
    if not self.Initialized then
        warn("ClientCombatCore: Trying to access system before initialization: " .. systemName)
        return nil
    end
    
    return self.Systems[systemName]
end

-- Get all systems
function ClientCombatCore:GetSystems()
    if not self.Initialized then
        warn("ClientCombatCore: Trying to access systems before initialization")
        return nil
    end
    
    return self.Systems
end

-- Initialize all client-side combat systems
function ClientCombatCore:Initialize()
    -- Skip if already initialized
    if self.Initialized then
        return self
    end
    
    print("[ClientCombatCore] Beginning client combat system initialization...")
    
    -- Wait for character
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
    end
    
    -- Load shared modules from ReplicatedStorage
    print("[ClientCombatCore] Loading shared modules...")
    local EventSystem = require(SharedPath:WaitForChild("EventSystem"))
    local Constants = require(SharedPath:WaitForChild("Constants"))
    
    -- Initialize EventSystem first as it's a core dependency
    print("[ClientCombatCore] Initializing client EventSystem...")
    local eventSystem = EventSystem.new()
    
    -- Wait for RemoteEvents
    if not RemoteEvents then
        warn("[ClientCombatCore] Combat_RemoteEvents not found, waiting...")
        RemoteEvents = ReplicatedStorage:WaitForChild("Combat_RemoteEvents", 10)
        if not RemoteEvents then
            error("[ClientCombatCore] Failed to find Combat_RemoteEvents after waiting")
            return self
        end
    end
    
    -- Initialize client systems
    print("[ClientCombatCore] Initializing FeedbackSystem...")
    local FeedbackSystem = require(script.Parent.Parent.Systems.FeedbackSystem)
    local feedbackSystem = FeedbackSystem.new(eventSystem)
    
    -- Initialize AbilityController
    print("[ClientCombatCore] Initializing AbilityController...")
    local AbilityController = require(script.Parent.Parent.Combat_AbilityController)
    local abilityController = AbilityController.new()
    
    -- Initialize the ability controller with RemoteEvents
    abilityController:Initialize(nil, eventSystem)
    
    -- Initialize UI systems
    print("[ClientCombatCore] Initializing AbilityBarUI...")
    local AbilityBarUI = require(script.Parent.Parent.UI.Combat_AbilityBarUI)
    local abilityBarUI = AbilityBarUI.new()
    
    -- Connect UI to controller
    abilityController:SetUIController(abilityBarUI)
    abilityBarUI:Initialize(abilityController)
    
    -- Store all systems in the Systems table
    self.Systems = {
        eventSystem = eventSystem,
        feedbackSystem = feedbackSystem,
        abilityController = abilityController,
        abilityBarUI = abilityBarUI
    }
    
    -- Set up character changed handler
    LocalPlayer.CharacterAdded:Connect(function(character)
        print("[ClientCombatCore] Character added, updating systems...")
        -- Update systems with new character reference if needed
    end)
    
    -- Mark as initialized
    self.Initialized = true
    
    print("[ClientCombatCore] Client combat system initialization complete!")
    
    -- Set an attribute on script for other systems to check
    script:SetAttribute("ClientCombatSystemInitialized", true)
    
    return self
end

-- Check if the system is initialized
function ClientCombatCore:IsInitialized()
    return self.Initialized
end

return ClientCombatCore