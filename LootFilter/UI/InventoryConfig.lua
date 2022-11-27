local addon, LF = ...

if LF.UI == nil then
    LF.UI = {}
end
LF.UI.InventoryConfig = {}


LF.UI.InventoryConfig.DisplayBagNum = 1 -- the bag to display
LF.UI.InventoryConfig.ItemsDisplayed = {} -- the frames of every item that has been displayed so far
LF.UI.InventoryConfig.Window = nil -- the Loot Filter window
LF.UI.InventoryConfig.InventoryFrame = nil -- the Inventory page
LF.UI.InventoryConfig.ShowSelectedCheckbox = nil -- the checkbox to show only the selected items
LF.UI.InventoryConfig.DeleteSelectedCheckbox = nil -- the checkbox to trigger auto deletion of the selected items
LF.UI.InventoryConfig.ViewSelectedButton = nil -- the button to open the view selected window
LF.UI.InventoryConfig.ReloadDisclaimerText = nil -- text to inform the user to use /reloadui to save settings
LF.UI.InventoryConfig.Tooltips = nil -- tooltips

LF.UI.InventoryConfig.RedisplayInventory = function(allowDeletionIfAutoDeleting)
    for _,v in pairs(LF.UI.InventoryConfig.ItemsDisplayed) do
        v:SetVisible(false)
    end
    LF.UI.InventoryConfig.DisplayItemsInBag(allowDeletionIfAutoDeleting)
    LF.UI.AutoDeleteConfirmation.UpdateDeletionConfirmationText()
    LF.UI.SelectedItemsConfig.RedisplaySelectedItems(true)
end

-- Displays an item from the inventory at the coordinates on the inventory frame
LF.UI.InventoryConfig.DisplayItem = function(bagSlot, itemSlot, posX, posY)
    local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(bagSlot, itemSlot))

    if idetail ~= nil then
        local colors = LF.Utility.GetColors(idetail)

        -- Make the border
        local borderFrame = nil
        if LF.UI.InventoryConfig.ItemsDisplayed['Border:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] == nil then
            borderFrame = UI.CreateFrame('Frame', 'Border:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type, LF.UI.InventoryConfig.InventoryFrame)
            borderFrame:EventAttach(Event.UI.Input.Mouse.Cursor.Move, function(self, h)
                -- There is a bug with StatWeights. Imhothar's bag addon has the same bug.
                local type, shown = Inspect.Tooltip()
                if type ~= 'item' then
                    Command.Tooltip(idetail.id)
                elseif shown ~= idetail.id then
                    Command.Tooltip(idetail.id)
                end
            end, 'LF Item Start Mouseover')
            borderFrame:EventAttach(Event.UI.Input.Mouse.Cursor.Out, function(self, h)
                Command.Tooltip(nil)
            end, 'LF Item End Mouseover')

            LF.UI.InventoryConfig.Tooltips:InjectEvents(borderFrame,
                function(t)
                    t:SetFontSize(16)
                    t:SetFontColor(colors.rf, colors.gf, colors.bf, 1)
                    if LF.Settings.LockedItems[idetail.type] ~= nil then
                        return '[LOCKED]\n' .. idetail.name .. (idetail.stack ~= nil and idetail.stack > 1 and ' x' .. idetail.stack or '')
                    else
                        return idetail.name .. (idetail.stack ~= nil and idetail.stack > 1 and ' x' .. idetail.stack or '')
                    end
                end
            )
            -- Toggle item selection on click if we are not auto deleting
            borderFrame:EventAttach(Event.UI.Input.Mouse.Left.Down, function(self, h) -- Left click to select the item
                if not LF.Settings.AutoDeleting and LF.Settings.LockedItems[idetail.type] == nil then
                    -- Toggle selection
                    if LF.Settings.SelectedItems[idetail.type] == nil then
                        LF.Settings.SelectedItems[idetail.type] = {
                            name = idetail.name,
                            icon = idetail.icon,
                            rarity = idetail.rarity
                        }
                        -- Check if the item is currently equipped
                        for itype,_ in pairs(LF.Utility.GetEquippedItemsList()) do
                            if idetail.type == itype then
                                LF.UI.CurrentlyEquippedWarning.CreateCurrentlyEquippedWarningWindow()
                            end
                        end
                        LF.Settings.PushUpdatesToSavedVariables()
                    else
                        LF.Settings.SelectedItems[idetail.type] = nil
                        LF.Settings.PushUpdatesToSavedVariables()
                    end
                    if LF.UI.InventoryConfig.ShowSelectedCheckbox:GetChecked() == true then
                        Command.Tooltip(nil)
                        LF.UI.InventoryConfig.Tooltips.SetVisible(false)
                    end
                    LF.UI.InventoryConfig.RedisplayInventory()
                end
            end, 'Event.UI.Input.Mouse.Left.Down')
            borderFrame:EventAttach(Event.UI.Input.Mouse.Right.Down, function(self, h) -- Right click to make item locked
                if not LF.Settings.AutoDeleting then
                    -- Toggle selection
                    if LF.Settings.LockedItems[idetail.type] == nil then
                        LF.Settings.LockedItems[idetail.type] = {
                            name = idetail.name,
                            icon = idetail.icon,
                            rarity = idetail.rarity
                        }
                        LF.Settings.SelectedItems[idetail.type] = nil
                        LF.Settings.PushUpdatesToSavedVariables()
                        LF.UI.InventoryConfig.Tooltips:SetText('[LOCKED]\n' .. idetail.name .. (idetail.stack ~= nil and idetail.stack > 1 and ' x' .. idetail.stack or ''))
                    else
                        LF.Settings.LockedItems[idetail.type] = nil
                        LF.Settings.PushUpdatesToSavedVariables()
                        LF.UI.InventoryConfig.Tooltips:SetText(idetail.name .. (idetail.stack ~= nil and idetail.stack > 1 and ' x' .. idetail.stack or ''))
                    end
                    if LF.UI.InventoryConfig.ShowSelectedCheckbox:GetChecked() == true then
                        Command.Tooltip(nil)
                        LF.UI.InventoryConfig.Tooltips.SetVisible(false)
                    end
                    LF.UI.InventoryConfig.RedisplayInventory()
                end
            end, 'Event.UI.Input.Mouse.Right.Down')
        else
            borderFrame = LF.UI.InventoryConfig.ItemsDisplayed['Border:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type]
        end
        -- Locked/selected item border logic
        if LF.Settings.LockedItems[idetail.type] ~= nil then
            -- If item is locked, make the border purple
            borderFrame:SetBackgroundColor(0.25, 0, 0.25)
            borderFrame:SetAlpha(1)
        elseif LF.Settings.SelectedItems[idetail.type] ~= nil then
            -- If item is selected, make the border yellow
            borderFrame:SetBackgroundColor(1, 1, 0)
            borderFrame:SetAlpha(1)
        else
            -- Otherwise, have no border
            borderFrame:SetAlpha(0)
        end
        borderFrame:SetPoint('TOPLEFT', LF.UI.InventoryConfig.InventoryFrame, 'TOPLEFT', posX, posY)
        borderFrame:SetWidth(72)
        borderFrame:SetHeight(72)
        borderFrame:SetLayer(5)
        borderFrame:SetVisible(true)

        LF.UI.InventoryConfig.ItemsDisplayed['Border:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] = borderFrame

        if LF.Settings.DisplayRarity then
            -- Make the rarity indicator
            local rarityBorderFrame =  nil
            if LF.UI.InventoryConfig.ItemsDisplayed['RarityBorder:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] == nil then
                rarityBorderFrame = UI.CreateFrame('Frame', 'RarityBorder:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type, LF.UI.InventoryConfig.InventoryFrame)
            else
                rarityBorderFrame = LF.UI.InventoryConfig.ItemsDisplayed['RarityBorder:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type]
            end
            rarityBorderFrame:SetBackgroundColor(colors.rf, colors.gf, colors.bf)
            rarityBorderFrame:SetPoint('TOPLEFT', LF.UI.InventoryConfig.InventoryFrame, 'TOPLEFT', posX + 4, posY + 4)
            rarityBorderFrame:SetWidth(5)
            rarityBorderFrame:SetHeight(6)
            rarityBorderFrame:SetLayer(15)
            rarityBorderFrame:SetVisible(true)
            if LF.Settings.AutoDeleting or LF.Settings.LockedItems[idetail.type] ~= nil then
                rarityBorderFrame:SetAlpha(0.5) -- Grey out the items if auto deleting or item is locked
            else
                rarityBorderFrame:SetAlpha(1)
            end
            LF.UI.InventoryConfig.ItemsDisplayed['RarityBorder:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] = rarityBorderFrame
        end

        -- Make the in game icon
        local itemIcon =  nil
        if LF.UI.InventoryConfig.ItemsDisplayed['Icon:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] == nil then
            itemIcon = UI.CreateFrame('Texture', 'Icon:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type, LF.UI.InventoryConfig.InventoryFrame)
        else
            itemIcon = LF.UI.InventoryConfig.ItemsDisplayed['Icon:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type]
        end
        itemIcon:SetWidth(64)
        itemIcon:SetHeight(64)
        itemIcon:SetPoint('TOPLEFT', LF.UI.InventoryConfig.InventoryFrame, 'TOPLEFT', posX+4, posY+4)
        itemIcon:SetLayer(10)
        itemIcon:SetTexture('Rift', idetail.icon)
        itemIcon:SetVisible(true)
        if LF.Settings.AutoDeleting or LF.Settings.LockedItems[idetail.type] ~= nil then
            itemIcon:SetAlpha(0.5) -- Grey out the items if auto deleting or item is locked
        else
            itemIcon:SetAlpha(1)
        end
        LF.UI.InventoryConfig.ItemsDisplayed['Icon:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] = itemIcon

        -- If the slot has multiple items in it, display text
        if idetail.stack ~= nil and idetail.stack > 1 then
            -- Display a text in the lower right detailing the quantity of the item
            local stackCount =  nil
            if LF.UI.InventoryConfig.ItemsDisplayed['Stack:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] == nil then
                stackCount = UI.CreateFrame('Text', 'Stack:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type, LF.UI.InventoryConfig.InventoryFrame)
            else
                stackCount = LF.UI.InventoryConfig.ItemsDisplayed['Stack:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type]
            end
            stackCount:SetPoint('TOPLEFT', LF.UI.InventoryConfig.InventoryFrame, 'TOPLEFT', posX + 63 - math.floor(11 * string.len(tostring(idetail.stack))), posY+42)
            stackCount:SetFontSize(18)
            stackCount:SetFontColor(1, 1, 1)
            stackCount:SetBackgroundColor(0, 0, 0)
            stackCount:SetText(tostring(idetail.stack))
            stackCount:SetLayer(15)
            stackCount:SetVisible(true)
            if LF.Settings.AutoDeleting or LF.Settings.LockedItems[idetail.type] ~= nil then
                stackCount:SetAlpha(0.5) -- Grey out the items if auto deleting or item is locked
            else
                stackCount:SetAlpha(1)
            end
            LF.UI.InventoryConfig.ItemsDisplayed['Stack:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] = stackCount
        end
    end
end


-- Select all items in a bag on right click. If all items are already selected, de-select all items instead.
LF.UI.InventoryConfig.ToggleSelectAllItemsInBag = function(bagSlotNum)
    -- Check if the bag exists
    local bag = Inspect.Item.Detail(Utility.Item.Slot.Inventory('bag', bagSlotNum))
    local currentlyEquippedItemSelected = false
    local itemsToDeselect = {}
    local unselectedItemFound = false
    if bag ~= nil then
        -- Loop through the items in the bag
        for slotNum = 1, bag.slots do
            -- Determine if an item to display exists at the coordinates
            local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(bagSlotNum, slotNum))
            if idetail ~= nil then
                if LF.Settings.SelectedItems[idetail.type] == nil and LF.Settings.LockedItems[idetail.type] == nil then
                    LF.Settings.SelectedItems[idetail.type] = {
                        name = idetail.name,
                        icon = idetail.icon,
                        rarity = idetail.rarity
                    }
                    LF.Settings.PushUpdatesToSavedVariables()
                    -- Check if the item is currently equipped
                    for itype,_ in pairs(LF.Utility.GetEquippedItemsList()) do
                        if idetail.type == itype then
                            currentlyEquippedItemSelected = true
                        end
                    end
                    unselectedItemFound = true
                else
                    itemsToDeselect[idetail.type] = {
                        name = idetail.name,
                        icon = idetail.icon,
                        rarity = idetail.rarity
                    }
                end
            end
        end
    end
    -- If all items in the bag are selected, Deselect all items in the bag instead
    if unselectedItemFound == false then
        for idetailType,_ in pairs(itemsToDeselect) do
            LF.Settings.SelectedItems[idetailType] = nil
            LF.Settings.PushUpdatesToSavedVariables()
        end
    else
        -- A currently equipped item got Selected. Make sure to warn the user!
        if currentlyEquippedItemSelected == true then
            LF.UI.CurrentlyEquippedWarning.CreateCurrentlyEquippedWarningWindow()
        end
    end
end


-- Displays a bag at the coordinates on the inventory frame
LF.UI.InventoryConfig.DisplayBag = function(bagSlotNum, posX, posY, numItemsInBag, numSelectedInBag)
    local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory('bag', bagSlotNum))

    if idetail ~= nil then
        local colors = LF.Utility.GetColors(idetail)

        -- Make the general border
        local borderFrame = nil
        if LF.UI.InventoryConfig.ItemsDisplayed['Border:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] == nil then
            borderFrame = UI.CreateFrame('Frame', 'Border:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type, LF.UI.InventoryConfig.InventoryFrame)
            -- Attach a click event to change the selected bag, and then Redisplay
            borderFrame:EventAttach(Event.UI.Input.Mouse.Left.Down, function(self, h)
                LF.UI.InventoryConfig.DisplayBagNum = bagSlotNum
                LF.UI.InventoryConfig.RedisplayInventory(true)
            end, 'Event.UI.Input.Mouse.Left.Down')
            -- Select all items in a bag on right click. If all items are already selected, de-select all items instead.
            borderFrame:EventAttach(Event.UI.Input.Mouse.Right.Down, function(self, h)
                if not LF.Settings.AutoDeleting then
                    LF.UI.InventoryConfig.ToggleSelectAllItemsInBag(bagSlotNum)
                end
                LF.UI.InventoryConfig.DisplayBagNum = bagSlotNum
                LF.UI.InventoryConfig.RedisplayInventory(true)
            end, 'Event.UI.Input.Mouse.Right.Down')

            -- Display the item tooltip on hover
            borderFrame:EventAttach(Event.UI.Input.Mouse.Cursor.Move, function(self, h)
                -- There is a bug with StatWeights. Imhothar's bag addon has the same bug.
                local type, shown = Inspect.Tooltip()
                if type ~= 'item' then
                    Command.Tooltip(idetail.id)
                elseif shown ~= idetail.id then
                    Command.Tooltip(idetail.id)
                end
            end, 'LF Item Start Mouseover')
            borderFrame:EventAttach(Event.UI.Input.Mouse.Cursor.Out, function(self, h)
                Command.Tooltip(nil)
            end, 'LF Item End Mouseover')

            LF.UI.InventoryConfig.Tooltips:InjectEvents(borderFrame,
                function(t)
                    t:SetFontSize(16)
                    t:SetFontColor(colors.rf, colors.gf, colors.bf, 1)
                    return idetail.name .. '\n(Bag Slot #' .. bagSlotNum .. ')'
                end
            )
        else
            borderFrame = LF.UI.InventoryConfig.ItemsDisplayed['Border:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type]
        end
        if (bagSlotNum == LF.UI.InventoryConfig.DisplayBagNum) then
            -- If bag is selected, make the border cyan
            borderFrame:SetBackgroundColor(0, 1, 1)
        else
            -- Otherwise, use grey
            borderFrame:SetBackgroundColor(0.5, 0.5, 0.5)
        end

        borderFrame:SetPoint('TOPLEFT', LF.UI.InventoryConfig.InventoryFrame, 'TOPLEFT', posX, posY)
        borderFrame:SetWidth(72)
        borderFrame:SetHeight(72)
        borderFrame:SetLayer(5)
        borderFrame:SetVisible(true)

        LF.UI.InventoryConfig.ItemsDisplayed['Border:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] = borderFrame

        if LF.Settings.DisplayRarity then
            -- Make the rarity indicator
            local rarityBorderFrame = nil
            if LF.UI.InventoryConfig.ItemsDisplayed['RarityBorder:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] == nil then
                rarityBorderFrame = UI.CreateFrame('Frame', 'RarityBorder:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type, LF.UI.InventoryConfig.InventoryFrame)
            else
                rarityBorderFrame = LF.UI.InventoryConfig.ItemsDisplayed['RarityBorder:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type]
            end
            rarityBorderFrame:SetBackgroundColor(colors.rf, colors.gf, colors.bf)
            rarityBorderFrame:SetPoint('TOPLEFT', LF.UI.InventoryConfig.InventoryFrame, 'TOPLEFT', posX + 4, posY + 4)
            rarityBorderFrame:SetWidth(5)
            rarityBorderFrame:SetHeight(6)
            rarityBorderFrame:SetLayer(15)
            rarityBorderFrame:SetVisible(true)
            LF.UI.InventoryConfig.ItemsDisplayed['RarityBorder:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] = rarityBorderFrame
        end

        -- Make the in game icon
        local bagIcon = nil
        if LF.UI.InventoryConfig.ItemsDisplayed['Icon:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] == nil then
            bagIcon = UI.CreateFrame('Texture', 'Icon:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type, LF.UI.InventoryConfig.InventoryFrame)
        else
            bagIcon = LF.UI.InventoryConfig.ItemsDisplayed['Icon:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type]
        end
        bagIcon:SetWidth(64)
        bagIcon:SetHeight(64)
        bagIcon:SetPoint('TOPLEFT', LF.UI.InventoryConfig.InventoryFrame, 'TOPLEFT', posX+4, posY+4)
        bagIcon:SetLayer(10)
        bagIcon:SetTexture('Rift', idetail.icon)
        bagIcon:SetVisible(true)
        LF.UI.InventoryConfig.ItemsDisplayed['Icon:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] = bagIcon

        -- Add the number of items in the bottom right of the bag
        local numItems = nil
        if LF.UI.InventoryConfig.ItemsDisplayed['NumItems:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] == nil then
            numItems = UI.CreateFrame('Text', 'NumItems:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type, LF.UI.InventoryConfig.InventoryFrame)
        else
            numItems = LF.UI.InventoryConfig.ItemsDisplayed['NumItems:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type]
        end

        local numItemsText = tostring(numSelectedInBag)
        if LF.UI.InventoryConfig.ShowSelectedCheckbox:GetChecked() == false then
            numItemsText = tostring(numItemsInBag) .. ' (' .. tostring(numSelectedInBag) .. ')'
        end
        numItems:SetPoint('TOPLEFT', LF.UI.InventoryConfig.InventoryFrame, 'TOPLEFT', posX + 5, posY + 44)
        numItems:SetFontSize(16)
        numItems:SetFontColor(1, 1, 1)
        numItems:SetBackgroundColor(0, 0, 0)
        numItems:SetText(numItemsText)
        numItems:SetLayer(15)
        numItems:SetVisible(true)
        LF.UI.InventoryConfig.ItemsDisplayed['NumItems:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] = numItems
    end
end


-- Displays every item in a specific bag
LF.UI.InventoryConfig.DisplayItemsInBag = function(allowDeletionIfAutoDeleting)
    if LF.UI.InventoryConfig.Window ~= nil and LF.UI.InventoryConfig.Window:GetVisible() == true then
        if LF.UI.InventoryConfig.InventoryFrame == nil then
            LF.UI.InventoryConfig.InventoryFrame = UI.CreateFrame('Frame', 'LF.UI.InventoryConfig.InventoryFrame', LF.UI.InventoryConfig.Window)
        end
        LF.UI.InventoryConfig.InventoryFrame:SetVisible(true)
        LF.UI.InventoryConfig.InventoryFrame:SetPoint('TOPLEFT', LF.UI.InventoryConfig.Window, 'TOPLEFT', 0, 0)
    end

    -- Loop through the possible bags
    for bagNum = 1, 8 do
        -- Check if the bag exists
        local bag = Inspect.Item.Detail(Utility.Item.Slot.Inventory('bag', bagNum))
        if bag ~= nil then
            local numItemsInBag = 0
            local numSelectedInBag = 0

            -- Item display positioning logic
            local tempNumColumns = 0
            local numRows = 0

            -- Loop through the items in the bag
            for slotNum = 1, bag.slots do
                -- Determine if an item to display exists at the coordinates
                local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(bagNum, slotNum))
                if idetail ~= nil then
                    if
                        LF.Settings.AutoSelectGreyItems
                        and idetail.rarity ~= nil and idetail.rarity == 'sellable'
                        and LF.Settings.SelectedItems[idetail.type] == nil
                        and LF.Settings.LockedItems[idetail.type] == nil
                    then
                        -- Auto Select Grey Items is enabled
                        -- The item is a grey item that is not selected or locked
                        -- Add it to the Selected Items list
                        LF.Settings.SelectedItems[idetail.type] = {
                            name = idetail.name,
                            icon = idetail.icon,
                            rarity = idetail.rarity
                        }
                        LF.Settings.PushUpdatesToSavedVariables()
                    end
                    if LF.Settings.SelectedItems[idetail.type] == true then
                        -- A migrated item was found that does not yet have its data. Fill it out!!!
                        LF.Settings.SelectedItems[idetail.type] = {
                            name = idetail.name,
                            icon = idetail.icon,
                            rarity = idetail.rarity
                        }
                        LF.Settings.PushUpdatesToSavedVariables()
                    end
                    local itemDeleted = false -- Determines whether to display the item based on deletion status (simulated deletions count!)
                    if allowDeletionIfAutoDeleting then
                        itemDeleted = LF.Utility.DeleteItem(idetail) -- *Attempt* to auto delete the item
                    end
                    if itemDeleted == false and LF.UI.InventoryConfig.Window ~= nil and LF.UI.InventoryConfig.Window:GetVisible() == true then
                        if LF.Settings.SelectedItems[idetail.type] ~= nil and LF.Settings.LockedItems[idetail.type] == nil then
                            numSelectedInBag = numSelectedInBag + 1
                        end
                        if LF.UI.InventoryConfig.ShowSelectedCheckbox:GetChecked() == false -- If we show everything (not just the selected items)
                            or (LF.Settings.SelectedItems[idetail.type] ~= nil
                            and LF.Settings.LockedItems[idetail.type] == nil) -- Or we show only a selected non-locked item
                        then
                            -- Display the item if it's in the current bag being displayed
                            if LF.UI.InventoryConfig.DisplayBagNum == bagNum then
                                LF.UI.InventoryConfig.DisplayItem(bagNum, slotNum, 60 + (80 * tempNumColumns), 100 + (80 * numRows))
                                tempNumColumns = tempNumColumns + 1
                                if tempNumColumns == 8 then
                                    numRows = numRows + 1
                                    tempNumColumns = 0
                                end
                            end
                            -- Increment number of items in the current bag for this iteration of the loop
                            numItemsInBag = numItemsInBag + 1
                        end
                    end
                end
            end

            -- Display the bag (this becomes a button to choose which bag's items to display!)
            if LF.UI.InventoryConfig.Window ~= nil and LF.UI.InventoryConfig.Window:GetVisible() == true then
                LF.UI.InventoryConfig.DisplayBag(bagNum, 60 + (80 * (bagNum-1)), 560, numItemsInBag, numSelectedInBag)
            end
        end
    end
end


-- Auto Delete configuration window
LF.UI.InventoryConfig.DisplayConfigWindow = function()
    if LF.UI.InventoryConfig.Window == nil or LF.UI.InventoryConfig.Window:GetVisible() == false then
        if LF.UI.SelectedItemsConfig.Window ~= nil and LF.UI.SelectedItemsConfig.Window:GetVisible() == true then
            LF.UI.SelectedItemsConfig.Window:SetVisible(false) -- the Loot Filter window
            LF.UI.SelectedItemsConfig.Frame:SetVisible(false) -- the frame for the current page of Selected Items
            LF.UI.SelectedItemsConfig.PageLeft:SetVisible(false) -- the button to move to the left in the pagination
            LF.UI.SelectedItemsConfig.PageText:SetVisible(false) -- the page indicator
            LF.UI.SelectedItemsConfig.PageRight:SetVisible(false) -- the button to move to the right in the pagination
            LF.UI.SelectedItemsConfig.Submit:SetVisible(false) -- the button to submit changes to the Selected Items window

            LF.UI.SelectedItemsConfig.DisplayPageNum = 1 -- the page to display
            for _,v in pairs(LF.UI.SelectedItemsConfig.ItemsDisplayed) do
                v:SetVisible(false)
            end
        end
        -- Create something behind the scenes for stuff to sit on
        LF.UI.General.Context:SetVisible(true)

        -- Create a window
        if LF.UI.InventoryConfig.Window == nil then -- if none exists, create it and make the event
            LF.UI.InventoryConfig.Window = UI.CreateFrame('SimpleWindow', 'LF.UI.InventoryConfig.Window', LF.UI.General.Context)
            LF.UI.InventoryConfig.Window:SetCloseButtonVisible(true)
            -- Reset the displayed state of application when window closes
            LF.UI.InventoryConfig.Window.closeButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
                LF.UI.InventoryConfig.Window:SetVisible(false) -- the Loot Filter window
                LF.UI.InventoryConfig.InventoryFrame:SetVisible(false) -- the Inventory page
                LF.UI.InventoryConfig.ShowSelectedCheckbox:SetVisible(false) -- the checkbox to show only the selected items
                LF.UI.InventoryConfig.DeleteSelectedCheckbox:SetVisible(false) -- the checkbox to trigger auto deletion of the selected items
                LF.UI.InventoryConfig.ViewSelectedButton:SetVisible(false) -- the button to show the selected window
                LF.UI.InventoryConfig.ReloadDisclaimerText:SetVisible(false) -- text to inform the user to use /reloadui to save settings
                LF.UI.InventoryConfig.Tooltips:SetVisible(false) -- tooltips
                if LF.UI.AutoDeleteConfirmation.Window ~= nil then
                    LF.UI.AutoDeleteConfirmation.Window:SetVisible(false) -- the window to confirm enabling Auto Delete
                    LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText:SetVisible(false) -- the number of items to delete
                    LF.UI.AutoDeleteConfirmation.StartButton:SetVisible(false) -- the Start auto deleting button
                    LF.UI.AutoDeleteConfirmation.CancelButton:SetVisible(false) -- the Cancel confirm auto deleting button
                end
                LF.UI.InventoryConfig.DisplayBagNum = 1 -- the bag to display
                for _,v in pairs(LF.UI.InventoryConfig.ItemsDisplayed) do
                    v:SetVisible(false)
                end
            end, 'CloseLeftClick')
        end
        LF.UI.InventoryConfig.Window:SetVisible(true)
        LF.UI.InventoryConfig.Window:SetTitle('Loot Filter')
        LF.UI.InventoryConfig.Window:SetWidth(760)
        LF.UI.InventoryConfig.Window:SetHeight(800)
        LF.UI.InventoryConfig.Window:SetPoint(
            'TOPLEFT', UIParent, 'TOPLEFT',
            (UIParent:GetWidth()/2) - (LF.UI.InventoryConfig.Window:GetWidth()/2),
            (UIParent:GetHeight()/2) - (LF.UI.InventoryConfig.Window:GetHeight()/2)
        )
        LF.UI.InventoryConfig.Window:SetLayer(10)


        -- Button to open the Selected Items window
        if LF.UI.InventoryConfig.ViewSelectedButton == nil then
            LF.UI.InventoryConfig.ViewSelectedButton = UI.CreateFrame('RiftButton', 'LF.UI.InventoryConfig.ViewSelectedButton', LF.UI.InventoryConfig.Window)
            LF.UI.InventoryConfig.ViewSelectedButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
                LF.UI.SelectedItemsConfig.DisplayViewSelectedWindow()
                LF.UI.InventoryConfig.Window:SetVisible(false) -- the Loot Filter window
                LF.UI.InventoryConfig.InventoryFrame:SetVisible(false) -- the Inventory page
                LF.UI.InventoryConfig.ShowSelectedCheckbox:SetVisible(false) -- the checkbox to show only the selected items
                LF.UI.InventoryConfig.DeleteSelectedCheckbox:SetVisible(false) -- the checkbox to trigger auto deletion of the selected items
                LF.UI.InventoryConfig.ViewSelectedButton:SetVisible(false) -- the button to show the selected window
                LF.UI.InventoryConfig.ReloadDisclaimerText:SetVisible(false) -- text to inform the user to use /reloadui to save settings
                LF.UI.InventoryConfig.Tooltips:SetVisible(false) -- tooltips
                if LF.UI.AutoDeleteConfirmation.Window ~= nil then
                    LF.UI.AutoDeleteConfirmation.Window:SetVisible(false) -- the window to confirm enabling Auto Delete
                    LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText:SetVisible(false) -- the number of items to delete
                    LF.UI.AutoDeleteConfirmation.StartButton:SetVisible(false) -- the Start auto deleting button
                    LF.UI.AutoDeleteConfirmation.CancelButton:SetVisible(false) -- the Cancel confirm auto deleting button
                end
                LF.UI.InventoryConfig.DisplayBagNum = 1 -- the bag to display
                for _,v in pairs(LF.UI.InventoryConfig.ItemsDisplayed) do
                    v:SetVisible(false)
                end
            end, 'View Selected Left Click')
        end
        LF.UI.InventoryConfig.ViewSelectedButton:SetVisible(true)
        LF.UI.InventoryConfig.ViewSelectedButton:SetText('View Selected')
        LF.UI.InventoryConfig.ViewSelectedButton:SetPoint('BOTTOMRIGHT', LF.UI.InventoryConfig.Window, 'BOTTOMRIGHT', -60, -120)

        -- Display Only Selected Checkbox
        if LF.UI.InventoryConfig.ShowSelectedCheckbox == nil then -- if none exists, create it and make the event
            LF.UI.InventoryConfig.ShowSelectedCheckbox = UI.CreateFrame('SimpleCheckbox', 'LF.UI.InventoryConfig.ShowSelectedCheckbox', LF.UI.InventoryConfig.Window)
            LF.UI.InventoryConfig.ShowSelectedCheckbox.check:EventAttach(Event.UI.Checkbox.Change, function(self, h)
                if LF.UI.InventoryConfig.ShowSelectedCheckbox:GetEnabled() == true then
                    LF.UI.InventoryConfig.RedisplayInventory()
                else
                    -- Prevent checking the show selected checkbox while auto deleting
                    if LF.Settings.AutoDeleting and LF.UI.InventoryConfig.ShowSelectedCheckbox:GetChecked() == true then
                        LF.UI.InventoryConfig.ShowSelectedCheckbox:SetChecked(false)
                    end
                end
            end, 'Display Selected Items Checkbox Changed')
        end
        LF.UI.InventoryConfig.ShowSelectedCheckbox:SetVisible(true)
        LF.UI.InventoryConfig.ShowSelectedCheckbox:SetText('Display Only Selected Items')
        LF.UI.InventoryConfig.ShowSelectedCheckbox:SetFontSize(28)
        LF.UI.InventoryConfig.ShowSelectedCheckbox:SetChecked(false)
        LF.UI.InventoryConfig.ShowSelectedCheckbox:SetEnabled(not LF.Settings.AutoDeleting)
        LF.UI.InventoryConfig.ShowSelectedCheckbox:SetPoint('BOTTOMLEFT', LF.UI.InventoryConfig.Window, 'BOTTOMLEFT', 60, -120)

        -- Auto Delete Checkbox
        if LF.UI.InventoryConfig.DeleteSelectedCheckbox == nil then -- if none exists, create it and make the event
            LF.UI.InventoryConfig.DeleteSelectedCheckbox = UI.CreateFrame('SimpleCheckbox', 'LF.UI.InventoryConfig.DeleteSelectedCheckbox', LF.UI.InventoryConfig.Window)
            LF.UI.InventoryConfig.DeleteSelectedCheckbox.check:EventAttach(Event.UI.Checkbox.Change, function(self, h)
                -- If checkbox is selected when we aren't auto deleting
                if LF.UI.InventoryConfig.DeleteSelectedCheckbox:GetChecked() == true and not LF.Settings.AutoDeleting then
                    -- Automatically deselect the checkbox until we're *certain* we want to be
                    LF.UI.InventoryConfig.DeleteSelectedCheckbox:SetChecked(false)

                    -- Ensure the confirmation window has been created
                    if LF.UI.AutoDeleteConfirmation.Window == nil then
                        LF.UI.AutoDeleteConfirmation.CreateConfirmAutoDeleteWindow()
                    end

                    if LF.UI.AutoDeleteConfirmation.Window ~= nil then
                        -- Toggle the display of the confirmation window
                        if LF.UI.AutoDeleteConfirmation.Window:GetVisible() == false then
                            -- Show the confirmation window
                            LF.UI.AutoDeleteConfirmation.Window:SetVisible(true)
                            LF.UI.AutoDeleteConfirmation.StartButton:SetVisible(true)
                            LF.UI.AutoDeleteConfirmation.CancelButton:SetVisible(true)
                            LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText:SetVisible(true)

                            LF.UI.AutoDeleteConfirmation.UpdateDeletionConfirmationText()

                            -- Put the confirmation window to the middle of the screen
                            LF.UI.AutoDeleteConfirmation.Window:SetPoint(
                                'TOPLEFT', UIParent, 'TOPLEFT',
                                (UIParent:GetWidth()/2) - (LF.UI.AutoDeleteConfirmation.Window:GetWidth()/2),
                                (UIParent:GetHeight()/2) - (LF.UI.AutoDeleteConfirmation.Window:GetHeight()/2)
                            )
                        else
                            -- Remove all confirmation UI
                            LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText:SetVisible(false)
                            LF.UI.AutoDeleteConfirmation.StartButton:SetVisible(false)
                            LF.UI.AutoDeleteConfirmation.CancelButton:SetVisible(false)
                            LF.UI.AutoDeleteConfirmation.Window:SetVisible(false)
                        end
                    end

                -- If auto delete checkbox is no longer selected
                elseif LF.UI.InventoryConfig.DeleteSelectedCheckbox:GetChecked() == false then
                    -- Ensure we are not auto deleting since we are not checked
                    LF.Settings.AutoDeleting = false
                    LF.Settings.PushUpdatesToSavedVariables()
                    -- Re-enable the show only selected checkbox
                    LF.UI.InventoryConfig.ShowSelectedCheckbox:SetEnabled(true)
                    -- Trigger a redisplay (useful only when the Prevent Deletion setting is active)
                    LF.UI.InventoryConfig.RedisplayInventory()
                end


            end, 'Delete Selected Items Checkbox Changed')
        end
        LF.UI.InventoryConfig.DeleteSelectedCheckbox:SetVisible(true)
        LF.UI.InventoryConfig.DeleteSelectedCheckbox:SetText('Automatically Delete Selected Items')
        LF.UI.InventoryConfig.DeleteSelectedCheckbox:SetFontSize(28)
        LF.UI.InventoryConfig.DeleteSelectedCheckbox:SetChecked(LF.Settings.AutoDeleting)
        LF.UI.InventoryConfig.DeleteSelectedCheckbox:SetPoint('BOTTOMLEFT', LF.UI.InventoryConfig.Window, 'BOTTOMLEFT', 60, -70)

        -- Text disclaimer to inform the user how to save their changes
        if LF.UI.InventoryConfig.ReloadDisclaimerText == nil then
            LF.UI.InventoryConfig.ReloadDisclaimerText = UI.CreateFrame('Text', 'LF.UI.InventoryConfig.ReloadDisclaimerText', LF.UI.InventoryConfig.Window)
        end
        LF.UI.InventoryConfig.ReloadDisclaimerText:SetPoint('BOTTOMLEFT', LF.UI.InventoryConfig.Window, 'BOTTOMLEFT', 60, -25)
        LF.UI.InventoryConfig.ReloadDisclaimerText:SetVisible(true)
        LF.UI.InventoryConfig.ReloadDisclaimerText:SetText('Use /reloadui to save your settings in case Rift crashes!')
        LF.UI.InventoryConfig.ReloadDisclaimerText:SetFontSize(24)

        -- Used to show the item names on hover
        if LF.UI.InventoryConfig.Tooltips == nil then
            LF.UI.InventoryConfig.Tooltips = UI.CreateFrame('SimpleTooltip', 'LF.UI.InventoryConfig.Tooltips', LF.UI.General.Context)
        end
    else
        -- Reset the position when redisplaying
        LF.UI.InventoryConfig.Window:SetPoint(
            'TOPLEFT', UIParent, 'TOPLEFT',
            (UIParent:GetWidth()/2) - (LF.UI.InventoryConfig.Window:GetWidth()/2),
            (UIParent:GetHeight()/2) - (LF.UI.InventoryConfig.Window:GetHeight()/2)
        )
    end
    LF.UI.InventoryConfig.RedisplayInventory(true)
end

