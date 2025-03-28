--[[
    EventSystem.lua
    
    PURPOSE:
    Provides a centralized event system for decoupled communication between
    combat subsystems. Handles both server-side events and client synchronization.
    
    DESIGN PRINCIPLES:
    - Decoupled event-based communication
    - Support for event filtering
    - Optimized event payloads
    - No global state
    
    USAGE:
    local EventSystem = require(path.to.EventSystem)
    local eventSystem = EventSystem.new()
    
    -- Subscribe to events
    local connection = eventSystem:Subscribe("EVENT_TYPE", function(data)
        -- Handle event data
    end)
    
    -- Subscribe with response (for request/response pattern)
    local connection = eventSystem:SubscribeWithResponse("REQUEST_TYPE", function(data)
        -- Process request and return a response
        return {success = true, result = "processed"}
    end)
    
    -- Access response handlers (for systems implementing SendEventWithResponse)
    local responseHandlers = eventSystem:GetResponseHandlers("REQUEST_TYPE")
    
    -- Publish events
    eventSystem:Publish("EVENT_TYPE", {
        target = entity,
        value = 100
    })
    
    -- Cleanup
    connection:Disconnect()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Constants)
local EVENTS = Constants.EVENTS

local EventSystem = {}
EventSystem.__index = EventSystem

-- Connection class
local Connection = {}
Connection.__index = Connection

function Connection.new(eventSystem, eventType, handler)
    local self = setmetatable({}, Connection)
    self.EventSystem = eventSystem
    self.EventType = eventType
    self.Handler = handler
    self.IsConnected = true
    return self
end

function Connection:Disconnect()
    if not self.IsConnected then return end
    
    self.IsConnected = false
    
    local handlers = self.EventSystem.Handlers[self.EventType]
    if not handlers then return end
    
    -- Find and remove this handler
    for i, handlerFunc in ipairs(handlers) do
        if handlerFunc == self.Handler then
            table.remove(handlers, i)
            break
        end
    end
    
    -- Clean up empty event lists
    if #handlers == 0 then
        self.EventSystem.Handlers[self.EventType] = nil
    end
    
    -- Also clean up response handlers if this is a response handler
    local responseHandlers = self.EventSystem.ResponseHandlers[self.EventType]
    if responseHandlers then
        for i, handlerFunc in ipairs(responseHandlers) do
            if handlerFunc == self.Handler then
                table.remove(responseHandlers, i)
                break
            end
        end
        
        -- Clean up empty response handler lists
        if #responseHandlers == 0 then
            self.EventSystem.ResponseHandlers[self.EventType] = nil
        end
    end
end

-- EventSystem implementation
function EventSystem.new()
    local self = setmetatable({}, EventSystem)
    self.Handlers = {} -- Mapping of event types to arrays of handlers
    self.ResponseHandlers = {} -- Mapping of event types to arrays of handlers that return responses
    self.RemoteEvents = {} -- Cache of RemoteEvent objects
    
    -- Initialize remote events if on server
    if RunService:IsServer() then
        self:InitializeRemoteEvents()
    end
    
    return self
end

-- Initialize remote events (server-side only)
function EventSystem:InitializeRemoteEvents()
    if not RunService:IsServer() then return end
    
    local remoteEventNames = {
        "Combat_AbilityRequest",
        "Combat_AbilityResponse",
        "Combat_AbilityExecution",
        "Combat_ConditionUpdate", 
        "Combat_DamageEvent",
        "Combat_StatUpdate"
    }
    
    for _, name in ipairs(remoteEventNames) do
        local remoteEvent = ReplicatedStorage:FindFirstChild(name)
        if not remoteEvent then
            remoteEvent = Instance.new("RemoteEvent")
            remoteEvent.Name = name
            remoteEvent.Parent = ReplicatedStorage
        end
        
        self.RemoteEvents[name] = remoteEvent
        
        -- Connect server-side handlers for client requests
        if name == "Combat_AbilityRequest" then
            remoteEvent.OnServerEvent:Connect(function(player, ...)
                self:Publish(EVENTS.ABILITY_REQUEST, {
                    player = player,
                    args = {...}
                })
            end)
        end
    end
end

-- Subscribe to an event
function EventSystem:Subscribe(eventType, handler)
    if not self.Handlers[eventType] then
        self.Handlers[eventType] = {}
    end
    
    table.insert(self.Handlers[eventType], handler)
    return Connection.new(self, eventType, handler)
end

-- Subscribe to an event with response capability
function EventSystem:SubscribeWithResponse(eventType, handler)
    if not self.ResponseHandlers[eventType] then
        self.ResponseHandlers[eventType] = {}
    end
    
    table.insert(self.ResponseHandlers[eventType], handler)
    return Connection.new(self, eventType, handler)
end

-- Get response handlers for an event type
function EventSystem:GetResponseHandlers(eventType)
    return self.ResponseHandlers[eventType] or {}
end

-- Publish an event
function EventSystem:Publish(eventType, data)
    -- Handle local event subscribers
    local handlers = self.Handlers[eventType]
    if handlers then
        for _, handler in ipairs(handlers) do
            task.spawn(function()
                local success, err = pcall(handler, data)
                if not success then
                    warn("[EventSystem] Error in event handler for " .. eventType .. ": " .. tostring(err))
                end
            end)
        end
    end
    
    -- Handle remote event synchronization (server to client)
    if RunService:IsServer() then
        self:SyncEventWithClients(eventType, data)
    end
end

-- Synchronize event with clients (server-side only)
function EventSystem:SyncEventWithClients(eventType, data)
    if not RunService:IsServer() then return end
    
    -- Map internal event types to RemoteEvents
    local remoteEventMapping = {
        [EVENTS.ABILITY_RESPONSE] = "Combat_AbilityResponse",
        [EVENTS.ABILITY_EXECUTED] = "Combat_AbilityExecution",
        [EVENTS.CONDITION_APPLIED] = "Combat_ConditionUpdate",
        [EVENTS.CONDITION_REMOVED] = "Combat_ConditionUpdate",
        [EVENTS.CONDITION_STACK_ADDED] = "Combat_ConditionUpdate",
        [EVENTS.CONDITION_STACK_REMOVED] = "Combat_ConditionUpdate",
        [EVENTS.DAMAGE_DEALT] = "Combat_DamageEvent",
        [EVENTS.HEALING_APPLIED] = "Combat_DamageEvent",
        [EVENTS.STAT_CHANGED] = "Combat_StatUpdate",
    }
    
    local remoteName = remoteEventMapping[eventType]
    if not remoteName then return end -- No remote event for this event type
    
    local remoteEvent = self.RemoteEvents[remoteName]
    if not remoteEvent then return end
    
    -- For player-specific events, fire only to relevant player
    if data.player and data.player:IsA("Player") then
        remoteEvent:FireClient(data.player, eventType, data)
    -- For entity-specific events, fire to relevant players
    elseif data.target and data.target.Player then
        remoteEvent:FireClient(data.target.Player, eventType, data)
    -- For AoE or global events, fire to all clients
    else
        remoteEvent:FireAllClients(eventType, data)
    end
end

return EventSystem