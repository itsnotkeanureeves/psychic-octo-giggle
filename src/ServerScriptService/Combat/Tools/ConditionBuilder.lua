--[[
    ConditionBuilder.lua
    
    PURPOSE:
    Provides a fluent interface for defining conditions (buffs/debuffs).
    Makes condition creation more readable and less error-prone.
    
    USAGE:
    local ConditionBuilder = require(path.to.ConditionBuilder)
    
    local burning = ConditionBuilder.new("BURNING")
        :setName("Burning")
        :setDescription("Taking fire damage over time")
        :setCategory("DAMAGE_EFFECT")
        :setIsDebuff(true)
        :setIcon("rbxassetid://12345678")
        :setColor(Color3.fromRGB(255, 60, 30))
        :setMaxStacks(5)
        :setDefaultDuration(4)
        :setStackBehavior("REFRESH")
        :setTickRate(1)
        :addEventHandler("onTick", function(params, conditionSystem)
            -- Handle tick event
        end)
        :build()
    
    conditionSystem:RegisterCondition("BURNING", burning)
]]

local ConditionBuilder = {}
ConditionBuilder.__index = ConditionBuilder

-- Create a new condition builder
function ConditionBuilder.new(conditionId)
    local self = setmetatable({}, ConditionBuilder)
    
    -- Initialize with required fields
    self.conditionData = {
        id = conditionId,
        name = conditionId,
        description = "No description provided",
        category = "MISC",
        isDebuff = false,
        handlers = {}
    }
    
    return self
end

-- Set condition name
function ConditionBuilder:setName(name)
    self.conditionData.name = name
    return self
end

-- Set condition description
function ConditionBuilder:setDescription(description)
    self.conditionData.description = description
    return self
end

-- Set condition category
function ConditionBuilder:setCategory(category)
    self.conditionData.category = category
    return self
end

-- Set whether condition is a debuff
function ConditionBuilder:setIsDebuff(isDebuff)
    self.conditionData.isDebuff = isDebuff
    return self
end

-- Set condition icon
function ConditionBuilder:setIcon(iconId)
    self.conditionData.icon = iconId
    return self
end

-- Set condition color
function ConditionBuilder:setColor(color)
    self.conditionData.color = color
    return self
end

-- Set condition priority
function ConditionBuilder:setPriority(priority)
    self.conditionData.priority = priority
    return self
end

-- Set maximum stacks
function ConditionBuilder:setMaxStacks(maxStacks)
    self.conditionData.maxStacks = maxStacks
    return self
end

-- Set default duration
function ConditionBuilder:setDefaultDuration(duration)
    self.conditionData.defaultDuration = duration
    return self
end

-- Set stack behavior
function ConditionBuilder:setStackBehavior(behavior)
    self.conditionData.stackBehavior = behavior
    return self
end

-- Set stacks to remove on expiration
function ConditionBuilder:setRemoveStacksOnExpire(stacks)
    self.conditionData.removeStacksOnExpire = stacks
    return self
end

-- Set tick rate
function ConditionBuilder:setTickRate(tickRate)
    self.conditionData.tickRate = tickRate
    return self
end

-- Add conditions this prevents
function ConditionBuilder:addPrevents(conditionIds)
    if not self.conditionData.prevents then
        self.conditionData.prevents = {}
    end
    
    if type(conditionIds) == "string" then
        table.insert(self.conditionData.prevents, conditionIds)
    elseif type(conditionIds) == "table" then
        for _, id in ipairs(conditionIds) do
            table.insert(self.conditionData.prevents, id)
        end
    end
    
    return self
end

-- Add conditions this removes
function ConditionBuilder:addRemoves(conditionIds)
    if not self.conditionData.removes then
        self.conditionData.removes = {}
    end
    
    if type(conditionIds) == "string" then
        table.insert(self.conditionData.removes, conditionIds)
    elseif type(conditionIds) == "table" then
        for _, id in ipairs(conditionIds) do
            table.insert(self.conditionData.removes, id)
        end
    end
    
    return self
end

-- Add event handler
function ConditionBuilder:addEventHandler(eventName, handlerFn)
    if not self.conditionData.handlers then
        self.conditionData.handlers = {}
    end
    
    self.conditionData.handlers[eventName] = handlerFn
    return self
end

-- Set transform condition
function ConditionBuilder:setTransform(checkFn, targetCondition, options)
    options = options or {}
    
    self.conditionData.transform = {
        condition = checkFn,
        targetCondition = targetCondition,
        preserveStacks = options.preserveStacks or false
    }
    
    if options.data then
        self.conditionData.transform.data = options.data
    end
    
    return self
end

-- Build the condition data
function ConditionBuilder:build()
    -- Validate required fields
    assert(self.conditionData.id, "Condition ID is required")
    assert(self.conditionData.name, "Condition name is required")
    
    -- Apply defaults for missing fields
    if not self.conditionData.maxStacks then
        self.conditionData.maxStacks = 1
    end
    
    if not self.conditionData.defaultDuration then
        self.conditionData.defaultDuration = 5
    end
    
    if not self.conditionData.stackBehavior then
        self.conditionData.stackBehavior = "REFRESH"
    end
    
    if not self.conditionData.removeStacksOnExpire then
        self.conditionData.removeStacksOnExpire = 1
    end
    
    if not self.conditionData.priority then
        self.conditionData.priority = self.conditionData.isDebuff and 5 or 3
    end
    
    return self.conditionData
end

return ConditionBuilder
