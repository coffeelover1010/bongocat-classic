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

local function SetPose(pose)
    -- The atlas is 2048x512: three 512px-wide poses followed by transparent padding.
    local left = pose * 0.25
    cat.art:SetTexCoord(left, left + 0.25, 0, 1)
end

local function Hit()
    if not cat or not db.shown then
        return
    end

    nextPaw = nextPaw == "left" and "right" or "left"
    SetPose(nextPaw == "left" and 1 or 2)
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
    cat = CreateFrame("Frame", addonName .. "Frame", UIParent)
    cat:SetSize(420, 420)
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
            SetPose(0)
            lastHit = 0
        end
    end)

    cat.art = cat:CreateTexture(nil, "ARTWORK")
    cat.art:SetAllPoints(cat)
    cat.art:SetTexture("Interface\\AddOns\\BongoCatClassic\\Art\\BongoCatClassic.tga")
    SetPose(0)
    ApplyPosition()
end

local function OnChatEdited(editBox)
    if editBox and editBox:HasFocus() then
        Hit()
    end
end

local function Help()
    Print("Commands: |cffffffff/bc show|hide|toggle|r, |cffffffff/bc lock|unlock|r, |cffffffff/bc scale 0.5-2|r, |cffffffff/bc reset|r, |cffffffff/bc test|r, |cffffffff/bc credits|r")
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
    elseif command == "credits" then
        Print("Bongo Cat art concept: @StrayRogue. Original video concept: @DitzyFlama.")
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
