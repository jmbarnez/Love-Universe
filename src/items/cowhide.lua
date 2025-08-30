local cowhide = {}
cowhide.__index = cowhide

local base = require("src.items.base")
local ui = require("src.ui")

-- Draw a cowhide icon
local function createCowhideIcon()
    return base.getCachedIcon("cowhide", function()
        local canvas = base.createIconCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)  -- Transparent background

        -- Draw cowhide base
        love.graphics.setColor(0.6, 0.4, 0.2, 1)  -- Brown color
        love.graphics.ellipse("fill", 16, 16, 12, 10)

        -- Add some spots
        love.graphics.setColor(0.3, 0.2, 0.1, 1)  -- Darker brown spots
        love.graphics.ellipse("fill", 12, 12, 3, 2)
        love.graphics.ellipse("fill", 20, 14, 2.5, 2)
        love.graphics.ellipse("fill", 14, 20, 2, 1.5)
        love.graphics.ellipse("fill", 18, 18, 2, 2)

        -- Add texture lines
        love.graphics.setColor(0.4, 0.3, 0.15, 1)
        love.graphics.line(10, 16, 22, 16)
        love.graphics.line(16, 10, 16, 22)

        love.graphics.setCanvas()
        return canvas
    end)
end

function cowhide.new()
    local self = setmetatable({}, cowhide)
    self.id = "cowhide"
    self.name = "Cowhide"
    self.description = "A raw cowhide. Can be tanned into leather."
    self.type = "material"
    self.rarity = "common"
    self.stackable = true
    self.stackMax = 99
    self.color = {0.6, 0.4, 0.2, 1}  -- Brown
    self.icon = createCowhideIcon()
    self.count = 1

    -- Item functions
    self.onUse = function(player, item)
        ui.addChatMessage("You feel the rough texture of the cowhide.", {0.6, 0.4, 0.2})
    end

    return self
end

return cowhide