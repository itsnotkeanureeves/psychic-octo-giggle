--[[
    NPCSpawner.lua
    
    PURPOSE:
    Provides utility functions for spawning test NPCs for combat system testing.
    Creates NPCs with humanoids that can be targeted by player abilities.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatPath = ServerScriptService.Combat
local SharedPath = ReplicatedStorage.Combat.Shared

-- Get CombatCore
local CombatCore = require(SharedPath.CombatCore)

-- NPCSpawner module
local NPCSpawner = {}

-- Create a test NPC
function NPCSpawner:CreateTestNPC(position, npcType)
    position = position or Vector3.new(0, 5, 0)
    npcType = npcType or "Target"
    
    print("[NPCSpawner] Creating test NPC:", npcType)
    
    -- Create NPC model
    local model = Instance.new("Model")
    model.Name = npcType .. " NPC"
    
    -- Create humanoid
    local humanoid = Instance.new("Humanoid")
    humanoid.Parent = model
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    
    -- Create parts for the NPC
    local torso = Instance.new("Part")
    torso.BrickColor = BrickColor.new("Bright red")
    torso.Size = Vector3.new(2, 2, 1)
    torso.CFrame = CFrame.new(position)
    torso.Anchored = false
    torso.CanCollide = true
    torso.Parent = model
    torso.Name = "HumanoidRootPart"
    
    -- Create head
    local head = Instance.new("Part")
    head.BrickColor = BrickColor.new("Bright yellow")
    head.Size = Vector3.new(1, 1, 1)
    head.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
    head.Anchored = false
    head.CanCollide = true
    head.Parent = model
    head.Name = "Head"
    
    -- Create welds
    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = torso
    headWeld.Part1 = head
    headWeld.Parent = torso
    
    -- Set up humanoid properties
    humanoid.HipHeight = 0
    
    -- Register with EntitySystem
    if CombatCore:IsInitialized() then
        local entitySystem = CombatCore:GetSystem("entitySystem")
        local npcAdapter = CombatCore:GetSystem("npcAdapter")
        
        if entitySystem then
            -- NPC attributes
            local attributes = {
                level = 1,
                health = 100,
                maxHealth = 100,
                power = 10,
                defense = 5,
                team = "Enemy"
            }
            
            -- Create proper NPC entity if adapter exists
            if npcAdapter then
                local npcEntity = npcAdapter:CreateNPC(model, attributes)
                print("[NPCSpawner] Created NPC entity using adapter")
            else
                print("[NPCSpawner] Warning: NPCAdapter not found")
            end
            
            -- Register NPC with EntitySystem
            local entityId = entitySystem:RegisterNPC(model)
            print("[NPCSpawner] Registered NPC with entity ID:", entityId)
            
            -- Set EntityId attribute for client-side identification
            model:SetAttribute("EntityId", entityId)
            
            -- Add test ability to NPC if needed
            local abilitySystem = CombatCore:GetSystem("abilitySystem")
            if abilitySystem then
                abilitySystem:GrantAbility(entityId, "NPC_ATTACK")
                print("[NPCSpawner] Granted NPC_ATTACK ability to NPC")
            end
            
            -- Parent model to workspace
            model.Parent = workspace
            
            -- Return entity ID and model
            return entityId, model
        else
            warn("[NPCSpawner] EntitySystem not available")
        end
    else
        warn("[NPCSpawner] CombatCore not initialized")
    end
    
    -- Parent model to workspace even if registration failed
    model.Parent = workspace
    
    return nil, model
end

-- Fixed SpawnMultiple function that matches the AutoSpawnNPCs usage pattern
function NPCSpawner:SpawnMultiple(npcType, centerPosition, radius, count)
    print("[NPCSpawner] Spawning multiple NPCs:", npcType, "Count:", count)
    
    local results = {}
    
    -- Handle the case when positions is a string (npcType) followed by position
    if type(npcType) == "string" and typeof(centerPosition) == "Vector3" then
        -- Spawn NPCs in a circle around the center position
        for i = 1, count do
            local angle = (i / count) * math.pi * 2
            local offsetX = math.cos(angle) * radius
            local offsetZ = math.sin(angle) * radius
            local position = centerPosition + Vector3.new(offsetX, 0, offsetZ)
            
            local entityId, model = self:CreateTestNPC(position, npcType)
            if entityId then
                table.insert(results, {
                    entityId = entityId,
                    model = model
                })
            end
        end
    end
    
    return results
end

return NPCSpawner