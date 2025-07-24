-- ME-System для Computercraft Tweaked
-- Исправленная версия для текущей установки Basalt

local basalt = require("basalt")
local chestNames = {} -- Названия сундуков для поиска

-- Загрузка конфигурации
local function loadConfig()
    if fs.exists("me_config.cfg") then
        local file = fs.open("me_config.cfg", "r")
        local data = textutils.unserialize(file.readAll() or "{}")
        file.close()
        chestNames = data.chestNames or {"minecraft:chest"}
    else
        chestNames = {"minecraft:chest"} -- Сундуки по умолчанию
        saveConfig()
    end
end

-- Сохранение конфигурации
local function saveConfig()
    local data = {chestNames = chestNames}
    local file = fs.open("me_config.cfg", "w")
    file.write(textutils.serialize(data))
    file.close()
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
local chestFrame = mainFrame:addFrame():setPosition(1, 3):setSize(30, 15)
local logFrame = mainFrame:addFrame():setPosition(31, 3):setSize(20, 15)

-- Панель управления
local controlFrame = mainFrame:addFrame()
    :setPosition(1, 1)
    :setSize(50, 2)
    :setBackground(colors.gray)

controlFrame:addLabel()
    :setText("ME System")
    :setPosition(2, 1)
    :setForeground(colors.white)

controlFrame:addButton()
    :setText("Scan")
    :setPosition(20, 1)
    :setSize(6, 1)
    :onClick(function()
        updateChestList()
    end)

-- Поле для ввода названий сундуков (исправлено)
local input = controlFrame:addInput()
    :setPosition(30, 1)
    :setSize(15, 1)
    :setValue(table.concat(chestNames, ",")) -- Используем setValue вместо setDefaultText

input:onEnter(function(self)
    local value = self:getValue()
    if value ~= "" then
        chestNames = {}
        for name in value:gmatch("[^,]+") do
            table.insert(chestNames, name:trim())
        end
        saveConfig()
        updateChestList()
    end
end)

-- Отображение сундуков
local function updateChestList()
    chestFrame:removeChildren()
    local chests = findChests()
    
    local y = 1
    for _, chest in ipairs(chests) do
        local btn = chestFrame:addButton()
            :setPosition(2, y)
            :setSize(26, 3)
            :setText(chest.name)
            :onClick(function()
                logFrame:removeChildren()
                logFrame:addLabel():setText("Selected: "..chest.name):setPosition(1, 1)
                
                -- Дополнительный функционал при клике
                -- Например: открытие инвентаря сундука
                local items = chest.peripheral.list()
                local itemY = 2
                for slot, item in pairs(items) do
                    if item then
                        logFrame:addLabel():setText(item.name.." x"..item.count):setPosition(1, itemY)
                        itemY = itemY + 1
                    end
                end
            end)
        y = y + 4
    end
    
    -- Обновляем статус в логе
    logFrame:removeChildren()
    logFrame:addLabel():setText("Found: "..#chests.." chests"):setPosition(1, 1)
end

-- Инициализация системы
loadConfig()
updateChestList()

-- Запуск GUI
basalt.autoUpdate()
