-- ME-System для Computercraft Tweaked
-- Требует: basalt (установка: pastebin run getBasalt)

-- 1. Инициализация и конфигурация
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
  local data = {
    chestNames = chestNames
  }
  local file = fs.open("me_config.cfg", "w")
  file.write(textutils.serialize(data))
  file.close()
end

-- 2. Автообнаружение сундуков
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

-- 3. Графический интерфейс
local mainFrame = basalt.createFrame()
local chestFrame = mainFrame:addFrame():setPosition(1,2):setSize(30,15)
local logFrame = mainFrame:addFrame():setPosition(31,2):setSize(20,15)

-- Панель управления
local controlFrame = mainFrame:addFrame()
  :setPosition(1,1)
  :setSize(50,1)
  :setBackground(colors.gray)

controlFrame:addLabel()
  :setText("ME System")
  :setPosition(2,1)
  :setForeground(colors.white)

controlFrame:addButton()
  :setText("Scan")
  :setPosition(20,1)
  :setSize(6,1)
  :onClick(function()
    updateChestList()
  end)

-- Поле для ввода названий сундуков
local input = controlFrame:addInput()
  :setPosition(30,1)
  :setSize(15,1)
  :setDefaultText("chest1,chest2")
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
        -- Действие при клике на сундук
        logFrame:addLabel():setText("Selected: "..chest.name):setPosition(1,1)
      end)
    
    y = y + 4
  end
end

-- 4. Инициализация системы
loadConfig()
updateChestList()

-- 5. Запуск GUI
basalt.autoUpdate()
