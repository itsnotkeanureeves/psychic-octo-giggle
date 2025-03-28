--[[
    EntityUtility.lua
    
    PURPOSE:
    Provides shared utility functions for entity-related operations.
    Helps resolve entity IDs to character models and vice versa.
    
    DESIGN PRINCIPLES:
    - No state/dependencies (pure utility functions)
    - Consistent entity handling
    - Efficient lookup methods
]]

local EntityUtility = {}

-- Find an entity model by ID
function EntityUtility.FindEntityModel(entityId)
    if not entityId then
        return nil
    end
    
    -- Try to find directly in workspace
    local model = workspace:FindFirstChild(entityId)
    if model then return model end
    
    -- Try to find based on attributes
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("EntityId") == entityId then
            return child
        end
    end
    
    -- If nothing found, try to search deeper (more costly)
    for _, child in ipairs(workspace:GetDescendants()) do
        if child.Name == entityId and child:IsA("Model") then
            return child
        end
        
        if child:IsA("Model") and child:GetAttribute("EntityId") == entityId then
            return child
        end
    end
    
    return nil
end

-- Get the Humanoid from an entity
function EntityUtility.GetHumanoid(entityOrModel)
    if not entityOrModel then
        return nil
    end
    
    -- If this is already a model
    if typeof(entityOrModel) == "Instance" then
        if entityOrModel:IsA("Model") then
            return entityOrModel:FindFirstChildOfClass("Humanoid")
        end
    end
    
    -- If this is an entity ID
    if typeof(entityOrModel) == "string" then
        local model = EntityUtility.FindEntityModel(entityOrModel)
        if model then
            return model:FindFirstChildOfClass("Humanoid")
        end
    end
    
    return nil
end

-- Get the HumanoidRootPart from an entity
function EntityUtility.GetRootPart(entityOrModel)
    if not entityOrModel then
        return nil
    end
    
    local humanoid = EntityUtility.GetHumanoid(entityOrModel)
    if humanoid and humanoid.Parent then
        return humanoid.Parent:FindFirstChild("HumanoidRootPart")
    end
    
    -- Direct lookup if a model is provided
    if typeof(entityOrModel) == "Instance" and entityOrModel:IsA("Model") then
        return entityOrModel:FindFirstChild("HumanoidRootPart")
    end
    
    return nil
end

-- Get character position
function EntityUtility.GetPosition(entityOrModel)
    local rootPart = EntityUtility.GetRootPart(entityOrModel)
    if rootPart then
        return rootPart.Position
    end
    
    -- Fallback to model's position if it exists
    if typeof(entityOrModel) == "Instance" and entityOrModel:IsA("Model") then
        return entityOrModel:GetPivot().Position
    end
    
    return nil
end

return EntityUtility
