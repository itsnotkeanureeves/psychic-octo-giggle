--[[
    RemoteEventAdapter.lua
    
    PURPOSE:
    Provides standardized access to RemoteEvents for the combat system.
    Handles error checking and provides consistent interface for client and server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteEventAdapter = {}

-- Get RemoteEvents folder
function RemoteEventAdapter:GetRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("Combat_RemoteEvents")
    if not remoteEvents then
        warn("RemoteEventAdapter: Combat_RemoteEvents folder not found")
        remoteEvents = ReplicatedStorage:WaitForChild("Combat_RemoteEvents", 10)
        if not remoteEvents then
            error("RemoteEventAdapter: Failed to find Combat_RemoteEvents folder")
            return nil
        end
    end
    return remoteEvents
end

-- Get a specific RemoteEvent
function RemoteEventAdapter:GetRemoteEvent(eventName)
    local remoteEvents = self:GetRemoteEvents()
    if not remoteEvents then
        return nil
    end
    
    local event = remoteEvents:FindFirstChild(eventName)
    if not event then
        warn("RemoteEventAdapter: RemoteEvent not found: " .. eventName)
        return nil
    end
    
    return event
end

-- Client-to-Server: Fire a RemoteEvent
function RemoteEventAdapter:FireServer(eventName, ...)
    local event = self:GetRemoteEvent(eventName)
    if not event then
        return false
    end
    
    event:FireServer(...)
    return true
end

-- Server-to-Client: Fire a RemoteEvent
function RemoteEventAdapter:FireClient(eventName, player, ...)
    local event = self:GetRemoteEvent(eventName)
    if not event then
        return false
    end
    
    event:FireClient(player, ...)
    return true
end

-- Server-to-All-Clients: Fire a RemoteEvent
function RemoteEventAdapter:FireAllClients(eventName, ...)
    local event = self:GetRemoteEvent(eventName)
    if not event then
        return false
    end
    
    event:FireAllClients(...)
    return true
end

-- Connect to a client-side event
function RemoteEventAdapter:ConnectClientEvent(eventName, callback)
    local event = self:GetRemoteEvent(eventName)
    if not event then
        return nil
    end
    
    return event.OnClientEvent:Connect(callback)
end

-- Connect to a server-side event
function RemoteEventAdapter:ConnectServerEvent(eventName, callback)
    local event = self:GetRemoteEvent(eventName)
    if not event then
        return nil
    end
    
    return event.OnServerEvent:Connect(callback)
end

return RemoteEventAdapter
