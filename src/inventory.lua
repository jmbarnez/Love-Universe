-- Inventory module for Love2D RPG
-- Handles player inventory with grid-based UI

local inventory = {}
local constants = require("src.constants")

-- Inventory constants
local SLOT_SIZE = 40
local SLOT_PADDING = 2
local SLOT_ROWS = 6
local SLOT_COLS = 4
local TOTAL_SLOTS = SLOT_ROWS * SLOT_COLS
local INVENTORY_MARGIN = 10

-- Inventory colors
local SLOT_BG_COLOR = {0.2, 0.2, 0.2, 0.9}
local SLOT_BORDER_COLOR = {0.5, 0.5, 0.5, 1}
local SLOT_HOVER_COLOR = {0.3, 0.3, 0.3, 1}
local WINDOW_BG_COLOR = {0.1, 0.1, 0.1, 0.8}

-- Create a new inventory
function inventory.create()
    local inv = {
        items = {},
        visible = false,
        hoveredSlot = nil
    }

    -- Initialize empty slots
    for i = 1, TOTAL_SLOTS do
        inv.items[i] = nil
    end

    return inv
end

-- Add item to inventory
function inventory.addItem(inv, item)
    -- Try to stack with existing items
    if item.stackable then
        for i = 1, TOTAL_SLOTS do
            if inv.items[i] and inv.items[i].name == item.name then
                inv.items[i].count = (inv.items[i].count or 1) + (item.count or 1)
                return true -- Item stacked
            end
        end
    end

    -- Find first empty slot
    for i = 1, TOTAL_SLOTS do
        if not inv.items[i] then
            inv.items[i] = item
            if not inv.items[i].count then inv.items[i].count = 1 end
            return true -- Item added successfully
        end
    end
    return false -- Inventory full
end

-- Remove item from inventory
function inventory.removeItem(inv, slotIndex)
    if slotIndex >= 1 and slotIndex <= TOTAL_SLOTS then
        local item = inv.items[slotIndex]
        inv.items[slotIndex] = nil
        return item
    end
    return nil
end

-- Get item from slot
function inventory.getItem(inv, slotIndex)
    if slotIndex >= 1 and slotIndex <= TOTAL_SLOTS then
        return inv.items[slotIndex]
    end
    return nil
end

-- Check if inventory has space
function inventory.hasSpace(inv)
    for i = 1, TOTAL_SLOTS do
        if not inv.items[i] then
            return true
        end
    end
    return false
end

-- Toggle inventory visibility
function inventory.toggle(inv)
    inv.visible = not inv.visible
end

-- Draw inventory UI
function inventory.draw(inv)
    if not inv.visible then return end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Calculate inventory dimensions
    local inventoryWidth = (SLOT_COLS * SLOT_SIZE) + ((SLOT_COLS - 1) * SLOT_PADDING) + (INVENTORY_MARGIN * 2)
    local inventoryHeight = (SLOT_ROWS * SLOT_SIZE) + ((SLOT_ROWS - 1) * SLOT_PADDING) + (INVENTORY_MARGIN * 2) + 30 -- Extra space for title

    -- Position in bottom right
    local inventoryX = screenWidth - inventoryWidth - 10
    local inventoryY = screenHeight - inventoryHeight - 10

    -- Draw inventory background
    love.graphics.setColor(WINDOW_BG_COLOR)
    love.graphics.rectangle("fill", inventoryX, inventoryY, inventoryWidth, inventoryHeight)

    -- Draw inventory border
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.rectangle("line", inventoryX, inventoryY, inventoryWidth, inventoryHeight)

    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    local title = "INVENTORY"
    local font = love.graphics.getFont()
    local titleWidth = font:getWidth(title)
    love.graphics.print(title, inventoryX + (inventoryWidth - titleWidth) / 2, inventoryY + 8)

    -- Draw inventory grid
    local slotX = inventoryX + INVENTORY_MARGIN
    local slotY = inventoryY + INVENTORY_MARGIN + 25 -- Account for title

    for row = 1, SLOT_ROWS do
        for col = 1, SLOT_COLS do
            local slotIndex = (row - 1) * SLOT_COLS + col
            local currentSlotX = slotX + (col - 1) * (SLOT_SIZE + SLOT_PADDING)
            local currentSlotY = slotY + (row - 1) * (SLOT_SIZE + SLOT_PADDING)

            -- Check if mouse is hovering over this slot
            local mouseX, mouseY = love.mouse.getPosition()
            local isHovered = mouseX >= currentSlotX and mouseX <= currentSlotX + SLOT_SIZE and
                             mouseY >= currentSlotY and mouseY <= currentSlotY + SLOT_SIZE

            -- Draw slot background
            if isHovered then
                love.graphics.setColor(SLOT_HOVER_COLOR)
            else
                love.graphics.setColor(SLOT_BG_COLOR)
            end
            love.graphics.rectangle("fill", currentSlotX, currentSlotY, SLOT_SIZE, SLOT_SIZE)

            -- Draw slot border
            love.graphics.setColor(SLOT_BORDER_COLOR)
            love.graphics.rectangle("line", currentSlotX, currentSlotY, SLOT_SIZE, SLOT_SIZE)

            -- Draw item if present
            local item = inv.items[slotIndex]
            if item then
                -- Draw item icon (placeholder - simple colored rectangle for now)
                love.graphics.setColor(item.color or {0.8, 0.8, 0.8, 1})
                love.graphics.rectangle("fill", currentSlotX + 4, currentSlotY + 4, SLOT_SIZE - 8, SLOT_SIZE - 8)

                -- Draw item count if stackable
                if item.count and item.count > 1 then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.print(tostring(item.count), currentSlotX + SLOT_SIZE - 15, currentSlotY + SLOT_SIZE - 15)
                end
            end

            -- Store hovered slot for mouse interaction
            if isHovered then
                inv.hoveredSlot = slotIndex
            end
        end
    end

    -- Reset hovered slot if mouse not over any slot
    local mouseX, mouseY = love.mouse.getPosition()
    local mouseOverInventory = mouseX >= inventoryX and mouseX <= inventoryX + inventoryWidth and
                              mouseY >= inventoryY and mouseY <= inventoryY + inventoryHeight

    if not mouseOverInventory then
        inv.hoveredSlot = nil
    end

    -- Draw tooltip for hovered item
    if inv.hoveredSlot and inv.items[inv.hoveredSlot] then
        local item = inv.items[inv.hoveredSlot]
        local tooltipX = mouseX + 15
        local tooltipY = mouseY - 25

        -- Tooltip background
        love.graphics.setColor(0, 0, 0, 0.8)
        local tooltipText = item.name or "Unknown Item"
        local tooltipWidth = font:getWidth(tooltipText) + 10
        local tooltipHeight = font:getHeight() + 8
        love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, tooltipHeight)

        -- Tooltip border
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", tooltipX, tooltipY, tooltipWidth, tooltipHeight)

        -- Tooltip text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(tooltipText, tooltipX + 5, tooltipY + 4)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Handle mouse click on inventory
function inventory.handleClick(inv, x, y, button)
    if not inv.visible or not inv.hoveredSlot then return end

    if button == 1 then -- Left click
        local item = inv.items[inv.hoveredSlot]
        if item then
            print("Clicked on item: " .. (item.name or "Unknown"))
            -- Handle item usage/consumption here
        end
    elseif button == 2 then -- Right click
        local item = inv.items[inv.hoveredSlot]
        if item then
            print("Right-clicked on item: " .. (item.name or "Unknown"))
            -- Handle item context menu here
        end
    end
end

-- Get inventory dimensions for positioning other UI elements
function inventory.getDimensions()
    local inventoryWidth = (SLOT_COLS * SLOT_SIZE) + ((SLOT_COLS - 1) * SLOT_PADDING) + (INVENTORY_MARGIN * 2)
    local inventoryHeight = (SLOT_ROWS * SLOT_SIZE) + ((SLOT_ROWS - 1) * SLOT_PADDING) + (INVENTORY_MARGIN * 2) + 30

    return inventoryWidth, inventoryHeight
end

return inventory
