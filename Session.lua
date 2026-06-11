-- ==========================================
-- Session.lua: Отслеживание времени и золота
-- ==========================================

SST.Session = {}

local startTime = time()
local sessionGained = 0
local sessionSpent = 0
local lastGold = 0
local isPlayerLoggedIn = false

local function FormatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function FormatMoney(copper, colorCode)
    local absCopper = math.abs(copper)
    local g = math.floor(absCopper / 10000)
    local s = math.floor((absCopper % 10000) / 100)
    local c = absCopper % 100
    return string.format("%s%dз %dс %dм|r", colorCode, g, s, c)
end

local frame = SST.Frame

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -24)
title:SetText("|cffaaaaaaСтатистика сессии:|r")

local textTime = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
textTime:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -44)
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

SST.Session.elements = {
    title = title,
    textTime = textTime,
    textGained = textGained,
    textSpent = textSpent,
    textNet = textNet
}

function SST.Session:Init()
    isPlayerLoggedIn = true
    lastGold = GetMoney()
    sessionGained = 0
    sessionSpent = 0
    startTime = time()
end

-- ИСПРАВЛЕННАЯ ФУНКЦИЯ СБРОСА
function SST.Session:Reset()
    startTime = time()
    lastGold = GetMoney()
    sessionGained = 0
    sessionSpent = 0
    -- Удален вызов SST.Cooldowns:Clear(), теперь список заклинаний не трогается
    print("|cff00ff00[SST]|r Статистика сессии сброшена.")
end

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not isPlayerLoggedIn then return end
    
    local currentGold = GetMoney()
    local diff = currentGold - lastGold
    
    if diff > 0 then
        sessionGained = sessionGained + diff
    elseif diff < 0 then
        sessionSpent = sessionSpent + math.abs(diff)
    end
    lastGold = currentGold
    
    local netProfit = sessionGained - sessionSpent
    
    textTime:SetText("Время: " .. FormatTime(time() - startTime))
    textGained:SetText("Получено: " .. FormatMoney(sessionGained, "|cff00ff00"))
    textSpent:SetText("Потрачено: " .. FormatMoney(sessionSpent, "|cffff0000"))
    
    if netProfit >= 0 then
        textNet:SetText("Баланс: +" .. FormatMoney(netProfit, "|cff00ff00"))
    else
        textNet:SetText("Баланс: -" .. FormatMoney(math.abs(netProfit), "|cffff0000"))
    end
end)