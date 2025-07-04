-- Configuration
local OUTPUT_CHEST = "top" -- Output chest side
local MONITOR_SIDE = "right" -- Advanced monitor side

-- Main components
local monitor = peripheral.wrap(MONITOR_SIDE)
local output = peripheral.wrap(OUTPUT_CHEST)
local chests = {}

-- UI Constants
local ITEMS_PER_PAGE = 28
local MAX_NAME_LENGTH = 20

-- System state
local currentPage = 1
local searchResults = {}
local searchTerm = ""

-- Find all connected storage chests
local function findChests()
    chests = {}
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "minecraft:chest" or 
           peripheral.getType(side) == "ironchest:iron_chest" or
           peripheral.getType(side) == "appliedenergistics2:chest" then
            table.insert(chests, {
                name = side,
                peripheral = peripheral.wrap(side)
            })
        end
    end
end

-- Scan all inventories and build item list
local function scanInventories()
    local items = {}
    
    for _, chest in ipairs(chests) do
        if chest.peripheral then
            for slot = 1, chest.peripheral.size() do
                local item = chest.peripheral.getItemDetail(slot)
                if item then
                    -- Check if we already have this item
                    local found = false
                    for _, existing in ipairs(items) do
                        if existing.name == item.name and 
                           existing.damage == item.damage and
                           (existing.nbt == item.nbt or (not existing.nbt and not item.nbt)) then
                            existing.count = existing.count + item.count
                            found = true
                            break
                        end
                    end
                    
                    if not found then
                        table.insert(items, {
                            name = item.name,
                            displayName = item.displayName,
                            count = item.count,
                            damage = item.damage,
                            nbt = item.nbt,
                            chest = chest.name,
                            slot = slot
                        })
                    end
                end
            end
        end
    end
    
    return items
end

-- Search items by name
local function searchItems(term)
    term = term:lower()
    local allItems = scanInventories()
    local results = {}
    
    for _, item in ipairs(allItems) do
        if term == "" or 
           item.name:lower():find(term, 1, true) or 
           item.displayName:lower():find(term, 1, true) then
            table.insert(results, item)
        end
    end
    
    -- Sort alphabetically
    table.sort(results, function(a, b)
        return a.displayName:lower() < b.displayName:lower()
    end)
    
    return results
end

-- Return items from output to system
local function returnItemsToSystem()
    if not output then
        print("Error: Output chest not found!")
        return 0
    end
    
    local itemsMoved = 0
    for slot = 1, output.size() do
        local item = output.getItemDetail(slot)
        if item then
            -- Find any storage chest
            local targetChest = nil
            for _, chest in ipairs(chests) do
                if chest.peripheral then
                    targetChest = chest.peripheral
                    break
                end
            end
            
            if targetChest then
                local moved = output.pushItems(peripheral.getName(targetChest), slot)
                itemsMoved = itemsMoved + moved
            end
        end
    end
    return itemsMoved
end

-- Draw the UI
local function redrawUI()
    if not monitor then return end
    
    monitor.clear()
    monitor.setCursorPos(1, 1)
    
    local w, h = monitor.getSize()
    local title = "ME Storage System"
    if searchTerm ~= "" then
        title = title .. " - Search: " .. searchTerm
    end
    
    monitor.write(title)
    monitor.setCursorPos(1, 2)
    monitor.write(string.rep("-", w))
    
    -- Calculate page count
    local pageCount = math.ceil(#searchResults / ITEMS_PER_PAGE)
    if pageCount == 0 then pageCount = 1 end
    
    -- Display page info
    monitor.setCursorPos(1, h)
    monitor.write("Page " .. currentPage .. "/" .. pageCount)
    
    -- Display items
    local startIndex = (currentPage - 1) * ITEMS_PER_PAGE + 1
    local endIndex = math.min(startIndex + ITEMS_PER_PAGE - 1, #searchResults)
    
    local y = 3
    for i = startIndex, endIndex do
        local item = searchResults[i]
        local displayName = item.displayName
        if #displayName > MAX_NAME_LENGTH then
            displayName = displayName:sub(1, MAX_NAME_LENGTH - 3) .. "..."
        end
        
        monitor.setCursorPos(1, y)
        monitor.write(displayName)
        
        monitor.setCursorPos(MAX_NAME_LENGTH + 2, y)
        monitor.write("x" .. item.count)
        
        y = y + 1
    end
end

-- Retrieve an item from storage
local function retrieveItem(index)
    local item = searchResults[index]
    if not item then return false end
    
    -- Find the chest
    local chest = nil
    for _, c in ipairs(chests) do
        if c.name == item.chest then
            chest = c.peripheral
            break
        end
    end
    
    if not chest then return false end
    
    -- Clear output first
    returnItemsToSystem()
    
    -- Transfer item
    local success = chest.pushItems(peripheral.getName(output), item.slot, 64)
    if success > 0 then
        return true
    end
    return false
end

-- Handle monitor touch events
local function handleTouch(x, y)
    if y >= 3 and y <= 3 + ITEMS_PER_PAGE - 1 then
        local index = (currentPage - 1) * ITEMS_PER_PAGE + (y - 2)
        if index <= #searchResults then
            if retrieveItem(index) then
                searchResults = searchItems(searchTerm)
                redrawUI()
            end
        end
    end
end

-- Handle keyboard input
local function handleInput()
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        
        if event == "monitor_touch" then
            handleTouch(param2, param3)
        elseif event == "key" then
            if param1 == keys.up and currentPage > 1 then
                currentPage = currentPage - 1
                redrawUI()
            elseif param1 == keys.down and currentPage < math.ceil(#searchResults / ITEMS_PER_PAGE) then
                currentPage = currentPage + 1
                redrawUI()
            end
        elseif event == "char" then
            if param1 == "\r" or param1 == "\n" then -- Enter
                searchResults = searchItems(searchTerm)
                currentPage = 1
                redrawUI()
                searchTerm = ""
            elseif param1 == "\b" then -- Backspace
                searchTerm = searchTerm:sub(1, -2)
                redrawUI()
            else
                searchTerm = searchTerm .. param1
                redrawUI()
            end
        end
    end
end

-- System startup
print("Initializing ME system...")

-- Check for output chest
if not output then
    print("Error: Output chest not found on side "..OUTPUT_CHEST)
    print("Connect an output chest to continue")
    return
end

-- Check for monitor
if not monitor then
    print("Error: Monitor not found on side "..MONITOR_SIDE)
    print("Connect an advanced monitor to continue")
    return
end

findChests()
scanInventories()
searchResults = searchItems("")
redrawUI()

print("System ready! Use arrow keys for pagination")
print("Type anything to search items")
print("Tap items on monitor to retrieve")

-- Register monitor touch event
if monitor then
    peripheral.call(MONITOR_SIDE, "setTextScale", 0.5)
end

handleInput()
