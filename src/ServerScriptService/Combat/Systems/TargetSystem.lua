--[[
    TargetSystem.lua
    
    PURPOSE:
    Provides spatial target detection for abilities and effects.
    Handles shape-based targeting and team filtering.
    
    DESIGN PRINCIPLES:
    - Optimized spatial queries
    - Shape-based detection (sphere, cone, rectangle)
    - Team/faction filtering
    - Direction-based targeting
    
    USAGE:
    local TargetSystem = require(path.to.TargetSystem)
    local targetSystem = TargetSystem.new(entitySystem, eventSystem)
    
    -- Get targets in a sphere
    local targets = targetSystem:GetTargetsInSphere(sourceId, position, {
        range = 10,
        teamFilter = "ENEMIES",
        maxTargets = 5
    })
    
    -- Get targets in a cone
    local targets = targetSystem:GetTargetsInCone(sourceId, position, direction, {
        range = 15,
        angle = 30,
        teamFilter = "ALL"
    })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SharedPath = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Shared")
local Constants = require(SharedPath:WaitForChild("Constants"))

local TARGETING = Constants.TARGETING
local ENTITY_TYPES = Constants.ENTITY_TYPES

-- TargetSystem implementation
local TargetSystem = {}
TargetSystem.__index = TargetSystem

function TargetSystem.new(entitySystem, eventSystem)
    local self = setmetatable({}, TargetSystem)
    self.EntitySystem = entitySystem
    self.EventSystem = eventSystem
    self.DebugVisualization = true -- Enable for development, disable for production
    
    return self
end

-- Get all possible targets (optimized for regular calling)
function TargetSystem:GetAllPotentialTargets()
    local targets = {}
    
    -- Get all registered entities
    local allEntities = self.EntitySystem:GetAllEntities()
    for entityId, entity in pairs(allEntities) do
        -- Only include valid entities with a position
        if entity.rootPart then
            table.insert(targets, {
                entityId = entityId,
                entity = entity,
                position = entity.rootPart.Position
            })
        end
    end
    
    return targets
end

-- Filter targets by team relationship
function TargetSystem:FilterTargetsByTeam(sourceId, targets, teamFilter)
    if not teamFilter or teamFilter == TARGETING.TEAM_FILTERS.ALL then
        return targets
    end
    
    local filteredTargets = {}
    
    for _, targetData in ipairs(targets) do
        local relationship = self.EntitySystem:GetTeamRelationship(sourceId, targetData.entityId)
        
        if (teamFilter == TARGETING.TEAM_FILTERS.ENEMIES and relationship == "Hostile") or
           (teamFilter == TARGETING.TEAM_FILTERS.ALLIES and relationship == "Friendly") then
            table.insert(filteredTargets, targetData)
        end
    end
    
    return filteredTargets
end

-- Get targets in a sphere shape
function TargetSystem:GetTargetsInSphere(sourceId, position, options)
    options = options or {}
    
    -- Default options
    local range = options.range or TARGETING.DEFAULT_RANGE
    local teamFilter = options.teamFilter or TARGETING.TEAM_FILTERS.ENEMIES
    local maxTargets = options.maxTargets
    local includeSelf = options.includeSelf or false
    
    -- Get all potential targets
    local potentialTargets = self:GetAllPotentialTargets()
    local validTargets = {}
    
    -- Filter by distance
    for _, targetData in ipairs(potentialTargets) do
        -- Skip self unless explicitly included
        if targetData.entityId == sourceId and not includeSelf then
            continue
        end
        
        -- Calculate distance (ignoring Y axis for flat plane detection)
        local targetPos = targetData.position
        local distanceXZ = ((targetPos.X - position.X)^2 + (targetPos.Z - position.Z)^2)^0.5
        
        -- Check if within range
        if distanceXZ <= range then
            -- Add distance for sorting
            targetData.distance = distanceXZ
            table.insert(validTargets, targetData)
        end
    end
    
    -- Filter by team
    validTargets = self:FilterTargetsByTeam(sourceId, validTargets, teamFilter)
    
    -- Sort by distance (closest first)
    table.sort(validTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Limit number of targets if specified
    if maxTargets and #validTargets > maxTargets then
        for i = maxTargets + 1, #validTargets do
            validTargets[i] = nil
        end
    end
    
    -- Debug visualization
    if self.DebugVisualization then
        self:VisualizeTargeting("sphere", position, {
            radius = range,
            targets = validTargets
        })
    end
    
    return validTargets
end

-- Get targets in a cone shape
function TargetSystem:GetTargetsInCone(sourceId, position, direction, options)
    options = options or {}
    
    -- Default options
    local range = options.range or TARGETING.DEFAULT_RANGE
    local angle = math.rad(options.angle or 30) -- Convert to radians
    local teamFilter = options.teamFilter or TARGETING.TEAM_FILTERS.ENEMIES
    local maxTargets = options.maxTargets
    local includeSelf = options.includeSelf or false
    
    -- Normalize direction
    direction = direction.Unit
    
    -- Get all potential targets
    local potentialTargets = self:GetAllPotentialTargets()
    local validTargets = {}
    
    -- Filter by distance and angle
    for _, targetData in ipairs(potentialTargets) do
        -- Skip self unless explicitly included
        if targetData.entityId == sourceId and not includeSelf then
            continue
        end
        
        -- Calculate distance vector (ignoring Y axis for flat plane detection)
        local targetPos = targetData.position
        local toTarget = Vector3.new(targetPos.X - position.X, 0, targetPos.Z - position.Z)
        local distanceXZ = toTarget.Magnitude
        
        -- Check if within range
        if distanceXZ <= range and distanceXZ > 0 then
            -- Calculate angle between direction and target
            local directionXZ = Vector3.new(direction.X, 0, direction.Z).Unit
            local toTargetDir = toTarget.Unit
            local dotProduct = directionXZ:Dot(toTargetDir)
            local angleBetween = math.acos(math.clamp(dotProduct, -1, 1))
            
            -- Check if within cone angle
            if angleBetween <= angle / 2 then
                -- Add distance and angle for sorting
                targetData.distance = distanceXZ
                targetData.angle = angleBetween
                table.insert(validTargets, targetData)
            end
        end
    end
    
    -- Filter by team
    validTargets = self:FilterTargetsByTeam(sourceId, validTargets, teamFilter)
    
    -- Sort by distance (closest first)
    table.sort(validTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Limit number of targets if specified
    if maxTargets and #validTargets > maxTargets then
        for i = maxTargets + 1, #validTargets do
            validTargets[i] = nil
        end
    end
    
    -- Debug visualization
    if self.DebugVisualization then
        self:VisualizeTargeting("cone", position, {
            direction = direction,
            length = range,
            angle = angle,
            targets = validTargets
        })
    end
    
    return validTargets
end

-- Get targets in a rectangle shape
function TargetSystem:GetTargetsInRectangle(sourceId, position, direction, options)
    options = options or {}
    
    -- Default options
    local length = options.length or TARGETING.DEFAULT_RANGE
    local width = options.width or length / 2
    local teamFilter = options.teamFilter or TARGETING.TEAM_FILTERS.ENEMIES
    local maxTargets = options.maxTargets
    local includeSelf = options.includeSelf or false
    
    -- Normalize direction
    direction = direction.Unit
    
    -- Calculate rectangle corners (ignoring Y axis)
    local forward = Vector3.new(direction.X, 0, direction.Z).Unit
    local right = Vector3.new(-forward.Z, 0, forward.X).Unit
    
    -- Get all potential targets
    local potentialTargets = self:GetAllPotentialTargets()
    local validTargets = {}
    
    -- Filter by rectangle bounds
    for _, targetData in ipairs(potentialTargets) do
        -- Skip self unless explicitly included
        if targetData.entityId == sourceId and not includeSelf then
            continue
        end
        
        -- Calculate relative position to center (ignoring Y axis)
        local targetPos = targetData.position
        local relativePos = Vector3.new(targetPos.X - position.X, 0, targetPos.Z - position.Z)
        
        -- Project onto forward and right axes
        local forwardProj = relativePos:Dot(forward)
        local rightProj = relativePos:Dot(right)
        
        -- Check if within rectangle bounds
        if forwardProj >= 0 and forwardProj <= length and 
           rightProj >= -width/2 and rightProj <= width/2 then
            -- Add distance for sorting
            targetData.distance = forwardProj
            targetData.rightOffset = rightProj
            table.insert(validTargets, targetData)
        end
    end
    
    -- Filter by team
    validTargets = self:FilterTargetsByTeam(sourceId, validTargets, teamFilter)
    
    -- Sort by distance (closest first)
    table.sort(validTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Limit number of targets if specified
    if maxTargets and #validTargets > maxTargets then
        for i = maxTargets + 1, #validTargets do
            validTargets[i] = nil
        end
    end
    
    -- Debug visualization
    if self.DebugVisualization then
        self:VisualizeTargeting("rectangle", position, {
            direction = direction,
            length = length,
            width = width,
            targets = validTargets
        })
    end
    
    return validTargets
end

-- Get single target from raycast
function TargetSystem:GetTargetFromRaycast(sourceId, position, direction, options)
    options = options or {}
    
    -- Default options
    local range = options.range or TARGETING.DEFAULT_RANGE
    local teamFilter = options.teamFilter or TARGETING.TEAM_FILTERS.ENEMIES
    local includeSelf = options.includeSelf or false
    
    -- Normalize direction
    direction = direction.Unit
    
    -- Set up raycast parameters
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
    
    -- Create filter list from all potential targets
    local filterInstances = {}
    local idToEntityMap = {}
    
    -- Get all potential targets
    local potentialTargets = self:GetAllPotentialTargets()
    
    -- Build filter list
    for _, targetData in ipairs(potentialTargets) do
        -- Skip self unless explicitly included
        if targetData.entityId == sourceId and not includeSelf then
            continue
        end
        
        if targetData.entity.character then
            table.insert(filterInstances, targetData.entity.character)
            idToEntityMap[targetData.entity.character] = targetData
        elseif targetData.entity.model then
            table.insert(filterInstances, targetData.entity.model)
            idToEntityMap[targetData.entity.model] = targetData
        end
    end
    
    raycastParams.FilterDescendantsInstances = filterInstances
    
    -- Perform the raycast
    local raycastResult = Workspace:Raycast(position, direction * range, raycastParams)
    
    if raycastResult then
        local hitInstance = raycastResult.Instance
        
        -- Find the character or model the hit part belongs to
        local model = hitInstance:FindFirstAncestorOfClass("Model")
        
        if model and idToEntityMap[model] then
            local targetData = idToEntityMap[model]
            
            -- Check team filter
            local validTargets = self:FilterTargetsByTeam(sourceId, {targetData}, teamFilter)
            
            -- Debug visualization
            if self.DebugVisualization then
                self:VisualizeTargeting("raycast", position, {
                    direction = direction,
                    length = range,
                    hitPosition = raycastResult.Position,
                    targets = validTargets
                })
            end
            
            return validTargets
        end
    end
    
    -- Debug visualization even if no hit
    if self.DebugVisualization then
        self:VisualizeTargeting("raycast", position, {
            direction = direction,
            length = range,
            targets = {}
        })
    end
    
    return {}
end

-- Get targets based on targeting type
function TargetSystem:GetTargets(sourceId, position, direction, options)
    options = options or {}
    local targetingType = options.type or TARGETING.TYPES.SPHERE
    
    if targetingType == TARGETING.TYPES.SELF then
        -- Self-targeting only includes the source
        local sourceEntity = self.EntitySystem:GetEntity(sourceId)
        if sourceEntity and sourceEntity.rootPart then
            return {
                {
                    entityId = sourceId,
                    entity = sourceEntity,
                    position = sourceEntity.rootPart.Position,
                    distance = 0
                }
            }
        else
            return {}
        end
    elseif targetingType == TARGETING.TYPES.SPHERE then
        return self:GetTargetsInSphere(sourceId, position, options)
    elseif targetingType == TARGETING.TYPES.CONE then
        return self:GetTargetsInCone(sourceId, position, direction, options)
    elseif targetingType == TARGETING.TYPES.RECTANGLE then
        return self:GetTargetsInRectangle(sourceId, position, direction, options)
    elseif targetingType == TARGETING.TYPES.RAYCAST then
        return self:GetTargetFromRaycast(sourceId, position, direction, options)
    else
        warn("TargetSystem: Unknown targeting type: " .. targetingType)
        return {}
    end
end

-- Visualize targeting for debugging (temporary parts)
function TargetSystem:VisualizeTargeting(targetingType, position, options)
    -- Skip if visualization is disabled
    if not self.DebugVisualization then
        return
    end
    
    -- Create a folder for visualization parts if it doesn't exist
    local visualFolder = Workspace:FindFirstChild("TargetingVisualization")
    if not visualFolder then
        visualFolder = Instance.new("Folder")
        visualFolder.Name = "TargetingVisualization"
        visualFolder.Parent = Workspace
    end
    
    -- Clear existing parts older than 1 second
    for _, child in pairs(visualFolder:GetChildren()) do
        if child:IsA("BasePart") and child:GetAttribute("CreatedAt") and 
           time() - child:GetAttribute("CreatedAt") > 3 then
            child:Destroy()
        end
    end
    
    -- Create visualization based on targeting type
    if targetingType == "sphere" then
        -- Create sphere visualization
        local radius = options.radius
        local sphere = Instance.new("Part")
        sphere.Shape = Enum.PartType.Ball
        sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
        sphere.Position = position
        sphere.Anchored = true
        sphere.CanCollide = false
        sphere.Transparency = 0.8
        sphere.Material = Enum.Material.Neon
        sphere.Color = Color3.fromRGB(0, 255, 0)
        sphere:SetAttribute("CreatedAt", time())
        sphere.Parent = visualFolder
    elseif targetingType == "cone" then
        -- Simplified cone visualization using parts
        local direction = options.direction
        local length = options.length
        local angle = options.angle
        
        -- Create line for direction
        local line = Instance.new("Part")
        line.Size = Vector3.new(0.2, 0.2, length)
        line.CFrame = CFrame.lookAt(position, position + direction * length)
        line.Anchored = true
        line.CanCollide = false
        line.Transparency = 0.5
        line.Material = Enum.Material.Neon
        line.Color = Color3.fromRGB(255, 0, 0)
        line:SetAttribute("CreatedAt", time())
        line.Parent = visualFolder
        
        -- Create arc parts for cone edges
        local edgeCount = 8
        local radius = math.tan(angle / 2) * length
        
        for i = 1, edgeCount do
            local theta = (i - 1) * (math.pi * 2 / edgeCount)
            local edgeDir = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), theta) * Vector3.new(radius, 0, length)
            
            local edge = Instance.new("Part")
            edge.Size = Vector3.new(0.2, 0.2, (edgeDir.Magnitude))
            edge.CFrame = CFrame.lookAt(position, position + edgeDir)
            edge.Anchored = true
            edge.CanCollide = false
            edge.Transparency = 0.7
            edge.Material = Enum.Material.Neon
            edge.Color = Color3.fromRGB(0, 0, 255)
            edge:SetAttribute("CreatedAt", time())
            edge.Parent = visualFolder
        end
    elseif targetingType == "rectangle" then
        -- Simplified rectangle visualization
        local direction = options.direction
        local length = options.length
        local width = options.width
        
        -- Calculate corners
        local forward = direction.Unit
        local right = Vector3.new(-forward.Z, 0, forward.X).Unit
        
        local frontLeft = position + forward * length - right * (width / 2)
        local frontRight = position + forward * length + right * (width / 2)
        local backLeft = position - right * (width / 2)
        local backRight = position + right * (width / 2)
        
        -- Create outline parts
        local edges = {
            {backLeft, frontLeft},
            {frontLeft, frontRight},
            {frontRight, backRight},
            {backRight, backLeft}
        }
        
        for i, edge in ipairs(edges) do
            local start, ending = edge[1], edge[2]
            local edgeLength = (ending - start).Magnitude
            
            local part = Instance.new("Part")
            part.Size = Vector3.new(0.2, 0.2, edgeLength)
            part.CFrame = CFrame.lookAt(start, ending) * CFrame.new(0, 0, -edgeLength/2)
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 0.7
            part.Material = Enum.Material.Neon
            part.Color = Color3.fromRGB(255, 255, 0)
            part:SetAttribute("CreatedAt", time())
            part.Parent = visualFolder
        end
    elseif targetingType == "raycast" then
        -- Raycast visualization
        local direction = options.direction
        local length = options.length
        local hitPosition = options.hitPosition
        
        -- Create line for ray
        local rayPart = Instance.new("Part")
        
        if hitPosition then
            -- If hit, show line to hit point
            local rayLength = (hitPosition - position).Magnitude
            rayPart.Size = Vector3.new(0.2, 0.2, rayLength)
            rayPart.CFrame = CFrame.lookAt(position, hitPosition) * CFrame.new(0, 0, -rayLength/2)
        else
            -- If no hit, show full ray length
            rayPart.Size = Vector3.new(0.2, 0.2, length)
            rayPart.CFrame = CFrame.lookAt(position, position + direction * length) * CFrame.new(0, 0, -length/2)
        end
        
        rayPart.Anchored = true
        rayPart.CanCollide = false
        rayPart.Transparency = 0.5
        rayPart.Material = Enum.Material.Neon
        rayPart.Color = Color3.fromRGB(255, 0, 255)
        rayPart:SetAttribute("CreatedAt", time())
        rayPart.Parent = visualFolder
        
        -- Create sphere at hit point if any
        if hitPosition then
            local hitSphere = Instance.new("Part")
            hitSphere.Shape = Enum.PartType.Ball
            hitSphere.Size = Vector3.new(0.5, 0.5, 0.5)
            hitSphere.Position = hitPosition
            hitSphere.Anchored = true
            hitSphere.CanCollide = false
            hitSphere.Transparency = 0.3
            hitSphere.Material = Enum.Material.Neon
            hitSphere.Color = Color3.fromRGB(255, 0, 0)
            hitSphere:SetAttribute("CreatedAt", time())
            hitSphere.Parent = visualFolder
        end
    end
    
    -- Visualize targets
    if options.targets then
        for _, target in ipairs(options.targets) do
            local targetPos = target.position
            
            local targetPart = Instance.new("Part")
            targetPart.Shape = Enum.PartType.Ball
            targetPart.Size = Vector3.new(0.5, 0.5, 0.5)
            targetPart.Position = targetPos
            targetPart.Anchored = true
            targetPart.CanCollide = false
            targetPart.Transparency = 0.3
            targetPart.Material = Enum.Material.Neon
            targetPart.Color = Color3.fromRGB(255, 255, 255)
            targetPart:SetAttribute("CreatedAt", time())
            targetPart.Parent = visualFolder
        end
    end
    
    -- Clean up after 3 seconds
    task.delay(3, function()
        for _, child in pairs(visualFolder:GetChildren()) do
            if child:GetAttribute("CreatedAt") and time() - child:GetAttribute("CreatedAt") > 2.9 then
                child:Destroy()
            end
        end
    end)
end

return TargetSystem
