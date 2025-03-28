-- PlayerDataService.server.lua - Initializes the PlayerDataManager and handles player data events
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require modules
local PlayerDataManager = require(ServerScriptService:WaitForChild("PlayerDataManager"))
local DebugUtil = require(ReplicatedStorage:WaitForChild("DebugUtil"))

-- Setup DataStore events (for manual save/load if needed)
local function setupDataEvents()
    -- Create a folder for data-related RemoteEvents if it doesn't exist
    local dataEvents = ReplicatedStorage:FindFirstChild("DataEvents")
    if not dataEvents then
        dataEvents = Instance.new("Folder")
        dataEvents.Name = "DataEvents"
        dataEvents.Parent = ReplicatedStorage
        
        -- Request manual save (could be triggered by player, e.g., "Save and Exit" button)
        local saveEvent = Instance.new("RemoteEvent")
        saveEvent.Name = "RequestSave"
        saveEvent.Parent = dataEvents
    end
    
    -- Connect manual save request event
    local saveEvent = dataEvents:WaitForChild("RequestSave")
    saveEvent.OnServerEvent:Connect(function(player)
        DebugUtil:Log("Manual save requested by " .. player.Name)
        local success = PlayerDataManager:SaveData(player, true)
        if success then
            -- Optionally notify the player of successful save
        end
    end)
    
    return dataEvents
end

-- Initialize everything
local function init()
    -- Setup RemoteEvents for data operations
    setupDataEvents()
    
    -- Initialize PlayerDataManager
    --PlayerDataManager:Initialize()
    --DebugUtil:Log("PlayerDataService initialized")
end

-- Start everything
init()