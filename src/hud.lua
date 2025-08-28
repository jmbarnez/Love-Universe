-- HUD module for Love2D RPG
-- Simple health and stamina bars only

local hud = {}
local constants = require("src.constants")



-- Draw minimal HUD with three bars in top left corner
function hud.draw(player, gameState)
    local barWidth = constants.HUD_BAR_WIDTH
    local barHeight = constants.HUD_BAR_HEIGHT
    local spacing = constants.HUD_BAR_SPACING
    local startY = constants.HUD_START_Y
    local barX = 10

    -- Helper function to draw a bar with text inside
    local function drawBarWithText(label, current, max, yPos, fillColor, textColor)
        -- Background
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", barX, yPos, barWidth, barHeight)

        -- Fill
        love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3])
        love.graphics.rectangle("fill", barX, yPos, barWidth * (current / max), barHeight)

        -- Border
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", barX, yPos, barWidth, barHeight)

        -- Text inside bar (centered)
        local text = label .. ": " .. current .. "/" .. max
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        local textX = barX + (barWidth - textWidth) / 2
        local textY = yPos + (barHeight - textHeight) / 2

        love.graphics.setColor(textColor[1], textColor[2], textColor[3])
        love.graphics.print(text, textX, textY)
    end

    -- Health Bar (Red background, white text)
    local healthColor = {1, 0, 0} -- Red
    -- Flash brighter red when taking damage
    if player.flashTimer and player.flashTimer > 0 then
        healthColor = {1, 0.3, 0.3} -- Light red flash
    end
    drawBarWithText("HP", player.health, player.maxHealth, startY, healthColor, {1, 1, 1})

    -- Mana Bar (Blue background, white text)
    drawBarWithText("MP", math.floor(player.mana), player.maxMana, startY + spacing, {0, 0.5, 1}, {1, 1, 1})

    -- Stamina Bar (Yellow background, dark text for contrast)
    drawBarWithText("ST", math.floor(player.stamina), player.maxStamina, startY + (spacing * 2), {1, 1, 0}, {0, 0, 0})

    -- Reset color
    love.graphics.setColor(1, 1, 1)

    -- Show inventory toggle hint (bottom left)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("Press TAB for Inventory", 10, love.graphics.getHeight() - 25)

    -- Draw enemy tooltip (top center)
    local tooltipTarget = hud.getTooltipTarget(gameState)
    if tooltipTarget then
        hud.drawEnemyTooltip(tooltipTarget)
    end
end

-- Find the enemy that should show a tooltip (current target or hovered enemy)
function hud.getTooltipTarget(gameState)
    -- First priority: current combat target
    if gameState.playerTarget and gameState.playerTarget.entity and gameState.playerTarget.entity.alive then
        return gameState.playerTarget.entity
    end

    -- Second priority: enemy under mouse cursor (only if inventory is not visible)
    if not gameState.inventory or not gameState.inventory.visible then
        if gameState.mouse then
            local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
            local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

            -- Check tiles around mouse position
            local mouseTileX = math.floor(gameState.mouse.worldX / constants.TILE_SIZE) + 1
            local mouseTileY = math.floor(gameState.mouse.worldY / constants.TILE_SIZE) + 1
            local checkRadius = 2

            for x = math.max(1, mouseTileX - checkRadius), math.min(tilesX, mouseTileX + checkRadius) do
                for y = math.max(1, mouseTileY - checkRadius), math.min(tilesY, mouseTileY + checkRadius) do
                    if gameState.chickens[x] and gameState.chickens[x][y] and gameState.chickens[x][y].alive then
                        local chick = gameState.chickens[x][y]
                        local distance = math.sqrt((chick.worldX - gameState.mouse.worldX)^2 + (chick.worldY - gameState.mouse.worldY)^2)

                        -- If mouse is within reasonable distance of enemy
                        if distance <= chick.size + 20 then
                            return chick
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- Draw enemy tooltip in top center of screen
function hud.drawEnemyTooltip(enemy)
    if not enemy then return end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Tooltip dimensions
    local tooltipWidth = 250
    local tooltipHeight = 60
    local tooltipX = (screenWidth - tooltipWidth) / 2
    local tooltipY = 20

    -- Tooltip background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", tooltipX - 2, tooltipY - 2, tooltipWidth + 4, tooltipHeight + 4)

    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, tooltipHeight)

    -- Tooltip border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipWidth, tooltipHeight)

    -- Enemy name and level
    local nameText = enemy.name .. " (Level " .. enemy.level .. ")"
    love.graphics.setColor(1, 1, 1, 1)
    local font = love.graphics.getFont()
    local nameWidth = font:getWidth(nameText)
    local nameX = tooltipX + (tooltipWidth - nameWidth) / 2
    love.graphics.print(nameText, nameX, tooltipY + 8)

    -- Health bar
    local barWidth = 200
    local barHeight = 12
    local barX = tooltipX + (tooltipWidth - barWidth) / 2
    local barY = tooltipY + 30

    -- Health bar background
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)

    -- Health bar fill
    local currentHealth = enemy.alive and enemy.health or 0
    local healthPercent = currentHealth / enemy.maxHealth
    local healthColor = {0, 1, 0} -- Green
    if not enemy.alive then
        healthColor = {0.5, 0.5, 0.5} -- Gray when dead
    elseif healthPercent < 0.3 then
        healthColor = {1, 0, 0} -- Red when low
    elseif healthPercent < 0.6 then
        healthColor = {1, 1, 0} -- Yellow when medium
    end

    love.graphics.setColor(healthColor[1], healthColor[2], healthColor[3], 0.9)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)

    -- Health bar border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)

    -- Health text
    local healthText = currentHealth .. "/" .. enemy.maxHealth
    if not enemy.alive then
        healthText = "DEAD"
    end
    love.graphics.setColor(1, 1, 1, 1)
    local healthTextWidth = font:getWidth(healthText)
    love.graphics.print(healthText, barX + (barWidth - healthTextWidth) / 2, barY + barHeight + 2)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return hud
