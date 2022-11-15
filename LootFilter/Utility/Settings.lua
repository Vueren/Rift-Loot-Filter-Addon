local addon, LF = ...

LF.Settings = {}

LF.Settings.PushUpdatesToSavedVariables = function()
    LootFilter_Settings = {}
    LootFilter_Settings.LockedItems = LF.Settings.LockedItems -- items that the user NEVER wants deleted
    LootFilter_Settings.SelectedItems = LF.Settings.SelectedItems -- items that the user selected
    LootFilter_Settings.AutoDeleting = LF.Settings.AutoDeleting -- flag for whether or not to auto delete
    LootFilter_Settings.TotalItemsDeleted = LF.Settings.TotalItemsDeleted -- total number of items deleted by the addon (including stack count)
    LootFilter_Settings.DisplayRarity = LF.Settings.DisplayRarity -- display the rarity of the item in the config window
    LootFilter_Settings.DisplayChat = LF.Settings.DisplayChat -- display the chat of deletions of items
    LootFilter_Settings.PreventDeletion = LF.Settings.PreventDeletion -- ultimately prevents the deletion, allowing users to try and see how the addon works
    LootFilter_Settings.AutoSelectGreyItems = LF.Settings.AutoSelectGreyItems -- automatically selects all Grey-tier items (Sellable according to the Addon API)
end

-- Handles migrations from earlier versions of the addon
LF.Settings.InitializeFromSavedVariables = function(_, addonidentifier)
    if addonidentifier == 'LootFilter' then
        if LootFilter_Settings == nil then
            LootFilter_Settings = {}
        end
        -- Migrate from Beta v0.8, or initialize state
        if LootFilter_Settings.LockedItems == nil then
            LF.Settings.LockedItems = {} -- items that the user NEVER wants deleted
        end
        if LootFilter_Settings.SelectedItems == nil then
            LF.Settings.SelectedItems = {} -- items that the user selected
            -- Migrate values from an older version of the addon
            if LootFilter_Settings.itemsSelected ~= nil then
                print('Welcome to a new version of Loot Filter!')
                print('Migrating all previous selected items to a new format...')
                for itemitype,_ in pairs(LootFilter_Settings.itemsSelected) do
                    --print('Migrating: ' .. string.sub(itemitype, 6, -1))
                    local function migrateItemDetail(itemitype)
                        local idetail = Inspect.Item.Detail(string.sub(itemitype, 6, -1))
                        -- Add new details that were not previously present in the older version of the addon
                        LF.Settings.SelectedItems[idetail.type] = {
                            name = idetail.name,
                            icon = idetail.icon,
                            rarity = idetail.rarity
                        }
                    end
                    -- if ANY error was thrown retrieving old item data...
                    if not pcall(migrateItemDetail, itemitype) then
                        -- just migrate the value as-is (true) and fill out the details later when the item is found again
                        LF.Settings.SelectedItems[itemitype] = true
                    end
                end
                LootFilter_Settings.itemsSelected = nil
                print('Done!')
            end
        end
        if LootFilter_Settings.AutoDeleting == nil then
            LF.Settings.AutoDeleting = false -- flag for whether or not to auto delete

            -- Remove a value from an older version of the addon
            if LootFilter_Settings.autoDeletingItems ~= nil then
                if LootFilter_Settings.autoDeletingItems then
                    print('Auto Deletion has been disabled as a result of the addon version migration!')
                    print('Please type /lf to confirm selected items and re-enable Auto Deletion!')
                end
                LF.Settings.autoDeletingItems = nil
            end
        end
        if LootFilter_Settings.TotalItemsDeleted == nil then
            LF.Settings.TotalItemsDeleted = 0 -- total number of items deleted by the addon (including stack count)
        end
        if LootFilter_Settings.DisplayRarity == nil then
            LF.Settings.DisplayRarity = true -- display the rarity of the item in the config window
        end
        if LootFilter_Settings.DisplayChat == nil then
            LF.Settings.DisplayChat = true -- display the chat of deletions of items
        end
        if LootFilter_Settings.PreventDeletion == nil then
            LF.Settings.PreventDeletion = false -- ultimately prevents the deletion, allowing users to try and see how the addon works
        end
        if LootFilter_Settings.AutoSelectGreyItems == nil then
            LF.Settings.AutoSelectGreyItems = false -- automatically selects all Grey-tier items (Sellable according to the Addon API)
        end
        

        -- Import settings from SavedVariables if they exist
        if LootFilter_Settings.LockedItems ~= nil then
            LF.Settings.LockedItems = LootFilter_Settings.LockedItems -- items that the user NEVER wants deleted
        end
        if LootFilter_Settings.SelectedItems ~= nil then
            LF.Settings.SelectedItems = LootFilter_Settings.SelectedItems -- items that the user selected
        end
        if LootFilter_Settings.AutoDeleting ~= nil then
            LF.Settings.AutoDeleting = LootFilter_Settings.AutoDeleting -- flag for whether or not to auto delete
        end
        if LootFilter_Settings.TotalItemsDeleted ~= nil then
            LF.Settings.TotalItemsDeleted = LootFilter_Settings.TotalItemsDeleted -- total number of items deleted by the addon (including stack count)
        end
        if LootFilter_Settings.DisplayRarity ~= nil then
            LF.Settings.DisplayRarity = LootFilter_Settings.DisplayRarity -- display the rarity of the item in the config window
        end
        if LootFilter_Settings.DisplayChat ~= nil then
            LF.Settings.DisplayChat = LootFilter_Settings.DisplayChat -- display the chat of deletions of items
        end
        if LootFilter_Settings.PreventDeletion ~= nil then
            LF.Settings.PreventDeletion = LootFilter_Settings.PreventDeletion -- ultimately prevents the deletion, allowing users to try and see how the addon works
        end
        if LootFilter_Settings.AutoSelectGreyItems ~= nil then
            LF.Settings.AutoSelectGreyItems = LootFilter_Settings.AutoSelectGreyItems -- automatically selects all Grey-tier items (Sellable according to the Addon API)
        end
        
        print('Loot Filter ready!')
        if LF.Settings.AutoDeleting then
            print('Loot Filter is currently Auto Deleting on this character!')
        end
    end
end

Command.Event.Attach(Event.Addon.SavedVariables.Load.End, LF.Settings.InitializeFromSavedVariables, 'LootFilterSavedVariablesLoaded')