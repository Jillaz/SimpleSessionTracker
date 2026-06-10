-- ==========================================
-- SpellIDTooltip.lua: Отображение ID в подсказках (ToolTips)
-- Версия: 2.2 (Убрано из экшен-бара, оставлено в Книге заклинаний)
-- ==========================================

local function AddSpellIDToTooltip(self, spellID, spellName)
    if spellID then
        local displayText = "ID: " .. spellID
        if spellName then
            displayText = displayText .. " (" .. spellName .. ")"
        end
        -- Светло-серый цвет, чтобы не отвлекать от основного описания
        self:AddLine(displayText, 0.7, 0.7, 0.7)
        self:Show() -- Перерисовываем подсказку для корректного расчета размера
    end
end

-- 1. Хук для книги заклинаний (Spellbook) - ОСТАВЛЯЕМ
local origSetSpell = GameTooltip.SetSpell
GameTooltip.SetSpell = function(self, spellName, rank, ...)
    origSetSpell(self, spellName, rank, ...) -- Сначала рисуем стандартную подсказку
    
    local link
    if rank and rank ~= "" then
        link = GetSpellLink(spellName, rank)
    else
        link = GetSpellLink(spellName)
    end
    
    if link then
        local spellID = string.match(link, "spell:(%d+)")
        AddSpellIDToTooltip(self, spellID, spellName)
    end
end

-- 2. Хук для гиперссылок (чаты, чары, некоторые элементы интерфейса) - ОСТАВЛЯЕМ
local origSetHyperlink = GameTooltip.SetHyperlink
GameTooltip.SetHyperlink = function(self, link, ...)
    origSetHyperlink(self, link, ...)
    if link and type(link) == "string" then
        local spellID = string.match(link, "spell:(%d+)")
        if spellID then
            local spellName = GetSpellInfo(spellID)
            AddSpellIDToTooltip(self, spellID, spellName)
        end
    end
end

-- 3. Хук для дерева талантов (Talent Tree) - ОСТАВЛЯЕМ
local origSetTalent = GameTooltip.SetTalent
if origSetTalent then
    GameTooltip.SetTalent = function(self, tab, index, ...)
        origSetTalent(self, tab, index, ...)
        local link = GetTalentLink(tab, index)
        if link then
            local spellID = string.match(link, "spell:(%d+)")
            if spellID then
                local spellName = GetSpellInfo(spellID)
                AddSpellIDToTooltip(self, spellID, spellName)
            end
        end
    end
end