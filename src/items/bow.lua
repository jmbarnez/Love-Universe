local bow = {}
local base = require("src.items.base")

local function createBowIcon()
    return base.getCachedIcon("bow", function()
        local canvas = base.createIconCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        -- Bow body
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", 15, 4, 2, 24)
        
        -- Bow string
        love.graphics.setColor(0.8, 0.8, 0.6, 1)
        love.graphics.line(16, 6, 14, 10)
        love.graphics.line(14, 10, 14, 22)
        love.graphics.line(14, 22, 16, 26)
        
        love.graphics.setCanvas()
        return canvas
    end)
end

function bow.createBow()
    local woodenBow = {
        id = "wooden_bow",
        name = "Wooden Bow",
        description = "A simple wooden bow. Good for ranged combat.",
        type = "weapon",
        rarity = "common",
        stackable = false,
        color = {0.4, 0.2, 0.1, 1},  -- Brown wood
        icon = createBowIcon(),
        count = 1,
        stats = {
            attack = 12,
            range = 8
        },
        
        onUse = function(player, item)
            ui.addChatMessage("You draw the bow and take aim.", {0.8, 0.8, 1})
        end,
        
        onEquip = function(player, slot)
            ui.addChatMessage("Equipped Wooden Bow (+12 Attack)", {0, 1, 0})
        end
    }
    return woodenBow
end

return bow