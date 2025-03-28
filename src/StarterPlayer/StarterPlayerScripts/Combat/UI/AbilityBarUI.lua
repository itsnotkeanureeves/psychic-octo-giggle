--[[
    AbilityBarUI.lua
    
    PURPOSE:
    Provides a client-side UI for displaying and using abilities.
    
    FEATURES:
    - Displays ability icons
    - Shows cooldown overlays
    - Handles key bindings
    - Displays tooltips
    - Supports ability chains (Phase 4)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Remote events
local AbilityResponseEvent = ReplicatedStorage:WaitForChild("Combat_AbilityResponse")
local AbilityRequestEvent = ReplicatedStorage:WaitForChild("Combat_AbilityRequest")

-- Load shared modules
local function loadSharedModules()
    local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
    local Constants = require(SharedPath:WaitForChild("Constants"))
    
    return {
        Constants = Constants,
        EVENTS = Constants.EVENTS
    }
end

-- Create AbilityBarUI class
local AbilityBarUI = {}
AbilityBarUI.__index = AbilityBarUI

-- Create a new AbilityBarUI instance
function AbilityBarUI.new(abilities)
    local self = setmetatable({}, AbilityBarUI)
    
    -- Load dependencies
    local deps = loadSharedModules()
    self.Constants = deps.Constants
    self.EVENTS = deps.EVENTS
    
    -- Store abilities
    self.Abilities = abilities or {}
    self.AbilitySlots = {}
    self.MouseTarget = nil
    self.MouseDown = false
    
    -- Chain ability state
    self.CurrentChain = nil -- Current active chain state
    
    -- Default keybindings (1-5)
    self.KeyBindings = {
        [1] = Enum.KeyCode.One,
        [2] = Enum.KeyCode.Two,
        [3] = Enum.KeyCode.Three,
        [4] = Enum.KeyCode.Four,
        [5] = Enum.KeyCode.Five
    }
    
    -- Create UI
    self:CreateUI()
    
    -- Connect events
    self:ConnectEvents()
    
    return self
end

-- Create the ability bar UI
function AbilityBarUI:CreateUI()
    -- Create ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "AbilityBarUI"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.Parent = PlayerGui
    
    -- Create main frame
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Name = "AbilityBar"
    self.MainFrame.Size = UDim2.new(0, 400, 0, 80)
    self.MainFrame.Position = UDim2.new(0.5, -200, 1, -100)
    self.MainFrame.BackgroundTransparency = 0.5
    self.MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.Parent = self.ScreenGui
    
    -- Create ability slots
    for i = 1, 5 do
        local slot = self:CreateAbilitySlot(i)
        self.AbilitySlots[i] = slot
    end
    
    -- Create tooltip
    self.Tooltip = Instance.new("Frame")
    self.Tooltip.Name = "Tooltip"
    self.Tooltip.Size = UDim2.new(0, 200, 0, 150)
    self.Tooltip.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    self.Tooltip.BackgroundTransparency = 0.2
    self.Tooltip.BorderSizePixel = 0
    self.Tooltip.Visible = false
    self.Tooltip.ZIndex = 10
    self.Tooltip.Parent = self.ScreenGui
    
    -- Add tooltip content
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Text = "Ability Name"
    title.ZIndex = 11
    title.Parent = self.Tooltip
    
    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Size = UDim2.new(1, -20, 1, -40)
    description.Position = UDim2.new(0, 10, 0, 35)
    description.BackgroundTransparency = 1
    description.TextColor3 = Color3.fromRGB(200, 200, 200)
    description.TextSize = 14
    description.Font = Enum.Font.Gotham
    description.Text = "Ability description..."
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.ZIndex = 11
    description.Parent = self.Tooltip
end

-- Create an ability slot
function AbilityBarUI:CreateAbilitySlot(index)
    local slotSize = 70
    local spacing = 10
    local xPosition = (index - 1) * (slotSize + spacing)
    
    local slot = {}
    
    -- Create slot frame
    local frame = Instance.new("Frame")
    frame.Name = "AbilitySlot" .. index
    frame.Size = UDim2.new(0, slotSize, 0, slotSize)
    frame.Position = UDim2.new(0, xPosition, 0.5, -slotSize/2)
    frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    frame.BorderSizePixel = 0
    frame.Parent = self.MainFrame
    
    -- Create key binding label
    local keyLabel = Instance.new("TextLabel")
    keyLabel.Name = "KeyLabel"
    keyLabel.Size = UDim2.new(0, 20, 0, 20)
    keyLabel.Position = UDim2.new(0, 5, 0, 5)
    keyLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    keyLabel.BackgroundTransparency = 0.5
    keyLabel.BorderSizePixel = 0
    keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyLabel.TextSize = 12
    keyLabel.Font = Enum.Font.GothamBold
    keyLabel.Text = tostring(index)
    keyLabel.ZIndex = 2
    keyLabel.Parent = frame
    
    -- Create ability icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, -10, 1, -10)
    icon.Position = UDim2.new(0, 5, 0, 5)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png" -- Placeholder
    icon.ZIndex = 1
    icon.Parent = frame
    
    -- Create cooldown overlay
    local cooldown = Instance.new("Frame")
    cooldown.Name = "Cooldown"
    cooldown.Size = UDim2.new(1, 0, 0, 0)
    cooldown.Position = UDim2.new(0, 0, 1, 0)
    cooldown.AnchorPoint = Vector2.new(0, 1)
    cooldown.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    cooldown.BackgroundTransparency = 0.5
    cooldown.BorderSizePixel = 0
    cooldown.ZIndex = 3
    cooldown.Visible = false
    cooldown.Parent = frame
    
    -- Create cooldown text
    local cooldownText = Instance.new("TextLabel")
    cooldownText.Name = "CooldownText"
    cooldownText.Size = UDim2.new(1, 0, 1, 0)
    cooldownText.BackgroundTransparency = 1
    cooldownText.TextColor3 = Color3.fromRGB(255, 255, 255)
    cooldownText.TextSize = 24
    cooldownText.Font = Enum.Font.GothamBold
    cooldownText.Text = ""
    cooldownText.ZIndex = 4
    cooldownText.Visible = false
    cooldownText.Parent = frame
    
    -- Create click detector
    local button = Instance.new("TextButton")
    button.Name = "Button"
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.ZIndex = 5
    button.Parent = frame
    
    -- Store UI elements in slot
    slot.Frame = frame
    slot.Icon = icon
    slot.Cooldown = cooldown
    slot.CooldownText = cooldownText
    slot.Button = button
    slot.KeyLabel = keyLabel
    slot.Index = index
    slot.AbilityId = nil
    
    -- Connect events
    button.MouseButton1Down:Connect(function()
        self:OnAbilityActivated(index)
    end)
    
    button.MouseEnter:Connect(function()
        self:ShowTooltip(index)
    end)
    
    button.MouseLeave:Connect(function()
        self:HideTooltip()
    end)
    
    return slot
end

-- Connect input events and other system events
function AbilityBarUI:ConnectEvents()
    -- Keybindings
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.Keyboard then
            for index, keyCode in pairs(self.KeyBindings) do
                if input.KeyCode == keyCode then
                    self:OnAbilityActivated(index)
                    break
                end
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.MouseDown = true
            
            -- Store mouse target for abilities that need a target position
            local mouseLocation = UserInputService:GetMouseLocation()
            local ray = workspace.CurrentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
            
            local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
            
            if raycastResult then
                self.MouseTarget = raycastResult.Position
            else
                -- If no hit, use a point far along the ray
                self.MouseTarget = ray.Origin + ray.Direction * 100
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.MouseDown = false
        end
    end)
    
    -- Listen for ability response
    AbilityResponseEvent.OnClientEvent:Connect(function(abilityId, success, errorMessage, data)
        -- Update UI based on response
        if success then
            self:StartCooldown(abilityId)
            
            -- Check for chain info in data
            if data and data.chainInfo then
                self:HandleChainInfo(data.chainInfo)
            end
        else
            self:ShowErrorMessage(errorMessage)
        end
    end)
    
    -- Connect to chain ability events
    local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
    local EventSystem = require(SharedPath:WaitForChild("EventSystem"))
    local Constants = require(SharedPath:WaitForChild("Constants"))
    local eventSystem = EventSystem.new()
    
    eventSystem:Subscribe(Constants.EVENTS.CHAIN_ABILITY_READY, function(data)
        self:UpdateAbilityInChain(data.nextAbilityId, data.timeout)
    end)
    
    eventSystem:Subscribe(Constants.EVENTS.CHAIN_ABILITY_TIMEOUT, function(data)
        self:ClearChainState()
    end)
    
    -- Character respawn
    LocalPlayer.CharacterAdded:Connect(function(character)
        -- Update UI if needed when character respawns
        self:ClearChainState()
    end)
end

-- Update the abilities displayed
function AbilityBarUI:UpdateAbilities(abilities)
    self.Abilities = abilities or self.Abilities
    
    -- Update each slot
    for i, ability in ipairs(self.Abilities) do
        if i <= #self.AbilitySlots then
            local slot = self.AbilitySlots[i]
            slot.AbilityId = ability.id
            
            -- Update icon
            if ability.icon then
                slot.Icon.Image = ability.icon
            else
                slot.Icon.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
            end
            
            -- Update cooldown if applicable
            if ability.remainingCooldown and ability.remainingCooldown > 0 then
                self:ShowCooldown(i, ability.remainingCooldown)
            else
                self:HideCooldown(i)
            end
        end
    end
    
    -- Clear unused slots
    for i = #self.Abilities + 1, #self.AbilitySlots do
        local slot = self.AbilitySlots[i]
        slot.AbilityId = nil
        slot.Icon.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
        self:HideCooldown(i)
    end
end

-- Update a specific ability slot
function AbilityBarUI:UpdateAbilitySlot(slotNumber, abilityId)
    if slotNumber < 1 or slotNumber > #self.AbilitySlots then
        return false, "Invalid slot number"
    end
    
    -- Find ability data
    local abilityData = nil
    for _, ability in ipairs(self.Abilities) do
        if ability.id == abilityId then
            abilityData = ability
            break
        end
    end
    
    if not abilityData then
        print("[AbilityBarUI] No data found for ability: " .. abilityId)
        abilityData = {
            id = abilityId,
            name = abilityId,
            description = "No description available",
            icon = "rbxasset://textures/ui/GuiImagePlaceholder.png"
        }
    end
    
    -- Update slot
    local slot = self.AbilitySlots[slotNumber]
    slot.AbilityId = abilityId
    
    -- Update icon
    if abilityData.icon then
        slot.Icon.Image = abilityData.icon
    else
        slot.Icon.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    end
    
    return true
end

-- Show ability tooltip
function AbilityBarUI:ShowTooltip(index)
    if index > #self.Abilities then return end
    
    local ability = self.Abilities[index]
    local slot = self.AbilitySlots[index]
    
    if not ability then return end
    
    -- Update tooltip content
    self.Tooltip.Title.Text = ability.name or "Unknown Ability"
    
    local description = ability.description or "No description available."
    local cooldown = ability.cooldown or 0
    local resourceCost = ability.resourceCost or {}
    
    local tooltipText = description .. "\n\n"
    tooltipText = tooltipText .. "Cooldown: " .. cooldown .. " seconds\n"
    
    if resourceCost.type and resourceCost.amount then
        tooltipText = tooltipText .. "Cost: " .. resourceCost.amount .. " " .. resourceCost.type
    end
    
    self.Tooltip.Description.Text = tooltipText
    
    -- Position tooltip near slot
    local slotPosition = slot.Frame.AbsolutePosition
    local tooltipPosition = UDim2.new(0, slotPosition.X, 0, slotPosition.Y - self.Tooltip.Size.Y.Offset - 10)
    self.Tooltip.Position = tooltipPosition
    
    -- Show tooltip
    self.Tooltip.Visible = true
end

-- Hide ability tooltip
function AbilityBarUI:HideTooltip()
    self.Tooltip.Visible = false
end

-- Handle ability activation
function AbilityBarUI:OnAbilityActivated(index)
    if index > #self.Abilities then return end
    
    local ability = self.Abilities[index]
    local slot = self.AbilitySlots[index]
    
    if not ability or not slot.AbilityId then return end
    
    -- Check if ability is on cooldown
    if slot.Cooldown.Visible then return end
    
    -- Get target position and direction
    local character = LocalPlayer.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local targetPosition = self.MouseTarget or rootPart.Position + rootPart.CFrame.LookVector * 10
    local direction = (targetPosition - rootPart.Position).Unit
    
    -- Request ability activation
    AbilityRequestEvent:FireServer(slot.AbilityId, targetPosition, direction)
end

-- Show cooldown overlay
function AbilityBarUI:ShowCooldown(index, duration)
    if index > #self.AbilitySlots then return end
    
    local slot = self.AbilitySlots[index]
    
    -- Reset cooldown display
    slot.Cooldown.Size = UDim2.new(1, 0, 1, 0)
    slot.Cooldown.Visible = true
    slot.CooldownText.Visible = true
    
    -- Store cooldown info
    slot.CooldownDuration = duration
    slot.CooldownStartTime = tick()
    slot.CooldownActive = true
    
    -- Update cooldown in a loop
    if not self.CooldownLoop then
        self.CooldownLoop = true
        task.spawn(function()
            while self.CooldownLoop do
                self:UpdateCooldowns()
                task.wait(0.1)
            end
        end)
    end
end

-- Update all active cooldowns
function AbilityBarUI:UpdateCooldowns()
    local activeCooldowns = false
    
    for i, slot in ipairs(self.AbilitySlots) do
        if slot.CooldownActive then
            local elapsed = tick() - slot.CooldownStartTime
            local remaining = math.max(0, slot.CooldownDuration - elapsed)
            local progress = remaining / slot.CooldownDuration
            
            -- Update cooldown overlay
            slot.Cooldown.Size = UDim2.new(1, 0, progress, 0)
            
            -- Update text
            if remaining > 0 then
                slot.CooldownText.Text = math.ceil(remaining)
                activeCooldowns = true
            else
                self:HideCooldown(i)
            end
        end
    end
    
    -- Stop cooldown loop if no active cooldowns
    if not activeCooldowns then
        self.CooldownLoop = false
    end
end

-- Hide cooldown overlay
function AbilityBarUI:HideCooldown(index)
    if index > #self.AbilitySlots then return end
    
    local slot = self.AbilitySlots[index]
    
    slot.Cooldown.Visible = false
    slot.CooldownText.Visible = false
    slot.CooldownActive = false
end

-- Start cooldown for an ability
function AbilityBarUI:StartCooldown(abilityId)
    for i, ability in ipairs(self.Abilities) do
        if ability.id == abilityId then
            self:ShowCooldown(i, ability.cooldown or 1.5)
            break
        end
    end
end

-- Show error message
function AbilityBarUI:ShowErrorMessage(message)
    -- Create error message label if it doesn't exist
    if not self.ErrorMessage then
        self.ErrorMessage = Instance.new("TextLabel")
        self.ErrorMessage.Name = "ErrorMessage"
        self.ErrorMessage.Size = UDim2.new(0, 400, 0, 30)
        self.ErrorMessage.Position = UDim2.new(0.5, -200, 0.8, 0)
        self.ErrorMessage.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        self.ErrorMessage.BackgroundTransparency = 0.2
        self.ErrorMessage.BorderSizePixel = 0
        self.ErrorMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
        self.ErrorMessage.TextSize = 16
        self.ErrorMessage.Font = Enum.Font.GothamBold
        self.ErrorMessage.ZIndex = 10
        self.ErrorMessage.Visible = false
        self.ErrorMessage.Parent = self.ScreenGui
    end
    
    -- Show error message
    self.ErrorMessage.Text = message
    self.ErrorMessage.Visible = true
    
    -- Hide after a delay
    task.delay(2, function()
        self.ErrorMessage.Visible = false
    end)
end

-- PHASE 4: Handle chain ability info
function AbilityBarUI:HandleChainInfo(chainInfo)
    if not chainInfo or not chainInfo.nextAbilityId then return end
    
    print("[AbilityBarUI] Chain ability ready:", chainInfo.nextAbilityId)
    
    -- Update UI with chain ability
    self:UpdateAbilityInChain(chainInfo.nextAbilityId, chainInfo.timeout)
    
    -- Store current chain state
    self.CurrentChain = {
        chainId = chainInfo.chainId,
        nextAbilityId = chainInfo.nextAbilityId,
        timeoutAt = tick() + (chainInfo.timeout or 3)
    }
    
    -- Set up chain timeout check
    task.delay(chainInfo.timeout, function()
        if self.CurrentChain and self.CurrentChain.chainId == chainInfo.chainId then
            -- If chain is still active and timed out
            self:ClearChainState()
        end
    end)
end

-- PHASE 4: Update UI for chain ability
function AbilityBarUI:UpdateAbilityInChain(nextAbilityId, timeout)
    if not nextAbilityId then return end
    
    -- Find the slot containing the next ability in chain
    local slotIndex = nil
    for i, slot in ipairs(self.AbilitySlots) do
        if slot.AbilityId == nextAbilityId then
            slotIndex = i
            break
        end
    end
    
    if not slotIndex then return end
    
    -- Highlight the chain ability
    self:HighlightChainAbility(slotIndex, timeout)
end

-- PHASE 4: Highlight a chain ability
function AbilityBarUI:HighlightChainAbility(slotIndex, timeout)
    local slot = self.AbilitySlots[slotIndex]
    if not slot then return end
    
    -- Reset previous chain slots
    for _, s in ipairs(self.AbilitySlots) do
        if s.ChainHighlight then
            s.ChainHighlight.Visible = false
        end
    end
    
    -- Create highlight if it doesn't exist
    if not slot.ChainHighlight then
        slot.ChainHighlight = Instance.new("UIStroke")
        slot.ChainHighlight.Thickness = 3
        slot.ChainHighlight.Color = Color3.fromRGB(255, 215, 0) -- Gold color
        slot.ChainHighlight.Parent = slot.Frame
    end
    
    -- Show highlight
    slot.ChainHighlight.Visible = true
    
    -- Create flash effect
    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flash.BackgroundTransparency = 0.7
    flash.BorderSizePixel = 0
    flash.ZIndex = 5
    flash.Parent = slot.Frame
    
    -- Animate flash
    local flashTween = TweenService:Create(
        flash,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}
    )
    
    flashTween:Play()
    
    -- Remove flash after animation
    task.delay(0.3, function()
        if flash and flash.Parent then
            flash:Destroy()
        end
    end)
    
    -- Start timeout timer
    self:StartChainTimeout(slotIndex, timeout)
end

-- PHASE 4: Start chain timeout timer
function AbilityBarUI:StartChainTimeout(slotIndex, timeout)
    local slot = self.AbilitySlots[slotIndex]
    if not slot then return end
    
    -- Create timeout indicator if it doesn't exist
    if not slot.TimeoutIndicator then
        slot.TimeoutIndicator = Instance.new("Frame")
        slot.TimeoutIndicator.Name = "TimeoutIndicator"
        slot.TimeoutIndicator.Size = UDim2.new(1, 0, 0, 3)
        slot.TimeoutIndicator.Position = UDim2.new(0, 0, 1, -3)
        slot.TimeoutIndicator.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        slot.TimeoutIndicator.BorderSizePixel = 0
        slot.TimeoutIndicator.ZIndex = 4
        slot.TimeoutIndicator.Parent = slot.Frame
    end
    
    -- Reset size
    slot.TimeoutIndicator.Size = UDim2.new(1, 0, 0, 3)
    slot.TimeoutIndicator.Visible = true
    
    -- Animate timeout
    local timeoutTween = TweenService:Create(
        slot.TimeoutIndicator,
        TweenInfo.new(timeout, Enum.EasingStyle.Linear),
        {Size = UDim2.new(0, 0, 0, 3)}
    )
    
    timeoutTween:Play()
    
    -- Store tween to cancel if needed
    slot.TimeoutTween = timeoutTween
    
    -- Hide when complete
    timeoutTween.Completed:Connect(function()
        if slot.TimeoutIndicator then
            slot.TimeoutIndicator.Visible = false
        end
        if slot.ChainHighlight then
            slot.ChainHighlight.Visible = false
        end
    end)
end

-- PHASE 4: Clear chain state
function AbilityBarUI:ClearChainState()
    self.CurrentChain = nil
    
    -- Clear UI elements
    for _, slot in ipairs(self.AbilitySlots) do
        if slot.ChainHighlight then
            slot.ChainHighlight.Visible = false
        end
        if slot.TimeoutIndicator then
            slot.TimeoutIndicator.Visible = false
        end
        if slot.TimeoutTween then
            slot.TimeoutTween:Cancel()
            slot.TimeoutTween = nil
        end
    end
    
    print("[AbilityBarUI] Chain state cleared")
end

-- Clean up
function AbilityBarUI:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
    
    self.CooldownLoop = false
end

return AbilityBarUI
