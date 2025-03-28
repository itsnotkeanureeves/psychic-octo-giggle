-- EnhancementServer (Script) - Listens for enhancement requests and updates player tools.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnhancementModule = require(ServerScriptService:WaitForChild("EnhancementModule"))

local EnhanceRequest = ReplicatedStorage:FindFirstChild("EnhanceRequest") or Instance.new("RemoteEvent")
EnhanceRequest.Name = "EnhanceRequest"
EnhanceRequest.Parent = ReplicatedStorage


-- need to break this out into enhancementeventsmodule
local EnhanceResult = ReplicatedStorage:FindFirstChild("EnhanceResult") or Instance.new("RemoteEvent")
EnhanceResult.Name = "EnhanceResult"
EnhanceResult.Parent = ReplicatedStorage


-- Listen for Enhancement Requests
EnhanceRequest.OnServerEvent:Connect(function(player, toolName, runeName, soulStoneCount)
    print("[DEBUG SERVER] Enhancement attempt received for:", toolName, "Rune:", runeName or "None", "SoulStones:", soulStoneCount or 0)
    
    -- Check if player has enough SoulStones
    local inventory = require(ServerScriptService.InventoryManager):GetInventory(player)
    if not inventory or not inventory.items["SoulStone"] or inventory.items["SoulStone"] < (soulStoneCount or 1) then
        EnhanceResult:FireClient(player, false, "Not enough SoulStones!")
        return
    end
    
    -- Consume SoulStones
    if soulStoneCount and soulStoneCount > 0 then
        require(ServerScriptService.InventoryManager):AddItem(player, "SoulStone", -soulStoneCount)
    end
    
    -- Pass SoulStone count to enhancement calculation
    local modifiers = {soulStoneCount = soulStoneCount or 0}
    local success, message = EnhancementModule.AttemptEnhancement(player, toolName, runeName, modifiers)
    
    -- hard save
    local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))
    PlayerDataManager:SaveData(player, true) 

    -- Send enhancement result back to the client
    EnhanceResult:FireClient(player, success, message)
end)