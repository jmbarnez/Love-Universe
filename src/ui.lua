-- Enhanced UI module for Love2D RPG
-- Uses SUIT library for better looking and more functional UI components

local ui = {}
local suit = require("lib.suit")
local lume = require("lib.lume")

-- UI state
local uiState = {
    windows = {},
    modals = {},
    tooltips = {},
    currentModal = nil,
    theme = {},
    chatWindow = {
        messages = {},
        visible = true,
        maxMessages = 50,
        x = 10,
        y = 0, -- Will be set dynamically
        width = 400,
        height = 150
    }
}

-- Initialize UI system
function ui.init()
    -- Create custom theme
    ui.createTheme()
    
    -- Position chat window at bottom left
    uiState.chatWindow.y = love.graphics.getHeight() - uiState.chatWindow.height - 10
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
    love.graphics.printf(window.title, x, y + (titleHeight - 16) / 2, w, "center")
    
    -- Draw window content
    if window.content_func then
        love.graphics.push()
        love.graphics.translate(x, y + titleHeight)
        window.content_func(window, w, h - titleHeight)
        love.graphics.pop()
    end
end

-- Create a health bar
function ui.drawHealthBar(x, y, w, h, current, max, label)
    local colors = uiState.theme.colors
    local percentage = lume.clamp(current / max, 0, 1)
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Health fill
    love.graphics.setColor(colors.health)
    love.graphics.rectangle("fill", x, y, w * percentage, h)
    
    -- Border
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Text
    if label then
        love.graphics.setColor(colors.text)
        local text = string.format("%s: %d/%d", label, current, max)
        love.graphics.printf(text, x, y + (h - 14) / 2, w, "center")
    end
end

-- Create a mana bar
function ui.drawManaBar(x, y, w, h, current, max, label)
    local colors = uiState.theme.colors
    local percentage = lume.clamp(current / max, 0, 1)
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Mana fill
    love.graphics.setColor(colors.mana)
    love.graphics.rectangle("fill", x, y, w * percentage, h)
    
    -- Border
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Text
    if label then
        love.graphics.setColor(colors.text)
        local text = string.format("%s: %d/%d", label, current, max)
        love.graphics.printf(text, x, y + (h - 14) / 2, w, "center")
    end
end

-- Create a stamina bar
function ui.drawStaminaBar(x, y, w, h, current, max, label)
    local colors = uiState.theme.colors
    local percentage = lume.clamp(current / max, 0, 1)
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Stamina fill
    love.graphics.setColor(colors.stamina)
    love.graphics.rectangle("fill", x, y, w * percentage, h)
    
    -- Border
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Text
    if label then
        love.graphics.setColor(colors.text)
        local text = string.format("%s: %.0f/%.0f", label, current, max)
        love.graphics.printf(text, x, y + (h - 14) / 2, w, "center")
    end
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
    local font = love.graphics.getFont()
    local text = tooltip.text
    local w = font:getWidth(text) + 16
    local h = font:getHeight() + 8
    
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
            love.graphics.printf(tostring(item.count), x, y + h - 16, w, "right")
        end
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
    love.graphics.print("Console", chat.x + 5, chat.y + 3)
    
    -- Messages
    local font = love.graphics.getFont()
    local lineHeight = font:getHeight() + 2
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
    
    -- Draw tooltip last (on top)
    ui.drawTooltip()
    
    love.graphics.pop()
end

-- Event handling
function ui.mousepressed(x, y, button)
    suit.mousepressed(x, y, button)
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