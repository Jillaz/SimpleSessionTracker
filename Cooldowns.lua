-- ==========================================
-- Cooldowns.lua: Отслеживание перезарядки заклинаний (ДИАГНОСТИКА)
-- ==========================================

print("|cff00ff00[SST DEBUG]|r Файл Cooldowns.lua успешно загружен игрой!")

SST.Cooldowns = {}

local trackedSpells = {} 
local cooldownFrames = {} 

local frame = SST.Frame
local cdContainer = CreateFrame("Frame", nil, frame)
cdContainer:SetWidth(260)
cdContainer:SetHeight(0)

local cdTitle = cdContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cdTitle:SetPoint("TOPLEFT", cdContainer, "TOPLEFT", 0, 0)
cdTitle:SetText("|cffaaaaaaПерезарядка:|r")
cdTitle:Hide()

function SST.Cooldowns:Init()
    print("|cff00ff00[SST DEBUG]|r Запуск функции Init...")
    wipe(trackedSpells)
    local loadedCount = 0
    
    print("|cff00ff00[SST DEBUG]|r SST_DB существует: " .. tostring(SST_DB ~= nil))
    
    if SST_DB then
        print("|cff00ff00[SST DEBUG]|r SST_DB.trackedIDs существует: " .. tostring(SST_DB.trackedIDs ~= nil))
        
        if SST_DB.trackedIDs then
            for key, _ in pairs(SST_DB.trackedIDs) do
                print("|cff00ff00[SST DEBUG]|r Найдено в сохранении ключ: " .. tostring(key))
                local spellID = tonumber(key)
                
                if spellID then
                    local name = GetSpellInfo(spellID)
                    if name then
                        local start, duration, enable = GetSpellCooldown(name)
                        local endTime = (duration > 0 and start > 0 and enable == 1) and (start + duration) or GetTime()
                        trackedSpells[spellID] = { name = name, endTime = endTime }
                        loadedCount = loadedCount + 1
                        print("|cff00ff00[SST DEBUG]|r Успешно загружено: " .. name .. " (ID: " .. spellID .. ")")
                    else
                        print("|cffffaa00[SST DEBUG]|r ВНИМАНИЕ: GetSpellInfo вернул nil для ID " .. spellID .. ". Заклинание удалено из сохранения.")
                        SST_DB.trackedIDs[key] = nil
                    end
                end
            end
            print("|cff00ff00[SST]|r ИТОГО: Успешно загружено заклинаний из сохранения: " .. loadedCount)
        else
            print("|cffff0000[SST DEBUG]|r ОШИБКА: Поле trackedIDs отсутствует. Создаем.")
            SST_DB.trackedIDs = {}
        end
    else
        print("|cffff0000[SST DEBUG]|r КРИТИЧЕСКАЯ ОШИБКА: Глобальная таблица SST_DB равна nil!")
        SST_DB = { trackedIDs = {} }
    end
end

function SST.Cooldowns:Add(idStr)
    local spellID = tonumber(idStr)
    if not spellID then
        print("|cffff0000[SST]|r Ошибка: Пожалуйста, введите числовой ID.")
        return
    end
    
    local name = GetSpellInfo(spellID)
    if not name then
        print("|cffff0000[SST]|r Ошибка: Заклинание с ID " .. spellID .. " не найдено в книге.")
        return
    end
    
    local start, duration, enable = GetSpellCooldown(name)
    local endTime = (duration > 0 and start > 0 and enable == 1) and (start + duration) or GetTime()
    
    trackedSpells[spellID] = { name = name, endTime = endTime }
    
    -- Явная запись
    SST_DB.trackedIDs[spellID] = true 
    
    print("|cff00ff00[SST DEBUG]|r Заклинание добавлено в память. Проверка SST_DB.trackedIDs[" .. spellID .. "]: " .. tostring(SST_DB.trackedIDs[spellID]))
    print("|cff00ff00[SST]|r Заклинание [" .. name .. "] добавлено.")
    
    frame:Show()
    SST_DB.isVisible = true
end

function SST.Cooldowns:Clear()
    wipe(trackedSpells)
    wipe(SST_DB.trackedIDs)
    print("|cff00ff00[SST]|r Список очищен.")
end

function SST.Cooldowns.UpdateLayout()
    local activeCount = 0
    for _ in pairs(trackedSpells) do activeCount = activeCount + 1 end
    
    if activeCount == 0 then
        cdContainer:SetHeight(0)
        cdTitle:Hide()
        for _, btn in ipairs(cooldownFrames) do btn:Hide() end
        if SST.showStats then frame:SetHeight(100) else frame:SetHeight(40) end
        return
    end

    if SST.showStats and SST.Session and SST.Session.elements and SST.Session.elements.textNet then
        cdContainer:SetPoint("TOPLEFT", SST.Session.elements.textNet, "BOTTOMLEFT", 0, -8)
    else
        cdContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -26)
    end
    
    cdTitle:Show()
    
    while #cooldownFrames < activeCount do
        local idx = #cooldownFrames + 1
        local btn = CreateFrame("Button", nil, cdContainer)
        btn:SetWidth(260)
        btn:SetHeight(16)
        btn:SetPoint("TOPLEFT", cdContainer, "TOPLEFT", 0, -20 - (idx - 1) * 18)
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

    for spellID, data in pairs(trackedSpells) do
        local start, duration, enable = GetSpellCooldown(data.name)
        if duration > 0 and start > 0 and enable == 1 then
            local newEndTime = start + duration
            if newEndTime > data.endTime then data.endTime = newEndTime end
        end
    end

    local i = 1
    for spellID, data in pairs(trackedSpells) do
        if i > activeCount then break end
        local btn = cooldownFrames[i]
        local remaining = math.max(0, math.ceil(data.endTime - GetTime()))
        local statusText = remaining > 0 and format("|cffffd700%d|r сек.", remaining) or "|cff00ff00Готово|r"
        
        btn.text:SetText(format("|cff00ff00%s|r |cff888888(ID:%d)|r: %s", data.name, spellID, statusText))
        btn:Show()
        
        btn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                trackedSpells[spellID] = nil
                SST_DB.trackedIDs[spellID] = nil
                print("|cffff0000[SST]|r Заклинание удалено.")
                SST.Cooldowns.UpdateLayout()
            else
                local anyEnabled = SST_DB.chSay or SST_DB.chParty or SST_DB.chRaid or SST_DB.chGuild
                if not anyEnabled then
                    print("|cffff0000[SST]|r Необходимо выбрать канал для отправки.")
                    return
                end

                local currentRem = math.max(0, math.ceil(data.endTime - GetTime()))
                local spellLink = GetSpellLink(spellID)
                local msg = currentRem > 0 and format("%s кд %d сек.", spellLink, currentRem) or format("%s готово!", spellLink)
                
                local sent = false
                if SST_DB.chSay then SendChatMessage(msg, "SAY"); sent = true end
                if SST_DB.chParty and (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0) then SendChatMessage(msg, "PARTY"); sent = true end
                if SST_DB.chRaid and GetNumRaidMembers() > 0 then SendChatMessage(msg, "RAID"); sent = true end
                if SST_DB.chGuild and IsInGuild() then SendChatMessage(msg, "GUILD"); sent = true end
                
                if not sent then print("|cFFffaa00[SST]|r Выбранный канал сейчас недоступен.") end
            end
        end)
        i = i + 1
    end

    for j = i, #cooldownFrames do cooldownFrames[j]:Hide() end

    local totalHeight = 28 + (activeCount * 18)
    cdContainer:SetHeight(totalHeight)
    if SST.showStats then frame:SetHeight(100 + totalHeight) else frame:SetHeight(40 + totalHeight) end
end

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not self.timer then self.timer = 0 end
    self.timer = self.timer + elapsed
    if self.timer < 0.3 then return end
    self.timer = 0
    SST.Cooldowns.UpdateLayout()
end)