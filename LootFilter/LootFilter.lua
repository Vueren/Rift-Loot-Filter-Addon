local lfUIWindow = nil -- the Loot Filter window
local lfUIInventoryFrame = nil -- the Inventory page
local lfUIShowSelectedCheckbox = nil -- the checkbox to show only the selected items
local lfUITooltips = nil -- tooltips
local displayBagNum = 1 -- the bag to display
local displayItemsInBag = nil -- function to display the items in the displayBagNum bag slot
local itemsDisplayed = {} -- the frames of every item that has been displayed so far
if LootFilter_Settings == nil then
    LootFilter_Settings = {}
    LootFilter_Settings.itemsSelected = {} -- items that the user selected
    LootFilter_Settings.autoDeletingItems = false
end

-- Displays an item from the inventory at the coordinates on the inventory frame
local function displayItem(bagSlot, itemSlot, posX, posY, numItemsInBag)
    local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(bagSlot, itemSlot))

    if idetail ~= nil then
        -- Check if the item has already been displayed. If it has, simply display it again.
        local hasItemAlreadyBeenDisplayed = false
        for k,v in pairs(itemsDisplayed) do
            -- if an item border has already been displayed
            if
                k == "itemBorder:" .. tostring(bagSlot) .. tostring(itemSlot)
            then
                hasItemAlreadyBeenDisplayed = true
                v:SetVisible(true)
                v:SetPoint("TOPLEFT", lfUIInventoryFrame, "TOPLEFT", posX, posY)

                -- selected bag/item border logic
                if 
                    (bagSlot == 'bag' and itemSlot == displayBagNum)
                    or (LootFilter_Settings ~= nil and LootFilter_Settings.itemsSelected["item:" .. idetail.type] ~= nil)
                then
                    -- if it is selected, make the border yellow
                    v:SetBackgroundColor(1, 1, 0)
                else
                    -- otherwise, use grey
                    v:SetBackgroundColor(0.5, 0.5, 0.5)
                end
            -- if an item icon has already been displayed
            elseif 
                k == "itemIcon:" .. tostring(bagSlot) .. tostring(itemSlot) 
            then
                v:SetTexture("Rift", idetail.icon)
                v:SetVisible(true)
                v:SetPoint("TOPLEFT", lfUIInventoryFrame, "TOPLEFT", posX+2, posY+2)
            -- if an item quantity has already been displayed
            elseif
                k == "numItem:" .. tostring(bagSlot) .. tostring(itemSlot) 
            then
                v:SetVisible(false)
                if idetail.stack ~= nil and idetail.stack > 1 then
                    v:SetText(tostring(idetail.stack))
                    v:SetVisible(true)
                    v:SetPoint("TOPLEFT", lfUIInventoryFrame, "TOPLEFT", posX + 29 - math.floor(5.5 * string.len(tostring(idetail.stack))), posY+19)
                end
            -- if a bag item quantity has already been displayed
            elseif
                k == "numItems:" .. tostring(bagSlot) .. tostring(itemSlot) 
            then
                if numItemsInBag ~= nil then
                    v:SetText(tostring(numItemsInBag))
                    v:SetVisible(true)
                    v:SetPoint("TOPLEFT", lfUIInventoryFrame, "TOPLEFT", posX + 28 - (6 * string.len(tostring(numItemsInBag))), posY+17)
                end
            end
        end

        -- if the item has not already been displayed, we need to create it.
        if not hasItemAlreadyBeenDisplayed then
            -- Make the border
            local borderFrame = UI.CreateFrame("Frame", "itemBorder:" .. tostring(bagSlot) .. tostring(itemSlot), lfUIInventoryFrame)
            -- selected bag/item border logic
            if 
                (bagSlot == 'bag' and itemSlot == displayBagNum)
                or (LootFilter_Settings ~= nil and LootFilter_Settings.itemsSelected["item:" .. idetail.type] ~= nil)
            then
                -- if it is selected, make the border yellow
                borderFrame:SetBackgroundColor(1, 1, 0)
            else
                -- otherwise, use grey
                borderFrame:SetBackgroundColor(0.5, 0.5, 0.5)
            end
            borderFrame:SetPoint("TOPLEFT", lfUIInventoryFrame, "TOPLEFT", posX, posY)
            borderFrame:SetWidth(36)
            borderFrame:SetHeight(36)
            borderFrame:SetLayer(5)
            itemsDisplayed["itemBorder:" .. tostring(bagSlot) .. tostring(itemSlot)] = borderFrame

            -- Make the in game icon
            local itemIcon = UI.CreateFrame("Texture", "itemIcon:" .. tostring(bagSlot) .. tostring(itemSlot), lfUIInventoryFrame)
            itemIcon:SetWidth(32)
            itemIcon:SetHeight(32)
            itemIcon:SetPoint("TOPLEFT", lfUIInventoryFrame, "TOPLEFT", posX+2, posY+2)
            itemIcon:SetLayer(10)
            itemIcon:SetTexture("Rift", idetail.icon)
            itemsDisplayed["itemIcon:" .. tostring(bagSlot) .. tostring(itemSlot)] = itemIcon

            -- if the slot has multiple items in it, display text
            if idetail.stack ~= nil and idetail.stack > 1 then
                -- display a text in the lower right detailing the quantity of the item
                local numItem = UI.CreateFrame("Text", "numItem:" .. tostring(bagSlot) .. tostring(itemSlot), lfUIInventoryFrame)
                numItem:SetPoint("TOPLEFT", lfUIInventoryFrame, "TOPLEFT", posX + 29 - math.floor(5.5 * string.len(tostring(idetail.stack))), posY+19)
                numItem:SetFontSize(9)
                numItem:SetFontColor(1, 1, 1)
                numItem:SetBackgroundColor(0, 0, 0)
                numItem:SetText(tostring(idetail.stack))
                numItem:SetLayer(15)
                itemsDisplayed["numItem:" .. tostring(bagSlot) .. tostring(itemSlot)] = numItem
            end

            -- add a tooltip for the item or bag
            lfUITooltips:InjectEvents(borderFrame, 
                function(t)
                    t:SetFontSize(14)
                    t:SetFontColor(1, 1, 1, 1)
                    return idetail.name
                end
            )

            -- add the number of items in the bottom right of the bag
            if numItemsInBag ~= nil then
                local numItems = UI.CreateFrame("Text", "numItems:" .. tostring(bagSlot) .. tostring(itemSlot), lfUIInventoryFrame)
                numItems:SetPoint("TOPLEFT", lfUIInventoryFrame, "TOPLEFT", posX + 28 - (6 * string.len(tostring(numItemsInBag))), posY+17)
                numItems:SetFontSize(10)
                numItems:SetFontColor(1, 1, 1)
                numItems:SetBackgroundColor(0, 0, 0)
                numItems:SetText(tostring(numItemsInBag))
                numItems:SetLayer(15)
                itemsDisplayed["numItems:" .. tostring(bagSlot) .. tostring(itemSlot)] = numItems
            end
        
            -- Attach a click event to change the selected bag, and then Redisplay
            if bagSlot == 'bag' then
                borderFrame:EventAttach(Event.UI.Input.Mouse.Left.Down, function(self, h)
                    for k,v in pairs(itemsDisplayed) do
                        v:SetVisible(false)
                    end
                    displayBagNum = itemSlot
                    displayItemsInBag()
                end, "Event.UI.Input.Mouse.Left.Click")
            -- Attach a click event to select an item, and then Redisplay
            elseif bagSlot ~= 'bag' then
                borderFrame:EventAttach(Event.UI.Input.Mouse.Left.Down, function(self, h)
                    if LootFilter_Settings ~= nil and not LootFilter_Settings.autoDeletingItems then
                        for k,v in pairs(itemsDisplayed) do
                            v:SetVisible(false)
                        end
                        -- Toggle selection
                        if LootFilter_Settings.itemsSelected["item:" .. idetail.type] == nil then
                            LootFilter_Settings.itemsSelected["item:" .. idetail.type] = true
                        else
                            LootFilter_Settings.itemsSelected["item:" .. idetail.type] = nil
                        end
                        displayItemsInBag()
                    end
                end, "Event.UI.Input.Mouse.Left.Click")
            end
        end
    end
end

-- Displays every item in a specific bag
displayItemsInBag = function()
    
    if lfUIWindow ~= nil and lfUIWindow:GetVisible() then
        lfUIInventoryFrame = UI.CreateFrame("Frame", "Loot Filter UI - Window - Frame - Inventory", lfUIWindow)
        lfUIInventoryFrame:SetVisible(true)
        lfUIInventoryFrame:SetPoint("TOPLEFT", lfUIWindow, "TOPLEFT", 0, 0)
    end

    -- Loop through the possible bags
    for bagNum = 1, 8, 1 do
        -- Check if the bag exists
        local bag = Inspect.Item.Detail(Utility.Item.Slot.Inventory('bag', bagNum))
        if bag ~= nil then
            local numItemsInBag = 0

            -- Item display positioning logic
            local tempNumColumns = 0
            local numRows = 0
            -- Loop through the items in the bag
            for slotNum = 1, bag.slots, 1 do
                -- Determine if an item to display exists at the coordinates
                local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(bagNum, slotNum))
                if idetail ~= nil then
                    if lfUIWindow ~= nil and lfUIWindow:GetVisible() and lfUIShowSelectedCheckbox:GetChecked() then
                        if LootFilter_Settings ~= nil and LootFilter_Settings.itemsSelected['item:' .. idetail.type] == nil then
                            -- Skip the item since it isn't selected. Do not count it in the bag.
                            goto afterdisplay
                        end
                    end
                    if LootFilter_Settings ~= nil and LootFilter_Settings.autoDeletingItems then
                        if LootFilter_Settings.itemsSelected['item:' .. idetail.type] ~= nil then
                            -- Delete the selected item
                            print("Loot Filter Deleting: " .. idetail.name)
                            Command.Item.Destroy(idetail.id)
                            goto afterdisplay
                        end
                    end
                    -- Item exists, display and update positioning logic
                    
                    if lfUIWindow ~= nil and lfUIWindow:GetVisible() then
                        if displayBagNum == bagNum then
                            displayItem(bagNum, slotNum, 30 + (40 * tempNumColumns), 70 + (40 * numRows))
                            tempNumColumns = tempNumColumns + 1
                            if tempNumColumns == 8 then
                                numRows = numRows + 1
                                tempNumColumns = 0
                            end
                        end
                        numItemsInBag = numItemsInBag + 1
                    end
                end
                ::afterdisplay::
            end

            -- Display the bag (this becomes a button to choose which bag's items to display!)
            if lfUIWindow ~= nil and lfUIWindow:GetVisible() then
                displayItem('bag', bagNum, 30 + (40 * (bagNum-1)), 280, numItemsInBag)
            end
        end
    end
end

-- Automatically updates the Loot Filter inventory
local function slotUpdate(updates)
    local shouldUpdateLootFilter = false
    for slotID,val in pairs(updates) do
        local itemLocation = Utility.Item.Slot.Parse(slotID)
        if itemLocation == 'inventory' then
            shouldUpdateLootFilter = true
        end
    end
    if shouldUpdateLootFilter then
        for k,v in pairs(itemsDisplayed) do
            v:SetVisible(false)
        end
        itemsDisplayed = {}
        displayItemsInBag()
    end
end

-- After a delay, automatically update the Loot Filter inventory if an item has moved around the bags.
local function slotUpdateHandler(eventHandle, updates)
    StartTimer(0.4, slotUpdate, updates)
end

-- the /lf command
local function slashHandler(eventHandle, params)
    if nil == lfUIWindow or not lfUIWindow:GetVisible() then
        if LootFilter_Settings == nil then
            LootFilter_Settings = {}
            LootFilter_Settings.itemsSelected = {} -- items that the user selected
            LootFilter_Settings.autoDeletingItems = false
        end

        -- Create something behind the scenes for stuff to sit on
        local lfUIContext = UI.CreateContext("Loot Filter UI - Context")
        lfUIContext:SetVisible(true)

        -- Create a window
        lfUIWindow = UI.CreateFrame("SimpleWindow", "Loot Filter UI - Window", lfUIContext)
        lfUIWindow:SetVisible(true)
        lfUIWindow:SetCloseButtonVisible(true)
        lfUIWindow:SetTitle("Loot Filter")
        lfUIWindow:SetWidth(380)
        lfUIWindow:SetHeight(400)
        lfUIWindow:SetPoint(
            "TOPLEFT", UIParent, "TOPLEFT",
            (UIParent:GetWidth()/2) - (lfUIWindow:GetWidth()/2),
            (UIParent:GetHeight()/2) - (lfUIWindow:GetHeight()/2)
        )
        lfUIWindow:SetLayer(10)

        -- Reset the displayed state of application when window closes
        lfUIWindow.closeButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            lfUIContext = nil
            lfUIWindow = nil -- the Loot Filter window
            lfUIInventoryFrame = nil -- the Inventory page
            lfUIShowSelectedCheckbox = nil -- the checkbox to show only the selected items
            lfUITooltips = nil -- tooltips
            displayBagNum = 1 -- the bag to display
            itemsDisplayed = {} -- the frames of every item that has been displayed so far
        end, "CloseLeftClick")

        -- Display Only Selected Checkbox
        lfUIShowSelectedCheckbox = UI.CreateFrame("SimpleCheckbox", "Loot Filter UI - Window - Toggle Display Selected Items", lfUIWindow)
        lfUIShowSelectedCheckbox:SetVisible(true)
        lfUIShowSelectedCheckbox:SetText("Display Only Selected Items")
        lfUIShowSelectedCheckbox:SetChecked(false)
        lfUIShowSelectedCheckbox:SetEnabled(not LootFilter_Settings.autoDeletingItems)
        lfUIShowSelectedCheckbox:SetPoint("BOTTOMLEFT", lfUIWindow, "BOTTOMLEFT", 30, -60)
        lfUIShowSelectedCheckbox.check:EventAttach(Event.UI.Checkbox.Change, function(self, h)
            for k,v in pairs(itemsDisplayed) do
                v:SetVisible(false)
            end
            itemsDisplayed = {}
            displayItemsInBag()
        end, "Display Selected Items Checkbox Changed")


        -- Auto Delete Checkbox
        lfUIDeleteSelectedCheckbox = UI.CreateFrame("SimpleCheckbox", "Loot Filter UI - Window - Toggle Deleting Selected Items", lfUIWindow)
        lfUIDeleteSelectedCheckbox:SetVisible(true)
        lfUIDeleteSelectedCheckbox:SetText("Automatically Delete Selected Items")
        lfUIDeleteSelectedCheckbox:SetChecked(LootFilter_Settings.autoDeletingItems)
        lfUIDeleteSelectedCheckbox:SetPoint("BOTTOMLEFT", lfUIWindow, "BOTTOMLEFT", 30, -20)
        lfUIDeleteSelectedCheckbox.check:EventAttach(Event.UI.Checkbox.Change, function(self, h)
            -- If checkbox is selected when we aren't auto deleting
            if lfUIDeleteSelectedCheckbox:GetChecked() and not LootFilter_Settings.autoDeletingItems then
                -- Automatically deselect the checkbox until we're *certain* we want to be
                lfUIDeleteSelectedCheckbox:SetChecked(false)

                -- Create a confirmation window
                local lfUIConfirmAutoDeleteWindow = UI.CreateFrame("SimpleWindow", "Loot Filter UI - Window - Toggle Deleting Selected Items - Confirm Window", lfUIContext)
                lfUIConfirmAutoDeleteWindow:SetVisible(true)
                lfUIConfirmAutoDeleteWindow:SetCloseButtonVisible(true)
                lfUIConfirmAutoDeleteWindow:SetTitle("START DELETING?")
                lfUIConfirmAutoDeleteWindow:SetWidth(380)
                lfUIConfirmAutoDeleteWindow:SetHeight(115)
                lfUIConfirmAutoDeleteWindow:SetPoint(
                    "TOPLEFT", UIParent, "TOPLEFT",
                    (UIParent:GetWidth()/2) - (lfUIConfirmAutoDeleteWindow:GetWidth()/2),
                    (UIParent:GetHeight()/2) - (lfUIConfirmAutoDeleteWindow:GetHeight()/2)
                )
                lfUIConfirmAutoDeleteWindow:SetLayer(20)

                -- Add the Start button
                local lfUIConfirmAutoDeleteStartButton = UI.CreateFrame("RiftButton", "Loot Filter UI - Window - Toggle Deleting Selected Items - Confirm Window - Start Button", lfUIConfirmAutoDeleteWindow)
                lfUIConfirmAutoDeleteStartButton:SetVisible(true)
                lfUIConfirmAutoDeleteStartButton:SetText("Start")
                lfUIConfirmAutoDeleteStartButton:SetPoint("TOPLEFT", lfUIConfirmAutoDeleteWindow, "TOPLEFT", 30, 70)

                -- Add the Cancel button
                local lfUIConfirmAutoDeleteCancelButton = UI.CreateFrame("RiftButton", "Loot Filter UI - Window - Toggle Deleting Selected Items - Confirm Window - Cancel Button", lfUIConfirmAutoDeleteWindow)
                lfUIConfirmAutoDeleteCancelButton:SetVisible(true)
                lfUIConfirmAutoDeleteCancelButton:SetText("Cancel")
                lfUIConfirmAutoDeleteCancelButton:SetPoint("TOPRIGHT", lfUIConfirmAutoDeleteWindow, "TOPRIGHT", -30, 70)


                -- Start auto deleting if clicked
                lfUIConfirmAutoDeleteStartButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
                    -- Automatically disable "show only selected"
                    lfUIShowSelectedCheckbox:SetChecked(false)
                    lfUIShowSelectedCheckbox:SetEnabled(false)

                    -- Remove all confirmation UI
                    lfUIConfirmAutoDeleteStartButton:SetVisible(false)
                    lfUIConfirmAutoDeleteStartButton = nil
                    lfUIConfirmAutoDeleteCancelButton:SetVisible(false)
                    lfUIConfirmAutoDeleteCancelButton = nil
                    lfUIConfirmAutoDeleteWindow:SetVisible(false)
                    lfUIConfirmAutoDeleteWindow = nil

                    -- Start Auto Deleting
                    if LootFilter_Settings ~= nil then
                        LootFilter_Settings.autoDeletingItems = true
                    end

                    -- Checkbox the UI
                    lfUIDeleteSelectedCheckbox:SetChecked(true)
                    
                    -- Trigger a refresh, which starts auto deleting
                    for k,v in pairs(itemsDisplayed) do
                        v:SetVisible(false)
                    end
                    itemsDisplayed = {}
                    displayItemsInBag()
                end, "Start Left Click")

                -- Cancel confirmation, do not auto delete
                lfUIConfirmAutoDeleteCancelButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
                    -- Remove all confirmation UI
                    lfUIConfirmAutoDeleteStartButton:SetVisible(false)
                    lfUIConfirmAutoDeleteStartButton = nil
                    lfUIConfirmAutoDeleteCancelButton:SetVisible(false)
                    lfUIConfirmAutoDeleteCancelButton = nil
                    lfUIConfirmAutoDeleteWindow:SetVisible(false)
                    lfUIConfirmAutoDeleteWindow = nil
                end, "Cancel Left Click")
                
            elseif not lfUIDeleteSelectedCheckbox:GetChecked() then
                -- Ensure we are not auto deleting since we are not checked
                if LootFilter_Settings ~= nil then
                    LootFilter_Settings.autoDeletingItems = false
                end
                -- Re-enable the show only selected checkbox
                lfUIShowSelectedCheckbox:SetEnabled(true)
                    
                -- Trigger a refresh (does nothing once Auto Delete is *ACTUALLY* DELETING)
                for k,v in pairs(itemsDisplayed) do
                    v:SetVisible(false)
                end
                itemsDisplayed = {}
                displayItemsInBag()
            end


        end, "Delete Selected Items Checkbox Changed")

        lfUITooltips = UI.CreateFrame("SimpleTooltip", "Loot Filter UI - Window - Tooltips", lfUIWindow)
    else
        -- Reset the position
        lfUIWindow:SetPoint(
            "TOPLEFT", UIParent, "TOPLEFT",
            (UIParent:GetWidth()/2) - (lfUIWindow:GetWidth()/2),
            (UIParent:GetHeight()/2) - (lfUIWindow:GetHeight()/2)
        )
    end
    displayItemsInBag()
end

-- This is the /idetail debug command's functions. 
local function slashHandlerIDetail(eventHandle, params)
    local sanitizedArgs = string.split(string.lower(string.trim(params)), "%s+", true)
    if #sanitizedArgs == 2 then
        if -- User wants to display a specific item in a specific bag?
            tonumber(sanitizedArgs[1]) ~= nil
            and tonumber(sanitizedArgs[1]) > 0
            and tonumber(sanitizedArgs[2]) ~= nil
            and tonumber(sanitizedArgs[2]) > 0
        then
            local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(tonumber(sanitizedArgs[1]), tonumber(sanitizedArgs[2])))
            if idetail ~= nil then
                print("===")
                for k,v in pairs(idetail) do
                    print(tostring(k) .. ": " .. tostring(v))
                end
                print("===")
            else
                print("No item in this slot!")
            end
        elseif -- User wants to display information about a specific bag?
            sanitizedArgs[1] == 'bag'
            and tonumber(sanitizedArgs[2]) ~= nil
            and tonumber(sanitizedArgs[2]) > 0
        then
            local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(sanitizedArgs[1], tonumber(sanitizedArgs[2])))
            if idetail ~= nil then
                print("===")
                for k,v in pairs(idetail) do
                    print(tostring(k) .. ": " .. tostring(v))
                end
                print("===")
            else
                print("No bag in this slot!")
            end
        end
    elseif -- User wants to inspect all items in a bag?
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
                idetail = Inspect.Item.Detail(ikey) -- Get the current item details.
                print(idetail.name .. ": " .. ikey .. " | " .. ival .. " | " .. bagSlot .. " | " .. itemSlot)
            end
        end
    else -- Display all items in the entire inventory to the user
        for ikey,ival in pairs(Inspect.Item.List()) do
            -- Does not apply to empty inventory slots.
            -- Only applies to items in your inventory, NOT the banks / etc.
            local itemLocation,bagSlot,itemSlot = Utility.Item.Slot.Parse(ikey)
            if(
                ival ~= false 
                and itemLocation == 'inventory'
            ) then
                idetail = Inspect.Item.Detail(ikey) -- Get the current item details.
                print(idetail.name .. ": " .. ikey .. " | " .. ival .. " | " .. bagSlot .. " | " .. itemSlot)
            end
        end
    end
end

-- This is the /lfnull debug command. It removes the configuration of the loot filter.
local function slashHandlerNull(eventHandle, params)
    LootFilter_Settings = {}
    LootFilter_Settings.itemsSelected = {} -- items that the user selected
    LootFilter_Settings.autoDeletingItems = false

    if lfUIWindow ~= nil and lfUIWindow:GetVisible() then
        lfUIShowSelectedCheckbox:SetChecked(false)
        lfUIShowSelectedCheckbox:SetEnabled(true)

        lfUIDeleteSelectedCheckbox:SetChecked(false)
        
        for k,v in pairs(itemsDisplayed) do
            v:SetVisible(false)
        end
        itemsDisplayed = {}
        displayItemsInBag()
    end
    print("Nullified all saved Loot Filter settings on this character.")
end

Command.Event.Attach(Command.Slash.Register("lf"), slashHandler, "LootFilter")
Command.Event.Attach(Command.Slash.Register("lfnull"), slashHandlerNull, "LootFilterNullify")
Command.Event.Attach(Command.Slash.Register("idetail"), slashHandlerIDetail, "ItemDetailDebugger")
Command.Event.Attach(Event.Item.Slot, slotUpdateHandler, "SlotUpdatedSomewhere")
Command.Event.Attach(Event.Item.Update, slotUpdateHandler, "ItemUpdatedSomewhere")
