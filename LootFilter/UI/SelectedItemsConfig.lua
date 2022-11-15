local addon, LF = ...

if LF.UI == nil then
    LF.UI = {}
end
LF.UI.SelectedItemsConfig = {}


LF.UI.SelectedItemsConfig.Window = nil -- the window to view all Selected Items
LF.UI.SelectedItemsConfig.Frame = nil -- the frame for the current page of Selected Items
LF.UI.SelectedItemsConfig.PageLeft = nil -- the button to move to the left in the pagination
LF.UI.SelectedItemsConfig.PageText = nil -- the page indicator
LF.UI.SelectedItemsConfig.PageRight = nil -- the button to move to the right in the pagination
LF.UI.SelectedItemsConfig.Submit = nil -- the button to submit changes to the Selected Items window

LF.UI.SelectedItemsConfig.DisplayPageNum = 1 -- the page to display
LF.UI.SelectedItemsConfig.ItemsToDeselect = {} -- the items to deselect
LF.UI.SelectedItemsConfig.ItemsToLock = {} -- the items to lock
LF.UI.SelectedItemsConfig.ItemsDisplayed = {} -- the frames of every item that has been displayed so far

LF.UI.SelectedItemsConfig.RedisplaySelectedItems = function(removeCurrentChanges)
    for _,v in pairs(LF.UI.SelectedItemsConfig.ItemsDisplayed) do
        v:SetVisible(false)
    end
    local numSelectedItems = 0
    for _,_ in pairs(LF.Settings.SelectedItems) do
        numSelectedItems = numSelectedItems + 1
    end
    -- move to last page if there are items and the current page is lower than the lower boundary
    if numSelectedItems ~= 0 and LF.UI.SelectedItemsConfig.DisplayPageNum < 1 then
        LF.UI.SelectedItemsConfig.DisplayPageNum = math.ceil(numSelectedItems / 40)
    end
    -- move to first page if there are items and the current page is higher than the highest boundary
    if numSelectedItems ~= 0 and LF.UI.SelectedItemsConfig.DisplayPageNum > math.ceil(numSelectedItems / 40) then
        -- Examples:
        -- 39 items is 1 page.  1 + 1 is 2, > 1, rotate it back around to 1.
        -- 40 items is 1 page.  1 + 1 is 2, > 1, rotate it back around to 1.
        -- 41 items is 2 pages. 2 + 1 is 3, > 2, rotate it back around to 1.
        LF.UI.SelectedItemsConfig.DisplayPageNum = 1
    end
    -- display a blank page when there are no selected items
    if numSelectedItems == 0 then
        LF.UI.SelectedItemsConfig.DisplayPageNum = 0
    end
    
    -- update the page indicator text
    local pageIndicatorText = tostring(LF.UI.SelectedItemsConfig.DisplayPageNum) .. '/' .. tostring(math.ceil(numSelectedItems / 40))
    if LF.UI.SelectedItemsConfig.PageText ~= nil then
        LF.UI.SelectedItemsConfig.PageText:SetPoint('BOTTOMLEFT', LF.UI.SelectedItemsConfig.Window, 'BOTTOMLEFT', LF.UI.SelectedItemsConfig.Window:GetWidth()/2 - 18 * string.len(pageIndicatorText), -25)
        LF.UI.SelectedItemsConfig.PageText:SetText(pageIndicatorText)
    end
    if removeCurrentChanges == true then
        LF.UI.SelectedItemsConfig.ItemsToDeselect = {} -- the items to deselect
        LF.UI.SelectedItemsConfig.ItemsToLock = {} -- the items to lock
    end
    -- display the page
    LF.UI.SelectedItemsConfig.DisplaySelectedItems(numSelectedItems)
end


-- Displays an item from the inventory at the coordinates on the inventory frame
LF.UI.SelectedItemsConfig.DisplaySelectedItem = function(itemType, idetailRaw, posX, posY)
    local idetail = idetailRaw
    
    -- item was migrated and needs a hug
    if idetailRaw == true then
        idetail = {
            name = 'Unknown Item\n'..itemType,
            icon = 'StartIconTray_I166.dds',
            rarity = nil
        }
    end


    local colors = LF.Utility.GetColors(idetail)

    -- Make the border
    local borderFrame = nil
    if LF.UI.SelectedItemsConfig.ItemsDisplayed['Border:' .. itemType] == nil then
        borderFrame = UI.CreateFrame('Frame', 'Border:' .. itemType, LF.UI.SelectedItemsConfig.Frame)
        LF.UI.SelectedItemsConfig.Tooltips:InjectEvents(borderFrame,
            function(t)
                t:SetFontSize(16)
                t:SetFontColor(colors.rf, colors.gf, colors.bf, 1)
                if LF.UI.SelectedItemsConfig.ItemsToLock[itemType] ~= nil then
                    return '[LOCKED]\n' .. idetail.name
                else
                    return idetail.name
                end
            end
        )
        -- Toggle item selection on click
        borderFrame:EventAttach(Event.UI.Input.Mouse.Left.Down, function(self, h) -- Left click to select the item
            if LF.UI.SelectedItemsConfig.ItemsToLock[itemType] == nil then
                -- Toggle selection
                if LF.UI.SelectedItemsConfig.ItemsToDeselect[itemType] == nil then
                    LF.UI.SelectedItemsConfig.ItemsToDeselect[itemType] = {
                        name = idetail.name,
                        icon = idetail.icon,
                        rarity = idetail.rarity
                    }
                else
                    LF.UI.SelectedItemsConfig.ItemsToDeselect[itemType] = nil
                end
                LF.UI.SelectedItemsConfig.RedisplaySelectedItems()
            end
        end, 'Event.UI.Input.Mouse.Left.Down')
        borderFrame:EventAttach(Event.UI.Input.Mouse.Right.Down, function(self, h) -- Right click to make item locked
            -- Toggle selection
            if LF.UI.SelectedItemsConfig.ItemsToLock[itemType] == nil then
                LF.UI.SelectedItemsConfig.ItemsToLock[itemType] = {
                    name = idetail.name,
                    icon = idetail.icon,
                    rarity = idetail.rarity
                }
                LF.UI.SelectedItemsConfig.ItemsToDeselect[itemType] = {
                    name = idetail.name,
                    icon = idetail.icon,
                    rarity = idetail.rarity
                }
                LF.UI.SelectedItemsConfig.Tooltips:SetText('[LOCKED]\n' .. idetail.name)
            else
                LF.UI.SelectedItemsConfig.ItemsToLock[itemType] = nil
                LF.UI.SelectedItemsConfig.Tooltips:SetText(idetail.name)
            end
            LF.UI.SelectedItemsConfig.RedisplaySelectedItems()
        end, 'Event.UI.Input.Mouse.Right.Down')
    else
        borderFrame = LF.UI.SelectedItemsConfig.ItemsDisplayed['Border:' .. itemType]
    end
    -- locked/selected item border logic
    if LF.UI.SelectedItemsConfig.ItemsToLock[itemType] ~= nil then
        -- if item is locked, make the border purple
        borderFrame:SetBackgroundColor(0.25, 0, 0.25)
        borderFrame:SetAlpha(1)
    elseif LF.UI.SelectedItemsConfig.ItemsToDeselect[itemType] == nil then
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
    borderFrame:SetPoint('TOPLEFT', LF.UI.SelectedItemsConfig.Frame, 'TOPLEFT', posX, posY)
    borderFrame:SetWidth(72)
    borderFrame:SetHeight(72)
    borderFrame:SetLayer(5)
    borderFrame:SetVisible(true)

    LF.UI.SelectedItemsConfig.ItemsDisplayed['Border:' .. itemType] = borderFrame

    if LF.Settings.DisplayRarity and idetailRaw ~= true then
        -- Make the rarity indicator
        local rarityBorderFrame =  nil
        if LF.UI.SelectedItemsConfig.ItemsDisplayed['RarityBorder:' .. itemType] == nil then
            rarityBorderFrame = UI.CreateFrame('Frame', 'RarityBorder:' .. itemType, LF.UI.SelectedItemsConfig.Frame)
        else
            rarityBorderFrame = LF.UI.SelectedItemsConfig.ItemsDisplayed['RarityBorder:' .. itemType]
        end
        rarityBorderFrame:SetBackgroundColor(colors.rf, colors.gf, colors.bf)
        rarityBorderFrame:SetPoint('TOPLEFT', LF.UI.SelectedItemsConfig.Frame, 'TOPLEFT', posX + 4, posY + 4)
        rarityBorderFrame:SetWidth(5)
        rarityBorderFrame:SetHeight(6)
        rarityBorderFrame:SetLayer(15)
        rarityBorderFrame:SetVisible(true)
        if LF.UI.SelectedItemsConfig.ItemsToLock[itemType] ~= nil then
            rarityBorderFrame:SetAlpha(0.5) -- Grey out the items if item is locked.
        else
            rarityBorderFrame:SetAlpha(1)
        end
        LF.UI.SelectedItemsConfig.ItemsDisplayed['RarityBorder:' .. itemType] = rarityBorderFrame
    end

    -- Make the in game icon
    local itemIcon =  nil
    if LF.UI.SelectedItemsConfig.ItemsDisplayed['Icon:' .. itemType] == nil then
        itemIcon = UI.CreateFrame('Texture', 'Icon:' .. itemType, LF.UI.SelectedItemsConfig.Frame)
    else
        itemIcon = LF.UI.SelectedItemsConfig.ItemsDisplayed['Icon:' .. itemType]
    end
    itemIcon:SetWidth(64)
    itemIcon:SetHeight(64)
    itemIcon:SetPoint('TOPLEFT', LF.UI.SelectedItemsConfig.Frame, 'TOPLEFT', posX+4, posY+4)
    itemIcon:SetLayer(10)
    itemIcon:SetTexture('Rift', idetail.icon)
    itemIcon:SetVisible(true)
    if LF.UI.SelectedItemsConfig.ItemsToLock[itemType] ~= nil then
        itemIcon:SetAlpha(0.5) -- Grey out the items if item is locked.
    else
        itemIcon:SetAlpha(1)
    end
    LF.UI.SelectedItemsConfig.ItemsDisplayed['Icon:' .. itemType] = itemIcon
end

-- Displays every selected item
LF.UI.SelectedItemsConfig.DisplaySelectedItems = function(numSelectedItems)
    if LF.UI.SelectedItemsConfig.Window ~= nil and LF.UI.SelectedItemsConfig.Window:GetVisible() == true then
        if LF.UI.SelectedItemsConfig.Frame == nil then
            LF.UI.SelectedItemsConfig.Frame = UI.CreateFrame('Frame', 'LF.UI.SelectedItemsConfig.Frame', LF.UI.SelectedItemsConfig.Window)
        end
        LF.UI.SelectedItemsConfig.Frame:SetVisible(true)
        LF.UI.SelectedItemsConfig.Frame:SetPoint('TOPLEFT', LF.UI.SelectedItemsConfig.Window, 'TOPLEFT', 0, 0)
    end

    -- Item display positioning logic
    local tempNumColumns = 0
    local numRows = 0

    -- Loop through the items in the page
    local i = 1
    for k,v in pairs(LF.Settings.SelectedItems) do
        -- Ensure the items we want to display are on the current page
        -- Page 1: if i > 0 and i <= 40
        -- Page 2: if i > 40 and i <= 80
        -- etc
        if i > ((LF.UI.SelectedItemsConfig.DisplayPageNum - 1)*40) and i <= (LF.UI.SelectedItemsConfig.DisplayPageNum*40) then
            if LF.UI.SelectedItemsConfig.Window ~= nil and LF.UI.SelectedItemsConfig.Window:GetVisible() == true then
                LF.UI.SelectedItemsConfig.DisplaySelectedItem(k, v, 60 + (80 * tempNumColumns), 100 + (80 * numRows))
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
LF.UI.SelectedItemsConfig.DisplayViewSelectedWindow = function()
    -- Create something behind the scenes for stuff to sit on
    LF.UI.General.Context:SetVisible(true)

    -- Create a window
    if LF.UI.SelectedItemsConfig.Window == nil then
        LF.UI.SelectedItemsConfig.Window = UI.CreateFrame('SimpleWindow', 'LF.UI.SelectedItemsConfig.Window', LF.UI.General.Context)
        LF.UI.SelectedItemsConfig.Window:SetCloseButtonVisible(true)
        -- Reset the displayed state of application when window closes
        LF.UI.SelectedItemsConfig.Window.closeButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
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
            LF.UI.InventoryConfig.DisplayConfigWindow()
        end, 'CloseLeftClick')
    end
    LF.UI.SelectedItemsConfig.Window:SetVisible(true)
    LF.UI.SelectedItemsConfig.Window:SetTitle('Loot Filter - Selected Items')
    LF.UI.SelectedItemsConfig.Window:SetWidth(760)
    LF.UI.SelectedItemsConfig.Window:SetHeight(700)
    LF.UI.SelectedItemsConfig.Window:SetPoint(
        'TOPLEFT', UIParent, 'TOPLEFT',
        (UIParent:GetWidth()/2) - (LF.UI.SelectedItemsConfig.Window:GetWidth()/2),
        (UIParent:GetHeight()/2) - (LF.UI.SelectedItemsConfig.Window:GetHeight()/2)
    )
    LF.UI.SelectedItemsConfig.Window:SetLayer(10)


    -- Page Left Button
    if LF.UI.SelectedItemsConfig.PageLeft == nil then
        LF.UI.SelectedItemsConfig.PageLeft = UI.CreateFrame('RiftButton', 'LF.UI.SelectedItemsConfig.PageLeft', LF.UI.SelectedItemsConfig.Window)
        -- Move the current page number to the left, or rotate around to the other side
        LF.UI.SelectedItemsConfig.PageLeft:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            LF.UI.SelectedItemsConfig.DisplayPageNum = LF.UI.SelectedItemsConfig.DisplayPageNum - 1
            LF.UI.SelectedItemsConfig.RedisplaySelectedItems()
        end, 'Page Left Left Click')
    end
    LF.UI.SelectedItemsConfig.PageLeft:SetVisible(true)
    LF.UI.SelectedItemsConfig.PageLeft:SetText('<--')
    LF.UI.SelectedItemsConfig.PageLeft:SetPoint('BOTTOMLEFT', LF.UI.SelectedItemsConfig.Window, 'BOTTOMLEFT', 60, -25)

    -- Page Indicator Text
    if LF.UI.SelectedItemsConfig.PageText == nil then
        LF.UI.SelectedItemsConfig.PageText = UI.CreateFrame('Text', 'LF.UI.SelectedItemsConfig.PageText', LF.UI.SelectedItemsConfig.Window)
    end
    LF.UI.SelectedItemsConfig.PageText:SetVisible(true)
    LF.UI.SelectedItemsConfig.PageText:SetFontSize(24)

    -- Page Right Button
    if LF.UI.SelectedItemsConfig.PageRight == nil then
        LF.UI.SelectedItemsConfig.PageRight = UI.CreateFrame('RiftButton', 'LF.UI.SelectedItemsConfig.PageRight', LF.UI.SelectedItemsConfig.Window)
        -- Move the current page number to the right, or rotate around to the other side
        LF.UI.SelectedItemsConfig.PageRight:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            LF.UI.SelectedItemsConfig.DisplayPageNum = LF.UI.SelectedItemsConfig.DisplayPageNum + 1
            LF.UI.SelectedItemsConfig.RedisplaySelectedItems()
        end, 'Page Right Left Click')
    end
    LF.UI.SelectedItemsConfig.PageRight:SetVisible(true)
    LF.UI.SelectedItemsConfig.PageRight:SetText('-->')
    LF.UI.SelectedItemsConfig.PageRight:SetPoint('BOTTOMRIGHT', LF.UI.SelectedItemsConfig.Window, 'BOTTOMRIGHT', -60, -25)

    -- Submit Button
    if LF.UI.SelectedItemsConfig.Submit == nil then
        LF.UI.SelectedItemsConfig.Submit = UI.CreateFrame('RiftButton', 'LF.UI.SelectedItemsConfig.Submit', LF.UI.SelectedItemsConfig.Window)
        -- Submits the Selected Items view, triggering many data events
        LF.UI.SelectedItemsConfig.Submit:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            -- Remove ItemsToDeselect from the SelectedItems official list
            for idetailType,_ in pairs(LF.UI.SelectedItemsConfig.ItemsToDeselect) do
                LF.Settings.SelectedItems[idetailType] = nil
                LF.Settings.PushUpdatesToSavedVariables()
            end
            -- Add ItemsToLock to the LockedItems official list
            for idetailType,val in pairs(LF.UI.SelectedItemsConfig.ItemsToLock) do
                LF.Settings.LockedItems[idetailType] = val
                LF.Settings.PushUpdatesToSavedVariables()
            end
            LF.UI.SelectedItemsConfig.ItemsToDeselect = {}
            LF.UI.SelectedItemsConfig.ItemsToLock = {}
            -- Redisplay
            LF.UI.SelectedItemsConfig.RedisplaySelectedItems()
            LF.UI.InventoryConfig.RedisplayInventory(true)
        end, 'Submit Left Click')
    end
    LF.UI.SelectedItemsConfig.Submit:SetVisible(true)
    LF.UI.SelectedItemsConfig.Submit:SetText('Submit Changes')
    LF.UI.SelectedItemsConfig.Submit:SetPoint('BOTTOMRIGHT', LF.UI.SelectedItemsConfig.Window, 'BOTTOMRIGHT', -60, -70)

    -- Used to show the item names on hover
    if LF.UI.SelectedItemsConfig.Tooltips == nil then
        LF.UI.SelectedItemsConfig.Tooltips = UI.CreateFrame('SimpleTooltip', 'LF.UI.SelectedItemsConfig.Tooltips', LF.UI.General.Context)
    end

    LF.UI.SelectedItemsConfig.RedisplaySelectedItems()
end