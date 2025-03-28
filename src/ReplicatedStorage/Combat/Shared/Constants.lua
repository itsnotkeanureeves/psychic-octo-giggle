--[[
    Constants.lua
    
    PURPOSE:
    Defines all constants used throughout the combat system.
    
    AVAILABLE TYPES:
    
    Effect Types:
    - APPLY_DAMAGE - Deals immediate damage to a target
    - APPLY_DOT - Applies damage over time
    - APPLY_HEALING - Heals target immediately
    - APPLY_HOT - Applies healing over time
    - APPLY_CONDITION - Applies a condition
    - REMOVE_CONDITION - Removes a condition
    - APPLY_STAT_MODIFIER - Modifies a stat value
    - REMOVE_STAT_MODIFIER - Removes a stat modifier
    - APPLY_KNOCKBACK - Applies knockback force
    - APPLY_PULL - Applies pull force
    - APPLY_TELEPORT - Teleports entity
    
    Damage Types:
    - PHYSICAL - Physical damage
    - FIRE - Fire damage
    - ICE - Ice damage
    - POISON - Poison damage
    - LIGHTNING - Lightning damage
    - ARCANE - Arcane damage
    - HOLY - Holy damage
    - SHADOW - Shadow damage
    - TRUE - Ignores resistance/defense
    
    EXTENDING THE SYSTEM:
    
    To add a new effect type:
    1. Add a new entry to Constants.EFFECT.TYPES
    2. Add an implementation in EffectSystem:RegisterBuiltInEffects()
    3. Update this documentation header
    
    To add a new damage type:
    1. Add a new entry to Constants.EFFECT.DAMAGE_TYPES
    2. Update this documentation header
]]

local Constants = {}

-- Entity types
Constants.ENTITY_TYPES = {
    PLAYER = "PLAYER",
    NPC = "NPC",
}

-- Condition constants
Constants.CONDITION = {
    MAX_STACKS = 25, -- Maximum stacks for any condition
    DEFAULT_DURATION = 5, -- Default duration in seconds if none specified
    DEFAULT_TICK_RATE = 1, -- Default tick rate in seconds
    
    -- Stack behavior definitions
    STACK_BEHAVIORS = {
        REFRESH = "REFRESH", -- Reset duration, keep stacks
        ADD = "ADD", -- Add stacks, keep longer duration
        INDEPENDENT = "INDEPENDENT", -- Each application is separate
    },
    
    -- Data inheritance rules
    DATA_INHERITANCE = {
        PRESERVE = "PRESERVE", -- Keep original value, ignore new value
        LATEST = "LATEST", -- Use latest value, overwrite original
        SUM = "SUM", -- Add values together
        MAX = "MAX", -- Take maximum value
        MIN = "MIN", -- Take minimum value
    },
    
    -- Standard condition IDs
    IDS = {
        BURNING = "BURNING",          -- Default DoT fire damage
        BLEEDING = "BLEEDING",        -- Default DoT physical damage
        POISONED = "POISONED",        -- Default DoT poison damage
        REGENERATION = "REGENERATION",-- Default HoT
        STUNNED = "STUNNED",          -- Movement/action prevention
        SLOWED = "SLOWED",            -- Movement speed reduction
        WEAKENED = "WEAKENED",        -- Reduced damage output
        VULNERABLE = "VULNERABLE",    -- Increased damage taken
        STRENGTHENED = "STRENGTHENED",-- Increased damage output
        PROTECTED = "PROTECTED"       -- Reduced damage taken
    }
}

-- Ability constants
Constants.ABILITY = {
    DEFAULT_COOLDOWN = 1.5, -- Default cooldown in seconds
    DEFAULT_CAST_TIME = 0, -- Default instant cast
    MAX_CHAIN_TIMEOUT = 5, -- Maximum timeout for ability chains
}

-- Effect system constants
Constants.EFFECT = {
    -- Effect categories for organization
    CATEGORIES = {
        DAMAGE = "DAMAGE",
        HEALING = "HEALING",
        UTILITY = "UTILITY",
        MOVEMENT = "MOVEMENT",
        STAT = "STAT",
        CONDITION = "CONDITION",
        VISUAL = "VISUAL"
    },
    
    -- Effect types within categories - STANDARDIZED WITH ACTION VERBS
    TYPES = {
        -- Damage effects
        APPLY_DAMAGE = "APPLY_DAMAGE",
        APPLY_DOT = "APPLY_DOT",
        
        -- Healing effects
        APPLY_HEALING = "APPLY_HEALING",
        APPLY_HOT = "APPLY_HOT",
        
        -- Utility effects
        APPLY_STAT_MODIFIER = "APPLY_STAT_MODIFIER",
        REMOVE_STAT_MODIFIER = "REMOVE_STAT_MODIFIER",
        
        -- Movement effects
        APPLY_KNOCKBACK = "APPLY_KNOCKBACK",
        APPLY_PULL = "APPLY_PULL",
        APPLY_TELEPORT = "APPLY_TELEPORT",
        
        -- Condition effects
        APPLY_CONDITION = "APPLY_CONDITION",
        REMOVE_CONDITION = "REMOVE_CONDITION"
    },
    
    -- Damage types
    DAMAGE_TYPES = {
        PHYSICAL = "physical",
        FIRE = "fire",
        ICE = "ice",
        LIGHTNING = "lightning",
        POISON = "poison",
        ARCANE = "arcane",
        HOLY = "holy",
        SHADOW = "shadow",
        TRUE = "true" -- Ignores resistance/defense
    },
    
    -- Execution steps for 6-step flow
    EXECUTION_STEPS = {
        VALIDATION = 1,
        PRE_PROCESSING = 2,
        PARAMETER_CALCULATION = 3,
        EFFECT_APPLICATION = 4,
        POST_PROCESSING = 5,
        FEEDBACK = 6
    }
}

-- Stat constants
Constants.STAT = {
    -- Base stats
    POWER = "power", -- Scales ability damage
    DEFENSE = "defense", -- Reduces incoming ability damage
    FOCUS = "focus", -- Scales condition damage
    HEALING_POWER = "healingPower", -- Scales healing effects
    
    -- Rating stats (with diminishing returns)
    PRECISION = "precision", -- Crit chance rating
    FEROCITY = "ferocity", -- Crit damage multiplier rating
    EXPERTISE = "expertise", -- Condition tickRate multiplier rating
    
    -- Basic attributes
    HEALTH = "health",
    MAX_HEALTH = "maxHealth",
    ENERGY = "energy",
    MAX_ENERGY = "maxEnergy",
    
    -- Default stat values
    DEFAULTS = {
        power = 10,
        defense = 5,
        focus = 10,
        healingPower = 10,
        precision = 5,
        ferocity = 150, -- Base 150% crit damage
        expertise = 100, -- Base 100% condition effectiveness
        health = 100,
        maxHealth = 100,
        energy = 100,
        maxEnergy = 100,
        level = 1, -- Default level
    },
    
    -- Stat diminishing returns constants
    DIMINISHING_RETURNS = {
        precision = {
            BASE_VALUE = 0.05, -- 5% base crit chance
            RATING_PER_PERCENT = 20, -- 20 rating gives 1% crit chance at level 1
            SOFT_CAP = 0.5, -- 50% soft cap
            HARD_CAP = 0.75, -- 75% hard cap
        },
        ferocity = {
            BASE_VALUE = 1.5, -- 150% base crit damage
            RATING_PER_PERCENT = 15, -- 15 rating gives 1% crit damage at level 1
        },
        expertise = {
            BASE_VALUE = 1.0, -- 100% base effectiveness
            RATING_PER_PERCENT = 10, -- 10 rating gives 1% effectiveness at level 1
        },
    },
}

-- Level scaling constants
Constants.LEVEL_SCALING = {
    -- Base stat scaling
    STAT_MULTIPLIER_PER_LEVEL = 0.1, -- Stats increase by 10% per level
    
    -- Damage and defense scaling
    DAMAGE_FACTOR_PER_LEVEL = 0.05, -- 5% more/less damage per level difference
    DEFENSE_FACTOR_PER_LEVEL = 0.05, -- 5% more/less defense effectiveness per level difference
    MAX_LEVEL_MODIFIER = 0.5, -- Cap at 50% more/less
    
    -- Rating scaling (how much more rating is needed per level)
    RATING_INCREASE_PER_LEVEL = 0.1, -- 10% more rating needed per level
    
    -- Defense formula constants
    DEFENSE_DENOMINATOR_BASE = 50, -- Base value in defense formula denominator
    DEFENSE_DENOMINATOR_MULTIPLIER = 1.0, -- How much the denominator scales with level
    MAX_DEFENSE_MITIGATION = 0.75, -- Maximum damage reduction from defense (75%)
}

-- Targeting constants
Constants.TARGETING = {
    TYPES = {
        SELF = "SELF", -- Only targets the caster
        SPHERE = "SPHERE", -- Spherical area
        RECTANGLE = "RECTANGLE", -- Rectangular area
        CONE = "CONE", -- Cone-shaped area
        RAYCAST = "RAYCAST", -- Single target hit by ray
    },
    TEAM_FILTERS = {
        ALL = "ALL", -- Target everyone
        ENEMIES = "ENEMIES", -- Target only enemies
        ALLIES = "ALLIES", -- Target only allies
    },
    DEFAULT_RANGE = 8, -- Default range in studs
}

-- Event types
Constants.EVENTS = {
    -- Ability events
    ABILITY_REQUEST = "ABILITY_REQUEST",
    ABILITY_RESPONSE = "ABILITY_RESPONSE",
    ABILITY_CAST_START = "ABILITY_CAST_START",
    ABILITY_CAST_COMPLETE = "ABILITY_CAST_COMPLETE",
    ABILITY_CAST_INTERRUPTED = "ABILITY_CAST_INTERRUPTED",
    ABILITY_EXECUTED = "ABILITY_EXECUTED",
    
    -- Combat events
    DAMAGE_DEALT = "DAMAGE_DEALT",
    HEALING_APPLIED = "HEALING_APPLIED",
    
    -- New event types for event-based communication
    DAMAGE_REQUEST = "DAMAGE_REQUEST",
    DAMAGE_RESPONSE = "DAMAGE_RESPONSE",
    HEALING_REQUEST = "HEALING_REQUEST",
    HEALING_RESPONSE = "HEALING_RESPONSE",
    CONDITION_REQUEST = "CONDITION_REQUEST",
    CONDITION_RESPONSE = "CONDITION_RESPONSE",
    
    -- Effect system events
    EFFECT_EXECUTED = "EFFECT_EXECUTED",
    EFFECT_FAILED = "EFFECT_FAILED",
    
    -- System ready events
    DAMAGE_SYSTEM_READY = "DAMAGE_SYSTEM_READY",
    EFFECT_SYSTEM_READY = "EFFECT_SYSTEM_READY",
    CONDITION_SYSTEM_READY = "CONDITION_SYSTEM_READY",
    
    -- Condition events
    CONDITION_APPLIED = "CONDITION_APPLIED",
    CONDITION_REMOVED = "CONDITION_REMOVED",
    CONDITION_TICK = "CONDITION_TICK",
    CONDITION_STACK_ADDED = "CONDITION_STACK_ADDED",
    CONDITION_STACK_REMOVED = "CONDITION_STACK_REMOVED",
    
    -- Entity events
    ENTITY_REGISTERED = "ENTITY_REGISTERED",
    ENTITY_UNREGISTERED = "ENTITY_UNREGISTERED",
    ENTITY_DAMAGED = "ENTITY_DAMAGED",
    ENTITY_HEALED = "ENTITY_HEALED",
    ENTITY_DIED = "ENTITY_DIED",
    ENTITY_ATTRIBUTE_CHANGED = "ENTITY_ATTRIBUTE_CHANGED",
    
    -- Stat events
    STAT_CHANGED = "STAT_CHANGED",
    STAT_MODIFIER_ADDED = "STAT_MODIFIER_ADDED",
    STAT_MODIFIER_REMOVED = "STAT_MODIFIER_REMOVED",
    
    -- Phase 4: Cast bar events
    CAST_PROGRESS_UPDATE = "CAST_PROGRESS_UPDATE",
    
    -- Phase 4: Chain ability events
    CHAIN_ABILITY_READY = "CHAIN_ABILITY_READY",
    CHAIN_ABILITY_TIMEOUT = "CHAIN_ABILITY_TIMEOUT",
    CHAIN_ABILITY_COMPLETED = "CHAIN_ABILITY_COMPLETED"
}

-- Return as read-only table
return table.freeze(Constants)
