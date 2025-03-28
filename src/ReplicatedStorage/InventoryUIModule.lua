-- InventoryUIModule.lua (Client Module)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryEventsModule = require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("InventoryEventsModule"))
local UIUtilityModule = require(ReplicatedStorage:WaitForChild("UIUtilityModule"))

local InventoryUIModule = {}

-- UI References
InventoryUIModule.screenGui = UIUtilityModule.GetOrCreateMainGui()
InventoryUIModule.toolSlots = {}

-- Create Inventory Display
function InventoryUIModule.CreateInventoryUI()
    -- Inventory Label
    local inventoryLabel = InventoryUIModule.screenGui:FindFirstChild("InventoryLabel") or Instance.new("TextLabel")
    inventoryLabel.Name = "InventoryLabel"
    inventoryLabel.Size = UDim2.new(0, 250, 0, 200)
    inventoryLabel.Position = UDim2.new(0, 10, 0, 10)
    inventoryLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    inventoryLabel.BackgroundTransparency = 0.5
    inventoryLabel.BorderSizePixel = 0
    inventoryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    inventoryLabel.TextXAlignment = Enum.TextXAlignment.Left
    inventoryLabel.TextYAlignment = Enum.TextYAlignment.Top
    inventoryLabel.Text = "Inventory:\n(Empty)"
    inventoryLabel.Parent = InventoryUIModule.screenGui
    inventoryLabel.Visible = false
    InventoryUIModule.inventoryLabel = inventoryLabel
    
    -- Tool slots container
    local toolSlotsFrame = inventoryLabel:FindFirstChild("ToolSlots") or Instance.new("Frame")
    toolSlotsFrame.Name = "ToolSlots"
    toolSlotsFrame.Size = UDim2.new(0.3, 0, 0.4, 0)
    toolSlotsFrame.Position = UDim2.new(1, 0, 0, 0)
    toolSlotsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    toolSlotsFrame.Parent = inventoryLabel
    InventoryUIModule.toolSlotsFrame = toolSlotsFrame
    
    return inventoryLabel
end

-- Initialize Tool Slots
function InventoryUIModule.InitializeToolSlots()
    -- Clear old slots
    for _, slot in pairs(InventoryUIModule.toolSlots) do
        if typeof(slot) == "table" and slot.frame then
            slot.frame:Destroy()
        end
    end
    InventoryUIModule.toolSlots = {}

    -- Define default gathering tool types 
    local toolTypes = { "Wood", "Ore", "Fishing", "Combat" }

    local yOffset = 0

    for _, toolType in ipairs(toolTypes) do
        -- Create slot frame for tool type 
        local slotFrame = Instance.new("Frame")
        slotFrame.Size = UDim2.new(1, 0, 0.15, 0)
        slotFrame.Position = UDim2.new(0, 0, yOffset, 0)
        slotFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        slotFrame.Parent = InventoryUIModule.toolSlotsFrame

        -- Label for slot 
        local slotLabel = Instance.new("TextLabel")
        slotLabel.Text = toolType .. " Tool: None"
        slotLabel.Size = UDim2.new(0.5, 0, 1, 0)
        slotLabel.BackgroundTransparency = 1
        slotLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        slotLabel.Parent = slotFrame

        -- Dropdown Buttons to Select Tool 
        local dropdownButton = Instance.new("TextButton")
        dropdownButton.Size = UDim2.new(1, 0, 1, 0)
        dropdownButton.Position = UDim2.new(0.5, 50, 0, 0)
        dropdownButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
        dropdownButton.Text = "Select"
        dropdownButton.Parent = slotFrame

        -- Dropdown List (Initially Hidden) 
        local toolListFrame = Instance.new("Frame")
        toolListFrame.Size = UDim2.new(1, 0, 1, 0)
        toolListFrame.Position = UDim2.new(0.5, 0, 1, 50)
        toolListFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        toolListFrame.Visible = false
        toolListFrame.Parent = slotFrame

        -- Store elements for later access 
        InventoryUIModule.toolSlots[toolType] = {
            frame = slotFrame,
            slotLabel = slotLabel,  
            dropdownButton = dropdownButton,
            toolListFrame = toolListFrame
        }

        -- Toggle Dropdown Visibility 
        dropdownButton.MouseButton1Click:Connect(function()
            toolListFrame.Visible = not toolListFrame.Visible
        end)

        yOffset = yOffset + 0.15
    end
end

-- Update tool slots in inventory UI 
function InventoryUIModule.UpdateToolSelectionUI(invData)
    local activeTools = invData.activeTools or {}

    for toolType, slotFrame in pairs(InventoryUIModule.toolSlots) do
        local currentToolId = activeTools[toolType]
        local currentTool = invData.tools and invData.tools[currentToolId] or nil

        -- Update slot label with active tool 
        if currentTool then
            slotFrame.slotLabel.Text = toolType .. " Tool: " .. currentTool.displayName
        else
            slotFrame.slotLabel.Text = toolType .. " Tool: None"
        end

        -- Populate the dropdown with tools of this type 
        for _, child in pairs(slotFrame.toolListFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end

        if invData.tools then
            for toolId, toolData in pairs(invData.tools) do
                if toolData.toolType == toolType then
                    local toolButton = Instance.new("TextButton")
                    toolButton.Size = UDim2.new(1, 0, 1, 0)
                    toolButton.Text = toolData.displayName
                    toolButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                    toolButton.Parent = slotFrame.toolListFrame

                    -- Handle tool selection 
                    toolButton.MouseButton1Click:Connect(function()
                        slotFrame.slotLabel.Text = toolType .. " Tool: " .. toolData.displayName
                        slotFrame.toolListFrame.Visible = false
                        InventoryEventsModule.GetSetActiveToolEvent():FireServer(toolId)
                    end)
                end
            end
        end
    end
end

-- Update the inventory UI display 
function InventoryUIModule.UpdateInventoryUI(invData)
    local text = "Inventory:\n"
    local hasItems = false
    
    -- Display items
    if invData.items and next(invData.items) then
        for itemName, count in pairs(invData.items) do
            text = text .. "- " .. itemName .. ": " .. tostring(count) .. "\n"
        end
    else
        text = text .. "(No Items)\n"
    end

    -- Display tools
    text = text .. "\nTools:\n"
    if invData.tools and next(invData.tools) then
        for uuid, toolData in pairs(invData.tools) do
            text = text .. "- " .. toolData.displayName .. " (Durability: " .. tostring(toolData.durability) .. ")\n"
        end
    else
        text = text .. "(No Tools)"
    end

    InventoryUIModule.inventoryLabel.Text = text
    
    -- Fire event for EnhancementUIModule to update tool lists
    if invData.tools then
        -- Use a custom event to communicate between modules
        if InventoryUIModule.OnToolsUpdated then
            InventoryUIModule.OnToolsUpdated:Fire(invData.tools)
        end
    end
end

-- Toggle Inventory Visibility
function InventoryUIModule.SetInventoryUIVisible(isVisible)
    InventoryUIModule.inventoryLabel.Visible = isVisible
end

-- Initialize module
function InventoryUIModule.Initialize()
    InventoryUIModule.CreateInventoryUI()
    InventoryUIModule.InitializeToolSlots()
    
    -- Create custom event for inter-module communication
    InventoryUIModule.OnToolsUpdated = Instance.new("BindableEvent")
    
    return InventoryUIModule
end

return InventoryUIModule