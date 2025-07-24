-- ME-System для Computercraft Tweaked с автозагрузкой Basalt
-- Если библиотека отсутствует, скачивает её напрямую с GitHub

-- 1. Проверка и установка Basalt
local function setupBasalt()
    if not fs.exists("basalt") then
        fs.makeDir("basalt")
    end
    
    if not fs.exists("basalt/install.lua") then
        print("Скачивание Basalt...")
        local response = http.get("https://raw.githubusercontent.com/Pyroxenium/Basalt/master/install.lua")
        if not response then
            error("Не удалось скачать Basalt. Проверьте подключение к интернету.")
        end
        
        local file = fs.open("basalt/install", "w")
        file.write(response.readAll())
        file.close()
        response.close()
        os.run({}, "basalt/install")
    end
end

setupBasalt()
local basalt = require("basalt")

-- 2. Инициализация и конфигурация
local chestNames = {"minecraft:chest"} -- Названия сундуков по умолчанию

-- Загрузка конфигурации
local function loadConfig()
    if fs.exists("me_config.cfg") then
        local file = fs.open("me_config.cfg", "r")
        local data = textutils.unserialize(file.readAll() or "{}")
        file.close()
        chestNames = data.chestNames or {"minecraft:chest"}
    else
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

-- 3. Автообнаружение сундуков
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

-- 4. Графический интерфейс
local main = basalt.createFrame()
local chestFrame = main:addFrame():setPosition(1, 3):setSize(30, 15)
local logFrame = main:addFrame():setPosition(31, 3):setSize(20, 15)

-- Верхняя панель для ввода названий сундуков
local inputFrame = main:addFrame():setPosition(1,1):setSize(50,2):setBackground(colors.gray)
inputFrame:addLabel():setText("Названия сундуков:"):setPosition(2,1):setForeground(colors.white)

local input = inputFrame:addInput()
    :setPosition(1,2)
    :setSize(40,1)
    :setDefaultText("Введите через запятую")
    :setValue(table.concat(chestNames, ","))

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

-- Кнопка сканирования
inputFrame:addButton():setText("Сканировать"):setPosition(42,2):setSize(8,1):onClick(updateChestList)

-- Отображение сундуков
function updateChestList()
    chestFrame:removeChildren()
    local chests = findChests()
    
    local y = 1
    for _, chest in ipairs(chests) do
        chestFrame:addButton()
            :setPosition(2, y)
            :setSize(26, 3)
            :setText(chest.name)
            :onClick(function()
                logFrame:removeChildren()
                logFrame:addLabel():setText("Выбрано: "..chest.name):setPosition(1,1)
                -- Здесь можно добавить функционал для работы с сундуком
            end)
        y = y + 4
    end
    
    logFrame:removeChildren()
    logFrame:addLabel():setText("Найдено: "..#chests.." сундуков"):setPosition(1,1)
end

-- 5. Инициализация и запуск
loadConfig()
updateChestList()
basalt.autoUpdate()
