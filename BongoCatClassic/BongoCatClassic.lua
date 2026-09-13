local addonName = ...
local Controller = CreateFrame("Frame", addonName .. "Controller")
local db, config
local cats = {}
local nextPaw, lastGlobalInput = 1, 0

local SIZE_NAMES = { "Small", "Medium", "Large" }
-- Dimensions are UI units before the target frame's effective scale is applied.
local SIZES = { { width = 72, height = 36 }, { width = 108, height = 54 }, { width = 150, height = 75 } }
local DEFAULTS = {
    layoutVersion = 3,
    shown = true,
    locations = {
        chat = { enabled = true, size = 2 },
        action = { enabled = true, size = 2, locked = false, placed = false, x = 0, y = 0 },
    },
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff8fcbffBongoCat Classic:|r " .. message)
end

local function CopyDefaults()
    BongoCatClassicDB = BongoCatClassicDB or {}
    local migrateLayout = BongoCatClassicDB.layoutVersion ~= DEFAULTS.layoutVersion
    if BongoCatClassicDB.shown == nil then BongoCatClassicDB.shown = DEFAULTS.shown end
    BongoCatClassicDB.locations = BongoCatClassicDB.locations or {}
    for name, defaults in pairs(DEFAULTS.locations) do
        local location = BongoCatClassicDB.locations[name] or {}
        BongoCatClassicDB.locations[name] = location
        for key, value in pairs(defaults) do
            if migrateLayout or location[key] == nil then location[key] = value end
        end
    end
    BongoCatClassicDB.layoutVersion = DEFAULTS.layoutVersion
    db = BongoCatClassicDB
end

local function SetPose(cat, pose)
    -- 2048x512 atlas: three 512px-wide poses; the cat occupies its middle half vertically.
    local left = pose * 0.25
    cat.art:SetTexCoord(left, left + 0.25, 0.25, 0.75)
end

local function ApplyCat(cat)
    local location = db.locations[cat.location]
    local size = SIZES[location.size]
    local target = cat.kind == "chat" and ChatFrame1 or MainMenuBar
    cat:SetSize(size.width, size.height)
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
    if db.shown and location.enabled then cat:Show() else cat:Hide() end
end

local function ApplyAll()
    for _, cat in pairs(cats) do ApplyCat(cat) end
end

local function CreateCat(key, location, kind)
    local cat = CreateFrame("Frame", addonName .. key, UIParent)
    cat.location, cat.kind, cat.lastHit = location, kind, 0
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
        location.size = location.size % 3 + 1
        Refresh()
        ApplyAll()
    end)
end

local function OpenConfig()
    if config then config:Show(); return end
    config = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    config:SetSize(420, 260)
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
    Label(config, "Action cat — reacts to player actions", 18, -138)
    Checkbox(config, "Enabled", 18, -160, db.locations.action.enabled, function(value)
        db.locations.action.enabled = value; ApplyAll()
    end)
    Checkbox(config, "Lock position", 110, -160, db.locations.action.locked, function(value)
        db.locations.action.locked = value
    end)
    CycleSizeButton(config, "action", 238, -162)
    Label(config, "Drag the action cat directly; lock it here when positioned.", 18, -196)
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
