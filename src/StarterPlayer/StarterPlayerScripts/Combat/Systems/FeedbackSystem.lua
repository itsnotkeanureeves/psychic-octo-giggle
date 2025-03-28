--[[
    FeedbackSystem.lua
    
    PURPOSE:
    Provides client-side visual and audio feedback for combat actions.
    Handles effects pooling, prioritization, and synchronization with server events.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local Constants = require(SharedPath:WaitForChild("Constants"))

local EFFECT = Constants.EFFECT
local EVENTS = Constants.EVENTS

-- FeedbackSystem implementation
local FeedbackSystem = {}
FeedbackSystem.__index = FeedbackSystem

function FeedbackSystem.new(eventSystem)
    local self = setmetatable({}, FeedbackSystem)
    self.EventSystem = eventSystem
    
    -- Effect objects pooling
    self.EffectPools = {} -- effectType -> { pooled objects }
    self.ActiveEffects = {} -- effectId -> effect object
    self.NextEffectId = 1
    
    -- Floating text pooling
    self.TextPool = {}
    self.ActiveTexts = {}
    self.NextTextId = 1
    
    -- Effect definitions
    self.EffectDefinitions = {}
    
    -- Audio objects pooling
    self.AudioPool = {}
    self.ActiveAudios = {}
    self.NextAudioId = 1
    
    -- Priority queue for effects
    self.MaxConcurrentEffects = 20 -- Tunable value
    self.EffectPriority = {
        CRITICAL = 10,
        HIGH = 8,
        MEDIUM = 5,
        LOW = 2
    }
    
    -- Create folders for organization
    self.EffectsFolder = Instance.new("Folder")
    self.EffectsFolder.Name = "CombatEffects"
    self.EffectsFolder.Parent = Workspace
    
    self.TextFolder = Instance.new("Folder")
    self.TextFolder.Name = "FloatingTexts"
    self.TextFolder.Parent = Workspace
    
    -- Register default effect definitions
    self:RegisterDefaultEffects()
    
    -- Connect to remote events
    self:ConnectToRemoteEvents()
    
    -- Clean up routine
    RunService.Heartbeat:Connect(function(dt)
        self:Update(dt)
    end)
    
    print("[FeedbackSystem] Initialized")
    
    return self
end

-- Register default visual effects
function FeedbackSystem:RegisterDefaultEffects()
    -- Ability effects
    self:RegisterEffectDefinition("ABILITY_CAST", {
        type = "Part",
        duration = 0.5,
        size = Vector3.new(1, 1, 1),
        color = Color3.fromRGB(0, 150, 255),
        priority = "MEDIUM"
    })
    
    -- Hit effects
    self:RegisterEffectDefinition("MELEE_HIT", {
        type = "Part",
        duration = 0.5,
        size = Vector3.new(1, 1, 1),
        color = Color3.fromRGB(255, 255, 255),
        priority = "MEDIUM"
    })
    
    self:RegisterEffectDefinition("FIRE_HIT", {
        type = "Part",
        duration = 0.8,
        size = Vector3.new(2, 2, 2),
        color = Color3.fromRGB(255, 100, 0),
        priority = "HIGH"
    })
    
    -- Default effect for any ability impact
    self:RegisterEffectDefinition("ABILITY_IMPACT", {
        type = "Part",
        duration = 0.5,
        size = Vector3.new(1, 1, 1),
        color = Color3.fromRGB(255, 255, 0),
        priority = "MEDIUM"
    })
    
    -- Fire specific effects
    self:RegisterEffectDefinition("FIRE_IMPACT", {
        type = "Part",
        duration = 0.8,
        size = Vector3.new(1.5, 1.5, 1.5),
        color = Color3.fromRGB(255, 100, 0),
        priority = "MEDIUM"
    })
    
    -- Condition effects
    self:RegisterEffectDefinition("CONDITION_APPLY", {
        type = "Part",
        duration = 0.5,
        size = Vector3.new(1, 1, 1),
        color = Color3.fromRGB(150, 150, 255),
        priority = "MEDIUM"
    })
    
    self:RegisterEffectDefinition("BURNING_APPLY", {
        type = "Part",
        duration = 0.5,
        size = Vector3.new(1, 1, 1),
        color = Color3.fromRGB(255, 100, 0),
        priority = "MEDIUM"
    })
    
    -- Floating text types
    self:RegisterEffectDefinition("DAMAGE_TEXT", {
        type = "Text",
        duration = 1.2,
        size = 24,
        color = Color3.fromRGB(255, 0, 0),
        criticalSize = 32,
        criticalColor = Color3.fromRGB(255, 150, 0),
        priority = "HIGH"
    })
    
    self:RegisterEffectDefinition("HEALING_TEXT", {
        type = "Text",
        duration = 1.2,
        size = 24,
        color = Color3.fromRGB(0, 255, 0),
        criticalSize = 32,
        criticalColor = Color3.fromRGB(150, 255, 150),
        priority = "MEDIUM"
    })
    
    print("[FeedbackSystem] Registered default effects")
end

-- Register a new effect definition
function FeedbackSystem:RegisterEffectDefinition(effectId, definition)
    self.EffectDefinitions[effectId] = definition
end

-- Connect to remote events for server feedback
function FeedbackSystem:ConnectToRemoteEvents()
    -- Ability execution event
    local abilityExecution = ReplicatedStorage:WaitForChild("Combat_AbilityExecution")
    abilityExecution.OnClientEvent:Connect(function(entityId, abilityId, position, direction, targets)
        print("[FeedbackSystem] Ability execution received:", abilityId)
        self:OnAbilityExecution(entityId, abilityId, position, direction, targets)
    end)
    
    -- Damage event
    local damageEvent = ReplicatedStorage:WaitForChild("Combat_DamageEvent")
    damageEvent.OnClientEvent:Connect(function(eventType, data)
        print("[FeedbackSystem] Damage event received:", eventType)
        if eventType == EVENTS.DAMAGE_DEALT then
            self:OnDamageTaken(data)
        elseif eventType == EVENTS.HEALING_APPLIED then
            self:OnHealingApplied(data)
        end
    end)
    
    -- Condition update event
    local conditionEvent = ReplicatedStorage:WaitForChild("Combat_ConditionUpdate")
    conditionEvent.OnClientEvent:Connect(function(eventType, data)
        if eventType == EVENTS.CONDITION_APPLIED then
            self:OnConditionApplied(data)
        elseif eventType == EVENTS.CONDITION_REMOVED then
            self:OnConditionRemoved(data)
        end
    end)
    
    print("[FeedbackSystem] Connected to remote events")
end

-- Handle ability execution feedback
function FeedbackSystem:OnAbilityExecution(entityId, abilityId, position, direction, targets)
    -- Safely handle possible nil targets
    if type(targets) ~= "table" then
        print("[FeedbackSystem] Warning: Received nil or invalid targets for ability", abilityId)
        targets = {}
    end
    
    print("[FeedbackSystem] Processing ability execution:", abilityId, "with", #targets, "targets")
    
    -- Map ability types to effect types
    local abilityEffects = {
        ["FIREBALL"] = {
            impactEffect = "FIRE_IMPACT"
        },
        ["SLASH"] = {
            impactEffect = "MELEE_HIT"
        },
        ["HEAL"] = {
            impactEffect = "HEAL_IMPACT"
        }
    }
    
    -- Get entity/character for visual attachment
    local character = self:FindEntityModel(entityId)
    if not character then
        print("[FeedbackSystem] Could not find entity model for ID:", entityId)
        return
    end
    
    -- Create default impact effect if none defined for this ability
    local impactEffect = "ABILITY_IMPACT"
    if abilityEffects[abilityId] and abilityEffects[abilityId].impactEffect then
        impactEffect = abilityEffects[abilityId].impactEffect
    end
    
    -- Play impact effects for each target
    for _, target in ipairs(targets) do
        local targetModel = self:FindEntityModel(target.entityId)
        if targetModel and targetModel.PrimaryPart then
            local targetPos = targetModel.PrimaryPart.Position
            self:PlayEffect(impactEffect, targetPos)
            
            -- Flash the target model to indicate it was hit
            self:FlashModel(targetModel)
        elseif target.position then
            self:PlayEffect(impactEffect, target.position)
        else
            print("[FeedbackSystem] No position for target:", target.entityId)
        end
    end
end

-- Helper function to find an entity model
function FeedbackSystem:FindEntityModel(entityId)
    if not entityId then return nil end
    
    -- Try to find model directly by name
    local model = workspace:FindFirstChild(entityId)
    if model then return model end
    
    -- Try to find model with attribute
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("EntityId") == entityId then
            return child
        end
    end
    
    -- Search in the entire workspace for an object with matching name
    for _, child in ipairs(workspace:GetDescendants()) do
        if child.Name == entityId and child:IsA("Model") then
            return child
        end
    end
    
    -- If nothing found, try to get it from NPC models (specific to this implementation)
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child.Name:match("Target") then
            -- This is likely an NPC
            if child:GetAttribute("EntityId") == entityId then
                return child
            end
        end
    end
    
    return nil
end

-- Flash a model to indicate it was hit
function FeedbackSystem:FlashModel(model)
    if not model then return end
    
    -- Create a highlight effect
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.new(1, 0, 0)
    highlight.OutlineColor = Color3.new(1, 1, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = model
    
    -- Remove highlight after short delay
    task.delay(0.2, function()
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end)
end

-- Handle damage feedback
function FeedbackSystem:OnDamageTaken(data)
    if not data then
        print("[FeedbackSystem] Received nil damage data")
        return
    end
    
    -- Extract data
    local targetId = data.targetId
    local amount = data.amount or 0
    local isCritical = data.isCritical or false
    local damageType = data.damageType or EFFECT.DAMAGE_TYPES.PHYSICAL
    
    print("[FeedbackSystem] Processing damage:", amount, "to", targetId)
    
    -- Find target character
    local character = self:FindEntityModel(targetId)
    
    if character then
        -- Find a suitable position for the effect
        local effectPosition = nil
        
        if character.PrimaryPart then
            effectPosition = character.PrimaryPart.Position + Vector3.new(0, 2, 0)
        else
            -- Try to find Head or other suitable part
            local head = character:FindFirstChild("Head")
            if head then
                effectPosition = head.Position + Vector3.new(0, 1, 0)
            else
                -- Use the character's position
                effectPosition = character:GetPivot().Position + Vector3.new(0, 2, 0)
            end
        end
        
        if effectPosition then
            -- Show damage number
            self:ShowFloatingText(effectPosition, tostring(amount), {
                isCritical = isCritical,
                color = Color3.fromRGB(255, 0, 0),
                criticalColor = Color3.fromRGB(255, 150, 0)
            })
            
            -- Flash the model
            self:FlashModel(character)
            
            -- Play hit effect based on damage type
            -- Convert damage type to uppercase for effect type matching
            local effectType = (damageType and string.upper(damageType) .. "_HIT") or "MELEE_HIT"
            
            -- Fall back to default if no specific effect defined
            if not self.EffectDefinitions[effectType] then
                effectType = "MELEE_HIT"
            end
            
            self:PlayEffect(effectType, effectPosition)
        end
    else
        print("[FeedbackSystem] Could not find entity model for damage target:", targetId)
    end
end

-- Handle healing feedback
function FeedbackSystem:OnHealingApplied(data)
    if not data then return end
    
    -- Extract data
    local targetId = data.targetId
    local amount = data.amount or 0
    local isCritical = data.isCritical or false
    
    -- Find target character
    local character = self:FindEntityModel(targetId)
    
    if character and character.PrimaryPart then
        -- Show healing number
        local textPosition = character.PrimaryPart.Position + Vector3.new(0, 2, 0)
        
        self:ShowFloatingText(textPosition, tostring(amount), {
            isCritical = isCritical,
            color = Color3.fromRGB(0, 255, 0),
            criticalColor = Color3.fromRGB(150, 255, 150),
            direction = Vector3.new(0, 1, 0) -- Healing numbers float upward
        })
        
        -- Play healing effect
        self:PlayEffect("HEALING_IMPACT", character.PrimaryPart.Position)
    end
end

-- Handle condition application feedback
function FeedbackSystem:OnConditionApplied(data)
    if not data then return end
    
    -- Extract data
    local targetId = data.targetId
    local conditionId = data.conditionId or ""
    
    -- Find target character
    local character = self:FindEntityModel(targetId)
    
    if character and character.PrimaryPart then
        -- Play condition apply effect
        local effectType = conditionId and (conditionId .. "_APPLY") or "CONDITION_APPLY"
        
        -- Fall back to default if no specific effect defined
        if not self.EffectDefinitions[effectType] then
            effectType = "CONDITION_APPLY"
        end
        
        self:PlayEffect(effectType, character.PrimaryPart.Position)
    end
end

-- Handle condition removal feedback
function FeedbackSystem:OnConditionRemoved(data)
    if not data then return end
    
    -- Extract data
    local targetId = data.targetId
    local conditionId = data.conditionId or ""
    
    -- Find target character
    local character = self:FindEntityModel(targetId)
    
    if character and character.PrimaryPart then
        -- Play condition remove effect
        local effectType = conditionId and (conditionId .. "_REMOVE") or "CONDITION_REMOVE"
        
        -- Fall back to default if no specific effect defined
        if not self.EffectDefinitions[effectType] then
            effectType = "CONDITION_REMOVE"
        end
        
        self:PlayEffect(effectType, character.PrimaryPart.Position)
    end
end

-- Play a visual effect
function FeedbackSystem:PlayEffect(effectType, position, options)
    options = options or {}
    
    -- Get effect definition
    local definition = self.EffectDefinitions[effectType]
    if not definition then
        print("[FeedbackSystem] Unknown effect type:", effectType, "- using default")
        
        -- Fall back to a default part
        definition = {
            type = "Part",
            duration = 0.5,
            size = Vector3.new(1, 1, 1),
            color = Color3.fromRGB(255, 0, 0),
            priority = "MEDIUM"
        }
    end
    
    -- Get or create effect object
    local effectObject = self:GetEffectFromPool(effectType)
    if not effectObject then
        print("[FeedbackSystem] Failed to create effect object for:", effectType)
        return nil
    end
    
    -- Set up effect
    effectObject.Position = position
    
    -- Apply options
    local scale = options.scale or 1
    if definition.size then
        effectObject.Size = definition.size * scale
    else
        effectObject.Size = Vector3.new(1, 1, 1) * scale
    end
    
    local color = options.color or definition.color or Color3.fromRGB(255, 255, 255)
    if effectObject:IsA("BasePart") then
        effectObject.Color = color
    end
    
    -- Make effect visible
    effectObject.Parent = self.EffectsFolder
    
    -- Add to active effects
    local effectId = "effect_" .. self.NextEffectId
    self.NextEffectId = self.NextEffectId + 1
    
    self.ActiveEffects[effectId] = {
        object = effectObject,
        effectType = effectType,
        startTime = time(),
        duration = definition.duration or 1
    }
    
    -- Play sound if defined
    if definition.sound then
        self:PlaySound(definition.sound, position)
    end
    
    -- Return effect ID
    return effectId
end

-- Get an effect object from the pool or create a new one
function FeedbackSystem:GetEffectFromPool(effectType)
    -- Initialize pool if needed
    if not self.EffectPools[effectType] then
        self.EffectPools[effectType] = {}
    end
    
    -- Check for available pooled object
    if #self.EffectPools[effectType] > 0 then
        return table.remove(self.EffectPools[effectType])
    end
    
    -- Create new effect object
    local definition = self.EffectDefinitions[effectType]
    if not definition then
        -- Fall back to a default part
        definition = {
            type = "Part",
            duration = 0.5, 
            size = Vector3.new(1, 1, 1),
            color = Color3.fromRGB(255, 0, 0),
            priority = "MEDIUM"
        }
    end
    
    -- Create based on type
    local part = Instance.new("Part")
    part.Name = effectType
    part.Anchored = true
    part.CanCollide = false
    part.Size = definition.size or Vector3.new(1, 1, 1)
    part.Shape = Enum.PartType.Ball
    part.Color = definition.color or Color3.fromRGB(255, 0, 0)
    part.Transparency = 0.3
    part.Material = Enum.Material.Neon
    
    return part
end

-- Return an effect to the pool
function FeedbackSystem:ReturnEffectToPool(effectId)
    local effect = self.ActiveEffects[effectId]
    if not effect then
        return
    end
    
    local effectObject = effect.object
    local effectType = effect.effectType
    
    -- Reset object
    effectObject.Parent = nil
    
    -- Add to pool
    if not self.EffectPools[effectType] then
        self.EffectPools[effectType] = {}
    end
    
    table.insert(self.EffectPools[effectType], effectObject)
    
    -- Remove from active effects
    self.ActiveEffects[effectId] = nil
end

-- Stop an active effect
function FeedbackSystem:StopEffect(effectId)
    local effect = self.ActiveEffects[effectId]
    if not effect then
        return false
    end
    
    self:ReturnEffectToPool(effectId)
    return true
end

-- Show floating text (like damage numbers)
function FeedbackSystem:ShowFloatingText(position, text, options)
    options = options or {}
    
    -- Create BillboardGui for text
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "FloatingText"
    billboardGui.AlwaysOnTop = true
    billboardGui.Size = UDim2.new(0, 100, 0, 100)
    billboardGui.StudsOffset = Vector3.new(0, 0, 0)
    billboardGui.LightInfluence = 0
    billboardGui.MaxDistance = 100
    billboardGui.Adornee = nil -- We'll position it in 3D space
    billboardGui.Parent = self.TextFolder
    billboardGui.Active = true
    
    -- Create text label
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "TextLabel"
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Text = text
    textLabel.Parent = billboardGui
    
    -- Apply options
    local isCritical = options.isCritical or false
    local size = isCritical and (options.criticalSize or 32) or (options.size or 24)
    local color = isCritical and (options.criticalColor or Color3.fromRGB(255, 150, 0)) or (options.color or Color3.fromRGB(255, 0, 0))
    
    textLabel.TextSize = size
    textLabel.TextColor3 = color
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.TextStrokeTransparency = 0
    
    -- Position the Billboard
    billboardGui.StudsOffset = Vector3.new(0, 0, 0)
    billboardGui.Adornee = workspace.Terrain
    billboardGui.Enabled = true
    
    -- Create a part to position the text
    local part = Instance.new("Part")
    part.Name = "TextPosition"
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Position = position
    part.Parent = self.TextFolder
    
    -- Set the billboard to the part
    billboardGui.Adornee = part
    
    -- Animate the text
    local duration = options.duration or 1.2
    local direction = options.direction or Vector3.new(0, 1, 0)
    
    task.spawn(function()
        local startTime = time()
        local endTime = startTime + duration
        
        while time() < endTime and part.Parent ~= nil do
            local elapsed = (time() - startTime) / duration
            
            -- Move upward
            part.Position = position + direction * (elapsed * 3)
            
            -- Fade out
            textLabel.TextTransparency = elapsed
            textLabel.TextStrokeTransparency = elapsed
            
            task.wait()
        end
        
        -- Clean up
        if part.Parent ~= nil then
            part:Destroy()
        end
        if billboardGui.Parent ~= nil then
            billboardGui:Destroy()
        end
    end)
end

-- Play a sound effect
function FeedbackSystem:PlaySound(soundId, position, options)
    options = options or {}
    
    -- Create a sound instance
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = options.volume or 0.5
    sound.RollOffMaxDistance = 100
    sound.RollOffMinDistance = 5
    
    -- Position the sound
    if position then
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Size = Vector3.new(0.1, 0.1, 0.1)
        part.Transparency = 1
        part.Position = position
        part.Parent = workspace
        
        sound.Parent = part
        
        -- Clean up after sound finished
        sound.Ended:Connect(function()
            part:Destroy()
        end)
    else
        sound.Parent = workspace
    end
    
    -- Play the sound
    sound:Play()
    
    -- Return the sound object
    return sound
end

-- Update function
function FeedbackSystem:Update(dt)
    -- Update active effects
    for id, effect in pairs(self.ActiveEffects) do
        if time() - effect.startTime >= effect.duration then
            self:ReturnEffectToPool(id)
        end
    end
end

-- Clean up function
function FeedbackSystem:Destroy()
    -- Stop and clean up all active effects
    for id, _ in pairs(self.ActiveEffects) do
        self:StopEffect(id)
    end
    
    -- Clean up folders
    if self.EffectsFolder then
        self.EffectsFolder:Destroy()
    end
    
    if self.TextFolder then
        self.TextFolder:Destroy()
    end
end

return FeedbackSystem