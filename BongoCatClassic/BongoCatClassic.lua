local addonName = ...

local BongoCat = CreateFrame("Frame", addonName .. "Controller")
local db
local cat
local lastHit = 0
local nextPaw = "left"

local DEFAULTS = {
    point = "BOTTOM",
    x = 0,
    y = 120,
    scale = 1,
    locked = false,
    shown = true,
}

local function CopyDefaults()
    for key, value in pairs(DEFAULTS) do
        if BongoCatClassicDB[key] == nil then
            BongoCatClassicDB[key] = value
        end
    end
    db = BongoCatClassicDB
end

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff8fcbffBongoCat Classic:|r " .. message)
end

local function Pixel(frame, width, height, r, g, b, a)
    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetSize(width, height)
    texture:SetVertexColor(r, g, b, a or 1)
    return texture
end

local function SetPaw(paw, side, raised)
    paw:ClearAllPoints()
    paw:SetPoint("BOTTOM", cat, "BOTTOM", side == "left" and -45 or 45, raised and 43 or 25)
    paw:SetSize(34, raised and 56 or 38)
end

local function Hit()
    if not cat or not db.shown then
        return
    end

    nextPaw = nextPaw == "left" and "right" or "left"
    SetPaw(cat.leftPaw, "left", nextPaw == "left")
    SetPaw(cat.rightPaw, "right", nextPaw == "right")
    lastHit = GetTime()
end

local function ApplyPosition()
    cat:ClearAllPoints()
    cat:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    cat:SetScale(db.scale)
    if db.shown then cat:Show() else cat:Hide() end
end

local function SavePosition()
    local point, _, _, x, y = cat:GetPoint(1)
    db.point, db.x, db.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
end

local function CreateCat()
    cat = CreateFrame("Frame", addonName .. "Frame", UIParent, "BackdropTemplate")
    cat:SetSize(230, 185)
    cat:SetClampedToScreen(true)
    cat:SetMovable(true)
    cat:EnableMouse(true)
    cat:RegisterForDrag("LeftButton")
    cat:SetScript("OnDragStart", function(self)
        if not db.locked then self:StartMoving() end
    end)
    cat:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    cat:SetScript("OnUpdate", function()
        if lastHit > 0 and GetTime() - lastHit > 0.22 then
            SetPaw(cat.leftPaw, "left", false)
            SetPaw(cat.rightPaw, "right", false)
            lastHit = 0
        end
    end)

    -- All artwork below is drawn from WoW's built-in solid texture; no external art is bundled.
    local tableTop = Pixel(cat, 230, 18, 0.33, 0.16, 0.06)
    tableTop:SetPoint("BOTTOM")
    local body = Pixel(cat, 138, 78, 0.72, 0.62, 0.45)
    body:SetPoint("BOTTOM", 0, 16)
    local head = Pixel(cat, 160, 90, 0.78, 0.69, 0.51)
    head:SetPoint("BOTTOM", 0, 72)
    local leftEar = Pixel(cat, 42, 45, 0.63, 0.51, 0.34)
    leftEar:SetPoint("BOTTOM", head, "TOPLEFT", 15, -6)
    local rightEar = Pixel(cat, 42, 45, 0.63, 0.51, 0.34)
    rightEar:SetPoint("BOTTOM", head, "TOPRIGHT", -15, -6)
    local leftEye = Pixel(cat, 10, 16, 0.08, 0.05, 0.02)
    leftEye:SetPoint("CENTER", head, "CENTER", -34, 8)
    local rightEye = Pixel(cat, 10, 16, 0.08, 0.05, 0.02)
    rightEye:SetPoint("CENTER", head, "CENTER", 34, 8)
    local nose = Pixel(cat, 13, 8, 0.55, 0.25, 0.25)
    nose:SetPoint("CENTER", head, "CENTER", 0, -8)
    local mouth = Pixel(cat, 34, 5, 0.20, 0.11, 0.07)
    mouth:SetPoint("TOP", nose, "BOTTOM", 0, -8)

    cat.leftPaw = Pixel(cat, 34, 38, 0.78, 0.69, 0.51)
    cat.rightPaw = Pixel(cat, 34, 38, 0.78, 0.69, 0.51)
    SetPaw(cat.leftPaw, "left", false)
    SetPaw(cat.rightPaw, "right", false)
    ApplyPosition()
end

local function OnChatEdited(editBox)
    if editBox and editBox:HasFocus() then
        Hit()
    end
end

local function Help()
    Print("Commands: |cffffffff/bc show|hide|toggle|r, |cffffffff/bc lock|unlock|r, |cffffffff/bc scale 0.5-2|r, |cffffffff/bc reset|r, |cffffffff/bc test|r")
end

SLASH_BONGOCATCLASSIC1 = "/bongocat"
SLASH_BONGOCATCLASSIC2 = "/bc"
SlashCmdList.BONGOCATCLASSIC = function(message)
    local command, argument = message:match("^(%S*)%s*(.-)$")
    command = command:lower()
    if command == "show" then
        db.shown = true; ApplyPosition(); Print("shown.")
    elseif command == "hide" then
        db.shown = false; ApplyPosition(); Print("hidden.")
    elseif command == "toggle" then
        db.shown = not db.shown; ApplyPosition(); Print(db.shown and "shown." or "hidden.")
    elseif command == "lock" then
        db.locked = true; Print("locked.")
    elseif command == "unlock" then
        db.locked = false; Print("unlocked — drag with the left mouse button.")
    elseif command == "scale" then
        local scale = tonumber(argument)
        if scale and scale >= 0.5 and scale <= 2 then
            db.scale = scale; ApplyPosition(); Print("scale set to " .. scale .. ".")
        else
            Print("scale must be from 0.5 to 2.")
        end
    elseif command == "reset" then
        for key, value in pairs(DEFAULTS) do db[key] = value end
        ApplyPosition(); Print("position and options reset.")
    elseif command == "test" then
        for _ = 1, 3 do Hit() end
        Print("bop!")
    else
        Help()
    end
end

BongoCat:RegisterEvent("PLAYER_LOGIN")
BongoCat:SetScript("OnEvent", function()
    BongoCatClassicDB = BongoCatClassicDB or {}
    CopyDefaults()
    CreateCat()
    if type(ChatEdit_OnTextChanged) == "function" then
        hooksecurefunc("ChatEdit_OnTextChanged", OnChatEdited)
    else
        Print("chat typing hook is unavailable in this client; use /bc test to confirm the addon loaded.")
    end
    Print("loaded. Type in chat to make the cat bop; use /bc for options.")
end)
