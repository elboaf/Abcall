-- ABCall: Arathi Basin Callout Addon
-- Compatible with WoW 1.12 / Turtle WoW (Lua 5.0)
-- /abcall        - toggle show/hide
-- /abcall layout - cycle layout (vertical → horizontal → sequential)
-- /abcall debug  - toggle debug mode (prints to chat instead of /bg)
-- /abcall reset  - reset frame position and scale to default
-- SavedVariables: ABCallDB

local AB_MAP_NAME = "Arathi Basin"

local objectives = {
    { name = "Stables",     code = "ST" },
    { name = "Lumber Mill", code = "LM" },
    { name = "Blacksmith",  code = "BS" },
    { name = "Gold Mine",   code = "GM" },
    { name = "Farm",        code = "FM" },
}

-- Global message definitions used by all layout modes.
-- msg = what gets sent to chat (after location prefix).
-- seqMsg = override for sequential mode (no location prefix on numbers).
local messages = {
    { label = "Safe",  msg = "Safe.",       r=0.4, g=1,   b=0.4, index=1 },
    { label = "1",     msg = "1",           r=1,   g=1,   b=1,   index=2 },
    { label = "2",     msg = "2",           r=1,   g=1,   b=1,   index=3 },
    { label = "3",     msg = "3",           r=1,   g=0.8, b=0.2, index=4 },
    { label = "4+",    msg = "4+",          r=1,   g=0.5, b=0,   index=5 },
    { label = "BIG",   msg = "BIG inc!",    r=1,   g=0.2, b=0.2, index=6 },
    { label = "Help!", msg = "Help!",       r=1,   g=0.2, b=0.2, index=7 },
    { label = "NDef",  msg = "Undefended!", r=1,   g=0.7, b=0,   index=8 },
    { label = "OMW",   msg = "OMW.",        r=0.4, g=1,   b=0.4, index=9 },
}

-- Sequential mode: two rows of buttons
-- Row 1 = numbers, Row 2 = status
local seqRow1 = { 2, 3, 4, 5 }   -- 1, 2, 3, 4+
local seqRow2 = { 1, 7, 9 }       -- Safe, Help!, OMW

-- Vertical layout row definitions
local vertRows = {
    { type="single", msgIndex=1 },
    { type="multi",  msgs={2,3} },
    { type="multi",  msgs={4,5} },
    { type="single", msgIndex=6 },
    { type="single", msgIndex=7 },
    { type="single", msgIndex=8 },
    { type="single", msgIndex=9 },
}

local manualOverride  = false
local debugMode       = false
local frameScale      = 1.0
local layoutMode      = "vertical"   -- "vertical" | "horizontal" | "sequential"
local layoutCycle     = { "vertical", "horizontal", "sequential" }

local selectedBase    = nil   -- sequential mode: currently selected objective index
local seqBaseFS       = {}    -- sequential mode: fontstrings for base buttons
local seqMsgBtns      = {}    -- sequential mode: message buttons (to re-highlight)

local NUM_OBJ  = table.getn(objectives)
local NUM_MSG  = table.getn(messages)
local NUM_VROW = table.getn(vertRows)
local NUM_SEQR1 = table.getn(seqRow1)
local NUM_SEQR2 = table.getn(seqRow2)

-- ─────────────────────────────────────────────
-- Layout constants
-- ─────────────────────────────────────────────
local BTN_H     = 16   -- slightly taller for sequential (roomier feel)
local BTN_PAD_X = 1
local BTN_GAP   = 2
local ROW_GAP   = 2
local PAD       = 4
local LABEL_W   = 20

local _m = UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
local msgWidths = {}
local objWidths = {}
for i, md in ipairs(messages) do
    _m:SetText(md.label)
    msgWidths[i] = math.ceil(_m:GetStringWidth()) + BTN_PAD_X * 2
end
for i, obj in ipairs(objectives) do
    _m:SetText(obj.code)
    objWidths[i] = math.ceil(_m:GetStringWidth()) + BTN_PAD_X * 2
end
_m:Hide()

-- ─────────────────────────────────────────────
-- Vertical layout sizing helpers
-- ─────────────────────────────────────────────
local function vertRowContentW(row)
    if row.type == "single" then
        return msgWidths[row.msgIndex]
    else
        local w = 0
        for i, mi in ipairs(row.msgs) do
            w = w + msgWidths[mi]
            if i < table.getn(row.msgs) then w = w + BTN_GAP end
        end
        return w
    end
end

local function calcColW(objIdx)
    local w = objWidths[objIdx]
    for _, row in ipairs(vertRows) do
        local rw = vertRowContentW(row)
        if rw > w then w = rw end
    end
    return w
end

local colWidths = {}
for i = 1, NUM_OBJ do colWidths[i] = calcColW(i) end

-- ─────────────────────────────────────────────
-- Frame size helpers
-- ─────────────────────────────────────────────
local function calcHorizSize()
    local totalBtnW = 0
    for i = 1, NUM_MSG do totalBtnW = totalBtnW + msgWidths[i] + BTN_GAP end
    local w = PAD + LABEL_W + BTN_GAP + totalBtnW + PAD
    local h = PAD + (BTN_H + ROW_GAP) * NUM_OBJ + PAD
    return w, h
end

local function calcVertSize()
    local totalColW = 0
    for i = 1, NUM_OBJ do totalColW = totalColW + colWidths[i] + BTN_GAP end
    local w = PAD + totalColW + PAD
    local h = PAD + (BTN_H + ROW_GAP) * (NUM_VROW + 1) + PAD
    return w, h
end

local function calcSeqSize()
    -- Base buttons: each must be at least as wide as its label
    local minBaseBtnW = 0
    for i = 1, NUM_OBJ do
        if objWidths[i] > minBaseBtnW then minBaseBtnW = objWidths[i] end
    end
    local basesW = (minBaseBtnW + BTN_GAP) * NUM_OBJ
    local row1W = 0
    for _, mi in ipairs(seqRow1) do row1W = row1W + msgWidths[mi] + BTN_GAP end
    local row2W = 0
    for _, mi in ipairs(seqRow2) do row2W = row2W + msgWidths[mi] + BTN_GAP end
    local w = PAD + math.max(basesW, row1W, row2W) + PAD
    local h = PAD + (BTN_H + ROW_GAP) * 3 + PAD
    return w, h
end

-- ─────────────────────────────────────────────
-- Main frame
-- ─────────────────────────────────────────────
local frame = CreateFrame("Frame", "ABCallFrame", UIParent)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    tile = true, tileSize = 32, edgeSize = 0,
    insets = { left=0, right=0, top=0, bottom=0 },
})
frame:SetBackdropColor(0, 0, 0, 0.88)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() frame:StartMoving() end)
frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
frame:Hide()

-- ─────────────────────────────────────────────
-- Corner toggle dot (cycles all 3 layouts)
-- ─────────────────────────────────────────────
local cornerBtn = CreateFrame("Button", "ABCallCorner", frame)
cornerBtn:SetWidth(6)
cornerBtn:SetHeight(6)
cornerBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
cornerBtn:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 0,
    insets   = { left=0, right=0, top=0, bottom=0 },
})
cornerBtn:SetBackdropColor(1, 0.82, 0, 0.35)
cornerBtn:SetScript("OnEnter", function() cornerBtn:SetBackdropColor(1, 0.82, 0, 1) end)
cornerBtn:SetScript("OnLeave", function() cornerBtn:SetBackdropColor(1, 0.82, 0, 0.35) end)

-- ─────────────────────────────────────────────
-- Message format templates
-- Tokens: %location% %num% (numbers only)
-- These are the defaults; player can edit them in the settings panel.
-- ─────────────────────────────────────────────
local msgFormats = {
    safe  = "%location% Safe.",
    num   = "%location% %num%",
    big   = "%location% BIG inc!",
    help  = "Help %location%!",
    ndef  = "%location% Undefended!",
    omw   = "OMW %location%",
}

-- Map message index → format key (nil = use default loc+msg fallback)
local msgFormatKey = {
    [1]  = "safe",
    [2]  = "num",
    [3]  = "num",
    [4]  = "num",
    [5]  = "num",
    [6]  = "big",
    [7]  = "help",
    [8]  = "ndef",
    [9]  = "omw",
}

local function applyFormat(template, loc, num)
    local s = template
    s = string.gsub(s, "%%location%%", loc)
    if num then
        s = string.gsub(s, "%%num%%", num)
    end
    return s
end

-- ─────────────────────────────────────────────
-- Chat send wrapper (debug mode prints locally)
-- ─────────────────────────────────────────────
local function sendMsg(text)
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700[ABCall Debug]|r " .. text)
    else
        SendChatMessage(text, "BATTLEGROUND")
    end
end

-- ─────────────────────────────────────────────
-- Message builder (shared by all modes)
-- ─────────────────────────────────────────────
local function buildMsg(obj, md)
    local loc = obj.code
    if obj.code == "FM" then loc = "FARM" end
    local key = msgFormatKey[md.index]
    if key then
        local num = md.label  -- for number buttons label IS the number
        return applyFormat(msgFormats[key], loc, num)
    end
    return loc .. " " .. md.msg
end
-- ─────────────────────────────────────────────
-- Saved variables helpers
-- ABCallDB = { layout=..., formats={ safe=..., ... } }
-- ─────────────────────────────────────────────
local function saveVars()
    ABCallDB = ABCallDB or {}
    ABCallDB.layout = layoutMode
    ABCallDB.scale  = frameScale
    ABCallDB.formats = {}
    for k, v in pairs(msgFormats) do
        ABCallDB.formats[k] = v
    end
end

local function loadVars()
    if not ABCallDB then return end
    if ABCallDB.layout then
        layoutMode = ABCallDB.layout
    end
    if ABCallDB.scale then
        frameScale = ABCallDB.scale
    end
    if ABCallDB.formats then
        for k, v in pairs(ABCallDB.formats) do
            if msgFormats[k] ~= nil then   -- only load known keys
                msgFormats[k] = v
            end
        end
    end
end

-- ─────────────────────────────────────────────
-- Settings panel
-- ─────────────────────────────────────────────
local settingsFrame = CreateFrame("Frame", "ABCallSettings", UIParent)
settingsFrame:SetWidth(300)
settingsFrame:SetHeight(260)
settingsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
settingsFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left=5, right=5, top=5, bottom=5 },
})
settingsFrame:SetBackdropColor(0, 0, 0, 0.95)
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", function() settingsFrame:StartMoving() end)
settingsFrame:SetScript("OnDragStop",  function() settingsFrame:StopMovingOrSizing() end)
settingsFrame:SetFrameStrata("DIALOG")
settingsFrame:Hide()

local settingsTitle = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
settingsTitle:SetPoint("TOP", settingsFrame, "TOP", 0, -10)
settingsTitle:SetText("|cffFFD700ABCall - Message Formats|r")

local settingsClose = CreateFrame("Button", "ABCallSettingsClose", settingsFrame, "UIPanelCloseButton")
settingsClose:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", 2, 2)
settingsClose:SetScript("OnClick", function() settingsFrame:Hide() end)

-- Format fields: { key, display label }
local formatFields = {
    { key="safe", label="Safe:"     },
    { key="num",  label="Numbers:"  },
    { key="big",  label="Big:"      },
    { key="help", label="Help:"     },
    { key="ndef", label="NDef:"     },
    { key="omw",  label="OMW:"      },
}

local settingsEditBoxes = {}
local SF_PAD   = 16
local SF_LBL_W = 58
local SF_EB_H  = 18
local SF_GAP   = 6

for i, field in ipairs(formatFields) do
    local y    = -(28 + (i-1) * (SF_EB_H + SF_GAP))
    local fkey = field.key   -- capture before closure

    local lbl = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetWidth(SF_LBL_W)
    lbl:SetHeight(SF_EB_H)
    lbl:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", SF_PAD, y)
    lbl:SetJustifyH("RIGHT")
    lbl:SetText(field.label)
    lbl:SetTextColor(1, 0.82, 0)

    local eb = CreateFrame("EditBox", "ABCallEB_"..fkey, settingsFrame)
    eb:SetWidth(300 - SF_PAD*2 - SF_LBL_W - 6)
    eb:SetHeight(SF_EB_H)
    eb:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", SF_PAD + SF_LBL_W + 6, y)
    eb:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left=2, right=2, top=2, bottom=2 },
    })
    eb:SetBackdropColor(0.05, 0.05, 0.1, 0.9)
    eb:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    eb:SetFontObject("GameFontNormalSmall")
    eb:SetTextColor(1, 1, 1)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(120)
    eb:SetText(msgFormats[fkey])
    eb:SetScript("OnEscapePressed", function() eb:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function() eb:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", function()
        local val = eb:GetText()
        if val and string.len(val) > 0 then
            msgFormats[fkey] = val
            saveVars()
        end
    end)

    settingsEditBoxes[fkey] = eb
end

-- Scale slider
local scaleLbl = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
scaleLbl:SetPoint("BOTTOMLEFT", settingsFrame, "BOTTOMLEFT", SF_PAD, 52)
scaleLbl:SetText("|cffFFD700Scale:|r")
scaleLbl:SetTextColor(1, 0.82, 0)

local scaleValLbl = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
scaleValLbl:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -SF_PAD, 52)
scaleValLbl:SetTextColor(1, 1, 1)

local slider = CreateFrame("Slider", "ABCallScaleSlider", settingsFrame, "OptionsSliderTemplate")
slider:SetWidth(300 - SF_PAD * 2 - 4)
slider:SetHeight(16)
slider:SetPoint("BOTTOM", settingsFrame, "BOTTOM", 0, 30)
slider:SetMinMaxValues(0.5, 2.0)
slider:SetValueStep(0.05)
slider:SetValue(frameScale)
-- Hide the default min/max labels baked into OptionsSliderTemplate
getglobal(slider:GetName().."Low"):SetText("")
getglobal(slider:GetName().."High"):SetText("")
getglobal(slider:GetName().."Text"):SetText("")

local function updateScaleLabel(val)
    scaleValLbl:SetText(string.format("%.0f%%", val * 100))
end
updateScaleLabel(frameScale)

slider:SetScript("OnValueChanged", function()
    local val = math.floor(slider:GetValue() / 0.05 + 0.5) * 0.05
    frameScale = val
    frame:SetScale(frameScale)
    updateScaleLabel(val)
    saveVars()
end)

-- Helper text at the bottom
local hint = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("BOTTOM", settingsFrame, "BOTTOM", 0, 14)
hint:SetText("|cff888888Tokens: %location%  %num% (numbers only)|r")

-- Top-left corner dot: opens settings
local settingsBtn = CreateFrame("Button", "ABCallSettingsBtn", frame)
settingsBtn:SetWidth(6)
settingsBtn:SetHeight(6)
settingsBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
settingsBtn:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 0,
    insets   = { left=0, right=0, top=0, bottom=0 },
})
settingsBtn:SetBackdropColor(1, 0.82, 0, 0.35)
settingsBtn:SetScript("OnEnter", function() settingsBtn:SetBackdropColor(1, 0.82, 0, 1) end)
settingsBtn:SetScript("OnLeave", function() settingsBtn:SetBackdropColor(1, 0.82, 0, 0.35) end)
settingsBtn:SetScript("OnClick", function()
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        -- Refresh editboxes and slider with current values before showing
        for _, field in ipairs(formatFields) do
            settingsEditBoxes[field.key]:SetText(msgFormats[field.key])
        end
        slider:SetValue(frameScale)
        updateScaleLabel(frameScale)
        settingsFrame:Show()
    end
end)

-- ─────────────────────────────────────────────
-- Highlight (horiz/vert modes)
-- ─────────────────────────────────────────────
local objHeaderFS = {}
local cellFS      = {}
for o = 1, NUM_OBJ do cellFS[o] = {} end

local function setHighlight(activeObj)
    for o = 1, NUM_OBJ do
        local dim = (o ~= activeObj)
        if objHeaderFS[o] then
            if dim then objHeaderFS[o]:SetTextColor(0.3, 0.3, 0.3)
            else        objHeaderFS[o]:SetTextColor(1, 1, 1) end
        end
        for _, e in ipairs(cellFS[o]) do
            if dim then e.fs:SetTextColor(0.3, 0.3, 0.3)
            else        e.fs:SetTextColor(e.r, e.g, e.b) end
        end
    end
end

local function clearHighlight()
    for o = 1, NUM_OBJ do
        if objHeaderFS[o] then objHeaderFS[o]:SetTextColor(1, 0.82, 0) end
        for _, e in ipairs(cellFS[o]) do e.fs:SetTextColor(e.r, e.g, e.b) end
    end
end

frame:SetScript("OnLeave", function() clearHighlight() end)

-- ─────────────────────────────────────────────
-- Child management
-- ─────────────────────────────────────────────
local children = {}

local function destroyChildren()
    for _, c in ipairs(children) do c:Hide() ; c:SetParent(nil) end
    children     = {}
    objHeaderFS  = {}
    seqBaseFS    = {}
    seqMsgBtns   = {}
    selectedBase = nil
end

local function makeBtn(name, w, h)
    local btn = CreateFrame("Button", name, frame)
    btn:SetWidth(w) ; btn:SetHeight(h)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 6, insets = { left=1, right=1, top=1, bottom=1 },
    })
    btn:SetBackdropColor(0.08, 0.08, 0.12, 0.85)
    btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
    table.insert(children, btn)
    return btn
end

local function makeHover(name, w, h)
    local f = CreateFrame("Button", name, frame)
    f:SetWidth(w) ; f:SetHeight(h) ; f:EnableMouse(true)
    table.insert(children, f)
    return f
end

local function makeGap(name, w, h)
    local g = CreateFrame("Frame", name, frame)
    g:SetWidth(w) ; g:SetHeight(h) ; g:EnableMouse(true)
    table.insert(children, g)
    return g
end


local function attachBtn(btn, obj, md, co)
    btn:SetScript("OnClick", function()
        sendMsg(buildMsg(obj, md))
    end)
    btn:SetScript("OnEnter", function()
        setHighlight(co)
        btn:SetBackdropBorderColor(1, 0.82, 0, 1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
    end)
end

-- ─────────────────────────────────────────────
-- Sequential mode helpers
-- ─────────────────────────────────────────────
local function seqRefreshBaseButtons()
    for o, entry in ipairs(seqBaseFS) do
        if o == selectedBase then
            entry.btn:SetBackdropBorderColor(1, 0.82, 0, 1)
            entry.btn:SetBackdropColor(0.2, 0.15, 0, 0.9)
            entry.fs:SetTextColor(1, 1, 1)
        else
            entry.btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
            entry.btn:SetBackdropColor(0.08, 0.08, 0.12, 0.85)
            entry.fs:SetTextColor(1, 0.82, 0)
        end
    end
end

local function seqRefreshMsgButtons()
    for _, entry in ipairs(seqMsgBtns) do
        if selectedBase then
            entry.btn:SetBackdropColor(0.08, 0.12, 0.08, 0.85)
            entry.fs:SetTextColor(entry.r, entry.g, entry.b)
        else
            entry.btn:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
            entry.fs:SetTextColor(0.3, 0.3, 0.3)
        end
    end
end

-- ─────────────────────────────────────────────
-- Horizontal layout
-- ─────────────────────────────────────────────
local function buildHorizontal()
    local fw, fh = calcHorizSize()
    frame:SetWidth(fw) ; frame:SetHeight(fh)

    for o, obj in ipairs(objectives) do
        local y  = -(PAD + (o-1) * (BTN_H + ROW_GAP))
        local co = o

        local lbl = makeHover("ABCallHLbl_"..o, LABEL_W, BTN_H)
        lbl:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
        local lfs = lbl:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lfs:SetAllPoints() ; lfs:SetJustifyH("LEFT")
        lfs:SetText(obj.code) ; lfs:SetTextColor(1, 0.82, 0)
        objHeaderFS[o] = lfs
        lbl:SetScript("OnEnter", function() setHighlight(co) end)

        if o < NUM_OBJ then
            local g = makeGap("ABCallHGapL_"..o, LABEL_W, ROW_GAP)
            g:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y - BTN_H)
            g:SetScript("OnEnter", function() setHighlight(co) end)
        end

        local x = PAD + LABEL_W + BTN_GAP
        for m, md in ipairs(messages) do
            local bw  = msgWidths[m]
            local btn = makeBtn("ABCallHBtn_"..o.."_"..m, bw, BTN_H)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
            local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetAllPoints() ; fs:SetJustifyH("CENTER")
            fs:SetText(md.label) ; fs:SetTextColor(md.r, md.g, md.b)
            table.insert(cellFS[o], { fs=fs, r=md.r, g=md.g, b=md.b })
            attachBtn(btn, obj, md, co)

            if o < NUM_OBJ then
                local g = makeGap("ABCallHGapB_"..o.."_"..m, bw, ROW_GAP)
                g:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y - BTN_H)
                g:SetScript("OnEnter", function() setHighlight(co) end)
            end
            x = x + bw + BTN_GAP
        end
    end
end

-- ─────────────────────────────────────────────
-- Vertical layout
-- ─────────────────────────────────────────────
local function buildVertical()
    local fw, fh = calcVertSize()
    frame:SetWidth(fw) ; frame:SetHeight(fh)

    local colX = {}
    local x = PAD
    for o = 1, NUM_OBJ do
        colX[o] = x
        x = x + colWidths[o] + BTN_GAP
    end

    for o, obj in ipairs(objectives) do
        local cx = colX[o]
        local cw = colWidths[o]
        local co = o

        local y   = -PAD
        local hdr = makeHover("ABCallVHdr_"..o, cw, BTN_H)
        hdr:SetPoint("TOPLEFT", frame, "TOPLEFT", cx, y)
        local hfs = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hfs:SetAllPoints() ; hfs:SetJustifyH("CENTER")
        hfs:SetText(obj.code) ; hfs:SetTextColor(1, 0.82, 0)
        objHeaderFS[o] = hfs
        hdr:SetScript("OnEnter", function() setHighlight(co) end)

        if o < NUM_OBJ then
            local g = makeGap("ABCallVGapH_"..o, BTN_GAP, BTN_H)
            g:SetPoint("TOPLEFT", frame, "TOPLEFT", cx + cw, y)
            g:SetScript("OnEnter", function() setHighlight(co) end)
        end

        for vr, row in ipairs(vertRows) do
            y = -(PAD + vr * (BTN_H + ROW_GAP))

            if row.type == "single" then
                local md  = messages[row.msgIndex]
                local btn = makeBtn("ABCallVBtn_"..o.."_"..vr, cw, BTN_H)
                btn:SetPoint("TOPLEFT", frame, "TOPLEFT", cx, y)
                local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fs:SetAllPoints() ; fs:SetJustifyH("CENTER")
                fs:SetText(md.label) ; fs:SetTextColor(md.r, md.g, md.b)
                table.insert(cellFS[o], { fs=fs, r=md.r, g=md.g, b=md.b })
                attachBtn(btn, obj, md, co)

                if o < NUM_OBJ then
                    local g = makeGap("ABCallVGapS_"..o.."_"..vr, BTN_GAP, BTN_H)
                    g:SetPoint("TOPLEFT", frame, "TOPLEFT", cx + cw, y)
                    g:SetScript("OnEnter", function() setHighlight(co) end)
                end
            else
                local half = math.floor((cw - BTN_GAP) / 2)
                local xpos = { cx, cx + half + BTN_GAP }

                for idx, mi in ipairs(row.msgs) do
                    local md  = messages[mi]
                    local btn = makeBtn("ABCallVMul_"..o.."_"..vr.."_"..idx, half, BTN_H)
                    btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xpos[idx], y)
                    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    fs:SetAllPoints() ; fs:SetJustifyH("CENTER")
                    fs:SetText(md.label) ; fs:SetTextColor(md.r, md.g, md.b)
                    table.insert(cellFS[o], { fs=fs, r=md.r, g=md.g, b=md.b })
                    attachBtn(btn, obj, md, co)
                end

                if o < NUM_OBJ then
                    local g = makeGap("ABCallVGapM_"..o.."_"..vr, BTN_GAP, BTN_H)
                    g:SetPoint("TOPLEFT", frame, "TOPLEFT", cx + cw, y)
                    g:SetScript("OnEnter", function() setHighlight(co) end)
                end
            end
        end
    end
end

-- ─────────────────────────────────────────────
-- Sequential layout
-- Row 1: base selector buttons (ST LM BS GM FM)
-- Row 2: message buttons (reduced set, bigger)
-- Click base → highlights it; click message → sends and resets
-- ─────────────────────────────────────────────
local function buildSequential()
    local fw, fh = calcSeqSize()
    frame:SetWidth(fw) ; frame:SetHeight(fh)

    local innerW = fw - PAD * 2

    -- Row 1: base buttons, evenly spaced across innerW
    -- Each button gets an equal share, guaranteed >= widest label
    local baseBtnW = math.floor((innerW - BTN_GAP * (NUM_OBJ - 1)) / NUM_OBJ)
    local minW = 0
    for i = 1, NUM_OBJ do if objWidths[i] > minW then minW = objWidths[i] end end
    if baseBtnW < minW then baseBtnW = minW end
    local y1 = -PAD

    for o, obj in ipairs(objectives) do
        local x   = PAD + (o-1) * (baseBtnW + BTN_GAP)
        local btn = makeBtn("ABCallSBase_"..o, baseBtnW, BTN_H)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y1)

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints() ; fs:SetJustifyH("CENTER")
        fs:SetText(obj.code) ; fs:SetTextColor(1, 0.82, 0)

        seqBaseFS[o] = { btn=btn, fs=fs }

        local co = o
        btn:SetScript("OnClick", function()
            selectedBase = co
            seqRefreshBaseButtons()
            seqRefreshMsgButtons()
        end)
        btn:SetScript("OnEnter", function()
            btn:SetBackdropBorderColor(1, 0.82, 0, 1)
        end)
        btn:SetScript("OnLeave", function()
            if selectedBase ~= co then
                btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
            end
        end)
    end

    -- Row 2: number buttons (1 2 3 4+)
    local r1BtnW = math.floor((innerW - BTN_GAP * (NUM_SEQR1 - 1)) / NUM_SEQR1)
    local y2 = -(PAD + BTN_H + ROW_GAP)
    for col, mi in ipairs(seqRow1) do
        local md  = messages[mi]
        local x   = PAD + (col-1) * (r1BtnW + BTN_GAP)
        local btn = makeBtn("ABCallSR1_"..col, r1BtnW, BTN_H)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y2)
        btn:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints() ; fs:SetJustifyH("CENTER")
        fs:SetText(md.label) ; fs:SetTextColor(0.3, 0.3, 0.3)
        local idx = table.getn(seqMsgBtns) + 1
        seqMsgBtns[idx] = { btn=btn, fs=fs, r=md.r, g=md.g, b=md.b }
        local cm = md
        btn:SetScript("OnClick", function()
            if not selectedBase then
                DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Pick a base first.")
                return
            end
            sendMsg(buildMsg(objectives[selectedBase], cm))
        end)
        btn:SetScript("OnEnter", function()
            if selectedBase then btn:SetBackdropBorderColor(1, 0.82, 0, 1) end
        end)
        btn:SetScript("OnLeave", function()
            btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
        end)
    end

    -- Row 3: status buttons (Safe, Help!, OMW)
    local r2BtnW = math.floor((innerW - BTN_GAP * (NUM_SEQR2 - 1)) / NUM_SEQR2)
    local y3 = -(PAD + (BTN_H + ROW_GAP) * 2)
    for col, mi in ipairs(seqRow2) do
        local md  = messages[mi]
        local x   = PAD + (col-1) * (r2BtnW + BTN_GAP)
        local btn = makeBtn("ABCallSR2_"..col, r2BtnW, BTN_H)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y3)
        btn:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints() ; fs:SetJustifyH("CENTER")
        fs:SetText(md.label) ; fs:SetTextColor(0.3, 0.3, 0.3)
        local idx = table.getn(seqMsgBtns) + 1
        seqMsgBtns[idx] = { btn=btn, fs=fs, r=md.r, g=md.g, b=md.b }
        local cm = md
        btn:SetScript("OnClick", function()
            if not selectedBase then
                DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Pick a base first.")
                return
            end
            sendMsg(buildMsg(objectives[selectedBase], cm))
        end)
        btn:SetScript("OnEnter", function()
            if selectedBase then btn:SetBackdropBorderColor(1, 0.82, 0, 1) end
        end)
        btn:SetScript("OnLeave", function()
            btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
        end)
    end
end

-- ─────────────────────────────────────────────
-- Rebuild dispatcher
-- ─────────────────────────────────────────────
local function rebuild()
    destroyChildren()
    if     layoutMode == "horizontal" then buildHorizontal()
    elseif layoutMode == "vertical"   then buildVertical()
    else                                   buildSequential() end
    frame:SetScale(frameScale)
    cornerBtn:ClearAllPoints()
    cornerBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    cornerBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
    settingsBtn:ClearAllPoints()
    settingsBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    settingsBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
end

rebuild()

cornerBtn:SetScript("OnClick", function()
    local nextLayout = { vertical="horizontal", horizontal="sequential", sequential="vertical" }
    layoutMode = nextLayout[layoutMode]
    rebuild()
    saveVars()
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Layout: " .. layoutMode)
end)
cornerBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
settingsBtn:SetFrameLevel(frame:GetFrameLevel() + 10)

-- ─────────────────────────────────────────────
-- Event handler: VARIABLES_LOADED fires before
-- PLAYER_ENTERING_WORLD, so we load prefs here
-- and do the initial rebuild with correct values.
-- ─────────────────────────────────────────────
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        loadVars()
        rebuild()   -- rebuild with loaded layout + formats

    elseif event == "PLAYER_LOGOUT" then
        saveVars()

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        if GetRealZoneText() == AB_MAP_NAME then
            manualOverride = false
            frame:Show()
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Arathi Basin detected. (/abcall to hide)")
        else
            if not manualOverride then frame:Hide() end
        end
    end
end)

-- ─────────────────────────────────────────────
-- Slash commands
-- ─────────────────────────────────────────────
SLASH_ABCALL1 = "/abcall"
SlashCmdList["ABCALL"] = function(arg)
    if arg == "reset" then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frameScale = 1.0
        frame:SetScale(frameScale)
        frame:Show()
        manualOverride = true
        saveVars()
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Frame reset to center.")
    elseif arg == "debug" then
        debugMode = not debugMode
        if debugMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Debug ON - messages print here instead of /bg.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Debug OFF.")
        end
    elseif arg == "layout" then
        local nextLayout = { vertical="horizontal", horizontal="sequential", sequential="vertical" }
        layoutMode = nextLayout[layoutMode]
        rebuild()
        saveVars()
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Layout: " .. layoutMode)
    else
        if frame:IsShown() then
            frame:Hide()
            manualOverride = false
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Hidden.")
        else
            frame:Show()
            manualOverride = true
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Shown.")
        end
    end
end