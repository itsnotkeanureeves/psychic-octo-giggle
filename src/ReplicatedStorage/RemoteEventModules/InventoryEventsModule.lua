-- InventoryEventsModule.lua (ReplicatedStorage)
-- Creates and provides access to inventory-related RemoteEvents
--[[
Example:
local InventoryEventsModule = require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("InventoryEventsModule"))
InventoryEventsModule.GetSetActiveToolEvent().OnClientEvent:Connect
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryEventsModule = {}

-- Create and store events
local events = {}

-- Helper function to create a RemoteEvent if it doesn't exist
local function createRemoteEvent(name)
    -- Check if folder exists
    local categoryFolder = ReplicatedStorage:FindFirstChild("InventoryEvents")
    if not categoryFolder then
        categoryFolder = Instance.new("Folder")
        categoryFolder.Name = "InventoryEvents"
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

-- Initialize all inventory events
function InventoryEventsModule.Initialize()
    -- Create inventory events
    events.InventoryUpdate = createRemoteEvent("InventoryUpdate")
    events.SetActiveTool = createRemoteEvent("SetActiveTool")
    events.ItemAdded = createRemoteEvent("ItemAdded")
    
    return events
end

-- Get all events (ensures events are initialized)
function InventoryEventsModule.GetEvents()
    -- Initialize if not done already
    if not events.InventoryUpdate then
        InventoryEventsModule.Initialize()
    end
    return events
end

-- Accessors for specific events
function InventoryEventsModule.GetInventoryUpdateEvent()
    if not events.InventoryUpdate then
        InventoryEventsModule.Initialize()
    end
    return events.InventoryUpdate
end

function InventoryEventsModule.GetSetActiveToolEvent()
    if not events.SetActiveTool then
        InventoryEventsModule.Initialize()
    end
    return events.SetActiveTool
end

function InventoryEventsModule.GetItemAddedEvent()
    if not events.ItemAdded then
        InventoryEventsModule.Initialize()
    end
    return events.ItemAdded
end

-- Initialize events when this module is required
InventoryEventsModule.Initialize()

return InventoryEventsModule