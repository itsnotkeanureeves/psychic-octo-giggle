--[[
    AbilityBuilder.lua
    
    PURPOSE:
    Provides a fluent interface for defining abilities.
    Makes ability creation more readable and less error-prone.
    
    USAGE:
    local AbilityBuilder = require(path.to.AbilityBuilder)
    
    local fireball = AbilityBuilder.new("FIREBALL")
        :setName("Fireball")
        :setDescription("Launch a fireball at your target")
        :setCastTime(1.2)
        :setCooldown(6)
        :setResourceCost("MANA", 30)
        :setTargeting("SPHERE", 20, "ENEMIES")
        :addDamageEffect(40, "fire", 1.2)
        :addConditionEffect("BURNING", 2, 4)
        :build()
    
    abilitySystem:RegisterAbility("FIREBALL", fireball)
]]

local AbilityBuilder = {}
AbilityBuilder.__index = AbilityBuilder

-- Create a new ability builder
function AbilityBuilder.new(abilityId)
    local self = setmetatable({}, AbilityBuilder)
    
    -- Initialize with required fields
    self.abilityData = {
        id = abilityId,
        name = abilityId,
        description = "No description provided",
        category = "MISC",
        effects = {}
    }
    
    return self
end

-- Set ability name
function AbilityBuilder:setName(name)
    self.abilityData.name = name
    return self
end

-- Set ability description
function AbilityBuilder:setDescription(description)
    self.abilityData.description = description
    return self
end

-- Set ability category
function AbilityBuilder:setCategory(category)
    self.abilityData.category = category
    return self
end

-- Set ability icon
function AbilityBuilder:setIcon(iconId)
    self.abilityData.icon = iconId
    return self
end

-- Set cast time
function AbilityBuilder:setCastTime(castTime, interruptible)
    self.abilityData.castTime = castTime
    self.abilityData.interruptible = interruptible ~= false -- Default to true if not specified
    return self
end

-- Set animation
function AbilityBuilder:setAnimation(animationId)
    self.abilityData.animation = animationId
    return self
end

-- Set cooldown
function AbilityBuilder:setCooldown(cooldown)
    self.abilityData.cooldown = cooldown
    return self
end

-- Set cooldown category
function AbilityBuilder:setCooldownCategory(category)
    self.abilityData.cooldownCategory = category
    return self
end

-- Set resource cost
function AbilityBuilder:setResourceCost(resourceType, amount)
    self.abilityData.resourceCost = {
        type = resourceType,
        amount = amount
    }
    return self
end

-- Set targeting
function AbilityBuilder:setTargeting(targetType, range, teamFilter, options)
    options = options or {}
    
    self.abilityData.targeting = {
        type = targetType,
        range = range,
        teamFilter = teamFilter
    }
    
    -- Add optional targeting parameters
    if options.width then
        self.abilityData.targeting.width = options.width
    end
    
    if options.angle then
        self.abilityData.targeting.angle = options.angle
    end
    
    if options.maxTargets then
        self.abilityData.targeting.maxTargets = options.maxTargets
    end
    
    if options.includeSelf ~= nil then
        self.abilityData.targeting.includeSelf = options.includeSelf
    end
    
    return self
end

-- Add damage effect
function AbilityBuilder:addDamageEffect(amount, damageType, powerScaling, options)
    options = options or {}
    
    local effect = {
        type = "DAMAGE",
        amount = amount,
        damageType = damageType or "physical",
        powerScaling = powerScaling or 1.0
    }
    
    -- Add optional effect parameters
    if options.isCritical ~= nil then
        effect.isCritical = options.isCritical
    end
    
    if options.bypassBlock ~= nil then
        effect.bypassBlock = options.bypassBlock
    end
    
    if options.isPeriodic ~= nil then
        effect.isPeriodic = options.isPeriodic
    end
    
    table.insert(self.abilityData.effects, effect)
    return self
end

-- Add healing effect
function AbilityBuilder:addHealingEffect(amount, healingScaling, options)
    options = options or {}
    
    local effect = {
        type = "HEALING",
        amount = amount,
        healingScaling = healingScaling or 1.0
    }
    
    -- Add optional effect parameters
    if options.isCritical ~= nil then
        effect.isCritical = options.isCritical
    end
    
    if options.isPeriodic ~= nil then
        effect.isPeriodic = options.isPeriodic
    end
    
    table.insert(self.abilityData.effects, effect)
    return self
end

-- Add condition effect
function AbilityBuilder:addConditionEffect(conditionId, stacks, duration, data)
    local effect = {
        type = "APPLY_CONDITION",
        conditionId = conditionId,
        stacks = stacks or 1,
        duration = duration
    }
    
    -- Add optional condition data
    if data then
        effect.data = data
    end
    
    table.insert(self.abilityData.effects, effect)
    return self
end

-- Add knockback effect
function AbilityBuilder:addKnockbackEffect(force, direction)
    local effect = {
        type = "APPLY_KNOCKBACK",
        force = force,
        direction = direction or "OUTWARD" -- Special case handled in execution
    }
    
    table.insert(self.abilityData.effects, effect)
    return self
end

-- Add stat modifier effect
function AbilityBuilder:addStatModifierEffect(modifierId, source, duration, flatModifiers, percentModifiers)
    local effect = {
        type = "APPLY_STAT_MODIFIER",
        modifierData = {
            id = modifierId,
            source = source,
            duration = duration,
            flatModifiers = flatModifiers or {},
            percentModifiers = percentModifiers or {}
        }
    }
    
    table.insert(self.abilityData.effects, effect)
    return self
end

-- Add custom effect
function AbilityBuilder:addCustomEffect(effectType, params)
    local effect = {
        type = effectType
    }
    
    -- Copy all parameters
    for k, v in pairs(params) do
        effect[k] = v
    end
    
    table.insert(self.abilityData.effects, effect)
    return self
end

-- Set ability chain
function AbilityBuilder:setAbilityChain(chainId, position, nextAbilityId, timeout)
    self.abilityData.chain = {
        isChained = true,
        chainId = chainId,
        position = position
    }
    
    if nextAbilityId then
        self.abilityData.chain.nextAbilityId = nextAbilityId
    end
    
    if timeout then
        self.abilityData.chain.timeout = timeout
    end
    
    return self
end

-- Build the ability data
function AbilityBuilder:build()
    -- Validate required fields
    assert(self.abilityData.id, "Ability ID is required")
    assert(self.abilityData.name, "Ability name is required")
    
    -- Validate targeting
    if not self.abilityData.targeting then
        -- Default to self-targeting if not specified
        self.abilityData.targeting = {
            type = "SELF"
        }
    end
    
    -- Validate effects
    if #self.abilityData.effects == 0 then
        warn("Ability '" .. self.abilityData.name .. "' has no effects")
    end
    
    return self.abilityData
end

return AbilityBuilder
