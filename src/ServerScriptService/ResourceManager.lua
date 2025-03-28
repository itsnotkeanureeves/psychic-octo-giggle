-- ResourceManager (ModuleScript) - Handles spawning, tracking, and collecting resource nodes in ServerScriptService
local ServerStorage       = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local HttpService         = game:GetService("HttpService") -- Needed for UUID generation in creating unique resources

-- Require shared modules
local ResourceDropTables = require(ReplicatedStorage:WaitForChild("GameData"):WaitForChild("DropTables"):WaitForChild("ResourceDropTables"))
local ResourceTypes   = require(ReplicatedStorage:WaitForChild("ResourceTypes"))
local InventoryManager = require(ServerScriptService:WaitForChild("InventoryManager"))
local ServerConfig    = require(ReplicatedStorage:WaitForChild("ServerConfig"))
local DebugUtil       = require(ReplicatedStorage:WaitForChild("DebugUtil"))

-- Table to track active resource instances in the world
local resources = {}

-- Internal function to spawn a single resource node of a given type at a position
local function spawnResource(resourceTypeName: string, position: Vector3)
	local resourceType = ResourceTypes.Types[resourceTypeName]
	if not resourceType then
		DebugUtil:Log("Attempted to spawn unknown resource type: " .. tostring(resourceTypeName))
		return nil
	end
	  
	-- Create a unique ID for the resource node
	local resourceId = HttpService:GenerateGUID(false)

	-- Obtain the model or part for this resource type
	local resourceModel = nil
	if ServerStorage:FindFirstChild("ResourceModels") then
		resourceModel = ServerStorage.ResourceModels:FindFirstChild(resourceType.model or "")
	end

	local resourceObj
	if resourceModel then
		resourceObj = resourceModel:Clone()
		-- If the resource model is a Model, position it properly
		if resourceObj:IsA("Model") then
			if resourceObj.PrimaryPart then
				resourceObj:SetPrimaryPartCFrame(CFrame.new(position))
			else
				resourceObj:PivotTo(CFrame.new(position))
			end
		elseif resourceObj:IsA("BasePart") then
			resourceObj.Position = position
		end
		-- Ensure the resource's name matches its type for identification
		resourceObj.Name = resourceId
		-- Anchor all parts in the model so it stays in place (resource nodes are static)
		if resourceObj:IsA("Model") then
			for _, part in ipairs(resourceObj:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
		elseif resourceObj:IsA("BasePart") then
			resourceObj.Anchored = true
		end
	else
		-- If no predefined model, create a simple placeholder part
		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 4, 4)
		part.Anchored = true
		-- Set visual appearance based on resource type (for differentiation)
		if resourceTypeName == "Tree" then
			part.BrickColor = BrickColor.new("Earth green")
		elseif resourceTypeName == "Ore" then
			part.BrickColor = BrickColor.new("Dark stone grey")
		else
			part.BrickColor = BrickColor.new("Bright yellow")
		end
		part.Name = resourceTypeName
		part.Position = position
		resourceObj = part
	end

	-- Parent the resource to a designated folder in the Workspace for organization
	local resourcesFolder = workspace:FindFirstChild("Resources") or Instance.new("Folder", workspace)
	resourcesFolder.Name = "Resources"
	resourceObj.Parent = resourcesFolder

    -- Store unique ID as an attribute
    resourceObj:SetAttribute("resourceId", resourceId)

	-- Store resource metadata in the server-side table
	resources[resourceId] = {
		typeName = resourceTypeName,
		requiredToolType = resourceType.requiredToolType,
		dropTableKey = resourceType.dropTableKey, -- possibly issue here?
		instance = resourceObj
	}

	-- Ensure ClickDetector is attached to a BasePart inside the model
	if resourceObj:IsA("Model") then
		local primaryPart = resourceObj.PrimaryPart or resourceObj:FindFirstChildWhichIsA("BasePart")
		if primaryPart then
			local clickDetector = Instance.new("ClickDetector")
			clickDetector.Parent = primaryPart
		else
			warn("No suitable part found to attach ClickDetector for " .. resourceObj.Name)
		end
	elseif resourceObj:IsA("BasePart") then
		local clickDetector = Instance.new("ClickDetector")
		clickDetector.Parent = resourceObj
	end

    --DebugUtil:Log("Spawned resource '" .. resourceTypeName .. "' with ID " .. resourceId)
	return resourceObj
end

-- Internal function to remove a resource node from the world and tracking
local function removeResource(resourceObj: Instance)
    if resourceObj then
        local resourceId = resourceObj:GetAttribute("resourceId")
        if resourceId and resources[resourceId] then
            resources[resourceId] = nil -- Remove from server tracking
        end

        resourceObj:Destroy()
        DebugUtil:Log("Resource removed: " .. tostring(resourceId or resourceObj.Name))
    end
end


-- Function to handle a player collecting a resource node
local function collectResource(player: Player, resourceObj: Instance)
	local premiumChance = 0.02 -- Base chance for premium currency
	local runeFindChance = 0.005 -- Base chance for rune drop
	
    -- Ensure the resource object exists and has an ID
    local resourceId = resourceObj:GetAttribute("resourceId")
    if not resourceId then
        DebugUtil:Log("ERROR: collectResource - Resource object is missing an ID.")
        return
    end
    local resourceData = resources[resourceId]
    if not resourceData then
        DebugUtil:Log("ERROR: collectResource - Resource ID not found in tracking table.")
        return
    end

	DebugUtil:Log("Resource ID: " .. tostring(resourceId))
	DebugUtil:Log("Resource Data: " .. tostring(resourceData))


	-- define required tool based on resource
	local requiredToolType = resourceData.requiredToolType
	if not requiredToolType then
		DebugUtil:Log("ERROR: collectResource - No required tool type defined for resource.")
		return
	end
	DebugUtil:Log("Checking tool of type: " .. requiredToolType)
	
	-- Ensure player has an active tool that matches the required type
	local inventory = InventoryManager:GetInventory(player)
	if not inventory then
		DebugUtil:Log("ERROR: Player inventory not found for " .. player.Name)
		return
	end

	local activeToolId = inventory.activeTools[requiredToolType]  -- Get the tool ID for the required type
	local activeTool = inventory.tools[activeToolId]  -- Retrieve the actual tool object
	if not activeTool then
        DebugUtil:Log("ERROR: No active tool found for type: " .. requiredToolType)
        return
    end

    if activeTool.durability <= 0 then
        DebugUtil:Log("ERROR: Active tool is broken.")
        return
    end
	DebugUtil:Log("Active tool type: " .. activeTool.toolType .. " | Required: " .. requiredToolType)

	-- check if resource still exists
	if not resourceObj or not resourceObj.Parent then
		DebugUtil:Log("collectResource: Resource is already gone or invalid.")
		return
	end

    -- Select a random item from the resource’s drop table
	local dropTable = ResourceDropTables.Tables[resourceData.dropTableKey]  -- Retrieve actual drop table
	if not dropTable or #dropTable == 0 then
		DebugUtil:Log("ERROR: No valid drop table found for key: " .. tostring(resourceData.dropTableKey))
		return
	end
	
	local dropItem = ResourceDropTables:GetRandomDrop(resourceData.dropTableKey)
	if not dropItem then
		DebugUtil:Log("ERROR: No valid drop found for resource: " .. tostring(resourceData.typeName))
		return
	end
	
	if dropItem then
		local added = InventoryManager:AddItem(player, dropItem, 1)
		if added then
			DebugUtil:Log(player.Name .. " collected 1x " .. dropItem)
		else
			DebugUtil:Log("Failed to add item '" .. dropItem .. "' to " .. player.Name .. "'s inventory.")
		end
	else
		DebugUtil:Log("No valid drop found for resource: " .. tostring(resourceData.typeName))
	end

	-- Special rewards, should break out into own function
	premiumChance = premiumChance + activeTool.enhancementLevel * 0.005
	runeFindChance = runeFindChance + activeTool.enhancementLevel * 0.002

	if activeTool.runeEffect == "Luck" then
		premiumChance = premiumChance + 0.10
	elseif activeTool.runeEffect == "Plenty" then
		if math.random() < 0.5 then 
			InventoryManager:AddItem(player, dropItem, 1) 
			DebugUtil:Log(player.Name .. " got an ExtraResource due to Rune of Plenty.")
		end
	end

	if math.random() < premiumChance then
		InventoryManager:AddItem(player, "Ducat", 1)
		DebugUtil:Log(player.Name .. " got Ducat from gathering.")
	end

	if math.random() < runeFindChance then
		InventoryManager:AddItem(player, "RandomRune", 1) --this is not a real rune
		DebugUtil:Log(player.Name .. " found a RandomRune while gathering.")
	end

	activeTool.durability = activeTool.durability - 1
    DebugUtil:Log(player.Name .. " gathered using " .. (activeTool.toolType or "Unknown Tool") .. " (Durability: " .. tostring(activeTool.durability) .. ")")

	-- Remove the resource node from the world after collection
	removeResource(resourceObj)
end

-- Expose the ResourceManager interface
local ResourceManager = {}
-- Spawn a resource node of given type at position
ResourceManager.SpawnResource = spawnResource
-- Remove a resource node instance
ResourceManager.RemoveResource = removeResource
-- Player collects a resource node
ResourceManager.CollectResource = collectResource
-- Get the table of active resources (for counting, etc.)Is this necessary?
function ResourceManager:GetActiveResources()
	return resources
end

return ResourceManager

-- This is a patch at the end of the file to make sure collectResource uses notifications
-- Find and replace where relevant in your collectResource function:

-- Original line:
-- local added = InventoryManager:AddItem(player, dropItem, 1)

-- Modified approach (will use the modified AddItem that automatically notifies):
-- InventoryManager:AddItem(player, dropItem, 1)

-- For the special rewards (premium currency, runes, etc.), add these lines after adding items:
-- if premium currency added: InventoryManager:NotifyItemReceived(player, "PremiumCurrency", 1)
-- if rune found: InventoryManager:NotifyItemReceived(player, "RandomRune", 1)
-- if extra item from Rune of Plenty: InventoryManager:NotifyItemReceived(player, dropItem, 1)
