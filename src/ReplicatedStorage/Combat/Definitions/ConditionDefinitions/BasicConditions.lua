--[[
    BasicConditions.lua
    
    PURPOSE:
    Defines a set of basic conditions (buffs/debuffs) that demonstrate the combat system's features.
    
    CONDITION CATEGORIES:
    - DAMAGE_EFFECT: Conditions that deal damage over time
    - HEALING_EFFECT: Conditions that heal over time
    - BUFF: Positive effects that enhance the target
    - DEBUFF: Negative effects that hinder the target
    - CONTROL: Effects that limit movement or actions
    - STATE: Special states (casting, stealth, etc.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local Constants = require(SharedPath:WaitForChild("Constants"))

local EFFECT = Constants.EFFECT
local CONDITION = Constants.CONDITION

local EffectSystem = nil -- Will be set by the ConditionSystem when loading

local BasicConditions = {
    -- ======== DAMAGE EFFECTS ======== --
    
    -- Burning (fire DoT)
    BURNING = {
        name = "Burning",
        description = "Taking fire damage over time",
        category = "DAMAGE_EFFECT",
        isDebuff = true,
        
        -- UI properties
        priority = 7,
        icon = "rbxassetid://12345694", -- Placeholder asset ID
        color = Color3.fromRGB(255, 60, 30),
        
        -- Stack behavior
        maxStacks = 5,
        defaultDuration = 4,
        stackBehavior = CONDITION.STACK_BEHAVIORS.REFRESH, -- Refresh duration on reapplication
        removeStacksOnExpire = 1, -- Remove 1 stack when duration expires
        tickRate = 1, -- Tick every 1 second
        
        -- Condition interactions
        prevents = {"FREEZING"},
        removes = {"CHILLED"},
        
        -- Event handlers
        handlers = {
            -- Called when condition is applied or stacks added
            onApply = function(params, conditionSystem)
                -- Visual/sound effects could be triggered here
                print("[BURNING] onApply called for target:", params.targetId, 
                      "stacks:", params.stacks, 
                      "sourceId:", params.data.sourceId)
            end,
            
            -- Called when condition is completely removed
            onRemove = function(params, conditionSystem)
                -- Clean-up effects
                print("[BURNING] onRemove called for target:", params.targetId)
            end,
            
            -- Called when duration expires
            onExpire = function(params, conditionSystem)
                -- Nothing special on expiry
                print("[BURNING] onExpire called for target:", params.targetId)
            end,
            
            -- Called periodically based on tickRate
            onTick = function(params, conditionSystem)
                -- Deal damage on tick
                local targetId = params.targetId
                local stacks = params.stacks
                local data = params.data or {}
                
                -- Get the effect system reference
                local effectSystem = conditionSystem.EffectSystem
                
                -- Calculate damage based on stacks and scaling
                local baseDamage = data.damagePerTick or 5
                local focusScaling = data.focusScaling or 0.2
                
                print("[BURNING] onTick executing for target:", targetId, 
                      "stacks:", stacks, 
                      "baseDamage:", baseDamage, 
                      "sourceId:", data.sourceId)
                
                -- Apply damage using standardized effect type
                local success, result = effectSystem:ExecuteEffect(EFFECT.TYPES.APPLY_DAMAGE, {
                    sourceId = data.sourceId,
                    targetId = targetId,
                    amount = baseDamage * stacks,
                    damageType = EFFECT.DAMAGE_TYPES.FIRE,
                    isPeriodic = true,
                    conditionId = CONDITION.IDS.BURNING
                })
                
                print("[BURNING] APPLY_DAMAGE result:", success, result and result.damage)
            end
        }
    },
    
    -- Poisoned (poison DoT)
    POISONED = {
        name = "Poisoned",
        description = "Taking poison damage over time",
        category = "DAMAGE_EFFECT",
        isDebuff = true,
        
        -- UI properties
        priority = 7,
        icon = "rbxassetid://12345695", -- Placeholder asset ID
        color = Color3.fromRGB(30, 180, 30),
        
        -- Stack behavior
        maxStacks = 5,
        defaultDuration = 8,
        stackBehavior = CONDITION.STACK_BEHAVIORS.ADD, -- Add stacks on reapplication
        removeStacksOnExpire = 1,
        tickRate = 2, -- Tick every 2 seconds
        
        -- Event handlers
        handlers = {
            onTick = function(params, conditionSystem)
                -- Deal damage on tick
                local targetId = params.targetId
                local stacks = params.stacks
                local data = params.data
                
                local effectSystem = conditionSystem.EffectSystem
                
                local baseDamage = data.damagePerTick or 5
                local focusScaling = data.focusScaling or 0.3
                
                effectSystem:ExecuteEffect(EFFECT.TYPES.APPLY_DAMAGE, {
                    sourceId = data.sourceId,
                    targetId = targetId,
                    amount = baseDamage * stacks,
                    damageType = EFFECT.DAMAGE_TYPES.POISON,
                    isPeriodic = true,
                    conditionId = CONDITION.IDS.POISONED
                })
            end,
            
            onDamaged = function(params, conditionSystem)
                -- Poison increases physical damage taken
                if params.damageType == EFFECT.DAMAGE_TYPES.PHYSICAL then
                    local stacks = params.stacks
                    local amount = params.amount
                    
                    -- 5% increased physical damage per stack
                    params.amount = amount * (1 + (0.05 * stacks))
                end
                
                return params
            end
        }
    },
    
    -- Electrified (stun + DoT)
    ELECTRIFIED = {
        name = "Electrified",
        description = "Stunned and taking lightning damage",
        category = "CONTROL",
        isDebuff = true,
        
        -- UI properties
        priority = 9,
        icon = "rbxassetid://12345696", -- Placeholder asset ID
        color = Color3.fromRGB(100, 100, 255),
        
        -- Stack behavior
        maxStacks = 1,
        defaultDuration = 3,
        stackBehavior = CONDITION.STACK_BEHAVIORS.REFRESH,
        tickRate = 1,
        
        -- Event handlers
        handlers = {
            onApply = function(params, conditionSystem)
                -- Apply stun effect through a stat modifier
                local statSystem = conditionSystem.StatSystem
                
                params.stunModifier = statSystem:ApplyStatModifier(params.targetId, {
                    id = "ELECTRIFIED_STUN_" .. params.targetId,
                    source = "CONDITION",
                    flatModifiers = {},
                    percentModifiers = {
                        movementSpeed = 0 -- 0% movement speed (complete stun)
                    },
                    duration = params.duration
                })
            end,
            
            onRemove = function(params, conditionSystem)
                -- Stun modifier automatically removed by duration
            end,
            
            onTick = function(params, conditionSystem)
                -- Deal damage on tick
                local targetId = params.targetId
                local data = params.data
                
                local effectSystem = conditionSystem.EffectSystem
                
                effectSystem:ExecuteEffect(EFFECT.TYPES.APPLY_DAMAGE, {
                    sourceId = data.sourceId,
                    targetId = targetId,
                    amount = 10,
                    damageType = EFFECT.DAMAGE_TYPES.LIGHTNING,
                    isPeriodic = true,
                    conditionId = "ELECTRIFIED"
                })
            end
        }
    },
    
    -- ======== DEBUFFS ======== --
    
    -- Weakened (reduced damage)
    WEAKENED = {
        name = "Weakened",
        description = "Deals reduced damage",
        category = "DEBUFF",
        isDebuff = true,
        
        -- UI properties
        priority = 6,
        icon = "rbxassetid://12345697", -- Placeholder asset ID
        color = Color3.fromRGB(150, 150, 150),
        
        -- Stack behavior
        maxStacks = 3,
        defaultDuration = 5,
        stackBehavior = CONDITION.STACK_BEHAVIORS.REFRESH,
        
        -- Event handlers
        handlers = {
            onApply = function(params, conditionSystem)
                -- Apply power reduction through a stat modifier
                local statSystem = conditionSystem.StatSystem
                local stacks = params.stacks
                
                -- 10% power reduction per stack
                local reduction = 100 - (10 * stacks)
                
                params.statModifier = statSystem:ApplyStatModifier(params.targetId, {
                    id = "WEAKENED_MOD_" .. params.targetId,
                    source = "CONDITION",
                    flatModifiers = {},
                    percentModifiers = {
                        power = reduction, -- Reduced power
                        focus = reduction -- Reduced focus too
                    },
                    duration = params.duration
                })
            end
        }
    },
    
    -- Chilled (slowed)
    CHILLED = {
        name = "Chilled",
        description = "Movement and attack speed reduced",
        category = "DEBUFF",
        isDebuff = true,
        
        -- UI properties
        priority = 6,
        icon = "rbxassetid://12345698", -- Placeholder asset ID
        color = Color3.fromRGB(100, 200, 255),
        
        -- Stack behavior
        maxStacks = 5,
        defaultDuration = 6,
        stackBehavior = CONDITION.STACK_BEHAVIORS.ADD,
        
        -- Condition interactions
        prevents = {"BURNING"},
        
        -- Transformation rules
        transform = {
            condition = function(params)
                -- Transform to FROZEN when reaching 5 stacks
                return params.stacks >= 5
            end,
            targetCondition = "FROZEN",
            preserveStacks = false, -- Don't preserve stacks
            data = {} -- Additional data for FROZEN
        },
        
        -- Event handlers
        handlers = {
            onApply = function(params, conditionSystem)
                -- Apply slow effect through a stat modifier
                local statSystem = conditionSystem.StatSystem
                local stacks = params.stacks
                
                -- 10% slow per stack (down to 50% at max stacks)
                local speedMultiplier = 100 - math.min(50, (10 * stacks))
                
                params.statModifier = statSystem:ApplyStatModifier(params.targetId, {
                    id = "CHILLED_SLOW_" .. params.targetId,
                    source = "CONDITION",
                    flatModifiers = {},
                    percentModifiers = {
                        movementSpeed = speedMultiplier, -- Reduced movement speed
                        attackSpeed = speedMultiplier -- Reduced attack speed
                    },
                    duration = params.duration
                })
            end
        }
    },
    
    -- Frozen (complete immobilization)
    FROZEN = {
        name = "Frozen",
        description = "Completely immobilized and unable to act",
        category = "CONTROL",
        isDebuff = true,
        
        -- UI properties
        priority = 9,
        icon = "rbxassetid://12345699", -- Placeholder asset ID
        color = Color3.fromRGB(150, 230, 255),
        
        -- Stack behavior
        maxStacks = 1,
        defaultDuration = 3,
        stackBehavior = CONDITION.STACK_BEHAVIORS.REFRESH,
        
        -- Event handlers
        handlers = {
            onApply = function(params, conditionSystem)
                -- Apply freeze effect through stat modifiers
                local statSystem = conditionSystem.StatSystem
                
                params.freezeModifier = statSystem:ApplyStatModifier(params.targetId, {
                    id = "FROZEN_IMMOBILIZE_" .. params.targetId,
                    source = "CONDITION",
                    flatModifiers = {},
                    percentModifiers = {
                        movementSpeed = 0, -- 0% movement speed (complete immobilization)
                        attackSpeed = 0, -- 0% attack speed (can't attack)
                        castingSpeed = 0 -- 0% casting speed (can't cast)
                    },
                    duration = params.duration
                })
            end,
            
            onDamaged = function(params, conditionSystem)
                -- Check if damage is fire damage
                if params.damageType == EFFECT.DAMAGE_TYPES.FIRE then
                    -- Fire damage breaks freeze
                    conditionSystem:RemoveCondition(params.targetId, "FROZEN", true)
                    
                    -- Apply Chilled instead (2 stacks)
                    conditionSystem:ApplyCondition(params.targetId, "CHILLED", 2, 3, {
                        sourceId = params.sourceId
                    })
                end
                
                return params
            end
        }
    },
    
    -- ======== HEALING EFFECTS ======== --
    
    -- Regeneration (healing over time)
    REGENERATION = {
        name = "Regeneration",
        description = "Restoring health over time",
        category = "HEALING_EFFECT",
        isDebuff = false,
        
        -- UI properties
        priority = 5,
        icon = "rbxassetid://12345700", -- Placeholder asset ID
        color = Color3.fromRGB(100, 255, 100),
        
        -- Stack behavior
        maxStacks = 3,
        defaultDuration = 6,
        stackBehavior = CONDITION.STACK_BEHAVIORS.REFRESH,
        tickRate = 1, -- Heal every second
        
        -- Event handlers
        handlers = {
            onTick = function(params, conditionSystem)
                -- Apply healing on tick
                local targetId = params.targetId
                local stacks = params.stacks
                local data = params.data
                
                local effectSystem = conditionSystem.EffectSystem
                
                local baseHealing = data.healingPerTick or 5
                local healingScaling = data.healingScaling or 0.3
                
                effectSystem:ExecuteEffect(EFFECT.TYPES.APPLY_HEALING, {
                    sourceId = data.sourceId,
                    targetId = targetId,
                    amount = baseHealing * stacks,
                    isPeriodic = true,
                    conditionId = CONDITION.IDS.REGENERATION
                })
            end
        }
    },
    
    -- ======== BUFFS ======== --
    
    -- Protected (damage reduction)
    PROTECTED = {
        name = "Protected",
        description = "Taking reduced damage from all sources",
        category = "BUFF",
        isDebuff = false,
        
        -- UI properties
        priority = 8,
        icon = "rbxassetid://12345701", -- Placeholder asset ID
        color = Color3.fromRGB(200, 200, 255),
        
        -- Stack behavior
        maxStacks = 1,
        defaultDuration = 10,
        stackBehavior = CONDITION.STACK_BEHAVIORS.REFRESH,
        
        -- Event handlers
        handlers = {
            onApply = function(params, conditionSystem)
                -- Apply defense boost through a stat modifier
                local statSystem = conditionSystem.StatSystem
                
                params.statModifier = statSystem:ApplyStatModifier(params.targetId, {
                    id = "PROTECTED_MOD_" .. params.targetId,
                    source = "CONDITION",
                    flatModifiers = {
                        defense = 20 -- Flat defense boost
                    },
                    percentModifiers = {},
                    duration = params.duration
                })
            end,
            
            onDamaged = function(params, conditionSystem)
                -- Reduce all damage by 20%
                params.amount = params.amount * 0.8
                return params
            end
        }
    },
    
    -- ======== STATE CONDITIONS ======== --
    
    -- Casting (ability cast in progress)
    CASTING = {
        name = "Casting",
        description = "Casting an ability",
        category = "STATE",
        isDebuff = false,
        
        -- UI properties
        priority = 10,
        icon = "rbxassetid://12345702", -- Placeholder asset ID
        color = Color3.fromRGB(200, 200, 100),
        
        -- Stack behavior
        maxStacks = 1,
        defaultDuration = 3, -- Default, will be overridden by ability cast time
        stackBehavior = CONDITION.STACK_BEHAVIORS.REFRESH,
        
        -- Event handlers
        handlers = {
            onApply = function(params, conditionSystem)
                -- Apply casting visual effects if needed
            end,
            
            onRemove = function(params, conditionSystem)
                -- Remove casting visual effects
            end,
            
            onDamaged = function(params, conditionSystem)
                -- Check if casting can be interrupted
                if params.data and params.data.interruptible then
                    if params.amount > 5 then
                        -- Trigger cast interrupt through event system
                        conditionSystem.EventSystem:Publish("CAST_INTERRUPTED", {
                            targetId = params.targetId,
                            abilityId = params.data.abilityId,
                            damageAmount = params.amount,
                            sourceId = params.sourceId
                        })
                    end
                end
                
                return params
            end
        }
    },
    
    -- Dashing (movement ability active)
    DASHING = {
        name = "Dashing",
        description = "Dashing forward with increased speed",
        category = "STATE",
        isDebuff = false,
        
        -- UI properties
        priority = 9,
        icon = "rbxassetid://12345703", -- Placeholder asset ID
        color = Color3.fromRGB(255, 255, 150),
        
        -- Stack behavior
        maxStacks = 1,
        defaultDuration = 0.5,
        stackBehavior = CONDITION.STACK_BEHAVIORS.REFRESH,
        
        -- Event handlers
        handlers = {
            onApply = function(params, conditionSystem)
                -- Apply movement speed boost
                local statSystem = conditionSystem.StatSystem
                
                params.dashModifier = statSystem:ApplyStatModifier(params.targetId, {
                    id = "DASH_SPEED_" .. params.targetId,
                    source = "CONDITION",
                    flatModifiers = {},
                    percentModifiers = {
                        movementSpeed = 300 -- 3x movement speed
                    },
                    duration = params.duration
                })
            end,
            
            onDamaged = function(params, conditionSystem)
                -- Immune to damage while dashing
                params.amount = 0
                return params
            end
        }
    },
    
    -- Stealth (invisibility)
    STEALTH = {
        name = "Stealth",
        description = "Invisible to enemies",
        category = "STATE",
        isDebuff = false,
        
        -- UI properties
        priority = 8,
        icon = "rbxassetid://12345704", -- Placeholder asset ID
        color = Color3.fromRGB(100, 100, 100),
        
        -- Stack behavior
        maxStacks = 1,
        defaultDuration = 15,
        stackBehavior = CONDITION.STACK_BEHAVIORS.REFRESH,
        
        -- Event handlers
        handlers = {
            onApply = function(params, conditionSystem)
                -- Apply stealth visual effect
                -- In a real implementation, would modify character transparency
                -- and handle visibility to different teams
            end,
            
            onRemove = function(params, conditionSystem)
                -- Remove stealth visual effect
            end,
            
            onDealDamage = function(params, conditionSystem)
                -- Break stealth when dealing damage
                conditionSystem:RemoveCondition(params.sourceId, "STEALTH", true)
                
                -- Increase damage while breaking stealth
                params.amount = params.amount * 1.5
                return params
            end
        }
    }
}

-- Set up references when loaded by the condition system
function BasicConditions:Initialize(effectSystemRef)
    print("[BasicConditions] Initialize called with effectSystemRef:", effectSystemRef ~= nil)
    EffectSystem = effectSystemRef
end

return BasicConditions
