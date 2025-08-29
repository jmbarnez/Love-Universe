-- World module for Love2D RPG
-- Main interface for world generation and management

local world = {}
local world_config = require("src.world.world_config")
local world_generator = require("src.world.world_generator")
local ground_items = require("src.world.ground_items")
local constants = require("src.constants")
local lume = require("lib.lume")

-- Ground items storage (will be set by game module)
world.groundItems = nil

-- Generate procedural world with realistic biomes using default configuration
function world.generate()
    local config = world_config.get_default()
    return world_generator.generate(config)
end

-- Generate world using a specific configuration
function world.generateWithConfig(config_name)
    local config = world_config.get(config_name)
    return world_generator.generate(config)
end

-- Generate world using a custom configuration
function world.generateWithCustomConfig(custom_config)
    return world_generator.generate(custom_config)
end

-- Ground item management functions (delegated to ground_items module)
function world.addGroundItem(...)
    return ground_items.add_item(...)
end

function world.updateGroundItems(...)
    return ground_items.update(...)
end

-- Additional ground item functions (delegated to ground_items module)
function world.drawGroundItems(...)
    return ground_items.draw(...)
end

function world.updateGroundItemHover(...)
    return ground_items.update_hover(...)
end

function world.drawGroundItemTooltip(...)
    return ground_items.draw_tooltip(...)
end

function world.drawGroundItemOutlines(...)
    return ground_items.draw_outlines(...)
end

function world.getGroundItemAtPosition(...)
    return ground_items.get_at_position(...)
end




-- Convert screen coordinates to world coordinates (pixel-based)
function world.screenToWorld(screenX, screenY, camera)
    -- Use hump camera for coordinate conversion
    return camera:worldCoords(screenX, screenY)
end

-- Convert world coordinates to screen coordinates (pixel-based)
function world.worldToScreen(worldX, worldY, camera)
    -- Use hump camera for coordinate conversion
    return camera:screenCoords(worldX, worldY)
end

-- Check if coordinates are within world bounds (pixel-based)
function world.isInWorld(x, y)
    return x >= 0 and x < constants.WORLD_WIDTH and y >= 0 and y < constants.WORLD_HEIGHT
end

-- Check if a position is walkable (pixel-based)
function world.isWalkable(x, y, gameWorld)
    -- Convert pixel coordinates to tile coordinates for lookup
    local tileX = math.floor(x / constants.TILE_SIZE) + 1
    local tileY = math.floor(y / constants.TILE_SIZE) + 1

    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    if tileX < 1 or tileX > tilesX or tileY < 1 or tileY > tilesY then
        return false
    end

    local tile = gameWorld[tileX] and gameWorld[tileX][tileY]
    return tile and tile.walkable
end

-- Find the nearest safe spawn location (pixel-based)
function world.findSafeSpawn(gameWorld)
    local centerX, centerY = constants.WORLD_WIDTH / 2, constants.WORLD_HEIGHT / 2

    -- First check the center
    if world.isWalkable(centerX, centerY, gameWorld) then
        return centerX, centerY
    end

    -- Spiral outward from center to find nearest walkable position
    local maxSearchRadius = 300 -- pixels to search
    local step = 16 -- step size in pixels (half tile)

    for radius = step, maxSearchRadius, step do
        -- Check perimeter of circle
        local circumference = 2 * math.pi * radius
        local numChecks = math.max(8, math.floor(circumference / step))

        for i = 1, numChecks do
            local angle = (i / numChecks) * 2 * math.pi
            local checkX = centerX + math.cos(angle) * radius
            local checkY = centerY + math.sin(angle) * radius

            if world.isInWorld(checkX, checkY) and world.isWalkable(checkX, checkY, gameWorld) then
                return checkX, checkY
            end
        end
    end

    -- Ultimate fallback - center of world (even if not walkable)
    return centerX, centerY
end

-- Draw world tiles
function world.drawTiles(gameWorld, camera, GAME_WIDTH, GAME_HEIGHT)
    -- With hump camera, we need to calculate the actual visible world bounds
    -- Get the world coordinates of the screen corners to determine what to draw
    local topLeftWorldX, topLeftWorldY = camera:worldCoords(0, 0)
    local bottomRightWorldX, bottomRightWorldY = camera:worldCoords(GAME_WIDTH, GAME_HEIGHT)

    -- Clamp the world coordinates to valid bounds to prevent rendering outside the world
    topLeftWorldX = math.max(0, topLeftWorldX)
    topLeftWorldY = math.max(0, topLeftWorldY)
    bottomRightWorldX = math.min(constants.WORLD_WIDTH - 1, bottomRightWorldX)
    bottomRightWorldY = math.min(constants.WORLD_HEIGHT - 1, bottomRightWorldY)

    -- Calculate which tiles are visible (convert world coords to tile coords)
    local startTileX = math.max(1, math.floor(topLeftWorldX / constants.TILE_SIZE) + 1)
    local startTileY = math.max(1, math.floor(topLeftWorldY / constants.TILE_SIZE) + 1)
    local endTileX = math.min(#gameWorld, math.ceil(bottomRightWorldX / constants.TILE_SIZE) + 1)
    local endTileY = math.min(#gameWorld[1] or 0, math.ceil(bottomRightWorldY / constants.TILE_SIZE) + 1)

    -- Draw tiles
    for x = startTileX, endTileX do
        for y = startTileY, endTileY do
            if gameWorld[x] and gameWorld[x][y] then
                local tile = gameWorld[x][y]

                -- Calculate pixel position
                local pixelX = (x - 1) * constants.TILE_SIZE
                local pixelY = (y - 1) * constants.TILE_SIZE

                -- Slightly blend tile colors to reduce grid appearance
                local blendColor = {
                    tile.color[1] * constants.TILE_COLOR_BLEND_FACTOR,
                    tile.color[2] * constants.TILE_COLOR_BLEND_FACTOR,
                    tile.color[3] * constants.TILE_COLOR_BLEND_FACTOR,
                    1.0
                }

                love.graphics.setColor(blendColor)
                love.graphics.rectangle("fill", pixelX, pixelY, constants.TILE_SIZE, constants.TILE_SIZE)

                -- Add subtle shading to water tiles
                if tile.type == "water" then
                    love.graphics.setColor(tile.color[1] * constants.WATER_SHADING_FACTOR, tile.color[2] * constants.WATER_SHADING_FACTOR, tile.color[3] * constants.WATER_SHADING_FACTOR, constants.WATER_TRANSPARENCY)
                    love.graphics.rectangle("fill", pixelX, pixelY, constants.TILE_SIZE, constants.TILE_SIZE)
                end
            end
        end
    end
end

-- Draw world objects
function world.drawObjects(objects, camera, GAME_WIDTH, GAME_HEIGHT)
    -- With hump camera, we need to calculate the actual visible world bounds
    -- Get the world coordinates of the screen corners to determine what to draw
    local topLeftWorldX, topLeftWorldY = camera:worldCoords(0, 0)
    local bottomRightWorldX, bottomRightWorldY = camera:worldCoords(GAME_WIDTH, GAME_HEIGHT)

    -- Clamp the world coordinates to valid bounds to prevent rendering outside the world
    topLeftWorldX = math.max(0, topLeftWorldX)
    topLeftWorldY = math.max(0, topLeftWorldY)
    bottomRightWorldX = math.min(constants.WORLD_WIDTH - 1, bottomRightWorldX)
    bottomRightWorldY = math.min(constants.WORLD_HEIGHT - 1, bottomRightWorldY)

    -- Calculate which tiles are visible (convert world coords to tile coords)
    local startTileX = math.max(1, math.floor(topLeftWorldX / constants.TILE_SIZE) + 1)
    local startTileY = math.max(1, math.floor(topLeftWorldY / constants.TILE_SIZE) + 1)
    local endTileX = math.min(#objects, math.ceil(bottomRightWorldX / constants.TILE_SIZE) + 1)
    local endTileY = math.min(#objects[1] or 0, math.ceil(bottomRightWorldY / constants.TILE_SIZE) + 1)

    -- Draw objects (trees, rocks, flowers)
    for x = startTileX, endTileX do
        for y = startTileY, endTileY do
            if objects[x] and objects[x][y] then
                local obj = objects[x][y]
                local pixelX = (x - 1) * constants.TILE_SIZE
                local pixelY = (y - 1) * constants.TILE_SIZE

                love.graphics.setColor(obj.color)

                if obj.type == "tree" then
                    love.graphics.circle("fill", pixelX + constants.TILE_SIZE/2, pixelY + constants.TILE_SIZE/2, obj.size/2)
                elseif obj.type == "rock" then
                    love.graphics.rectangle("fill", pixelX, pixelY, obj.size, obj.size)
                elseif obj.type == "flower" then
                    love.graphics.circle("fill", pixelX + constants.TILE_SIZE/2, pixelY + constants.TILE_SIZE/2, obj.size/2)
                elseif obj.type == "cactus" then
                    -- Draw cactus as a vertical rectangle with arms
                    love.graphics.rectangle("fill", pixelX + obj.size/4, pixelY, obj.size/2, obj.size)
                    -- Add arms
                    love.graphics.rectangle("fill", pixelX, pixelY + obj.size/3, obj.size/4, obj.size/4)
                    love.graphics.rectangle("fill", pixelX + obj.size * 0.75, pixelY + obj.size/2, obj.size/4, obj.size/4)
                elseif obj.type == "palm" then
                    -- Draw palm tree: trunk + leaves
                    love.graphics.rectangle("fill", pixelX + obj.size/2 - 1, pixelY + obj.size/2, 2, obj.size/2)
                    -- Palm leaves
                    love.graphics.circle("fill", pixelX + obj.size/2, pixelY + obj.size/4, obj.size/3)
                end
            end
        end
    end
end

-- Draw entities (chickens, NPCs, etc.)
function world.drawEntities(entities, camera, GAME_WIDTH, GAME_HEIGHT, playerX, playerY, playerTarget, mouseWorldX, mouseWorldY)
    -- Calculate visible world bounds to only check entities that might be on screen
    local topLeftWorldX, topLeftWorldY = camera:worldCoords(0, 0)
    local bottomRightWorldX, bottomRightWorldY = camera:worldCoords(GAME_WIDTH, GAME_HEIGHT)

    -- Clamp the world coordinates to valid bounds to prevent rendering outside the world
    topLeftWorldX = math.max(0, topLeftWorldX)
    topLeftWorldY = math.max(0, topLeftWorldY)
    bottomRightWorldX = math.min(constants.WORLD_WIDTH - 1, bottomRightWorldX)
    bottomRightWorldY = math.min(constants.WORLD_HEIGHT - 1, bottomRightWorldY)

    -- Add some buffer around the visible area
    local buffer = constants.TILE_SIZE * 2
    topLeftWorldX = topLeftWorldX - buffer
    topLeftWorldY = topLeftWorldY - buffer
    bottomRightWorldX = bottomRightWorldX + buffer
    bottomRightWorldY = bottomRightWorldY + buffer

    -- Find closest interactable entity for outline
    local closestEntity = nil
    local closestDistance = math.huge
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    -- First pass: find closest entity within interaction range (only check visible area)
    local startTileX = math.max(1, math.floor(topLeftWorldX / constants.TILE_SIZE) + 1)
    local startTileY = math.max(1, math.floor(topLeftWorldY / constants.TILE_SIZE) + 1)
    local endTileX = math.min(tilesX, math.ceil(bottomRightWorldX / constants.TILE_SIZE) + 1)
    local endTileY = math.min(tilesY, math.ceil(bottomRightWorldY / constants.TILE_SIZE) + 1)

    -- Safety check to prevent infinite loops
    if startTileX > endTileX or startTileY > endTileY then
        return -- No visible tiles, skip drawing
    end

    for x = startTileX, endTileX do
        for y = startTileY, endTileY do
            if entities[x] and entities[x][y] and entities[x][y].alive then
                local entity = entities[x][y]
                local distance = lume.distance(entity.worldX, entity.worldY, playerX, playerY)
                if distance <= constants.INTERACTION_DISTANCE and distance < closestDistance then -- 75 is INTERACTION_DISTANCE
                    closestDistance = distance
                    closestEntity = entity
                end
            end
        end
    end

    -- Second pass: draw entities in visible area, highlight the closest one
    for x = startTileX, endTileX do
        for y = startTileY, endTileY do
            if entities[x] and entities[x][y] then
                local entity = entities[x][y]
                -- Only draw alive entities
                if entity.alive then
                    local isInteractable = (entity == closestEntity)
                    local isTargeted = (playerTarget and playerTarget.entity == entity)
                local isHovered = false
                    local distance_to_mouse = lume.distance(entity.worldX, entity.worldY, mouseWorldX, mouseWorldY)
                    if distance_to_mouse <= entity.size then
                    isHovered = true
                end

                    -- Draw entity using its icon
                    world.drawEntityIcon(entity, camera, isInteractable, isTargeted, isHovered, playerX, playerY)
                end
            end
        end
    end
end

-- Draw entity using its icon (generic drawing method)
function world.drawEntityIcon(entity, camera, isInteractable, isTargeted, isHovered, playerX, playerY)
    -- Use world coordinates directly since we're in camera context
    local worldX, worldY = entity.worldX, entity.worldY

    local interaction_outline = require("src.interaction_outline")
    local constants = require("src.constants")
    
    -- Calculate distance to player
    local lume = require("lib.lume")
    local distance = lume.distance(entity.worldX, entity.worldY, playerX or 0, playerY or 0)
    
    -- Determine outline color based on state
    if isTargeted then
        -- Red for attacking (within attack range), yellow for targeted but out of attack range
        if distance <= constants.ATTACK_RANGE then
            interaction_outline.draw(entity, worldX, worldY, {1, 0, 0}) -- Red for attacking
        else
            interaction_outline.draw(entity, worldX, worldY, {1, 1, 0}) -- Yellow for targeted but out of attack range
        end
    elseif isHovered then
        interaction_outline.draw(entity, worldX, worldY, {1, 1, 1}) -- White for hovered/interactable
    elseif isInteractable then
        interaction_outline.draw(entity, worldX, worldY, {1, 1, 1}) -- White for interactable
    end

    if entity.icon then
        -- Draw the entity icon
        love.graphics.setColor(1, 1, 1, 1) -- White tint
        local iconSize = 24 -- Size to draw the icon
        local scale = iconSize / 32 -- Scale from 32x32 icon to desired size
        love.graphics.draw(entity.icon, worldX, worldY, 0, scale, scale, 16, 16) -- Center the 32x32 icon
    else
        -- Fallback: draw a simple shape
        love.graphics.setColor(1, 1, 1, 1) -- White
        love.graphics.circle("fill", worldX, worldY, 8) -- Simple white circle
        love.graphics.setColor(0, 0, 0, 1) -- Black border
        love.graphics.circle("line", worldX, worldY, 8)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return world
