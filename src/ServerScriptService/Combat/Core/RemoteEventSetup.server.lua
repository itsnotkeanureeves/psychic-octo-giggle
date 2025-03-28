--[[
    RemoteEventSetup.server.lua
    
    PURPOSE:
    Sets up all required RemoteEvents for client-server communication in the combat system.
    Ensures all necessary events exist in ReplicatedStorage for the combat system to function.
    
    IMPORTANT: This script must run BEFORE CombatCoreSetup.server.lua
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- List of required RemoteEvents
local REQUIRED_EVENTS = {
    "Combat_AbilityRequest",      -- Client requests ability activation
    "Combat_AbilityResponse",     -- Server response to ability request
    "Combat_AbilityExecution",    -- Notifies clients about ability execution
    "Combat_AbilityCast",         -- Updates clients on casting status
    "Combat_ConditionUpdate",     -- Syncs condition state to client
    "Combat_DamageEvent",         -- Notifies clients about damage events
    "Combat_StatUpdate",          -- Syncs stat changes to clients
    "Combat_PlayerAbilities",     -- Sends abilities to client
    "Combat_ChainAbilityUpdate",  -- Phase 4: Notifies clients about chain abilities
    "Combat_CastBarUpdate"        -- Phase 4: Updates cast bar progress
}

-- Create folder for combat remote events
local function createRemoteEventsFolder()
    local folder = ReplicatedStorage:FindFirstChild("Combat_RemoteEvents")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "Combat_RemoteEvents"
        folder.Parent = ReplicatedStorage
        print("[RemoteEventSetup] Created Combat_RemoteEvents folder")
    end
    return folder
end

-- Create remote events
local function createRemoteEvents(folder)
    for _, eventName in ipairs(REQUIRED_EVENTS) do
        local event = folder:FindFirstChild(eventName)
        if not event then
            event = Instance.new("RemoteEvent")
            event.Name = eventName
            event.Parent = folder
            print("[RemoteEventSetup] Created RemoteEvent: " .. eventName)
        end
    end
end

-- Set up folder and events
local remoteEventsFolder = createRemoteEventsFolder()
createRemoteEvents(remoteEventsFolder)

print("[RemoteEventSetup] RemoteEvents setup complete")

-- Signal that RemoteEvents are ready for use
local scriptObj = script
scriptObj:SetAttribute("RemoteEventsInitialized", true)
