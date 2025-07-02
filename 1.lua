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
returnButtonColor = colors.red
local highlightColor = colors.cyan
paginationColor = colors.gray

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
    if query == "" then
        local results = {}
        for _, item in pairs(itemsDB) do
            table.insert(results, item)
        end
        table.sort(results, function(a, b) 
            return a.displayName < b.displayName 
        end)
        return results
    end
    
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
        
        if chest.pushItems(OUTPUT_CHEST, loc.slot, toExtract) then
            loc.count = loc.count - toExtract
            itemsDB[itemKey].total = itemsDB[itemKey].total - toExtract
            remaining = remaining - toExtract
        end
    end
    
    return remaining == 0
end

-- Return items from output to system
local function returnItemsToSystem()
    local itemsMoved = 0
    for slot = 1, output.size() do
        local item = output.getItemDetail(slot)
        if item then
            local key = item.name.."@"..item.damage
            local moved = output.pushItems(CHEST_SIDE, slot, item.count)
            itemsMoved = itemsMoved + moved
        end
    end
    return itemsMoved
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
    
    -- Pagination controls
    local pagination = "< Page "..currentPage.." >"
    monitor.setCursorPos(math.floor((w - #pagination) / 2) + 1, y)
    monitor.write(pagination)
    
    -- Return items button
    local returnText = " [Return Items] "
    monitor.setBackgroundColor(returnButtonColor)
    monitor.setCursorPos(w - #returnText + 1, y)
    monitor.write(returnText)
end

local function drawItemList()
    local startY = 2
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
    
    -- No items message
    if #searchResults == 0 then
        monitor.setCursorPos(math.floor(w/2)-7, math.floor(h/2))
        monitor.write("No items found")
    end
end

local function redrawUI()
    monitor.setBackgroundColor(bgColor)
    monitor.clear()
    
    drawHeader()
    drawItemList()
    drawFooter()
end

-- Input handling
local function handleInput()
    while true do
        local event, side, x, y = os.pullEvent()
        
        if event == "monitor_touch" and side == MONITOR_SIDE then
            -- Handle touch input
            if y == h then -- Footer area
                -- Return items button
                local returnText = " [Return Items] "
                local returnX = w - #returnText + 1
                if x >= returnX and x <= w then
                    local itemsMoved = returnItemsToSystem()
                    print("Returned "..itemsMoved.." items to system")
                    redrawUI()
                
                -- Pagination controls
                else
                    local pagination = "< Page "..currentPage.." >"
                    local paginationX = math.floor((w - #pagination) / 2) + 1
                    
                    -- Left arrow
                    if x >= paginationX and x < paginationX + 2 then
                        currentPage = math.max(1, currentPage - 1)
                        redrawUI()
                    
                    -- Right arrow
                    elseif x > paginationX + #pagination - 3 and x <= paginationX + #pagination then
                        currentPage = currentPage + 1
                        redrawUI()
                    end
                end
            
            -- Item selection (y from 2 to h-1)
            elseif y >= 2 and y <= h-1 then
                local itemsPerPage = (h - 1) - 2
                local idx = (y - 2) + ((currentPage - 1) * itemsPerPage)
                
                if searchResults[idx] then
                    local item = searchResults[idx]
                    if retrieveItem(item.name.."@"..item.damage, 1) then
                        print("Retrieved 1 "..item.displayName)
                        scanInventories()
                        searchResults = searchItems(searchQuery)
                        redrawUI()
                    else
                        print("Retrieval failed!")
                    end
                end
            end
            
        elseif event == "char" then
            -- Search from computer terminal
            term.setCursorPos(1, 1)
            term.clear()
            term.write("Enter search query: ")
            searchQuery = read()
            
            if searchQuery then
                searchResults = searchItems(searchQuery)
                currentPage = 1
                redrawUI()
            end
        
        elseif event == "key" then
            -- Arrow key pagination
            if side == 203 then -- Left arrow
                currentPage = math.max(1, currentPage - 1)
                redrawUI()
            elseif side == 205 then -- Right arrow
                currentPage = currentPage + 1
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

print("System ready! Use arrow keys for pagination")
print("Type anything to search items")
print("Tap items on monitor to retrieve")
handleInput()
