local addonName = ...
local Controller = CreateFrame("Frame", addonName .. "Controller")
local db, config
local actionTriggersExpanded = false
local cats = {}
local nextPaw, lastGlobalInput = 1, 0
local globalSequence = { remaining = 0, nextAt = 0 }
local spellSequence = { remaining = 0, nextAt = 0 }
local startedSpellCasts = {}
local activeLocation = "chat"

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
local LAYER_NAMES = {
    BACKGROUND = "Background",
    LOW = "Low",
    MEDIUM = "Medium",
    HIGH = "High",
    DIALOG = "Dialog",
    FULLSCREEN = "Fullscreen",
    FULLSCREEN_DIALOG = "Fullscreen dialog",
    TOOLTIP = "On top",
}
local LAYER_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local FADE_DELAYS = { 1, 2, 5, 10 }
local FADE_DURATIONS = { 0.25, 0.5, 1.0, 2.0 }
local SEQUENCE_STEPS = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
local SEQUENCE_INTERVALS = { 0.08, 0.12, 0.16, 0.20 }
local ACTION_TRIGGER_DEFAULTS = {
    actionBar = true, castStart = true, castSuccess = true, channelStart = true,
    combat = true, enterCombat = true, movement = true, turning = true,
    targetChange = true, equipment = true, bags = true,
}
-- Dimensions are UI units before the target frame's effective scale is applied.
local SIZES = {
    { width = 42, height = 21 },
    { width = 56, height = 28 },
    { width = 72, height = 36 },
    { width = 88, height = 44 },
    { width = 104, height = 52 },
}
local DEFAULTS = {
    layoutVersion = 7,
    shown = true,
    fade = { enabled = true, delay = 5, duration = 0.5 },
    actionSequence = { minimum = 5, maximum = 5, interval = 0.12 },
    actionTriggers = ACTION_TRIGGER_DEFAULTS,
    locations = {
        chat = { enabled = true, onlyWhileEditing = false, size = 3, locked = false, x = 0, y = 0, fill = "cream", outline = "ink", strata = "TOOLTIP" },
        action = { enabled = true, size = 3, locked = false, placed = false, x = 0, y = 0, fill = "cream", outline = "ink", strata = "TOOLTIP" },
        spell = { enabled = true, size = 2, fill = "cream", outline = "ink", strata = "TOOLTIP" },
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
    BongoCatClassicDB.fade = BongoCatClassicDB.fade or {}
    for key, value in pairs(DEFAULTS.fade) do
        if BongoCatClassicDB.fade[key] == nil then BongoCatClassicDB.fade[key] = value end
    end
    BongoCatClassicDB.actionSequence = BongoCatClassicDB.actionSequence or {}
    if BongoCatClassicDB.actionSequence.steps then
        BongoCatClassicDB.actionSequence.minimum = BongoCatClassicDB.actionSequence.steps
        BongoCatClassicDB.actionSequence.maximum = BongoCatClassicDB.actionSequence.steps
        BongoCatClassicDB.actionSequence.steps = nil
    end
    if BongoCatClassicDB.actionSequence.minimum == nil then BongoCatClassicDB.actionSequence.minimum = DEFAULTS.actionSequence.minimum end
    if BongoCatClassicDB.actionSequence.maximum == nil then BongoCatClassicDB.actionSequence.maximum = DEFAULTS.actionSequence.maximum end
    if BongoCatClassicDB.actionSequence.interval == nil then BongoCatClassicDB.actionSequence.interval = DEFAULTS.actionSequence.interval end
    if BongoCatClassicDB.actionSequence.interval > 0.20 then BongoCatClassicDB.actionSequence.interval = 0.20 end
    BongoCatClassicDB.actionTriggers = BongoCatClassicDB.actionTriggers or {}
    for key, value in pairs(ACTION_TRIGGER_DEFAULTS) do
        if BongoCatClassicDB.actionTriggers[key] == nil then BongoCatClassicDB.actionTriggers[key] = value end
    end
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

local function ClampChatLocation(location, size)
    -- The draggable chat cat may occupy the entire chat frame plus a 20% margin on every side.
    local marginX = ChatFrame1:GetWidth() * 0.20
    local marginY = ChatFrame1:GetHeight() * 0.20
    location.x = math.max(-marginX, math.min(ChatFrame1:GetWidth() + marginX - size.width, location.x or 0))
    location.y = math.max(-marginY, math.min(ChatFrame1:GetHeight() + marginY - size.height, location.y or 0))
end

local function ChatInputOpen()
    for index = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame" .. index .. "EditBox"]
        if editBox and editBox:IsShown() then return true end
    end
    return false
end

local function CastingBar()
    return CastingBarFrame or PlayerCastingBarFrame or UIParent
end

local function ApplyCat(cat)
    local location = db.locations[cat.location]
    local size = SIZES[location.size]
    local textureSize = SIZE_NAMES[location.size]
    local target = cat.kind == "chat" and ChatFrame1 or (cat.kind == "spell" and CastingBar() or MainMenuBar)
    cat:SetSize(size.width, size.height)
    cat.fill:SetTexture("Interface\\AddOns\\BongoCatClassic\\Art\\BongoCatClassicFill-" .. textureSize .. ".tga")
    cat.art:SetTexture("Interface\\AddOns\\BongoCatClassic\\Art\\BongoCatClassic-" .. textureSize .. ".tga")
    cat:SetFrameStrata(location.strata or "TOOLTIP")
    cat:SetFrameLevel(cat.kind == "spell" and target:GetFrameLevel() + 10 or 100)
    cat:SetAlpha(1)
    local fill = location.fillColour or FILL_COLOURS[location.fill] or FILL_COLOURS.cream
    cat.fill:SetVertexColor(fill.r, fill.g, fill.b, fill.a)
    local outline = location.outlineColour or OUTLINE_COLOURS[location.outline] or OUTLINE_COLOURS.ink
    cat.art:SetVertexColor(outline.r, outline.g, outline.b, outline.a)
    -- UIParent and Blizzard frames may use different scales. Match the target's scale so
    -- a "medium" cat remains medium beside the frame it is attached to.
    cat:SetScale(target:GetEffectiveScale() / UIParent:GetEffectiveScale())
    cat:ClearAllPoints()
    if cat.kind == "chat" then
        ClampChatLocation(location, size)
        -- Anchor to the chat frame after clamping to its padded drag area.
        cat:SetPoint("BOTTOMLEFT", ChatFrame1, "BOTTOMLEFT", location.x, location.y)
    elseif cat.kind == "spell" then
        local icon = target.Icon or target.icon or target
        -- Keep the paws and bongo directly over the spell image at the start of the cast bar.
        cat:SetPoint("CENTER", icon, "CENTER", 0, 0)
    elseif location.placed then
        cat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", location.x, location.y)
    else
        -- The cat's paws overlap the upper edge of the action bar.
        cat:SetPoint("BOTTOM", MainMenuBar, "TOP", 0, 0)
    end
    if cat.kind == "chat" or cat.kind == "action" then cat:EnableMouse(db.shown and location.enabled and not location.locked) end
    local conditionalChatHidden = cat.location == "chat" and location.onlyWhileEditing and not ChatInputOpen()
    local previewingConfig = config and config:IsShown()
    if previewingConfig or (db.shown and location.enabled and cat.location == activeLocation and not conditionalChatHidden) then cat:Show() else cat:Hide() end
end

local function ApplyAll()
    for _, cat in pairs(cats) do ApplyCat(cat) end
end

local function CreateCat(key, location, kind)
    local cat = CreateFrame("Frame", addonName .. key, UIParent)
    cat.location, cat.kind, cat.lastHit, cat.lastActivity = location, kind, 0, GetTime()
    cat.fill = cat:CreateTexture(nil, "BACKGROUND")
    cat.fill:SetAllPoints(cat)
    cat.fill:SetTexture("Interface\\AddOns\\BongoCatClassic\\Art\\BongoCatClassicFill.tga")
    cat.art = cat:CreateTexture(nil, "ARTWORK")
    cat.art:SetAllPoints(cat)
    cat.art:SetTexture("Interface\\AddOns\\BongoCatClassic\\Art\\BongoCatClassic.tga")
    if kind == "spell" then
        cat.spellIcon = cat:CreateTexture(nil, "BACKGROUND", nil, -1)
        cat.spellIcon:SetPoint("CENTER", cat, "CENTER")
        cat.spellIcon:SetSize(28, 28)
        cat.spellIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    if kind == "chat" or kind == "action" then
        cat:SetMovable(true)
        cat:EnableMouse(true)
        cat:RegisterForDrag("LeftButton")
        cat:SetScript("OnDragStart", function(self)
            if not db.locations[self.location].locked then
                self.dragging = true
                self.lastActivity = GetTime()
                self:SetAlpha(1)
                self:StartMoving()
            end
        end)
        cat:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self.dragging = false
            self.lastActivity = GetTime()
            local location = db.locations[self.location]
            if self.kind == "chat" then
                local scale = ChatFrame1:GetEffectiveScale()
                local x = (self:GetLeft() - ChatFrame1:GetLeft()) / scale
                local y = (self:GetBottom() - ChatFrame1:GetBottom()) / scale
                location.x = x
                location.y = y
                ClampChatLocation(location, SIZES[location.size])
                ApplyCat(self)
            else
                local scale = UIParent:GetEffectiveScale()
                location.x = math.floor(self:GetLeft() / scale + 0.5)
                location.y = math.floor(self:GetBottom() / scale + 0.5)
                location.placed = true
            end
        end)
    end
    SetPose(cat, 0)
    cats[key] = cat
end

local function Trigger(locations, fromSequence)
    local now = GetTime()
    nextPaw = nextPaw == 1 and 2 or 1
    for _, location in ipairs(locations) do
        if not fromSequence then
            activeLocation = location
            ApplyAll()
        end
        if db.locations[location].enabled then
            for _, cat in pairs(cats) do
                if cat.location == location then SetPose(cat, nextPaw); cat.lastHit = now end
                if cat.location == location then
                    cat.lastActivity = now
                    cat:SetAlpha(1)
                    if (cat.kind == "action" or cat.kind == "chat") and not db.locations[cat.location].locked then cat:EnableMouse(true) end
                end
            end
        end
    end
end

local function TriggerGlobal(condition)
    if condition and not db.actionTriggers[condition] then return end
    local now = GetTime()
    -- A short gate turns rapid input into an intentional rhythm instead of a flicker.
    if now - lastGlobalInput < 0.10 then return end
    lastGlobalInput = now
    Trigger({ "action" })
    local steps = math.random(db.actionSequence.minimum, db.actionSequence.maximum)
    globalSequence.remaining = math.max(globalSequence.remaining, steps - 1)
    globalSequence.nextAt = now + db.actionSequence.interval
end

local function TriggerSpell(spellID)
    if not db.locations.spell.enabled then return end
    local now = GetTime()
    local texture = spellID and GetSpellTexture(spellID)
    for _, cat in pairs(cats) do
        if cat.location == "spell" and cat.spellIcon then
            cat.spellIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            cat.spellIcon:SetSize(SIZES[db.locations.spell.size].height, SIZES[db.locations.spell.size].height)
        end
    end
    Trigger({ "spell" })
    local steps = math.random(db.actionSequence.minimum, db.actionSequence.maximum)
    spellSequence.remaining = math.max(spellSequence.remaining, steps - 1)
    spellSequence.nextAt = now + db.actionSequence.interval
end

local function OnChatEdited(editBox)
    if editBox and editBox:HasFocus() then Trigger({ "chat" }) end
end

local function HookChatEditBoxes()
    -- Direct edit-box hooks are more reliable across Classic UI versions than relying on
    -- the ChatEdit_OnTextChanged helper being invoked as a global function.
    for index = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame" .. index .. "EditBox"]
        if editBox and not editBox.BongoCatClassicHooked then
            editBox.BongoCatClassicHooked = true
            editBox:HookScript("OnTextChanged", function(self, userInput)
                if userInput and self:HasFocus() then Trigger({ "chat" }) end
            end)
            editBox:HookScript("OnShow", function()
                if db.locations.chat.onlyWhileEditing then
                    activeLocation = "chat"
                    local now = GetTime()
                    for _, cat in pairs(cats) do
                        if cat.location == "chat" then
                            cat.lastActivity = now
                            cat:SetAlpha(1)
                        end
                    end
                    ApplyAll()
                end
            end)
            editBox:HookScript("OnHide", function()
                if db.locations.chat.onlyWhileEditing then ApplyAll() end
            end)
        end
    end
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

local function ColourButton(parent, name, key, fallback, text, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(135, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", function()
        local location = db.locations[name]
        local current = location[key] or fallback
        local original = { r = current.r, g = current.g, b = current.b, a = current.a }
        local function Changed()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            location[key] = { r = r, g = g, b = b, a = ColorPickerFrame:GetColorAlpha() }
            ApplyAll()
        end
        local function Cancelled()
            location[key] = original
            ApplyAll()
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = current.r, g = current.g, b = current.b, opacity = current.a,
                hasOpacity = true, swatchFunc = Changed, opacityFunc = Changed, cancelFunc = Cancelled,
            })
        else
            ColorPickerFrame:SetColorRGB(current.r, current.g, current.b)
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacity = current.a
            ColorPickerFrame.func = Changed
            ColorPickerFrame.opacityFunc = Changed
            ColorPickerFrame.cancelFunc = Cancelled
            ColorPickerFrame:Show()
        end
    end)
end

local function CycleFadeButton(parent, x, y, label, values, key, suffix)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(155, 24)
    button:SetPoint("TOPLEFT", x, y)
    local function Refresh()
        button:SetText(label .. ": " .. db.fade[key] .. suffix)
    end
    Refresh()
    button:SetScript("OnClick", function()
        for index, value in ipairs(values) do
            if value == db.fade[key] then db.fade[key] = values[index % #values + 1]; break end
        end
        Refresh()
    end)
end

local function FadeModeButton(parent, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(155, 24)
    button:SetPoint("TOPLEFT", x, y)
    local function Refresh()
        button:SetText(db.fade.enabled and "Fade: enabled" or "Fade: none")
    end
    Refresh()
    button:SetScript("OnClick", function()
        db.fade.enabled = not db.fade.enabled
        if not db.fade.enabled then for _, cat in pairs(cats) do cat:SetAlpha(1) end end
        Refresh()
    end)
end

local function CycleSequenceButton(parent, x, y, key, label)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(150, 24)
    button:SetPoint("TOPLEFT", x, y)
    local function Refresh()
        button:SetText(label .. ": " .. db.actionSequence[key])
    end
    Refresh()
    button:SetScript("OnClick", function()
        for index, value in ipairs(SEQUENCE_STEPS) do
            if value == db.actionSequence[key] then
                db.actionSequence[key] = SEQUENCE_STEPS[index % #SEQUENCE_STEPS + 1]
                break
            end
        end
        if db.actionSequence.minimum > db.actionSequence.maximum then
            if key == "minimum" then db.actionSequence.maximum = db.actionSequence.minimum else db.actionSequence.minimum = db.actionSequence.maximum end
        end
        Refresh()
    end)
end

local function CycleSequenceIntervalButton(parent, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(150, 24)
    button:SetPoint("TOPLEFT", x, y)
    local function Refresh()
        button:SetText(string.format("Tap interval: %.2fs", db.actionSequence.interval))
    end
    Refresh()
    button:SetScript("OnClick", function()
        for index, value in ipairs(SEQUENCE_INTERVALS) do
            if value == db.actionSequence.interval then
                db.actionSequence.interval = SEQUENCE_INTERVALS[index % #SEQUENCE_INTERVALS + 1]
                break
            end
        end
        Refresh()
    end)
end

local function OpenConfig()
    if config then
        config:Show()
        for _, cat in pairs(cats) do cat:SetAlpha(1) end
        return
    end
    config = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    config:SetSize(420, actionTriggersExpanded and 360 or 550)
    config:SetPoint("CENTER")
    config:SetFrameStrata("DIALOG")
    config:SetScript("OnShow", function()
        for _, cat in pairs(cats) do cat:SetAlpha(1) end
        ApplyAll()
    end)
    config:SetScript("OnHide", function() ApplyAll() end)
    config:SetMovable(true); config:EnableMouse(true); config:RegisterForDrag("LeftButton")
    config:SetScript("OnDragStart", config.StartMoving)
    config:SetScript("OnDragStop", config.StopMovingOrSizing)
    config:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 11, top = 11, bottom = 11 } })
    local title = config:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18); title:SetText("BongoCat Classic placements")
    if actionTriggersExpanded then
        local triggerToggle = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
        triggerToggle:SetSize(190, 22); triggerToggle:SetPoint("TOPLEFT", 18, -52)
        triggerToggle:SetText("Action-cat triggers: hide")
        triggerToggle:SetScript("OnClick", function()
            actionTriggersExpanded = false
            config:Hide(); config = nil; OpenConfig()
        end)
        Label(config, "Other settings are collapsed while editing triggers.", 18, -80)
        Checkbox(config, "Action bar use", 18, -102, db.actionTriggers.actionBar, function(value) db.actionTriggers.actionBar = value end)
        Checkbox(config, "Spell cast starts", 18, -126, db.actionTriggers.castStart, function(value) db.actionTriggers.castStart = value end)
        Checkbox(config, "Spell cast completes", 18, -150, db.actionTriggers.castSuccess, function(value) db.actionTriggers.castSuccess = value end)
        Checkbox(config, "Channel starts", 18, -174, db.actionTriggers.channelStart, function(value) db.actionTriggers.channelStart = value end)
        Checkbox(config, "Combat damage", 18, -198, db.actionTriggers.combat, function(value) db.actionTriggers.combat = value end)
        Checkbox(config, "Enter combat", 18, -222, db.actionTriggers.enterCombat, function(value) db.actionTriggers.enterCombat = value end)
        Checkbox(config, "Movement", 200, -102, db.actionTriggers.movement, function(value) db.actionTriggers.movement = value end)
        Checkbox(config, "Turning", 200, -126, db.actionTriggers.turning, function(value) db.actionTriggers.turning = value end)
        Checkbox(config, "Target changes", 200, -150, db.actionTriggers.targetChange, function(value) db.actionTriggers.targetChange = value end)
        Checkbox(config, "Equipment changes", 200, -174, db.actionTriggers.equipment, function(value) db.actionTriggers.equipment = value end)
        Checkbox(config, "Bag updates", 200, -198, db.actionTriggers.bags, function(value) db.actionTriggers.bags = value end)
        local close = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
        close:SetSize(75, 22); close:SetPoint("BOTTOMRIGHT", -20, 18); close:SetText("Close")
        close:SetScript("OnClick", function() config:Hide() end)
        ApplyAll()
        return
    end
    Label(config, "Chat cat — reacts to typing", 18, -52)
    Checkbox(config, "Enabled", 18, -74, db.locations.chat.enabled, function(value)
        db.locations.chat.enabled = value; ApplyAll()
    end)
    Checkbox(config, "Lock position", 110, -74, db.locations.chat.locked, function(value)
        db.locations.chat.locked = value; ApplyAll()
    end)
    CycleSizeButton(config, "chat", 238, -76)
    Checkbox(config, "Only while input is open", 18, -104, db.locations.chat.onlyWhileEditing, function(value)
        db.locations.chat.onlyWhileEditing = value; ApplyAll()
    end)
    ColourButton(config, "chat", "fillColour", FILL_COLOURS.cream, "Fill colour", 18, -134)
    ColourButton(config, "chat", "outlineColour", OUTLINE_COLOURS.ink, "Outline colour", 160, -134)
    CycleLayerButton(config, "chat", 18, -164)
    Label(config, "Action cat — reacts to player actions", 18, -206)
    Checkbox(config, "Enabled", 18, -228, db.locations.action.enabled, function(value)
        db.locations.action.enabled = value; ApplyAll()
    end)
    Checkbox(config, "Lock position", 110, -228, db.locations.action.locked, function(value)
        db.locations.action.locked = value
        ApplyAll()
    end)
    CycleSizeButton(config, "action", 238, -230)
    ColourButton(config, "action", "fillColour", FILL_COLOURS.cream, "Fill colour", 18, -260)
    ColourButton(config, "action", "outlineColour", OUTLINE_COLOURS.ink, "Outline colour", 160, -260)
    CycleLayerButton(config, "action", 18, -290)
    Checkbox(config, "Spell cat enabled", 220, -290, db.locations.spell.enabled, function(value)
        db.locations.spell.enabled = value; ApplyAll()
    end)
    local triggerToggle = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
    triggerToggle:SetSize(190, 22); triggerToggle:SetPoint("TOPLEFT", 18, -318)
    triggerToggle:SetText(actionTriggersExpanded and "Action-cat triggers: hide" or "Action-cat triggers: show")
    triggerToggle:SetScript("OnClick", function()
        actionTriggersExpanded = not actionTriggersExpanded
        config:Hide(); config = nil; OpenConfig()
    end)
    local lowerControlsY = -354
    Label(config, "Drag either cat directly; lock it when positioned.", 18, lowerControlsY)
    FadeModeButton(config, 18, lowerControlsY - 30)
    CycleFadeButton(config, 18, lowerControlsY - 60, "Fade delay", FADE_DELAYS, "delay", "s")
    CycleFadeButton(config, 190, lowerControlsY - 60, "Fade time", FADE_DURATIONS, "duration", "s")
    CycleSequenceButton(config, 18, lowerControlsY - 90, "minimum", "Sequence min")
    CycleSequenceButton(config, 180, lowerControlsY - 90, "maximum", "Sequence max")
    CycleSequenceIntervalButton(config, 18, lowerControlsY - 120)
    local reset = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
    reset:SetSize(135, 22); reset:SetPoint("BOTTOMLEFT", 20, 18); reset:SetText("Reset placements")
    reset:SetScript("OnClick", function() db.locations = {}; db.layoutVersion = 0; CopyDefaults(); ApplyAll(); config:Hide(); config = nil; OpenConfig() end)
    local close = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
    close:SetSize(75, 22); close:SetPoint("BOTTOMRIGHT", -20, 18); close:SetText("Close")
    close:SetScript("OnClick", function() config:Hide() end)
    ApplyAll()
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
    elseif command == "test" then Trigger({ "chat" }); TriggerGlobal(); TriggerSpell(); Print("bop!")
    elseif command == "credits" then Print("Kitgore icon-font artwork used under MIT; see THIRD_PARTY_NOTICES.md.")
    else Help() end
end

Controller:RegisterEvent("PLAYER_LOGIN")
Controller:RegisterEvent("PLAYER_STARTED_MOVING")
Controller:RegisterEvent("PLAYER_STARTED_TURNING")
Controller:RegisterEvent("PLAYER_TARGET_CHANGED")
Controller:RegisterEvent("PLAYER_REGEN_DISABLED")
Controller:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
Controller:RegisterEvent("UNIT_SPELLCAST_START")
Controller:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
Controller:RegisterEvent("UNIT_COMBAT")
Controller:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
Controller:RegisterEvent("BAG_UPDATE_DELAYED")
Controller:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "PLAYER_LOGIN" then
        CopyDefaults()
        CreateCat("Chat", "chat", "chat")
        CreateCat("Action", "action", "action")
        CreateCat("Spell", "spell", "spell")
        ApplyAll()
        HookChatEditBoxes()
        -- Covers action-bar mouse clicks and bound action keys in addition to cast events.
        if type(UseAction) == "function" then hooksecurefunc("UseAction", function() TriggerGlobal("actionBar") end) end
        Print("loaded. Use /bc config to place and size cats.")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" then
            TriggerGlobal("castSuccess")
            if not castGUID or not startedSpellCasts[castGUID] then TriggerSpell(spellID) end
            if castGUID then startedSpellCasts[castGUID] = nil end
        end
    elseif event == "UNIT_SPELLCAST_START" then
        if unit == "player" then
            if castGUID then startedSpellCasts[castGUID] = true end
            TriggerGlobal("castStart"); TriggerSpell(spellID)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        if unit == "player" then
            if castGUID then startedSpellCasts[castGUID] = true end
            TriggerGlobal("channelStart"); TriggerSpell(spellID)
        end
    elseif event == "UNIT_COMBAT" then
        if unit == "player" then TriggerGlobal("combat") end
    elseif event == "PLAYER_STARTED_MOVING" then
        TriggerGlobal("movement")
    elseif event == "PLAYER_STARTED_TURNING" then
        TriggerGlobal("turning")
    elseif event == "PLAYER_TARGET_CHANGED" then
        TriggerGlobal("targetChange")
    elseif event == "PLAYER_REGEN_DISABLED" then
        TriggerGlobal("enterCombat")
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        TriggerGlobal("equipment")
    elseif event == "BAG_UPDATE_DELAYED" then
        TriggerGlobal("bags")
    end
end)

Controller:SetScript("OnUpdate", function()
    local now = GetTime()
    if globalSequence.remaining > 0 and now >= globalSequence.nextAt then
        Trigger({ "action" }, true)
        globalSequence.remaining = globalSequence.remaining - 1
        globalSequence.nextAt = now + db.actionSequence.interval
    end
    if spellSequence.remaining > 0 and now >= spellSequence.nextAt then
        Trigger({ "spell" }, true)
        spellSequence.remaining = spellSequence.remaining - 1
        spellSequence.nextAt = now + db.actionSequence.interval
    end
    for _, cat in pairs(cats) do
        if cat.lastHit > 0 and now - cat.lastHit > 0.18 then SetPose(cat, 0); cat.lastHit = 0 end
        if db.fade.enabled and cat:IsShown() and not cat.dragging and not (config and config:IsShown()) then
            local fadeProgress = (now - cat.lastActivity - db.fade.delay) / db.fade.duration
            cat:SetAlpha(math.max(0, math.min(1, 1 - fadeProgress)))
            if (cat.kind == "action" or cat.kind == "chat") and cat:GetAlpha() <= 0.01 then cat:EnableMouse(false) end
        end
    end
end)
