-- Entity UI module for Love2D RPG
-- Handles drawing mini health bars and entity labels above entities

local entity_ui = {}

-- Draw a mini health bar above an entity
function entity_ui.drawMiniHealthBar(entity, screenX, screenY, barWidth, barHeight)
    if not entity.alive or not entity.health or not entity.maxHealth then return end

    -- Calculate health percentage
    local healthPercent = entity.health / entity.maxHealth
    local barY = screenY - entity.size - barHeight - 5 -- Position above entity

    -- Background (gray)
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.rectangle("fill", screenX - barWidth/2, barY, barWidth, barHeight)

    -- Health bar (green for full, red for low)
    local healthColor = {0, 1, 0} -- Green
    if healthPercent < 0.3 then
        healthColor = {1, 0, 0} -- Red when low
    elseif healthPercent < 0.6 then
        healthColor = {1, 0.5, 0} -- Orange when medium
    end

    love.graphics.setColor(healthColor[1], healthColor[2], healthColor[3], 0.9)
    love.graphics.rectangle("fill", screenX - barWidth/2, barY, barWidth * healthPercent, barHeight)

    -- Border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", screenX - barWidth/2, barY, barWidth, barHeight)

    -- Health text
    love.graphics.setColor(1, 1, 1, 1)
    local healthText = entity.health .. "/" .. entity.maxHealth
    local textWidth = love.graphics.getFont():getWidth(healthText)
    love.graphics.print(healthText, screenX - textWidth/2, barY - 15)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw entity label (name and level)
function entity_ui.drawEntityLabel(entity, screenX, screenY)
    if not entity.alive or not entity.name or not entity.level then return end

    local labelY = screenY - entity.size - 25 -- Position above health bar

    -- Label background
    local labelText = entity.name .. " (Lv." .. entity.level .. ")"
    local textWidth = love.graphics.getFont():getWidth(labelText)
    local padding = 4

    love.graphics.setColor(0, 0, 0, 0.7) -- Semi-transparent black background
    love.graphics.rectangle("fill", screenX - textWidth/2 - padding, labelY - padding, textWidth + padding*2, 14 + padding*2)

    -- Label text
    love.graphics.setColor(1, 1, 1, 1) -- White text
    love.graphics.print(labelText, screenX - textWidth/2, labelY)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw idle UI for an entity (small label only, when not in combat)
function entity_ui.drawIdleUI(entity, screenX, screenY)
    if not entity.alive or not entity.name or not entity.level then return end

    -- Only show when NOT in combat
    local combat = require("src.combat")
    if combat.isInCombat(entity) then return end

    local labelY = screenY - entity.size - 15 -- Position closer to entity (smaller)

    -- Label background (smaller)
    local labelText = entity.name .. " (Lv." .. entity.level .. ")"
    local textWidth = love.graphics.getFont():getWidth(labelText)
    local padding = 2 -- Smaller padding

    love.graphics.setColor(0, 0, 0, 0.5) -- More transparent background
    love.graphics.rectangle("fill", screenX - textWidth/2 - padding, labelY - padding, textWidth + padding*2, 12 + padding*2)

    -- Label text (smaller font)
    love.graphics.setColor(1, 1, 1, 1) -- White text
    love.graphics.print(labelText, screenX - textWidth/2, labelY)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw combat UI for an entity (health bar + label)
function entity_ui.drawCombatUI(entity, screenX, screenY)
    if not entity.alive then return end

    -- Only show during combat or if health is not full
    local showUI = false
    local combat = require("src.combat")
    if combat.isInCombat(entity) then
        showUI = true
    elseif entity.health and entity.maxHealth and entity.health < entity.maxHealth then
        showUI = true
    end

    if showUI then
        -- Draw label first (higher up)
        entity_ui.drawEntityLabel(entity, screenX, screenY)
        -- Draw health bar below label
        entity_ui.drawMiniHealthBar(entity, screenX, screenY, 40, 6)
    end
end

return entity_ui
