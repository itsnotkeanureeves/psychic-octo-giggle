-- ItemRarityDefinitionsModule.lua
--[[
local ItemRarityDefinitionsModule = 
require(game:GetService("ServerScriptService"):WaitForChild("GameData"):WaitForChild("Definitions"):WaitForChild("ItemRarityDefinitionsModule"))
]]--
-- Change how Rarity looks
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDefinitions = require(game:GetService("ReplicatedStorage"):WaitForChild("GameData"):WaitForChild("Definitions"):WaitForChild("ItemDefinitionsModule"))
local ItemRarityModule = {}

-- Define rarity levels and their properties
ItemRarityModule.Rarities = {
    Common = {
        color = Color3.fromRGB(255, 255, 255), -- White
        displayTime = 2, -- UI NOTIFICATIONS: seconds
        floatSpeed = 1, -- UI NOTIFICATIONS: base speed
        scale = 1, -- UI NOTIFICATIONS: base scale
    },
    Uncommon = {
        color = Color3.fromRGB(100, 255, 100), -- Green
        displayTime = 2.2,
        floatSpeed = 1.1,
        scale = 1.05,
    },
    Rare = {
        color = Color3.fromRGB(0, 170, 255), -- Blue
        displayTime = 2.5,
        floatSpeed = 1.2,
        scale = 1.1,
    },
    Epic = {
        color = Color3.fromRGB(170, 0, 255), -- Purple
        displayTime = 3,
        floatSpeed = 1.3,
        scale = 1.15,
    },
    Legendary = {
        color = Color3.fromRGB(255, 165, 0), -- Orange/Gold
        displayTime = 3.5,
        floatSpeed = 1.4,
        scale = 1.2,
    },
}

-- Function to get rarity for an item
function ItemRarityModule:GetItemRarity(itemName)
    local itemData = ItemDefinitions.Items[itemName]
    -- First check if rarity is defined in ItemDefinitions
    if itemData and itemData.rarity then
        return itemData.rarity
    end
    -- Fallback to our mapping
    return self.ItemRarities[itemName] or "Common"
end

-- Function to get rarity properties for an item
function ItemRarityModule:GetRarityPropertiesForItem(itemName)
    local rarity = self:GetItemRarity(itemName)
    return self.Rarities[rarity] or self.Rarities.Common
end

return ItemRarityModule