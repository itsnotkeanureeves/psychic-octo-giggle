--[[
    AbilityController.lua
    
    PURPOSE:
    Handles client-side ability activation and input handling.
    Communicates with server for ability execution.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- AbilityController implementation
local AbilityController = {}
AbilityController.__index = AbilityController

function AbilityController.new()
    local self = setmetatable({}, AbilityController)
    
    -- Initialize properties
    self.AbilitySlots = {}  -- Slot number -> abilityId
    self.Abilities = {}     -- All available abilities
    self.Cooldowns = {}     -- abilityId -> cooldownEndTime
    self.UIController = nil -- Reference to AbilityBarUI
    self.TargetPosition = nil
    self.TargetDirection = nil
    self.EventSystem = nil
    
    -- Chain ability state (Phase 4)
    self.CurrentChain = nil -- Current active chain state
    
    return self
end

-- Initialize controller
function AbilityController:Initialize(abilities, eventSystem)
    self.EventSystem = eventSystem
    
    -- Load shared Constants 
    local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
    local Constants = require(SharedPath:WaitForChild("Constants"))
    self.EVENTS = Constants.EVENTS
    
    -- Listen for input
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Handle ability keybinds (Z, X, C, V)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Z then
                self:ActivateAbilityInSlot(1)
            elseif input.KeyCode == Enum.KeyCode.X then
                self:ActivateAbilityInSlot(2)
            elseif input.KeyCode == Enum.KeyCode.C then
                self:ActivateAbilityInSlot(3)
            elseif input.KeyCode == Enum.KeyCode.V then
                self:ActivateAbilityInSlot(4)
            elseif input.KeyCode == Enum.KeyCode.B then
                self:ActivateAbilityInSlot(5)
            end
        end
    end)
    
    -- Update target position on mouse movement
    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            self:UpdateTargetPosition()
        end
    end)
    
    -- Connect to remote events
    local abilityResponseEvent = ReplicatedStorage:WaitForChild("Combat_AbilityResponse")
    abilityResponseEvent.OnClientEvent:Connect(function(abilityId, success, errorMessage, data)
        self:HandleAbilityResponse(abilityId, success, errorMessage, data)
    end)
    
    -- Connect to ability execution event (NEW for Phase 4 - this was missing)
    local remoteEvents = ReplicatedStorage:WaitForChild("Combat_RemoteEvents", 10)
    if remoteEvents then
        local abilityExecutionEvent = remoteEvents:WaitForChild("Combat_AbilityExecution")
        abilityExecutionEvent.OnClientEvent:Connect(function(entityId, abilityId, targetPosition, targetDirection, targets, chainInfo)
            -- Process chain info if provided
            if chainInfo then
                print("[AbilityController] Received chain info from execution event")
                self:HandleChainInfo(chainInfo)
            end
        end)
        
        -- Connect to chain ability update event (existing)
        local chainUpdateEvent = remoteEvents:WaitForChild("Combat_ChainAbilityUpdate")
        chainUpdateEvent.OnClientEvent:Connect(function(nextAbilityId, timeout)
            self:HandleChainAbilityUpdate(nextAbilityId, timeout)
        end)
    end
    
    -- Subscribe to chain ability events if EventSystem is available (Phase 4)
    if self.EventSystem then
        self.EventSystem:Subscribe(self.EVENTS.CHAIN_ABILITY_READY, function(data)
            self:HandleChainInfo(data)
        end)
        
        self.EventSystem:Subscribe(self.EVENTS.CHAIN_ABILITY_TIMEOUT, function(data)
            self:ClearChainState()
        end)
    end
    
    -- Update ability list if provided
    if abilities then
        self:UpdateAbilities(abilities)
    end
    
    print("[AbilityController] Initialized")
    return self
end

-- Set UI controller
function AbilityController:SetUIController(uiController)
    self.UIController = uiController
    print("[AbilityController] UI controller set")
end

-- Update target position based on mouse
function AbilityController:UpdateTargetPosition()
    local mousePos = UserInputService:GetMouseLocation()
    local ray = workspace.CurrentCamera:ViewportPointToRay(mousePos.X, mousePos.Y)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    
    if raycastResult then
        self.TargetPosition = raycastResult.Position
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local rootPos = LocalPlayer.Character.HumanoidRootPart.Position
            self.TargetDirection = (self.TargetPosition - rootPos).Unit
        end
    end
end

-- Assign ability to slot
function AbilityController:AssignAbilityToSlot(slotNumber, abilityId)
    if slotNumber < 1 or slotNumber > 5 then
        return false, "Invalid slot number"
    end
    
    -- Assign to slot
    self.AbilitySlots[slotNumber] = abilityId
    
    -- Update UI if available
    if self.UIController then
        self.UIController:UpdateAbilitySlot(slotNumber, abilityId)
    end
    
    return true
end

-- Get ability in slot
function AbilityController:GetAbilityInSlot(slotNumber)
    return self.AbilitySlots[slotNumber]
end

-- Activate ability in slot
function AbilityController:ActivateAbilityInSlot(slotNumber)
    local abilityId = self.AbilitySlots[slotNumber]
    if not abilityId then
        print("[AbilityController] No ability assigned to slot", slotNumber)
        return false, "No ability assigned to slot"
    end
    
    return self:RequestAbility(abilityId)
end

-- Request ability activation from server
function AbilityController:RequestAbility(abilityId)
    -- Check if ability is on cooldown
    if self:IsOnCooldown(abilityId) then
        if self.UIController then
            self.UIController:ShowErrorMessage("Ability is on cooldown")
        end
        return false, "Ability is on cooldown"
    end
    
    -- Update target position before sending request
    self:UpdateTargetPosition()
    
    -- Send request to server
    local abilityRequestEvent = ReplicatedStorage:WaitForChild("Combat_RemoteEvents"):WaitForChild("Combat_AbilityRequest")
    print("[AbilityController] Requesting ability", abilityId)
    abilityRequestEvent:FireServer(abilityId, self.TargetPosition, self.TargetDirection)
    
    -- Notify EventSystem
    if self.EventSystem then
        self.EventSystem:Publish("ABILITY_REQUESTED", {
            abilityId = abilityId,
            targetPosition = self.TargetPosition,
            targetDirection = self.TargetDirection
        })
    end
    
    return true
end

-- Handle ability response from server
function AbilityController:HandleAbilityResponse(abilityId, success, errorMessage, data)
    print("[AbilityController] Response for ability", abilityId, success, errorMessage)
    
    if success then
        -- Notify EventSystem
        if self.EventSystem then
            self.EventSystem:Publish("ABILITY_ACTIVATED", {
                abilityId = abilityId,
                success = true
            })
        end
        
        -- Start cooldown in UI
        if self.UIController then
            local ability = self.Abilities[abilityId]
            if ability then
                self.UIController:StartCooldown(abilityId, ability.cooldown or 1.5)
            end
        end
        
        -- Process chain information if provided (Phase 4)
        if data and data.chainInfo then
            print("[AbilityController] Received chain info from response:", data.chainInfo.nextAbilityId)
            self:HandleChainInfo(data.chainInfo)
        end
    else
        -- Show error message
        if self.UIController then
            self.UIController:ShowErrorMessage(errorMessage or "Failed to use ability")
        end
        
        -- Notify EventSystem
        if self.EventSystem then
            self.EventSystem:Publish("ABILITY_ACTIVATION_FAILED", {
                abilityId = abilityId,
                reason = errorMessage
            })
        end
    end
end

-- Handle chain ability update (Phase 4)
function AbilityController:HandleChainAbilityUpdate(nextAbilityId, timeout)
    if not nextAbilityId then return end
    
    print("[AbilityController] Chain ability ready:", nextAbilityId, "timeout:", timeout)
    
    -- Update UI
    if self.UIController then
        self.UIController:UpdateAbilityInChain(nextAbilityId, timeout)
    end
    
    -- Store chain state
    self.CurrentChain = {
        nextAbilityId = nextAbilityId,
        timeoutAt = tick() + (timeout or 3)
    }
    
    -- Set up timeout
    task.delay(timeout, function()
        if self.CurrentChain and self.CurrentChain.nextAbilityId == nextAbilityId then
            self:ClearChainState()
        end
    end)
end

-- Handle chain info from ability response (Phase 4) - IMPROVED
function AbilityController:HandleChainInfo(chainInfo)
    if type(chainInfo) == "table" then
        local nextAbilityId = chainInfo.nextAbilityId
        local timeout = chainInfo.timeout or 3
        
        if nextAbilityId then
            print("[AbilityController] Processing chain info:", nextAbilityId, "timeout:", timeout)
            
            -- Update UI
            if self.UIController then
                self.UIController:UpdateAbilityInChain(nextAbilityId, timeout)
            end
            
            -- Store chain state
            self.CurrentChain = {
                chainId = chainInfo.chainId,
                nextAbilityId = nextAbilityId,
                timeoutAt = tick() + timeout
            }
            
            -- Also publish event for other systems
            if self.EventSystem then
                self.EventSystem:Publish(self.EVENTS.CHAIN_ABILITY_READY, {
                    nextAbilityId = nextAbilityId,
                    timeout = timeout
                })
            end
            
            -- Set up timeout
            task.delay(timeout, function()
                if self.CurrentChain and self.CurrentChain.nextAbilityId == nextAbilityId then
                    self:ClearChainState()
                end
            end)
        end
    end
end

-- Clear chain state (Phase 4)
function AbilityController:ClearChainState()
    self.CurrentChain = nil
    
    -- Update UI
    if self.UIController then
        self.UIController:ClearChainState()
    end
    
    -- Publish event
    if self.EventSystem then
        self.EventSystem:Publish(self.EVENTS.CHAIN_ABILITY_TIMEOUT, {})
    end
    
    print("[AbilityController] Chain state cleared")
end

-- Update abilities list
function AbilityController:UpdateAbilities(abilities)
    self.Abilities = {}
    
    for _, ability in ipairs(abilities) do
        self.Abilities[ability.id] = ability
    end
    
    -- Update UI if available
    if self.UIController then
        self.UIController:UpdateAbilities(abilities)
    end
end

-- Start cooldown
function AbilityController:StartCooldown(abilityId, duration)
    self.Cooldowns[abilityId] = tick() + duration
    
    -- Update UI
    if self.UIController then
        self.UIController:StartCooldown(abilityId, duration)
    end
end

-- End cooldown
function AbilityController:EndCooldown(abilityId)
    self.Cooldowns[abilityId] = nil
    
    -- Update UI
    if self.UIController then
        self.UIController:EndCooldown(abilityId)
    end
end

-- Check if ability is on cooldown
function AbilityController:IsOnCooldown(abilityId)
    local cooldownEnd = self.Cooldowns[abilityId]
    if not cooldownEnd then
        return false
    end
    
    return tick() < cooldownEnd
end

-- Get remaining cooldown
function AbilityController:GetRemainingCooldown(abilityId)
    local cooldownEnd = self.Cooldowns[abilityId]
    if not cooldownEnd then
        return 0
    end
    
    local remaining = cooldownEnd - tick()
    return math.max(0, remaining)
end

return AbilityController