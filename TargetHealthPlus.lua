-- TargetHealthPlus (Classic Anniversary / Era 2.5.5+)
-- Displays target health/power text (percent/value) on the target frame.
-- Notes:
--  - No Blizzard internal function hooks (2.5.5+ resilient)
--  - Text is drawn above frame art (overlay frame)
--  - Keeps Blizzard status text hidden (even on hover)
--  - Hides text when target is dead (avoids "Dead" overlap)
--  - Does NOT hard-code a font: copies the font currently used by the player frame text.
--  - When Status Text = None, values will show on mouseover (like the player frame)

STATUS_TEXT_DISPLAY_MODE = STATUS_TEXT_DISPLAY_MODE or {
    NUMERIC = "NUMERIC",
    PERCENT = "PERCENT",
    BOTH    = "BOTH",
    NONE    = "NONE",
}

local f = CreateFrame("Frame")

-- ----------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------
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

local function HideDefaultTextStrings(bar)
    if not bar then return end
    local keys = {
        "TextString","TextString2","TextString3",
        "LeftText","RightText","CenterText",
        "textString","textString2","textString3",
    }
    for i = 1, #keys do
        local t = bar[keys[i]]
        if t then
            if t.Hide then t:Hide() end
            if t.SetAlpha then t:SetAlpha(0) end
        end
    end
end

-- ----------------------------------------------------------
-- Overlay frame (above art)
-- ----------------------------------------------------------
local overlayFrame
local function EnsureOverlayFrame()
    local parent = _G.TargetFrameTextureFrame or _G.TargetFrame or UIParent

    if overlayFrame and overlayFrame:GetParent() ~= parent then
        overlayFrame:Hide()
        overlayFrame = nil
        TargetHealthPercentText = nil
        TargetHealthValueText   = nil
        TargetHealthCenterText  = nil
        TargetManaPercentText   = nil
        TargetManaValueText     = nil
        TargetManaCenterText    = nil
    end

    if overlayFrame then return overlayFrame end

    overlayFrame = CreateFrame("Frame", "TargetHealthPlusOverlay", parent)
    overlayFrame:SetFrameStrata("HIGH")
    overlayFrame:SetFrameLevel((parent:GetFrameLevel() or 0) + 80)
    overlayFrame:Show()
    return overlayFrame
end

-- ----------------------------------------------------------
-- Font: follow whatever the player frame is currently using
-- ----------------------------------------------------------
local function GetFontSource()
    return _G.PlayerFrameHealthBarTextLeft
        or _G.PlayerFrameHealthBarText
        or (_G.PlayerFrameHealthBar and _G.PlayerFrameHealthBar.TextString)
        or (_G.PlayerFrame and _G.PlayerFrame.healthbar and _G.PlayerFrame.healthbar.TextString)
        or _G.TextStatusBarText
end

local function ApplyFont(fs)
    if not fs or not fs.SetFont then return end
    local src = GetFontSource()
    if not src or not src.GetFont then return end
    local font, size, flags = src:GetFont()
    if font and size then
        fs:SetFont(font, size, flags)
    end
end

-- ----------------------------------------------------------
-- Create our FontStrings
-- ----------------------------------------------------------
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

-- Mouseover state (for Status Text = None)
local hoverHealth, hoverMana = false, false

local function HideAll(a,b,c)
    if a then a:Hide() end
    if b then b:Hide() end
    if c then c:Hide() end
end

-- Throttled update
local pending = false
local function QueueUpdate()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        pcall(function() -- pcall wrapper keeps errors from breaking event handler
            if UpdateTargetText then UpdateTargetText() end
        end)
    end)
end

local function HookBarMouseHandlers(bar, which)
    if not bar or bar.__THP_Hooked then return end
    bar.__THP_Hooked = true

    bar:HookScript("OnEnter", function()
        HideDefaultTextStrings(bar)
        if which == "health" then hoverHealth = true else hoverMana = true end
        if GetDisplayMode() == STATUS_TEXT_DISPLAY_MODE.NONE then
            QueueUpdate()
        end
    end)

    bar:HookScript("OnLeave", function()
        HideDefaultTextStrings(bar)
        if which == "health" then hoverHealth = false else hoverMana = false end
        if GetDisplayMode() == STATUS_TEXT_DISPLAY_MODE.NONE then
            QueueUpdate()
        end
    end)
end

local function CreateTargetText()
    local hb = _G.TargetFrameHealthBar or (_G.TargetFrame and _G.TargetFrame.healthbar)
    local mb = _G.TargetFrameManaBar   or (_G.TargetFrame and _G.TargetFrame.manabar)
    if not hb then return false end

    EnsureOverlayFrame()

    HookBarMouseHandlers(hb, "health")
    if mb then HookBarMouseHandlers(mb, "mana") end

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

    ApplyFont(healthLeft); ApplyFont(healthRight); ApplyFont(healthCenter)
    ApplyFont(manaLeft);   ApplyFont(manaRight);   ApplyFont(manaCenter)

    return true
end

-- ----------------------------------------------------------
-- Rendering
-- ----------------------------------------------------------
local function ApplyMode(leftFS, rightFS, centerFS, value, maxValue, hoverShow)
    local mode = GetDisplayMode()

    if not value or not maxValue or maxValue <= 0 then
        HideAll(leftFS, rightFS, centerFS)
        return
    end

    local pct = math.floor((value / maxValue) * 100 + 0.5)

    if mode == STATUS_TEXT_DISPLAY_MODE.BOTH then
        if leftFS  then leftFS:SetText(pct .. "%"); leftFS:Show() end
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

    elseif mode == STATUS_TEXT_DISPLAY_MODE.NONE then
        -- None: show values only when hovering the bar (player-frame behavior)
        if hoverShow and centerFS then
            centerFS:SetText(Abbrev(value) .. " / " .. Abbrev(maxValue))
            centerFS:Show()
        else
            HideAll(leftFS, rightFS, centerFS)
        end

    else
        HideAll(leftFS, rightFS, centerFS)
    end
end

-- forward-declared for QueueUpdate closure
function UpdateTargetText()
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

    -- Keep our font synced
    ApplyFont(healthLeft); ApplyFont(healthRight); ApplyFont(healthCenter)
    ApplyFont(manaLeft);   ApplyFont(manaRight);   ApplyFont(manaCenter)

    if not UnitExists("target") then
        HideAll(healthLeft, healthRight, healthCenter)
        HideAll(manaLeft, manaRight, manaCenter)
        return
    end

    if UnitIsDeadOrGhost("target") then
        HideAll(healthLeft, healthRight, healthCenter)
        HideAll(manaLeft, manaRight, manaCenter)
        return
    end

    ApplyMode(healthLeft, healthRight, healthCenter,
        UnitHealth("target"), UnitHealthMax("target"), hoverHealth)

    if mb and manaLeft and manaRight and manaCenter then
        ApplyMode(manaLeft, manaRight, manaCenter,
            UnitPower("target"), UnitPowerMax("target"), hoverMana)
    else
        HideAll(manaLeft, manaRight, manaCenter)
    end
end

-- ----------------------------------------------------------
-- Debug (one-shot)
-- ----------------------------------------------------------
SLASH_THPDEBUG1 = "/thpdebug"
SlashCmdList.THPDEBUG = function()
    local src = GetFontSource()
    local font, size, flags = src and src.GetFont and src:GetFont()
    DEFAULT_CHAT_FRAME:AddMessage("THP font source: " .. (src and src.GetName and src:GetName() or tostring(src) or "nil"))
    DEFAULT_CHAT_FRAME:AddMessage("THP font: " .. tostring(font) .. " " .. tostring(size) .. " " .. tostring(flags))
end

-- ----------------------------------------------------------
-- Events
-- ----------------------------------------------------------
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("UNIT_MAXHEALTH")
f:RegisterEvent("UNIT_POWER_UPDATE")
f:RegisterEvent("UNIT_MAXPOWER")
f:RegisterEvent("UNIT_DISPLAYPOWER")
f:RegisterEvent("CVAR_UPDATE")

f:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH"
    or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        if unit ~= "target" then return end
    end

    if event == "PLAYER_LOGIN" then
        CreateTargetText()
    end
    QueueUpdate()
end)

-- Safety: some addons apply fonts a moment after login
C_Timer.After(1, function() pcall(UpdateTargetText) end)
