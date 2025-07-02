-- Configuration
local CHEST_SIDE = "back" -- Chest connection side
local OUTPUT_CHEST = "top" -- Output chest
local MONITOR_SIDE = "right" -- Advanced monitor

-- Main components
local monitor = peripheral.wrap(MONITOR_SIDE)
local output = peripheral.wrap(OUTPUT_CHEST)
local chests = {}

-- Items database
local itemsDB = {}
local lastScan = 0

-- Monitor resolution
local w, h = monitor.getSize()

-- Color scheme
local bgColor = colors.black
local textColor = colors.white
local headerColor = colors.blue
local buttonColor = colors.green
local highlightColor = colors.cyan

-- Initialization
monitor.setTextScale(0.5)
monitor.setBackgroundColor(bgColor)
monitor.clear()

-- Find all chests
local function findChests()
    chests = {}
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "inventory" and side ~= OUTPUT_CHEST then
            table.insert(chests, {
                peripheral = peripheral.wrap(side),
                name = side
            })
        end
    end
    return #chests
end

-- Scan inventories
local function scanInventories()
    itemsDB = {}
    for _, chest in ipairs(chests) do
        local inv = chest.peripheral
        for slot = 1, inv.size() do
            local item = inv.getItemDetail(slot)
            if item then
                local key = item.name.."@"..item.damage
                if not itemsDB[key] then
                    itemsDB[key] = {
                        name = item.name,
                        damage = item.damage,
                        displayName = item.displayName,
                        total = 0,
                        locations = {}
                    }
                end
                itemsDB[key].total = itemsDB[key].total + item.count
                table.insert(itemsDB[key].locations, {
                    chest = chest.name,
                    slot = slot,
                    count = item.count
                })
            end
        end
    end
    lastScan = os.epoch("utc")
    return true
end

-- Find item
local function searchItems(query)
    local results = {}
    query = query:lower()
    for _, item in pairs(itemsDB) do
        if item.displayName:lower():find(query, 1, true) 
           or item.name:lower():find(query, 1, true) then
            table.insert(results, item)
        end
    end
    table.sort(results, function(a, b) 
        return a.displayName < b.displayName 
    end)
    return results
end

-- Retrieve item
local function retrieveItem(itemKey, amount)
    if not itemsDB[itemKey] then return false end
    
    local remaining = amount
    for _, loc in ipairs(itemsDB[itemKey].locations) do
        if remaining <= 0 then break end
        
        local chest = peripheral.wrap(loc.chest)
        local toExtract = math.min(remaining, loc.count)
        
        chest.pushItems(OUTPUT_CHEST, loc.slot, toExtract)
        loc.count = loc.count - toExtract
        itemsDB[itemKey].total = itemsDB[itemKey].total - toExtract
        remaining = remaining - toExtract
    end
    
    return remaining == 0
end

-- User interface
local currentPage = 1
local searchQuery = ""
local searchResults = {}
local selectedItem = nil

local function drawHeader()
    monitor.setBackgroundColor(headerColor)
    monitor.setTextColor(textColor)
    monitor.setCursorPos(1, 1)
    monitor.clearLine()
    monitor.write(" ME System ")
    
    -- Database status
    local status = "Items: "..tableCount(itemsDB)
    monitor.setCursorPos(w - #status + 1, 1)
    monitor.write(status)
end

local function drawFooter()
    local y = h
    monitor.setBackgroundColor(headerColor)
    monitor.setTextColor(textColor)
    monitor.setCursorPos(1, y)
    monitor.clearLine()
    
    local help = "F1=Refresh  F2=Search  F3=Retrieve"
    monitor.setCursorPos(math.floor((w - #help) / 2) + 1, y)
    monitor.write(help)
end

local function drawSearchBar()
    monitor.setBackgroundColor(bgColor)
    monitor.setTextColor(textColor)
    monitor.setCursorPos(1, 2)
    monitor.clearLine()
    
    monitor.write("Search: ")
    local inputPos = 9
    monitor.setCursorPos(inputPos, 2)
    monitor.write(searchQuery)
    
    if #searchQuery < w - inputPos then
        monitor.write("_") -- Cursor
    end
end

local function drawItemList()
    local startY = 3
    local endY = h - 1
    local itemsPerPage = endY - startY
    
    -- Pagination
    local totalPages = math.max(1, math.ceil(#searchResults / itemsPerPage))
    currentPage = math.min(currentPage, totalPages)
    
    monitor.setBackgroundColor(bgColor)
    monitor.setTextColor(textColor)
    
    -- Clear area
    for y = startY, endY do
        monitor.setCursorPos(1, y)
        monitor.clearLine()
    end
    
    -- Display items
    local startIdx = (currentPage - 1) * itemsPerPage + 1
    local endIdx = math.min(startIdx + itemsPerPage - 1, #searchResults)
    
    for i = startIdx, endIdx do
        local item = searchResults[i]
        local yPos = startY + (i - startIdx)
        
        -- Highlight selected item
        if selectedItem == item then
            monitor.setBackgroundColor(highlightColor)
        else
            monitor.setBackgroundColor(bgColor)
        end
        
        monitor.setCursorPos(1, yPos)
        monitor.clearLine()
        
        -- Name and quantity
        local text = ("%s x%d"):format(item.displayName, item.total)
        if #text > w then
            text = text:sub(1, w-3).."..."
        end
        monitor.write(text)
    end
    
    -- Pagination
    if totalPages > 1 then
        monitor.setBackgroundColor(bgColor)
        monitor.setTextColor(colors.lightGray)
        local pageText = ("Page %d/%d"):format(currentPage, totalPages)
        monitor.setCursorPos(w - #pageText + 1, endY)
        monitor.write(pageText)
    end
end

local function drawItemDetails()
    if not selectedItem then return end
    
    local details = {
        "Name: "..selectedItem.displayName,
        "ID: "..selectedItem.name,
        "Total: "..selectedItem.total,
        "",
        "Press F3 to retrieve"
    }
    
    -- Center window
    local boxWidth = math.min(w - 4, 40)
    local boxHeight = #details + 2
    local startX = math.floor((w - boxWidth) / 2) + 1
    local startY = math.floor((h - boxHeight) / 2) + 1
    
    -- Frame
    monitor.setBackgroundColor(colors.gray)
    for y = startY, startY + boxHeight - 1 do
        monitor.setCursorPos(startX, y)
        monitor.write((" "):rep(boxWidth))
    end
    
    -- Text
    monitor.setTextColor(textColor)
    for i, line in ipairs(details) do
        monitor.setCursorPos(startX + 1, startY + i)
        monitor.write(line)
    end
    
    -- Close button
    monitor.setBackgroundColor(colors.red)
    monitor.setCursorPos(startX + boxWidth - 1, startY)
    monitor.write("X")
end

local function redrawUI()
    monitor.setBackgroundColor(bgColor)
    monitor.clear()
    
    drawHeader()
    drawSearchBar()
    drawItemList()
    drawFooter()
    
    if selectedItem then
        drawItemDetails()
    end
end

-- Input handling
local function handleInput()
    while true do
        local event, side, x, y = os.pullEvent()
        
        if event == "monitor_touch" and side == MONITOR_SIDE then
            -- Handle touch input
            if y == 2 and x >= 9 then -- Search
                selectedItem = nil
                monitor.setCursorPos(9, 2)
                monitor.blit(searchQuery, ("f"):rep(#searchQuery), ("0"):rep(#searchQuery))
                
                local newQuery = read()
                if newQuery then
                    searchQuery = newQuery
                    searchResults = searchItems(searchQuery)
                    currentPage = 1
                end
                
            elseif y >= 3 and y <= h-1 and not selectedItem then -- Select item
                local idx = (y - 3) + ((currentPage - 1) * (h - 4))
                if searchResults[idx] then
                    selectedItem = searchResults[idx]
                end
                
            elseif selectedItem then -- Close details
                selectedItem = nil
            end
            
            redrawUI()
            
        elseif event == "key" then
            -- Hotkeys
            if side == 59 then -- F1
                findChests()
                scanInventories()
                searchResults = searchItems(searchQuery)
                redrawUI()
                
            elseif side == 60 then -- F2
                term.redirect(monitor)
                monitor.setCursorPos(9, 2)
                monitor.blit(searchQuery, ("f"):rep(#searchQuery), ("0"):rep(#searchQuery))
                
                local newQuery = read()
                if newQuery then
                    searchQuery = newQuery
                    searchResults = searchItems(searchQuery)
                    currentPage = 1
                end
                term.restore()
                redrawUI()
                
            elseif side == 61 and selectedItem then -- F3
                term.redirect(monitor)
                print("How much to retrieve?")
                local amount = tonumber(read())
                
                if amount and amount > 0 then
                    if retrieveItem(selectedItem.name.."@"..selectedItem.damage, amount) then
                        print("Success!")
                    else
                        print("Retrieval error!")
                    end
                    sleep(1)
                end
                term.restore()
                scanInventories()
                searchResults = searchItems(searchQuery)
                redrawUI()
            end
        end
    end
end

-- Helper functions
function tableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- System startup
print("Initializing ME system...")
findChests()
scanInventories()
searchResults = searchItems("")
redrawUI()

print("System ready!")
handleInput()
