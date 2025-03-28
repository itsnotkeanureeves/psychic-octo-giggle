-- RemoteEventManager.lua (ServerScriptService)
-- Centralized manager for creating and managing RemoteEvents
-- This module handles the creation of RemoteEvents but lets each module define its own events
-- This allows us to keep sensitive functions like granting items on server and inaccessible to clients
-- Current convention is to reference a ReplicatedStorage ModuleScript. For ease, sensitive calculations were included in there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEventManager = {}

-- Store created events for easy access
RemoteEventManager.Events = {}

-- Helper function to create a RemoteEvent if it doesn't exist
function RemoteEventManager.CreateRemoteEvent(name, category)
    -- Check if folder exists
    local categoryFolder = ReplicatedStorage:FindFirstChild(category .. "Events")
    if not categoryFolder then
        categoryFolder = Instance.new("Folder")
        categoryFolder.Name = category .. "Events"
        categoryFolder.Parent = ReplicatedStorage
    end
    
    -- Create or find the RemoteEvent
    local remoteEvent = categoryFolder:FindFirstChild(name)
    if not remoteEvent then
        remoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = name
        remoteEvent.Parent = categoryFolder
    end
    
    -- Store the event for easy retrieval
    if not RemoteEventManager.Events[category] then
        RemoteEventManager.Events[category] = {}
    end
    
    RemoteEventManager.Events[category][name] = remoteEvent
    
    return remoteEvent
end

-- Register an entire module's events at once
function RemoteEventManager.RegisterEvents(moduleEvents, category)
    if not RemoteEventManager.Events[category] then
        RemoteEventManager.Events[category] = {}
    end
    
    -- Create each event in the module's definition
    for eventName, _ in pairs(moduleEvents) do
        moduleEvents[eventName] = RemoteEventManager.CreateRemoteEvent(eventName, category)
        -- Also store in our central registry for reference
        RemoteEventManager.Events[category][eventName] = moduleEvents[eventName]
    end
    
    return moduleEvents
end

-- Helper to get an event
function RemoteEventManager.GetEvent(category, name)
    if RemoteEventManager.Events[category] then
        return RemoteEventManager.Events[category][name]
    end
    
    return nil
end

-- Helper to get all events for a category
function RemoteEventManager.GetCategoryEvents(category)
    return RemoteEventManager.Events[category]
end

return RemoteEventManager