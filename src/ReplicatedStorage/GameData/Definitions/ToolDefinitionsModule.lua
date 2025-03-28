-- ToolDefinitionsModule (Module) - Defines all gathering tools and their properties, including tool sets.

-- local ToolDefinitionsModule = 
-- require(game:GetService("ServerScriptService"):WaitForChild("GameData"):WaitForChild("Definitions"):WaitForChild("ToolDefinitionsModule"))

local ToolDefinitions = {}

-- 🎯 Tool Definitions
ToolDefinitions.Tools = {
	["iron_axe"] = { -- replaced by UUID when given to player
		toolType = "Wood",
		maxDurability = 100,
		enhancementLevel = 0,
		durability = 100,
		runeEffect = nil,
		baseName = "Iron Axe",
		displayName = "Iron Axe", -- used for UI, captures any modifiers/treatments to a tool's name
	},
	["iron_pickaxe"] = {
		toolType = "Ore",
		maxDurability = 100,
		enhancementLevel = 0,
		durability = 100,
		runeEffect = nil,
		baseName = "Iron Pickaxe",
		displayName = "Iron Pickaxe",
	},
	["steel_axe"] = {
		toolType = "Wood",
		maxDurability = 100,
		enhancementLevel = 0,
		durability = 100,
		runeEffect = nil,
		baseName = "Steel Axe",
		displayName = "Steel Axe",
	},
	["steel_pickaxe"] = {
		toolType = "Ore",
		maxDurability = 100,
		enhancementLevel = 0,
		durability = 100,
		runeEffect = nil,
		baseName = "Steel Pickaxe",
		displayName = "Steel Pickaxe",
	}
}

-- 🎁 Tool Sets (Starter, Premium, etc.)
ToolDefinitions.ToolSets = {
	["Starter Set"] = { "iron_axe", "iron_pickaxe" },
	["Premium Bundle"] = { "steel_axe", "steel_pickaxe" }
}

-- 🎯 Function: Assigns a pre-defined tool set to a player
function ToolDefinitions.giveToolSet(player, setName)
	local toolSet = ToolDefinitions.ToolSets[setName]
	if not toolSet then
		warn("Invalid tool set: " .. tostring(setName))
		return {}
	end

	local assignedTools = {}
	for _, toolName in ipairs(toolSet) do
		if ToolDefinitions.Tools[toolName] then
			assignedTools[toolName] = table.clone(ToolDefinitions.Tools[toolName])
		end
	end
	return assignedTools
end

return ToolDefinitions
