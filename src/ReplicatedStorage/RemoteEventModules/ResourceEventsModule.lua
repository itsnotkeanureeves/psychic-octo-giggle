-- ResourceEventsModule.lua (ReplicatedStorage)
-- Creates and provides access to resource-related RemoteEvents
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResourceEventsModule = {}

-- Create and store events
local events = {}

-- Helper function to create a RemoteEvent if it doesn't exist
local function createRemoteEvent(name)
    -- Check if folder exists
    local categoryFolder = ReplicatedStorage:FindFirstChild("ResourceEvents")
    if not categoryFolder then
        categoryFolder = Instance.new("Folder")
        categoryFolder.Name = "ResourceEvents"
        categoryFolder.Parent = ReplicatedStorage
    end
    
    -- Create or find the RemoteEvent
    local remoteEvent = categoryFolder:FindFirstChild(name)
    if not remoteEvent then
        remoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = name
        remoteEvent.Parent = categoryFolder
    end
    
    -- Store in our events table
    events[name] = remoteEvent
    
    return remoteEvent
end

-- Initialize all resource events
function ResourceEventsModule.Initialize()
    -- Create resource events
    events.CollectResource = createRemoteEvent("CollectResource")
    
    return events
end

-- Get all events (ensures events are initialized)
function ResourceEventsModule.GetEvents()
    -- Initialize if not done already
    if not events.CollectResource then
        ResourceEventsModule.Initialize()
    end
    return events
end

-- Accessor for the CollectResource event
function ResourceEventsModule.GetCollectResourceEvent()
    if not events.CollectResource then
        ResourceEventsModule.Initialize()
    end
    return events.CollectResource
end

-- Initialize events when this module is required
ResourceEventsModule.Initialize()

return ResourceEventsModule