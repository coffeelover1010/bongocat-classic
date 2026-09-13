local addonName = ...
local Controller = CreateFrame("Frame", addonName .. "Controller")
local db, config
local cats = {}
local nextPaw, lastGlobalInput = 1, 0

local SIZE_NAMES = { "XS", "S", "M", "L", "XL" }
local FILL_COLOURS = {
    cream = { label = "Cream", r = 1.00, g = 0.96, b = 0.86, a = 1 },
    white = { label = "White", r = 1.00, g = 1.00, b = 1.00, a = 1 },
    grey = { label = "Grey", r = 0.82, g = 0.82, b = 0.82, a = 1 },
    none = { label = "None", r = 1.00, g = 1.00, b = 1.00, a = 0 },
}
local FILL_ORDER = { "cream", "white", "grey", "none" }
local OUTLINE_COLOURS = {
    ink = { label = "Soft black", r = 0.075, g = 0.075, b = 0.090, a = 1 },
    black = { label = "Black", r = 0.00, g = 0.00, b = 0.00, a = 1 },
    brown = { label = "Brown", r = 0.24, g = 0.16, b = 0.14, a = 1 },
    slate = { label = "Slate", r = 0.16, g = 0.19, b = 0.23, a = 1 },
}
local OUTLINE_ORDER = { "ink", "black", "brown", "slate" }
local LAYER_NAMES = { MEDIUM = "Medium", HIGH = "High", DIALOG = "Dialog", TOOLTIP = "On top" }
local LAYER_ORDER = { "MEDIUM", "HIGH", "DIALOG", "TOOLTIP" }
-- Dimensions are UI units before the target frame's effective scale is applied.
local SIZES = {
    { width = 42, height = 21 },
    { width = 56, height = 28 },
    { width = 72, height = 36 },
    { width = 88, height = 44 },
    { width = 104, height = 52 },
}
local DEFAULTS = {
    layoutVersion = 6,
    shown = true,
    locations = {
        chat = { enabled = true, size = 3, fill = "cream", outline = "ink", strata = "TOOLTIP" },
        action = { enabled = true, size = 3, locked = false, placed = false, x = 0, y = 0, fill = "cream", outline = "ink", strata = "TOOLTIP" },
    },
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff8fcbffBongoCat Classic:|r " .. message)
end

local function CopyDefaults()
    BongoCatClassicDB = BongoCatClassicDB or {}
    local migrateLayout = (BongoCatClassicDB.layoutVersion or 0) < 3
    local migrateSizes = (BongoCatClassicDB.layoutVersion or 0) < 5
    if BongoCatClassicDB.shown == nil then BongoCatClassicDB.shown = DEFAULTS.shown end
    BongoCatClassicDB.locations = BongoCatClassicDB.locations or {}
    for name, defaults in pairs(DEFAULTS.locations) do
        local location = BongoCatClassicDB.locations[name] or {}
        BongoCatClassicDB.locations[name] = location
        for key, value in pairs(defaults) do
            if migrateLayout or location[key] == nil then location[key] = value end
        end
        if migrateSizes and not migrateLayout and location.size then location.size = math.min(location.size + 1, #SIZES) end
    end
    BongoCatClassicDB.layoutVersion = DEFAULTS.layoutVersion
    db = BongoCatClassicDB
end

local function SetPose(cat, pose)
    -- 2048x512 atlas: three 512px-wide poses; the cat occupies its middle half vertically.
    local left = pose * 0.25
    cat.art:SetTexCoord(left, left + 0.25, 0.25, 0.75)
    cat.fill:SetTexCoord(left, left + 0.25, 0.25, 0.75)
end

local function ApplyCat(cat)
    local location = db.locations[cat.location]
    local size = SIZES[location.size]
    local target = cat.kind == "chat" and ChatFrame1 or MainMenuBar
    cat:SetSize(size.width, size.height)
    cat:SetFrameStrata(location.strata or "TOOLTIP")
    cat:SetFrameLevel(100)
    local fill = FILL_COLOURS[location.fill] or FILL_COLOURS.cream
    cat.fill:SetVertexColor(fill.r, fill.g, fill.b, fill.a)
    local outline = OUTLINE_COLOURS[location.outline] or OUTLINE_COLOURS.ink
    cat.art:SetVertexColor(outline.r, outline.g, outline.b, outline.a)
    -- UIParent and Blizzard frames may use different scales. Match the target's scale so
    -- a "medium" cat remains medium beside the frame it is attached to.
    cat:SetScale(target:GetEffectiveScale() / UIParent:GetEffectiveScale())
    cat:ClearAllPoints()
    if cat.kind == "chat" then
        -- Keep the chat cat's attachment point inside the chat window's lower 20% band.
        cat:SetPoint("BOTTOMLEFT", ChatFrame1, "BOTTOMLEFT", math.floor(ChatFrame1:GetWidth() * 0.04), math.floor(ChatFrame1:GetHeight() * 0.20))
    elseif location.placed then
        cat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", location.x, location.y)
    else
        -- The cat's paws overlap the upper edge of the action bar.
        cat:SetPoint("BOTTOM", MainMenuBar, "TOP", 0, 0)
    end
    if cat.kind == "action" then cat:EnableMouse(db.shown and location.enabled and not location.locked) end
    if db.shown and location.enabled then cat:Show() else cat:Hide() end
end

local function ApplyAll()
    for _, cat in pairs(cats) do ApplyCat(cat) end
end

local function CreateCat(key, location, kind)
    local cat = CreateFrame("Frame", addonName .. key, UIParent)
    cat.location, cat.kind, cat.lastHit = location, kind, 0
    cat.fill = cat:CreateTexture(nil, "BACKGROUND")
    cat.fill:SetAllPoints(cat)
    cat.fill:SetTexture("Interface\\AddOns\\BongoCatClassic\\Art\\BongoCatClassicFill.tga")
    cat.art = cat:CreateTexture(nil, "ARTWORK")
    cat.art:SetAllPoints(cat)
    cat.art:SetTexture("Interface\\AddOns\\BongoCatClassic\\Art\\BongoCatClassic.tga")
    if kind == "action" then
        cat:SetMovable(true)
        cat:EnableMouse(true)
        cat:RegisterForDrag("LeftButton")
        cat:SetScript("OnDragStart", function(self)
            if not db.locations.action.locked then self:StartMoving() end
        end)
        cat:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local scale = UIParent:GetEffectiveScale()
            db.locations.action.x = math.floor(self:GetLeft() / scale + 0.5)
            db.locations.action.y = math.floor(self:GetBottom() / scale + 0.5)
            db.locations.action.placed = true
        end)
    end
    SetPose(cat, 0)
    cats[key] = cat
end

local function Trigger(locations)
    local now = GetTime()
    nextPaw = nextPaw == 1 and 2 or 1
    for _, location in ipairs(locations) do
        if db.locations[location].enabled then
            for _, cat in pairs(cats) do
                if cat.location == location then SetPose(cat, nextPaw); cat.lastHit = now end
            end
        end
    end
end

local function TriggerGlobal()
    local now = GetTime()
    -- A short gate turns rapid input into an intentional rhythm instead of a flicker.
    if now - lastGlobalInput < 0.10 then return end
    lastGlobalInput = now
    Trigger({ "action" })
end

local function OnChatEdited(editBox)
    if editBox and editBox:HasFocus() then Trigger({ "chat" }) end
end

local function Label(parent, text, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function Checkbox(parent, text, x, y, checked, changed)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", x, y)
    box.text = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    box.text:SetPoint("LEFT", box, "RIGHT", 2, 0)
    box.text:SetText(text)
    box:SetChecked(checked)
    box:SetScript("OnClick", function(self) changed(self:GetChecked() and true or false) end)
end

local function CycleSizeButton(parent, name, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(165, 24)
    button:SetPoint("TOPLEFT", x, y)
    local function Refresh()
        button:SetText(name .. " size: " .. SIZE_NAMES[db.locations[name].size])
    end
    Refresh()
    button:SetScript("OnClick", function()
        local location = db.locations[name]
        location.size = location.size % #SIZES + 1
        Refresh()
        ApplyAll()
    end)
end

local function CycleFillButton(parent, name, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(100, 24)
    button:SetPoint("TOPLEFT", x, y)
    local function Refresh()
        button:SetText("Fill: " .. FILL_COLOURS[db.locations[name].fill].label)
    end
    Refresh()
    button:SetScript("OnClick", function()
        local location = db.locations[name]
        for index, key in ipairs(FILL_ORDER) do
            if key == location.fill then location.fill = FILL_ORDER[index % #FILL_ORDER + 1]; break end
        end
        Refresh()
        ApplyAll()
    end)
end

local function CycleLayerButton(parent, name, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(125, 24)
    button:SetPoint("TOPLEFT", x, y)
    local function Refresh()
        button:SetText("Layer: " .. LAYER_NAMES[db.locations[name].strata])
    end
    Refresh()
    button:SetScript("OnClick", function()
        local location = db.locations[name]
        for index, key in ipairs(LAYER_ORDER) do
            if key == location.strata then location.strata = LAYER_ORDER[index % #LAYER_ORDER + 1]; break end
        end
        Refresh()
        ApplyAll()
    end)
end

local function CycleOutlineButton(parent, name, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(155, 24)
    button:SetPoint("TOPLEFT", x, y)
    local function Refresh()
        button:SetText("Outline: " .. OUTLINE_COLOURS[db.locations[name].outline].label)
    end
    Refresh()
    button:SetScript("OnClick", function()
        local location = db.locations[name]
        for index, key in ipairs(OUTLINE_ORDER) do
            if key == location.outline then location.outline = OUTLINE_ORDER[index % #OUTLINE_ORDER + 1]; break end
        end
        Refresh()
        ApplyAll()
    end)
end

local function OpenConfig()
    if config then config:Show(); return end
    config = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    config:SetSize(420, 390)
    config:SetPoint("CENTER")
    config:SetFrameStrata("DIALOG")
    config:SetMovable(true); config:EnableMouse(true); config:RegisterForDrag("LeftButton")
    config:SetScript("OnDragStart", config.StartMoving)
    config:SetScript("OnDragStop", config.StopMovingOrSizing)
    config:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 11, top = 11, bottom = 11 } })
    local title = config:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18); title:SetText("BongoCat Classic placements")
    Label(config, "The chat cat stays inside the chat window's lower 20% band.", 18, -46)
    Label(config, "Chat cat — reacts to typing", 18, -78)
    Checkbox(config, "Enabled", 18, -100, db.locations.chat.enabled, function(value)
        db.locations.chat.enabled = value; ApplyAll()
    end)
    CycleSizeButton(config, "chat", 190, -102)
    CycleFillButton(config, "chat", 18, -132)
    CycleLayerButton(config, "chat", 130, -132)
    CycleOutlineButton(config, "chat", 18, -162)
    Label(config, "Action cat — reacts to player actions", 18, -204)
    Checkbox(config, "Enabled", 18, -226, db.locations.action.enabled, function(value)
        db.locations.action.enabled = value; ApplyAll()
    end)
    Checkbox(config, "Lock position", 110, -226, db.locations.action.locked, function(value)
        db.locations.action.locked = value
        ApplyAll()
    end)
    CycleSizeButton(config, "action", 238, -228)
    CycleFillButton(config, "action", 18, -258)
    CycleLayerButton(config, "action", 130, -258)
    CycleOutlineButton(config, "action", 18, -288)
    Label(config, "Drag the action cat directly; lock it when positioned.", 18, -324)
    local reset = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
    reset:SetSize(135, 22); reset:SetPoint("BOTTOMLEFT", 20, 18); reset:SetText("Reset placements")
    reset:SetScript("OnClick", function() db.locations = {}; db.layoutVersion = 0; CopyDefaults(); ApplyAll(); config:Hide(); config = nil; OpenConfig() end)
    local close = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
    close:SetSize(75, 22); close:SetPoint("BOTTOMRIGHT", -20, 18); close:SetText("Close")
    close:SetScript("OnClick", function() config:Hide() end)
end

local function Help()
    Print("Commands: |cffffffff/bc config|r, |cffffffff/bc show|hide|toggle|r, |cffffffff/bc test|r, |cffffffff/bc reset|r, |cffffffff/bc credits|r")
end

SLASH_BONGOCATCLASSIC1, SLASH_BONGOCATCLASSIC2 = "/bongocat", "/bc"
SlashCmdList.BONGOCATCLASSIC = function(message)
    local command = (message:match("^(%S*)") or ""):lower()
    if command == "config" or command == "options" then OpenConfig()
    elseif command == "show" then db.shown = true; ApplyAll(); Print("shown.")
    elseif command == "hide" then db.shown = false; ApplyAll(); Print("hidden.")
    elseif command == "toggle" then db.shown = not db.shown; ApplyAll(); Print(db.shown and "shown." or "hidden.")
    elseif command == "reset" then db.locations = {}; CopyDefaults(); ApplyAll(); Print("placements reset.")
    elseif command == "test" then Trigger({ "chat", "action" }); Print("bop!")
    elseif command == "credits" then Print("Kitgore icon-font artwork used under MIT; see THIRD_PARTY_NOTICES.md.")
    else Help() end
end

Controller:RegisterEvent("PLAYER_LOGIN")
Controller:RegisterEvent("PLAYER_STARTED_MOVING")
Controller:RegisterEvent("PLAYER_TARGET_CHANGED")
Controller:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
Controller:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        CopyDefaults()
        CreateCat("Chat", "chat", "chat")
        CreateCat("Action", "action", "action")
        ApplyAll()
        if type(ChatEdit_OnTextChanged) == "function" then hooksecurefunc("ChatEdit_OnTextChanged", OnChatEdited) end
        Print("loaded. Use /bc config to place and size cats.")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" then TriggerGlobal() end
    else
        TriggerGlobal()
    end
end)

Controller:SetScript("OnUpdate", function()
    local now = GetTime()
    for _, cat in pairs(cats) do
        if cat.lastHit > 0 and now - cat.lastHit > 0.18 then SetPose(cat, 0); cat.lastHit = 0 end
    end
end)
