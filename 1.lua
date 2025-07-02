-- Configuration
local OUTPUT_CHEST = "top" -- Output chest side
local MONITOR_SIDE = "right" -- Advanced monitor side

-- Main components
local monitor = peripheral.wrap(MONITOR_SIDE)
local output = peripheral.wrap(OUTPUT_CHEST)
local chests = {}

-- ... (остальной код без изменений до функции returnItemsToSystem) ...

-- Return items from output to system
local function returnItemsToSystem()
    -- FIX: Added nil check for output
    if not output then
        print("Error: Output chest not found!")
        return 0
    end
    
    local itemsMoved = 0
    for slot = 1, output.size() do  -- FIXED: output.size() instead of output_size()
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
                local moved = output.pushItems(peripheral.getName(targetChest), slot, item.count)
                itemsMoved = itemsMoved + moved
            end
        end
    end
    return itemsMoved
end

-- ... (остальной код без изменений) ...

-- System startup
print("Initializing ME system...")

-- FIX: Check for output chest
if not output then
    print("Error: Output chest not found on side "..OUTPUT_CHEST)
    print("Connect an output chest to continue")
    return
end

findChests()
scanInventories()
searchResults = searchItems("")
redrawUI()

print("System ready! Use arrow keys for pagination")
print("Type anything to search items")
print("Tap items on monitor to retrieve")
handleInput()
