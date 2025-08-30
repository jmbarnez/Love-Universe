-- Interaction Outline module for Love2D RPG
-- Handles drawing simple square outlines around entities for interaction highlighting

local interaction_outline = {}

-- Draw simple square outline for any entity
function interaction_outline.drawSimpleSquareOutline(entity, worldX, worldY, color)
    love.graphics.setColor(color or {1, 1, 1, 0.8}) -- Use provided color or default to white
    love.graphics.setLineWidth(2)
    
    -- Calculate square dimensions with minimal padding
    local padding = math.min(4, entity.size * 0.1) -- Use minimal padding, max 4 pixels
    local halfSize = entity.size + padding
    local x = worldX - halfSize
    local y = worldY - halfSize
    local width = halfSize * 2
    local height = halfSize * 2
    
    love.graphics.rectangle("line", x, y, width, height)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1) -- Reset to white
end


-- Table to store custom outline functions for different entity types
local customOutlines = {}

-- Register a custom outline function for a specific entity type
function interaction_outline.registerOutline(entityType, outlineFunction)
    customOutlines[entityType] = outlineFunction
end

-- Universal simple square outline function for all entities
function interaction_outline.draw(entity, worldX, worldY, color)
    if not entity then return end

    -- Check if there's a custom outline function for this entity type
    if customOutlines[entity.type] then
        customOutlines[entity.type](entity, worldX, worldY, color)
        return
    end

    -- Use simple square outline for all entity types
    interaction_outline.drawSimpleSquareOutline(entity, worldX, worldY, color)
end

return interaction_outline
