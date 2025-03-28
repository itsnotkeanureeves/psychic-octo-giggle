-- ResourceSpawner (Server) - Periodically spawns resources in the world in ServerScriptService
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Players             = game:GetService("Players")

-- Require needed modules
local ResourceManager = require(ServerScriptService:WaitForChild("ResourceManager"))
local ResourceTypes   = require(ReplicatedStorage:WaitForChild("ResourceTypes"))
local ServerConfig    = require(ReplicatedStorage:WaitForChild("ServerConfig"))
local DebugUtil       = require(ReplicatedStorage:WaitForChild("DebugUtil"))

-- Ensure a folder exists in workspace for resources (for cleanliness)
local resourcesFolder = workspace:FindFirstChild("Resources") or Instance.new("Folder", workspace)
resourcesFolder.Name = "Resources"

-- Helper: get a random Vector3 within the configured spawn region
local function getRandomPositionInRegion()
    local min = ServerConfig.SpawnRegion.min
    local max = ServerConfig.SpawnRegion.max
    local x = math.random(min.X, max.X)
    local z = math.random(min.Z, max.Z)
    local y = min.Y  -- spawn at the base height (e.g., ground level)
    return Vector3.new(x, y, z)
end

-- Spawn initial resources up to the maximum limit at game start
for i = 1, ServerConfig.MaxResources do
    -- Pick a random resource type from the defined types
    local typeNames = {}
    for typeName, _ in pairs(ResourceTypes.Types) do
        table.insert(typeNames, typeName)
    end
    if #typeNames == 0 then break end  -- No resource types defined
    local resourceTypeName = typeNames[math.random(1, #typeNames)]
    local position = getRandomPositionInRegion()
    ResourceManager.SpawnResource(resourceTypeName, position)
end
DebugUtil:Log("Initial resources spawned: " .. tostring(#ResourceManager:GetActiveResources()))

-- Continuous spawn loop
while true do
    wait(ServerConfig.SpawnInterval)  -- wait defined seconds between spawn attempts
    local activeCount = #ResourceManager:GetActiveResources()
    if activeCount < ServerConfig.MaxResources then
        -- There is room to spawn a new resource
        local typeNames = {}
        for typeName, _ in pairs(ResourceTypes.Types) do
            table.insert(typeNames, typeName)
        end
        if #typeNames > 0 then
            local resourceTypeName = typeNames[math.random(1, #typeNames)]
            local position = getRandomPositionInRegion()
            ResourceManager.SpawnResource(resourceTypeName, position)
        end
    else
        DebugUtil:Log("Max resources reached (" .. ServerConfig.MaxResources .. "); skipping spawn this interval.")
    end
end
