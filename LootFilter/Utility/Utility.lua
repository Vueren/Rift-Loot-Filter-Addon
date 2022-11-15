local addon, LF = ...

LF.Utility = {}

LF.Utility.LastUpdateServerTime = 0 -- Used to ensure the auto delete function only runs after a certain amount of time has passed since the last inventory update
LF.Utility.SlotUpdates = nil -- Used to store the inventory updates
LF.Utility.TotalSelectedItemsInInventory = 0 -- Used to display the number of items that will be deleted on the first pass of the Loot Filter's auto delete

-- Obtains the colors based on an idetail's rarity property
LF.Utility.GetColors = function(idetail)
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

-- Returns the number of selected items in the inventory
LF.Utility.GetNumberOfSelectedItemsInInventory = function()
    -- Accumulator variable
    local numItems = 0
    
    -- Loop through the possible bags:
    for bagNum = 1, 8 do
        -- Check if the bag exists:
        local bag = Inspect.Item.Detail(Utility.Item.Slot.Inventory('bag', bagNum))
        if bag ~= nil then
            -- Loop through the items in the bag:
            for slotNum = 1, bag.slots do
                -- Determine if an item to display exists at the coordinates:
                local idetail = Inspect.Item.Detail(Utility.Item.Slot.Inventory(bagNum, slotNum))
                if idetail ~= nil then
                    -- Item exists
                    -- If the item is Selected and not Locked:
                    if LF.Settings.SelectedItems[idetail.type] ~= nil and LF.Settings.LockedItems[idetail.type] == nil then
                        numItems = numItems + 1
                    end
                end
            end
        end
    end

    -- Return number
    return numItems
end

-- Deletes the item if permitted. Returns true if item was deleted.
LF.Utility.DeleteItem = function(idetail)
    if LF.Settings.AutoDeleting then
        -- If the item is an item to auto delete
        if
            LF.Settings.SelectedItems[idetail.type] ~= nil
            and LF.Settings.LockedItems[idetail.type] == nil
        then
            -- Delete the selected item
            if LF.Settings.PreventDeletion == false then
                if LF.Settings.DisplayChat then
                    Command.Console.Display('general', true, 'Loot Filter Deleting: ' .. idetail.name, false)
                end
                Command.Item.Destroy(idetail.id)
            else
                if LF.Settings.DisplayChat then
                    Command.Console.Display('general', true, 'Loot Filter Simulating Deleting: ' .. idetail.name, false)
                end
            end
            if idetail.stack ~= nil then
                LF.Settings.TotalItemsDeleted = LF.Settings.TotalItemsDeleted + idetail.stack
            else
                LF.Settings.TotalItemsDeleted = LF.Settings.TotalItemsDeleted + 1
            end
            LF.Settings.PushUpdatesToSavedVariables()
            return true
        end
    end
    return false
end

-- Automatically updates the Loot Filter inventory with changes in the real inventory
-- Also triggers the destruction logic in RedisplayInventory
-- - Requires a full 5 seconds since the last time the inventory was left untouched!
-- - This guarantees that all items are in their slot when the addon makes its pass!
-- - Before then, DO NOT auto delete! Just update the UI.
LF.Utility.SlotUpdate = function()
    -- Check every half second if it has been 5 seconds yet
    if Inspect.Time.Server() <= LF.Utility.LastUpdateServerTime + 5 then
        StartTimer(0.5, LF.Utility.SlotUpdate)
    else
        -- 5 seconds has passed
        LF.Utility.LastUpdateServerTime = 0
        LF.UI.InventoryConfig.RedisplayInventory(true)
    end

    if LF.Utility.SlotUpdates ~= nil then
        -- Update the loot filter's inventory display if there are updates to display
        LF.UI.InventoryConfig.RedisplayInventory()
        LF.Utility.SlotUpdates = nil
    end
end

-- After a delay, automatically update the Loot Filter inventory if an item has moved around the bags.
LF.Utility.SlotUpdateHandler = function(_, updates)
    if LF.Utility.SlotUpdates == nil then
        LF.Utility.SlotUpdates = {}
    end
    for slotID,v in pairs(updates) do
        LF.Utility.SlotUpdates[slotID] = v
    end
    -- Ensure that only one slotUpdate function is running at any given time
    if LF.Utility.LastUpdateServerTime == 0 then
        StartTimer(0.5, LF.Utility.SlotUpdate)
    end
    LF.Utility.LastUpdateServerTime = Inspect.Time.Server()
end


-- the /lf command
LF.Utility.SlashHandler = function(_, params)
    local sanitizedArgs = string.split(string.lower(string.trim(params)), '%s+', true)
    local function printSettings()
        print('===')
        print('Loot Filter settings:')
        print('===')
        print('[Auto Deleting]: ' .. tostring(LF.Settings.AutoDeleting))
        if LF.Settings.AutoDeleting then
            print('- Loot Filter is currently automatically deleting selected items')
        else
            print('- Loot Filter is not automatically deleting items at this time')
        end
        print('===')
        print('[Display Rarity]: ' .. tostring(LF.Settings.DisplayRarity))
        print('- /lf toggle rarity')
        if LF.Settings.DisplayRarity then
            print('- Rarity indicators are being displayed in the Loot Filter config window')
        else
            print('- Rarity indicators are hidden in the Loot Filter config window')
        end
        print('===')
        print('[Display Chat]: ' .. tostring(LF.Settings.DisplayChat))
        print('- /lf toggle chat')
        if LF.Settings.DisplayChat then
            print('- Chat messages are being displayed whenever deletions occur')
        else
            print('- Chat messages are hidden whenever deletions occur')
        end
        print('===')
        print('[Prevent Deletion]: ' .. tostring(LF.Settings.PreventDeletion))
        print('- /lf toggle prevent')
        if LF.Settings.PreventDeletion then
            if LF.Settings.AutoDeleting then
                print('- Automatic deletions are being prevented at the last moment')
            else
                print('- Automatic deletions would be prevented if Auto Deleting was enabled')
            end
        else
            if LF.Settings.AutoDeleting then
                print('- Automatic deletions are allowed when they occur')
            else
                print('- Automatic deletions would be allowed if Auto Deleting was enabled')
            end
        end
        print('===')
        print('[Auto Select Grey Items]: ' .. tostring(LF.Settings.AutoSelectGreyItems))
        print('- /lf toggle grey')
        if LF.Settings.AutoSelectGreyItems then
            if LF.Settings.AutoDeleting then
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
                LF.Settings.DisplayRarity = not LF.Settings.DisplayRarity
                LF.Settings.PushUpdatesToSavedVariables()
                print('Display Rarity setting is now set to: ' .. tostring(LF.Settings.DisplayRarity))
                LF.UI.InventoryConfig.RedisplayInventory()
            elseif sanitizedArgs[2] == 'chat' then
                LF.Settings.DisplayChat = not LF.Settings.DisplayChat
                LF.Settings.PushUpdatesToSavedVariables()
                print('Display Chat setting is now set to: ' .. tostring(LF.Settings.DisplayChat))
            elseif sanitizedArgs[2] == 'prevent' then
                LF.Settings.PreventDeletion = not LF.Settings.PreventDeletion
                LF.Settings.PushUpdatesToSavedVariables()
                print('Prevent Deletion setting is now set to: ' .. tostring(LF.Settings.PreventDeletion))
            elseif sanitizedArgs[2] == 'grey' or sanitizedArgs[2] == 'gray' then
                LF.Settings.AutoSelectGreyItems = not LF.Settings.AutoSelectGreyItems
                LF.Settings.PushUpdatesToSavedVariables()
                print('Auto Select Grey Items setting is now set to: ' .. tostring(LF.Settings.AutoSelectGreyItems))
                LF.UI.InventoryConfig.RedisplayInventory()
            else
                printHelp()
            end
        elseif sanitizedArgs[1] == 'settings' then
            printSettings()
        elseif sanitizedArgs[1] == 'config' then
            LF.UI.InventoryConfig.DisplayConfigWindow()
        elseif sanitizedArgs[1] == 'selected' then
            LF.UI.SelectedItemsConfig.DisplayViewSelectedWindow()
            if LF.UI.InventoryConfig.Window ~= nil then
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
            end
        else
            printHelp()
        end
    else
        LF.UI.InventoryConfig.DisplayConfigWindow()
    end
end

-- This is the /idetail debug command's functions.
LF.Utility.SlashHandlerIDetail = function(_, params)
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
LF.Utility.SlashHandlerNull = function(_, params)
    LF.Settings = {}
    LF.Settings.LockedItems = {}
    LF.Settings.SelectedItems = {}
    LF.Settings.AutoDeleting = false
    LF.Settings.AutoSelectGreyItems = false
    LF.Settings.TotalItemsDeleted = 0
    LF.Settings.DisplayRarity = true
    LF.Settings.DisplayChat = true
    LF.Settings.PreventDeletion = false

    if LF.UI.InventoryConfig.Window ~= nil and LF.UI.InventoryConfig.Window:GetVisible() == true then
        LF.UI.InventoryConfig.ShowSelectedCheckbox:SetChecked(false)
        LF.UI.InventoryConfig.ShowSelectedCheckbox:SetEnabled(true)

        LF.UI.InventoryConfig.DeleteSelectedCheckbox:SetChecked(false)

        LF.UI.InventoryConfig.RedisplayInventory()
    end

    LF.Settings.PushUpdatesToSavedVariables()
    print('Nullified all saved Loot Filter settings on this character.')
    print('Please use the /reloadui command now :)')
end


Command.Event.Attach(Command.Slash.Register('lf'), LF.Utility.SlashHandler, 'LootFilter')
Command.Event.Attach(Command.Slash.Register('lfnull'), LF.Utility.SlashHandlerNull, 'LootFilterNullify')
Command.Event.Attach(Command.Slash.Register('idetail'), LF.Utility.SlashHandlerIDetail, 'ItemDetailDebugger')

Command.Event.Attach(Event.Item.Slot, LF.Utility.SlotUpdateHandler, 'LootFilterSlotUpdatedSomewhere')
Command.Event.Attach(Event.Item.Update, LF.Utility.SlotUpdateHandler, 'LootFilterItemUpdatedSomewhere')