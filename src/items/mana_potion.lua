local mana_potion = {}
local base = require("src.items.base")
local ui = require("src.ui")

local function createManaPotionIcon()
    return base.getCachedIcon("manaPotion", function()
        local canvas = base.createIconCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        -- Potion bottle
        love.graphics.setColor(0.2, 0.4, 0.8, 1)
        love.graphics.rectangle("fill", 12, 8, 8, 16)
        
        -- Potion neck
        love.graphics.rectangle("fill", 14, 4, 4, 6)
        
        -- Potion liquid
        love.graphics.setColor(0.3, 0.5, 1, 0.8)
        love.graphics.rectangle("fill", 13, 18, 6, 4)
        
        -- Cork
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", 14, 2, 4, 4)
        
        love.graphics.setCanvas()
        return canvas
    end)
end

function mana_potion.createManaPotion()
    local manaPotion = {
        id = "mana_potion",
        name = "Mana Potion",
        description = "Restores 30 MP when consumed.",
        type = "consumable",
        rarity = "common",
        stackable = true,
        stackMax = 10,
        color = {0.2, 0.4, 0.8, 1},  -- Blue
        icon = createManaPotionIcon(),
        count = 1,
        
        onUse = function(player, item)
            -- In a real game, you'd have mana system
            ui.addChatMessage("Restored 30 MP", {0.3, 0.5, 1})
        end
    }
    return manaPotion
end

return mana_potion