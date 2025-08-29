local shield = {}
local base = require("src.items.base")
local ui = require("src.ui")

local function createShieldIcon()
    return base.getCachedIcon("shield", function()
        local canvas = base.createIconCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        -- Shield body
        love.graphics.setColor(0.7, 0.7, 0.8, 1)
        love.graphics.rectangle("fill", 8, 6, 16, 20)
        
        -- Shield boss (center piece)
        love.graphics.setColor(0.6, 0.6, 0.7, 1)
        love.graphics.circle("fill", 16, 16, 4)
        
        -- Shield rim
        love.graphics.setColor(0.5, 0.5, 0.6, 1)
        love.graphics.rectangle("line", 8, 6, 16, 20)
        
        love.graphics.setCanvas()
        return canvas
    end)
end

function shield.createShield()
    local ironShield = {
        id = "iron_shield",
        name = "Iron Shield",
        description = "A sturdy iron shield. Provides excellent protection.",
        type = "shield",
        rarity = "uncommon",
        stackable = false,
        color = {0.7, 0.7, 0.8, 1},  -- Steel gray
        icon = createShieldIcon(),
        count = 1,
        stats = {
            defense = 8,
            block = 0.3
        },
        
        onEquip = function(player, slot)
            ui.addChatMessage("Equipped Iron Shield (+8 Defense)", {0, 1, 0})
        end
    }
    return ironShield
end

return shield