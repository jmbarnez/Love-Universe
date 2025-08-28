local armor = {}
local base = require("src.items.base")

local function createArmorIcon()
    return base.getCachedIcon("armor", function()
        local canvas = base.createIconCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        -- Armor chest piece
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", 8, 10, 16, 12)
        
        -- Armor shoulder pads
        love.graphics.rectangle("fill", 4, 12, 6, 6)
        love.graphics.rectangle("fill", 22, 12, 6, 6)
        
        -- Armor details (stitching)
        love.graphics.setColor(0.5, 0.3, 0.1, 1)
        love.graphics.rectangle("fill", 9, 11, 14, 1)
        love.graphics.rectangle("fill", 9, 20, 14, 1)
        
        love.graphics.setCanvas()
        return canvas
    end)
end

function armor.createArmor()
    local leatherArmor = {
        id = "leather_armor",
        name = "Leather Armor",
        description = "Basic leather armor. Provides some protection.",
        type = "armor",
        rarity = "common",
        stackable = false,
        color = {0.6, 0.4, 0.2, 1},  -- Brown
        icon = createArmorIcon(),
        count = 1,
        stats = {
            defense = 5,
            speed = -0.05
        },
        
        onEquip = function(player, slot)
            ui.addChatMessage("Equipped Leather Armor (+5 Defense)", {0, 1, 0})
        end
    }
    return leatherArmor
end

return armor