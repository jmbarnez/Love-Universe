local sword = {}
local base = require("src.items.base")

local function createSwordIcon()
    return base.getCachedIcon("sword", function()
        local canvas = base.createIconCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        -- Sword blade
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.rectangle("fill", 14, 8, 4, 18)
        
        -- Sword guard
        love.graphics.setColor(0.7, 0.7, 0.8, 1)
        love.graphics.rectangle("fill", 10, 18, 12, 2)
        
        -- Sword hilt
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", 13, 20, 6, 8)
        
        -- Sword pommel
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.rectangle("fill", 14, 26, 4, 3)
        
        love.graphics.setCanvas()
        return canvas
    end)
end

function sword.createSword()
    local ironSword = {
        id = "iron_sword",
        name = "Iron Sword",
        description = "A sturdy iron sword. Good for combat.",
        type = "weapon",
        rarity = "uncommon",
        stackable = false,
        color = {0.7, 0.7, 0.8, 1},  -- Steel gray
        icon = createSwordIcon(),
        count = 1,
        stats = {
            attack = 15,
            speed = -0.1
        },
        
        onUse = function(player, item)
            ui.addChatMessage("You swing the sword through the air.", {0.8, 0.8, 1})
        end,
        
        onEquip = function(player, slot)
            ui.addChatMessage("Equipped Iron Sword (+15 Attack)", {0, 1, 0})
        end
    }
    return ironSword
end

return sword