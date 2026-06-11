-- ==========================================
-- Cooldowns.lua: Отслеживание перезарядки заклинаний
-- Версия: 13.0 (Скрытие недоступных заклинаний из списка)
-- ==========================================

print("|cff00ff00[SST]|r Версия Cooldowns.lua: 13.0 (Чистый список по специализации)")

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

-- ФУНКЦИЯ ЗАГРУЗКИ: Добавляет в список ТОЛЬКО доступные заклинания
function SST.Cooldowns:Init()
    wipe(trackedSpells)
    local activeCount = 0
    
    local keys = {}
    if SST_DB and SST_DB.trackedIDs then
        for k, _ in pairs(SST_DB.trackedIDs) do
            table.insert(keys, k)
        end
    end

    for i = 1, #keys do
        local rawKey = keys[i]
        local spellID = tonumber(rawKey)
        
        if spellID then
            local success, currentName = pcall(GetSpellInfo, spellID)
            
            -- Проверяем, знает ли персонаж это заклинание в текущей специализации
            local isKnown = false
            local ok, knownResult = pcall(IsSpellKnown, spellID)
            if ok then isKnown = knownResult end
            
            -- ИЗМЕНЕНИЕ: Добавляем в активный список только если заклинание известно
            if success and currentName and isKnown then
                local s2, start, duration = pcall(GetSpellCooldown, currentName)
                local endTime = (s2 and type(start) == "number" and type(duration) == "number" and duration > 0 and start > 0) and (start + duration) or GetTime()
                
                trackedSpells[spellID] = { name = currentName, endTime = endTime }
                activeCount = activeCount + 1
            end
            -- Если заклинание неизвестно, мы просто пропускаем его. 
            -- Оно остается в SST_DB.trackedIDs, но не отображается в trackedSpells.
        end
    end
    
    print("|cff00ff00[SST]|r Загружено активных заклинаний: " .. activeCount)
end

-- ФУНКЦИЯ ДОБАВЛЕНИЯ ПО НАЗВАНИЮ
function SST.Cooldowns:Add(spellNameStr)
    if not spellNameStr or string.trim(spellNameStr) == "" then
        print("|cffff0000[SST]|r Ошибка: Пожалуйста, введите название заклинания. Пример: |cff00ff00/sst add Ледяная глыба|r")
        return
    end
    
    local success, name = pcall(GetSpellInfo, spellNameStr)
    if not success or not name then
        print("|cffff0000[SST]|r Ошибка: Заклинание '" .. spellNameStr .. "' не найдено в вашей книге заклинаний.")
        return
    end
    
    local link = GetSpellLink(name)
    local spellID = nil
    if link then
        spellID = tonumber(string.match(link, "spell:(%d+)"))
    end
    
    if not spellID then
        print("|cffff0000[SST]|r Ошибка: Не удалось определить ID заклинания '" .. name .. "'.")
        return
    end
    
    local s2, start, duration = pcall(GetSpellCooldown, name)
    local endTime = (s2 and type(start) == "number" and type(duration) == "number" and duration > 0 and start > 0) and (start + duration) or GetTime()
    
    trackedSpells[spellID] = { name = name, endTime = endTime }
    
    -- Сохраняем имя заклинания в базу данных
    SST_DB.trackedIDs[tostring(spellID)] = name 
    
    print("|cff00ff00[SST]|r Заклинание [" .. name .. "] (ID: " .. spellID .. ") добавлено.")
    frame:Show()
    SST_DB.isVisible = true
end

function SST.Cooldowns:Clear()
    wipe(trackedSpells)
    wipe(SST_DB.trackedIDs)
    print("|cff00ff00[SST]|r Список отслеживаемых заклинаний полностью очищен.")
end

function SST.Cooldowns.UpdateLayout()
    local activeCount = 0
    for _ in pairs(trackedSpells) do activeCount = activeCount + 1 end
    
    if activeCount == 0 then
        cdContainer:SetHeight(0)
        cdTitle:Hide()
        for _, btn in ipairs(cooldownFrames) do btn:Hide() end
        
        if SST.showStats then
            frame:SetHeight(100)
        else
            frame:SetHeight(40)
        end
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

    -- Авто-синхронизация кулдаунов
    for spellID, data in pairs(trackedSpells) do
        local success, start, duration = pcall(GetSpellCooldown, data.name)
        if success and type(start) == "number" and type(duration) == "number" and duration > 0 and start > 0 then
            local newEndTime = start + duration
            if newEndTime > data.endTime then data.endTime = newEndTime end
        end
    end

    -- Отрисовка и обработка кликов
    local i = 1
    for spellID, data in pairs(trackedSpells) do
        if i > activeCount then break end
        
        local btn = cooldownFrames[i]
        
        -- ИЗМЕНЕНИЕ: Убрана логика статуса "Недоступно", так как в списке только активные заклинания
        local remaining = math.max(0, math.ceil(data.endTime - GetTime()))
        local statusText = remaining > 0 and format("|cffffd700%d|r сек.", remaining) or "|cff00ff00Готово|r"
        
        btn.text:SetText(format("|cff00ff00%s|r |cff888888(ID:%d)|r: %s", data.name, spellID, statusText))
        btn:Show()
        
        btn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                trackedSpells[spellID] = nil
                SST_DB.trackedIDs[tostring(spellID)] = nil
                print("|cffff0000[SST]|r Заклинание [" .. data.name .. "] (ID: " .. spellID .. ") удалено.")
                SST.Cooldowns.UpdateLayout()
            else
                -- ИЗМЕНЕНИЕ: Убрана проверка isAvailable
                local anyEnabled = SST_DB.chSay or SST_DB.chParty or SST_DB.chRaid or SST_DB.chGuild
                if not anyEnabled then
                    print("|cffff0000[SST]|r Необходимо выбрать канал для отправки сообщений.")
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
    
    if SST.showStats then
        frame:SetHeight(100 + totalHeight)
    else
        frame:SetHeight(40 + totalHeight)
    end
end

-- Слушатель смены специализации
local talentFrame = CreateFrame("Frame")
talentFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
talentFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

talentFrame:SetScript("OnEvent", function(self, event)
    SST.Cooldowns:Init()
    SST.Cooldowns.UpdateLayout()
    
    local activeCount = 0
    for _ in pairs(trackedSpells) do activeCount = activeCount + 1 end
    print("|cff00ff00[SST]|r Специализация изменена. Активных заклинаний в списке: " .. activeCount)
end)

-- Основной цикл обновлений
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not self.timer then self.timer = 0 end
    self.timer = self.timer + elapsed
    if self.timer < 0.3 then return end
    self.timer = 0
    SST.Cooldowns.UpdateLayout()
end)