local addon, LF = ...

if LF.UI == nil then
    LF.UI = {}
end
LF.UI.AutoDeleteConfirmation = {}
LF.UI.AutoDeleteConfirmation.Window = nil -- the window to confirm enabling Auto Delete
LF.UI.AutoDeleteConfirmation.NumItemsText = nil -- the number of items to delete
LF.UI.AutoDeleteConfirmation.StartButton = nil -- the Start auto deleting button
LF.UI.AutoDeleteConfirmation.CancelButton = nil -- the Cancel confirm auto deleting button

LF.UI.AutoDeleteConfirmation.UpdateDeletionConfirmationText = function()
    local totalSelectedItemsInInventory = tostring(LF.Utility.GetNumberOfSelectedItemsInInventory())
    if LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText ~= nil then
        -- Update the text with the new totalSelectedItemsInInventory value
        LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText:SetPoint('TOPLEFT', LF.UI.AutoDeleteConfirmation.Window, 'TOPLEFT', 62 - math.floor(5 * string.len(totalSelectedItemsInInventory)), 42)
        LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText:SetText('# of items that will be deleted right now: ' .. totalSelectedItemsInInventory)
    end
end


-- Auto Delete confirmation window
LF.UI.AutoDeleteConfirmation.CreateConfirmAutoDeleteWindow = function()
    -- Create a hidden confirmation window
    if LF.UI.AutoDeleteConfirmation.Window == nil then
        LF.UI.AutoDeleteConfirmation.Window = UI.CreateFrame('SimpleWindow', 'LF.UI.AutoDeleteConfirmation.Window', LF.UI.General.Context)
        LF.UI.AutoDeleteConfirmation.Window:SetCloseButtonVisible(true)
        LF.UI.AutoDeleteConfirmation.Window.closeButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            -- Re-enable the show selected checkbox
            LF.UI.InventoryConfig.ShowSelectedCheckbox:SetEnabled(true)
        end, 'CloseLeftClick')
    end
    LF.UI.AutoDeleteConfirmation.Window:SetVisible(false)
    LF.UI.AutoDeleteConfirmation.Window:SetTitle('START DELETING?')
    LF.UI.AutoDeleteConfirmation.Window:SetWidth(380)
    LF.UI.AutoDeleteConfirmation.Window:SetHeight(115)
    LF.UI.AutoDeleteConfirmation.Window:SetLayer(20)

    -- Text disclaimer to inform the user how to save their changes
    if LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText == nil then
        LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText = UI.CreateFrame('Text', 'LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText', LF.UI.AutoDeleteConfirmation.Window)
    end
    LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText:SetVisible(false)
    LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText:SetFontSize(14)

    -- Add the Start button
    if LF.UI.AutoDeleteConfirmation.StartButton == nil then
        LF.UI.AutoDeleteConfirmation.StartButton = UI.CreateFrame('RiftButton', 'LF.UI.AutoDeleteConfirmation.StartButton', LF.UI.AutoDeleteConfirmation.Window)
        -- Start auto deleting if confirm is clicked
        LF.UI.AutoDeleteConfirmation.StartButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            -- Automatically disable 'show only selected'
            LF.UI.InventoryConfig.ShowSelectedCheckbox:SetChecked(false)
            LF.UI.InventoryConfig.ShowSelectedCheckbox:SetEnabled(false)

            -- Remove all confirmation UI
            LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText:SetVisible(false)
            LF.UI.AutoDeleteConfirmation.StartButton:SetVisible(false)
            LF.UI.AutoDeleteConfirmation.CancelButton:SetVisible(false)
            LF.UI.AutoDeleteConfirmation.Window:SetVisible(false)

            -- Start Auto Deleting
            LF.Settings.AutoDeleting = true
            LF.Settings.PushUpdatesToSavedVariables()

            -- Checkbox the UI
            LF.UI.InventoryConfig.DeleteSelectedCheckbox:SetChecked(true)

            -- Trigger a redisplay, which starts auto deleting
            LF.UI.InventoryConfig.RedisplayInventory(true)
        end, 'Start Left Click')
    end
    LF.UI.AutoDeleteConfirmation.StartButton:SetVisible(false)
    LF.UI.AutoDeleteConfirmation.StartButton:SetText('Start')
    LF.UI.AutoDeleteConfirmation.StartButton:SetPoint('TOPLEFT', LF.UI.AutoDeleteConfirmation.Window, 'TOPLEFT', 30, 70)

    -- Add the Cancel button
    if LF.UI.AutoDeleteConfirmation.CancelButton == nil then
        LF.UI.AutoDeleteConfirmation.CancelButton = UI.CreateFrame('RiftButton', 'LF.UI.AutoDeleteConfirmation.CancelButton', LF.UI.AutoDeleteConfirmation.Window)
        -- Cancel confirmation, do not auto delete
        LF.UI.AutoDeleteConfirmation.CancelButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            -- Remove all confirmation UI
            LF.UI.AutoDeleteConfirmation.ConfirmNumItemsText:SetVisible(false)
            LF.UI.AutoDeleteConfirmation.StartButton:SetVisible(false)
            LF.UI.AutoDeleteConfirmation.CancelButton:SetVisible(false)
            LF.UI.AutoDeleteConfirmation.Window:SetVisible(false)
            -- Re-enable the show selected checkbox
            LF.UI.InventoryConfig.ShowSelectedCheckbox:SetEnabled(true)
            LF.UI.InventoryConfig.RedisplayInventory()
        end, 'Cancel Left Click')
    end
    LF.UI.AutoDeleteConfirmation.CancelButton:SetVisible(false)
    LF.UI.AutoDeleteConfirmation.CancelButton:SetText('Cancel')
    LF.UI.AutoDeleteConfirmation.CancelButton:SetPoint('TOPRIGHT', LF.UI.AutoDeleteConfirmation.Window, 'TOPRIGHT', -30, 70)
end

