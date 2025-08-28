local scroll = {}

-- Icon cache to avoid recreating the same icons
local iconCache = {}

-- Create a simple icon canvas
local function createIconCanvas()
    return love.graphics.newCanvas(32, 32)
end

-- Draw a scroll icon
local function createScrollIcon()
    if iconCache.scroll then return iconCache.scroll end
    local canvas = createIconCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    -- Scroll background
    love.graphics.setColor(0.9, 0.8, 0.6, 1)
    love.graphics.rectangle("fill", 8, 8, 16, 16)
    -- Scroll text lines
    love.graphics.setColor(0.3, 0.2, 0.1, 1)
    for i = 0, 4 do
        local y = 10 + i * 3
        love.graphics.rectangle("fill", 10, y, 12, 1)
    end
    -- Scroll ribbon
    love.graphics.setColor(0.6, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", 12, 4, 8, 4)
    love.graphics.setCanvas()
    iconCache.scroll = canvas
    return canvas
end

function scroll.createSpellScroll()
    local spellScroll = {
        id = "fireball_scroll",
        name = "Fireball Scroll",
        description = "A scroll containing the Fireball spell. Single use.",
        type = "consumable",
        rarity = "rare",
        stackable = true,
        stackMax = 5,
        color = {0.9, 0.3, 0.1, 1},  -- Orange/red
        icon = createScrollIcon(),
        count = 1,

        onUse = function(player, item)
            ui.addChatMessage("You cast Fireball! Deals 50 fire damage.", {1, 0.5, 0})
        end
    }
    return spellScroll
end

return scroll