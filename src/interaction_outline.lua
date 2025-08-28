-- Interaction Outline module for Love2D RPG
-- Handles drawing accurate outlines around entities for interaction highlighting

local interaction_outline = {}

-- Draw outline for chicken entity
function interaction_outline.drawChickenOutline(chick, screenX, screenY)
    love.graphics.setColor(1, 1, 0, 0.8) -- Yellow outline for interaction

    -- Draw outline around chicken body (oval)
    love.graphics.ellipse("line", screenX, screenY, chick.size/2 + 2, chick.size/3 + 2)

    -- Draw outline around chicken head (circle)
    love.graphics.circle("line", screenX + chick.size/4, screenY - chick.size/4, chick.size/4 + 2)

    -- Draw outline around beak (triangle)
    love.graphics.polygon("line",
        screenX + chick.size/4 + chick.size/8, screenY - chick.size/4,
        screenX + chick.size/4 + chick.size/6, screenY - chick.size/4 - chick.size/12,
        screenX + chick.size/4 + chick.size/6, screenY - chick.size/4 + chick.size/12)

    -- Draw outline around legs (rectangles)
    love.graphics.rectangle("line", screenX - chick.size/8 - 1, screenY + chick.size/3 - 1, 4, chick.size/4 + 2)
    love.graphics.rectangle("line", screenX + chick.size/8 - 2 - 1, screenY + chick.size/3 - 1, 4, chick.size/4 + 2)

    love.graphics.setColor(1, 1, 1) -- Reset to white
end

-- Draw outline for generic circular entity (like player)
function interaction_outline.drawCircleOutline(entity, screenX, screenY)
    love.graphics.setColor(1, 1, 0, 0.8) -- Yellow outline for interaction
    love.graphics.circle("line", screenX, screenY, entity.size + 2)
    love.graphics.setColor(1, 1, 1) -- Reset to white
end

-- Draw outline for rectangular entity
function interaction_outline.drawRectangleOutline(entity, screenX, screenY)
    love.graphics.setColor(1, 1, 0, 0.8) -- Yellow outline for interaction
    love.graphics.rectangle("line", screenX - entity.size/2 - 2, screenY - entity.size/2 - 2, entity.size + 4, entity.size + 4)
    love.graphics.setColor(1, 1, 1) -- Reset to white
end

-- Table to store custom outline functions for different entity types
local customOutlines = {}

-- Register a custom outline function for a specific entity type
function interaction_outline.registerOutline(entityType, outlineFunction)
    customOutlines[entityType] = outlineFunction
end

-- Generic outline drawing function - dispatches based on entity type
function interaction_outline.draw(entity, screenX, screenY)
    if not entity or not entity.type then return end

    -- Check if there's a custom outline function for this entity type
    if customOutlines[entity.type] then
        customOutlines[entity.type](entity, screenX, screenY)
        return
    end

    -- Built-in outline functions
    if entity.type == "chicken" then
        interaction_outline.drawChickenOutline(entity, screenX, screenY)
    elseif entity.type == "player" then
        interaction_outline.drawCircleOutline(entity, screenX, screenY)
    elseif entity.type == "orc" then
        -- Example orc outline (rectangular)
        interaction_outline.drawRectangleOutline(entity, screenX, screenY)
    elseif entity.type == "goblin" then
        -- Example goblin outline (circular)
        interaction_outline.drawCircleOutline(entity, screenX, screenY)
    elseif entity.type == "skeleton" then
        -- Example skeleton outline (tall rectangle)
        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.rectangle("line", screenX - entity.size/4, screenY - entity.size/2, entity.size/2, entity.size)
        love.graphics.setColor(1, 1, 1)
    elseif entity.type == "dragon" then
        -- Example dragon outline (large oval)
        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.ellipse("line", screenX, screenY, entity.size, entity.size/2)
        love.graphics.setColor(1, 1, 1)
    else
        -- Default to circle outline for unknown types
        interaction_outline.drawCircleOutline(entity, screenX, screenY)
    end
end

return interaction_outline
