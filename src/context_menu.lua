local context_menu = {}

function context_menu.create(x, y, options)
    return {
        x = x,
        y = y,
        options = options,
        width = 100,
        height = #options * 20 + 10
    }
end

function context_menu.draw(menu)
    if not menu then return end

    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", menu.x, menu.y, menu.width, menu.height)

    -- Draw border
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.rectangle("line", menu.x, menu.y, menu.width, menu.height)

    -- Draw options
    love.graphics.setColor(1, 1, 1, 1)
    for i, option in ipairs(menu.options) do
        love.graphics.print(option.text, menu.x + 5, menu.y + 5 + (i - 1) * 20)
    end
end

function context_menu.handleClick(menu, x, y)
    if not menu then return nil end

    if x >= menu.x and x <= menu.x + menu.width and y >= menu.y and y <= menu.y + menu.height then
        local option_index = math.floor((y - menu.y - 5) / 20) + 1
        if option_index > 0 and option_index <= #menu.options then
            return menu.options[option_index]
        end
    end
    return nil
end

return context_menu
