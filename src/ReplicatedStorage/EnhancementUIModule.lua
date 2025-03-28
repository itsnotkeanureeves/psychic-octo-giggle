-- EnhancementUIModule.lua (Module)
-- 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIUtilityModule = require(ReplicatedStorage:WaitForChild("UIUtilityModule"))
local EnhancementCalculator = require(ReplicatedStorage:WaitForChild("EnhancementCalculator"))
local InventoryEventsModule = require(ReplicatedStorage:WaitForChild("RemoteEventModules"):WaitForChild("InventoryEventsModule"))
local InventoryUpdateEvent = InventoryEventsModule.GetInventoryUpdateEvent()
local EnhancementUIModule = {}

-- UI References
EnhancementUIModule.screenGui = UIUtilityModule.GetOrCreateMainGui()
EnhancementUIModule.selectedTool = nil
EnhancementUIModule.toolsData = {} -- Store tool data for calculations

-- Soul Stone variables
EnhancementUIModule.soulStoneCount = 0
EnhancementUIModule.maxSoulStoneCount = 0 -- Updates based on player inventory

-- Create Enhancement Window
function EnhancementUIModule.CreateEnhancementWindow()
    -- Enhancement Window Frame 
    local enhancementWindow = EnhancementUIModule.screenGui:FindFirstChild("EnhancementWindow") or Instance.new("Frame")
    enhancementWindow.Name = "EnhancementWindow"
    enhancementWindow.Size = UDim2.new(0, 300, 0, 250) -- Increased height for success chance display
    enhancementWindow.Position = UDim2.new(0.5, -150, 0.5, -125)
    enhancementWindow.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    enhancementWindow.Visible = false
    enhancementWindow.Parent = EnhancementUIModule.screenGui
    EnhancementUIModule.enhancementWindow = enhancementWindow
    
    -- Dropdown Button 
    local dropdownButton = enhancementWindow:FindFirstChild("DropdownButton") or Instance.new("TextButton")
    dropdownButton.Name = "DropdownButton"
    dropdownButton.Size = UDim2.new(0.8, 0, 0.15, 0) -- Adjusted size
    dropdownButton.Position = UDim2.new(0.1, 0, 0.25, 0) -- Adjusted position
    dropdownButton.Text = "Select Tool"
    dropdownButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    dropdownButton.Parent = enhancementWindow
    
    -- Tool List 
    local toolList = enhancementWindow:FindFirstChild("ToolList") or Instance.new("Frame")
    toolList.Name = "ToolList"
    toolList.Size = UDim2.new(0.8, 0, 0.35, 0) -- Adjusted size
    toolList.Position = UDim2.new(0.1, 0, 0.4, 0) -- Adjusted position
    toolList.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    toolList.Visible = false
    toolList.Parent = enhancementWindow
    
    -- Enhancement Window Title 
    local enhancementTitle = enhancementWindow:FindFirstChild("Title") or Instance.new("TextLabel")
    enhancementTitle.Name = "Title"
    enhancementTitle.Size = UDim2.new(0.7, 0, 0.2, 0)
    enhancementTitle.Text = "Enhance Your Tool"
    enhancementTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    enhancementTitle.Parent = enhancementWindow
    
    -- Enhancement Window Close Button 
    local closeButton = enhancementWindow:FindFirstChild("CloseButton") or Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0.3, 0, 0.2, 0)
    closeButton.Position = UDim2.new(0.7, 0, 0)
    closeButton.Text = "X"
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.Parent = enhancementWindow
    
    -- Success Chance Label
    local successChanceLabel = enhancementWindow:FindFirstChild("SuccessChanceLabel") or Instance.new("TextLabel")
    successChanceLabel.Name = "SuccessChanceLabel"
    successChanceLabel.Size = UDim2.new(0.3, 0, 0.6, 0)  -- Larger size
    successChanceLabel.Position = UDim2.new(-0.4, 0, 0.2, 0)  -- Moved to left side
    successChanceLabel.Text = "Success\nChance:\n0%"  -- Multi-line format
    successChanceLabel.TextSize = 18  -- Larger text
    successChanceLabel.Font = Enum.Font.SourceSansBold  -- Bold font
    successChanceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    successChanceLabel.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    successChanceLabel.TextWrapped = true
    successChanceLabel.Parent = enhancementWindow
    EnhancementUIModule.successChanceLabel = successChanceLabel
    
    -- Enhance Attempt Button 
    local enhanceButton = enhancementWindow:FindFirstChild("EnhanceButton") or Instance.new("TextButton")
    enhanceButton.Name = "EnhanceButton"
    enhanceButton.Size = UDim2.new(0.8, 0, 0.15, 0) -- Adjusted size
    enhanceButton.Position = UDim2.new(0.1, 0, 0.8, 0) -- Adjusted position
    enhanceButton.Text = "Enhance Tool"
    enhanceButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    enhanceButton.Parent = enhancementWindow
    
    -- Toggle Enhancement Window Button 
    local toggleEnhanceButton = EnhancementUIModule.screenGui:FindFirstChild("ToggleEnhanceButton") or Instance.new("TextButton")
    toggleEnhanceButton.Name = "ToggleEnhanceButton"
    toggleEnhanceButton.Size = UDim2.new(0, 120, 0, 40)
    toggleEnhanceButton.Position = UDim2.new(0.8, 0, 0.05, 0)
    toggleEnhanceButton.Text = "Enhance Tool"
    toggleEnhanceButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    toggleEnhanceButton.Parent = EnhancementUIModule.screenGui
    
        -- Soul Stone Section
    local soulStoneSection = enhancementWindow:FindFirstChild("SoulStoneSection") or Instance.new("Frame")
    soulStoneSection.Name = "SoulStoneSection"
    soulStoneSection.Size = UDim2.new(0.8, 0, 0.15, 0)
    soulStoneSection.Position = UDim2.new(0.1, 0, 1, 0) -- Adjust position as needed
    soulStoneSection.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    soulStoneSection.Parent = enhancementWindow

    -- Soul Stone Label
    local soulStoneLabel = soulStoneSection:FindFirstChild("SoulStoneLabel") or Instance.new("TextLabel")
    soulStoneLabel.Name = "SoulStoneLabel"
    soulStoneLabel.Size = UDim2.new(0.4, 0, 1, 0)
    soulStoneLabel.Position = UDim2.new(0, 0, 0, 0)
    soulStoneLabel.Text = "Soul Stones: 0"
    soulStoneLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    soulStoneLabel.BackgroundTransparency = 1
    soulStoneLabel.Parent = soulStoneSection

    -- Decrease Soul Stone Button
    local decreaseSoulStoneButton = soulStoneSection:FindFirstChild("DecreaseSoulStoneButton") or Instance.new("TextButton")
    decreaseSoulStoneButton.Name = "DecreaseSoulStoneButton"
    decreaseSoulStoneButton.Size = UDim2.new(0.15, 0, 1, 0)
    decreaseSoulStoneButton.Position = UDim2.new(0.4, 0, 0, 0)
    decreaseSoulStoneButton.Text = "-"
    decreaseSoulStoneButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
    decreaseSoulStoneButton.Parent = soulStoneSection

    -- Increase Soul Stone Button
    local increaseSoulStoneButton = soulStoneSection:FindFirstChild("IncreaseSoulStoneButton") or Instance.new("TextButton")
    increaseSoulStoneButton.Name = "IncreaseSoulStoneButton"
    increaseSoulStoneButton.Size = UDim2.new(0.15, 0, 1, 0)
    increaseSoulStoneButton.Position = UDim2.new(0.55, 0, 0, 0)
    increaseSoulStoneButton.Text = "+"
    increaseSoulStoneButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    increaseSoulStoneButton.Parent = soulStoneSection

    -- Soul Stone Count Display
    local soulStoneCountDisplay = soulStoneSection:FindFirstChild("SoulStoneCountDisplay") or Instance.new("TextLabel")
    soulStoneCountDisplay.Name = "SoulStoneCountDisplay"
    soulStoneCountDisplay.Size = UDim2.new(0.3, 0, 1, 0)
    soulStoneCountDisplay.Position = UDim2.new(0.7, 0, 0, 0)
    soulStoneCountDisplay.Text = "0"
    soulStoneCountDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
    soulStoneCountDisplay.BackgroundTransparency = 1
    soulStoneCountDisplay.Parent = soulStoneSection

    -- Modifier Details Label
    local modifierDetailsLabel = enhancementWindow:FindFirstChild("ModifierDetailsLabel") or Instance.new("TextLabel")
    modifierDetailsLabel.Name = "ModifierDetailsLabel"
    modifierDetailsLabel.Size = UDim2.new(0.8, 0, 0.15, 0)
    modifierDetailsLabel.Position = UDim2.new(0.1, 0, 1.2, 0) -- Position below SoulStoneSection
    modifierDetailsLabel.Text = "Modifiers: None"
    modifierDetailsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    modifierDetailsLabel.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    modifierDetailsLabel.TextWrapped = true
    modifierDetailsLabel.Parent = enhancementWindow
    
    EnhancementUIModule.dropdownButton = dropdownButton
    EnhancementUIModule.toolList = toolList
    EnhancementUIModule.enhanceButton = enhanceButton
    EnhancementUIModule.toggleEnhanceButton = toggleEnhanceButton
    EnhancementUIModule.closeButton = closeButton
    EnhancementUIModule.soulStoneLabel = soulStoneLabel
    EnhancementUIModule.soulStoneCountDisplay = soulStoneCountDisplay
    EnhancementUIModule.modifierDetailsLabel = modifierDetailsLabel

    return enhancementWindow
end

-- Update the tool list in the enhancement window
function EnhancementUIModule.UpdateToolList(tools)
    -- Store the tools data for later calculations
    EnhancementUIModule.toolsData = tools
    
    -- Clear previous tool buttons
    for _, child in pairs(EnhancementUIModule.toolList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local toolDisplayNames = {}
    for uuid, toolData in pairs(tools) do
        -- Use the displayName instead of the UUID for display
        local displayName = toolData.displayName

        table.insert(toolDisplayNames, displayName)

        -- Create a button for each tool in dropdown
        local toolButton = Instance.new("TextButton")
        toolButton.Size = UDim2.new(1, 0, 0.2, 0)
        toolButton.Text = displayName
        toolButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
        toolButton.Parent = EnhancementUIModule.toolList

        -- When clicked, select tool and update dropdown text and success chance
        toolButton.MouseButton1Click:Connect(function()
            -- Store the UUID as the selected tool, but use displayName for UI
            EnhancementUIModule.selectedTool = uuid
            EnhancementUIModule.dropdownButton.Text = displayName
            EnhancementUIModule.toolList.Visible = false
            EnhancementUIModule.UpdateSuccessChance(uuid)
            print("[DEBUG CLIENT] Selected Tool: " .. displayName)
        end)
    end

    -- Default to first tool if no selection
    if #toolDisplayNames > 0 then
        local firstDisplayName = toolDisplayNames[1]
        -- Find the corresponding UUID for the first display name
        for uuid, toolData in pairs(tools) do
            if toolData.displayName == firstDisplayName then
                EnhancementUIModule.selectedTool = uuid
                EnhancementUIModule.UpdateSuccessChance(uuid)
                break
            end
        end
        EnhancementUIModule.dropdownButton.Text = firstDisplayName
    else
        EnhancementUIModule.selectedTool = nil
        EnhancementUIModule.dropdownButton.Text = "Select Tool"
        EnhancementUIModule.UpdateSuccessChance(nil)
    end
end

-- Success Chance Display using the centralized calculator
function EnhancementUIModule.UpdateSuccessChance(toolId)
    if not toolId or not EnhancementUIModule.toolsData[toolId] then
        EnhancementUIModule.successChanceLabel.Text = "Success\nChance:\n0%"
        return
    end
    
    local tool = EnhancementUIModule.toolsData[toolId]
    
    -- Create modifiers with current SoulStone count
    local modifiers = {
        soulStoneCount = EnhancementUIModule.soulStoneCount or 0
    }
    
    -- Use the centralized calculator for chance calculation with modifiers
    local successChance = EnhancementCalculator.CalculateSuccessChance(tool.enhancementLevel, modifiers)
    
    -- Format the chance for display
    local successPercentage = EnhancementCalculator.FormatSuccessChance(successChance)
    
    -- Update the label with the success chance in a more prominent format
    EnhancementUIModule.successChanceLabel.Text = "Success\nChance:\n" .. successPercentage .. "%"
    
    -- Get appropriate color based on success percentage
    EnhancementUIModule.successChanceLabel.TextColor3 = EnhancementCalculator.GetColorForChance(successPercentage)
end

function EnhancementUIModule.UpdateMaxSoulStones(inventoryData)
    -- Get SoulStone count from inventory data
    local soulStoneCount = inventoryData and inventoryData.items and inventoryData.items["SoulStone"] or 0
    
    -- Update the max count
    EnhancementUIModule.maxSoulStoneCount = soulStoneCount
    
    -- Update SoulStone label to show available count
    if EnhancementUIModule.soulStoneLabel then
        EnhancementUIModule.soulStoneLabel.Text = "Soul Stones: " .. tostring(soulStoneCount)
    end
    
    -- Ensure current count doesn't exceed max
    if EnhancementUIModule.soulStoneCount > soulStoneCount then
        EnhancementUIModule.soulStoneCount = math.max(0, soulStoneCount)
        EnhancementUIModule.soulStoneCountDisplay.Text = tostring(EnhancementUIModule.soulStoneCount)
        
        -- Update success chance with new count
        if EnhancementUIModule.selectedTool then
            EnhancementUIModule.UpdateSuccessChance(EnhancementUIModule.selectedTool)
        end
    end
end

-- Add Soul Stone count changing function here
function EnhancementUIModule.UpdateSoulStoneCount(delta)
    local newCount = EnhancementUIModule.soulStoneCount + delta
    
    -- Cannot go below 0 or above player's inventory amount
    newCount = math.max(0, math.min(newCount, EnhancementUIModule.maxSoulStoneCount))
    
    EnhancementUIModule.soulStoneCount = newCount
    EnhancementUIModule.soulStoneCountDisplay.Text = tostring(newCount)
    
    -- Update success chance display with new count
    if EnhancementUIModule.selectedTool then
        EnhancementUIModule.UpdateSuccessChance(EnhancementUIModule.selectedTool)
    end
end

-- Toggle Enhancement Window Visibility
function EnhancementUIModule.ToggleEnhancementUI()
    EnhancementUIModule.enhancementWindow.Visible = not EnhancementUIModule.enhancementWindow.Visible
end

-- Enhance Selected Tool
function EnhancementUIModule.EnhanceSelectedTool()
    if EnhancementUIModule.selectedTool then
        if EnhancementUIModule.soulStoneCount <= 0 then
            -- Show error message if no SoulStones are being used
            local errorMessage = EnhancementUIModule.screenGui:FindFirstChild("ErrorMessage") or Instance.new("TextLabel")
            errorMessage.Name = "ErrorMessage"
            errorMessage.Size = UDim2.new(0, 200, 0, 50)
            errorMessage.Position = UDim2.new(0.5, -100, 0.7, 0)
            errorMessage.Text = "At least 1 SoulStone is required!"
            errorMessage.TextColor3 = Color3.fromRGB(255, 0, 0)
            errorMessage.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            errorMessage.Parent = EnhancementUIModule.screenGui
            
            -- Remove the error message after 3 seconds
            game:GetService("Debris"):AddItem(errorMessage, 1)
            return
        end
        
        -- Sends enhancement request to server with SoulStone count
        game.ReplicatedStorage.EnhanceRequest:FireServer(EnhancementUIModule.selectedTool, nil, EnhancementUIModule.soulStoneCount)
        print("[DEBUG CLIENT] Sent enhancement request for:", EnhancementUIModule.selectedTool, "with", EnhancementUIModule.soulStoneCount, "SoulStones")
        
        -- Reset SoulStone count to 0 after enhancement attempt
        EnhancementUIModule.soulStoneCount = 0
        EnhancementUIModule.soulStoneCountDisplay.Text = "0"
    else
        print("[ERROR CLIENT] No tool selected for enhancement.")
    end
end

-- Initialize module
function EnhancementUIModule.Initialize()
    EnhancementUIModule.CreateEnhancementWindow()
    
    -- Connect Enhancement UI Buttons
    EnhancementUIModule.toggleEnhanceButton.MouseButton1Click:Connect(EnhancementUIModule.ToggleEnhancementUI)
    EnhancementUIModule.closeButton.MouseButton1Click:Connect(EnhancementUIModule.ToggleEnhancementUI)
    EnhancementUIModule.dropdownButton.MouseButton1Click:Connect(function()
        EnhancementUIModule.toolList.Visible = not EnhancementUIModule.toolList.Visible
    end)
    EnhancementUIModule.enhanceButton.MouseButton1Click:Connect(EnhancementUIModule.EnhanceSelectedTool)
    
    -- Connect Soul Stone increment and decrement buttons
    local soulStoneSection = EnhancementUIModule.enhancementWindow:FindFirstChild("SoulStoneSection")
    if soulStoneSection then
        local increaseSoulStoneButton = soulStoneSection:FindFirstChild("IncreaseSoulStoneButton")
        local decreaseSoulStoneButton = soulStoneSection:FindFirstChild("DecreaseSoulStoneButton")
        
        if increaseSoulStoneButton then
            increaseSoulStoneButton.MouseButton1Click:Connect(function()
                EnhancementUIModule.UpdateSoulStoneCount(1)
            end)
        end
        
        if decreaseSoulStoneButton then
            decreaseSoulStoneButton.MouseButton1Click:Connect(function()
                EnhancementUIModule.UpdateSoulStoneCount(-1)
            end)
        end
    end
    
    -- Listen for enhancement results to update the success chance
    game.ReplicatedStorage.EnhanceResult.OnClientEvent:Connect(function(success, message)
        if success and EnhancementUIModule.selectedTool then
            -- Update the chance after a successful enhancement (tool level increased)
            EnhancementUIModule.UpdateSuccessChance(EnhancementUIModule.selectedTool)
        end
    end)
    
    -- Listen for inventory updates to update SoulStone count
    InventoryUpdateEvent.OnClientEvent:Connect(function(inventoryData)
        EnhancementUIModule.UpdateMaxSoulStones(inventoryData)
    end)
    
    -- Initialize maxSoulStoneCount to 0 (will be updated when inventory updates)
    EnhancementUIModule.maxSoulStoneCount = 0
    EnhancementUIModule.soulStoneCount = 0
    EnhancementUIModule.soulStoneCountDisplay.Text = "0"
    
    return EnhancementUIModule
end

return EnhancementUIModule