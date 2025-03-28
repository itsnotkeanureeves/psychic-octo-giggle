-- RemoteEventInitializer.server.lua (ServerScriptService)
-- Initializes all event modules at server start

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RemoteEventManager = require(ServerScriptService:WaitForChild("RemoteEventManager"))

-- Load all the event modules
local InventoryEventsModule = require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("InventoryEventsModule"))
local ResourceEventsModule = require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("ResourceEventsModule"))

-- Initialize each module's events
print("Initializing RemoteEvents...")

InventoryEventsModule.Initialize()
print("- Initialized Inventory events")

ResourceEventsModule.Initialize()
print("- Initialized Resource events")


-- Log successful initialization of all events
print("\nRemoteEvents initialized successfully. Event structure:")
for category, categoryEvents in pairs(RemoteEventManager.Events) do
    print("  Category: " .. category)
    for name, _ in pairs(categoryEvents) do
        print("    - " .. name)
    end
end

print("\nRemote event initialization complete!")