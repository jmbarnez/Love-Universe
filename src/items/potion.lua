local potion = {}
local base = require("src.items.base")

local function createPotionIcon()
    return base.getCachedIcon("potion", function()
        local canvas = base.createIconCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        -- Potion bottle
        love.graphics.setColor(0.8, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", 12, 8, 8, 16)
        
        -- Potion neck
        love.graphics.rectangle("fill", 14, 4, 4, 6)
        
        -- Potion liquid
        love.graphics.setColor(1, 0.3, 0.3, 0.8)
        love.graphics.rectangle("fill", 13, 18, 6, 4)
        
        -- Cork
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", 14, 2, 4, 4)
        
        love.graphics.setCanvas()
        return canvas
    end)
end

function potion.createPotion()
    local healthPotion = {
        id = "health_potion",
        name = "Health Potion",
        description = "Restores 50 HP when consumed.",
        type = "consumable",
        rarity = "common",
        stackable = true,
        stackMax = 10,
        color = {0.8, 0.2, 0.2, 1},  -- Red
        icon = createPotionIcon(),
        count = 1,
        
        onUse = function(player, item)
            if player and player.health then
                local oldHealth = player.health
                player.health = math.min(player.maxHealth or 100, player.health + 50)
                local healed = player.health - oldHealth
                ui.addChatMessage("Restored " .. healed .. " HP", {0, 1, 0})
            end
        end
    }
    return healthPotion
end

return potion