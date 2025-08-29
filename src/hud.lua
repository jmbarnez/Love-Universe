-- HUD module for Love2D RPG
-- Enhanced HUD with new UI system integration

local hud = {}
local constants = require("src.constants")
local ui = require("src.ui")
local lume = require("lib.lume")

-- Scaled HUD font (will be created in draw function)
local hudFont



-- Draw enhanced HUD with new UI system
function hud.draw(player, gameState)
    -- Create scaled HUD font
    local scale = constants.UI_SCALE or 1.0
    hudFont = love.graphics.newFont(math.max(9, math.floor(12 * scale)))

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
    love.graphics.setFont(hudFont)
    love.graphics.print("Press TAB for Inventory", constants.HUD_MARGIN_X, love.graphics.getHeight() - constants.INVENTORY_HINT_Y_OFFSET)

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
    local colors = ui.getThemeColors()

    -- Tooltip dimensions (scaled)
    local tooltipWidth = constants.TOOLTIP_WIDTH or math.floor(250 * constants.UI_SCALE)
    local tooltipHeight = constants.TOOLTIP_HEIGHT or math.floor(60 * constants.UI_SCALE)
    local tooltipX = (screenWidth - tooltipWidth) / 2
    local tooltipY = constants.TOOLTIP_Y_OFFSET
    local cornerRadius = 6

    -- Draw tooltip shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    ui.drawRoundedRect(tooltipX + 3, tooltipY + 3, tooltipWidth, tooltipHeight, cornerRadius)

    -- Tooltip background using theme colors
    love.graphics.setColor(colors.panel)
    ui.drawRoundedRect(tooltipX, tooltipY, tooltipWidth, tooltipHeight, cornerRadius)

    -- Inner shadow for depth
    love.graphics.setColor(0, 0, 0, 0.2)
    ui.drawRoundedRect(tooltipX + 2, tooltipY + 2, tooltipWidth - 4, tooltipHeight - 4, cornerRadius * 0.7)

    -- Tooltip border
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    ui.drawRoundedRectOutline(tooltipX, tooltipY, tooltipWidth, tooltipHeight, cornerRadius)
    love.graphics.setLineWidth(1)

    -- Enemy name and level
    local nameText = enemy.name .. " (Level " .. enemy.level .. ")"
    love.graphics.setColor(colors.text)
    love.graphics.setFont(hudFont)
    local nameWidth = hudFont:getWidth(nameText)
    local nameX = tooltipX + (tooltipWidth - nameWidth) / 2
    love.graphics.print(nameText, nameX, tooltipY + 10)

    -- Health bar using enhanced UI system
    local barWidth = math.floor(200 * constants.UI_SCALE)
    local barHeight = math.floor(12 * constants.UI_SCALE)
    local barX = tooltipX + (tooltipWidth - barWidth) / 2
    local barY = tooltipY + constants.HEALTH_BAR_Y_OFFSET

    local currentHealth = enemy.alive and enemy.health or 0
    local healthPercent = currentHealth / enemy.maxHealth

    -- Use the enhanced bar system for health
    ui.drawBar(barX, barY, barWidth, barHeight, currentHealth, enemy.maxHealth, nil, "health",
               {cornerRadius = 4, segments = 5, animate = false})

    -- Health text overlay
    local healthText = currentHealth .. "/" .. enemy.maxHealth
    if not enemy.alive then
        healthText = "DEAD"
    end
    love.graphics.setColor(colors.text)
    love.graphics.setFont(hudFont)
    local healthTextWidth = hudFont:getWidth(healthText)
    love.graphics.print(healthText, barX + (barWidth - healthTextWidth) / 2, barY + barHeight + 4)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return hud
