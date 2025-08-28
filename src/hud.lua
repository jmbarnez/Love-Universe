-- HUD module for Love2D RPG
-- Enhanced HUD with new UI system integration

local hud = {}
local constants = require("src.constants")
local ui = require("src.ui")
local lume = require("lib.lume")



-- Draw enhanced HUD with new UI system
function hud.draw(player, gameState)
    local barWidth = constants.HUD_BAR_WIDTH
    local barHeight = constants.HUD_BAR_HEIGHT
    local spacing = constants.HUD_BAR_SPACING
    local startY = constants.HUD_START_Y
    local barX = constants.HUD_MARGIN_X

    -- Use the new UI system for better-looking bars
    ui.drawHealthBar(barX, startY, barWidth, barHeight, player.health, player.maxHealth, "Health")
    ui.drawManaBar(barX, startY + spacing, barWidth, barHeight, player.mana, player.maxMana, "Mana")
    ui.drawStaminaBar(barX, startY + spacing * 2, barWidth, barHeight, player.stamina, player.maxStamina, "Stamina")

    -- Reset color
    love.graphics.setColor(1, 1, 1)

    -- Show inventory toggle hint (bottom left)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("Press TAB for Inventory", constants.HUD_MARGIN_X, love.graphics.getHeight() - 25 * constants.UI_SCALE)

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
                        local distance = lume.distance(chick.worldX, chick.worldY, gameState.mouse.worldX, gameState.mouse.worldY)

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

    -- Tooltip dimensions (scaled)
    local tooltipWidth = 250 * constants.UI_SCALE
    local tooltipHeight = 60 * constants.UI_SCALE
    local tooltipX = (screenWidth - tooltipWidth) / 2
    local tooltipY = 20 * constants.UI_SCALE

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

    -- Health bar (scaled)
    local barWidth = 200 * constants.UI_SCALE
    local barHeight = 12 * constants.UI_SCALE
    local barX = tooltipX + (tooltipWidth - barWidth) / 2
    local barY = tooltipY + 30 * constants.UI_SCALE

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
