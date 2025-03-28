-- ResourceEvents (Server) - Sets up and handles remote events for resource interactions in ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Updated: Use the new module from ServerScriptService
local ResourceEventsModule = require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("ResourceEventsModule"))
local ResourceManager = require(ServerScriptService:WaitForChild("ResourceManager"))
local DebugUtil = require(ReplicatedStorage:WaitForChild("DebugUtil"))

-- Get the ResourceCollect event
local CollectResourceEvent = ResourceEventsModule.GetCollectResourceEvent()

-- Connect the remote event for collecting a resource node
CollectResourceEvent.OnServerEvent:Connect(function(player, resourceInstance)
    DebugUtil:Log("CollectResource event received from " .. player.Name)
    ResourceManager.CollectResource(player, resourceInstance)
end)