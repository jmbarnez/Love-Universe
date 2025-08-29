local gem = {}
local ui = require("src.ui")

-- Icon cache to avoid recreating the same icons
local iconCache = {}

-- Create a simple icon canvas
local function createIconCanvas()
    return love.graphics.newCanvas(32, 32)
end

-- Draw a gem icon
local function createGemIcon()
    if iconCache.gem then return iconCache.gem end

    local canvas = createIconCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    -- Gem facets (octagon shape)
    love.graphics.setColor(0.9, 0.1, 0.1, 1)
    love.graphics.polygon("fill",
        16, 6,   -- top
        22, 10,  -- top-right
        22, 16,  -- bottom-right
        16, 22,  -- bottom
        10, 16,  -- bottom-left
        10, 10   -- top-left
    )

    -- Gem highlights
    love.graphics.setColor(1, 0.3, 0.3, 0.8)
    love.graphics.polygon("fill",
        16, 8,
        20, 12,
        16, 16,
        12, 12
    )

    -- Gem sparkle
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", 14, 10, 1)
    love.graphics.circle("fill", 18, 14, 1)

    love.graphics.setCanvas()
    iconCache.gem = canvas
    return canvas
end

function gem.createGem()
    local ruby = {
        id = "ruby",
        name = "Ruby",
        description = "A precious red gem. Valuable and rare.",
        type = "material",
        rarity = "rare",
        stackable = true,
        stackMax = 50,
        color = {0.9, 0.1, 0.1, 1},  -- Bright red
        icon = createGemIcon(),
        count = 1,

        onUse = function(player, item)
            ui.addChatMessage("The ruby gleams with inner fire.", {0.8, 0.8, 1})
        end
    }
    return ruby
end

return gem