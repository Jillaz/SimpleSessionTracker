-- ==========================================
-- Cooldowns.lua: Отслеживание перезарядки заклинаний
-- ==========================================

SST.Cooldowns = {}

local trackedSpells = {} 
local cooldownFrames = {} 

local frame = SST.Frame
local cdContainer = CreateFrame("Frame", nil, frame)
cdContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -82)
cdContainer:SetWidth(260)
cdContainer:SetHeight(0)

local cdTitle = cdContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cdTitle:SetPoint("TOPLEFT", cdContainer, "TOPLEFT", 0, 0)
cdTitle:SetText("|cffaaaaaaПерезарядка:|r")
cdTitle:Hide()

function SST.Cooldowns:Init()
    wipe(trackedSpells)
    if SST_DB and SST_DB.trackedIDs then
        for key, _ in pairs(SST_DB.trackedIDs) do
            local spellID = tonumber(key)
            if spellID then
                local name = GetSpellInfo(spellID)
                if name then
                    local start, duration, enable = GetSpellCooldown(name)
                    local endTime = (duration > 0 and start > 0 and enable == 1) and (start + duration) or GetTime()
                    trackedSpells[spellID] = { name = name, endTime = endTime }
                else
                    SST_DB.trackedIDs[key] = nil
                end
            end
        end
    else
        SST_DB.trackedIDs = {}
    end
end

function SST.Cooldowns:Add(idStr)
    local spellID = tonumber(idStr)
    if not spellID then
        print("|cffff0000[SST]|r Ошибка: Пожалуйста, введите числовой ID. Пример: /sst add 45438")
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
end

function SST.Cooldowns:Clear()
    wipe(trackedSpells)
    wipe(SST_DB.trackedIDs)
    print("|cff00ff00[SST]|r Список отслеживаемых заклинаний очищен.")
end

-- Функция пересчета макета окна
function SST.Cooldowns.UpdateLayout()
    local activeCount = 0
    for _ in pairs(trackedSpells) do activeCount = activeCount + 1 end
    
    local baseHeight = SST.showStats and 95 or 35
    local cdOffset = SST.showStats and -82 or -22
    
    if activeCount == 0 then
        cdContainer:SetHeight(0)
        cdTitle:Hide()
        for _, btn in ipairs(cooldownFrames) do btn:Hide() end
        frame:SetHeight(baseHeight)
        return
    end

    cdContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, cdOffset)
    cdTitle:Show()
    
    while #cooldownFrames < activeCount do
        local idx = #cooldownFrames + 1
        local btn = CreateFrame("Button", nil, cdContainer)
        btn:SetWidth(260)
        btn:SetHeight(16)
        btn:SetPoint("TOPLEFT", cdContainer, "TOPLEFT", 0, -20 - (idx - 1) * 18)
        
        -- 🔑 КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ: Явно разрешаем обработку правого клика
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
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

    -- Авто-синхронизация
    for spellID, data in pairs(trackedSpells) do
        local start, duration, enable = GetSpellCooldown(data.name)
        if duration > 0 and start > 0 and enable == 1 then
            local newEndTime = start + duration
            if newEndTime > data.endTime then data.endTime = newEndTime end
        end
    end

    -- Отрисовка и обработка кликов
    local i = 1
    for spellID, data in pairs(trackedSpells) do
        if i > activeCount then break end
        
        local btn = cooldownFrames[i]
        local remaining = math.max(0, math.ceil(data.endTime - GetTime()))
        local statusText = remaining > 0 and format("|cffffd700%d|r сек.", remaining) or "|cff00ff00Готово|r"
        
        btn.text:SetText(format("|cff00ff00%s|r |cff888888(ID:%d)|r: %s", data.name, spellID, statusText))
        btn:Show()
        
        -- ОБРАБОТЧИК КЛИКОВ
        btn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                -- УДАЛЕНИЕ ЗАКЛИНАНИЯ
                trackedSpells[spellID] = nil
                SST_DB.trackedIDs[spellID] = nil
                print("|cffff0000[SST]|r Заклинание [|r" .. data.name .. "|cffff0000] удалено из отслеживания.")
                
                -- Мгновенно обновляем макет
                SST.Cooldowns.UpdateLayout()
            else
                -- ЛЕВЫЙ КЛИК: Отправка сообщения в чат
                local currentRem = math.max(0, math.ceil(data.endTime - GetTime()))
                local inGroup = GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
                local channel = inGroup and "PARTY" or "SAY"
                local spellLink = GetSpellLink(spellID)
                
                if currentRem > 0 then
                    SendChatMessage(format("%s кд %d сек.", spellLink, currentRem), channel)
                else
                    SendChatMessage(format("%s готово!", spellLink), channel)
                end
            end
        end)
        i = i + 1
    end

    for j = i, #cooldownFrames do cooldownFrames[j]:Hide() end

    -- Динамическая высота
    local totalHeight = 20 + (activeCount * 18)
    cdContainer:SetHeight(totalHeight)
    frame:SetHeight(baseHeight + totalHeight)
end

-- Основной цикл обновлений
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not self.timer then self.timer = 0 end
    self.timer = self.timer + elapsed
    if self.timer < 0.3 then return end
    self.timer = 0
    
    SST.Cooldowns.UpdateLayout()
end)