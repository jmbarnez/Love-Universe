-- Enhanced UI module for Love2D RPG
-- Uses SUIT library for better looking and more functional UI components

local ui = {}
local suit = require("lib.suit")
local lume = require("lib.lume")
local constants = require("src.constants")

-- UI state
local uiState = {
    windows = {},
    modals = {},
    tooltips = {},
    currentModal = nil,
    contextMenu = nil,
    theme = {},
    chatWindow = {
        messages = {},
        visible = true,
        maxMessages = 50,
        x = 0, -- Will be set dynamically
        y = 0, -- Will be set dynamically
        width = 0, -- Will be set dynamically
        height = 0 -- Will be set dynamically
    }
}

-- Scaled fonts (will be created in updateLayout)
local barFont, titleFont, dialogFont, chatFont, smallFont

-- Initialize UI system
function ui.init()
    -- Create custom theme
    ui.createTheme()

    -- Update UI positions based on current scaling
    ui.updateLayout()
end

-- Show context menu
function ui.showContextMenu(menu)
    uiState.contextMenu = menu
end

-- Hide context menu
function ui.hideContextMenu()
    uiState.contextMenu = nil
end

-- Update UI layout based on current screen size and scaling
function ui.updateLayout()
    -- Update chat window dimensions and position
    uiState.chatWindow.x = constants.INVENTORY_MARGIN or math.floor(10 * constants.UI_SCALE)
    uiState.chatWindow.width = constants.CHAT_WIDTH or math.floor(400 * constants.UI_SCALE)
    uiState.chatWindow.height = constants.CHAT_HEIGHT or math.floor(150 * constants.UI_SCALE)
    uiState.chatWindow.y = love.graphics.getHeight() - uiState.chatWindow.height - (constants.CHAT_BOTTOM_MARGIN or math.floor(10 * constants.UI_SCALE))

    -- Create scaled fonts based on current UI scale
    local scale = constants.UI_SCALE or 1.0
    barFont = love.graphics.newFont(math.max(8, math.floor(10 * scale)))
    titleFont = love.graphics.newFont(math.max(10, math.floor(14 * scale)))
    dialogFont = love.graphics.newFont(math.max(9, math.floor(12 * scale)))
    chatFont = love.graphics.newFont(math.max(8, math.floor(11 * scale)))
    smallFont = love.graphics.newFont(math.max(7, math.floor(9 * scale)))

    -- Update any other UI elements that need repositioning
    for _, window in pairs(uiState.windows) do
        if window.relativePosition then
            -- If window has relative positioning, update it
            window.x = window.relativePosition.x * love.graphics.getWidth()
            window.y = window.relativePosition.y * love.graphics.getHeight()
        end
    end

    -- Update inventory panels if they exist
    local inventory = require("src.inventory")
    if inventory and inventory.panelSystem and inventory.panelSystem.updateLayout then
        inventory.panelSystem.updateLayout()
    end
end

-- Create a custom theme for the RPG
function ui.createTheme()
    -- Dark fantasy theme colors
    local colors = {
        background = {0.08, 0.08, 0.12, 0.95},
        panel = {0.12, 0.12, 0.18, 0.9},
        border = {0.4, 0.3, 0.2, 1.0},
        text = {0.9, 0.85, 0.8, 1.0},
        accent = {0.6, 0.4, 0.2, 1.0},
        button = {0.25, 0.2, 0.15, 1.0},
        button_hover = {0.35, 0.25, 0.18, 1.0},
        button_active = {0.15, 0.12, 0.1, 1.0},
        health = {0.8, 0.2, 0.2, 1.0},
        mana = {0.2, 0.4, 0.8, 1.0},
        stamina = {0.2, 0.8, 0.2, 1.0}
    }

    uiState.theme.colors = colors

    -- Override SUIT theme
    suit.theme.Button = function(arg, opt, x, y, w, h)
        local color = colors.button
        if arg.hovered then
            color = colors.button_hover
        end
        if arg.down then
            color = colors.button_active
        end

        -- Draw button background with rounded corners effect
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", x, y, w, h)

        -- Draw border
        love.graphics.setColor(colors.border)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h)
        love.graphics.setLineWidth(1)

        -- Draw text
        love.graphics.setColor(colors.text)
        local font = love.graphics.getFont()
        love.graphics.printf(opt.text or "", x, y + (h - font:getHeight()) / 2, w, "center")
    end

    suit.theme.Input = function(arg, opt, x, y, w, h)
        local bg_color = colors.panel
        local border_color = colors.border

        if arg.focused then
            border_color = colors.accent
        end

        -- Background
        love.graphics.setColor(bg_color)
        love.graphics.rectangle("fill", x, y, w, h)

        -- Border
        love.graphics.setColor(border_color)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h)
        love.graphics.setLineWidth(1)

        -- Text
        love.graphics.setColor(colors.text)
        local font = love.graphics.getFont()
        local text = arg.text or ""
        if arg.focused then
            text = text .. "|"
        end
        love.graphics.printf(text, x + 8, y + (h - font:getHeight()) / 2, w - 16, "left")
    end
end

-- Get theme colors (safe getter for external access)
function ui.getThemeColors()
    if uiState.theme and uiState.theme.colors then
        return uiState.theme.colors
    else
        -- Fallback colors if theme not initialized
        return {
            background = {0.08, 0.08, 0.12, 0.95},
            panel = {0.12, 0.12, 0.18, 0.9},
            border = {0.4, 0.3, 0.2, 1.0},
            text = {0.9, 0.85, 0.8, 1.0},
            accent = {0.6, 0.4, 0.2, 1.0},
            button = {0.25, 0.2, 0.15, 1.0},
            button_hover = {0.35, 0.25, 0.18, 1.0},
            button_active = {0.15, 0.12, 0.1, 1.0},
            health = {0.8, 0.2, 0.2, 1.0},
            mana = {0.2, 0.4, 0.8, 1.0},
            stamina = {0.2, 0.8, 0.2, 1.0}
        }
    end
end

-- Create a window
function ui.createWindow(id, title, x, y, w, h, content_func)
    uiState.windows[id] = {
        id = id,
        title = title,
        x = x,
        y = y,
        w = w,
        h = h,
        visible = true,
        content_func = content_func,
        dragging = false,
        drag_offset_x = 0,
        drag_offset_y = 0
    }
    return uiState.windows[id]
end

-- Draw a window with title bar
function ui.drawWindow(window)
    if not window or not window.visible then return end
    
    local colors = uiState.theme.colors
    local x, y, w, h = window.x, window.y, window.w, window.h
    local titleHeight = 30
    
    -- Window background
    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Title bar
    love.graphics.setColor(colors.panel)
    love.graphics.rectangle("fill", x, y, w, titleHeight)
    
    -- Window border
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)
    
    -- Title bar separator
    love.graphics.line(x, y + titleHeight, x + w, y + titleHeight)
    
    -- Title text
    love.graphics.setColor(colors.text)
    love.graphics.setFont(titleFont)
    love.graphics.printf(window.title, x, y + (titleHeight - titleFont:getHeight()) / 2, w, "center")
    
    -- Draw window content
    if window.content_func then
        love.graphics.push()
        love.graphics.translate(x, y + titleHeight)
        window.content_func(window, w, h - titleHeight)
        love.graphics.pop()
    end
end

-- Unified bar renderer with visual enhancements
function ui.drawBar(x, y, w, h, current, max, label, barType, options)
    local colors = uiState.theme.colors
    options = options or {}

    -- Default settings based on bar type
    local barColors = {
        health = colors.health,
        mana = colors.mana,
        stamina = colors.stamina
    }

    local fillColor = barColors[barType] or colors.health
    local percentage = lume.clamp(current / max, 0, 1)
    local cornerRadius = options.cornerRadius or math.min(w, h) * 0.15
    local segments = options.segments or 10
    local animate = options.animate ~= false  -- Default to true

    -- For instant updates (like health bars), skip animation to show immediate changes
    local displayPercentage = percentage

    -- Animation state (smooth value lerping) - only for non-critical bars
    local anim = nil
    if animate and barType ~= "health" then
        local animKey = string.format("%s_%s", barType, label or "default")
        if not uiState.barAnimations then uiState.barAnimations = {} end
        if not uiState.barAnimations[animKey] then
            uiState.barAnimations[animKey] = { current = percentage, target = percentage, velocity = 0 }
        end

        anim = uiState.barAnimations[animKey]
        anim.target = percentage

        -- Smooth animation towards target
        if anim.current ~= anim.target then
            local dt = love.timer.getDelta()
            local diff = anim.target - anim.current
            anim.velocity = anim.velocity + diff * dt * 8  -- Spring-like acceleration
            anim.velocity = anim.velocity * 0.8  -- Damping
            anim.current = anim.current + anim.velocity * dt
            anim.current = lume.clamp(anim.current, 0, 1)
        else
            anim.current = anim.target
        end

        displayPercentage = anim.current
    end

    -- Draw background with rounded corners
    love.graphics.setColor(0.15, 0.15, 0.15, 0.9)
    ui.drawRoundedRect(x, y, w, h, cornerRadius)

    -- Draw inner shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    ui.drawRoundedRect(x + 2, y + 2, w - 4, h - 4, cornerRadius * 0.7)

    -- Draw fill with gradient
    ui.drawGradientBar(x + 2, y + 2, w - 4, h - 4, displayPercentage, fillColor, cornerRadius * 0.7)

    -- Draw segment ticks
    if segments > 1 then
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(1)
        local segmentWidth = (w - 4) / segments
        for i = 1, segments - 1 do
            local tickX = x + 2 + i * segmentWidth
            love.graphics.line(tickX, y + 4, tickX, y + h - 4)
        end
    end

    -- Draw damage/heal highlights (only for animated bars)
    if options.showHighlights and animate and barType ~= "health" and anim and anim.velocity ~= 0 then
        local highlightAlpha = math.abs(anim.velocity) * 2
        if anim.velocity > 0 then
            -- Healing highlight (green)
            love.graphics.setColor(0, 1, 0, highlightAlpha * 0.5)
        else
            -- Damage highlight (red)
            love.graphics.setColor(1, 0, 0, highlightAlpha * 0.5)
        end
        ui.drawRoundedRect(x + 2, y + 2, (w - 4) * displayPercentage, h - 4, cornerRadius * 0.7)
    end

    -- Draw border with rounded corners
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    ui.drawRoundedRectOutline(x, y, w, h, cornerRadius)

    -- Draw text
    if label then
        love.graphics.setColor(colors.text)
        love.graphics.setFont(barFont)
        local text = string.format("%s: %d/%d", label, current, max)
        local textHeight = barFont:getHeight()
        love.graphics.printf(text, x, y + (h - textHeight) / 2, w, "center")
    end
end

-- Helper function to draw rounded rectangles
function ui.drawRoundedRect(x, y, w, h, radius)
    local segments = 16
    love.graphics.rectangle("fill", x + radius, y, w - 2 * radius, h)
    love.graphics.rectangle("fill", x, y + radius, radius, h - 2 * radius)
    love.graphics.rectangle("fill", x + w - radius, y + radius, radius, h - 2 * radius)

    -- Draw corners
    love.graphics.arc("fill", x + radius, y + radius, radius, math.pi, math.pi * 1.5, segments)
    love.graphics.arc("fill", x + w - radius, y + radius, radius, math.pi * 1.5, math.pi * 2, segments)
    love.graphics.arc("fill", x + w - radius, y + h - radius, radius, 0, math.pi * 0.5, segments)
    love.graphics.arc("fill", x + radius, y + h - radius, radius, math.pi * 0.5, math.pi, segments)
end

-- Helper function to draw rounded rectangle outline
function ui.drawRoundedRectOutline(x, y, w, h, radius)
    local segments = 16

    -- Draw straight lines
    love.graphics.line(x + radius, y, x + w - radius, y)  -- Top
    love.graphics.line(x + radius, y + h, x + w - radius, y + h)  -- Bottom
    love.graphics.line(x, y + radius, x, y + h - radius)  -- Left
    love.graphics.line(x + w, y + radius, x + w, y + h - radius)  -- Right

    -- Draw corner arcs
    love.graphics.arc("line", x + radius, y + radius, radius, math.pi, math.pi * 1.5, segments)
    love.graphics.arc("line", x + w - radius, y + radius, radius, math.pi * 1.5, math.pi * 2, segments)
    love.graphics.arc("line", x + w - radius, y + h - radius, radius, 0, math.pi * 0.5, segments)
    love.graphics.arc("line", x + radius, y + h - radius, radius, math.pi * 0.5, math.pi, segments)
end

-- Helper function to draw gradient bar
function ui.drawGradientBar(x, y, w, h, percentage, color, radius)
    local fillWidth = w * percentage

    -- Create gradient effect
    for i = 0, fillWidth, 2 do
        local alpha = 0.8 + 0.2 * (i / fillWidth)  -- Gradient from darker to lighter
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        local sliceWidth = math.min(2, fillWidth - i)
        if sliceWidth > 0 then
            love.graphics.rectangle("fill", x + i, y, sliceWidth, h)
        end
    end

    -- Add gloss effect
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("fill", x, y, fillWidth * 0.8, h * 0.3)
end

-- Create a health bar (legacy wrapper)
function ui.drawHealthBar(x, y, w, h, current, max, label)
    ui.drawBar(x, y, w, h, current, max, label, "health", {showHighlights = true})
end

-- Create a mana bar (legacy wrapper)
function ui.drawManaBar(x, y, w, h, current, max, label)
    ui.drawBar(x, y, w, h, current, max, label, "mana", {showHighlights = true})
end

-- Create a stamina bar (legacy wrapper)
function ui.drawStaminaBar(x, y, w, h, current, max, label)
    ui.drawBar(x, y, w, h, current, max, label, "stamina", {showHighlights = true})
end

-- Create a tooltip
function ui.showTooltip(text, x, y)
    uiState.tooltip = {
        text = text,
        x = x,
        y = y,
        timer = 0.1 -- Small delay before showing
    }
end

-- Draw tooltip
function ui.drawTooltip()
    local tooltip = uiState.tooltip
    if not tooltip or tooltip.timer > 0 then return end
    
    local colors = uiState.theme.colors
    love.graphics.setFont(dialogFont)
    local text = tooltip.text
    local w = dialogFont:getWidth(text) + 16
    local h = dialogFont:getHeight() + 8

    -- Keep tooltip on screen
    local x = lume.clamp(tooltip.x, 0, love.graphics.getWidth() - w)
    local y = lume.clamp(tooltip.y - h - 10, 0, love.graphics.getHeight() - h)

    -- Background
    love.graphics.setColor(colors.panel)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Border
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", x, y, w, h)

    -- Text
    love.graphics.setColor(colors.text)
    love.graphics.print(text, x + 8, y + 4)
end

-- Create a better inventory grid
function ui.drawInventorySlot(x, y, w, h, item, index, selected)
    local colors = uiState.theme.colors
    
    -- Slot background
    local bg_color = selected and colors.accent or colors.panel
    love.graphics.setColor(bg_color)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Border
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Item representation (placeholder - you'd draw actual item sprites here)
    if item then
        -- Item icon placeholder
        love.graphics.setColor(colors.text)
        love.graphics.circle("fill", x + w/2, y + h/2, 8)
        
        -- Item count
        if item.count and item.count > 1 then
            love.graphics.setFont(smallFont)
            love.graphics.setColor(colors.text)
            love.graphics.printf(tostring(item.count), x, y + h - smallFont:getHeight() - 2, w, "right")
        end
    end
end

-- Create a confirmation modal
function ui.showConfirmDialog(title, message, onConfirm, onCancel)
    uiState.confirmDialog = {
        title = title,
        message = message,
        onConfirm = onConfirm or function() end,
        onCancel = onCancel or function() end,
        visible = true
    }
end

function ui.drawConfirmDialog()
    local dialog = uiState.confirmDialog
    if not dialog or not dialog.visible then return end

    local colors = uiState.theme.colors
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Dialog dimensions
    local dialogWidth = constants.DIALOG_WIDTH or math.floor(300 * constants.UI_SCALE)
    local dialogHeight = constants.DIALOG_HEIGHT or math.floor(120 * constants.UI_SCALE)
    local dialogX = (screenWidth - dialogWidth) / 2
    local dialogY = (screenHeight - dialogHeight) / 2

    -- Ensure dialog stays within screen bounds with proper margins
    local margin = constants.INVENTORY_MARGIN or math.floor(10 * constants.UI_SCALE)
    dialogX = math.max(margin, math.min(dialogX, screenWidth - dialogWidth - margin))
    dialogY = math.max(margin, math.min(dialogY, screenHeight - dialogHeight - margin))

    -- Draw dialog background
    love.graphics.setColor(colors.background)
    ui.drawRoundedRect(dialogX, dialogY, dialogWidth, dialogHeight, 8)

    -- Draw dialog border
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    ui.drawRoundedRectOutline(dialogX, dialogY, dialogWidth, dialogHeight, 8)
    love.graphics.setLineWidth(1)

    -- Draw title
    love.graphics.setColor(colors.text)
    love.graphics.setFont(dialogFont)
    local titleWidth = dialogFont:getWidth(dialog.title)
    love.graphics.print(dialog.title, dialogX + (dialogWidth - titleWidth) / 2, dialogY + 10)

    -- Draw message
    love.graphics.setColor(colors.text)
    love.graphics.setFont(dialogFont)
    local messageY = dialogY + 35
    local messageLines = {}
    local lineWidth = dialogWidth - 20
    local lineHeight = dialogFont:getHeight() + 2
    local words = {}
    for word in dialog.message:gmatch("%S+") do
        table.insert(words, word)
    end

    local currentLine = ""
    for _, word in ipairs(words) do
        local testLine = currentLine .. (currentLine == "" and "" or " ") .. word
        if dialogFont:getWidth(testLine) > lineWidth then
            table.insert(messageLines, currentLine)
            currentLine = word
        else
            currentLine = testLine
        end
    end
    if currentLine ~= "" then
        table.insert(messageLines, currentLine)
    end

    for i, line in ipairs(messageLines) do
        love.graphics.print(line, dialogX + 10, messageY + (i-1) * lineHeight)
    end

    -- Draw buttons
    local buttonY = dialogY + dialogHeight - 35
    local buttonWidth = 80
    local buttonHeight = 25
    local confirmX = dialogX + dialogWidth - buttonWidth - 10
    local cancelX = dialogX + 10

    suit.layout:reset(cancelX, buttonY, buttonWidth, buttonHeight)
    if suit.Button("Cancel", {id = "confirm_cancel"}, cancelX, buttonY, buttonWidth, buttonHeight).hit then
        dialog.onCancel()
        dialog.visible = false
    end

    suit.layout:reset(confirmX, buttonY, buttonWidth, buttonHeight)
    if suit.Button("Confirm", {id = "confirm_ok"}, confirmX, buttonY, buttonWidth, buttonHeight).hit then
        dialog.onConfirm()
        dialog.visible = false
    end
end

-- Create a settings panel
function ui.createSettingsPanel()
    local settings_content = function(window, w, h)
        local y_offset = 20
        local spacing = 40
        
        -- Volume slider (placeholder)
        suit.Label({}, {text = "Master Volume"}, 20, y_offset, w - 40, 20)
        y_offset = y_offset + spacing
        
        -- Graphics settings
        suit.Label({}, {text = "Graphics Quality"}, 20, y_offset, w - 40, 20)
        y_offset = y_offset + 30
        
        if suit.Button({id = "graphics_low"}, {text = "Low"}, 20, y_offset, 60, 30).hit then
            print("Graphics set to Low")
        end
        
        if suit.Button({id = "graphics_med"}, {text = "Medium"}, 90, y_offset, 60, 30).hit then
            print("Graphics set to Medium")
        end
        
        if suit.Button({id = "graphics_high"}, {text = "High"}, 160, y_offset, 60, 30).hit then
            print("Graphics set to High")
        end
        
        y_offset = y_offset + 60
        
        -- Close button
        if suit.Button({id = "close_settings"}, {text = "Close"}, w - 80, h - 40, 60, 30).hit then
            ui.hideWindow("settings")
        end
    end
    
    return ui.createWindow("settings", "Settings", 100, 100, 300, 250, settings_content)
end

-- Show/hide windows
function ui.showWindow(id)
    if uiState.windows[id] then
        uiState.windows[id].visible = true
    end
end

function ui.hideWindow(id)
    if uiState.windows[id] then
        uiState.windows[id].visible = false
    end
end

-- Add message to chat window
function ui.addChatMessage(message, color)
    color = color or {1, 1, 1} -- Default white
    local time = os.date("*t")
    local timestamp = string.format("[%02d:%02d]", time.hour, time.min)
    
    table.insert(uiState.chatWindow.messages, {
        text = timestamp .. " " .. message,
        color = color,
        time = love.timer.getTime()
    })
    
    -- Remove old messages
    if #uiState.chatWindow.messages > uiState.chatWindow.maxMessages then
        table.remove(uiState.chatWindow.messages, 1)
    end
end

-- Toggle chat window visibility
function ui.toggleChat()
    uiState.chatWindow.visible = not uiState.chatWindow.visible
end

-- Draw chat window
function ui.drawChatWindow()
    local chat = uiState.chatWindow
    if not chat.visible then return end
    
    local colors = uiState.theme.colors
    
    -- Background
    love.graphics.setColor(colors.background[1], colors.background[2], colors.background[3], 0.9)
    love.graphics.rectangle("fill", chat.x, chat.y, chat.width, chat.height)
    
    -- Border
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", chat.x, chat.y, chat.width, chat.height)
    love.graphics.setLineWidth(1)
    
    -- Title bar
    love.graphics.setColor(colors.panel[1], colors.panel[2], colors.panel[3], 0.8)
    love.graphics.rectangle("fill", chat.x, chat.y, chat.width, 20)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(chatFont)
    love.graphics.print("Console", chat.x + 5, chat.y + 3)
    
    -- Messages
    love.graphics.setFont(chatFont)
    local lineHeight = chatFont:getHeight() + 2
    local startY = chat.y + 25
    local visibleLines = math.floor((chat.height - 30) / lineHeight)

    -- Draw messages from bottom to top (newest at bottom)
    local startIndex = math.max(1, #chat.messages - visibleLines + 1)
    for i = startIndex, #chat.messages do
        local msg = chat.messages[i]
        local y = startY + (i - startIndex) * lineHeight

        love.graphics.setColor(msg.color)
        love.graphics.print(msg.text, chat.x + 5, y)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

-- Update UI system
function ui.update(dt)
    suit.update(dt)
    
    -- Update tooltips
    if uiState.tooltip and uiState.tooltip.timer > 0 then
        uiState.tooltip.timer = uiState.tooltip.timer - dt
    end
end

-- Draw all UI elements
function ui.draw()
    love.graphics.push("all")

    -- Draw windows
    for _, window in pairs(uiState.windows) do
        ui.drawWindow(window)
    end

    -- Draw chat window
    ui.drawChatWindow()

    -- Draw confirmation dialog (on top of other UI)
    ui.drawConfirmDialog()

    -- Draw context menu (on top of other UI)
    if uiState.contextMenu then
        local context_menu = require("src.context_menu")
        context_menu.draw(uiState.contextMenu)
    end

    -- Draw tooltip last (on top)
    ui.drawTooltip()

    love.graphics.pop()
end

-- Event handling
function ui.mousepressed(x, y, button)
    -- Let SUIT handle the click first
    suit.mousepressed(x, y, button)
    
    -- Check if the click was over any UI element


    
    -- Check all windows
    for windowId, window in pairs(uiState.windows) do
        if window.visible then
            local winX = window.x or 0
            local winY = window.y or 0  
            local winW = window.w or 0
            local winH = window.h or 0
            if x >= winX and x <= winX + winW and
               y >= winY and y <= winY + winH then
                -- Handle window-specific click events
                if window.onClick then
                    window.onClick(x - winX, y - winY, button)
                end
                return true -- UI consumed the click
            end
        end
    end
    
    -- Check if the chat window is visible and was clicked
    if uiState.chatWindow.visible then
        local chatX = uiState.chatWindow.x
        local chatY = uiState.chatWindow.y
        local chatW = uiState.chatWindow.width
        local chatH = uiState.chatWindow.height

        if x >= chatX and x <= chatX + chatW and
           y >= chatY and y <= chatY + chatH then
            return true -- UI consumed the click
        end
    end

    -- Check context menu (hide if clicked outside)
    if uiState.contextMenu then
        local context_menu = require("src.context_menu")
        if not context_menu.isPointInside(uiState.contextMenu, x, y) then
            ui.hideContextMenu()
            return true -- UI consumed the click (by hiding menu)
        end
    end

    return false -- UI did not consume the click
end




function ui.mousereleased(x, y, button)
    suit.mousereleased(x, y, button)
end

function ui.textinput(t)
    suit.textinput(t)
end

function ui.keypressed(key)
    suit.keypressed(key)
    
    if key == "escape" then
        -- Toggle settings window
        local settings = uiState.windows["settings"]
        if not settings then
            ui.createSettingsPanel()
        else
            settings.visible = not settings.visible
        end
    elseif key == "f1" or key == "`" then
        -- Toggle chat/console window
        ui.toggleChat()
    end
end

return ui