-- TargetHealthPlus (Classic Era 2.5.5)

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
    if n >= 1e6 then
        return string.format("%.1fm", n / 1e6)
    elseif n >= 1e3 then
        return string.format("%.1fk", n / 1e3)
    end
    return tostring(n)
end

local function GetDisplayMode()
    local mode = GetCVar and GetCVar("statusTextDisplay")
    if mode and mode ~= "" then return mode end

    local statusText = GetCVar and GetCVar("statusText")
    if statusText == "1" then return STATUS_TEXT_DISPLAY_MODE.BOTH end

    return STATUS_TEXT_DISPLAY_MODE.BOTH
end

local function HideDefaultTextStrings(statusBar)
    if not statusBar then return end
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
        if t and t.SetAlpha then
            t:SetAlpha(0)
        end
    end
end

local function HookBarMouseHandlers(bar)
    if not bar or bar.__TargetHealthPlusHooked then return end
    bar.__TargetHealthPlusHooked = true

    bar:HookScript("OnEnter", function()
        HideDefaultTextStrings(bar)
    end)

    bar:HookScript("OnLeave", function()
        HideDefaultTextStrings(bar)
    end)
end

local overlayFrame

local function GetOverlayParent()
    return _G.TargetFrameTextureFrame or _G.TargetFrame or UIParent
end

local function EnsureOverlayFrame()
    local parent = GetOverlayParent()

    if overlayFrame and overlayFrame:GetParent() ~= parent then
        overlayFrame:Hide()
        overlayFrame = nil
        TargetHealthPercentText = nil
        TargetHealthValueText = nil
        TargetHealthCenterText = nil
        TargetManaPercentText = nil
        TargetManaValueText = nil
        TargetManaCenterText = nil
    end

    if overlayFrame then return overlayFrame end

    overlayFrame = CreateFrame("Frame", "TargetHealthPlusOverlay", parent)
    overlayFrame:SetFrameStrata("HIGH")
    overlayFrame:SetFrameLevel((parent:GetFrameLevel() or 0) + 80)
    overlayFrame:Show()

    return overlayFrame
end

local function EnsureFS(name, point, rel, relPoint, x, y, justify)
    if _G[name] then return _G[name] end

    local parent = EnsureOverlayFrame()
    local fs = parent:CreateFontString(name, "OVERLAY", "TextStatusBarText")
    fs:SetPoint(point, rel, relPoint, x, y)
    fs:SetJustifyH(justify)
    fs:SetJustifyV("MIDDLE")

    if fs.SetSnapToPixelGrid then fs:SetSnapToPixelGrid(true) end
    if fs.SetTexelSnappingBias then fs:SetTexelSnappingBias(0) end

    return fs
end

local healthLeft, healthRight, healthCenter
local manaLeft, manaRight, manaCenter

local function CreateTargetText()
    local hb = _G.TargetFrameHealthBar or (_G.TargetFrame and _G.TargetFrame.healthbar)
    local mb = _G.TargetFrameManaBar   or (_G.TargetFrame and _G.TargetFrame.manabar)
    if not hb then return false end

    EnsureOverlayFrame()

    HookBarMouseHandlers(hb)
    if mb then HookBarMouseHandlers(mb) end

    HideDefaultTextStrings(hb)
    if mb then HideDefaultTextStrings(mb) end

    healthLeft   = EnsureFS("TargetHealthPercentText", "LEFT",   hb, "LEFT",   3,  0, "LEFT")
    healthRight  = EnsureFS("TargetHealthValueText",   "RIGHT",  hb, "RIGHT", -3,  0, "RIGHT")
    healthCenter = EnsureFS("TargetHealthCenterText",  "CENTER", hb, "CENTER", 0,  0, "CENTER")

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
        if leftFS then leftFS:Hide() end
        if rightFS then rightFS:Hide() end
        if centerFS then centerFS:Hide() end
        return
    end

    local pct = math.floor((value / maxValue) * 100 + 0.5)

    if mode == STATUS_TEXT_DISPLAY_MODE.BOTH then
        if leftFS then leftFS:SetText(pct .. "%"); leftFS:Show() end
        if rightFS then rightFS:SetText(Abbrev(value)); rightFS:Show() end
        if centerFS then centerFS:Hide() end

    elseif mode == STATUS_TEXT_DISPLAY_MODE.PERCENT then
        if centerFS then centerFS:SetText(pct .. "%"); centerFS:Show() end
        if leftFS then leftFS:Hide() end
        if rightFS then rightFS:Hide() end

    elseif mode == STATUS_TEXT_DISPLAY_MODE.NUMERIC then
        if centerFS then centerFS:SetText(Abbrev(value) .. " / " .. Abbrev(maxValue)); centerFS:Show() end
        if leftFS then leftFS:Hide() end
        if rightFS then rightFS:Hide() end

    else
        if leftFS then leftFS:Hide() end
        if rightFS then rightFS:Hide() end
        if centerFS then centerFS:Hide() end
    end
end

local function UpdateTargetText()
    local hb = _G.TargetFrameHealthBar or (_G.TargetFrame and _G.TargetFrame.healthbar)
    local mb = _G.TargetFrameManaBar   or (_G.TargetFrame and _G.TargetFrame.manabar)
    if not hb then return end

    EnsureOverlayFrame()

    if not (healthLeft and healthRight and healthCenter) then
        CreateTargetText()
    else
        HideDefaultTextStrings(hb)
        if mb then HideDefaultTextStrings(mb) end
    end

    if UnitExists("target") then
        -- ✅ NEW: hide addon text entirely when target is dead
        if UnitIsDeadOrGhost("target") then
            ApplyMode(healthLeft, healthRight, healthCenter, nil, nil)
            if mb and manaLeft and manaRight and manaCenter then
                ApplyMode(manaLeft, manaRight, manaCenter, nil, nil)
            end
            return
        end

        ApplyMode(healthLeft, healthRight, healthCenter,
            UnitHealth("target"), UnitHealthMax("target"))

        if mb and manaLeft and manaRight and manaCenter then
            ApplyMode(manaLeft, manaRight, manaCenter,
                UnitPower("target"), UnitPowerMax("target"))
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

    if (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH"
     or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER"
     or event == "UNIT_DISPLAYPOWER") and arg1 == "target" then
        QueueUpdate()
        return
    end

    QueueUpdate()
end)

RegisterEvents()
C_Timer.After(1, function() pcall(UpdateTargetText) end)
