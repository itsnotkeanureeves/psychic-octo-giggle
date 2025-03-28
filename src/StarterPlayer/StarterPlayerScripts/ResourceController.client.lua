-- ResourceController (Client) - Handles player interactions with resource nodes in StarterPlayerScripts
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Get reference to the RemoteEvent for collecting resources
local ResourceEvents = require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("ResourceEventsModule"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Helper function to find the actual resource Model
local function getResourceModel(part)
    local current = part
    while current and current.Parent do
        -- If the parent is "Resources" folder, we found the resource model
        if current.Parent.Name == "Resources" then
            return current
        end
        current = current.Parent
    end
    return nil
end

-- When the player left-clicks, check if they clicked a resource node
mouse.Button1Down:Connect(function()
    local target = mouse.Target  -- object player is pointing at
    if target then
        local resourceModel = getResourceModel(target)
        if resourceModel then
            ResourceEvents.GetCollectResourceEvent():FireServer(resourceModel)
            print("[Client] Sent collect request for resource: " .. resourceModel.Name)
        end
    end
end)
