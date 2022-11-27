local addon, LF = ...

if LF.UI == nil then
    LF.UI = {}
end
LF.UI.CurrentlyEquippedWarning = {}
LF.UI.CurrentlyEquippedWarning.Window = nil -- the window to alert that a selected item is currently equipped
LF.UI.CurrentlyEquippedWarning.EquippedWarningTextSubtitle = nil -- the text to warn the user that a selected item is currently equipped
LF.UI.CurrentlyEquippedWarning.EquippedWarningTextImplications = nil -- the text to warn the user why it's bad that that a selected item is currently equipped
LF.UI.CurrentlyEquippedWarning.OKButton = nil -- the OK button to close the window

-- Currently equipped warning window
LF.UI.CurrentlyEquippedWarning.CreateCurrentlyEquippedWarningWindow = function()
    -- Create a hidden confirmation window
    if LF.UI.CurrentlyEquippedWarning.Window == nil then
        LF.UI.CurrentlyEquippedWarning.Window = UI.CreateFrame('SimpleWindow', 'LF.UI.CurrentlyEquippedWarning.Window', LF.UI.General.Context)
        LF.UI.CurrentlyEquippedWarning.Window:SetCloseButtonVisible(true)
        LF.UI.CurrentlyEquippedWarning.Window.closeButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            -- Remove all warning UI
            LF.UI.CurrentlyEquippedWarning.EquippedWarningTextSubtitle:SetVisible(false)
            LF.UI.CurrentlyEquippedWarning.EquippedWarningTextImplications:SetVisible(false)
            LF.UI.CurrentlyEquippedWarning.OKButton:SetVisible(false)
            LF.UI.CurrentlyEquippedWarning.Window:SetVisible(false)
        end, 'CloseLeftClick')
    end
    LF.UI.CurrentlyEquippedWarning.Window:SetVisible(true)
    LF.UI.CurrentlyEquippedWarning.Window:SetTitle('WARNING - CURRENTLY EQUIPPED!')
    LF.UI.CurrentlyEquippedWarning.Window:SetWidth(600)
    LF.UI.CurrentlyEquippedWarning.Window:SetHeight(135)
    LF.UI.CurrentlyEquippedWarning.Window:SetLayer(20)

    -- Put the warning window to the middle of the screen
    LF.UI.CurrentlyEquippedWarning.Window:SetPoint(
        'TOPLEFT', UIParent, 'TOPLEFT',
        (UIParent:GetWidth()/2) - (LF.UI.CurrentlyEquippedWarning.Window:GetWidth()/2),
        (UIParent:GetHeight()/2) - (LF.UI.CurrentlyEquippedWarning.Window:GetHeight()/2)
    )

    -- Text disclaimer to inform the user that a currently equipped item was selected
    if LF.UI.CurrentlyEquippedWarning.EquippedWarningTextSubtitle == nil then
        LF.UI.CurrentlyEquippedWarning.EquippedWarningTextSubtitle = UI.CreateFrame('Text', 'LF.UI.CurrentlyEquippedWarning.EquippedWarningTextSubtitle', LF.UI.CurrentlyEquippedWarning.Window)
    end
    LF.UI.CurrentlyEquippedWarning.EquippedWarningTextSubtitle:SetVisible(true)
    LF.UI.CurrentlyEquippedWarning.EquippedWarningTextSubtitle:SetFontSize(14)
    LF.UI.CurrentlyEquippedWarning.EquippedWarningTextSubtitle:SetPoint('TOPCENTER', LF.UI.CurrentlyEquippedWarning.Window, 'TOPCENTER', 0, 50)
    LF.UI.CurrentlyEquippedWarning.EquippedWarningTextSubtitle:SetText('Gear that was selected in this bag is also currently equipped by the character!')

    -- Text disclaimer to inform the user why it's bad that that a selected item is currently equipped
    if LF.UI.CurrentlyEquippedWarning.EquippedWarningTextImplications == nil then
        LF.UI.CurrentlyEquippedWarning.EquippedWarningTextImplications = UI.CreateFrame('Text', 'LF.UI.CurrentlyEquippedWarning.EquippedWarningTextImplications', LF.UI.CurrentlyEquippedWarning.Window)
    end
    LF.UI.CurrentlyEquippedWarning.EquippedWarningTextImplications:SetVisible(true)
    LF.UI.CurrentlyEquippedWarning.EquippedWarningTextImplications:SetFontSize(14)
    LF.UI.CurrentlyEquippedWarning.EquippedWarningTextImplications:SetPoint('TOPCENTER', LF.UI.CurrentlyEquippedWarning.Window, 'TOPCENTER', 0, 72)
    LF.UI.CurrentlyEquippedWarning.EquippedWarningTextImplications:SetText('If you begin auto deleting, unequipping that version of the gear WILL auto delete it!')

    -- Add the OK button
    if LF.UI.CurrentlyEquippedWarning.OKButton == nil then
        LF.UI.CurrentlyEquippedWarning.OKButton = UI.CreateFrame('RiftButton', 'LF.UI.CurrentlyEquippedWarning.OKButton', LF.UI.CurrentlyEquippedWarning.Window)
        -- Close window once OK is clicked
        LF.UI.CurrentlyEquippedWarning.OKButton:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
            -- Remove all warning UI
            LF.UI.CurrentlyEquippedWarning.EquippedWarningTextSubtitle:SetVisible(false)
            LF.UI.CurrentlyEquippedWarning.EquippedWarningTextImplications:SetVisible(false)
            LF.UI.CurrentlyEquippedWarning.OKButton:SetVisible(false)
            LF.UI.CurrentlyEquippedWarning.Window:SetVisible(false)
        end, 'Start Left Click')
    end
    LF.UI.CurrentlyEquippedWarning.OKButton:SetVisible(true)
    LF.UI.CurrentlyEquippedWarning.OKButton:SetText('OK')
    LF.UI.CurrentlyEquippedWarning.OKButton:SetPoint('BOTTOMCENTER', LF.UI.CurrentlyEquippedWarning.Window, 'BOTTOMCENTER', 0, -11)
end

