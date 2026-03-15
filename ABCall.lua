-- ABCall: Arathi Basin Callout Addon
-- Compatible with WoW 1.12 / Turtle WoW (Lua 5.0)
-- /abcall        - toggle show/hide
-- /abcall layout - toggle horizontal/vertical layout

local AB_MAP_NAME = "Arathi Basin"

local objectives = {
    { name = "Stables",     code = "ST" },
    { name = "Lumber Mill", code = "LM" },
    { name = "Blacksmith",  code = "BS" },
    { name = "Gold Mine",   code = "GM" },
    { name = "Farm",        code = "FM" },
}

local messages = {
    { label = "Safe",  msg = "Safe.",       r=0.4, g=1,   b=0.4 },
    { label = "1",     msg = "1 inc.",      r=1,   g=1,   b=1   },
    { label = "2",     msg = "2 inc.",      r=1,   g=1,   b=1   },
    { label = "3",     msg = "3 inc.",      r=1,   g=0.8, b=0.2 },
    { label = "4+",    msg = "4+ inc.",     r=1,   g=0.5, b=0   },
    { label = "BIG",   msg = "BIG inc!",    r=1,   g=0.2, b=0.2 },
    { label = "Help!", msg = "Help!",       r=1,   g=0.2, b=0.2 },
    { label = "NDef",  msg = "Undefended!", r=1,   g=0.7, b=0   },
    { label = "OMW",   msg = "OMW.",        r=0.4, g=1,   b=0.4 },
}

-- Vertical layout row definitions
-- single: one button per column cell, fills cell width
-- multi:  several mini-buttons packed naturally, centred in cell
local vertRows = {
    { type="single", msgIndex=1 },
    { type="multi",  msgs={2,3} },
    { type="multi",  msgs={4,5} },
    { type="single", msgIndex=6 },
    { type="single", msgIndex=7 },
    { type="single", msgIndex=8 },
    { type="single", msgIndex=9 },
}

local manualOverride = false
local layoutMode     = "vertical"

local NUM_OBJ  = table.getn(objectives)
local NUM_MSG  = table.getn(messages)
local NUM_VROW = table.getn(vertRows)

-- ─────────────────────────────────────────────
-- Layout constants
-- ─────────────────────────────────────────────
local BTN_H     = 14
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

-- Natural width of a vertical row's content
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

-- Column width = max of obj header and every row's natural content width
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

-- ─────────────────────────────────────────────
-- Main frame
-- ─────────────────────────────────────────────
local frame = CreateFrame("Frame", "ABCallFrame", UIParent)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    tile = true, tileSize = 32, edgeSize = 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
})
frame:SetBackdropColor(0, 0, 0, 0.88)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() frame:StartMoving() end)
frame:SetScript("OnDragStop",  function() frame:StopMovingOrSizing() end)
frame:Hide()

-- ─────────────────────────────────────────────
-- Layout toggle hotzone (tiny corner tab, top-right)
-- ─────────────────────────────────────────────
local cornerBtn = CreateFrame("Button", "ABCallCorner", frame)
cornerBtn:SetWidth(6)
cornerBtn:SetHeight(6)
cornerBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
cornerBtn:SetBackdrop({
    bgFile  = "Interface\Buttons\WHITE8X8",
    edgeSize = 0,
    insets   = { left=0, right=0, top=0, bottom=0 },
})
cornerBtn:SetBackdropColor(1, 0.82, 0, 0.35)
cornerBtn:SetScript("OnEnter", function()
    cornerBtn:SetBackdropColor(1, 0.82, 0, 1)
end)
cornerBtn:SetScript("OnLeave", function()
    cornerBtn:SetBackdropColor(1, 0.82, 0, 0.35)
end)
-- rebuild is defined later; we wire OnClick after rebuild is declared

-- ─────────────────────────────────────────────
-- Highlight
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
    children = {}
    objHeaderFS = {}
    for o = 1, NUM_OBJ do cellFS[o] = {} end
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

local function buildMsg(obj, md)
    local loc = obj.code
    if obj.code == "FM" then loc = "FARM" end
    if md.label == "OMW" then      return "OMW " .. loc
    elseif md.label == "Help!" then return "Help " .. loc .. "!"
    else                            return loc .. " " .. md.msg end
end

local function attachBtn(btn, obj, md, co)
    local cm = md
    btn:SetScript("OnClick", function()
        SendChatMessage(buildMsg(obj, cm), "BATTLEGROUND")
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
-- Each cell is sized to its content, no padding.
-- Single-row buttons stretch to column width.
-- Multi-row buttons are individually sized and packed tight.
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

        -- Header
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
                -- Stretch to full column width
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
                -- Two buttons per row, each gets exactly half the column
                -- minus the centre gap. This keeps all multi-rows aligned.
                local half  = math.floor((cw - BTN_GAP) / 2)
                local xpos  = { cx, cx + half + BTN_GAP }

                for idx, mi in ipairs(row.msgs) do
                    local md  = messages[mi]
                    local bw  = half  -- each button fills its half
                    local btn = makeBtn("ABCallVMul_"..o.."_"..vr.."_"..idx, bw, BTN_H)
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
-- Rebuild dispatcher
-- ─────────────────────────────────────────────
local function rebuild()
    destroyChildren()
    if layoutMode == "horizontal" then buildHorizontal()
    else                               buildVertical() end
end

rebuild()

cornerBtn:SetScript("OnClick", function()
    layoutMode = (layoutMode == "horizontal") and "vertical" or "horizontal"
    rebuild()
    -- Re-anchor corner to new frame size
    cornerBtn:ClearAllPoints()
    cornerBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    cornerBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Layout: " .. layoutMode)
end)
cornerBtn:SetFrameLevel(frame:GetFrameLevel() + 10)

-- ─────────────────────────────────────────────
-- Zone detection
-- ─────────────────────────────────────────────
local zoneWatcher = CreateFrame("Frame")
zoneWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneWatcher:SetScript("OnEvent", function()
    if GetRealZoneText() == AB_MAP_NAME then
        manualOverride = false
        frame:Show()
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700ABCall:|r Arathi Basin detected. (/abcall to hide)")
    else
        if not manualOverride then frame:Hide() end
    end
end)

-- ─────────────────────────────────────────────
-- Slash commands
-- ─────────────────────────────────────────────
SLASH_ABCALL1 = "/abcall"
SlashCmdList["ABCALL"] = function(arg)
    if arg == "layout" then
        layoutMode = (layoutMode == "horizontal") and "vertical" or "horizontal"
        rebuild()
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