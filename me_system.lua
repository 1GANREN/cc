-- ME-System для Computercraft Tweaked
-- Финальная исправленная версия

local basalt = require("basalt")
local chestNames = {"minecraft:chest"} -- Названия сундуков по умолчанию

-- Объявляем таблицы для хранения элементов GUI
local guiElements = {
    chestButtons = {},
    logLabels = {}
}

-- Функция безопасного чтения файла
local function safeReadFile(path)
    if fs.exists(path) then
        local file = fs.open(path, "r")
        local content = file.readAll()
        file.close()
        return content
    end
    return nil
end

-- Сохранение конфигурации
local function saveConfig()
    local data = {chestNames = chestNames}
    local file = fs.open("me_config.cfg", "w")
    file.write(textutils.serialize(data))
    file.close()
end

-- Загрузка конфигурации с защитой от ошибок
local function loadConfig()
    local content = safeReadFile("me_config.cfg")
    if content then
        local success, data = pcall(textutils.unserialize, content)
        if success and type(data) == "table" and data.chestNames then
            chestNames = data.chestNames
            return
        else
            print("Ошибка конфига. Использую настройки по умолчанию")
        end
    end
    saveConfig() -- Создаём новый конфиг
end

-- Автообнаружение сундуков
local function findChests()
    local found = {}
    local peripherals = peripheral.getNames()
    
    for _, name in ipairs(peripherals) do
        local pType = peripheral.getType(name)
        for _, chestType in ipairs(chestNames) do
            if pType == chestType then
                table.insert(found, {
                    name = name,
                    type = pType,
                    peripheral = peripheral.wrap(name)
                })
                break
            end
        end
    end
    
    return found
end

-- Создание GUI
local mainFrame = basalt.createFrame()
local chestFrame = mainFrame:addFrame():setPosition(1, 4):setSize(30, 15)
local logFrame = mainFrame:addFrame():setPosition(31, 4):setSize(20, 15)

-- Панель управления
local controlFrame = mainFrame:addFrame()
    :setPosition(1, 1)
    :setSize(50, 3)
    :setBackground(colors.gray)

controlFrame:addLabel()
    :setText("Названия сундуков:")
    :setPosition(2, 1)
    :setForeground(colors.white)

local inputText = table.concat(chestNames, ",")
local input = controlFrame:addInput()
    :setPosition(2, 2)
    :setSize(40, 1)
    :setBackground(colors.white)
    :setForeground(colors.black)

input.text = inputText

controlFrame:addButton()
    :setText("Сканировать")
    :setPosition(43, 2)
    :setSize(8, 1)
    :onClick(function()
        local value = input.text or ""
        if value ~= "" then
            chestNames = {}
            for name in value:gmatch("[^,]+") do
                table.insert(chestNames, name:trim())
            end
            saveConfig()
            updateChestList()
        end
    end)

controlFrame:addButton()
    :setText("Применить")
    :setPosition(33, 2)
    :setSize(8, 1)
    :onClick(function()
        local value = input.text or ""
        if value ~= "" then
            chestNames = {}
            for name in value:gmatch("[^,]+") do
                table.insert(chestNames, name:trim())
            end
            saveConfig()
            basalt.debug("Настройки сохранены: "..table.concat(chestNames, ", "))
        end
    end)

-- Функция очистки элементов GUI
local function clearGUI()
    -- Удаляем кнопки сундуков
    for _, button in ipairs(guiElements.chestButtons) do
        button:remove()
    end
    guiElements.chestButtons = {}
    
    -- Удаляем лейблы лога
    for _, label in ipairs(guiElements.logLabels) do
        label:remove()
    end
    guiElements.logLabels = {}
end

-- Функция обновления списка сундуков
local function updateChestList()
    clearGUI()  -- Очищаем предыдущие элементы
    
    local chests = findChests()
    
    -- Добавляем информацию о количестве сундуков
    local statusLabel = logFrame:addLabel()
        :setText("Найдено: "..#chests.." сундуков")
        :setPosition(1, 1)
    table.insert(guiElements.logLabels, statusLabel)
    
    local y = 1
    for _, chest in ipairs(chests) do
        local button = chestFrame:addButton()
            :setPosition(2, y)
            :setSize(26, 3)
            :setText(chest.name)
            :onClick(function()
                clearGUI()  -- Очищаем предыдущие элементы
                
                local selectedLabel = logFrame:addLabel()
                    :setText("Выбрано: "..chest.name)
                    :setPosition(1, 1)
                table.insert(guiElements.logLabels, selectedLabel)
                
                local success, items = pcall(function()
                    return chest.peripheral.list()
                end)
                
                if success then
                    local itemY = 2
                    for slot, item in pairs(items) do
                        if item then
                            local itemLabel = logFrame:addLabel()
                                :setText(item.name.." x"..item.count)
                                :setPosition(1, itemY)
                            table.insert(guiElements.logLabels, itemLabel)
                            itemY = itemY + 1
                        end
                    end
                else
                    local errorLabel = logFrame:addLabel()
                        :setText("Ошибка доступа")
                        :setPosition(1, 2)
                    table.insert(guiElements.logLabels, errorLabel)
                end
            end)
        
        table.insert(guiElements.chestButtons, button)
        y = y + 4
    end
end

-- Инициализация системы
loadConfig()
updateChestList()
