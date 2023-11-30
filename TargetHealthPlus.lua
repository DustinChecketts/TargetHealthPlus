-- Define a table to hold different status text display modes
STATUS_TEXT_DISPLAY_MODE = {
    NUMERIC = "NUMERIC",
    PERCENT = "PERCENT",
    BOTH = "BOTH",
    NONE = "NONE",
}

-- Set up HP (Health Points) text for the target frame
local layerHP = "BORDER"

-- Create font strings for HP text at different positions
TargetFrameTextureFrame:CreateFontString("TargetFrameHealthBarText", layerHP, "TextStatusBarText")
TargetFrameHealthBarText:SetPoint("CENTER", TargetFrameTextureFrame, "CENTER", -50, 3)

TargetFrameTextureFrame:CreateFontString("TargetFrameHealthBarTextLeft", layerHP, "TextStatusBarText")
TargetFrameHealthBarTextLeft:SetPoint("LEFT", TargetFrameTextureFrame, "LEFT", 8, 3)

TargetFrameTextureFrame:CreateFontString("TargetFrameHealthBarTextRight", layerHP, "TextStatusBarText")
TargetFrameHealthBarTextRight:SetPoint("RIGHT", TargetFrameTextureFrame, "RIGHT", -110, 3)

-- Set up Mana text for the target frame
local layerMana = "BORDER"

-- Create font strings for Mana text at different positions
TargetFrameTextureFrame:CreateFontString("TargetFrameManaBarText", layerMana, "TextStatusBarText")
TargetFrameManaBarText:SetPoint("CENTER", TargetFrameTextureFrame, "CENTER", -50, -8)

TargetFrameTextureFrame:CreateFontString("TargetFrameManaBarTextLeft", layerMana, "TextStatusBarText")
TargetFrameManaBarTextLeft:SetPoint("LEFT", TargetFrameTextureFrame, "LEFT", 8, -8)

TargetFrameTextureFrame:CreateFontString("TargetFrameManaBarTextRight", layerMana, "TextStatusBarText")
TargetFrameManaBarTextRight:SetPoint("RIGHT", TargetFrameTextureFrame, "RIGHT", -110, -8)

-- Set the status text for HP and Mana bars
TargetFrameHealthBar.LeftText = TargetFrameHealthBarTextLeft
TargetFrameHealthBar.RightText = TargetFrameHealthBarTextRight
TargetFrameManaBar.LeftText = TargetFrameManaBarTextLeft
TargetFrameManaBar.RightText = TargetFrameManaBarTextRight

-- Initialize the unit frame health and mana bars for the target frame
UnitFrameHealthBar_Initialize("target", TargetFrameHealthBar, TargetFrameHealthBarText, true)
UnitFrameManaBar_Initialize("target", TargetFrameManaBar, TargetFrameManaBarText, true)

-- Function to update the text string with values for a status frame
local function TextStatusBar_UpdateTextStringWithValues(statusFrame, textString, value, valueMin, valueMax)
    if (statusFrame.LeftText and statusFrame.RightText) then
        -- Clear and hide left and right text if they exist
        statusFrame.LeftText:SetText("")
        statusFrame.RightText:SetText("")
        statusFrame.LeftText:Hide()
        statusFrame.RightText:Hide()
    end

    -- Check if max value is valid and updates aren't paused
    if ((tonumber(valueMax) ~= valueMax or valueMax > 0) and not (statusFrame.pauseUpdates)) then
        statusFrame:Show()

        -- Check conditions to show or hide text based on configuration
        if ((statusFrame.cvar and GetCVar(statusFrame.cvar) == "1" and statusFrame.textLockable) or statusFrame.forceShow) then
            textString:Show()
        elseif (statusFrame.lockShow > 0 and (not statusFrame.forceHideText)) then
            textString:Show()
        else
            textString:SetText("")
            textString:Hide()
            return
        end

        -- Display zero text if value is 0 and zero text is defined
        if (value == 0 and statusFrame.zeroText) then
            textString:SetText(statusFrame.zeroText)
            statusFrame.isZero = 1
            textString:Show()
            return
        end

        statusFrame.isZero = nil

        local valueDisplay = value
        local valueMaxDisplay = valueMax

        -- Apply custom text transform function if provided, otherwise use default large number handling
        if (statusFrame.numericDisplayTransformFunc) then
            valueDisplay, valueMaxDisplay = statusFrame.numericDisplayTransformFunc(value, valueMax)
        else
            valueDisplay = AbbreviateLargeNumbers(value)
            valueMaxDisplay = AbbreviateLargeNumbers(valueMax)
        end

        local shouldUsePrefix = statusFrame.prefix and
            (statusFrame.alwaysPrefix or not (statusFrame.cvar and GetCVar(statusFrame.cvar) == "1" and statusFrame.textLockable))

        local displayMode = GetCVar("statusTextDisplay")

        if (statusFrame.showNumeric) then
            displayMode = STATUS_TEXT_DISPLAY_MODE.NUMERIC
        end

        -- If percent-only mode and percentages are disabled, fall back on numeric-only
        if (statusFrame.disablePercentages and displayMode == STATUS_TEXT_DISPLAY_MODE.PERCENT) then
            displayMode = STATUS_TEXT_DISPLAY_MODE.NUMERIC
        end

        -- Numeric only
        if (valueMax <= 0 or displayMode == STATUS_TEXT_DISPLAY_MODE.NUMERIC or displayMode == STATUS_TEXT_DISPLAY_MODE.NONE) then
            if (shouldUsePrefix) then
                textString:SetText(statusFrame.prefix .. " " .. valueDisplay .. " / " .. valueMaxDisplay)
            else
                textString:SetText(valueDisplay .. " / " .. valueMaxDisplay)
            end
        -- Numeric + Percentage
        elseif (displayMode == STATUS_TEXT_DISPLAY_MODE.BOTH) then
            if (statusFrame.LeftText and statusFrame.RightText) then
                -- Unless explicitly disabled, only display percentage on left if displaying mana or a non-power value
                if (not statusFrame.disablePercentages and (not statusFrame.powerToken or statusFrame.powerToken == "MANA")) then
                    statusFrame.LeftText:SetText(math.ceil((value / valueMax) * 100) .. "%")
                    statusFrame.LeftText:Show()
                end
                statusFrame.RightText:SetText(valueDisplay)
                statusFrame.RightText:Show()
                textString:Hide()
            else
                valueDisplay = valueDisplay .. " / " .. valueMaxDisplay
                if (not statusFrame.disablePercentages) then
                    valueDisplay = "(" .. math.ceil((value / valueMax) * 100) .. "%) " .. valueDisplay
                end
            end
            textString:SetText(valueDisplay)
        -- Percentage Only
        elseif (displayMode == STATUS_TEXT_DISPLAY_MODE.PERCENT) then
            valueDisplay = math.ceil((value / valueMax) * 100) .. "%"
            if (shouldUsePrefix) then
                textString:SetText(statusFrame.prefix .. " " .. valueDisplay)
            else
                textString:SetText(valueDisplay)
            end
        end
    -- Max value is invalid or updates are paused
    else
        textString:Hide()
        textString:SetText("")
        if (not statusFrame.alwaysShow) then
            statusFrame:Hide()
        else
            statusFrame:SetValue(0)
        end
    end
end

-- Hook the function to update text values for status bars
hooksecurefunc("TextStatusBar_UpdateTextStringWithValues", TextStatusBar_UpdateTextStringWithValues)
