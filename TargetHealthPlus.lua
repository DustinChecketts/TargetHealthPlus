-- TargetHealthPlus (Classic Era 2.5.5)

-- Display modes (compatible with older versions)
STATUS_TEXT_DISPLAY_MODE = STATUS_TEXT_DISPLAY_MODE or {
    NUMERIC = "NUMERIC",
    PERCENT = "PERCENT",
    BOTH    = "BOTH",
    NONE    = "NONE",
}

local ADDON_NAME = ...
local f = CreateFrame("Frame")

local function Abbrev(n)
    if type(AbbreviateLargeNumbers) == "function" then
        return AbbreviateLargeNumbers(n)
    end
    -- Fallback
    if n >= 1e6 then
        return string.format("%.1fm", n / 1e6)
    elseif n >= 1e3 then
        return string.format("%.1fk", n / 1e3)
    end
    return tostring(n)
end

local function GetDisplayMode()
    -- Retail/modern-style CVar is usually "statusTextDisplay" and returns:
    -- "BOTH", "PERCENT", "NUMERIC", "NONE"
    local mode = GetCVar and GetCVar("statusTextDisplay")
    if mode and mode ~= "" then return mode end

    -- Fallback: some builds use a boolean-ish cvar
    local statusText = GetCVar and GetCVar("statusText")
    if statusText == "1" then return STATUS_TEXT_DISPLAY_MODE.BOTH end

    return STATUS_TEXT_DISPLAY_MODE.BOTH
end

local function HideDefaultTextStrings(statusBar)
    if not statusBar then return end
    -- Different UI builds use different fields; hide whatever exists.
    local fields = {
        "TextString", "TextString2", "TextString3",
        "LeftText", "RightText", "CenterText",
        "textString", "textString2", "textString3",
    }
    for _, k in ipairs(fields) do
        local t = statusBar[k]
        if t and t.Hide then
            t:Hide()
        end
    end
end

-- ============================================================
-- Overlay layer (NEW): ensures text draws above frame art
-- ============================================================
local overlayFrame

local function GetOverlayParent()
    -- TargetFrameTextureFrame typically draws above the target art.
    return _G.TargetFrameTextureFrame or _G.TargetFrame or UIParent
end

local function EnsureOverlayFrame()
    local parent = GetOverlayParent()

    -- If UI gets rebuilt (Edit Mode / layout changes), re-parent cleanly.
    if overlayFrame and overlayFrame:GetParent() ~= parent then
        overlayFrame:Hide()
        overlayFrame = nil
        -- Force FontString recreation on next CreateTargetText()
        TargetHealthPercentText = nil
        TargetHealthValueText = nil
        TargetHealthCenterText = nil
        TargetManaPercentText = nil
        TargetManaValueText = nil
        TargetManaCenterText = nil
    end

    if overlayFrame then return overlayFrame end

    overlayFrame = CreateFrame("Frame", "TargetHealthPlusOverlay", parent)
    -- HIGH is usually enough; if any UI mod still draws above it, change to "DIALOG"
    overlayFrame:SetFrameStrata("HIGH")
    overlayFrame:SetFrameLevel((parent:GetFrameLevel() or 0) + 80)
    overlayFrame:Show()

    return overlayFrame
end

-- CHANGED: We now create fontstrings on overlayFrame (parent), but anchor them to the bar (rel).
local function EnsureFS(name, point, rel, relPoint, x, y, justify)
    if _G[name] then return _G[name] end

    local parent = EnsureOverlayFrame()
    local fs = parent:CreateFontString(name, "OVERLAY", "TextStatusBarText")
    fs:SetPoint(point, rel, relPoint, x, y)
    fs:SetJustifyH(justify)
    fs:SetJustifyV("MIDDLE")

    -- Optional: crisper rendering under scaling (helps reduce "bold" look)
    if fs.SetSnapToPixelGrid then fs:SetSnapToPixelGrid(true) end
    if fs.SetTexelSnappingBias then fs:SetTexelSnappingBias(0) end

    return fs
end

-- Create three text fields per bar:
--  - Left  (percent)
--  - Right (value)
--  - Center (percent OR value/max depending on setting)
local healthLeft, healthRight, healthCenter
local manaLeft, manaRight, manaCenter

local function CreateTargetText()
    -- Target frame bars can be reconstructed by Edit Mode, so recreate if needed.
    local hb = _G.TargetFrameHealthBar or (_G.TargetFrame and _G.TargetFrame.healthbar)
    local mb = _G.TargetFrameManaBar   or (_G.TargetFrame and _G.TargetFrame.manabar)
    if not hb then return false end

    EnsureOverlayFrame()

    HideDefaultTextStrings(hb)
    if mb then HideDefaultTextStrings(mb) end

    -- Health text (anchored to hb, created on overlay)
    healthLeft   = EnsureFS("TargetHealthPercentText", "LEFT",   hb, "LEFT",   3,  0, "LEFT")
    healthRight  = EnsureFS("TargetHealthValueText",   "RIGHT",  hb, "RIGHT", -3,  0, "RIGHT")
    healthCenter = EnsureFS("TargetHealthCenterText",  "CENTER", hb, "CENTER", 0,  0, "CENTER")

    -- Mana/Power text
    if mb then
        manaLeft   = EnsureFS("TargetManaPercentText", "LEFT",   mb, "LEFT",   3,  0, "LEFT")
        manaRight  = EnsureFS("TargetManaValueText",   "RIGHT",  mb, "RIGHT", -3,  0, "RIGHT")
        manaCenter = EnsureFS("TargetManaCenterText",  "CENTER", mb, "CENTER", 0,  0, "CENTER")
    end

    return true
end

local function ApplyMode(leftFS, rightFS, centerFS, value, maxValue)
    local mode = GetDisplayMode()

    if not value or not maxValue or maxValue <= 0 then
        if leftFS then leftFS:SetText(""); leftFS:Hide() end
        if rightFS then rightFS:SetText(""); rightFS:Hide() end
        if centerFS then centerFS:SetText(""); centerFS:Hide() end
        return
    end

    local pct = math.floor((value / maxValue) * 100 + 0.5)

    if mode == STATUS_TEXT_DISPLAY_MODE.BOTH then
        -- Left: %  Right: current value
        if leftFS then leftFS:SetText(pct .. "%"); leftFS:Show() end
        if rightFS then rightFS:SetText(Abbrev(value)); rightFS:Show() end
        if centerFS then centerFS:SetText(""); centerFS:Hide() end

    elseif mode == STATUS_TEXT_DISPLAY_MODE.PERCENT then
        -- Center: %
        if centerFS then centerFS:SetText(pct .. "%"); centerFS:Show() end
        if leftFS then leftFS:SetText(""); leftFS:Hide() end
        if rightFS then rightFS:SetText(""); rightFS:Hide() end

    elseif mode == STATUS_TEXT_DISPLAY_MODE.NUMERIC then
        -- Center: value / max (player-style)
        local txt = Abbrev(value) .. " / " .. Abbrev(maxValue)
        if centerFS then centerFS:SetText(txt); centerFS:Show() end
        if leftFS then leftFS:SetText(""); leftFS:Hide() end
        if rightFS then rightFS:SetText(""); rightFS:Hide() end

    else -- NONE or unknown
        if leftFS then leftFS:SetText(""); leftFS:Hide() end
        if rightFS then rightFS:SetText(""); rightFS:Hide() end
        if centerFS then centerFS:SetText(""); centerFS:Hide() end
    end
end

local function UpdateTargetText()
    -- Re-acquire bars each update in case Edit Mode rebuilt the frame.
    local hb = _G.TargetFrameHealthBar or (_G.TargetFrame and _G.TargetFrame.healthbar)
    local mb = _G.TargetFrameManaBar   or (_G.TargetFrame and _G.TargetFrame.manabar)
    if not hb then return end

    EnsureOverlayFrame()

    -- Ensure our fontstrings exist and default strings stay hidden.
    if not (healthLeft and healthRight and healthCenter) then
        CreateTargetText()
    else
        HideDefaultTextStrings(hb)
        if mb then HideDefaultTextStrings(mb) end
    end

    if UnitExists("target") then
        -- Health
        local hp  = UnitHealth("target")
        local hpm = UnitHealthMax("target")
        ApplyMode(healthLeft, healthRight, healthCenter, hp, hpm)

        -- Power
        if mb and manaLeft and manaRight and manaCenter then
            local pp  = UnitPower("target")
            local ppm = UnitPowerMax("target")
            ApplyMode(manaLeft, manaRight, manaCenter, pp, ppm)
        end
    else
        ApplyMode(healthLeft, healthRight, healthCenter, nil, nil)
        if manaLeft or manaRight or manaCenter then
            ApplyMode(manaLeft, manaRight, manaCenter, nil, nil)
        end
    end
end

local pending = false
local function QueueUpdate()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        pcall(UpdateTargetText)
    end)
end

local function RegisterEvents()
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("UNIT_HEALTH")
    f:RegisterEvent("UNIT_MAXHEALTH")
    f:RegisterEvent("UNIT_POWER_UPDATE")
    f:RegisterEvent("UNIT_MAXPOWER")
    f:RegisterEvent("UNIT_DISPLAYPOWER")
    f:RegisterEvent("CVAR_UPDATE")
end

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        CreateTargetText()
        QueueUpdate()
        return
    end

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if arg1 == "target" then QueueUpdate() end
        return
    end
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        if arg1 == "target" then QueueUpdate() end
        return
    end
    if event == "CVAR_UPDATE" then
        -- statusText / statusTextDisplay changes
        QueueUpdate()
        return
    end

    -- login/enter world/target change
    QueueUpdate()
end)

RegisterEvents()

-- Safety: also refresh after a short delay because Edit Mode / UI loading can reconstruct bars
C_Timer.After(1, function() pcall(UpdateTargetText) end)
