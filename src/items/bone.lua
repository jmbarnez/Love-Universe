local bone = {}
bone.__index = bone

local base = require("src.items.base")
local ui = require("src.ui")

-- Draw a bone icon
local function createBoneIcon()
    return base.getCachedIcon("bone", function()
        local canvas = base.createIconCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)  -- Transparent background

        -- Draw bone shaft
        love.graphics.setColor(0.9, 0.9, 0.8, 1)
        love.graphics.rectangle("fill", 12, 12, 8, 8)

        -- Draw bone ends (top and bottom)
        love.graphics.setColor(0.95, 0.95, 0.9, 1)
        love.graphics.ellipse("fill", 16, 8, 6, 4)   -- Top end
        love.graphics.ellipse("fill", 16, 24, 6, 4)  -- Bottom end

        -- Add some detail lines
        love.graphics.setColor(0.8, 0.8, 0.7, 1)
        love.graphics.line(14, 14, 14, 18)
        love.graphics.line(18, 14, 18, 18)

        love.graphics.setCanvas()
        return canvas
    end)
end

function bone.new()
    local self = setmetatable({}, bone)
    self.id = "bone"
    self.name = "Bone"
    self.description = "A sturdy bone. Useful for crafting and prayer."
    self.type = "material"
    self.rarity = "common"
    self.stackable = true
    self.stackMax = 99
    self.color = {0.9, 0.9, 0.8, 1}  -- Off-white
    self.icon = createBoneIcon()
    self.count = 1

    -- Item functions
    self.onUse = function(player, item)
        ui.addChatMessage("You examine the bone. It looks ancient.", {0.9, 0.9, 0.8})
    end

    return self
end

return bone