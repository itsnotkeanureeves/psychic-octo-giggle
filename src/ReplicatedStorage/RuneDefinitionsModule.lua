-- RuneDefinitionsModule (Module) - Defines special runes for tool enhancements.
local RuneDefinitions = {}

RuneDefinitions.Runes = {
	["Rune of Luck"] = {
		successBonus = 0.05,
		effectDescription = "Increases premium currency drop chance by 10%.",
		effectType = "Luck"
	},
	["Rune of Plenty"] = {
		successBonus = 0.05,
		effectDescription = "Grants a chance for double resource drop.",
		effectType = "Plenty"
	}
}

return RuneDefinitions
