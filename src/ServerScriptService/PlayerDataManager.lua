-- PlayerDataManager (ModuleScript) - Centralized system for saving and loading player data in ServerScriptService
-- Handles data persistence for player location, health, inventory, and future game data

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- Import required modules
local DebugUtil = require(ReplicatedStorage:WaitForChild("DebugUtil"))
local ServerConfig = require(ReplicatedStorage:WaitForChild("ServerConfig"))
local InventoryManager = require(ServerScriptService:WaitForChild("InventoryManager"))

-- Constants
local AUTO_SAVE_INTERVAL = 300 -- Autosave every 5 minutes (configurable)
local DATASTORE_SCOPE = "PlayerData_v1" -- Version in scope name for migrations
local MAX_RETRIES = 5
local RETRY_DELAY = 3

-- Create a scope for different game modes if needed (e.g., testing vs production)
local DATA_SCOPE = (RunService:IsStudio() and ServerConfig.UseTestDataStore) and "Test" or "Production"

-- Initialize datastores with appropriate scope
local PlayerDataStore = DataStoreService:GetDataStore(DATASTORE_SCOPE .. "_" .. DATA_SCOPE)

-- Session locks to prevent multiple saves of the same player data
local SessionLocks = {}

-- Cache player data in memory to minimize datastore requests
local PlayerDataCache = {}

-- Default data structure for new players
local function getDefaultData()
    return {
        -- Last save timestamp
        lastSaved = os.time(),
        
        -- Character data
        character = {
            position = {x = 0, y = 10, z = 0}, -- Default spawn position
            health = 100,
            maxHealth = 100,
        },
        
        -- Game progression
        stats = {
            experience = 0,
            level = 1,
            skillPoints = 0,
            currency = {
                gold = 0,
                premium = 0
            },
            achievements = {},
            questProgress = {},
        },
        
        -- Specific game systems (inventory handled separately for now, but format prepared)
        inventory = {
            -- Structure will be filled from InventoryManager
            version = 1,
            items = {},
            tools = {},
            activeTools = {}
        },
        
        -- Player preferences and settings
        settings = {
            uiScale = 1,
            soundVolume = 1,
            musicVolume = 1,
        },
        
        -- Analytics and metadata
        metadata = {
            createDate = os.time(),
            totalPlayTime = 0,
            lastLogin = os.time(),
            loginCount = 1
        }
    }
end

local PlayerDataManager = {}

-- Utility: Deep copy a table to prevent reference issues
local function deepCopy(original)
    -- Return non-table values directly
    if type(original) ~= "table" then
        return original
    end
    
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- Helper: Update a table with values from another table (recursive)
local function recursiveUpdate(target, source)
    -- Verify both are tables
    if type(target) ~= "table" or type(source) ~= "table" then
        if type(source) == "table" then
            return deepCopy(source)
        else
            return source
        end
    end
    
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            recursiveUpdate(target[k], v)
        else
            target[k] = type(v) == "table" and deepCopy(v) or v
        end
    end
    return target
end

-- Sanitize a table to ensure it's DataStore-compatible (handles mixed arrays)
local function sanitizeForDataStore(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    
    -- Detect circular references
    local seen = {}
    local function sanitize(t, path)
        if type(t) ~= "table" then
            return t
        end
        
        -- Check for circular references
        if seen[t] then
            DebugUtil:Log("WARNING: Circular reference detected at " .. path)
            return nil
        end
        seen[t] = true
        
        -- Convert to dictionary format for safety - DataStore has issues with mixed arrays
        local result = {}
        
        -- Always store as dictionary with string keys for maximum compatibility
        for k, v in pairs(t) do
            local key
            if type(k) == "string" then
                key = k
            else
                -- Convert all non-string keys to string format
                key = "k_" .. tostring(k)
            end
            
            -- Recursively sanitize nested tables
            if type(v) == "table" then
                result[key] = sanitize(v, path .. "." .. tostring(k))
            elseif type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "thread" then
                -- Only include serializable types
                result[key] = v
            end
        end
        
        return result
    end
    
    return sanitize(tbl, "root")
end

-- Try to perform a datastore operation with retries
local function retryOperation(operation, ...)
    local success, result
    local attempts = 0
    
    repeat
        attempts = attempts + 1
        success, result = pcall(operation, ...)
        
        if not success then
            DebugUtil:Log("DataStore operation failed (" .. attempts .. "/" .. MAX_RETRIES .. "): " .. tostring(result))
            if attempts < MAX_RETRIES then
                task.wait(RETRY_DELAY)
            end
        end
    until success or attempts >= MAX_RETRIES
    
    return success, result
end

-- Update playerData with current character information before saving
local function updateCharacterData(player, playerData)
    -- Ensure character data structure exists
    if type(playerData.character) ~= "table" then
        playerData.character = {
            position = {x = 0, y = 10, z = 0},
            health = 100,
            maxHealth = 100
        }
    end

    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") then
        local position = character.HumanoidRootPart.Position
        playerData.character.position = {
            x = position.X,
            y = position.Y,
            z = position.Z
        }
        
        playerData.character.health = character.Humanoid.Health
        playerData.character.maxHealth = character.Humanoid.MaxHealth
    end
end

-- Update the inventory data from the InventoryManager before saving
local function updateInventoryData(player, playerData)
    local inventory = InventoryManager:GetInventory(player)
    if not inventory then
        DebugUtil:Log("No inventory found for " .. player.Name .. " when updating inventory data")
        return
    end
    
    -- Initialize inventory data structure if needed
    if type(playerData.inventory) ~= "table" then
        playerData.inventory = {
            version = 1,
            items = {},
            tools = {},
            activeTools = {}
        }
    end
    
    -- Deep copy items which have simple structure
    if type(inventory.items) == "table" then
        playerData.inventory.items = {}
        for itemName, amount in pairs(inventory.items) do
            if type(itemName) == "string" then
                playerData.inventory.items[itemName] = amount
            end
        end
    else
        playerData.inventory.items = {}
    end
    
    -- Special handling for tools - convert to array of individual tools with properties
    -- This avoids the mixed array/dictionary issues
    if type(inventory.tools) == "table" then
        -- Convert to array format for better DataStore compatibility
        playerData.inventory.tools = {}
        local toolIndex = 0
        
        for toolId, toolData in pairs(inventory.tools) do
            if type(toolData) == "table" then
                toolIndex = toolIndex + 1
                local toolEntry = {
                    toolId = toolId,
                    baseName = toolData.baseName or "Unknown Tool",
                    displayName = toolData.displayName or toolData.baseName or "Unknown Tool",
                    toolType = toolData.toolType or "unknown",
                    enhancementLevel = toolData.enhancementLevel or 0,
                    durability = toolData.durability or 100,
                    -- Add other essential properties
                }
                
                -- Store as numeric index for clean array structure
                playerData.inventory.tools[toolIndex] = toolEntry
            end
        end
    else
        playerData.inventory.tools = {}
    end
    
    -- Handle activeTools mapping - store as key-value pairs
    if type(inventory.activeTools) == "table" then
        playerData.inventory.activeTools = {}
        for toolType, toolId in pairs(inventory.activeTools) do
            if type(toolType) == "string" then
                playerData.inventory.activeTools[toolType] = toolId
            end
        end
    else
        playerData.inventory.activeTools = {}
    end
    
    DebugUtil:Log("Updated inventory data for " .. player.Name)
end

-- Convert sanitized keys back to their original form
local function desanitizeDataStore(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    
    -- First check if this is a flattened emergency table
    if tbl.emergency == true then
        DebugUtil:Log("WARNING: Loading from emergency saved data")
        return getDefaultData() -- Return a fresh default data structure
    end
    
    local result = {}
    
    for k, v in pairs(tbl) do
        if type(k) == "string" and k:sub(1, 2) == "k_" then
            -- Convert string keys back to numbers if they were numeric
            local numKey = tonumber(k:sub(3))
            if numKey then
                if type(v) == "table" then
                    result[numKey] = desanitizeDataStore(v)
                else
                    result[numKey] = v
                end
            else
                if type(v) == "table" then
                    result[k] = desanitizeDataStore(v)
                else
                    result[k] = v
                end
            end
        else
            if type(v) == "table" then
                result[k] = desanitizeDataStore(v)
            else
                result[k] = v
            end
        end
    end
    
    return result
end

-- Load player data from datastore
function PlayerDataManager:LoadData(player)
    if PlayerDataCache[player.UserId] then
        DebugUtil:Log("Player data for " .. player.Name .. " already loaded from cache")
        return PlayerDataCache[player.UserId]
    end
    
    -- Generate a unique session lock key
    SessionLocks[player.UserId] = os.time()
    
    -- Load data from datastore with retries
    local success, result = retryOperation(function()
        local loadSuccess, loadResult = pcall(function()
            return PlayerDataStore:GetAsync("Player_" .. player.UserId)
        end)
        
        if not loadSuccess then
            DebugUtil:Log("DataStore load error: " .. tostring(loadResult))
            return false, loadResult
        end
        
        return loadSuccess, loadResult
    end)
    
    -- Initialize with default data if load failed or no data exists
    local playerData = getDefaultData()
    
    -- Check if we have valid data from the datastore 
    -- We should only try to merge the result if it's a table
    if success and result and type(result) == "table" then
        -- Successfully loaded data, process it back from sanitized form
        local desanitizedData = desanitizeDataStore(result)
        
        -- Update the default data with loaded values
        playerData = recursiveUpdate(playerData, desanitizedData)
        
        -- These operations were causing the error - add proper type checking
        if type(playerData) == "table" and type(playerData.metadata) == "table" then
            playerData.metadata.lastLogin = os.time()
            playerData.metadata.loginCount = (playerData.metadata.loginCount or 0) + 1
        else
            -- Data structure is corrupted, recreate metadata
            playerData.metadata = {
                createDate = os.time(),
                lastLogin = os.time(),
                loginCount = 1,
                totalPlayTime = 0
            }
        end
        
        DebugUtil:Log("Successfully loaded data for " .. player.Name)
    else
        -- New player or load failed, use default data
        if type(playerData) == "table" and type(playerData.metadata) == "table" then
            playerData.metadata.createDate = os.time()
            playerData.metadata.lastLogin = os.time()
            playerData.metadata.loginCount = 1
        else
            -- Ensure metadata exists
            playerData.metadata = {
                createDate = os.time(),
                lastLogin = os.time(),
                loginCount = 1,
                totalPlayTime = 0
            }
        end
        
        DebugUtil:Log("Using default data for " .. player.Name .. (success and " (no saved data)" or " (load failed)"))
    end
    
    -- Double check that playerData is valid before caching
    if type(playerData) ~= "table" then
        DebugUtil:Log("WARNING: playerData is not a table, creating new default data")
        playerData = getDefaultData()
    end
    
    -- Cache the data
    PlayerDataCache[player.UserId] = playerData
    
    return playerData
end

-- Save player data to datastore
function PlayerDataManager:SaveData(player, immediate)
    local userId = player.UserId
    
    -- Check if we have data to save
    if not PlayerDataCache[userId] then
        DebugUtil:Log("No data in cache to save for " .. player.Name)
        return false
    end
    
    -- Get the data and update with latest information
    local playerData = deepCopy(PlayerDataCache[userId])
    
    -- Verify that playerData is a table before proceeding
    if type(playerData) ~= "table" then
        DebugUtil:Log("ERROR: Invalid playerData (not a table) for " .. player.Name)
        -- Recreate a valid data structure
        playerData = getDefaultData()
        PlayerDataCache[userId] = playerData
    end
    
    -- Update character position and health
    updateCharacterData(player, playerData)
    
    -- Update inventory data 
    updateInventoryData(player, playerData)
    
    -- Update metadata with safe type checking
    if type(playerData.metadata) == "table" then
        playerData.metadata.totalPlayTime = (playerData.metadata.totalPlayTime or 0) + 
            (os.time() - (playerData.lastSaved or os.time()))
    else
        -- Reinitialize metadata if it's missing
        playerData.metadata = {
            createDate = os.time(),
            lastLogin = os.time(),
            loginCount = 1,
            totalPlayTime = 0
        }
    end
    
    playerData.lastSaved = os.time()
    
    -- Final sanitization pass to ensure DataStore compatibility
    local sanitizedData = sanitizeForDataStore(playerData)
    
    -- Ensure nothing remained that could cause serialization issues
    local success = false
    local errorMessage = nil
    
    -- First, verify if the data can be encoded as JSON (which is what DataStoreService uses)
    local jsonSuccess, jsonResult = pcall(function()
        return game:GetService("HttpService"):JSONEncode(sanitizedData)
    end)
    
    if not jsonSuccess then
        DebugUtil:Log("WARNING: JSON encoding failed: " .. tostring(jsonResult))
        DebugUtil:Log("Forcing dictionary-only format conversion...")
        
        -- Force a more aggressive sanitization - convert everything to simple key/value pairs
        local forceSanitized = {}
        local function flattenTable(t, prefix)
            for k, v in pairs(t) do
                local key = prefix .. tostring(k)
                if type(v) == "table" then
                    flattenTable(v, key .. "_")
                elseif type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "thread" then
                    forceSanitized[key] = v
                end
            end
        end
        flattenTable(sanitizedData, "")
        sanitizedData = forceSanitized
    end
    
    -- Now try to save to datastore with retries
    success, errorMessage = retryOperation(function()
        -- Use pcall to catch any serialization errors and provide better debugging
        local saveSuccess, saveError = pcall(function()
            PlayerDataStore:SetAsync("Player_" .. userId, sanitizedData, {sessionLock = SessionLocks[userId]})
        end)
        
        if not saveSuccess then
            -- More detailed error logging
            DebugUtil:Log("DataStore serialization error: " .. tostring(saveError))
            
            -- If it's specifically the array casting error, try a last-resort approach
            if tostring(saveError):find("Unable to cast to Array") then
                DebugUtil:Log("Array casting error detected, attempting emergency fallback save...")
                
                -- Create a minimal "safe" version with just the essential data
                local emergencyData = {
                    lastSaved = os.time(),
                    emergency = true,
                    playerName = player.Name,
                    character = {
                        health = 100,
                        position = {x = 0, y = 10, z = 0}
                    },
                    inventory = {
                        items = {},
                        version = 1
                    }
                }
                
                -- Try to save just the player name as a last resort
                local emergencySuccess = pcall(function()
                    PlayerDataStore:SetAsync("Player_" .. userId, emergencyData)
                end)
                
                if emergencySuccess then
                    DebugUtil:Log("Emergency fallback save successful")
                    return true
                end
            end
            
            return false, saveError
        end
        
        return true
    end)
    
    if success then
        -- Update cache with the saved data
        PlayerDataCache[userId] = playerData
        DebugUtil:Log("Successfully saved data for " .. player.Name .. (immediate and " (immediate)" or " (auto)"))
    else
        DebugUtil:Log("Failed to save data for " .. player.Name .. ": " .. tostring(errorMessage))
    end
    
    return success
end

-- Get cached player data (without loading from datastore)
function PlayerDataManager:GetCachedData(player)
    return PlayerDataCache[player.UserId]
end

-- Apply loaded data to game systems
function PlayerDataManager:ApplyLoadedData(player, playerData)
    if not playerData then
        playerData = PlayerDataCache[player.UserId]
        if not playerData then
            DebugUtil:Log("No cached data for " .. player.Name .. " to apply")
            return false
        end
    end
    
    -- IMPORTANT: Get the existing inventory instead of creating a new one
    -- This preserves starter items that were already added
    local inventory = InventoryManager:GetInventory(player)
    
    -- If inventory doesn't exist yet, create it (first login)
    if not inventory then
        inventory = InventoryManager:CreateInventory(player)
        DebugUtil:Log("Created new inventory for " .. player.Name)
    end
    
    -- Only apply saved data if we actually have data to apply
    local hasSavedInventoryData = false
    
    -- Check if inventory has saved data and it's properly structured
    if type(playerData.inventory) == "table" then
        -- Apply items (simple key-value pairs) - MERGE with existing items rather than replace
        if type(playerData.inventory.items) == "table" and next(playerData.inventory.items) then
            -- Loop through saved items and add to existing inventory
            for itemName, amount in pairs(playerData.inventory.items) do
                if type(itemName) == "string" and type(amount) == "number" and amount > 0 then
                    -- If item already exists, add to existing amount
                    inventory.items[itemName] = (inventory.items[itemName] or 0) + amount
                    hasSavedInventoryData = true
                end
            end
        end
        
        -- Handle tools - ONLY if we have saved tools data
        if type(playerData.inventory.tools) == "table" and next(playerData.inventory.tools) then
            -- Check if tools are stored in array format (our new format)
            local isArray = true
            for k, _ in pairs(playerData.inventory.tools) do
                if type(k) ~= "number" then
                    isArray = false
                    break
                end
            end
            
            if isArray then
                -- Process array format (new format)
                for _, toolEntry in pairs(playerData.inventory.tools) do
                    if type(toolEntry) == "table" and toolEntry.toolId then
                        -- Create a proper tool entry with defaults for missing fields
                        inventory.tools[toolEntry.toolId] = {
                            baseName = toolEntry.baseName or "Unknown Tool",
                            displayName = toolEntry.displayName or toolEntry.baseName or "Unknown Tool",
                            toolType = toolEntry.toolType or "unknown",
                            enhancementLevel = toolEntry.enhancementLevel or 0,
                            durability = toolEntry.durability or 100,
                        }
                        hasSavedInventoryData = true
                    end
                end
            else
                -- Legacy format - directly copy tools with UUIDs as keys
                for toolId, toolData in pairs(playerData.inventory.tools) do
                    if type(toolData) == "table" then
                        inventory.tools[toolId] = deepCopy(toolData)
                        hasSavedInventoryData = true
                    end
                end
            end
        end
        
        -- Apply active tools (key-value mapping)
        if type(playerData.inventory.activeTools) == "table" and next(playerData.inventory.activeTools) then
            for toolType, toolId in pairs(playerData.inventory.activeTools) do
                if type(toolType) == "string" and inventory.tools[toolId] then
                    inventory.activeTools[toolType] = toolId
                    hasSavedInventoryData = true
                end
            end
        end
        
        -- Only log if we actually applied saved data
        if hasSavedInventoryData then
            DebugUtil:Log("Applied saved inventory data for " .. player.Name)
            
            -- Force inventory update to client
            local InventoryEvents = require(ReplicatedStorage:WaitForChild("InventoryEventsModule"))
            InventoryEvents.InventoryUpdate:FireClient(player, inventory)
        else
            DebugUtil:Log("No saved inventory data to apply for " .. player.Name)
        end
    end
    
    -- Apply position (wait for character to load)
    task.spawn(function()
        local character = player.Character or player.CharacterAdded:Wait()
        
        -- Apply health
        if character:FindFirstChild("Humanoid") and playerData.character and playerData.character.health then
            character.Humanoid.MaxHealth = playerData.character.maxHealth or 100
            character.Humanoid.Health = playerData.character.health or 100
        end
        
        -- Apply position
        if character:FindFirstChild("HumanoidRootPart") and playerData.character and 
           type(playerData.character.position) == "table" and
           playerData.character.position.x and 
           playerData.character.position.y and 
           playerData.character.position.z then
            
            local pos = playerData.character.position
            -- Wait a moment for the character to fully load
            task.wait(0.5)
            character:SetPrimaryPartCFrame(
                CFrame.new(pos.x, pos.y, pos.z)
            )
        end
    end)
    
    return true
end

-- Handle a player joining the game
function PlayerDataManager:PlayerAdded(player)
    -- Check if player already has an inventory before loading data
    local existingInventory = InventoryManager:GetInventory(player)
    
    -- Load the player's data
    local playerData = self:LoadData(player)
    
    -- Apply the loaded data to the player - this will merge with existing inventory if needed
    self:ApplyLoadedData(player, playerData)
    
    -- Set up auto-save for this player
    task.spawn(function()
        while player and player:IsDescendantOf(Players) do
            task.wait(AUTO_SAVE_INTERVAL)
            if player and player:IsDescendantOf(Players) then
                self:SaveData(player)
            else
                break
            end
        end
    end)
end

-- Handle a player leaving the game
function PlayerDataManager:PlayerRemoving(player)
    if SessionLocks[player.UserId] then
        -- Save the player's data immediately before they leave
        self:SaveData(player, true)
        
        -- Clean up
        PlayerDataCache[player.UserId] = nil
        SessionLocks[player.UserId] = nil
    end
end

-- Initialize the data system
function PlayerDataManager:Initialize()
    -- Bind player events
    Players.PlayerAdded:Connect(function(player)
        self:PlayerAdded(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:PlayerRemoving(player)
    end)
    
    -- Handle existing players (in case of script reloading)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            -- Check if this player already has cached data (to avoid double initialization)
            if not PlayerDataCache[player.UserId] then
                self:PlayerAdded(player)
            end
        end)
    end
    
    -- Set up auto-backup of all player data
    task.spawn(function()
        while true do
            task.wait(AUTO_SAVE_INTERVAL * 2) -- Backup less frequently than individual saves
            
            for userId, playerData in pairs(PlayerDataCache) do
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    self:SaveData(player)
                end
            end
        end
    end)
    
    DebugUtil:Log("PlayerDataManager initialized")
end

return PlayerDataManager