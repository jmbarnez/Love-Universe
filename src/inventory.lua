-- Enhanced Inventory module for Love2D RPG
-- Handles player inventory with advanced drag & drop, context menus, and tooltips

local inventory = {}
local constants = require("src.constants")
local ui = require("src.ui")
local suit = require("lib.suit")

-- Inventory constants (scaled)
local SLOT_ROWS = 6
local SLOT_COLS = 4
local TOTAL_SLOTS = SLOT_ROWS * SLOT_COLS

-- Helper functions to get scaled values
local function getSlotSize()
    return constants.INVENTORY_SLOT_SIZE or math.floor(40 * constants.UI_SCALE)
end

local function getSlotPadding()
    return constants.INVENTORY_SLOT_PADDING or math.floor(2 * constants.UI_SCALE)
end

local function getInventoryMargin()
    return constants.INVENTORY_MARGIN or math.floor(10 * constants.UI_SCALE)
end

-- Compatibility constants for old code
local SLOT_SIZE = getSlotSize()
local SLOT_PADDING = getSlotPadding()
local INVENTORY_MARGIN = getInventoryMargin()

-- Inventory colors (will be overridden by UI theme)
local SLOT_BG_COLOR = {0.2, 0.2, 0.2, 0.9}
local SLOT_BORDER_COLOR = {0.5, 0.5, 0.5, 1}
local SLOT_HOVER_COLOR = {0.3, 0.3, 0.3, 1}
local WINDOW_BG_COLOR = {0.1, 0.1, 0.1, 0.8}

-- Panel system for multi-panel support
local panelSystem = {
    panels = {},
    activePanel = nil
}

-- Update all panel layouts when scaling changes
function panelSystem.updateLayout()
    -- Update compatibility constants
    SLOT_SIZE = getSlotSize()
    SLOT_PADDING = getSlotPadding()
    INVENTORY_MARGIN = getInventoryMargin()
    
    for panelId, panel in pairs(panelSystem.panels) do
        if panel and panel.updateLayout then
            panel:updateLayout()
        elseif panel then
            -- Update slot sizes for basic panels
            panel.slotSize = constants.INVENTORY_SLOT_SIZE or math.floor(40 * constants.UI_SCALE)
            panel.slotPadding = constants.INVENTORY_SLOT_PADDING or math.floor(2 * constants.UI_SCALE)
        end
    end
end

-- Base panel class
local BasePanel = {}
BasePanel.__index = BasePanel

-- Update layout for scaling changes
function BasePanel:updateLayout()
    self.slotSize = constants.INVENTORY_SLOT_SIZE or math.floor(40 * constants.UI_SCALE)
    self.slotPadding = constants.INVENTORY_SLOT_PADDING or math.floor(2 * constants.UI_SCALE)
end

function BasePanel.new(id, x, y, rows, cols)
    local self = setmetatable({}, BasePanel)
    self.id = id
    self.x = x
    self.y = y
    self.rows = rows
    self.cols = cols
    self.items = {}
    self.visible = false
    self.slotSize = constants.INVENTORY_SLOT_SIZE or math.floor(40 * constants.UI_SCALE)
    self.slotPadding = constants.INVENTORY_SLOT_PADDING or math.floor(2 * constants.UI_SCALE)

    -- Initialize empty slots
    for i = 1, rows * cols do
        self.items[i] = nil
    end

    return self
end

-- Get slot rectangle for a given slot index
function BasePanel:getSlotRect(slotIndex)
    if not self.visible then return nil end

    local col = (slotIndex - 1) % self.cols
    local row = math.floor((slotIndex - 1) / self.cols)
    local slotX = self.x + col * (self.slotSize + self.slotPadding)
    local slotY = self.y + row * (self.slotSize + self.slotPadding)

    return slotX, slotY, self.slotSize, self.slotSize
end

-- Get slot index at screen coordinates
function BasePanel:slotAt(x, y)
    if not self.visible then return nil end

    for i = 1, self.rows * self.cols do
        local slotX, slotY, slotW, slotH = self:getSlotRect(i)
        if x >= slotX and x <= slotX + slotW and y >= slotY and y <= slotY + slotH then
            return i
        end
    end
    return nil
end

-- Check if an item can be placed in a specific slot
function BasePanel:canPlace(item, targetIndex, sourceIndex)
    if not targetIndex or targetIndex < 1 or targetIndex > self.rows * self.cols then
        return false, "Invalid slot"
    end

    if not item then
        return true, "Empty item can always be placed"
    end

    local targetItem = self.items[targetIndex]

    -- If target slot is empty, can always place
    if not targetItem then
        return true, "Slot is empty"
    end

    -- If same item and both are stackable, check if we can merge
    if targetItem.name == item.name and targetItem.stackable then
        local maxStack = targetItem.stackMax or 99
        local currentStack = targetItem.count or 1
        local newStack = currentStack + (item.count or 1)

        if newStack <= maxStack then
            return true, "Can merge stacks"
        else
            return false, "Stack would exceed maximum (" .. maxStack .. ")"
        end
    end

    -- Different items - can swap unless it's the same slot
    if sourceIndex and sourceIndex == targetIndex then
        return false, "Cannot place on same slot"
    end

    return true, "Can swap items"
end

-- Move or merge items between slots within the same panel
function BasePanel:moveOrMerge(fromIndex, toIndex, quantity)
    if not fromIndex or not toIndex or fromIndex == toIndex then
        return false, "Invalid move operation"
    end

    local sourceItem = self.items[fromIndex]
    if not sourceItem then
        return false, "No item to move"
    end

    -- If no quantity specified, move entire stack
    if not quantity then
        quantity = sourceItem.count or 1
    end

    -- Can't move more than available
    if quantity > (sourceItem.count or 1) then
        return false, "Not enough items"
    end

    local targetItem = self.items[toIndex]
    local canPlace, reason = self:canPlace(sourceItem, toIndex, fromIndex)

    if not canPlace then
        return false, reason
    end

    -- Handle stacking
    if targetItem and targetItem.name == sourceItem.name and sourceItem.stackable then
        -- Merge stacks
        local maxStack = targetItem.stackMax or 99
        local spaceAvailable = maxStack - (targetItem.count or 1)
        local amountToMove = math.min(quantity, spaceAvailable)

        targetItem.count = (targetItem.count or 1) + amountToMove

        -- Reduce source stack
        if quantity >= (sourceItem.count or 1) then
            -- Moved entire stack
            self.items[fromIndex] = nil
        else
            sourceItem.count = (sourceItem.count or 1) - amountToMove
        end

        return true, "Merged stacks"
    else
        -- Swap or place items
        if quantity >= (sourceItem.count or 1) then
            -- Moving entire stack
            self.items[toIndex] = sourceItem
            self.items[fromIndex] = targetItem  -- Could be nil
        else
            -- Splitting stack - create new item for target
            local newItem = {}
            for k, v in pairs(sourceItem) do
                newItem[k] = v
            end
            newItem.count = quantity
            self.items[toIndex] = newItem

            -- Reduce source stack
            sourceItem.count = (sourceItem.count or 1) - quantity
        end

        return true, "Moved items"
    end
end

-- Add item to panel
function BasePanel:addItem(item)
    -- Try to stack with existing items
    if item.stackable then
        for i = 1, self.rows * self.cols do
            if self.items[i] and self.items[i].name == item.name then
                self.items[i].count = (self.items[i].count or 1) + (item.count or 1)
                return true -- Item stacked
            end
        end
    end

    -- Find first empty slot
    for i = 1, self.rows * self.cols do
        if not self.items[i] then
            self.items[i] = item
            if not self.items[i].count then self.items[i].count = 1 end
            return true -- Item added successfully
        end
    end
    return false -- Panel full
end

-- Register a panel with the system
function panelSystem.register(panelId, panel)
    panelSystem.panels[panelId] = panel
end

-- Get panel by ID
function panelSystem.getPanel(panelId)
    return panelSystem.panels[panelId]
end

-- Equipment Panel class
local EquipmentPanel = setmetatable({}, BasePanel)
EquipmentPanel.__index = EquipmentPanel

function EquipmentPanel.new(x, y)
    local self = BasePanel.new("equipment", x, y, 4, 2)  -- 4 rows, 2 cols for equipment slots
    setmetatable(self, EquipmentPanel)

    -- Equipment slot types
    self.slotTypes = {
        [1] = "helmet",
        [2] = "armor",
        [3] = "weapon",
        [4] = "shield",
        [5] = "boots",
        [6] = "accessory",
        [7] = "ring",
        [8] = "amulet"
    }
    
    -- Store relative position for scaling
    self.relativeX = x
    self.relativeY = y

    return self
end

-- Override updateLayout to maintain relative position
function EquipmentPanel:updateLayout()
    BasePanel.updateLayout(self)
    self.x = math.floor(self.relativeX * constants.UI_SCALE)
    self.y = math.floor(self.relativeY * constants.UI_SCALE)
end

-- Override canPlace to check equipment type compatibility
function EquipmentPanel:canPlace(item, targetIndex, sourceIndex)
    if not targetIndex or targetIndex < 1 or targetIndex > 8 then
        return false, "Invalid equipment slot"
    end

    if not item then
        return true, "Empty item can always be placed"
    end

    local slotType = self.slotTypes[targetIndex]
    local itemType = item.type

    -- Check if item type matches slot type
    if itemType ~= slotType then
        return false, "Item type '" .. (itemType or "unknown") .. "' doesn't fit in " .. slotType .. " slot"
    end

    -- Check if slot is already occupied
    local targetItem = self.items[targetIndex]
    if targetItem then
        return false, "Equipment slot is already occupied"
    end

    return true, "Can equip item"
end

-- Draw equipment panel
function EquipmentPanel:draw()
    if not self.visible then return end

    local colors = (ui and ui.uiState and ui.uiState.theme and ui.uiState.theme.colors) or {
        background = {0.1, 0.1, 0.1, 0.8},
        border = {0.4, 0.3, 0.2, 1.0},
        panel = {0.12, 0.12, 0.18, 0.9},
        accent = {0.6, 0.4, 0.2, 1.0},
        text = {0.9, 0.85, 0.8, 1.0}
    }

    -- Get drag state safely
    local currentDragState = inventory.getDragStateForPanel()

    -- Calculate panel dimensions
    local panelWidth = (self.cols * self.slotSize) + ((self.cols - 1) * self.slotPadding) + (self.slotSize)  -- Extra space for labels
    local panelHeight = (self.rows * self.slotSize) + ((self.rows - 1) * self.slotPadding) + 40  -- Extra space for title

    -- Draw panel background
    love.graphics.setColor(colors.background)
    ui.drawRoundedRect(self.x - 10, self.y - 30, panelWidth, panelHeight, 8)

    -- Draw panel border
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    ui.drawRoundedRectOutline(self.x - 10, self.y - 30, panelWidth, panelHeight, 8)
    love.graphics.setLineWidth(1)

    -- Draw title
    love.graphics.setColor(colors.text)
    love.graphics.printf("EQUIPMENT", self.x - 10, self.y - 25, panelWidth, "center")

    -- Draw equipment slots
    for row = 1, self.rows do
        for col = 1, self.cols do
            local slotIndex = (row - 1) * self.cols + col
            local slotX = self.x + (col - 1) * (self.slotSize + self.slotPadding)
            local slotY = self.y + (row - 1) * (self.slotSize + self.slotPadding)

            -- Draw slot background
            local slotColor = colors.panel
            if currentDragState and currentDragState.targetPanel == "equipment" and currentDragState.targetIndex == slotIndex then
                if currentDragState.valid then
                    slotColor = {0, 0.8, 0, 0.7}
                else
                    slotColor = {0.8, 0, 0, 0.7}
                end
            end

            love.graphics.setColor(slotColor)
            ui.drawRoundedRect(slotX, slotY, self.slotSize, self.slotSize, 3)

            -- Draw slot border
            love.graphics.setColor(colors.border)
            love.graphics.setLineWidth(1)
            ui.drawRoundedRectOutline(slotX, slotY, self.slotSize, self.slotSize, 3)

            -- Draw equipment type label
            if self.slotTypes[slotIndex] then
                love.graphics.setColor(colors.text)
                local label = self.slotTypes[slotIndex]:upper()
                love.graphics.printf(label, slotX, slotY + self.slotSize + 2, self.slotSize, "center")
            end

            -- Draw item if present
            local item = self.items[slotIndex]
            if item then
                -- Draw item icon
                if item.icon then
                    love.graphics.setColor(1, 1, 1, 1)
                    local iconScale = (self.slotSize - 4) / 32
                    love.graphics.draw(item.icon, slotX + 2, slotY + 2, 0, iconScale, iconScale)
                else
                    local itemColor = item.color or {0.8, 0.8, 0.8, 1}
                    love.graphics.setColor(itemColor)
                    ui.drawRoundedRect(slotX + 2, slotY + 2, self.slotSize - 4, self.slotSize - 4, 2)
                end
            end
        end
    end
end

-- Hotbar Panel class
local HotbarPanel = setmetatable({}, BasePanel)
HotbarPanel.__index = HotbarPanel

function HotbarPanel.new(x, y)
    local self = BasePanel.new("hotbar", x, y, 1, 10)  -- 1 row, 10 cols for quick access
    setmetatable(self, HotbarPanel)

    self.visible = true  -- Hotbar is always visible
    
    -- Store relative position calculations
    self.centerScreenX = true  -- Flag to indicate this should be centered horizontally
    self.relativeY = y

    return self
end

-- Override updateLayout to center hotbar and maintain bottom position
function HotbarPanel:updateLayout()
    BasePanel.updateLayout(self)
    -- Center horizontally and maintain relative bottom position
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local hotbarWidth = 10 * (self.slotSize + self.slotPadding) - self.slotPadding
    self.x = (screenWidth - hotbarWidth) / 2
    self.y = screenHeight - constants.HOTBAR_BOTTOM_MARGIN
end

-- Override canPlace to allow any item in hotbar
function HotbarPanel:canPlace(item, targetIndex, sourceIndex)
    if not targetIndex or targetIndex < 1 or targetIndex > 10 then
        return false, "Invalid hotbar slot"
    end

    return true, "Can place in hotbar"
end

-- Draw hotbar (simplified version)
function HotbarPanel:draw()
    if not self.visible then return end

    local colors = (ui and ui.uiState and ui.uiState.theme and ui.uiState.theme.colors) or {
        background = {0.1, 0.1, 0.1, 0.8},
        border = {0.4, 0.3, 0.2, 1.0},
        panel = {0.12, 0.12, 0.18, 0.9},
        accent = {0.6, 0.4, 0.2, 1.0},
        text = {0.9, 0.85, 0.8, 1.0}
    }

    -- Get drag state safely
    local currentDragState = inventory.getDragStateForPanel()

    -- Draw hotbar background
    love.graphics.setColor(colors.background)
    ui.drawRoundedRect(self.x - 5, self.y - 5, self.cols * (self.slotSize + self.slotPadding) + 10, self.slotSize + 10, 4)

    -- Draw hotbar slots
    for i = 1, self.cols do
        local slotX, slotY, slotW, slotH = self:getSlotRect(i)
        local item = self.items[i]

        -- Draw slot background
        local slotColor = colors.panel
        if currentDragState and currentDragState.targetPanel == "hotbar" and currentDragState.targetIndex == i then
            if currentDragState.valid then
                slotColor = {0, 0.8, 0, 0.7}
            else
                slotColor = {0.8, 0, 0, 0.7}
            end
        end

        love.graphics.setColor(slotColor)
        ui.drawRoundedRect(slotX, slotY, slotW, slotH, 3)

        -- Draw slot border
        love.graphics.setColor(colors.border)
        love.graphics.setLineWidth(1)
        ui.drawRoundedRectOutline(slotX, slotY, slotW, slotH, 3)
        
        -- Draw selection highlight if this slot is selected
        local game = require("src.game")
        local gs = game.getState and game.getState() or nil
        if gs and gs.player and gs.player.selectedHotbarSlot == i then
            love.graphics.setColor(1, 1, 1, 0.8)  -- White highlight
            love.graphics.setLineWidth(3)
            ui.drawRoundedRectOutline(slotX - 1, slotY - 1, slotW + 2, slotH + 2, 4)
            love.graphics.setLineWidth(1)
        end

        -- Draw item if present
        if item then
            -- Draw item icon
            if item.icon then
                -- Draw the actual icon image
                love.graphics.setColor(1, 1, 1, 1)
                local iconScale = (slotW - 4) / 32  -- Scale to fit slot (32x32 icons)
                love.graphics.draw(item.icon, slotX + 2, slotY + 2, 0, iconScale, iconScale)
            else
                -- Fallback: draw colored rectangle if no icon
                local itemColor = item.color or {0.8, 0.8, 0.8, 1}
                love.graphics.setColor(itemColor)
                ui.drawRoundedRect(slotX + 2, slotY + 2, slotW - 4, slotH - 4, 2)
            end

            -- Draw item count if stackable
            if item.count and item.count > 1 then
                love.graphics.setColor(colors.text)
                local countText = tostring(item.count)
                local font = love.graphics.getFont()
                local textWidth = font:getWidth(countText)
                love.graphics.print(countText, slotX + slotW - textWidth - 1, slotY + slotH - 15)
            end
        end

        -- Draw hotbar number
        love.graphics.setColor(colors.text)
        local numberText = tostring(i)
        if i == 10 then numberText = "0" end
        love.graphics.print(numberText, slotX + 2, slotY + 2)
    end
end

-- Handle drag between panels
function panelSystem.moveBetweenPanels(fromPanel, fromIndex, toPanel, toIndex, quantity)
    local sourceItem = fromPanel.items[fromIndex]
    if not sourceItem then
        return false, "No item to move"
    end

    -- If no quantity specified, move entire stack
    if not quantity then
        quantity = sourceItem.count or 1
    end

    -- Can't move more than available
    if quantity > (sourceItem.count or 1) then
        return false, "Not enough items"
    end

    local targetItem = toPanel.items[toIndex]
    local canPlace, reason = toPanel:canPlace(sourceItem, toIndex, nil)

    if not canPlace then
        return false, reason
    end

    -- Handle stacking
    if targetItem and targetItem.name == sourceItem.name and sourceItem.stackable then
        -- Merge stacks
        local maxStack = targetItem.stackMax or 99
        local spaceAvailable = maxStack - (targetItem.count or 1)
        local amountToMove = math.min(quantity, spaceAvailable)

        targetItem.count = (targetItem.count or 1) + amountToMove

        -- Reduce source stack
        if quantity >= (sourceItem.count or 1) then
            -- Moved entire stack
            fromPanel.items[fromIndex] = nil
        else
            sourceItem.count = (sourceItem.count or 1) - amountToMove
        end

        return true, "Merged stacks"
    else
        -- Swap or place items
        if quantity >= (sourceItem.count or 1) then
            -- Moving entire stack
            toPanel.items[toIndex] = sourceItem
            fromPanel.items[fromIndex] = targetItem  -- Could be nil
        else
            -- Splitting stack - create new item for target
            local newItem = {}
            for k, v in pairs(sourceItem) do
                newItem[k] = v
            end
            newItem.count = quantity
            toPanel.items[toIndex] = newItem

            -- Reduce source stack
            sourceItem.count = (sourceItem.count or 1) - quantity
        end

        return true, "Moved items"
    end
end

-- Drag state (enhanced for multi-panel)
local dragState = {
    active = false,
    item = nil,
    quantity = nil,
    fromPanel = nil,
    fromIndex = nil,
    offsetX = 0,
    offsetY = 0,
    valid = false,
    targetPanel = nil,
    targetIndex = nil,
    overPanel = false
}

-- Hover state for tooltips
local hoverState = {
    slotIndex = nil,
    time = 0,
    tooltipDelay = 0.15  -- seconds before showing tooltip
}

-- Create a new inventory
function inventory.create()
    -- Create inventory as a BasePanel to work with the panel system
    local inv = BasePanel.new("inventory", 50, 50, SLOT_ROWS, SLOT_COLS)
    inv.visible = false
    inv.hoveredSlot = nil
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

-- Override getSlotRect for inventory panel to use correct dynamic position
function inventory.getSlotRect(inv, i)
    if not inv.visible then return nil end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Calculate inventory dimensions
    local inventoryWidth = (SLOT_COLS * SLOT_SIZE) + ((SLOT_COLS - 1) * SLOT_PADDING) + (INVENTORY_MARGIN * 2)
    local inventoryHeight = (SLOT_ROWS * SLOT_SIZE) + ((SLOT_ROWS - 1) * SLOT_PADDING) + (INVENTORY_MARGIN * 2) + 30

    -- Position in bottom right
    local inventoryX = screenWidth - inventoryWidth - 10
    local inventoryY = screenHeight - inventoryHeight - 10

    -- Calculate slot position
    local col = (i - 1) % SLOT_COLS
    local row = math.floor((i - 1) / SLOT_COLS)
    local slotX = inventoryX + INVENTORY_MARGIN + (col * (SLOT_SIZE + SLOT_PADDING))
    local slotY = inventoryY + INVENTORY_MARGIN + 25 + (row * (SLOT_SIZE + SLOT_PADDING))  -- Account for title

    return slotX, slotY, SLOT_SIZE, SLOT_SIZE
end

-- Override slotAt for inventory panel to use correct position
function inventory.slotAt(inv, x, y)
    if not inv.visible then return nil end

    for i = 1, TOTAL_SLOTS do
        local slotX, slotY, slotW, slotH = inventory.getSlotRect(inv, i)
        if x >= slotX and x <= slotX + slotW and y >= slotY and y <= slotY + slotH then
            return i
        end
    end
    return nil
end

-- Check if an item can be placed in a specific slot
function inventory.canPlace(inv, item, targetIndex, sourceIndex)
    if not targetIndex or targetIndex < 1 or targetIndex > TOTAL_SLOTS then
        return false, "Invalid slot"
    end

    if not item then
        return true, "Empty item can always be placed"
    end

    local targetItem = inv.items[targetIndex]

    -- If target slot is empty, can always place
    if not targetItem then
        return true, "Slot is empty"
    end

    -- If same item and both are stackable, check if we can merge
    if targetItem.name == item.name and targetItem.stackable then
        local maxStack = targetItem.stackMax or 99
        local currentStack = targetItem.count or 1
        local newStack = currentStack + (item.count or 1)

        if newStack <= maxStack then
            return true, "Can merge stacks"
        else
            return false, "Stack would exceed maximum (" .. maxStack .. ")"
        end
    end

    -- Different items - can swap unless it's the same slot
    if sourceIndex and sourceIndex == targetIndex then
        return false, "Cannot place on same slot"
    end

    return true, "Can swap items"
end

-- Move or merge items between slots
function inventory.moveOrMerge(inv, fromIndex, toIndex, quantity)
    if not fromIndex or not toIndex or fromIndex == toIndex then
        return false, "Invalid move operation"
    end

    local sourceItem = inv.items[fromIndex]
    if not sourceItem then
        return false, "No item to move"
    end

    -- If no quantity specified, move entire stack
    if not quantity then
        quantity = sourceItem.count or 1
    end

    -- Can't move more than available
    if quantity > (sourceItem.count or 1) then
        return false, "Not enough items"
    end

    local targetItem = inv.items[toIndex]
    local canPlace, reason = inventory.canPlace(inv, sourceItem, toIndex, fromIndex)

    if not canPlace then
        return false, reason
    end

    -- Handle stacking
    if targetItem and targetItem.name == sourceItem.name and sourceItem.stackable then
        -- Merge stacks
        local maxStack = targetItem.stackMax or 99
        local spaceAvailable = maxStack - (targetItem.count or 1)
        local amountToMove = math.min(quantity, spaceAvailable)

        targetItem.count = (targetItem.count or 1) + amountToMove

        -- Reduce source stack
        if quantity >= (sourceItem.count or 1) then
            -- Moved entire stack
            inv.items[fromIndex] = nil
        else
            sourceItem.count = (sourceItem.count or 1) - amountToMove
        end

        return true, "Merged stacks"
    else
        -- Swap or place items
        if quantity >= (sourceItem.count or 1) then
            -- Moving entire stack
            inv.items[toIndex] = sourceItem
            inv.items[fromIndex] = targetItem  -- Could be nil
        else
            -- Splitting stack - create new item for target
            local newItem = {}
            for k, v in pairs(sourceItem) do
                newItem[k] = v
            end
            newItem.count = quantity
            inv.items[toIndex] = newItem

            -- Reduce source stack
            sourceItem.count = (sourceItem.count or 1) - quantity
        end

        return true, "Moved items"
    end
end

-- Get current drag state (for external access)
function inventory.getDragState()
    return dragState
end

-- Get drag state for panel rendering (safe access)
function inventory.getDragStateForPanel()
    return dragState.active and dragState or nil
end

-- Clear drag state
function inventory.clearDragState()
    dragState.active = false
    dragState.item = nil
    dragState.quantity = nil
    dragState.fromIndex = nil
    dragState.valid = false
    dragState.targetIndex = nil
    dragState.overPanel = false
end

-- Start dragging an item (enhanced for multi-panel)
function inventory.startDrag(panel, slotIndex, mouseX, mouseY, ctrlPressed, panelId)
    local item = panel.items[slotIndex]
    if not item then return false end

    -- Get slot rectangle using appropriate method
    local slotX, slotY, slotW, slotH
    if panelId == "inventory" then
        slotX, slotY, slotW, slotH = inventory.getSlotRect(panel, slotIndex)
    elseif panel.getSlotRect then
        slotX, slotY, slotW, slotH = panel:getSlotRect(slotIndex)
    else
        return false -- Invalid panel
    end

    dragState.active = true
    dragState.item = item
    dragState.fromPanel = panelId or "inventory"
    dragState.fromIndex = slotIndex
    dragState.offsetX = mouseX - slotX - slotW/2
    dragState.offsetY = mouseY - slotY - slotH/2
    dragState.overPanel = false

    -- Handle splitting
    if ctrlPressed and item.count and item.count > 1 then
        dragState.quantity = math.ceil(item.count / 2)
    else
        dragState.quantity = item.count or 1
    end

    return true
end

-- Update drag target (enhanced for multi-panel)
function inventory.updateDragTarget(mouseX, mouseY)
    if not dragState.active then return end

    -- Reset drag state
    dragState.valid = false
    dragState.targetPanel = nil
    dragState.targetIndex = nil
    dragState.overPanel = false

    -- Check if mouse is over any inventory panel first
    local isOverAnyPanel = inventory.isMouseOverInventory(mouseX, mouseY)
    dragState.overPanel = isOverAnyPanel

    -- Check all registered panels for valid drop targets
    for panelId, panel in pairs(panelSystem.panels) do
        if panel.visible then
            local targetIndex

            -- Use appropriate slotAt method based on panel type
            if panelId == "inventory" then
                targetIndex = inventory.slotAt(panel, mouseX, mouseY)
            elseif panel.slotAt then
                targetIndex = panel:slotAt(mouseX, mouseY)
            end

            if targetIndex then
                -- Create a temporary item for validation
                local tempItem = {
                    name = dragState.item.name,
                    count = dragState.quantity,
                    stackable = dragState.item.stackable,
                    stackMax = dragState.item.stackMax,
                    type = dragState.item.type
                }

                -- Use appropriate canPlace method
                if panelId == "inventory" then
                    dragState.valid, _ = inventory.canPlace(panel, tempItem, targetIndex, nil)
                elseif panel.canPlace then
                    dragState.valid, _ = panel:canPlace(tempItem, targetIndex, nil)
                end

                dragState.targetPanel = panelId
                dragState.targetIndex = targetIndex
                dragState.overPanel = true
                return
            end
        end
    end
end

-- Finish drag operation (enhanced for multi-panel)
function inventory.finishDrag(mouseX, mouseY)
    if not dragState.active then return end

    if dragState.targetIndex and dragState.valid then
        local fromPanel = panelSystem.getPanel(dragState.fromPanel)
        local toPanel = panelSystem.getPanel(dragState.targetPanel)

        if fromPanel and toPanel then
            local success, message
            if dragState.fromPanel == dragState.targetPanel then
                -- Same panel movement
                success, message = fromPanel:moveOrMerge(dragState.fromIndex, dragState.targetIndex, dragState.quantity)
            else
                -- Cross-panel movement
                success, message = panelSystem.moveBetweenPanels(fromPanel, dragState.fromIndex, toPanel, dragState.targetIndex, dragState.quantity)
            end

            if success then
                ui.addChatMessage("Item moved: " .. message, {0.8, 0.8, 1})
            else
                ui.addChatMessage("Cannot move item: " .. message, {1, 0.5, 0.5})
            end
        end
    elseif dragState.overPanel then
        -- Mouse is over a panel but not on a valid slot - cancel drag, don't drop item
        ui.addChatMessage("Drag cancelled - item returned to original position", {0.8, 0.8, 1})
    else
        -- Mouse is not over any panel - drop the item at player's feet
        local fromPanel = panelSystem.getPanel(dragState.fromPanel)
        if fromPanel and dragState.fromIndex then
            -- Use the helper function to drop at player's feet
            inventory.dropItemAtPlayer(fromPanel, dragState.fromIndex, { count = dragState.quantity })
        end
    end

    inventory.clearDragState()
end

-- Draw inventory UI with enhanced features
function inventory.draw(inv)
    if not inv.visible then return end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Safety check for screen dimensions
    if not screenWidth or not screenHeight or screenWidth <= 0 or screenHeight <= 0 then
        return
    end

    -- Safety check for constants
    if not SLOT_SIZE or not SLOT_COLS or not SLOT_ROWS or not SLOT_PADDING or not INVENTORY_MARGIN then
        return
    end

    -- Calculate inventory dimensions
    local inventoryWidth = (SLOT_COLS * SLOT_SIZE) + ((SLOT_COLS - 1) * SLOT_PADDING) + (INVENTORY_MARGIN * 2)
    local inventoryHeight = (SLOT_ROWS * SLOT_SIZE) + ((SLOT_ROWS - 1) * SLOT_PADDING) + (INVENTORY_MARGIN * 2) + 30

    -- Position in bottom right
    local inventoryX = screenWidth - inventoryWidth - 10
    local inventoryY = screenHeight - inventoryHeight - 10

    -- Get UI theme colors
    local colors = (ui and ui.uiState and ui.uiState.theme and ui.uiState.theme.colors) or {
        background = {0.1, 0.1, 0.1, 0.8},
        border = {0.4, 0.3, 0.2, 1.0},
        text = {0.9, 0.85, 0.8, 1.0},
        panel = {0.12, 0.12, 0.18, 0.9},
        accent = {0.6, 0.4, 0.2, 1.0}
    }

    -- Draw inventory background with rounded corners
    love.graphics.setColor(colors.background)
    ui.drawRoundedRect(inventoryX, inventoryY, inventoryWidth, inventoryHeight, 8)

    -- Draw inventory border
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    ui.drawRoundedRectOutline(inventoryX, inventoryY, inventoryWidth, inventoryHeight, 8)
    love.graphics.setLineWidth(1)

    -- Draw title
    love.graphics.setColor(colors.text)
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
            local isHovered = false
            if mouseX and mouseY and currentSlotX and currentSlotY and SLOT_SIZE then
                isHovered = mouseX >= currentSlotX and mouseX <= currentSlotX + SLOT_SIZE and
                           mouseY >= currentSlotY and mouseY <= currentSlotY + SLOT_SIZE
            end

            -- Determine slot color based on state
            local slotColor = colors.panel
            if isHovered then
                slotColor = colors.accent
                hoverState.slotIndex = slotIndex
            elseif dragState.targetIndex == slotIndex and dragState.targetPanel == "inventory" then
                -- Target highlight for drag operation (only for inventory panel)
                if dragState.valid then
                    slotColor = {0, 0.8, 0, 0.7}  -- Green for valid
                else
                    slotColor = {0.8, 0, 0, 0.7}  -- Red for invalid
                end
            end

            -- Draw slot background with rounded corners
            love.graphics.setColor(slotColor)
            ui.drawRoundedRect(currentSlotX, currentSlotY, SLOT_SIZE, SLOT_SIZE, 4)

            -- Draw slot border
            love.graphics.setColor(colors.border)
            love.graphics.setLineWidth(1)
            ui.drawRoundedRectOutline(currentSlotX, currentSlotY, SLOT_SIZE, SLOT_SIZE, 4)

            -- Draw item if present
            local item = inv.items[slotIndex]
            if item then
                -- Draw item icon
                if item.icon then
                    -- Draw the actual icon image
                    love.graphics.setColor(1, 1, 1, 1)
                    local iconScale = (SLOT_SIZE - 6) / 32  -- Scale to fit slot (32x32 icons)
                    love.graphics.draw(item.icon, currentSlotX + 3, currentSlotY + 3, 0, iconScale, iconScale)
                else
                    -- Fallback: draw colored rectangle if no icon
                    local itemColor = item.color or {0.8, 0.8, 0.8, 1}
                    love.graphics.setColor(itemColor)
                    ui.drawRoundedRect(currentSlotX + 3, currentSlotY + 3, SLOT_SIZE - 6, SLOT_SIZE - 6, 3)

                    -- Add slight inner shadow for depth
                    love.graphics.setColor(0, 0, 0, 0.3)
                    ui.drawRoundedRect(currentSlotX + 5, currentSlotY + 5, SLOT_SIZE - 10, SLOT_SIZE - 10, 2)
                end

                -- Draw item count if stackable
                if item.count and item.count > 1 then
                    love.graphics.setColor(colors.text)
                    local countText = tostring(item.count)
                    local countWidth = font:getWidth(countText)
                    local countHeight = font:getHeight()
                    love.graphics.print(countText, currentSlotX + SLOT_SIZE - countWidth - 2, currentSlotY + SLOT_SIZE - countHeight - 1)
                end
            end
        end
    end

    -- Reset hover state if mouse not over any slot
    local mouseX, mouseY = love.mouse.getPosition()
    local mouseOverInventory = false

    -- Safety check for mouse position and inventory bounds
    if mouseX and mouseY and inventoryX and inventoryY and inventoryWidth and inventoryHeight then
        mouseOverInventory = mouseX >= inventoryX and mouseX <= inventoryX + inventoryWidth and
                            mouseY >= inventoryY and mouseY <= inventoryY + inventoryHeight
    end

    if not mouseOverInventory then
        hoverState.slotIndex = nil
        hoverState.time = 0
    end
end

-- Update function for animations and hover timing
function inventory.update(dt)
    -- Update hover timer for tooltips
    if hoverState.slotIndex then
        hoverState.time = hoverState.time + dt
    else
        hoverState.time = 0
    end
end

-- Enhanced mouse handling
function inventory.onMousePressed(inv, x, y, button, mods)
    if not inv.visible then return false end

    local slotIndex = inventory.slotAt(inv, x, y)
    if not slotIndex then return false end

    local item = inv.items[slotIndex]
    local ctrlPressed = mods and (mods.lctrl or mods.rctrl)

    if button == 1 then -- Left click
        if item then
            -- Start drag operation
            inventory.startDrag(inv, slotIndex, x, y, ctrlPressed)
            return true
        end
    elseif button == 2 then -- Right click
        if item then
            -- Show context menu
            inventory.showContextMenu(inv, slotIndex, x, y)
            return true
        end
    end

    return false
end

function inventory.onMouseReleased(inv, x, y, button)
    if not inv.visible then return false end

    if button == 1 and dragState.active then
        -- Finish drag operation
        inventory.finishDrag(inv, x, y)
        return true
    end

    return false
end

function inventory.onMouseMoved(inv, x, y)
    if not inv.visible then return false end

    -- Update drag target if dragging
    if dragState.active then
        inventory.updateDragTarget(inv, x, y)
        return true
    end

    return false
end

-- Draw drag ghost (item being dragged under cursor)
function inventory.drawDragGhost()
    if not dragState or not dragState.active or not dragState.item then return end

    local mouseX, mouseY = love.mouse.getPosition()
    if not mouseX or not mouseY or not dragState.offsetX or not dragState.offsetY then return end

    local ghostX = mouseX - dragState.offsetX
    local ghostY = mouseY - dragState.offsetY

    -- Draw ghost item
    if dragState.item.icon then
        -- Draw the actual icon image with transparency
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.draw(dragState.item.icon, ghostX, ghostY, 0, SLOT_SIZE/32, SLOT_SIZE/32)
    else
        -- Fallback: draw colored rectangle if no icon
        local itemColor = dragState.item.color or {0.8, 0.8, 0.8, 0.8}
        love.graphics.setColor(itemColor[1], itemColor[2], itemColor[3], 0.7)
        ui.drawRoundedRect(ghostX, ghostY, SLOT_SIZE, SLOT_SIZE, 4)
    end

    -- Draw quantity badge if splitting
    if dragState.quantity and dragState.quantity ~= (dragState.item.count or 1) then
        love.graphics.setColor(0, 0, 0, 0.8)
        ui.drawRoundedRect(ghostX + SLOT_SIZE - 18, ghostY + SLOT_SIZE - 18, 16, 16, 2)

        love.graphics.setColor(1, 1, 1, 1)
        local quantityText = tostring(dragState.quantity)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(quantityText)
        local textHeight = font:getHeight()
        love.graphics.print(quantityText, ghostX + SLOT_SIZE - 9 - textWidth/2, ghostY + SLOT_SIZE - 9 - textHeight/2)
    end
end

-- Draw tooltip for hovered item
function inventory.drawTooltip(inv)
    if not hoverState or not hoverState.slotIndex or hoverState.time < hoverState.tooltipDelay then return end

    if not inv or not inv.items then return end

    local item = inv.items[hoverState.slotIndex]
    if not item then return end

    local mouseX, mouseY = love.mouse.getPosition()
    if not mouseX or not mouseY then return end
    local tooltipX = mouseX + 15
    local tooltipY = mouseY - 10

    -- Build tooltip content with color information
    local lines = {}
    
    -- Item name with rarity color
    local nameColor = {0.9, 0.85, 0.8, 1.0} -- Default white
    if item.rarity then
        if item.rarity == "common" then
            nameColor = {0.8, 0.8, 0.8, 1.0} -- Gray
        elseif item.rarity == "uncommon" then
            nameColor = {0.3, 0.8, 0.3, 1.0} -- Green
        elseif item.rarity == "rare" then
            nameColor = {0.3, 0.5, 1.0, 1.0} -- Blue
        elseif item.rarity == "epic" then
            nameColor = {0.6, 0.3, 1.0, 1.0} -- Purple
        elseif item.rarity == "legendary" then
            nameColor = {1.0, 0.6, 0.0, 1.0} -- Orange
        end
    end
    table.insert(lines, {text = item.name or "Unknown Item", color = nameColor})

    -- Description in light gray
    if item.description then
        table.insert(lines, {text = item.description, color = {0.8, 0.8, 0.8, 1.0}})
    end

    -- Type in yellow
    if item.type then
        table.insert(lines, {text = "Type: " .. item.type, color = {1.0, 1.0, 0.6, 1.0}})
    end

    -- Rarity in its own color (same as name color)
    if item.rarity then
        table.insert(lines, {text = "Rarity: " .. item.rarity, color = nameColor})
    end

    -- Calculate tooltip dimensions
    local font = love.graphics.getFont()
    local maxWidth = 0
    local totalHeight = 0
    local lineHeight = font:getHeight() + 2

    for _, line in ipairs(lines) do
        local text = type(line) == "table" and line.text or line
        local width = font:getWidth(text)
        maxWidth = math.max(maxWidth, width)
        totalHeight = totalHeight + lineHeight
    end

    local tooltipWidth = maxWidth + 16
    local tooltipHeight = totalHeight + 8

    -- Keep tooltip on screen
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    if tooltipX + tooltipWidth > screenWidth then
        tooltipX = mouseX - tooltipWidth - 15
    end

    if tooltipY + tooltipHeight > screenHeight then
        tooltipY = mouseY - tooltipHeight - 10
    end

    if tooltipY < 0 then
        tooltipY = mouseY + 20
    end

    -- Get UI theme colors
    local colors = (ui and ui.uiState and ui.uiState.theme and ui.uiState.theme.colors) or {
        panel = {0.12, 0.12, 0.18, 0.95},
        border = {0.4, 0.3, 0.2, 1.0},
        text = {0.9, 0.85, 0.8, 1.0}
    }

    -- Draw tooltip background
    love.graphics.setColor(colors.panel)
    ui.drawRoundedRect(tooltipX, tooltipY, tooltipWidth, tooltipHeight, 6)

    -- Draw tooltip border
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    ui.drawRoundedRectOutline(tooltipX, tooltipY, tooltipWidth, tooltipHeight, 6)
    love.graphics.setLineWidth(1)

    -- Draw tooltip text with colors
    local yOffset = tooltipY + 6
    for _, line in ipairs(lines) do
        if type(line) == "table" then
            -- Colored text
            love.graphics.setColor(line.color)
            love.graphics.print(line.text, tooltipX + 8, yOffset)
        else
            -- Fallback for plain text (old format)
            love.graphics.setColor(colors.text)
            love.graphics.print(line, tooltipX + 8, yOffset)
        end
        yOffset = yOffset + lineHeight
    end
end



-- Drop item dialog for "Drop X" option
function inventory.dropItemDialog(inv, slotIndex)
    local item = inv.items[slotIndex]
    if not item then return end
    
    -- For now, drop half the stack (could be enhanced with text input dialog)
    local dropAmount = math.ceil((item.count or 1) / 2)
    inventory.dropItem(inv, slotIndex, dropAmount)
    ui.addChatMessage("Dropped " .. dropAmount .. " " .. (item.name or "items"), {0.8, 0.6, 0.4})
end

-- Start "Use with" interaction
function inventory.startUseWith(inv, slotIndex)
    local item = inv.items[slotIndex]
    if not item then return end
    
    -- Set cursor to use-with mode (for future implementation)
    ui.addChatMessage("Use " .. (item.name or "item") .. " with...", {0.6, 0.8, 1})
    -- Could add special cursor or highlight mode here
end

-- Enhanced drop item function with quantity support
function inventory.dropItem(inv, slotIndex, quantity)
    local item = inv.items[slotIndex]
    if not item then return false end
    
    local dropAmount = quantity or item.count or 1
    if dropAmount >= (item.count or 1) then
        -- Drop entire stack
        inv.items[slotIndex] = nil
        ui.addChatMessage("Dropped " .. (item.name or "item"), {0.8, 0.6, 0.4})
    else
        -- Drop partial stack
        item.count = item.count - dropAmount
        ui.addChatMessage("Dropped " .. dropAmount .. " " .. (item.name or "items"), {0.8, 0.6, 0.4})
    end
    return true
end

-- Split stack function
function inventory.splitStack(inv, slotIndex)
    local item = inv.items[slotIndex]
    if not item or not item.stackable or not item.count or item.count <= 1 then
        return false, "Cannot split this item"
    end

    -- Find empty slot for split
    local emptySlot = nil
    for i = 1, TOTAL_SLOTS do
        if not inv.items[i] then
            emptySlot = i
            break
        end
    end

    if not emptySlot then
        return false, "No empty slot available"
    end

    -- Split the stack
    local splitAmount = math.ceil(item.count / 2)
    local remainingAmount = item.count - splitAmount

    -- Create new item for split
    local newItem = {}
    for k, v in pairs(item) do
        newItem[k] = v
    end
    newItem.count = splitAmount

    -- Update original item
    if remainingAmount > 0 then
        item.count = remainingAmount
    else
        inv.items[slotIndex] = nil
    end

    -- Place split in empty slot
    inv.items[emptySlot] = newItem

    ui.addChatMessage("Split stack: " .. (item.name or "Unknown") .. " (" .. splitAmount .. ")", {0.8, 0.8, 1})
    return true
end

-- Drop item function
function inventory.dropItem(inv, slotIndex)
    local item = inv.items[slotIndex]
    if not item then return false end

    -- Add to world ground items (would need world integration)
    ui.addChatMessage("Dropped: " .. (item.name or "Unknown Item"), {1, 0.8, 0.5})

    -- Remove from inventory
    inv.items[slotIndex] = nil
    return true
end

-- Destroy item function (with confirmation)
function inventory.destroyItem(inv, slotIndex)
    local item = inv.items[slotIndex]
    if not item then return false end

    -- Show confirmation dialog
    ui.showConfirmDialog(
        "Destroy Item",
        "Are you sure you want to destroy '" .. (item.name or "Unknown Item") .. "'? This action cannot be undone.",
        function()
            -- Confirmed - destroy the item
            ui.addChatMessage("Destroyed: " .. (item.name or "Unknown Item"), {1, 0.5, 0.5})
            inv.items[slotIndex] = nil
        end,
        function()
            -- Cancelled - do nothing
            ui.addChatMessage("Destroy cancelled", {0.8, 0.8, 1})
        end
    )
    return true
end

-- Handle keyboard shortcuts for inventory
function inventory.handleKeyPress(inv, key, gameState)
    if not inv.visible then return false end

    -- Get current hovered slot
    local slotIndex = hoverState.slotIndex
    if not slotIndex then return false end

    local item = inv.items[slotIndex]
    if not item then return false end

    if key == "e" then
        -- Use/Equip item
        if item.onUse then
            item.onUse(gameState.player, item)
            return true
        elseif item.onEquip then
            item.onEquip(gameState.player, slotIndex)
            return true
        end
    elseif key == "r" then
        -- Split stack
        if item.stackable and item.count and item.count > 1 then
            inventory.splitStack(inv, slotIndex)
            return true
        end
    elseif key == "delete" then
        -- Destroy item
        inventory.destroyItem(inv, slotIndex)
        return true
    end

    return false
end

-- Show context menu for inventory slot
function inventory.showContextMenu(inv, slotIndex, x, y)
    local item = inv.items[slotIndex]
    if not item then return end

    local context_menu = require("src.context_menu")
    local options = {}

    -- Use item option
    if item.onUse then
        table.insert(options, {
            text = "Use",
            action = function()
                local game = _G.game or require("game")
                local gs = game.getState()
                if gs and gs.player then
                    item.onUse(gs.player, item)
                end
            end
        })
    end

    -- Equip item option (for equipment)
    if item.type and (item.type == "weapon" or item.type == "armor" or item.type == "shield" or item.type == "helmet" or item.type == "boots") then
        table.insert(options, {
            text = "Equip",
            action = function()
                local game = _G.game or require("game")
                local gs = game.getState()
                if gs and gs.player and item.onEquip then
                    item.onEquip(gs.player, slotIndex)
                    ui.addChatMessage("Equipped " .. (item.name or "item"), {0.6, 0.8, 1})
                end
            end
        })
    end

    -- Drop item option
    table.insert(options, {
        text = "Drop",
        action = function()
            -- For now, drop the entire stack. Could be enhanced later with amount prompt
            inventory.dropItemAtPlayer(inv, slotIndex)
        end
    })

    -- Split stack option (for stackable items)
    if item.stackable and item.count and item.count > 1 then
        table.insert(options, {
            text = "Split Stack",
            action = function()
                inventory.splitStack(inv, slotIndex)
            end
        })
    end

    -- Destroy item option (dangerous action)
    table.insert(options, {
        text = "Destroy",
        action = function()
            inventory.destroyItem(inv, slotIndex)
        end
    })

    -- Create and show the context menu
    local menu = context_menu.create(x, y, options)
    -- Store menu reference for drawing
    ui.showContextMenu(menu)
end

-- Drop item at player's feet helper function
function inventory.dropItemAtPlayer(inv, slotIndex, opts)
    local item = inv.items[slotIndex]
    if not item then return false end

    opts = opts or {}
    local countToDrop = opts.count or (item.count or 1)

    -- Validate drop amount
    if countToDrop <= 0 or countToDrop > (item.count or 1) then
        return false
    end

    -- Get player position from game state
    local game = _G.game or require("game")
    local gs = game.getState and game.getState() or nil
    if not gs or not gs.player then return false end

    -- Get world module for adding ground items
    local world = _G.world or require("world")
    if not world or not world.addGroundItem then return false end

    -- Get ground items table from game state
    local groundItems = gs.groundItems
    if not groundItems then return false end

    local droppedItem
    if countToDrop >= (item.count or 1) then
        -- Drop entire stack
        droppedItem = item
        inv.items[slotIndex] = nil
    else
        -- Drop partial stack - create new item instance
        droppedItem = {}
        for k, v in pairs(item) do
            droppedItem[k] = v
        end
        droppedItem.count = countToDrop
        item.count = item.count - countToDrop
    end

    -- Calculate drop position at player's feet (not center)
    -- Player feet are approximately 14 pixels below the center position
    local feetOffsetY = 14
    local playerX, playerY = gs.player.x, gs.player.y
    local dropX = playerX
    local dropY = playerY + feetOffsetY

    -- Add minor jitter so multiple drops don't perfectly overlap
    local jx = love.math.random(-8, 8)
    local jy = love.math.random(-4, 4)

    -- Add item to ground at player's feet (temporary item)
    world.addGroundItem(groundItems, droppedItem, dropX + jx, dropY + jy, false)

    -- Add chat message
    local itemName = droppedItem.name or "item"
    local quantityText = (droppedItem.count and droppedItem.count > 1) and (" x" .. droppedItem.count) or ""
    ui.addChatMessage("Dropped " .. itemName .. quantityText, {0.8, 0.6, 0.4})

    return true
end

-- Legacy mouse handling (for backward compatibility)
function inventory.handleClick(inv, x, y, button)
    if not inv.visible then return end

    local mods = {
        lctrl = love.keyboard.isDown("lctrl"),
        rctrl = love.keyboard.isDown("rctrl"),
        lshift = love.keyboard.isDown("lshift"),
        rshift = love.keyboard.isDown("rshift")
    }

    inventory.onMousePressed(inv, x, y, button, mods)
end

-- Get inventory dimensions for positioning other UI elements
function inventory.getDimensions()
    local inventoryWidth = (SLOT_COLS * SLOT_SIZE) + ((SLOT_COLS - 1) * SLOT_PADDING) + (INVENTORY_MARGIN * 2)
    local inventoryHeight = (SLOT_ROWS * SLOT_SIZE) + ((SLOT_ROWS - 1) * SLOT_PADDING) + (INVENTORY_MARGIN * 2) + 30

    return inventoryWidth, inventoryHeight
end

-- Check if mouse is over any visible inventory panel
function inventory.isMouseOverInventory(mouseX, mouseY)
    -- Check all registered panels
    for panelId, panel in pairs(panelSystem.panels) do
        if panel and panel.visible then
            local panelX, panelY, panelWidth, panelHeight

            -- Calculate actual panel position based on panel type
            if panelId == "inventory" then
                -- Inventory panel is positioned dynamically in bottom-right
                local screenWidth = love.graphics.getWidth()
                local screenHeight = love.graphics.getHeight()
                local slotSize = constants.INVENTORY_SLOT_SIZE or math.floor(40 * constants.UI_SCALE)
                local slotPadding = constants.INVENTORY_SLOT_PADDING or math.floor(2 * constants.UI_SCALE)
                local inventoryMargin = constants.INVENTORY_MARGIN or math.floor(10 * constants.UI_SCALE)
                local inventoryWidth = (SLOT_COLS * slotSize) + ((SLOT_COLS - 1) * slotPadding) + (inventoryMargin * 2)
                local inventoryHeight = (SLOT_ROWS * slotSize) + ((SLOT_ROWS - 1) * slotPadding) + (inventoryMargin * 2) + 30
                panelX = screenWidth - inventoryWidth - 10
                panelY = screenHeight - inventoryHeight - 10
                panelWidth = inventoryWidth
                panelHeight = inventoryHeight
            elseif panelId == "equipment" then
                -- Equipment panel uses stored position with offset (matches draw function)
                panelX = (panel.x or 0) - 10
                panelY = (panel.y or 0) - 30
                local padding = panel.slotPadding or 5
                panelWidth = (panel.cols * panel.slotSize) + ((panel.cols - 1) * padding) + panel.slotSize  -- Extra space for labels
                panelHeight = (panel.rows * panel.slotSize) + ((panel.rows - 1) * padding) + 40  -- Extra space for title
            elseif panelId == "hotbar" then
                -- Hotbar panel uses stored position (calculated in game.lua)
                panelX = panel.x or 0
                panelY = panel.y or 0
                -- Use the same calculation as HotbarPanel:updateLayout
                panelWidth = panel.cols * (panel.slotSize + panel.slotPadding) - panel.slotPadding
                panelHeight = panel.rows * panel.slotSize + 10  -- Simplified height calculation
            else
                -- Default calculation for other panels
                panelX = panel.x or 0
                panelY = panel.y or 0
                if panel.cols and panel.rows and panel.slotSize then
                    local padding = panel.slotPadding or 5
                    panelWidth = panel.cols * panel.slotSize + (panel.cols - 1) * padding + 20
                    panelHeight = panel.rows * panel.slotSize + (panel.rows - 1) * padding + 40
                else
                    panelWidth = 300
                    panelHeight = 200
                end
            end

            if mouseX >= panelX and mouseX <= panelX + panelWidth and
               mouseY >= panelY and mouseY <= panelY + panelHeight then
                return true, panelId, panel
            end
        end
    end
    return false
end

-- Export panel system and classes for external use
inventory.BasePanel = BasePanel
inventory.EquipmentPanel = EquipmentPanel
inventory.HotbarPanel = HotbarPanel
inventory.panelSystem = panelSystem

return inventory
