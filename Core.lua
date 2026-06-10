-- ==========================================
-- Core.lua: Основа, UI окна, кнопки и команды
-- ==========================================

SST = {}

-- Глобальный флаг видимости статистики (по умолчанию включена)
SST.showStats = true

-- 1. Прямая инициализация глобальной переменной SavedVariables
if not SST_DB then
    SST_DB = {
        point = "CENTER",
        x = 0,
        y = 0,
        isVisible = true,
        trackedIDs = {}
    }
else
    if not SST_DB.trackedIDs then
        SST_DB.trackedIDs = {}
    end
end

-- Создание главного окна
local frame = CreateFrame("Frame", "SST_Frame", UIParent)
frame:SetWidth(260) 
frame:SetHeight(95)
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

-- ==========================================
-- КНОПКИ УПРАВЛЕНИЯ
-- ==========================================

-- Вспомогательная функция для создания кнопок
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
    highlight:SetTexture(1, 1, 1, 0.2) -- Белая подсветка при наведении
    
    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetPoint("CENTER", btn, "CENTER", 0, 1) -- Небольшой визуальный сдвиг вверх для центровки
    txt:SetText(textChar)
    txt:SetTextColor(colorR, colorG, colorB)
    
    btn:SetScript("OnClick", onClickFunc)
    return btn
end

-- Кнопка 1: Переключение статистики ($)
local btnStats = CreateControlButton(frame, "$", 1, 0.8, 0, function()
    SST.showStats = not SST.showStats
    if SST.Session and SST.Session.elements then
        for _, fs in pairs(SST.Session.elements) do
            if SST.showStats then fs:Show() else fs:Hide() end
        end
    end
    -- Пересчитываем высоту окна
    if SST.Cooldowns and SST.Cooldowns.UpdateLayout then
        SST.Cooldowns.UpdateLayout()
    end
end)
btnStats:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)

-- Кнопка 2: Справка (?)
local btnHelp = CreateControlButton(frame, "?", 1, 1, 1, function()
    print("|cff00ff00=========================================|r")
    print("|cff00ff00[SST] Simple Session & Cooldown Tracker|r")
    print("|cff00ff00=========================================|r")
    print("|cff00ff00/sst add <ID>|r      - Добавить заклинание (Пример: |cff00ff00/sst add 45438|r)")
    print("|cff00ff00/sst clear|r         - Очистить список отслеживаемых заклинаний")
    print("|cff00ff00/sst reset|r         - Сбросить статистику сессии и очистить список")
    print("|cff00ff00/sst|r или |cff00ff00/session|r  - Показать или скрыть окно аддона")
    print("|cff00ff00ПКМ по заклинанию|r  - Удалить конкретное заклинание из списка отслеживания")
    print("|cffaaaaaa💡 Совет: Наведите курсор на заклинание в Книге заклинаний, чтобы увидеть его ID.|r")
    print("|cff00ff00=========================================|r")
end)
btnHelp:SetPoint("LEFT", btnStats, "RIGHT", 4, 0)

-- Заголовок (сдвигаем вправо от кнопок)
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("LEFT", btnHelp, "RIGHT", 6, 1)
title:SetText("|cffaaaaaaСтатистика сессии:|r")

-- Кнопка закрытия
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function()
    frame:Hide()
    SST_DB.isVisible = false
end)

-- Перетаскивание
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    SST_DB.point = point
    SST_DB.x = x
    SST_DB.y = y
end)

-- Загрузка
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "SimpleSessionTracker" then
        if SST_DB.isVisible then frame:Show() else frame:Hide() end
        frame:ClearAllPoints()
        frame:SetPoint(SST_DB.point, UIParent, SST_DB.point, SST_DB.x, SST_DB.y)
    elseif event == "PLAYER_LOGIN" then
        if SST.Session then SST.Session:Init() end
        if SST.Cooldowns then SST.Cooldowns:Init() end
    end
end)

-- ==========================================
-- Команды чата
-- ==========================================
SLASH_SST1 = "/sst"
SLASH_SST2 = "/session"

SlashCmdList["SST"] = function(msg)
    msg = string.lower(string.trim(msg or ""))
    
    if msg == "help" or msg == "" then
        -- Вызываем ту же логику, что и кнопка "?"
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