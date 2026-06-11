-- ==========================================
-- Settings.lua: Управление визуальными настройками (Цвет и Шрифт)
-- ==========================================

SST.Settings = {}

-- Инициализация настроек по умолчанию, если их нет в сохранении
function SST.Settings.InitDefaults()
    if not SST_DB.bgColor then
        -- Формат: {R, G, B, Alpha} от 0.0 до 1.0
        SST_DB.bgColor = {0.1, 0.1, 0.1, 0.85} 
    end
    if not SST_DB.fontSize then
        SST_DB.fontSize = 12 -- Стандартный размер шрифта
    end
end

-- Применение настроек ко всем элементам интерфейса
function SST.Settings.Apply()
    local r, g, b, a = unpack(SST_DB.bgColor)
    local fontPath = "Fonts\\FRIZQT__.TTF" -- Стандартный шрифт WoW
    local size = SST_DB.fontSize
    local flags = "OUTLINE" -- Обводка для лучшей читаемости

    -- 1. Обновляем цвет фона главного окна
    if SST.Frame and SST.Frame.bg then
        SST.Frame.bg:SetTexture(r, g, b, a)
    end

    -- 2. Обновляем шрифты в модуле Session
    if SST.Session and SST.Session.elements then
        for _, fs in pairs(SST.Session.elements) do
            if fs and fs.SetFont then
                fs:SetFont(fontPath, size, flags)
            end
        end
    end

    -- 3. Обновляем шрифты в модуле Cooldowns
    if SST.Cooldowns then
        if SST.Cooldowns.elements and SST.Cooldowns.elements.cdTitle then
            SST.Cooldowns.elements.cdTitle:SetFont(fontPath, size, flags)
        end
        
        -- Обновляем шрифт во всех кнопках списка заклинаний
        if SST.Cooldowns.frames then
            for _, btn in ipairs(SST.Cooldowns.frames) do
                if btn.text and btn.text.SetFont then
                    btn.text:SetFont(fontPath, size, flags)
                end
            end
        end
    end
    
    -- Пересчитываем макет, так как изменение размера шрифта может изменить высоту строк
    if SST.Cooldowns and SST.Cooldowns.UpdateLayout then
        SST.Cooldowns.UpdateLayout()
    end
end

-- Обработка команды изменения цвета: /sst color <R> <G> <B> <A>
function SST.Settings.ChangeColor(colorStr)
    local r, g, b, a = strsplit(" ", colorStr)
    r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a)
    
    if r and g and b and a and r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1 and a >= 0 and a <= 1 then
        SST_DB.bgColor = {r, g, b, a}
        SST.Settings.Apply()
        print(string.format("|cff00ff00[SST]|r Цвет фона изменен на: R=%.2f G=%.2f B=%.2f A=%.2f", r, g, b, a))
    else
        print("|cffff0000[SST]|r Ошибка формата. Используйте: |cff00ff00/sst color 0.1 0.1 0.1 0.85|r (значения от 0.0 до 1.0)")
        print("|cffaaaaaaПримеры:|r")
        print("  |cff00ff00/sst color 0 0 0 0.8|r (Черный полупрозрачный)")
        print("  |cff00ff00/sst color 0.2 0.1 0.1 0.9|r (Темно-красный)")
    end
end

-- Обработка команды изменения размера шрифта: /sst fontsize <размер>
function SST.Settings.ChangeFontSize(sizeStr)
    local size = tonumber(sizeStr)
    if size and size >= 8 and size <= 24 then
        SST_DB.fontSize = size
        SST.Settings.Apply()
        print("|cff00ff00[SST]|r Размер шрифта изменен на: " .. size)
    else
        print("|cffff0000[SST]|r Ошибка. Размер шрифта должен быть числом от 8 до 24. Пример: |cff00ff00/sst fontsize 14|r")
    end
end