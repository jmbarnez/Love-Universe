local chicken_skull = {}
chicken_skull.__index = chicken_skull

local base = require("src.items.base")
local ui = require("src.ui")

-- Draw a chicken skull icon
local function createChickenSkullIcon()
    return base.getCachedIcon("chicken_skull", function()
        local canvas = base.createIconCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)  -- Transparent background

        -- Draw skull base (main skull shape)
        love.graphics.setColor(0.9, 0.85, 0.8, 1) -- Bone white
        love.graphics.ellipse("fill", 16, 12, 10, 8) -- Main skull
        
        -- Draw eye sockets (black holes)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("fill", 12, 10, 2) -- Left eye socket
        love.graphics.circle("fill", 20, 10, 2) -- Right eye socket
        
        -- Draw beak (triangular)
        love.graphics.setColor(0.8, 0.7, 0.5, 1) -- Darker bone color for beak
        love.graphics.polygon("fill", 16, 14, 14, 18, 18, 18) -- Triangular beak
        
        -- Draw small crack details
        love.graphics.setColor(0.7, 0.6, 0.5, 1)
        love.graphics.setLineWidth(1)
        love.graphics.line(10, 8, 12, 6) -- Left crack
        love.graphics.line(22, 8, 20, 6) -- Right crack
        love.graphics.line(16, 20, 16, 24) -- Center crack going down
        
        -- Add some bone texture lines
        love.graphics.setColor(0.8, 0.75, 0.7, 1)
        love.graphics.line(8, 12, 24, 12) -- Horizontal line across skull
        love.graphics.line(16, 4, 16, 8) -- Vertical line on forehead

        love.graphics.setCanvas()
        return canvas
    end)
end

function chicken_skull.new()
    local self = setmetatable({}, chicken_skull)
    self.id = "chicken_skull"
    self.name = "Chicken Skull"
    self.description = "The bleached skull of a defeated chicken. A trophy of victory, or perhaps useful for dark rituals."
    self.type = "material"
    self.rarity = "common"
    self.stackable = true
    self.stackMax = 99
    self.color = {0.9, 0.85, 0.8, 1}  -- Bone white
    self.icon = createChickenSkullIcon()
    self.count = 1

    -- Item functions
    self.onUse = function(player, item)
        ui.addChatMessage("You examine the chicken skull. Its hollow eyes seem to stare back at you.", {0.8, 0.8, 0.6})
    end

    return self
end

return chicken_skull