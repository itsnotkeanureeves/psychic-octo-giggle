-- ServerConfig (Module) - For Testing Stores tunable configuration values for the game in ReplicatedStorage
local ServerConfig = {}

ServerConfig.Debug = true             -- Debug mode flag (if true, debug logs are enabled)
ServerConfig.SpawnInterval = .6       -- Seconds between resource spawn attempts
ServerConfig.MaxResources  = 20        -- Maximum number of resource nodes present in the world at once

-- Define the region within which resources can spawn (corners of a square area)
ServerConfig.SpawnRegion = {
	min = Vector3.new(-100, 0, -50),   -- bottom-left corner of spawn area (assuming y=0 is ground level)
	max = Vector3.new(-50, 0, 50)      -- top-right corner of spawn area
}

-- Data persistence settings
ServerConfig.UseTestDataStore = true  -- Use test datastore in Studio to avoid impacting production data
ServerConfig.AutoSaveInterval = 300   -- Time between auto-saves in seconds (5 minutes)
ServerConfig.BackupInterval = 900     -- Time between backing up all online players (15 minutes)
ServerConfig.MaxRetries = 5           -- Maximum number of retries for DataStore operations
ServerConfig.RetryDelay = 3           -- Delay between retries in seconds


-- (Additional configuration values can be added here as needed)

return ServerConfig
