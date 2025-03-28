-- ResourceTypes (Module) - Defines properties for each resource node type in ReplicatedStorage
local ResourceTypes = {}

ResourceTypes.Types = {
	Tree = { -- Name changed to UUID once spawned
		itemName   = "Wood",      -- TO BE DEPRECATED FOR dropTableKey: The name of the inventory item yielded by this resource
		model      = "TreeModel", -- Name of the model in ServerStorage.ResourceModels to use for this resource's appearance
		respawnTime = 30,         -- (Unused in this simple system; could be used for timed respawn)
		requiredToolType = "Wood", -- Require a tool with type "Tree" (e.g., Axe)
		dropTableKey = "zone_1_wood" -- Reference to DropTables module key
	},
	Ore = { --Resource Type Name may not match with the itemName that is dropped. i.e we could randomly spawn a "Large Rock" that also drops Stone but has a different model.
		itemName   = "Stone",
		model      = "RockModel",
		respawnTime = 30,
		requiredToolType = "Ore",
		dropTableKey = "zone_1_ore"
	}
	-- Additional resource types can be added here
}

return ResourceTypes
