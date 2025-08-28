local context_menu = {}
local suit = require("lib.suit")

function context_menu.create(x, y, options)
    return {
        x = x,
        y = y,
        options = options,
        width = 140,
        height = #options * 26 + 10,
        visible = true
    }
end

function context_menu.draw(menu)
    if not menu or not menu.visible then return end

    local colors = {
        background = {0.12, 0.12, 0.18, 0.95},
        border = {0.4, 0.3, 0.2, 1.0},
        text = {0.9, 0.85, 0.8, 1.0},
        button = {0.25, 0.2, 0.15, 1.0},
        button_hover = {0.35, 0.25, 0.18, 1.0},
        button_active = {0.15, 0.12, 0.1, 1.0}
    }

    -- Keep menu on screen
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    if menu.x + menu.width > screenWidth then
        menu.x = screenWidth - menu.width
    end

    if menu.y + menu.height > screenHeight then
        menu.y = screenHeight - menu.height
    end

    -- Draw menu background
    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", menu.x, menu.y, menu.width, menu.height)

    -- Draw menu border
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", menu.x, menu.y, menu.width, menu.height)

    -- Draw menu options using SUIT buttons
    local buttonY = menu.y + 5
    for i, option in ipairs(menu.options) do
        suit.layout:reset(menu.x + 5, buttonY, menu.width - 10, 20)

        if option.enabled == false then
            love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
            love.graphics.print(option.text, menu.x + 10, buttonY + 2)
        else
            local button = suit.Button(option.text, {id = "context_" .. i}, menu.x + 5, buttonY, menu.width - 10, 20)
            if button.hit then
                option.action()
                menu.visible = false
                return
            end
        end

        buttonY = buttonY + 26
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function context_menu.handleClick(menu, x, y)
    if not menu or not menu.visible then return nil end

    -- SUIT handles the button clicks, so we don't need manual click detection
    -- Just return nil to indicate no manual handling needed
    return nil
end

-- Check if a point is inside the menu (for click-outside-to-close)
function context_menu.isPointInside(menu, x, y)
    if not menu or not menu.visible then return false end
    return x >= menu.x and x <= menu.x + menu.width and y >= menu.y and y <= menu.y + menu.height
end

return context_menu
