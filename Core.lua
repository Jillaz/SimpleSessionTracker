-- ==========================================
-- Core.lua: Основа, UI окна, кнопки и команды
-- ==========================================

SST = {}
SST.showStats = true

if not SST_DB then
    SST_DB = {
        point = "CENTER",
        x = 0,
        y = 0,
        isVisible = true,
        trackedIDs = {},
        -- Инициализация состояний кнопок каналов (по умолчанию включен только SAY)
        chSay = true,
        chParty = false,
        chRaid = false,
        chGuild = false
    }
else
    if not SST_DB.trackedIDs then SST_DB.trackedIDs = {} end
    if SST_DB.chSay == nil then SST_DB.chSay = true end
    if SST_DB.chParty == nil then SST_DB.chParty = false end
    if SST_DB.chRaid == nil then SST_DB.chRaid = false end
    if SST_DB.chGuild == nil then SST_DB.chGuild = false end
end

local frame = CreateFrame("Frame", "SST_Frame", UIParent)
frame:SetWidth(280) -- Немного увеличили ширину для новых кнопок
frame:SetHeight(100)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
SST.Frame = frame

local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(frame)
bg:SetTexture(0.1, 0.1, 0.1, 0.85)

local border = frame:CreateTexture(nil, "BORDER")
border:SetAllPoints(frame)
border:SetTexture(0.5, 0.5, 0.5, 1)

-- Функция создания обычной кнопки
local function CreateControlButton(parent, textChar, colorR, colorG, colorB, onClickFunc)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    
    local bgBtn = btn:CreateTexture(nil, "BACKGROUND")
    bgBtn:SetAllPoints()
    bgBtn:SetTexture(0.2, 0.2, 0.2, 0.8)
    
    local borderBtn = btn:CreateTexture(nil, "BORDER")
    borderBtn:SetAllPoints()
    borderBtn:SetTexture(0.6, 0.6, 0.6, 1)
    
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture(1, 1, 1, 0.2)
    
    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetPoint("CENTER", btn, "CENTER", 0, 1)
    txt:SetText(textChar)
    txt:SetTextColor(colorR, colorG, colorB)
    
    btn:SetScript("OnClick", onClickFunc)
    return btn
end

-- Функция создания кнопки-переключателя (Toggle)
local function CreateToggleButton(parent, text, dbKey, anchorTo, offsetX)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(22, 18)
    btn:SetPoint("LEFT", anchorTo, "RIGHT", offsetX, 0)
    
    local bgBtn = btn:CreateTexture(nil, "BACKGROUND")
    bgBtn:SetAllPoints()
    
    local borderBtn = btn:CreateTexture(nil, "BORDER")
    borderBtn:SetAllPoints()
    borderBtn:SetTexture(0.5, 0.5, 0.5, 1)
    
    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("CENTER", btn, "CENTER", 0, 1)
    txt:SetText(text)
    
    -- Функция обновления визуального состояния
    local function UpdateVisuals()
        if SST_DB[dbKey] then
            bgBtn:SetTexture(0.2, 0.6, 0.2, 0.8) -- Зеленый фон (ВКЛ)
            txt:SetTextColor(1, 1, 1)            -- Белый текст
        else
            bgBtn:SetTexture(0.2, 0.2, 0.2, 0.8) -- Темный фон (ВЫКЛ)
            txt:SetTextColor(0.5, 0.5, 0.5)      -- Серый текст
        end
    end
    
    btn:SetScript("OnClick", function()
        SST_DB[dbKey] = not SST_DB[dbKey]
        UpdateVisuals()
    end)
    
    btn.UpdateVisuals = UpdateVisuals
    return btn
end

-- 1. Кнопка статистики ($)
local btnStats = CreateControlButton(frame, "$", 1, 0.8, 0, function()
    SST.showStats = not SST.showStats
    if SST.Session and SST.Session.elements then
        for _, fs in pairs(SST.Session.elements) do
            if SST.showStats then fs:Show() else fs:Hide() end
        end
    end
    if SST.Cooldowns and SST.Cooldowns.UpdateLayout then
        SST.Cooldowns.UpdateLayout()
    end
end)
btnStats:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)

-- 2. Кнопка справки (?)
local btnHelp = CreateControlButton(frame, "?", 1, 1, 1, function()
    print("|cff00ff00=========================================|r")
    print("|cff00ff00[SST] Simple Session & Cooldown Tracker|r")
    print("|cff00ff00=========================================|r")
    print("|cff00ff00/sst add <ID>|r      - Добавить заклинание (Пример: |cff00ff00/sst add 45438|r)")
    print("|cff00ff00/sst clear|r         - Очистить список отслеживаемых заклинаний")
    print("|cff00ff00/sst reset|r         - Сбросить статистику сессии (список заклинаний не изменится)")
    print("|cff00ff00/sst|r или |cff00ff00/session|r  - Показать или скрыть окно аддона")
    print("|cff00ff00ПКМ по заклинанию|r  - Удалить конкретное заклинание из списка отслеживания")
    print("|cffaaaaaa💡 Совет: Наведите курсор на заклинание в Книге заклинаний, чтобы увидеть его ID.|r")
    print("|cff00ff00=========================================|r")
end)
btnHelp:SetPoint("LEFT", btnStats, "RIGHT", 4, 0)

-- 3-6. Кнопки каналов чата (Переключатели)
local btnSay = CreateToggleButton(frame, "С", "chSay", btnHelp, 6)
local btnParty = CreateToggleButton(frame, "Гр", "chParty", btnSay, 2)
local btnRaid = CreateToggleButton(frame, "Р", "chRaid", btnParty, 2)
local btnGuild = CreateToggleButton(frame, "Г", "chGuild", btnRaid, 2)

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function()
    frame:Hide()
    SST_DB.isVisible = false
end)

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    SST_DB.point = point
    SST_DB.x = x
    SST_DB.y = y
end)

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "SimpleSessionTracker" then
        -- Обновляем визуальное состояние кнопок каналов при загрузке
        btnSay.UpdateVisuals()
        btnParty.UpdateVisuals()
        btnRaid.UpdateVisuals()
        btnGuild.UpdateVisuals()

        if SST_DB.isVisible then frame:Show() else frame:Hide() end
        frame:ClearAllPoints()
        frame:SetPoint(SST_DB.point, UIParent, SST_DB.point, SST_DB.x, SST_DB.y)
    elseif event == "PLAYER_LOGIN" then
        if SST.Session then SST.Session:Init() end
        if SST.Cooldowns then SST.Cooldowns:Init() end
    end
end)

SLASH_SST1 = "/sst"
SLASH_SST2 = "/session"

SlashCmdList["SST"] = function(msg)
    msg = string.lower(string.trim(msg or ""))
    
    if msg == "help" or msg == "" then
        btnHelp:GetScript("OnClick")(btnHelp)
    elseif msg == "reset" and SST.Session then
        SST.Session:Reset()
    elseif string.sub(msg, 1, 4) == "add " and SST.Cooldowns then
        SST.Cooldowns:Add(string.sub(msg, 5))
    elseif msg == "clear" and SST.Cooldowns then
        SST.Cooldowns:Clear()
    elseif msg == "hide" then
        frame:Hide()
        SST_DB.isVisible = false
    elseif msg == "show" then
        frame:Show()
        SST_DB.isVisible = true
    else
        if frame:IsVisible() then
            frame:Hide()
            SST_DB.isVisible = false
        else
            frame:Show()
            SST_DB.isVisible = true
        end
    end
end