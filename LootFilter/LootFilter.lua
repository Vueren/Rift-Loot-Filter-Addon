local addon, LF = ...

local lfUIContext = nil -- the backend stuff that windows sit on
local lfUIWindow = nil -- the Loot Filter window
local lfUIInventoryFrame = nil -- the Inventory page
local lfUIShowSelectedCheckbox = nil -- the checkbox to show only the selected items
local lfUIDeleteSelectedCheckbox = nil -- the checkbox to trigger auto deletion of the selected items
local lfUIReloadDisclaimerText = nil -- text to inform the user to use /reloadui to save settings
local lfUITooltips = nil -- tooltips
local lfUIConfirmAutoDeleteWindow = nil -- the window to confirm enabling Auto Delete
local lfUIConfirmAutoDeleteNumItemsText = nil -- the number of items to delete
local lfUIConfirmAutoDeleteStartButton = nil -- the Start auto deleting button
local lfUIConfirmAutoDeleteCancelButton = nil -- the Cancel confirm auto deleting button
local displayConfigWindow = nil -- function to display the config window

local displayBagNum = 1 -- the bag to display
local itemsDisplayed = {} -- the frames of every item that has been displayed so far

local lfUIViewSelectedButton = nil -- the button to open the view selected window

local lfUIViewSelectedWindow = nil -- the window to view all Selected Items
local lfUIViewSelectedFrame = nil -- the frame for the current page of Selected Items
local lfUIViewSelectedPageLeft = nil -- the button to move to the left in the pagination
local lfUIViewSelectedPageText = nil -- the page indicator
local lfUIViewSelectedPageRight = nil -- the button to move to the right in the pagination
local lfUIViewSelectedSubmit = nil -- the button to submit changes to the Selected Items window

local viewSelectedDisplayPageNum = 1 -- the page to display
local viewSelectedItemsToDeselect = {} -- the items to deselect
local viewSelectedItemsToLock = {} -- the items to lock
local viewSelectedItemsDisplayed = {} -- the frames of every item that has been displayed so far
local displaySelectedItems = nil -- function to display the selected items

local displayItemsInBag = nil -- function to display the items in the displayBagNum bag slot

local lastUpdateServerTime = 0 -- Used to ensure the auto delete function only runs after a certain amount of time has passed since the last inventory update
local slotUpdates = nil -- Used to store the inventory updates
local totalSelectedItemsInInventory = 0 -- Used to display the number of items that will be deleted on the first pass of the Loot Filter's auto delete

local function getColors(idetail)
    -- Handle border color and tooltip color
    local rf = 1
    local gf = 1
    local bf = 1
    if idetail.rarity == nil then -- White
        rf = 1
        gf = 1
        bf = 1
    elseif idetail.rarity == 'quest' then -- Yellow
        rf = 1
        gf = 1
        bf = 0
    elseif idetail.rarity == 'sellable' then -- Grey
        rf = 0.4
        gf = 0.4
        bf = 0.4
    elseif idetail.rarity == 'uncommon' then -- Green
        rf = 0
        gf = 0.8
        bf = 0
    elseif idetail.rarity == 'rare' then -- Blue
        rf = 0.3
        gf = 0.3
        bf = 1
    elseif idetail.rarity == 'epic' then -- Purple
        rf = 0.6
        gf = 0.2
        bf = 0.7
    elseif idetail.rarity == 'relic' then -- Orange
        rf = 1
        gf = 0.5
        bf = 0
    elseif idetail.rarity == 'transcendent' then -- Red
        rf = 1
        gf = 0.2
        bf = 0.2
    elseif idetail.rarity == 'eternal' then -- Cyan
        rf = 0.6
        gf = 0.8
        bf = 1
    end
    return {
        rf = rf,
        gf = gf,
        bf = bf,
    }
end

local function updateDeletionConfirmationText()
    if lfUIConfirmAutoDeleteNumItemsText ~= nil then
        -- Update the text with the new totalSelectedItemsInInventory value
        lfUIConfirmAutoDeleteNumItemsText:SetPoint('TOPLEFT', lfUIConfirmAutoDeleteWindow, 'TOPLEFT', 62 - math.floor(5 * string.len(tostring(totalSelectedItemsInInventory))), 42)
        lfUIConfirmAutoDeleteNumItemsText:SetText('# of items that will be deleted right now: ' .. tostring(totalSelectedItemsInInventory))
    end
end

local function redisplaySelectedItems(removeCurrentChanges)
    for _,v in pairs(viewSelectedItemsDisplayed) do
        v:SetVisible(false)
    end
    local numSelectedItems = 0
    for _,_ in pairs(LootFilter_Settings.SelectedItems) do
        numSelectedItems = numSelectedItems + 1
    end
    -- move to last page if page is lower than the lower boundary
    if viewSelectedDisplayPageNum < 1 then
        viewSelectedDisplayPageNum = math.ceil(numSelectedItems / 40)
    end
    -- move to first page if page is higher than the highest boundary
    if viewSelectedDisplayPageNum > math.ceil(numSelectedItems / 40) then
        -- Examples:
        -- 39 items is 1 page.  1 + 1 is 2, > 1, rotate it back around to 1.
        -- 40 items is 1 page.  1 + 1 is 2, > 1, rotate it back around to 1.
        -- 41 items is 2 pages. 2 + 1 is 3, > 2, rotate it back around to 1.
        viewSelectedDisplayPageNum = 1
    end
    -- display a blank page when there are no selected items
    if numSelectedItems == 0 then
        viewSelectedDisplayPageNum = 0
    end
    -- update the page indicator text
    
    local pageIndicatorText = tostring(viewSelectedDisplayPageNum) .. '/' .. tostring(math.ceil(numSelectedItems / 40))
    if lfUIViewSelectedPageText ~= nil then
        lfUIViewSelectedPageText:SetPoint('BOTTOMLEFT', lfUIViewSelectedWindow, 'BOTTOMLEFT', lfUIViewSelectedWindow:GetWidth()/2 - 18 * string.len(pageIndicatorText), -25)
        lfUIViewSelectedPageText:SetText(pageIndicatorText)
    end
    if removeCurrentChanges == true then
        viewSelectedItemsToDeselect = {} -- the items to deselect
        viewSelectedItemsToLock = {} -- the items to lock
    end
    -- display the page
    displaySelectedItems(numSelectedItems)
end

local function redisplayInventory(allowDeletionIfAutoDeleting)
    for _,v in pairs(itemsDisplayed) do
        v:SetVisible(false)
    end
    totalSelectedItemsInInventory = 0
    displayItemsInBag(allowDeletionIfAutoDeleting)
    updateDeletionConfirmationText()
    redisplaySelectedItems(true)
end

-- Displays an item from the inventory at the coordinates on the inventory frame
local function displayItem(bagSlot, itemSlot, posX, posY)
    local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(bagSlot, itemSlot))

    if idetail ~= nil then
        local colors = getColors(idetail)

        -- Make the border
        local borderFrame = nil
        if itemsDisplayed['Border:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] == nil then
            borderFrame = UI.CreateFrame('Frame', 'Border:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type, lfUIInventoryFrame)
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

            lfUITooltips:InjectEvents(borderFrame,
                function(t)
                    t:SetFontSize(16)
                    t:SetFontColor(colors.rf, colors.gf, colors.bf, 1)
                    if LootFilter_Settings.LockedItems[idetail.type] ~= nil then
                        return '[LOCKED]\n' .. idetail.name .. (idetail.stack ~= nil and idetail.stack > 1 and ' x' .. idetail.stack or '')
                    else
                        return idetail.name .. (idetail.stack ~= nil and idetail.stack > 1 and ' x' .. idetail.stack or '')
                    end
                end
            )
            -- Toggle item selection on click if we are not auto deleting
            borderFrame:EventAttach(Event.UI.Input.Mouse.Left.Down, function(self, h) -- Left click to select the item
                if not LootFilter_Settings.AutoDeleting and LootFilter_Settings.LockedItems[idetail.type] == nil then
                    -- Toggle selection
                    if LootFilter_Settings.SelectedItems[idetail.type] == nil then
                        LootFilter_Settings.SelectedItems[idetail.type] = {
                            name = idetail.name,
                            icon = idetail.icon,
                            rarity = idetail.rarity
                        }
                    else
                        LootFilter_Settings.SelectedItems[idetail.type] = nil
                    end
                    if lfUIShowSelectedCheckbox:GetChecked() == true then
                        Command.Tooltip(nil)
                        lfUITooltips.SetVisible(false)
                    end
                    redisplayInventory()
                end
            end, 'Event.UI.Input.Mouse.Left.Down')
            borderFrame:EventAttach(Event.UI.Input.Mouse.Right.Down, function(self, h) -- Right click to make item locked
                if not LootFilter_Settings.AutoDeleting then
                    -- Toggle selection
                    if LootFilter_Settings.LockedItems[idetail.type] == nil then
                        LootFilter_Settings.LockedItems[idetail.type] = {
                            name = idetail.name,
                            icon = idetail.icon,
                            rarity = idetail.rarity
                        }
                        LootFilter_Settings.SelectedItems[idetail.type] = nil
                        lfUITooltips:SetText('[LOCKED]\n' .. idetail.name .. (idetail.stack ~= nil and idetail.stack > 1 and ' x' .. idetail.stack or ''))
                    else
                        LootFilter_Settings.LockedItems[idetail.type] = nil
                        lfUITooltips:SetText(idetail.name .. (idetail.stack ~= nil and idetail.stack > 1 and ' x' .. idetail.stack or ''))
                    end
                    if lfUIShowSelectedCheckbox:GetChecked() == true then
                        Command.Tooltip(nil)
                        lfUITooltips.SetVisible(false)
                    end
                    redisplayInventory()
                end
            end, 'Event.UI.Input.Mouse.Right.Down')
        else
            borderFrame = itemsDisplayed['Border:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type]
        end
        -- locked/selected item border logic
        if LootFilter_Settings.LockedItems[idetail.type] ~= nil then
            -- if item is locked, make the border purple
            borderFrame:SetBackgroundColor(0.25, 0, 0.25)
            borderFrame:SetAlpha(1)
        elseif LootFilter_Settings.SelectedItems[idetail.type] ~= nil then
            -- if item is selected, make the border yellow
            borderFrame:SetBackgroundColor(1, 1, 0)
            borderFrame:SetAlpha(1)
        else
            -- otherwise, have no border
            borderFrame:SetAlpha(0)
        end
        borderFrame:SetPoint('TOPLEFT', lfUIInventoryFrame, 'TOPLEFT', posX, posY)
        borderFrame:SetWidth(72)
        borderFrame:SetHeight(72)
        borderFrame:SetLayer(5)
        borderFrame:SetVisible(true)

        itemsDisplayed['Border:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] = borderFrame

        if LootFilter_Settings.DisplayRarity then
            -- Make the rarity indicator
            local rarityBorderFrame =  nil
            if itemsDisplayed['RarityBorder:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] == nil then
                rarityBorderFrame = UI.CreateFrame('Frame', 'RarityBorder:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type, lfUIInventoryFrame)
            else
                rarityBorderFrame = itemsDisplayed['RarityBorder:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type]
            end
            rarityBorderFrame:SetBackgroundColor(colors.rf, colors.gf, colors.bf)
            rarityBorderFrame:SetPoint('TOPLEFT', lfUIInventoryFrame, 'TOPLEFT', posX + 4, posY + 4)
            rarityBorderFrame:SetWidth(5)
            rarityBorderFrame:SetHeight(6)
            rarityBorderFrame:SetLayer(15)
            rarityBorderFrame:SetVisible(true)
            if LootFilter_Settings.AutoDeleting or LootFilter_Settings.LockedItems[idetail.type] ~= nil then
                rarityBorderFrame:SetAlpha(0.5) -- Grey out the items if auto deleting or item is locked
            else
                rarityBorderFrame:SetAlpha(1)
            end
            itemsDisplayed['RarityBorder:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] = rarityBorderFrame
        end

        -- Make the in game icon
        local itemIcon =  nil
        if itemsDisplayed['Icon:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] == nil then
            itemIcon = UI.CreateFrame('Texture', 'Icon:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type, lfUIInventoryFrame)
        else
            itemIcon = itemsDisplayed['Icon:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type]
        end
        itemIcon:SetWidth(64)
        itemIcon:SetHeight(64)
        itemIcon:SetPoint('TOPLEFT', lfUIInventoryFrame, 'TOPLEFT', posX+4, posY+4)
        itemIcon:SetLayer(10)
        itemIcon:SetTexture('Rift', idetail.icon)
        itemIcon:SetVisible(true)
        if LootFilter_Settings.AutoDeleting or LootFilter_Settings.LockedItems[idetail.type] ~= nil then
            itemIcon:SetAlpha(0.5) -- Grey out the items if auto deleting or item is locked
        else
            itemIcon:SetAlpha(1)
        end
        itemsDisplayed['Icon:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] = itemIcon

        -- if the slot has multiple items in it, display text
        if idetail.stack ~= nil and idetail.stack > 1 then
            -- display a text in the lower right detailing the quantity of the item
            local stackCount =  nil
            if itemsDisplayed['Stack:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] == nil then
                stackCount = UI.CreateFrame('Text', 'Stack:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type, lfUIInventoryFrame)
            else
                stackCount = itemsDisplayed['Stack:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type]
            end
            stackCount:SetPoint('TOPLEFT', lfUIInventoryFrame, 'TOPLEFT', posX + 63 - math.floor(11 * string.len(tostring(idetail.stack))), posY+42)
            stackCount:SetFontSize(18)
            stackCount:SetFontColor(1, 1, 1)
            stackCount:SetBackgroundColor(0, 0, 0)
            stackCount:SetText(tostring(idetail.stack))
            stackCount:SetLayer(15)
            stackCount:SetVisible(true)
            if LootFilter_Settings.AutoDeleting or LootFilter_Settings.LockedItems[idetail.type] ~= nil then
                stackCount:SetAlpha(0.5) -- Grey out the items if auto deleting or item is locked
            else
                stackCount:SetAlpha(1)
            end
            itemsDisplayed['Stack:' .. tostring(bagSlot) .. ':' .. tostring(itemSlot) .. ':' .. idetail.type] = stackCount
        end
    end
end

-- Select all items in a bag on right click. If all items are already selected, de-select all items instead.
local function selectAllItemsInBag(bagSlotNum)
    -- Check if the bag exists
    local bag = Inspect.Item.Detail(Utility.Item.Slot.Inventory('bag', bagSlotNum))
    local itemsToDeselect = {}
    local unselectedItemFound = false
    if bag ~= nil then
        -- Loop through the items in the bag
        for slotNum = 1, bag.slots do
            -- Determine if an item to display exists at the coordinates
            local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(bagSlotNum, slotNum))
            if idetail ~= nil then
                if LootFilter_Settings.SelectedItems[idetail.type] == nil and LootFilter_Settings.LockedItems[idetail.type] == nil then
                    LootFilter_Settings.SelectedItems[idetail.type] = {
                        name = idetail.name,
                        icon = idetail.icon,
                        rarity = idetail.rarity
                    }
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
    if unselectedItemFound == false then
        for idetailType,_ in pairs(itemsToDeselect) do
            LootFilter_Settings.SelectedItems[idetailType] = nil
        end
    end
end

-- Displays a bag at the coordinates on the inventory frame
local function displayBag(bagSlotNum, posX, posY, numItemsInBag, numSelectedInBag)
    local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory('bag', bagSlotNum))

    if idetail ~= nil then
        local colors = getColors(idetail)

        -- Make the general border
        local borderFrame = nil
        if itemsDisplayed['Border:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] == nil then
            borderFrame = UI.CreateFrame('Frame', 'Border:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type, lfUIInventoryFrame)
            -- Attach a click event to change the selected bag, and then Redisplay
            borderFrame:EventAttach(Event.UI.Input.Mouse.Left.Down, function(self, h)
                displayBagNum = bagSlotNum
                redisplayInventory(true)
            end, 'Event.UI.Input.Mouse.Left.Down')
            -- Select all items in a bag on right click. If all items are already selected, de-select all items instead.
            borderFrame:EventAttach(Event.UI.Input.Mouse.Right.Down, function(self, h)
                if not LootFilter_Settings.AutoDeleting then
                    selectAllItemsInBag(bagSlotNum)
                end
                displayBagNum = bagSlotNum
                redisplayInventory(true)
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

            lfUITooltips:InjectEvents(borderFrame,
                function(t)
                    t:SetFontSize(16)
                    t:SetFontColor(colors.rf, colors.gf, colors.bf, 1)
                    return idetail.name .. '\n(Bag Slot #' .. bagSlotNum .. ')'
                end
            )
        else
            borderFrame = itemsDisplayed['Border:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type]
        end
        if (bagSlotNum == displayBagNum) then
            -- if bag is selected, make the border cyan
            borderFrame:SetBackgroundColor(0, 1, 1)
        else
            -- otherwise, use grey
            borderFrame:SetBackgroundColor(0.5, 0.5, 0.5)
        end

        borderFrame:SetPoint('TOPLEFT', lfUIInventoryFrame, 'TOPLEFT', posX, posY)
        borderFrame:SetWidth(72)
        borderFrame:SetHeight(72)
        borderFrame:SetLayer(5)
        borderFrame:SetVisible(true)

        itemsDisplayed['Border:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] = borderFrame

        if LootFilter_Settings.DisplayRarity then
            -- Make the rarity indicator
            local rarityBorderFrame = nil
            if itemsDisplayed['RarityBorder:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] == nil then
                rarityBorderFrame = UI.CreateFrame('Frame', 'RarityBorder:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type, lfUIInventoryFrame)
            else
                rarityBorderFrame = itemsDisplayed['RarityBorder:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type]
            end
            rarityBorderFrame:SetBackgroundColor(colors.rf, colors.gf, colors.bf)
            rarityBorderFrame:SetPoint('TOPLEFT', lfUIInventoryFrame, 'TOPLEFT', posX + 4, posY + 4)
            rarityBorderFrame:SetWidth(5)
            rarityBorderFrame:SetHeight(6)
            rarityBorderFrame:SetLayer(15)
            rarityBorderFrame:SetVisible(true)
            itemsDisplayed['RarityBorder:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] = rarityBorderFrame
        end

        -- Make the in game icon
        local bagIcon = nil
        if itemsDisplayed['Icon:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] == nil then
            bagIcon = UI.CreateFrame('Texture', 'Icon:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type, lfUIInventoryFrame)
        else
            bagIcon = itemsDisplayed['Icon:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type]
        end
        bagIcon:SetWidth(64)
        bagIcon:SetHeight(64)
        bagIcon:SetPoint('TOPLEFT', lfUIInventoryFrame, 'TOPLEFT', posX+4, posY+4)
        bagIcon:SetLayer(10)
        bagIcon:SetTexture('Rift', idetail.icon)
        bagIcon:SetVisible(true)
        itemsDisplayed['Icon:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] = bagIcon

        -- add the number of items in the bottom right of the bag
        local numItems = nil
        if itemsDisplayed['NumItems:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] == nil then
            numItems = UI.CreateFrame('Text', 'NumItems:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type, lfUIInventoryFrame)
        else
            numItems = itemsDisplayed['NumItems:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type]
        end

        local numItemsText = tostring(numSelectedInBag)
        if lfUIShowSelectedCheckbox:GetChecked() == false then
            numItemsText = tostring(numItemsInBag) .. ' (' .. tostring(numSelectedInBag) .. ')'
        end
        numItems:SetPoint('TOPLEFT', lfUIInventoryFrame, 'TOPLEFT', posX + 5, posY + 44)
        numItems:SetFontSize(16)
        numItems:SetFontColor(1, 1, 1)
        numItems:SetBackgroundColor(0, 0, 0)
        numItems:SetText(numItemsText)
        numItems:SetLayer(15)
        numItems:SetVisible(true)
        itemsDisplayed['NumItems:bag' .. tostring(bagSlotNum) .. ':' .. idetail.type] = numItems
    end
end

local function deleteItem(idetail)
    if LootFilter_Settings.AutoDeleting then
        -- If the item is an item to auto delete
        if
            LootFilter_Settings.SelectedItems[idetail.type] ~= nil
            and LootFilter_Settings.LockedItems[idetail.type] == nil
        then
            -- Delete the selected item
            if LootFilter_Settings.PreventDeletion == false then
                if LootFilter_Settings.DisplayChat then
                    Command.Console.Display('general', true, 'Loot Filter Deleting: ' .. idetail.name, false)
                end
                Command.Item.Destroy(idetail.id)
            else
                if LootFilter_Settings.DisplayChat then
                    Command.Console.Display('general', true, 'Loot Filter Simulating Deleting: ' .. idetail.name, false)
                end
            end
            if idetail.stack ~= nil then
                LootFilter_Settings.TotalItemsDeleted = LootFilter_Settings.TotalItemsDeleted + idetail.stack
            else
                LootFilter_Settings.TotalItemsDeleted = LootFilter_Settings.TotalItemsDeleted + 1
            end
            return true
        end
    end
    return false
end

-- Displays every item in a specific bag
displayItemsInBag = function(allowDeletionIfAutoDeleting)
    if lfUIWindow ~= nil and lfUIWindow:GetVisible() == true then
        if lfUIInventoryFrame == nil then
            lfUIInventoryFrame = UI.CreateFrame('Frame', 'lfUIInventoryFrame', lfUIWindow)
        end
        lfUIInventoryFrame:SetVisible(true)
        lfUIInventoryFrame:SetPoint('TOPLEFT', lfUIWindow, 'TOPLEFT', 0, 0)
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
                        LootFilter_Settings.AutoSelectGreyItems
                        and idetail.rarity ~= nil and idetail.rarity == 'sellable'
                        and LootFilter_Settings.SelectedItems[idetail.type] == nil
                        and LootFilter_Settings.LockedItems[idetail.type] == nil
                    then
                        -- Auto Select Grey Items is enabled
                        -- The item is a grey item that is not selected or locked
                        -- Add it to the Selected Items list
                        LootFilter_Settings.SelectedItems[idetail.type] = {
                            name = idetail.name,
                            icon = idetail.icon,
                            rarity = idetail.rarity
                        }
                    end
                    if LootFilter_Settings.SelectedItems[idetail.type] == true then
                        -- A migrated item was found that does not yet have its data. Fill it out!!!
                        LootFilter_Settings.SelectedItems[idetail.type] = {
                            name = idetail.name,
                            icon = idetail.icon,
                            rarity = idetail.rarity
                        }
                    end
                    local itemDeleted = false
                    if allowDeletionIfAutoDeleting then
                        itemDeleted = deleteItem(idetail) -- *Attempt* to auto delete the item
                    end
                    if itemDeleted == false and lfUIWindow ~= nil and lfUIWindow:GetVisible() == true then
                        if LootFilter_Settings.SelectedItems[idetail.type] ~= nil and LootFilter_Settings.LockedItems[idetail.type] == nil then
                            totalSelectedItemsInInventory = totalSelectedItemsInInventory + 1
                            numSelectedInBag = numSelectedInBag + 1
                        end
                        if lfUIShowSelectedCheckbox:GetChecked() == false -- if we show everything (not just the selected items)
                            or (LootFilter_Settings.SelectedItems[idetail.type] ~= nil
                            and LootFilter_Settings.LockedItems[idetail.type] == nil) -- or we show only a selected non-locked item
                        then
                            -- display the item if it's in the current bag being displayed
                            if displayBagNum == bagNum then
                                displayItem(bagNum, slotNum, 60 + (80 * tempNumColumns), 100 + (80 * numRows))
                                tempNumColumns = tempNumColumns + 1
                                if tempNumColumns == 8 then
                                    numRows = numRows + 1
                                    tempNumColumns = 0
                                end
                            end
                            -- increment number of items in the current bag for this iteration of the loop
                            numItemsInBag = numItemsInBag + 1
                        end
                    end
                end
            end

            -- Display the bag (this becomes a button to choose which bag's items to display!)
            if lfUIWindow ~= nil and lfUIWindow:GetVisible() == true then
                displayBag(bagNum, 60 + (80 * (bagNum-1)), 560, numItemsInBag, numSelectedInBag)
            end
        end
    end
end

-- Automatically updates the Loot Filter inventory with changes in the real inventory
-- Also triggers the destruction logic in displayItemsInBag
-- - Requires a full 5 seconds since the last time the inventory was left untouched!
-- - This guarantees that all items are in their slot when the addon makes its pass!
-- - Before then, DO NOT auto delete!
local function slotUpdate()
    local allowDeletionIfAutoDeleting = false
    -- Check every half second if it has been 5 seconds yet
    if Inspect.Time.Server() <= lastUpdateServerTime + 5 then
        StartTimer(0.5, slotUpdate)
    else
        -- 5 seconds has passed
        allowDeletionIfAutoDeleting = true
        lastUpdateServerTime = 0
        redisplayInventory(allowDeletionIfAutoDeleting)
    end

    if slotUpdates ~= nil then
        -- Update the loot filter inventory display anyway
        local shouldUpdateLootFilter = false
        for slotID,_ in pairs(slotUpdates) do
            local itemLocation = Utility.Item.Slot.Parse(slotID)
            if itemLocation == 'inventory' then
                shouldUpdateLootFilter = true
            end
        end
        if shouldUpdateLootFilter then
            redisplayInventory()
        end
        slotUpdates = nil
    end
end

-- After a delay, automatically update the Loot Filter inventory if an item has moved around the bags.
local function slotUpdateHandler(eventHandle, updates)
    slotUpdates = updates
    -- Ensure that only one slotUpdate function is running at any given time
    if lastUpdateServerTime == 0 then
        StartTimer(0.5, slotUpdate)
    end
    lastUpdateServerTime = Inspect.Time.Server()
end

-- Displays an item from the inventory at the coordinates on the inventory frame
local function displaySelectedItem(itemType, idetailRaw, posX, posY)
    local idetail = idetailRaw
    
    -- item was migrated and needs a hug
    if idetailRaw == true then
        idetail = {
            name = 'Unknown Item\n'..itemType,
            icon = 'StartIconTray_I166.dds',
            rarity = nil
        }
    end


    local colors = getColors(idetail)

    -- Make the border
    local borderFrame = nil
    if viewSelectedItemsDisplayed['Border:' .. itemType] == nil then
        borderFrame = UI.CreateFrame('Frame', 'Border:' .. itemType, lfUIViewSelectedFrame)
        lfUITooltips:InjectEvents(borderFrame,
            function(t)
                t:SetFontSize(16)
                t:SetFontColor(colors.rf, colors.gf, colors.bf, 1)
                if viewSelectedItemsToLock[itemType] ~= nil then
                    return '[LOCKED]\n' .. idetail.name
                else
                    return idetail.name
                end
            end
        )
        -- Toggle item selection on click
        borderFrame:EventAttach(Event.UI.Input.Mouse.Left.Down, function(self, h) -- Left click to select the item
            if viewSelectedItemsToLock[itemType] == nil then
                -- Toggle selection
                if viewSelectedItemsToDeselect[itemType] == nil then
                    viewSelectedItemsToDeselect[itemType] = {
                        name = idetail.name,
                        icon = idetail.icon,
                        rarity = idetail.rarity
                    }
                else
                    viewSelectedItemsToDeselect[itemType] = nil
                end
                redisplaySelectedItems()
            end
        end, 'Event.UI.Input.Mouse.Left.Down')
        borderFrame:EventAttach(Event.UI.Input.Mouse.Right.Down, function(self, h) -- Right click to make item locked
            -- Toggle selection
            if viewSelectedItemsToLock[itemType] == nil then
                viewSelectedItemsToLock[itemType] = {
                    name = idetail.name,
                    icon = idetail.icon,
                    rarity = idetail.rarity
                }
                viewSelectedItemsToDeselect[itemType] = {
                    name = idetail.name,
                    icon = idetail.icon,
                    rarity = idetail.rarity
                }
                lfUITooltips:SetText('[LOCKED]\n' .. idetail.name)
            else
                viewSelectedItemsToLock[itemType] = nil
                lfUITooltips:SetText(idetail.name)
            end
            redisplaySelectedItems()
        end, 'Event.UI.Input.Mouse.Right.Down')
    else
        borderFrame = viewSelectedItemsDisplayed['Border:' .. itemType]
    end
    -- locked/selected item border logic
    if viewSelectedItemsToLock[itemType] ~= nil then
        -- if item is locked, make the border purple
        borderFrame:SetBackgroundColor(0.25, 0, 0.25)
        borderFrame:SetAlpha(1)
    elseif viewSelectedItemsToDeselect[itemType] == nil then
        -- if item is selected, make the border yellow
        if idetailRaw == true then
            borderFrame:SetBackgroundColor(0.4, 0.4, 0)
        else
            borderFrame:SetBackgroundColor(1, 1, 0)
        end
        borderFrame:SetAlpha(1)
    else
        -- otherwise, have no border
        borderFrame:SetAlpha(0)
    end
    borderFrame:SetPoint('TOPLEFT', lfUIViewSelectedFrame, 'TOPLEFT', posX, posY)
    borderFrame:SetWidth(72)
    borderFrame:SetHeight(72)
    borderFrame:SetLayer(5)
    borderFrame:SetVisible(true)

    viewSelectedItemsDisplayed['Border:' .. itemType] = borderFrame

    if LootFilter_Settings.DisplayRarity and idetailRaw ~= true then
        -- Make the rarity indicator
        local rarityBorderFrame =  nil
        if viewSelectedItemsDisplayed['RarityBorder:' .. itemType] == nil then
            rarityBorderFrame = UI.CreateFrame('Frame', 'RarityBorder:' .. itemType, lfUIViewSelectedFrame)
        else
            rarityBorderFrame = viewSelectedItemsDisplayed['RarityBorder:' .. itemType]
        end
        rarityBorderFrame:SetBackgroundColor(colors.rf, colors.gf, colors.bf)
        rarityBorderFrame:SetPoint('TOPLEFT', lfUIViewSelectedFrame, 'TOPLEFT', posX + 4, posY + 4)
        rarityBorderFrame:SetWidth(5)
        rarityBorderFrame:SetHeight(6)
        rarityBorderFrame:SetLayer(15)
        rarityBorderFrame:SetVisible(true)
        if viewSelectedItemsToLock[itemType] ~= nil then
            rarityBorderFrame:SetAlpha(0.5) -- Grey out the items if item is locked.
        else
            rarityBorderFrame:SetAlpha(1)
        end
        viewSelectedItemsDisplayed['RarityBorder:' .. itemType] = rarityBorderFrame
    end

    -- Make the in game icon
    local itemIcon =  nil
    if viewSelectedItemsDisplayed['Icon:' .. itemType] == nil then
        itemIcon = UI.CreateFrame('Texture', 'Icon:' .. itemType, lfUIViewSelectedFrame)
    else
        itemIcon = viewSelectedItemsDisplayed['Icon:' .. itemType]
    end
    itemIcon:SetWidth(64)
    itemIcon:SetHeight(64)
    itemIcon:SetPoint('TOPLEFT', lfUIViewSelectedFrame, 'TOPLEFT', posX+4, posY+4)
    itemIcon:SetLayer(10)
    itemIcon:SetTexture('Rift', idetail.icon)
    itemIcon:SetVisible(true)
    if viewSelectedItemsToLock[itemType] ~= nil then
        itemIcon:SetAlpha(0.5) -- Grey out the items if item is locked.
    else
        itemIcon:SetAlpha(1)
    end
    viewSelectedItemsDisplayed['Icon:' .. itemType] = itemIcon
end

-- Displays every selected item
displaySelectedItems = function(numSelectedItems)
    if lfUIViewSelectedWindow ~= nil and lfUIViewSelectedWindow:GetVisible() == true then
        if lfUIViewSelectedFrame == nil then
            lfUIViewSelectedFrame = UI.CreateFrame('Frame', 'lfUIViewSelectedFrame', lfUIViewSelectedWindow)
        end
        lfUIViewSelectedFrame:SetVisible(true)
        lfUIViewSelectedFrame:SetPoint('TOPLEFT', lfUIViewSelectedWindow, 'TOPLEFT', 0, 0)
    end

    -- Item display positioning logic
    local tempNumColumns = 0
    local numRows = 0

    -- Loop through the items in the page
    local i = 1
    for k,v in pairs(LootFilter_Settings.SelectedItems) do
        -- Ensure the items we want to display are on the current page
        -- Page 1: if i > 0 and i <= 40
        -- Page 2: if i > 40 and i <= 80
        -- etc
        if i > ((viewSelectedDisplayPageNum - 1)*40) and i <= (viewSelectedDisplayPageNum*40) then
            if lfUIViewSelectedWindow ~= nil and lfUIViewSelectedWindow:GetVisible() == true then
                displaySelectedItem(k, v, 60 + (80 * tempNumColumns), 100 + (80 * numRows))
                tempNumColumns = tempNumColumns + 1
                if tempNumColumns == 8 then
                    numRows = numRows + 1
                    tempNumColumns = 0
                end
            end
        end
        i = i + 1
    end
end

-- View Selected Items window
local function displayViewSelectedWindow()
    -- Create something behind the scenes for stuff to sit on
    if lfUIContext == nil then
        lfUIContext = UI.CreateContext('lfUIContext')
    end
    lfUIContext:SetVisible(true)

    -- Create a window
    if lfUIViewSelectedWindow == nil then
        lfUIViewSelectedWindow = UI.CreateFrame('SimpleWindow', 'lfUIViewSelectedWindow', lfUIContext)
        lfUIViewSelectedWindow:SetCloseButtonVisible(true)
        -- Reset the displayed state of application when window closes
        lfUIViewSelectedWindow.closeButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            lfUIViewSelectedWindow:SetVisible(false) -- the Loot Filter window
            lfUIViewSelectedFrame:SetVisible(false) -- the frame for the current page of Selected Items
            lfUIViewSelectedPageLeft:SetVisible(false) -- the button to move to the left in the pagination
            lfUIViewSelectedPageText:SetVisible(false) -- the page indicator
            lfUIViewSelectedPageRight:SetVisible(false) -- the button to move to the right in the pagination
            lfUIViewSelectedSubmit:SetVisible(false) -- the button to submit changes to the Selected Items window
    
            viewSelectedDisplayPageNum = 1 -- the page to display
            for _,v in pairs(viewSelectedItemsDisplayed) do
                v:SetVisible(false)
            end
            displayConfigWindow()
        end, 'CloseLeftClick')
    end
    lfUIViewSelectedWindow:SetVisible(true)
    lfUIViewSelectedWindow:SetTitle('Loot Filter - Selected Items')
    lfUIViewSelectedWindow:SetWidth(760)
    lfUIViewSelectedWindow:SetHeight(700)
    lfUIViewSelectedWindow:SetPoint(
        'TOPLEFT', UIParent, 'TOPLEFT',
        (UIParent:GetWidth()/2) - (lfUIViewSelectedWindow:GetWidth()/2),
        (UIParent:GetHeight()/2) - (lfUIViewSelectedWindow:GetHeight()/2)
    )
    lfUIViewSelectedWindow:SetLayer(10)


    -- Page Left Button
    if lfUIViewSelectedPageLeft == nil then
        lfUIViewSelectedPageLeft = UI.CreateFrame('RiftButton', 'lfUIViewSelectedPageLeft', lfUIViewSelectedWindow)
        -- Move the current page number to the left, or rotate around to the other side
        lfUIViewSelectedPageLeft:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            viewSelectedDisplayPageNum = viewSelectedDisplayPageNum - 1
            redisplaySelectedItems()
        end, 'Page Left Left Click')
    end
    lfUIViewSelectedPageLeft:SetVisible(true)
    lfUIViewSelectedPageLeft:SetText('<--')
    lfUIViewSelectedPageLeft:SetPoint('BOTTOMLEFT', lfUIViewSelectedWindow, 'BOTTOMLEFT', 60, -25)

    -- Page Indicator Text
    if lfUIViewSelectedPageText == nil then
        lfUIViewSelectedPageText = UI.CreateFrame('Text', 'lfUIViewSelectedPageText', lfUIViewSelectedWindow)
    end
    lfUIViewSelectedPageText:SetVisible(true)
    lfUIViewSelectedPageText:SetFontSize(24)

    -- Page Right Button
    if lfUIViewSelectedPageRight == nil then
        lfUIViewSelectedPageRight = UI.CreateFrame('RiftButton', 'lfUIViewSelectedPageRight', lfUIViewSelectedWindow)
        -- Move the current page number to the right, or rotate around to the other side
        lfUIViewSelectedPageRight:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            viewSelectedDisplayPageNum = viewSelectedDisplayPageNum + 1
            redisplaySelectedItems()
        end, 'Page Right Left Click')
    end
    lfUIViewSelectedPageRight:SetVisible(true)
    lfUIViewSelectedPageRight:SetText('-->')
    lfUIViewSelectedPageRight:SetPoint('BOTTOMRIGHT', lfUIViewSelectedWindow, 'BOTTOMRIGHT', -60, -25)

    -- Submit Button
    if lfUIViewSelectedSubmit == nil then
        lfUIViewSelectedSubmit = UI.CreateFrame('RiftButton', 'lfUIViewSelectedSubmit', lfUIViewSelectedWindow)
        -- Submits the Selected Items view, triggering many data events
        lfUIViewSelectedSubmit:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            -- Remove itemsToDeselect from the SelectedItems official list
            for idetailType,_ in pairs(viewSelectedItemsToDeselect) do
                LootFilter_Settings.SelectedItems[idetailType] = nil
            end
            -- Add itemsToLock to the LockedItems official list
            for idetailType,val in pairs(viewSelectedItemsToLock) do
                LootFilter_Settings.LockedItems[idetailType] = val
            end
            viewSelectedItemsToDeselect = {}
            viewSelectedItemsToLock = {}
            -- Redisplay
            redisplaySelectedItems()
            redisplayInventory(true)
        end, 'Submit Left Click')
    end
    lfUIViewSelectedSubmit:SetVisible(true)
    lfUIViewSelectedSubmit:SetText('Submit Changes')
    lfUIViewSelectedSubmit:SetPoint('BOTTOMRIGHT', lfUIViewSelectedWindow, 'BOTTOMRIGHT', -60, -70)

    -- Used to show the item names on hover
    if lfUITooltips == nil then
        lfUITooltips = UI.CreateFrame('SimpleTooltip', 'lfUITooltips', lfUIContext)
    end

    redisplaySelectedItems()
end

-- Auto Delete confirmation window
local function createConfirmAutoDeleteWindow()
    -- Create a hidden confirmation window
    if lfUIConfirmAutoDeleteWindow == nil then
        lfUIConfirmAutoDeleteWindow = UI.CreateFrame('SimpleWindow', 'lfUIConfirmAutoDeleteWindow', lfUIContext)
        lfUIConfirmAutoDeleteWindow:SetCloseButtonVisible(true)
        lfUIConfirmAutoDeleteWindow.closeButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            -- Re-enable the show selected checkbox
            lfUIShowSelectedCheckbox:SetEnabled(true)
        end, 'CloseLeftClick')
    end
    lfUIConfirmAutoDeleteWindow:SetVisible(false)
    lfUIConfirmAutoDeleteWindow:SetTitle('START DELETING?')
    lfUIConfirmAutoDeleteWindow:SetWidth(380)
    lfUIConfirmAutoDeleteWindow:SetHeight(115)
    lfUIConfirmAutoDeleteWindow:SetLayer(20)

    -- Text disclaimer to inform the user how to save their changes
    if lfUIConfirmAutoDeleteNumItemsText == nil then
        lfUIConfirmAutoDeleteNumItemsText = UI.CreateFrame('Text', 'lfUIConfirmAutoDeleteNumItemsText', lfUIConfirmAutoDeleteWindow)
    end
    lfUIConfirmAutoDeleteNumItemsText:SetVisible(false)
    lfUIConfirmAutoDeleteNumItemsText:SetFontSize(14)

    -- Add the Start button
    if lfUIConfirmAutoDeleteStartButton == nil then
        lfUIConfirmAutoDeleteStartButton = UI.CreateFrame('RiftButton', 'lfUIConfirmAutoDeleteStartButton', lfUIConfirmAutoDeleteWindow)
        -- Start auto deleting if confirm is clicked
        lfUIConfirmAutoDeleteStartButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            -- Automatically disable 'show only selected'
            lfUIShowSelectedCheckbox:SetChecked(false)
            lfUIShowSelectedCheckbox:SetEnabled(false)

            -- Remove all confirmation UI
            lfUIConfirmAutoDeleteNumItemsText:SetVisible(false)
            lfUIConfirmAutoDeleteStartButton:SetVisible(false)
            lfUIConfirmAutoDeleteCancelButton:SetVisible(false)
            lfUIConfirmAutoDeleteWindow:SetVisible(false)

            -- Start Auto Deleting
            LootFilter_Settings.AutoDeleting = true

            -- Checkbox the UI
            lfUIDeleteSelectedCheckbox:SetChecked(true)

            -- Trigger a redisplay, which starts auto deleting
            redisplayInventory(true)
        end, 'Start Left Click')
    end
    lfUIConfirmAutoDeleteStartButton:SetVisible(false)
    lfUIConfirmAutoDeleteStartButton:SetText('Start')
    lfUIConfirmAutoDeleteStartButton:SetPoint('TOPLEFT', lfUIConfirmAutoDeleteWindow, 'TOPLEFT', 30, 70)

    -- Add the Cancel button
    if lfUIConfirmAutoDeleteCancelButton == nil then
        lfUIConfirmAutoDeleteCancelButton = UI.CreateFrame('RiftButton', 'lfUIConfirmAutoDeleteCancelButton', lfUIConfirmAutoDeleteWindow)
        -- Cancel confirmation, do not auto delete
        lfUIConfirmAutoDeleteCancelButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            -- Remove all confirmation UI
            lfUIConfirmAutoDeleteNumItemsText:SetVisible(false)
            lfUIConfirmAutoDeleteStartButton:SetVisible(false)
            lfUIConfirmAutoDeleteCancelButton:SetVisible(false)
            lfUIConfirmAutoDeleteWindow:SetVisible(false)
            -- Re-enable the show selected checkbox
            lfUIShowSelectedCheckbox:SetEnabled(true)
            redisplayInventory()
        end, 'Cancel Left Click')
    end
    lfUIConfirmAutoDeleteCancelButton:SetVisible(false)
    lfUIConfirmAutoDeleteCancelButton:SetText('Cancel')
    lfUIConfirmAutoDeleteCancelButton:SetPoint('TOPRIGHT', lfUIConfirmAutoDeleteWindow, 'TOPRIGHT', -30, 70)

end

-- Auto Delete configuration window
displayConfigWindow = function()
    if lfUIWindow == nil or lfUIWindow:GetVisible() == false then
        if lfUIViewSelectedWindow ~= nil and lfUIViewSelectedWindow:GetVisible() == true then
            lfUIViewSelectedWindow:SetVisible(false) -- the Loot Filter window
            lfUIViewSelectedFrame:SetVisible(false) -- the frame for the current page of Selected Items
            lfUIViewSelectedPageLeft:SetVisible(false) -- the button to move to the left in the pagination
            lfUIViewSelectedPageText:SetVisible(false) -- the page indicator
            lfUIViewSelectedPageRight:SetVisible(false) -- the button to move to the right in the pagination
            lfUIViewSelectedSubmit:SetVisible(false) -- the button to submit changes to the Selected Items window

            viewSelectedDisplayPageNum = 1 -- the page to display
            for _,v in pairs(viewSelectedItemsDisplayed) do
                v:SetVisible(false)
            end
        end
        -- Create something behind the scenes for stuff to sit on
        if lfUIContext == nil then
            lfUIContext = UI.CreateContext('lfUIContext')
        end
        lfUIContext:SetVisible(true)

        -- Create a window
        if lfUIWindow == nil then -- if none exists, create it and make the event
            lfUIWindow = UI.CreateFrame('SimpleWindow', 'lfUIWindow', lfUIContext)
            lfUIWindow:SetCloseButtonVisible(true)
            -- Reset the displayed state of application when window closes
            lfUIWindow.closeButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
                lfUIWindow:SetVisible(false) -- the Loot Filter window
                lfUIInventoryFrame:SetVisible(false) -- the Inventory page
                lfUIShowSelectedCheckbox:SetVisible(false) -- the checkbox to show only the selected items
                lfUIDeleteSelectedCheckbox:SetVisible(false) -- the checkbox to trigger auto deletion of the selected items
                lfUIReloadDisclaimerText:SetVisible(false) -- text to inform the user to use /reloadui to save settings
                lfUITooltips:SetVisible(false) -- tooltips
                if lfUIConfirmAutoDeleteWindow ~= nil then
                    lfUIConfirmAutoDeleteWindow:SetVisible(false) -- the window to confirm enabling Auto Delete
                    lfUIConfirmAutoDeleteNumItemsText:SetVisible(false) -- the number of items to delete
                    lfUIConfirmAutoDeleteStartButton:SetVisible(false) -- the Start auto deleting button
                    lfUIConfirmAutoDeleteCancelButton:SetVisible(false) -- the Cancel confirm auto deleting button
                end
                displayBagNum = 1 -- the bag to display
                for _,v in pairs(itemsDisplayed) do
                    v:SetVisible(false)
                end
            end, 'CloseLeftClick')
        end
        lfUIWindow:SetVisible(true)
        lfUIWindow:SetTitle('Loot Filter')
        lfUIWindow:SetWidth(760)
        lfUIWindow:SetHeight(800)
        lfUIWindow:SetPoint(
            'TOPLEFT', UIParent, 'TOPLEFT',
            (UIParent:GetWidth()/2) - (lfUIWindow:GetWidth()/2),
            (UIParent:GetHeight()/2) - (lfUIWindow:GetHeight()/2)
        )
        lfUIWindow:SetLayer(10)


        -- Button to open the Selected Items window
        if lfUIViewSelectedButton == nil then
            lfUIViewSelectedButton = UI.CreateFrame('RiftButton', 'lfUIViewSelectedButton', lfUIWindow)
            lfUIViewSelectedButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
                displayViewSelectedWindow()
                lfUIWindow:SetVisible(false) -- the Loot Filter window
                lfUIInventoryFrame:SetVisible(false) -- the Inventory page
                lfUIShowSelectedCheckbox:SetVisible(false) -- the checkbox to show only the selected items
                lfUIDeleteSelectedCheckbox:SetVisible(false) -- the checkbox to trigger auto deletion of the selected items
                lfUIReloadDisclaimerText:SetVisible(false) -- text to inform the user to use /reloadui to save settings
                lfUITooltips:SetVisible(false) -- tooltips
                if lfUIConfirmAutoDeleteWindow ~= nil then
                    lfUIConfirmAutoDeleteWindow:SetVisible(false) -- the window to confirm enabling Auto Delete
                    lfUIConfirmAutoDeleteNumItemsText:SetVisible(false) -- the number of items to delete
                    lfUIConfirmAutoDeleteStartButton:SetVisible(false) -- the Start auto deleting button
                    lfUIConfirmAutoDeleteCancelButton:SetVisible(false) -- the Cancel confirm auto deleting button
                end
                displayBagNum = 1 -- the bag to display
                for _,v in pairs(itemsDisplayed) do
                    v:SetVisible(false)
                end
            end, 'View Selected Left Click')
        end
        lfUIViewSelectedButton:SetVisible(true)
        lfUIViewSelectedButton:SetText('View Selected')
        lfUIViewSelectedButton:SetPoint('BOTTOMRIGHT', lfUIWindow, 'BOTTOMRIGHT', -60, -120)

        -- Display Only Selected Checkbox
        if lfUIShowSelectedCheckbox == nil then -- if none exists, create it and make the event
            lfUIShowSelectedCheckbox = UI.CreateFrame('SimpleCheckbox', 'lfUIShowSelectedCheckbox', lfUIWindow)
            lfUIShowSelectedCheckbox.check:EventAttach(Event.UI.Checkbox.Change, function(self, h)
                if lfUIShowSelectedCheckbox:GetEnabled() == true then
                    redisplayInventory()
                else
                    -- Prevent checking the show selected checkbox while auto deleting
                    if LootFilter_Settings.AutoDeleting and lfUIShowSelectedCheckbox:GetChecked() == true then
                        lfUIShowSelectedCheckbox:SetChecked(false)
                    end
                end
            end, 'Display Selected Items Checkbox Changed')
        end
        lfUIShowSelectedCheckbox:SetVisible(true)
        lfUIShowSelectedCheckbox:SetText('Display Only Selected Items')
        lfUIShowSelectedCheckbox:SetFontSize(28)
        lfUIShowSelectedCheckbox:SetChecked(false)
        lfUIShowSelectedCheckbox:SetEnabled(not LootFilter_Settings.AutoDeleting)
        lfUIShowSelectedCheckbox:SetPoint('BOTTOMLEFT', lfUIWindow, 'BOTTOMLEFT', 60, -120)

        -- Auto Delete Checkbox
        if lfUIDeleteSelectedCheckbox == nil then -- if none exists, create it and make the event
            lfUIDeleteSelectedCheckbox = UI.CreateFrame('SimpleCheckbox', 'lfUIDeleteSelectedCheckbox', lfUIWindow)
            lfUIDeleteSelectedCheckbox.check:EventAttach(Event.UI.Checkbox.Change, function(self, h)
                -- If checkbox is selected when we aren't auto deleting
                if lfUIDeleteSelectedCheckbox:GetChecked() == true and not LootFilter_Settings.AutoDeleting then
                    -- Automatically deselect the checkbox until we're *certain* we want to be
                    lfUIDeleteSelectedCheckbox:SetChecked(false)

                    -- Ensure the confirmation window has been created
                    if lfUIConfirmAutoDeleteWindow == nil then
                        createConfirmAutoDeleteWindow()
                    end

                    if lfUIConfirmAutoDeleteWindow ~= nil then
                        -- Toggle the display of the confirmation window
                        if lfUIConfirmAutoDeleteWindow:GetVisible() == false then
                            -- Show the confirmation window
                            lfUIConfirmAutoDeleteWindow:SetVisible(true)
                            lfUIConfirmAutoDeleteStartButton:SetVisible(true)
                            lfUIConfirmAutoDeleteCancelButton:SetVisible(true)
                            lfUIConfirmAutoDeleteNumItemsText:SetVisible(true)

                            updateDeletionConfirmationText()

                            -- Put the confirmation window to the middle of the screen
                            lfUIConfirmAutoDeleteWindow:SetPoint(
                                'TOPLEFT', UIParent, 'TOPLEFT',
                                (UIParent:GetWidth()/2) - (lfUIConfirmAutoDeleteWindow:GetWidth()/2),
                                (UIParent:GetHeight()/2) - (lfUIConfirmAutoDeleteWindow:GetHeight()/2)
                            )
                        else
                            -- Remove all confirmation UI
                            lfUIConfirmAutoDeleteNumItemsText:SetVisible(false)
                            lfUIConfirmAutoDeleteStartButton:SetVisible(false)
                            lfUIConfirmAutoDeleteCancelButton:SetVisible(false)
                            lfUIConfirmAutoDeleteWindow:SetVisible(false)
                        end
                    end

                -- If auto delete checkbox is no longer selected
                elseif lfUIDeleteSelectedCheckbox:GetChecked() == false then
                    -- Ensure we are not auto deleting since we are not checked
                    LootFilter_Settings.AutoDeleting = false
                    -- Re-enable the show only selected checkbox
                    lfUIShowSelectedCheckbox:SetEnabled(true)
                    -- Trigger a redisplay (useful only when the Prevent Deletion setting is active)
                    redisplayInventory()
                end


            end, 'Delete Selected Items Checkbox Changed')
        end
        lfUIDeleteSelectedCheckbox:SetVisible(true)
        lfUIDeleteSelectedCheckbox:SetText('Automatically Delete Selected Items')
        lfUIDeleteSelectedCheckbox:SetFontSize(28)
        lfUIDeleteSelectedCheckbox:SetChecked(LootFilter_Settings.AutoDeleting)
        lfUIDeleteSelectedCheckbox:SetPoint('BOTTOMLEFT', lfUIWindow, 'BOTTOMLEFT', 60, -70)

        -- Text disclaimer to inform the user how to save their changes
        if lfUIReloadDisclaimerText == nil then
            lfUIReloadDisclaimerText = UI.CreateFrame('Text', 'lfUIReloadDisclaimerText', lfUIWindow)
        end
        lfUIReloadDisclaimerText:SetPoint('BOTTOMLEFT', lfUIWindow, 'BOTTOMLEFT', 60, -25)
        lfUIReloadDisclaimerText:SetVisible(true)
        lfUIReloadDisclaimerText:SetText('Use /reloadui to save your settings in case Rift crashes!')
        lfUIReloadDisclaimerText:SetFontSize(24)

        -- Used to show the item names on hover
        if lfUITooltips == nil then
            lfUITooltips = UI.CreateFrame('SimpleTooltip', 'lfUITooltips', lfUIContext)
        end
    else
        -- Reset the position when redisplaying
        lfUIWindow:SetPoint(
            'TOPLEFT', UIParent, 'TOPLEFT',
            (UIParent:GetWidth()/2) - (lfUIWindow:GetWidth()/2),
            (UIParent:GetHeight()/2) - (lfUIWindow:GetHeight()/2)
        )
    end
    redisplayInventory(true)
end

-- the /lf command
local function slashHandler(eventHandle, params)
    local sanitizedArgs = string.split(string.lower(string.trim(params)), '%s+', true)
    local function printSettings()
        print('===')
        print('Loot Filter settings:')
        print('===')
        print('[Auto Deleting]: ' .. tostring(LootFilter_Settings.AutoDeleting))
        if LootFilter_Settings.AutoDeleting then
            print('- Loot Filter is currently automatically deleting selected items')
        else
            print('- Loot Filter is not automatically deleting items at this time')
        end
        print('===')
        print('[Display Rarity]: ' .. tostring(LootFilter_Settings.DisplayRarity))
        print('- /lf toggle rarity')
        if LootFilter_Settings.DisplayRarity then
            print('- Rarity indicators are being displayed in the Loot Filter config window')
        else
            print('- Rarity indicators are hidden in the Loot Filter config window')
        end
        print('===')
        print('[Display Chat]: ' .. tostring(LootFilter_Settings.DisplayChat))
        print('- /lf toggle chat')
        if LootFilter_Settings.DisplayChat then
            print('- Chat messages are being displayed whenever deletions occur')
        else
            print('- Chat messages are hidden whenever deletions occur')
        end
        print('===')
        print('[Prevent Deletion]: ' .. tostring(LootFilter_Settings.PreventDeletion))
        print('- /lf toggle prevent')
        if LootFilter_Settings.PreventDeletion then
            if LootFilter_Settings.AutoDeleting then
                print('- Automatic deletions are being prevented at the last moment')
            else
                print('- Automatic deletions would be prevented if Auto Deleting was enabled')
            end
        else
            if LootFilter_Settings.AutoDeleting then
                print('- Automatic deletions are allowed when they occur')
            else
                print('- Automatic deletions would be allowed if Auto Deleting was enabled')
            end
        end
        print('===')
        print('[Auto Select Grey Items]: ' .. tostring(LootFilter_Settings.AutoSelectGreyItems))
        print('- /lf toggle grey')
        if LootFilter_Settings.AutoSelectGreyItems then
            if LootFilter_Settings.AutoDeleting then
                print('- Grey items are automatically being Selected and Deleted')
            else
                print('- Grey items are automatically being Selected')
            end
        else
            print('- Grey items require manual selection')
        end
        print('===')
    end
    local function printHelp()
        print('===')
        print('Loot Filter commands:')
        print('===')
        print('/lf or /lf config - Displays the config window to select items from bags')
        print('/lf selected - Displays the window for managing the character\'s selected items')
        print('/lf settings - Displays the current state of all Loot Filter settings')
        print('/lf toggle rarity - Toggles the rarity indicator of items in the config window')
        print('/lf toggle chat - Toggles the display of the auto deletion chat messages')
        print('/lf toggle prevent - Toggles whether or not auto delete will *actually* delete the item')
        print('/lf toggle grey - Toggles the automatic selection of grey items')
        print('/lfnull - Nuclear debug option - Deletes every piece of Loot Filter data for the char')
        print('===')
    end
    if #sanitizedArgs >= 1 and sanitizedArgs[1] ~= '' then
        if sanitizedArgs[1] == 'toggle' then
            if sanitizedArgs[2] == 'rarity' then
                LootFilter_Settings.DisplayRarity = not LootFilter_Settings.DisplayRarity
                print('Display Rarity setting is now set to: ' .. tostring(LootFilter_Settings.DisplayRarity))
                redisplayInventory()
            elseif sanitizedArgs[2] == 'chat' then
                LootFilter_Settings.DisplayChat = not LootFilter_Settings.DisplayChat
                print('Display Chat setting is now set to: ' .. tostring(LootFilter_Settings.DisplayChat))
            elseif sanitizedArgs[2] == 'prevent' then
                LootFilter_Settings.PreventDeletion = not LootFilter_Settings.PreventDeletion
                print('Prevent Deletion setting is now set to: ' .. tostring(LootFilter_Settings.PreventDeletion))
            elseif sanitizedArgs[2] == 'grey' or sanitizedArgs[2] == 'gray' then
                LootFilter_Settings.AutoSelectGreyItems = not LootFilter_Settings.AutoSelectGreyItems
                print('Auto Select Grey Items setting is now set to: ' .. tostring(LootFilter_Settings.AutoSelectGreyItems))
                redisplayInventory()
            else
                printHelp()
            end
        elseif sanitizedArgs[1] == 'settings' then
            printSettings()
        elseif sanitizedArgs[1] == 'config' then
            displayConfigWindow()
        elseif sanitizedArgs[1] == 'selected' then
            displayViewSelectedWindow()
        else
            printHelp()
        end
    else
        displayConfigWindow()
    end
end

-- This is the /idetail debug command's functions.
local function slashHandlerIDetail(eventHandle, params)
    local sanitizedArgs = string.split(string.lower(string.trim(params)), '%s+', true)
    if #sanitizedArgs == 2 then
        -- User wants to search in a specific bag x to display a specific item y (/idetail x y)
        if
            tonumber(sanitizedArgs[1]) ~= nil
            and tonumber(sanitizedArgs[1]) > 0
            and tonumber(sanitizedArgs[2]) ~= nil
            and tonumber(sanitizedArgs[2]) > 0
        then
            local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(tonumber(sanitizedArgs[1]), tonumber(sanitizedArgs[2])))
            if idetail ~= nil then
                print('===')
                for k,v in pairs(idetail) do
                    print(tostring(k) .. ': ' .. tostring(v))
                end
                print('===')
            else
                print('No item in this slot!')
            end
        -- User wants to display information about a specific bag y (/idetail bag y)
        elseif
            sanitizedArgs[1] == 'bag'
            and tonumber(sanitizedArgs[2]) ~= nil
            and tonumber(sanitizedArgs[2]) > 0
        then
            local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(sanitizedArgs[1], tonumber(sanitizedArgs[2])))
            if idetail ~= nil then
                print('===')
                for k,v in pairs(idetail) do
                    print(tostring(k) .. ': ' .. tostring(v))
                end
                print('===')
            else
                print('No bag in this slot!')
            end
        end
    -- User wants to inspect all items in a specific bag x (/idetail x)
    elseif
        #sanitizedArgs == 1
        and tonumber(sanitizedArgs[1]) ~= nil
        and tonumber(sanitizedArgs[1]) > 0
    then
        for ikey,ival in pairs(Inspect.Item.List(Utility.Item.Slot.Inventory(tonumber(sanitizedArgs[1])))) do
            -- Does not apply to empty inventory slots.
            -- Only applies to items in your inventory, NOT the banks / etc.
            local itemLocation,bagSlot,itemSlot = Utility.Item.Slot.Parse(ikey)
            if(
                ival ~= false
                and itemLocation == 'inventory'
            ) then
                local idetail = Inspect.Item.Detail(ikey) -- Get the current item details.
                print(idetail.name .. ': ' .. ikey .. ' | ' .. ival .. ' | ' .. bagSlot .. ' | ' .. itemSlot)
            end
        end
    -- Display basic info about all items in the entire inventory to the user (/idetail *or* an unrecognized command)
    else
        for ikey,ival in pairs(Inspect.Item.List()) do
            -- Does not apply to empty inventory slots.
            -- Only applies to items in your inventory, NOT the banks / etc.
            local itemLocation,bagSlot,itemSlot = Utility.Item.Slot.Parse(ikey)
            if(
                ival ~= false
                and itemLocation == 'inventory'
            ) then
                local idetail = Inspect.Item.Detail(ikey) -- Get the current item details.
                print(idetail.name .. ': ' .. ikey .. ' | ' .. ival .. ' | ' .. bagSlot .. ' | ' .. itemSlot)
            end
        end
    end
end

-- This is the /lfnull debug command. It removes the *entire* configuration of the loot filter.
local function slashHandlerNull(eventHandle, params)
    LootFilter_Settings = {}
    LootFilter_Settings.LockedItems = {}
    LootFilter_Settings.SelectedItems = {}
    LootFilter_Settings.AutoDeleting = false
    LootFilter_Settings.AutoSelectGreyItems = false
    LootFilter_Settings.TotalItemsDeleted = 0
    LootFilter_Settings.DisplayRarity = true
    LootFilter_Settings.DisplayChat = true
    LootFilter_Settings.PreventDeletion = false

    if lfUIWindow ~= nil and lfUIWindow:GetVisible() == true then
        lfUIShowSelectedCheckbox:SetChecked(false)
        lfUIShowSelectedCheckbox:SetEnabled(true)

        lfUIDeleteSelectedCheckbox:SetChecked(false)

        redisplayInventory()
    end
    print('Nullified all saved Loot Filter settings on this character.')
    print('Please use the /reloadui command now :)')
end

local function initializeState(eventHandle, addonidentifier)
    if addonidentifier == 'LootFilter' then
        if LootFilter_Settings == nil then
            LootFilter_Settings = {}
        end
        if LootFilter_Settings.LockedItems == nil then
            LootFilter_Settings.LockedItems = {} -- items that the user NEVER wants deleted
        end
        if LootFilter_Settings.SelectedItems == nil then
            LootFilter_Settings.SelectedItems = {} -- items that the user selected
            -- Migrate values from an older version of the addon
            if LootFilter_Settings.itemsSelected ~= nil then
                print('Welcome to a new version of Loot Filter!')
                print('Migrating all previous selected items to a new format...')
                for itemitype,_ in pairs(LootFilter_Settings.itemsSelected) do
                    --print('Migrating: ' .. string.sub(itemitype, 6, -1))
                    local function migrateItemDetail(itemitype)
                        local idetail = Inspect.Item.Detail(string.sub(itemitype, 6, -1))
                        -- Add new details that were not previously present in the older version of the addon
                        LootFilter_Settings.SelectedItems[idetail.type] = {
                            name = idetail.name,
                            icon = idetail.icon,
                            rarity = idetail.rarity
                        }
                    end
                    -- if ANY error was thrown retrieving old item data...
                    if not pcall(migrateItemDetail, itemitype) then
                        -- just migrate the value as-is (true) and fill out the details later when the item is found again
                        LootFilter_Settings.SelectedItems[itemitype] = true
                    end
                end
                LootFilter_Settings.itemsSelected = nil
                print('Done!')
            end
        end
        if LootFilter_Settings.AutoDeleting == nil then
            LootFilter_Settings.AutoDeleting = false -- flag for whether or not to auto delete

            -- Remove a value from an older version of the addon
            if LootFilter_Settings.autoDeletingItems ~= nil then
                if LootFilter_Settings.autoDeletingItems then
                    print('Auto Deletion has been disabled as a result of the addon version migration!')
                    print('Please type /lf to confirm selected items and re-enable Auto Deletion!')
                end
                LootFilter_Settings.autoDeletingItems = nil
            end
        end
        if LootFilter_Settings.TotalItemsDeleted == nil then
            LootFilter_Settings.TotalItemsDeleted = 0 -- total number of items deleted by the addon (including stack count)
        end
        if LootFilter_Settings.DisplayRarity == nil then
            LootFilter_Settings.DisplayRarity = true -- display the rarity of the item in the config window
        end
        if LootFilter_Settings.DisplayChat == nil then
            LootFilter_Settings.DisplayChat = true -- display the chat of deletions of items
        end
        if LootFilter_Settings.PreventDeletion == nil then
            LootFilter_Settings.PreventDeletion = false -- ultimately prevents the deletion, allowing users to try and see how the addon works
        end
        if LootFilter_Settings.AutoSelectGreyItems == nil then
            LootFilter_Settings.AutoSelectGreyItems = false -- automatically selects all Grey-tier items (Sellable according to the Addon API)
        end
        print('Loot Filter ready!')
        if LootFilter_Settings.AutoDeleting then
            print('Loot Filter is currently Auto Deleting on this character!')
        end
    end
end

Command.Event.Attach(Command.Slash.Register('lf'), slashHandler, 'LootFilter')
Command.Event.Attach(Command.Slash.Register('lfnull'), slashHandlerNull, 'LootFilterNullify')
Command.Event.Attach(Command.Slash.Register('idetail'), slashHandlerIDetail, 'ItemDetailDebugger')

Command.Event.Attach(Event.Item.Slot, slotUpdateHandler, 'LootFilterSlotUpdatedSomewhere')
Command.Event.Attach(Event.Item.Update, slotUpdateHandler, 'LootFilterItemUpdatedSomewhere')
Command.Event.Attach(Event.Addon.SavedVariables.Load.End, initializeState, 'LootFilterSavedVariablesLoaded')
