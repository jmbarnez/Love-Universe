local stick = {}
stick.__index = stick

local base = require("src.items.base")
local ui = require("src.ui")

-- Draw a stick icon
local function createStickIcon()
    return base.getCachedIcon("stick", function()
        local canvas = base.createIconCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)  -- Transparent background

        -- Draw stick shaft
        love.graphics.setColor(0.6, 0.4, 0.2, 1)  -- Brown wood color
        love.graphics.rectangle("fill", 12, 6, 8, 20)

        -- Add some texture lines to make it look like wood
        love.graphics.setColor(0.5, 0.35, 0.15, 1)
        love.graphics.rectangle("fill", 14, 8, 4, 16)
        love.graphics.setColor(0.7, 0.5, 0.3, 1)
        love.graphics.rectangle("fill", 13, 10, 2, 12)
        love.graphics.rectangle("fill", 17, 12, 2, 10)

        love.graphics.setCanvas()
        return canvas
    end)
end

function stick.new()
    local self = setmetatable({}, stick)
    self.id = "stick"
    self.name = "Stick"
    self.description = "A sturdy wooden stick. Useful for crafting tools and weapons."
    self.type = "material"
    self.rarity = "common"
    self.stackable = true
    self.stackMax = 99
    self.color = {0.6, 0.4, 0.2, 1}  -- Brown wood color
    self.icon = createStickIcon()
    self.count = 1

    -- Item functions
    self.onUse = function(player, item)
        -- Example use function
        ui.addChatMessage("You examine the stick closely. It seems quite sturdy.", {0.8, 0.8, 1})
    end

    return self
end

return stick
