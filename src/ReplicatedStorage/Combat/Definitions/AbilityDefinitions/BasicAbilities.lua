--[[
    BasicAbilities.lua
    
    PURPOSE:
    Single source of truth for all ability definitions in the game.
    
    DESIGN PRINCIPLES:
    - Data-driven ability definitions
    - Clear, standardized effect types with action verbs (e.g., APPLY_DAMAGE)
    - Constants-based approach to eliminate string literals
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local Constants = require(SharedPath:WaitForChild("Constants"))

local EFFECT = Constants.EFFECT

local BasicAbilities = {
    -- Basic melee attack
    SLASH = {
        id = "SLASH", -- Explicitly include ID
        name = "Slash",
        description = "A basic melee attack that deals physical damage to a single target.",
        category = "MELEE",
        icon = "rbxassetid://12345678",
        
        castTime = 0,
        interruptible = true,
        
        cooldown = 1.5,
        
        targeting = {
            type = "CONE",
            range = 3,
            angle = 45,
            teamFilter = "ENEMIES"
        },
        
        effects = {
            {
                type = EFFECT.TYPES.APPLY_DAMAGE,
                damageType = EFFECT.DAMAGE_TYPES.PHYSICAL,
                amount = 20,
                powerScaling = 1.0
            }
        }
    },
    
    -- Three-hit combo attack
    TRIPLE_SLASH = {
        id = "TRIPLE_SLASH",
        name = "Triple Slash",
        description = "A three-hit combo attack. Each hit must be activated within the combo window.",
        category = "MELEE",
        icon = "rbxassetid://10511856020",
        
        castTime = 0,
        interruptible = true,
        
        resourceCost = {
            type = "ENERGY",
            amount = 0
        },
        
        cooldown = 6,
        
        targeting = {
            type = "CONE",
            range = 3,
            angle = 45,
            teamFilter = "ENEMIES"
        },
        
        effects = {
            {
                type = EFFECT.TYPES.APPLY_DAMAGE,
                damageType = EFFECT.DAMAGE_TYPES.PHYSICAL,
                amount = 15,
                powerScaling = 0.8
            }
        },
        
        chain = {
            isChained = true,
            chainId = "TRIPLE_SLASH_CHAIN",
            position = 1,
            nextAbilityId = "TRIPLE_SLASH_2",
            timeout = 2.5
        }
    },
    
    -- Second hit of triple slash
    TRIPLE_SLASH_2 = {
        id = "TRIPLE_SLASH_2",
        name = "Triple Slash: Second Strike",
        description = "Second strike of the Triple Slash combo.",
        category = "MELEE",
        icon = "rbxassetid://12345680",
        
        castTime = 0,
        interruptible = true,
        
        cooldown = 0.5,
        
        targeting = {
            type = "CONE",
            range = 3,
            angle = 45,
            teamFilter = "ENEMIES"
        },
        
        effects = {
            {
                type = EFFECT.TYPES.APPLY_DAMAGE,
                damageType = EFFECT.DAMAGE_TYPES.PHYSICAL,
                amount = 25,
                powerScaling = 1.0
            }
        },
        
        chain = {
            isChained = true,
            chainId = "TRIPLE_SLASH_CHAIN",
            position = 2,
            nextAbilityId = "TRIPLE_SLASH_3",
            timeout = 2.5
        }
    },
    
    -- Third hit of triple slash
    TRIPLE_SLASH_3 = {
        id = "TRIPLE_SLASH_3",
        name = "Triple Slash: Final Strike",
        description = "Powerful final strike of the Triple Slash combo.",
        category = "MELEE",
        icon = "rbxassetid://12345681",
        
        castTime = 0,
        interruptible = true,
        
        cooldown = 0.5,
        
        targeting = {
            type = "CONE",
            range = 3,
            angle = 45,
            teamFilter = "ENEMIES"
        },
        
        effects = {
            {
                type = EFFECT.TYPES.APPLY_DAMAGE,
                damageType = EFFECT.DAMAGE_TYPES.PHYSICAL,
                amount = 40,
                powerScaling = 1.5
            }
        },
        
        chain = {
            isChained = true,
            chainId = "TRIPLE_SLASH_CHAIN",
            position = 3
        }
    },
    
    -- Area of effect melee attack
    WHIRLWIND = {
        id = "WHIRLWIND",
        name = "Whirlwind",
        description = "A spinning attack that damages all enemies around you.",
        category = "MELEE",
        icon = "rbxassetid://12345682",
        
        castTime = 0.5,
        interruptible = true,
    
        cooldown = 1,
        
        targeting = {
            type = "SPHERE",
            range = 5,
            teamFilter = "ENEMIES",
            includeSelf = false
        },
        
        effects = {
            {
                type = EFFECT.TYPES.APPLY_DAMAGE,
                damageType = EFFECT.DAMAGE_TYPES.PHYSICAL,
                amount = 30,
                powerScaling = 0.8
            }
        }
    },
    
    -- Basic fire damage spell
    FIREBALL = {
        id = "FIREBALL",
        name = "Fireball",
        description = "Launch a ball of fire that explodes on impact, dealing area damage.",
        category = "MAGIC",
        icon = "rbxassetid://12345686",
        
        castTime = 1.2,
        interruptible = true,
    
        cooldown = 1,
        
        targeting = {
            type = "SPHERE",
            range = 20,
            teamFilter = "ENEMIES"
        },
        
        effects = {
            {
                type = EFFECT.TYPES.APPLY_DAMAGE,
                damageType = EFFECT.DAMAGE_TYPES.FIRE,
                amount = 40,
                powerScaling = 1.2
            },
            {
                type = EFFECT.TYPES.APPLY_CONDITION,
                conditionId = "BURNING",
                stacks = 2,
                duration = 2,
                data = {
                    damagePerTick = 1, -- Explicit damage per tick
                    focusScaling = 0.25 -- How much Focus stat affects DoT damage
                }
            }
        }
    },
    
    -- Basic healing spell
    HEAL = {
        id = "HEAL",
        name = "Heal",
        description = "Restore health to a friendly target.",
        category = "SUPPORT",
        icon = "rbxassetid://12345689",
        
        castTime = 1.5,
        interruptible = true,
        
        cooldown = 8,
        
        targeting = {
            type = "RAYCAST",
            range = 30,
            teamFilter = "ALLIES",
            includeSelf = true
        },
        
        effects = {
            {
                type = EFFECT.TYPES.APPLY_HEALING,
                amount = 50,
                healingScaling = 1.2
            }
        }
    }
}

return BasicAbilities
