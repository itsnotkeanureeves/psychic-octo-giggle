--[[
    CombatTypes.lua
    
    PURPOSE:
    Defines the standard data structures used throughout the combat system.
    Provides samples and documentation for each data type.
    
    NOTE:
    This file is for documentation purposes only and does not provide any functionality.
    It serves as a reference for how data should be structured in the combat system.
]]

local CombatTypes = {}

--[[
    EntityData - Structure for entity information
    Used by the EntitySystem to store entity data
]]
CombatTypes.EntityData = {
    id = "ENTITY_ID", -- Unique identifier (string)
    type = "PLAYER", -- Entity type (string) - PLAYER, NPC
    name = "Entity Name", -- Display name (string)
    
    -- Core references
    instance = nil, -- Roblox instance (Player or Model)
    character = nil, -- Character model (Model)
    humanoid = nil, -- Humanoid (Humanoid)
    rootPart = nil, -- HumanoidRootPart (Part)
    
    -- Basic attributes
    attributes = {
        -- Resource attributes
        health = 100,
        maxHealth = 100,
        energy = 100,
        maxEnergy = 100,
        
        -- State flags
        isAlive = true,
        isBlocking = false,
        isInvulnerable = false,
    },
    
    -- Team/faction data
    team = "TEAM_ID", -- Team identifier (string)
    faction = "FACTION_ID", -- Faction identifier (string)
    
    -- Level information
    level = 1 -- Entity level
}

--[[
    AbilityData - Structure for ability definitions
    Used by the AbilitySystem to define abilities
]]
CombatTypes.AbilityData = {
    id = "ABILITY_ID", -- Unique identifier (string)
    name = "Ability Name", -- Display name (string)
    description = "Description text", -- Description (string)
    category = "ATTACK", -- Category (string) - ATTACK, DEFENSE, UTILITY, etc.
    icon = "rbxassetid://12345678", -- Icon asset ID (string)
    
    -- Casting properties
    castTime = 0, -- Cast time in seconds (number)
    interruptible = true, -- Whether casting can be interrupted (boolean)
    animation = "ANIMATION_ID", -- Animation to play (string)
    
    -- Resource properties
    resourceCost = {
        type = "ENERGY", -- Resource type (string)
        amount = 25 -- Amount required (number)
    },
    
    -- Cooldown properties
    cooldown = 5, -- Cooldown in seconds (number)
    cooldownCategory = nil, -- Shared cooldown category (string or nil)
    
    -- Targeting
    targeting = {
        type = "SPHERE", -- Targeting type (string) - SELF, SPHERE, RECTANGLE, CONE, RAYCAST
        range = 10, -- Range in studs (number)
        width = nil, -- Width for rectangle/cone (number or nil)
        angle = nil, -- Angle for cone in degrees (number or nil)
        teamFilter = "ENEMIES", -- Who to "attack", using Team filter (string) - ENEMIES, ALLIES, ALL
        maxTargets = nil, -- Maximum targets to hit (number or nil)
        includeSelf = false -- Whether to include self as target (boolean)
    },
    
    -- Effects to apply
    effects = {
        -- Array of effect definitions
        {
            type = "DAMAGE", -- Effect type (string)
            damageType = "PHYSICAL", -- Damage type (string)
            amount = 25, -- Base amount (number)
            powerScaling = 0.5, -- How much Power stat affects damage (multiplier)
        },
        {
            type = "APPLY_CONDITION",
            conditionId = "BURNING",
            stacks = 2,
            duration = 4,
            data = {
                damagePerTick = 5,
                focusScaling = 0.2 -- How much Focus stat affects DoT damage
            }
        }
    },
    
    -- Chain ability properties (for combos)
    chain = {
        isChained = false, -- Is this part of a chain? (boolean)
        chainId = nil, -- Chain identifier (string or nil)
        position = nil, -- Position in chain (number or nil)
        nextAbilityId = nil, -- Next ability in chain (string or nil)
        timeout = nil -- Time window to use next ability (number or nil)
    }
}

--[[
    ConditionData - Structure for condition definitions
    Used by the ConditionSystem to define conditions
]]
CombatTypes.ConditionData = {
    id = "CONDITION_ID", -- Unique identifier (string)
    name = "Condition Name", -- Display name (string)
    description = "Description", -- Description text (string)
    category = "DAMAGE_OVER_TIME", -- Category (string)
    isDebuff = true, -- Is negative effect (boolean)
    
    -- UI properties
    icon = "rbxassetid://12345678", -- Icon asset ID (string)
    color = Color3.fromRGB(255, 0, 0), -- Color for UI (Color3)
    priority = 5, -- Display priority (number)
    
    -- Stack behavior
    maxStacks = 5, -- Maximum stack count (number)
    defaultDuration = 5, -- Default duration in seconds (number)
    stackBehavior = "REFRESH", -- Stack behavior (string) - REFRESH, ADD, INDEPENDENT
    removeStacksOnExpire = 1, -- Stacks to remove when duration ends (number)
    
    -- Tick behavior
    tickRate = 1, -- How often to tick in seconds (number)
    
    -- Interaction properties
    prevents = {}, -- Conditions this prevents (array of strings)
    removes = {}, -- Conditions this removes (array of strings)
    
    -- Handlers
    handlers = {
        onApply = function(params) end, -- Called when applied or stacked
        onRemove = function(params) end, -- Called when fully removed
        onExpire = function(params) end, -- Called when duration ends
        onTick = function(params) end, -- Called on tick interval
        onDamaged = function(params) end, -- Called when damaged
        onDealDamage = function(params) end, -- Called when dealing damage
        onHealed = function(params) end, -- Called when healed
        onMove = function(params) end, -- Called when moving
    },
    
    -- Transformation
    transform = {
        condition = function(data) end, -- Function to check transformation
        targetCondition = nil, -- Condition to transform into (string or nil)
        preserveStacks = false, -- Keep stack count (boolean)
        data = {} -- Data to pass to new condition (table)
    }
}

--[[
    EffectData - Structure for effect execution
    Used by the EffectSystem for effect parameters
]]
CombatTypes.EffectData = {
    -- Common properties for all effects
    id = "EFFECT_ID", -- Effect identifier (string)
    source = nil, -- Source entity ID (string)
    sourceAbility = nil, -- Source ability ID (string or nil)
    
    -- Damage effect properties
    amount = nil, -- Base effect amount (number or nil)
    damageType = nil, -- Damage type (string or nil)
    isCritical = false, -- Is critical hit/heal (boolean)
    
    -- Utility effect properties
    duration = nil, -- Effect duration (number or nil)
    strength = nil, -- Effect strength (number or nil)
    radius = nil, -- Effect radius (number or nil)
    
    -- Custom data
    data = {} -- Additional effect data (table)
}

--[[
    StatData - Structure for entity stats
    Used by the StatSystem to track entity stats
]]
CombatTypes.StatData = {
    -- Base stats
    power = 10, -- Scales ability damage
    defense = 5, -- Reduces incoming ability damage
    focus = 10, -- Scales condition damage
    healingPower = 10, -- Scales healing effects
    precision = 5, -- Crit chance rating
    ferocity = 150, -- Crit damage multiplier rating
    expertise = 100, -- Condition tickRate multiplier rating
    
    -- Derived stats (calculated from base stats)
    critChance = 5, -- Percent chance to crit
    critDamage = 150, -- Percent of normal damage on crit
    conditionDuration = 100, -- Percent of normal condition duration
}

--[[
    StatModifier - Structure for stat modifications
    Used by the StatSystem to modify entity stats
]]
CombatTypes.StatModifier = {
    id = "MODIFIER_ID", -- Unique identifier
    source = "GEAR_ITEM", -- Source of modifier (GEAR, BUFF, ABILITY, etc.)
    sourceId = "ITEM_ID", -- ID of the source item/ability/buff
    
    -- Flat additions
    flatModifiers = {
        power = 5, -- +5 power
        defense = 3, -- +3 defense
    },
    
    -- Percentage multipliers (100 = 100%)
    percentModifiers = {
        maxHealth = 110, -- +10% max health
        precision = 120, -- +20% precision
    },
    
    -- Duration (nil = permanent)
    duration = nil, -- Duration in seconds or nil
    
    -- Priority (for stacking rules)
    priority = 1, -- Higher priority overrides lower on conflicts
}

return CombatTypes
