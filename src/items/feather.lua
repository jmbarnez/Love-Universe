local feather = {}
feather.__index = feather

local base = require("src.items.base")
local ui = require("src.ui")

-- Draw a feather icon
local function createFeatherIcon()
    return base.getCachedIcon("feather", function()
        local canvas = base.createIconCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)  -- Transparent background

        -- Draw feather shaft
        love.graphics.setColor(0.8, 0.6, 0.4, 1)
        love.graphics.rectangle("fill", 14, 4, 4, 24)

        -- Draw feather vanes
        love.graphics.setColor(0.9, 0.8, 0.6, 1)
        for i = 0, 6 do
            local y = 6 + i * 3
            local leftX = 10 - i * 0.5
            local rightX = 22 + i * 0.5
            love.graphics.rectangle("fill", leftX, y, 4, 2)
            love.graphics.rectangle("fill", rightX, y, 4, 2)
        end

        love.graphics.setCanvas()
        return canvas
    end)
end

function feather.new()
    local self = setmetatable({}, feather)
    self.id = "feather"
    self.name = "Feather"
    self.description = "A light and fluffy feather. Useful for crafting."
    self.type = "material"
    self.rarity = "common"
    self.stackable = true
    self.stackMax = 99
    self.color = {0.9, 0.8, 0.6, 1}  -- Light brown
    self.icon = createFeatherIcon()
    self.count = 1

    -- Item functions
    self.onUse = function(player, item)
        -- Example use function
        ui.addChatMessage("You wave the feather around. Nothing happens.", {0.8, 0.8, 1})
    end

    return self
end

return feather