-- ==========================================
-- Simple Session Tracker + Cooldown Watcher
-- Версия: 3.7 (Исправлен баг Lua с отрицательным балансом золота)
-- ==========================================

local SST = {}

-- Сохранение позиции окна и СПИСКА ID заклинаний
SST_DB = SST_DB or {
    point = "CENTER",
    x = 0,
    y = 0,
    isVisible = true,
    trackedIDs = {} 
}

-- Переменные сессии
local startTime = time()
local sessionGained = 0
local sessionSpent = 0
local lastGold = 0
local isPlayerLoggedIn = false

-- Рабочая таблица для отображения кулдаунов
local trackedSpells = {} 
local cooldownFrames = {} 

-- ==========================================
-- Вспомогательные функции
-- ==========================================

local function FormatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

-- ИСПРАВЛЕННАЯ функция форматирования золота
local function FormatMoney(copper, colorCode)
    -- ГАРАНТИРОВАННО берем абсолютное значение, чтобы Lua не ломал математику с минусом
    local absCopper = math.abs(copper)
    local g = math.floor(absCopper / 10000)
    local s = math.floor((absCopper % 10000) / 100)
    local c = absCopper % 100
    return string.format("%s%dз %dс %dм|r", colorCode, g, s, c)
end

-- ==========================================
-- Основной интерфейс (UI)
-- ==========================================

local frame = CreateFrame("Frame", "SST_Frame", UIParent)
frame:SetWidth(220)
frame:SetHeight(95)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)

local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(frame)
bg:SetTexture(0.1, 0.1, 0.1, 0.85)

local border = frame:CreateTexture(nil, "BORDER")
border:SetAllPoints(frame)
border:SetTexture(0.5, 0.5, 0.5, 1)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
title:SetText("|cffaaaaaaСтатистика сессии:|r")

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function()
    frame:Hide()
    SST_DB.isVisible = false
end)

-- Строки статистики
local textTime = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
textTime:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -22)
textTime:SetJustifyH("LEFT")
textTime:SetTextColor(1, 0.8, 0)

local textGained = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
textGained:SetPoint("TOPLEFT", textTime, "BOTTOMLEFT", 0, -2)
textGained:SetJustifyH("LEFT")

local textSpent = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
textSpent:SetPoint("TOPLEFT", textGained, "BOTTOMLEFT", 0, -2)
textSpent:SetJustifyH("LEFT")

local textNet = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
textNet:SetPoint("TOPLEFT", textSpent, "BOTTOMLEFT", 0, -2)
textNet:SetJustifyH("LEFT")

-- ==========================================
-- Система отслеживания кулдаунов (UI)
-- ==========================================

local cdContainer = CreateFrame("Frame", nil, frame)
cdContainer:SetPoint("TOPLEFT", textNet, "BOTTOMLEFT", 0, -8)
cdContainer:SetWidth(210)
cdContainer:SetHeight(0)

local cdTitle = cdContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cdTitle:SetPoint("TOPLEFT", cdContainer, "TOPLEFT", 0, 0)
cdTitle:SetText("|cffaaaaaaПерезарядка:|r")
cdTitle:Hide()

local function UpdateCooldownUI()
    local currentTime = GetTime()
    local activeCount = 0
    
    for _ in pairs(trackedSpells) do
        activeCount = activeCount + 1
    end

    if activeCount == 0 then
        cdContainer:SetHeight(0)
        cdTitle:Hide()
        for _, btn in ipairs(cooldownFrames) do
            btn:Hide()
        end
        frame:SetHeight(95)
        return
    end

    cdTitle:Show()
    
    while #cooldownFrames < activeCount do
        local idx = #cooldownFrames + 1
        local btn = CreateFrame("Button", nil, cdContainer)
        btn:SetWidth(210)
        btn:SetHeight(16)
        btn:SetPoint("TOPLEFT", cdContainer, "TOPLEFT", 0, -20 - (idx - 1) * 18)
        
        local hoverBg = btn:CreateTexture(nil, "BACKGROUND")
        hoverBg:SetAllPoints(btn)
        hoverBg:SetTexture(1, 1, 1, 0.15)
        hoverBg:Hide()
        
        btn:SetScript("OnEnter", function() hoverBg:Show() end)
        btn:SetScript("OnLeave", function() hoverBg:Hide() end)
        
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 5, 0)
        text:SetJustifyH("LEFT")
        
        btn.text = text
        btn.hoverBg = hoverBg
        cooldownFrames[idx] = btn
    end

    -- АВТО-СИНХРОНИЗАЦИЯ С ИГРОЙ
    for spellID, data in pairs(trackedSpells) do
        local start, duration, enable = GetSpellCooldown(data.name)
        if duration > 0 and start > 0 and enable == 1 then
            local newEndTime = start + duration
            if newEndTime > data.endTime then
                data.endTime = newEndTime
            end
        end
    end

    -- Отрисовка
    local i = 1
    for spellID, data in pairs(trackedSpells) do
        if i > activeCount then break end
        
        local btn = cooldownFrames[i]
        local remaining = math.max(0, math.ceil(data.endTime - currentTime))
        
        local statusText = remaining > 0 and format("|cffffd700%d|r сек.", remaining) or "|cff00ff00Готово|r"
        
        btn.text:SetText(format("|cff00ff00%s|r |cff888888(ID:%d)|r: %s", data.name, spellID, statusText))
        btn:Show()
        
        btn:SetScript("OnClick", function()
            local currentRem = math.max(0, math.ceil(data.endTime - GetTime()))
            if currentRem > 0 then
                local inGroup = GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
                local channel = inGroup and "PARTY" or "SAY"
                SendChatMessage(format("Заклинание [%s] будет готово через %d сек.", data.name, currentRem), channel)
            else
                print("|cff00ff00[SST]|r Заклинание [" .. data.name .. "] уже готово!")
            end
        end)
        
        i = i + 1
    end

    for j = i, #cooldownFrames do
        cooldownFrames[j]:Hide()
    end

    local totalHeight = 20 + (activeCount * 18)
    cdContainer:SetHeight(totalHeight)
    frame:SetHeight(95 + totalHeight)
end

-- ==========================================
-- Основной цикл обновлений (OnUpdate)
-- ==========================================

frame:SetScript("OnUpdate", function(self, elapsed)
    -- 1. Обновление статистики золота
    if isPlayerLoggedIn then
        local currentGold = GetMoney()
        local diff = currentGold - lastGold
        
        if diff > 0 then
            sessionGained = sessionGained + diff
        elseif diff < 0 then
            sessionSpent = sessionSpent + math.abs(diff)
        end
        lastGold = currentGold
        
        local netProfit = sessionGained - sessionSpent
        
        -- Форматируем строки
        textTime:SetText("Время: " .. FormatTime(time() - startTime))
        textGained:SetText("Получено: " .. FormatMoney(sessionGained, "|cff00ff00"))
        textSpent:SetText("Потрачено: " .. FormatMoney(sessionSpent, "|cffff0000"))
        
        -- ИСПРАВЛЕННЫЙ БАЛАНС: передаем math.abs(netProfit) в функцию форматирования
        if netProfit >= 0 then
            textNet:SetText("Баланс: +" .. FormatMoney(netProfit, "|cff00ff00"))
        else
            textNet:SetText("Баланс: -" .. FormatMoney(math.abs(netProfit), "|cffff0000"))
        end
    end
    
    -- 2. Обновление кулдаунов
    if not self.cdTimer then self.cdTimer = 0 end
    self.cdTimer = self.cdTimer + elapsed
    if self.cdTimer >= 0.3 then
        UpdateCooldownUI()
        self.cdTimer = 0
    end
end)

-- Перетаскивание окна
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    SST_DB.point = point
    SST_DB.x = x
    SST_DB.y = y
end)

-- ==========================================
-- Загрузка и СОХРАНЕНИЕ данных
-- ==========================================

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "SimpleSessionTracker" then
        if SST_DB.isVisible then
            frame:Show()
        else
            frame:Hide()
        end
        frame:ClearAllPoints()
        frame:SetPoint(SST_DB.point, UIParent, SST_DB.point, SST_DB.x, SST_DB.y)
        
    elseif event == "PLAYER_LOGIN" then
        -- Инициализация золота ТОЛЬКО при полном входе персонажа в мир
        isPlayerLoggedIn = true
        lastGold = GetMoney()
        sessionGained = 0
        sessionSpent = 0
        startTime = time()
        
        -- ВОССТАНОВЛЕНИЕ СПИСКА ПРИ ВХОДЕ В ИГРУ
        wipe(trackedSpells)
        if SST_DB.trackedIDs then
            for spellID, _ in pairs(SST_DB.trackedIDs) do
                local name = GetSpellInfo(spellID)
                if name then
                    local start, duration, enable = GetSpellCooldown(name)
                    local endTime = (duration > 0 and start > 0 and enable == 1) and (start + duration) or GetTime()
                    trackedSpells[spellID] = { name = name, endTime = endTime }
                else
                    SST_DB.trackedIDs[spellID] = nil
                end
            end
        else
            SST_DB.trackedIDs = {}
        end
    end
end)

-- ==========================================
-- Команды чата (/sst или /session)
-- ==========================================
SLASH_SST1 = "/sst"
SLASH_SST2 = "/session"

SlashCmdList["SST"] = function(msg)
    msg = string.lower(string.trim(msg or ""))
    
    if msg == "reset" then
        startTime = time()
        lastGold = GetMoney()
        sessionGained = 0
        sessionSpent = 0
        wipe(trackedSpells)
        wipe(SST_DB.trackedIDs)
        print("|cff00ff00[SST]|r Статистика сессии и список кулдаунов сброшены.")
        
    elseif string.sub(msg, 1, 4) == "add " then
        local idStr = string.sub(msg, 5)
        local spellID = tonumber(idStr)
        
        if not spellID then
            print("|cffff0000[SST]|r Ошибка: Пожалуйста, введите числовой ID.")
            print("|cffff0000[SST]|r Пример: /sst add 45438")
            return
        end

        local name = GetSpellInfo(spellID)
        if not name then
            print("|cffff0000[SST]|r Ошибка: Заклинание с ID " .. spellID .. " не найдено.")
            return
        end

        local start, duration, enable = GetSpellCooldown(name)
        local endTime = (duration > 0 and start > 0 and enable == 1) and (start + duration) or GetTime()
        
        trackedSpells[spellID] = { name = name, endTime = endTime }
        SST_DB.trackedIDs[spellID] = true 
        
        print("|cff00ff00[SST]|r Заклинание [|r" .. name .. "|cff00ff00] (ID: " .. spellID .. ") добавлено и сохранено.")
        frame:Show()
        SST_DB.isVisible = true
        
    elseif msg == "clear" then
        wipe(trackedSpells)
        wipe(SST_DB.trackedIDs)
        print("|cff00ff00[SST]|r Список отслеживаемых заклинаний очищен.")
        
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