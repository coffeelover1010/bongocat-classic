local addonName = ...
local Controller = CreateFrame("Frame", addonName .. "Controller")
local db, config
local cats = {}
local nextPaw, lastGlobalInput = 1, 0

local SIZE_NAMES = { "Small", "Medium", "Large" }
local SIZES = { { width = 140, height = 70 }, { width = 220, height = 110 }, { width = 300, height = 150 } }
local DEFAULTS = {
    shown = true,
    locations = {
        chat = { enabled = true, size = 2, x = 0, y = -18 },
        action = { enabled = true, size = 2, x = 0, y = 2 },
        corners = { enabled = true, size = 1, x = 0, y = 0 },
    },
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff8fcbffBongoCat Classic:|r " .. message)
end

local function CopyDefaults()
    BongoCatClassicDB = BongoCatClassicDB or {}
    if BongoCatClassicDB.shown == nil then BongoCatClassicDB.shown = DEFAULTS.shown end
    BongoCatClassicDB.locations = BongoCatClassicDB.locations or {}
    for name, defaults in pairs(DEFAULTS.locations) do
        local location = BongoCatClassicDB.locations[name] or {}
        BongoCatClassicDB.locations[name] = location
        for key, value in pairs(defaults) do
            if location[key] == nil then location[key] = value end
        end
    end
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
    cat:SetSize(size.width, size.height)
    cat:ClearAllPoints()
    if cat.kind == "chat" then
        cat:SetPoint("BOTTOMLEFT", ChatFrame1, "BOTTOMLEFT", location.x, location.y)
    elseif cat.kind == "action" then
        -- The cat's paws overlap the upper edge of the action bar.
        cat:SetPoint("BOTTOM", MainMenuBar, "TOP", location.x, location.y)
    elseif cat.kind == "cornerLeft" then
        cat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 8 + location.x, 8 + location.y)
    else
        cat:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -8 + location.x, 8 + location.y)
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
    Trigger({ "action", "corners" })
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

local function Slider(parent, x, y, text, minimum, maximum, step, changed)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(165)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.label = Label(parent, text, x, y + 13)
    slider.value = Label(parent, "", x + 172, y + 13)
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        self.value:SetText(value)
        if self.ready then changed(value) end
    end)
    return slider
end

local function LocationControls(parent, title, name, y)
    local location = db.locations[name]
    Label(parent, title, 18, y)
    local enabled = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", 18, y - 22)
    enabled.text = enabled:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    enabled.text:SetPoint("LEFT", enabled, "RIGHT", 2, 0)
    enabled.text:SetText("Enabled")
    enabled:SetChecked(location.enabled)
    enabled:SetScript("OnClick", function(self) location.enabled = self:GetChecked() and true or false; ApplyAll() end)

    local size
    size = Slider(parent, 170, y - 24, "Size", 1, 3, 1, function(value)
        location.size = value; size.value:SetText(SIZE_NAMES[value]); ApplyAll()
    end)
    size.ready = false; size:SetValue(location.size); size.value:SetText(SIZE_NAMES[location.size]); size.ready = true

    local offsetX = Slider(parent, 18, y - 58, "Horizontal offset", -100, 100, 1, function(value)
        location.x = value; ApplyAll()
    end)
    offsetX.ready = false; offsetX:SetValue(location.x); offsetX.ready = true
    local offsetY = Slider(parent, 230, y - 58, "Vertical offset", -100, 100, 1, function(value)
        location.y = value; ApplyAll()
    end)
    offsetY.ready = false; offsetY:SetValue(location.y); offsetY.ready = true
end

local function OpenConfig()
    if config then config:Show(); return end
    config = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    config:SetSize(450, 390)
    config:SetPoint("CENTER")
    config:SetFrameStrata("DIALOG")
    config:SetMovable(true); config:EnableMouse(true); config:RegisterForDrag("LeftButton")
    config:SetScript("OnDragStart", config.StartMoving)
    config:SetScript("OnDragStop", config.StopMovingOrSizing)
    config:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 11, top = 11, bottom = 11 } })
    local title = config:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18); title:SetText("BongoCat Classic placements")
    Label(config, "Paws overlap their target. Drag this panel by its border.", 18, -46)
    LocationControls(config, "Chat cat — reacts to typing", "chat", -74)
    LocationControls(config, "Action-bar cat — reacts to player actions", "action", -178)
    LocationControls(config, "Corner cats — react to player actions", "corners", -282)
    local reset = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
    reset:SetSize(110, 22); reset:SetPoint("BOTTOMLEFT", 20, 18); reset:SetText("Reset defaults")
    reset:SetScript("OnClick", function() db.locations = {}; CopyDefaults(); ApplyAll(); config:Hide(); config = nil; OpenConfig() end)
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
    elseif command == "test" then Trigger({ "chat", "action", "corners" }); Print("bop!")
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
        CreateCat("CornerLeft", "corners", "cornerLeft")
        CreateCat("CornerRight", "corners", "cornerRight")
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
