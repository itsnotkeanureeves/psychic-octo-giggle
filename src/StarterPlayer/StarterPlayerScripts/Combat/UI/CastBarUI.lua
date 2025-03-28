--[[
    CastBarUI.lua
    
    PURPOSE:
    Provides client-side UI for displaying casting progress.
    Handles both player's own cast bar and world-space cast bars for other entities.
    
    DESIGN PRINCIPLES:
    - OOP encapsulation
    - Object pooling for efficiency
    - Event-driven updates
    - Consistent appearance
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Safe remote event access helper
local function safeGetRemoteEvent(name)
    -- Wait for the remote events folder with a reasonable timeout
    local startTime = tick()
    local maxWaitTime = 5 -- seconds
    
    local remoteEventsFolder
    repeat
        remoteEventsFolder = ReplicatedStorage:FindFirstChild("Combat_RemoteEvents")
        if not remoteEventsFolder then
            task.wait(0.1)
        end
    until remoteEventsFolder or (tick() - startTime > maxWaitTime)
    
    -- If folder not found after timeout, create a placeholder
    if not remoteEventsFolder then
        print("[CastBarUI] Warning: RemoteEvents folder not found, using placeholder")
        return { 
            OnClientEvent = { 
                Connect = function() 
                    return { Disconnect = function() end }
                end 
            } 
        }
    end
    
    -- Look for the event in the folder
    local event = remoteEventsFolder:FindFirstChild(name)
    if not event then
        print("[CastBarUI] Warning: RemoteEvent " .. name .. " not found, using placeholder")
        return { 
            OnClientEvent = { 
                Connect = function() 
                    return { Disconnect = function() end }
                end 
            } 
        }
    end
    
    print("[CastBarUI] Successfully connected to RemoteEvent: " .. name)
    return event
end

-- Load dependencies (with proper waiting and error handling)
local function loadDependencies()
    local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
    local Constants = require(SharedPath:WaitForChild("Constants"))
    local EVENTS = Constants.EVENTS
    
    local UtilityPath = SharedPath:WaitForChild("Utility")
    local EntityUtility
    
    -- Try to load EntityUtility but don't fail if not found
    pcall(function()
        EntityUtility = require(UtilityPath:WaitForChild("EntityUtility"))
    end)
    
    -- If EntityUtility wasn't loaded, create a minimal version
    if not EntityUtility then
        print("[CastBarUI] Warning: EntityUtility not found, using minimal implementation")
        EntityUtility = {
            FindEntityModel = function(entityId)
                if not entityId then return nil end
                
                -- Try to find directly in workspace
                local model = workspace:FindFirstChild(entityId)
                if model then return model end
                
                -- Try to find based on attributes
                for _, child in ipairs(workspace:GetChildren()) do
                    if child:IsA("Model") and child:GetAttribute("EntityId") == entityId then
                        return child
                    end
                end
                
                return nil
            end
        }
    end
    
    print("[CastBarUI] Dependencies loaded successfully")
    return {
        Constants = Constants,
        EVENTS = EVENTS,
        EntityUtility = EntityUtility
    }
end

-- CastBarUI implementation
local CastBarUI = {}
CastBarUI.__index = CastBarUI

function CastBarUI.new(eventSystem)
    local self = setmetatable({}, CastBarUI)
    
    -- Validate required arguments
    if not eventSystem then
        error("EventSystem is required to initialize CastBarUI")
    end
    
    print("[CastBarUI] Initializing with EventSystem")
    
    -- Load dependencies
    local deps = loadDependencies()
    self.Constants = deps.Constants
    self.EVENTS = deps.EVENTS
    self.EntityUtility = deps.EntityUtility
    
    -- Store references
    self.EventSystem = eventSystem
    
    -- Initialize state
    self.PlayerCastBar = nil       -- Player's own cast bar
    self.WorldCastBars = {}        -- entityId -> cast bar reference
    self.WorldCastBarPool = {}     -- Pooled world cast bars
    
    -- Create UI components
    self:CreatePlayerCastBar()
    
    -- Create container for world cast bars
    self.WorldCastBarFolder = Instance.new("Folder")
    self.WorldCastBarFolder.Name = "WorldCastBars"
    self.WorldCastBarFolder.Parent = workspace
    
    -- Connect to events
    self:ConnectEvents()
    
    -- Initialize update loop
    RunService.Heartbeat:Connect(function(dt)
        self:Update(dt)
    end)
    
    return self
end

-- Create the player's personal cast bar (IMPLEMENTED)
function CastBarUI:CreatePlayerCastBar()
    -- Create ScreenGui if it doesn't exist
    local screenGui = PlayerGui:FindFirstChild("CastBarUI")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CastBarUI"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = PlayerGui
    end
    
    -- Create player cast bar
    local castBarFrame = Instance.new("Frame")
    castBarFrame.Name = "PlayerCastBar"
    castBarFrame.Size = UDim2.new(0, 300, 0, 30)
    castBarFrame.Position = UDim2.new(0.5, -150, 0.7, 0)
    castBarFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    castBarFrame.BorderSizePixel = 0
    castBarFrame.Visible = false
    castBarFrame.Parent = screenGui
    
    -- Create ability icon
    local abilityIcon = Instance.new("ImageLabel")
    abilityIcon.Name = "AbilityIcon"
    abilityIcon.Size = UDim2.new(0, 30, 0, 30)
    abilityIcon.Position = UDim2.new(0, 0, 0, 0)
    abilityIcon.BackgroundTransparency = 1
    abilityIcon.Image = "rbxassetid://0"
    abilityIcon.Parent = castBarFrame
    
    -- Create ability name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "AbilityName"
    nameLabel.Size = UDim2.new(1, -40, 0, 15)
    nameLabel.Position = UDim2.new(0, 40, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = "Casting..."
    nameLabel.Parent = castBarFrame
    
    -- Create progress bar background
    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBackground"
    progressBg.Size = UDim2.new(1, -40, 0, 10)
    progressBg.Position = UDim2.new(0, 40, 0, 18)
    progressBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    progressBg.BorderSizePixel = 0
    progressBg.Parent = castBarFrame
    
    -- Create progress bar fill
    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg
    
    -- Store references
    self.PlayerCastBar = {
        frame = castBarFrame,
        icon = abilityIcon,
        nameLabel = nameLabel,
        progressBg = progressBg,
        progressFill = progressFill,
        castTime = 0,
        startTime = 0,
        active = false
    }
    
    print("[CastBarUI] Player cast bar created successfully")
end

-- Get or create a world cast bar from pool (IMPLEMENTED)
function CastBarUI:GetWorldCastBar()
    -- Check if there's one in the pool
    if #self.WorldCastBarPool > 0 then
        return table.remove(self.WorldCastBarPool)
    end
    
    -- Create a new world cast bar
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "WorldCastBar"
    billboardGui.Size = UDim2.new(0, 100, 0, 20)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.MaxDistance = 100
    billboardGui.Active = true
    
    -- Create background
    local background = Instance.new("Frame")
    background.Name = "Background"
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    background.BorderSizePixel = 0
    background.Parent = billboardGui
    
    -- Create ability name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "AbilityName"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 8
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Text = "Casting..."
    nameLabel.Parent = background
    
    -- Create progress bar background
    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBackground"
    progressBg.Size = UDim2.new(1, -4, 0.4, 0)
    progressBg.Position = UDim2.new(0, 2, 0.6, 0)
    progressBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    progressBg.BorderSizePixel = 0
    progressBg.Parent = background
    
    -- Create progress bar fill
    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg
    
    return {
        billboardGui = billboardGui,
        background = background,
        nameLabel = nameLabel,
        progressBg = progressBg,
        progressFill = progressFill,
        entityId = nil,
        castTime = 0,
        startTime = 0
    }
end

-- Return a world cast bar to the pool (IMPLEMENTED)
function CastBarUI:ReturnWorldCastBarToPool(castBar)
    if not castBar then return end
    
    -- Reset state
    castBar.billboardGui.Parent = nil
    castBar.entityId = nil
    castBar.castTime = 0
    castBar.startTime = 0
    castBar.progressFill.Size = UDim2.new(0, 0, 1, 0)
    
    -- Add to pool
    table.insert(self.WorldCastBarPool, castBar)
end

-- Connect to events
function CastBarUI:ConnectEvents()
    print("[CastBarUI] Setting up event connections")
    
    -- Connect to ability cast events via EventSystem
    self.EventSystem:Subscribe(self.EVENTS.ABILITY_CAST_START, function(data)
        print("[CastBarUI] Received ABILITY_CAST_START event")
        self:OnAbilityCastStart(data)
    end)
    
    self.EventSystem:Subscribe(self.EVENTS.ABILITY_CAST_COMPLETE, function(data)
        print("[CastBarUI] Received ABILITY_CAST_COMPLETE event")
        self:OnAbilityCastComplete(data)
    end)
    
    self.EventSystem:Subscribe(self.EVENTS.ABILITY_CAST_INTERRUPTED, function(data)
        print("[CastBarUI] Received ABILITY_CAST_INTERRUPTED event")
        self:OnAbilityCastInterrupted(data)
    end)
    
    -- Connect to cast bar update RemoteEvent - this is critical for Phase 4
    local castBarUpdateEvent = safeGetRemoteEvent("Combat_CastBarUpdate")
    print("[CastBarUI] Setting up CastBarUpdate event handler")
    castBarUpdateEvent.OnClientEvent:Connect(function(entityId, progress, abilityName, abilityIcon, castTime)
        print("[CastBarUI] Received CastBarUpdate: entity=" .. tostring(entityId) .. 
              ", progress=" .. tostring(progress) .. 
              ", ability=" .. tostring(abilityName) .. 
              ", time=" .. tostring(castTime))
        self:OnCastBarUpdate(entityId, progress, abilityName, abilityIcon, castTime)
    end)
    
    -- Connect to chain ability events
    self.EventSystem:Subscribe(self.EVENTS.CHAIN_ABILITY_READY, function(data)
        -- Not needed for the cast bar system
    end)
    
    print("[CastBarUI] All event connections established")
end

-- Event handlers (IMPLEMENTED)
function CastBarUI:OnAbilityCastStart(data)
    local entityId = data.entityId
    local abilityName = data.abilityName or "Unknown Ability"
    local abilityIcon = data.abilityIcon or ""
    local castTime = data.castTime or 1
    
    print("[CastBarUI] Processing cast started:", abilityName, "for entity", entityId, "with time", castTime)
    
    -- For local player
    if self:IsLocalPlayerEntity(entityId) then
        print("[CastBarUI] This is the local player - showing player cast bar")
        self:ShowPlayerCastBar(abilityName, abilityIcon, castTime)
    else
        -- For other entities
        print("[CastBarUI] This is another entity - showing world cast bar")
        local entityModel = self:FindEntityModel(entityId)
        if entityModel then
            self:ShowWorldCastBar(entityId, entityModel, abilityName, castTime)
        else
            print("[CastBarUI] Could not find entity model for", entityId)
        end
    end
end

function CastBarUI:OnAbilityCastComplete(data)
    local entityId = data.entityId
    
    print("[CastBarUI] Cast completed for entity", entityId)
    
    -- For local player
    if self:IsLocalPlayerEntity(entityId) then
        self:HidePlayerCastBar()
    else
        -- For other entities
        self:HideWorldCastBar(entityId)
    end
end

function CastBarUI:OnAbilityCastInterrupted(data)
    local entityId = data.entityId
    
    print("[CastBarUI] Cast interrupted for entity", entityId)
    
    -- For local player
    if self:IsLocalPlayerEntity(entityId) then
        self:HidePlayerCastBar(true) -- true = interrupted
    else
        -- For other entities
        self:HideWorldCastBar(entityId)
    end
end

function CastBarUI:OnCastBarUpdate(entityId, progress, abilityName, abilityIcon, castTime)
    -- Detailed logging for all parameters
    print("[CastBarUI] Processing cast update:", 
          "entity=" .. tostring(entityId), 
          "progress=" .. tostring(progress), 
          "ability=" .. tostring(abilityName), 
          "time=" .. tostring(castTime))
    
    -- For local player
    if self:IsLocalPlayerEntity(entityId) then
        if self.PlayerCastBar and self.PlayerCastBar.active then
            print("[CastBarUI] Updating player cast bar progress to", progress)
            self.PlayerCastBar.progressFill.Size = UDim2.new(progress, 0, 1, 0)
            
            -- If this is the first update (progress = 0), update the UI with ability info
            if progress == 0 then
                print("[CastBarUI] Initial cast update - showing cast bar")
                self:ShowPlayerCastBar(abilityName, abilityIcon, castTime)
            end
        else
            print("[CastBarUI] Received update for inactive player cast bar - showing it now")
            self:ShowPlayerCastBar(abilityName, abilityIcon, castTime)
        end
    else
        -- For other entities
        local castBar = self.WorldCastBars[entityId]
        if castBar then
            castBar.progressFill.Size = UDim2.new(progress, 0, 1, 0)
        elseif progress == 0 then
            -- If this is the first update and we don't have a bar, create one
            local entityModel = self:FindEntityModel(entityId)
            if entityModel then
                print("[CastBarUI] Creating new world cast bar for entity", entityId)
                self:ShowWorldCastBar(entityId, entityModel, abilityName, castTime)
            end
        end
    end
end

-- Show player cast bar (IMPLEMENTED)
function CastBarUI:ShowPlayerCastBar(abilityName, abilityIcon, castTime)
    if not self.PlayerCastBar then 
        print("[CastBarUI] Player cast bar not initialized")
        return 
    end
    
    -- Set values
    self.PlayerCastBar.nameLabel.Text = abilityName or "Casting..."
    self.PlayerCastBar.icon.Image = abilityIcon or ""
    self.PlayerCastBar.castTime = castTime or 1
    self.PlayerCastBar.startTime = tick()
    self.PlayerCastBar.active = true
    
    -- Reset progress
    self.PlayerCastBar.progressFill.Size = UDim2.new(0, 0, 1, 0)
    
    -- Show the cast bar
    self.PlayerCastBar.frame.Visible = true
    
    print("[CastBarUI] Player cast bar shown for", abilityName, "with time", castTime)
end

-- Show world cast bar for an entity (IMPLEMENTED)
function CastBarUI:ShowWorldCastBar(entityId, entityModel, abilityName, castTime)
    if not entityId or not entityModel then 
        print("[CastBarUI] Missing entity info for world cast bar")
        return 
    end
    
    -- If already has a cast bar, remove it first
    if self.WorldCastBars[entityId] then
        self:HideWorldCastBar(entityId)
    end
    
    -- Get a cast bar from the pool
    local castBar = self:GetWorldCastBar()
    
    -- Set values
    castBar.nameLabel.Text = abilityName or "Casting..."
    castBar.castTime = castTime or 1
    castBar.startTime = tick()
    castBar.entityId = entityId
    
    -- Attach to the entity model
    castBar.billboardGui.Adornee = entityModel
    castBar.billboardGui.Parent = self.WorldCastBarFolder
    
    -- Reset progress
    castBar.progressFill.Size = UDim2.new(0, 0, 1, 0)
    
    -- Store reference
    self.WorldCastBars[entityId] = castBar
    
    print("[CastBarUI] World cast bar shown for entity", entityId, "ability", abilityName)
end

-- Hide player cast bar (IMPLEMENTED)
function CastBarUI:HidePlayerCastBar(interrupted)
    if not self.PlayerCastBar then return end
    
    -- If interrupted, flash red briefly
    if interrupted then
        self.PlayerCastBar.frame.BackgroundColor3 = Color3.fromRGB(200, 40, 40) -- Red
        
        -- Delay hiding to show the interruption
        task.delay(0.3, function()
            self.PlayerCastBar.frame.Visible = false
            self.PlayerCastBar.active = false
        end)
    else
        self.PlayerCastBar.frame.Visible = false
        self.PlayerCastBar.active = false
    end
    
    print("[CastBarUI] Player cast bar hidden" .. (interrupted and " (interrupted)" or ""))
end

-- Hide world cast bar for an entity (IMPLEMENTED)
function CastBarUI:HideWorldCastBar(entityId)
    local castBar = self.WorldCastBars[entityId]
    if not castBar then return end
    
    -- Return to pool
    self:ReturnWorldCastBarToPool(castBar)
    
    -- Remove reference
    self.WorldCastBars[entityId] = nil
    
    print("[CastBarUI] World cast bar hidden for entity", entityId)
end

-- Update all cast bars (IMPLEMENTED)
function CastBarUI:Update(dt)
    -- Update player cast bar
    if self.PlayerCastBar and self.PlayerCastBar.active then
        local elapsed = tick() - self.PlayerCastBar.startTime
        local progress = math.clamp(elapsed / self.PlayerCastBar.castTime, 0, 1)
        
        self.PlayerCastBar.progressFill.Size = UDim2.new(progress, 0, 1, 0)
        
        -- Auto-hide when complete
        if progress >= 1 then
            self:HidePlayerCastBar()
        end
    end
    
    -- Update world cast bars
    for entityId, castBar in pairs(self.WorldCastBars) do
        local elapsed = tick() - castBar.startTime
        local progress = math.clamp(elapsed / castBar.castTime, 0, 1)
        
        castBar.progressFill.Size = UDim2.new(progress, 0, 1, 0)
        
        -- Auto-hide when complete
        if progress >= 1 then
            self:HideWorldCastBar(entityId)
        end
    end
end

-- Helper function to check if entity is local player
function CastBarUI:IsLocalPlayerEntity(entityId)
    -- Compare with player's userId
    if tostring(LocalPlayer.UserId) == tostring(entityId) then
        return true
    end
    
    -- Try to get character
    local character = LocalPlayer.Character
    if character and character:GetAttribute("EntityId") == entityId then
        return true
    end
    
    -- Also try entity_1 which is often the player entity in the system
    if tostring(entityId) == "entity_1" then
        return true
    end
    
    return false
end

-- Helper function to find entity model
function CastBarUI:FindEntityModel(entityId)
    -- Try using EntityUtility if available
    if self.EntityUtility and self.EntityUtility.FindEntityModel then
        return self.EntityUtility.FindEntityModel(entityId)
    end
    
    -- Fallback implementation
    -- Try to find directly in workspace
    local model = workspace:FindFirstChild(tostring(entityId))
    if model then return model end
    
    -- Try to find based on attributes
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("EntityId") == entityId then
            return child
        end
    end
    
    -- Look for player character if entity is entity_1
    if tostring(entityId) == "entity_1" and LocalPlayer.Character then
        return LocalPlayer.Character
    end
    
    print("[CastBarUI] Could not find model for entity:", entityId)
    return nil
end

-- Clean up function
function CastBarUI:Destroy()
    -- Clean up world cast bars
    for _, castBar in pairs(self.WorldCastBars) do
        self:ReturnWorldCastBarToPool(castBar)
    end
    
    -- Clear UI elements
    if self.PlayerCastBar and self.PlayerCastBar.frame then
        self.PlayerCastBar.frame:Destroy()
    end
    
    -- Remove folder
    if self.WorldCastBarFolder then
        self.WorldCastBarFolder:Destroy()
    end
    
    -- Clear pooled objects
    self.WorldCastBarPool = {}
    self.WorldCastBars = {}
    
    print("[CastBarUI] Resources destroyed")
end

return CastBarUI