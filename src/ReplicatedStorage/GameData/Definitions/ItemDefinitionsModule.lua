-- ItemDefinitionsModule (Module) - Defines item properties for inventory items in ReplicatedStorage
-- local ItemDefinitionsModule = 
-- require(game:GetService("ServerScriptService"):WaitForChild("GameData"):WaitForChild("Definitions"):WaitForChild("ItemDefinitionsModule"))

local ItemDefinitions = {}

ItemDefinitions.Items = {
	OakLog = {
		maxStack = 100,                      -- Maximum stack size for Wood (non functional)
		description = "Collected from Trees", -- Description or additional info (for future use in UI or tooltips), should localize
		rarity = "Common", 					-- Used in ItemRarityModule.lua
	},
	Stone = {
		maxStack = 100,
		description = "Collected from Rocks",
		rarity = "Uncommon"
	},
	SmallStone = {
		maxStack = 100,
		description = "Collected from Rocks",
		rarity = "Common"
	},
	IronOre = {
		maxStack = 100,
		description = "Collected from Rocks",
		rarity = "Rare"
	},
	PineLog = {
		maxStack = 100,                    
		description = "Collected from Trees",
		rarity = "Epic"
	},
	BirchLog = {
		maxStack = 100,                    
		description = "Collected from Trees",
		rarity = "Uncommon"
	},
	Ducat = {
		maxStack = 100,                    
		description = "Collected with luck",
		rarity = "Legendary"
	},
	SoulStone = {
		maxStack = 100,
		description = "Used to enhance tools with improved success chance",
		rarity = "Legendary"
	},	
	-- Additional item types can be added here with their properties
}

return ItemDefinitions
