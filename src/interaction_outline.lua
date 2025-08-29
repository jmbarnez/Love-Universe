-- Interaction Outline module for Love2D RPG
-- Handles drawing simple circle outlines around entities for interaction highlighting

local interaction_outline = {}

-- Draw simple circle outline for any entity
function interaction_outline.drawSimpleCircleOutline(entity, worldX, worldY, color)
    love.graphics.setColor(color or {1, 1, 0, 0.8}) -- Use provided color or default to yellow
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", worldX, worldY, entity.size + 8) -- Circle around entity with some padding
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1) -- Reset to white
end


-- Table to store custom outline functions for different entity types
local customOutlines = {}

-- Register a custom outline function for a specific entity type
function interaction_outline.registerOutline(entityType, outlineFunction)
    customOutlines[entityType] = outlineFunction
end

-- Universal simple circle outline function for all entities
function interaction_outline.draw(entity, worldX, worldY, color)
    if not entity then return end

    -- Check if there's a custom outline function for this entity type
    if customOutlines[entity.type] then
        customOutlines[entity.type](entity, worldX, worldY, color)
        return
    end

    -- Use simple circle outline for all entity types
    interaction_outline.drawSimpleCircleOutline(entity, worldX, worldY, color)
end

return interaction_outline
