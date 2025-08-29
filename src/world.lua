-- World module for Love2D RPG
-- Handles world generation, biomes, collision detection, and world objects

local world = {}
local constants = require("src.constants")
local chicken = require("src.enemies.chicken")
local lume = require("lib.lume")

-- Ground items storage (will be set by game module)
world.groundItems = nil

-- Generate height map (pixel-based)
function world.generateHeightMap()
    local heightMap = {}
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    for x = 1, tilesX do
        heightMap[x] = {}
        for y = 1, tilesY do
            -- Use multiple octaves for more natural terrain
            local height = 0
            local amplitude = 1
            local frequency = constants.HEIGHT_MAP_SCALE

            -- Add multiple octaves for detail
            for octave = 1, constants.HEIGHT_OCTAVES do
                height = height + love.math.noise(x * frequency, y * frequency) * amplitude
                amplitude = amplitude * 0.5
                frequency = frequency * 2
            end

            -- Normalize height to 0-1 range
            heightMap[x][y] = (height + 1) / 2
        end
    end

    return heightMap
end

-- Generate temperature map (north-south gradient with noise)
function world.generateTemperatureMap()
    local tempMap = {}
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    for x = 1, tilesX do
        tempMap[x] = {}
        for y = 1, tilesY do
            -- Temperature decreases as we go north (lower y values)
            local baseTemp = 1.0 - (y / tilesY) * constants.TEMPERATURE_BASE_GRADIENT
            local noise = love.math.noise(x * constants.TEMPERATURE_NOISE_SCALE, y * constants.TEMPERATURE_NOISE_SCALE) * constants.TEMPERATURE_NOISE_AMPLITUDE
            -- Add some extra variation for more interesting biome distribution
            local extraVariation = love.math.noise(x * constants.BIOME_VARIATION_SCALE, y * constants.BIOME_VARIATION_SCALE) * 0.1
            tempMap[x][y] = math.max(0, math.min(1, baseTemp + noise + extraVariation))
        end
    end

    return tempMap
end

-- Generate humidity map
function world.generateHumidityMap()
    local humidityMap = {}
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    for x = 1, tilesX do
        humidityMap[x] = {}
        for y = 1, tilesY do
            local baseHumidity = love.math.noise(x * constants.HUMIDITY_NOISE_SCALE, y * constants.HUMIDITY_NOISE_SCALE)
            -- Add some extra variation for more interesting biome distribution
            local extraVariation = love.math.noise(x * constants.BIOME_VARIATION_SCALE + 100, y * constants.BIOME_VARIATION_SCALE + 100) * 0.15
            humidityMap[x][y] = math.max(0, math.min(1, baseHumidity + extraVariation))
        end
    end

    return humidityMap
end

-- Determine biome based on height, temperature, and humidity
function world.getBiome(height, temperature, humidity, x, y)
    -- Ocean and deep ocean (lowest elevations)
    if height < constants.DEEP_OCEAN_THRESHOLD then
        return {type = "deep_ocean", color = {0.05, 0.15, 0.4}, walkable = false}
    elseif height < constants.OCEAN_THRESHOLD then
        -- Add some coastal water variation
        local coastalNoise = love.math.noise(x * 0.1, y * 0.1)
        if coastalNoise < constants.COASTAL_WATER_CHANCE then
            return {type = "ocean", color = {0.05, 0.25, 0.7}, walkable = false}
        else
            return {type = "ocean", color = {0.1, 0.3, 0.8}, walkable = false}
        end
    end

    -- Beach (coastal areas just above water)
    if height < constants.BEACH_THRESHOLD then
        return {type = "beach", color = {0.95, 0.9, 0.7}, walkable = true}
    end

    -- Desert (hot, dry areas)
    if temperature > constants.HOT_TEMPERATURE_THRESHOLD and humidity < constants.DRY_HUMIDITY_THRESHOLD then
        return {type = "desert", color = {0.9, 0.8, 0.6}, walkable = true}
    end

    -- Grassland (moderate conditions)
    if temperature > 0.4 and temperature < 0.9 and humidity > constants.DRY_HUMIDITY_THRESHOLD then
        if height > constants.MODERATE_HEIGHT_THRESHOLD then
            return {type = "hills", color = {0.3, 0.5, 0.2}, walkable = true}
        else
            return {type = "grassland", color = {0.25, 0.6, 0.2}, walkable = true}
        end
    end

    -- Forest in temperate, humid areas
    if temperature > constants.COLD_TEMPERATURE_THRESHOLD and temperature < constants.HOT_TEMPERATURE_THRESHOLD and humidity > constants.WET_HUMIDITY_THRESHOLD then
        if height > constants.HIGH_HEIGHT_THRESHOLD then
            return {type = "dark_forest", color = {0.1, 0.25, 0.1}, walkable = true}
        else
            return {type = "forest", color = {0.15, 0.4, 0.15}, walkable = true}
        end
    end

    -- Mountains at high elevations
    if height > constants.MOUNTAIN_HEIGHT_THRESHOLD then
        if temperature < constants.COLD_TEMPERATURE_THRESHOLD then
            return {type = "snow_mountain", color = {0.9, 0.9, 0.95}, walkable = true}
        else
            return {type = "mountain", color = {0.4, 0.4, 0.4}, walkable = true}
        end
    end

    -- Tundra in cold areas
    if temperature < constants.COLD_TEMPERATURE_THRESHOLD then
        return {type = "tundra", color = {0.6, 0.7, 0.5}, walkable = true}
    end

    -- Default to grassland
    return {type = "grassland", color = {0.25, 0.6, 0.2}, walkable = true}
end

-- Generate scattered objects (chickens and ground items) - pixel-based
function world.generateObjects(gameWorld)
    local objects = {}
    local chickens = {}
    local groundItems = {}

    -- Initialize empty objects and chickens tables (still use tile grid for storage)
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    for x = 1, tilesX do
        objects[x] = {}
        chickens[x] = {}
        for y = 1, tilesY do
            objects[x][y] = nil
            chickens[x][y] = nil
        end
    end

    -- Spawn chickens in grasslands and hills at pixel coordinates (max 3 total)
    local grasslandCount = 0
    local hillsCount = 0
    local chickensSpawned = 0

    for x = 1, tilesX do
        for y = 1, tilesY do
            local tile = gameWorld[x][y]
            if tile.type == "grassland" then grasslandCount = grasslandCount + 1 end
            if tile.type == "hills" then hillsCount = hillsCount + 1 end

            local spawnChance = love.math.random()

            if (tile.type == "grassland" or tile.type == "hills") and spawnChance < constants.CHICKEN_SPAWN_RATE and chickensSpawned < 3 then
                -- Spawn chicken at random pixel coordinates within this tile
                local tileLeft = (x - 1) * constants.TILE_SIZE
                local tileTop = (y - 1) * constants.TILE_SIZE
                local pixelX = tileLeft + love.math.random(0, constants.TILE_SIZE - 1)
                local pixelY = tileTop + love.math.random(0, constants.TILE_SIZE - 1)
                chickens[x][y] = chicken.create(pixelX, pixelY)
                chickensSpawned = chickensSpawned + 1
            end
        end
    end

    -- DEBUG: Print biome and chicken spawn info
    -- print("=== WORLD GENERATION DEBUG ===")
    -- print("World tiles: " .. tilesX .. "x" .. tilesY .. " = " .. (tilesX * tilesY) .. " total tiles")
    -- print("Grassland tiles: " .. grasslandCount)
    -- print("Hills tiles: " .. hillsCount)

    -- Ensure at least some chickens spawn near the center (fallback, but respect max 3 limit)
    if chickensSpawned < 3 then
        local centerTileX = math.floor(tilesX / 2)
        local centerTileY = math.floor(tilesY / 2)

        -- Always ensure some chickens spawn near the center for gameplay (but don't exceed 3 total)
        local guaranteedChickens = 0
        for x = math.max(1, centerTileX - 8), math.min(tilesX, centerTileX + 8) do
            for y = math.max(1, centerTileY - 8), math.min(tilesY, centerTileY + 8) do
                local tile = gameWorld[x][y]
                if chickens[x][y] == nil and (tile.type == "grassland" or tile.type == "hills") and love.math.random() < 0.4 and chickensSpawned < 3 then
                    local tileLeft = (x - 1) * constants.TILE_SIZE
                    local tileTop = (y - 1) * constants.TILE_SIZE
                    local pixelX = tileLeft + love.math.random(0, constants.TILE_SIZE - 1)
                    local pixelY = tileTop + love.math.random(0, constants.TILE_SIZE - 1)
                    chickens[x][y] = chicken.create(pixelX, pixelY)
                    guaranteedChickens = guaranteedChickens + 1
                    chickensSpawned = chickensSpawned + 1
                end
            end
        end
    end

    -- Spawn sticks in any grassy biome as world items (permanent, with random rotations)
    local sticksSpawned = 0
    local maxSticks = 50  -- Maximum number of sticks to spawn

    -- Define grassy tile types where sticks can spawn
    local grassyTileTypes = {
        "grassland",
        "hills",
        "forest",
        "dark_forest"
    }

    for x = 1, tilesX do
        for y = 1, tilesY do
            local tile = gameWorld[x][y]
            if tile and sticksSpawned < maxSticks then
                -- Check if this tile type is grassy
                local isGrassy = false
                for _, grassyType in ipairs(grassyTileTypes) do
                    if tile.type == grassyType then
                        isGrassy = true
                        break
                    end
                end

                if isGrassy then
                    local spawnChance = love.math.random()
                    if spawnChance < constants.STICK_SPAWN_RATE then
                        -- Spawn stick at random pixel coordinates within this tile
                        local tileLeft = (x - 1) * constants.TILE_SIZE
                        local tileTop = (y - 1) * constants.TILE_SIZE
                        local pixelX = tileLeft + love.math.random(0, constants.TILE_SIZE - 1)
                        local pixelY = tileTop + love.math.random(0, constants.TILE_SIZE - 1)

                        -- Create a stick item and add it as a permanent ground item with random rotation
                        local stick = require("src.items.stick")
                        local stickItem = stick.new()
                        world.addGroundItem(groundItems, stickItem, pixelX, pixelY + 2, true) -- true = permanent
                        sticksSpawned = sticksSpawned + 1
                    end
                end
            end
        end
    end

    return objects, chickens, groundItems
end

-- Generate procedural world with realistic biomes
function world.generate()
    -- Set a random seed for unique world generation each time
    local worldSeed = love.math.random(1, 1000000)
    love.math.setRandomSeed(worldSeed)

    -- Generate environmental maps
    local heightMap = world.generateHeightMap()
    local tempMap = world.generateTemperatureMap()
    local humidityMap = world.generateHumidityMap()

    -- Generate world based on environmental factors
    local gameWorld = {}
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    for x = 1, tilesX do
        gameWorld[x] = {}
        for y = 1, tilesY do
            local height = heightMap[x][y]
            local temperature = tempMap[x][y]
            local humidity = humidityMap[x][y]

            gameWorld[x][y] = world.getBiome(height, temperature, humidity, x, y)
        end
    end

    -- Generate scattered objects, chickens, and ground items
    local objects, chickens, groundItems = world.generateObjects(gameWorld)

    return gameWorld, objects, chickens, groundItems
end

-- Add a ground item to the world
function world.addGroundItem(groundItems, item, x, y, permanent)
    if groundItems then
        table.insert(groundItems, {
            item = item,
            x = x,
            y = y,
            rotation = permanent and (love.math.random() * 2 * math.pi) or 0, -- Random rotation for permanent items
            createdTime = love.timer.getTime(), -- Timestamp when item was dropped
            expireTime = permanent and nil or 30.0 -- Permanent items don't expire, others expire in 30 seconds
        })
    end
end



-- Update ground items and remove expired ones
function world.updateGroundItems(groundItems, dt)
    if not groundItems then
        return
    end

    local currentTime = love.timer.getTime()
    local i = 1
    while i <= #groundItems do
        local groundItem = groundItems[i]
        if groundItem.createdTime and groundItem.expireTime then
            local age = currentTime - groundItem.createdTime
            if age >= groundItem.expireTime then
                -- Item has expired, remove it
                table.remove(groundItems, i)
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
end

-- Ground item hover state for tooltips (now handles piles)
local groundItemHover = {
    pile = nil, -- Now stores the entire pile instead of single item
    time = 0,
    tooltipDelay = 0.15,
    x = 0,
    y = 0
}

-- Draw ground items
function world.drawGroundItems(groundItems, camera)
    if not groundItems then
        return
    end
    
    for i, groundItem in ipairs(groundItems) do
        local item = groundItem.item
        
        if item.icon then
            -- Draw the actual icon image with rotation if it's a permanent item
            love.graphics.setColor(1, 1, 1, 1)
            local iconSize = 24 -- Size of ground item icon
            local iconScale = iconSize / 32 -- Scale from 32x32 to desired size
            local rotation = groundItem.rotation or 0
            love.graphics.draw(item.icon,
                              groundItem.x, groundItem.y,
                              rotation,
                              iconScale, iconScale,
                              16, 16) -- Origin at center of 32x32 icon
        else
            -- Fallback: draw colored rectangle if no icon (with rotation for permanent items)
            local itemColor = item.color or {0.8, 0.8, 0.8, 1}
            love.graphics.setColor(itemColor)
            local iconSize = 20
            local rotation = groundItem.rotation or 0
            if rotation > 0 then
                love.graphics.push()
                love.graphics.translate(groundItem.x, groundItem.y)
                love.graphics.rotate(rotation)
                love.graphics.rectangle("fill", -iconSize/2, -iconSize/2, iconSize, iconSize)
                love.graphics.pop()
            else
                love.graphics.rectangle("fill", groundItem.x - iconSize/2, groundItem.y - iconSize/2, iconSize, iconSize)
            end
        end
        
        -- Draw item count if stackable and count > 1
        if item.count and item.count > 1 then
            love.graphics.setColor(1, 1, 1, 1)
            local countText = tostring(item.count)
            local font = love.graphics.getFont()
            local textWidth = font:getWidth(countText)
            local textHeight = font:getHeight()
            
            -- Draw dark background for text
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle("fill", groundItem.x + 8, groundItem.y + 8, textWidth + 4, textHeight + 2)
            
            -- Draw count text
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(countText, groundItem.x + 10, groundItem.y + 9)
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1)
end



-- Update ground item hover state for tooltips (now handles piles)
function world.updateGroundItemHover(dt, mouseWorldX, mouseWorldY, groundItems)
    if not groundItems then
        groundItemHover.pile = nil
        groundItemHover.time = 0
        return
    end
    
    local hoveredPile = nil
    local checkRadius = 20 -- pixels - interaction radius
    local piles = world.groupItemsByLocation(groundItems)
    
    -- Check if mouse is over any item pile
    for _, pile in ipairs(piles) do
        local distance = lume.distance(pile.centerX, pile.centerY, mouseWorldX, mouseWorldY)
        if distance <= checkRadius then
            hoveredPile = pile
            break
        end
    end
    
    if hoveredPile then
        if groundItemHover.pile and 
           groundItemHover.pile.centerX == hoveredPile.centerX and 
           groundItemHover.pile.centerY == hoveredPile.centerY then
            groundItemHover.time = groundItemHover.time + dt
        else
            groundItemHover.pile = hoveredPile
            groundItemHover.time = 0
            groundItemHover.x = mouseWorldX
            groundItemHover.y = mouseWorldY
        end
    else
        groundItemHover.pile = nil
        groundItemHover.time = 0
    end
end

-- Draw ground item tooltip (now handles item piles with stacked tooltips)
function world.drawGroundItemTooltip(camera)
    if not groundItemHover.pile or groundItemHover.time < groundItemHover.tooltipDelay then
        return
    end
    
    local pile = groundItemHover.pile
    if not pile or not pile.items or #pile.items == 0 then return end
    
    -- Convert world position to screen position for tooltip
    local screenX, screenY = world.worldToScreen(groundItemHover.x, groundItemHover.y, camera)
    local tooltipX = screenX + 15
    local tooltipY = screenY - 10
    
    -- Build tooltip content for all items in the pile
    local lines = {}
    local itemCounts = {} -- Track item types and their total counts
    
    -- Group items by name and sum their counts
    for _, groundItem in ipairs(pile.items) do
        local item = groundItem.item
        local itemName = item.name or "Unknown Item"
        
        if not itemCounts[itemName] then
            itemCounts[itemName] = {
                item = item,
                count = 0
            }
        end
        itemCounts[itemName].count = itemCounts[itemName].count + (item.count or 1)
    end
    
    -- If multiple item types, show pile header
    if next(itemCounts, next(itemCounts)) then -- More than one item type
        table.insert(lines, "=== Item Pile (" .. #pile.items .. " items) ===")
        table.insert(lines, "") -- Empty line for spacing
    end
    
    -- Add each unique item type to tooltip
    for itemName, itemData in pairs(itemCounts) do
        local item = itemData.item
        local totalCount = itemData.count
        
        -- Item name with count if > 1
        if totalCount > 1 then
            table.insert(lines, itemName .. " (x" .. totalCount .. ")")
        else
            table.insert(lines, itemName)
        end
        
        -- Add item details for first occurrence (avoid repetition)
        if item.description then
            table.insert(lines, "  " .. item.description)
        end
        
        if item.type then
            table.insert(lines, "  Type: " .. item.type)
        end
        
        if item.rarity then
            table.insert(lines, "  Rarity: " .. item.rarity)
        end
        
        table.insert(lines, "") -- Empty line between item types
    end
    
    -- Remove last empty line
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines)
    end
    
    -- Calculate tooltip dimensions
    local font = love.graphics.getFont()
    local maxWidth = 0
    local totalHeight = 0
    local lineHeight = font:getHeight() + 2
    
    for _, line in ipairs(lines) do
        local width = font:getWidth(line)
        maxWidth = math.max(maxWidth, width)
        totalHeight = totalHeight + lineHeight
    end
    
    local tooltipWidth = maxWidth + 16
    local tooltipHeight = totalHeight + 8
    
    -- Keep tooltip on screen
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    if tooltipX + tooltipWidth > screenWidth then
        tooltipX = screenX - tooltipWidth - 15
    end
    
    if tooltipY + tooltipHeight > screenHeight then
        tooltipY = screenY - tooltipHeight - 10
    end
    
    if tooltipY < 0 then
        tooltipY = screenY + 20
    end
    
    -- Get UI colors from ui module if available
    local ui = require("src.ui")
    local colors = (ui and ui.uiState and ui.uiState.theme and ui.uiState.theme.colors) or {
        panel = {0.12, 0.12, 0.18, 0.95},
        border = {0.4, 0.3, 0.2, 1.0},
        text = {0.9, 0.85, 0.8, 1.0}
    }
    
    -- Draw tooltip background
    love.graphics.setColor(colors.panel)
    if ui and ui.drawRoundedRect then
        ui.drawRoundedRect(tooltipX, tooltipY, tooltipWidth, tooltipHeight, 6)
    else
        love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, tooltipHeight)
    end
    
    -- Draw tooltip border
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    if ui and ui.drawRoundedRectOutline then
        ui.drawRoundedRectOutline(tooltipX, tooltipY, tooltipWidth, tooltipHeight, 6)
    else
        love.graphics.rectangle("line", tooltipX, tooltipY, tooltipWidth, tooltipHeight)
    end
    love.graphics.setLineWidth(1)
    
    -- Draw tooltip text
    love.graphics.setColor(colors.text)
    local yOffset = tooltipY + 6
    for _, line in ipairs(lines) do
        love.graphics.print(line, tooltipX + 8, yOffset)
        yOffset = yOffset + lineHeight
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

-- Group nearby items into piles for better interaction handling
function world.groupItemsByLocation(groundItems)
    local piles = {}
    local pileRadius = 25 -- pixels - items within this distance are grouped together
    
    for _, groundItem in ipairs(groundItems) do
        local foundPile = false
        
        -- Check if this item belongs to an existing pile
        for _, pile in ipairs(piles) do
            local distance = lume.distance(groundItem.x, groundItem.y, pile.centerX, pile.centerY)
            if distance <= pileRadius then
                table.insert(pile.items, groundItem)
                -- Update pile center to average of all items
                local totalX, totalY = 0, 0
                for _, item in ipairs(pile.items) do
                    totalX = totalX + item.x
                    totalY = totalY + item.y
                end
                pile.centerX = totalX / #pile.items
                pile.centerY = totalY / #pile.items
                foundPile = true
                break
            end
        end
        
        -- If no pile found, create a new one
        if not foundPile then
            table.insert(piles, {
                centerX = groundItem.x,
                centerY = groundItem.y,
                items = {groundItem}
            })
        end
    end
    
    return piles
end

-- Draw interaction outline for ground items (handles item piles)
function world.drawGroundItemOutlines(groundItems, mouseWorldX, mouseWorldY, interactionOutline)
    if not groundItems or not interactionOutline then
        return
    end
    
    local checkRadius = 20 -- pixels - interaction radius
    local piles = world.groupItemsByLocation(groundItems)
    
    -- Find the closest pile within interaction range
    for _, pile in ipairs(piles) do
        local distance = lume.distance(pile.centerX, pile.centerY, mouseWorldX, mouseWorldY)
        if distance <= checkRadius then
            local itemCount = #pile.items
            
            if itemCount == 1 then
                -- Single item - draw tight outline around icon
                local item = pile.items[1].item
                local iconSize = item.icon and 24 or 20
                
                love.graphics.setColor(1, 1, 0, 0.8) -- Yellow outline
                love.graphics.rectangle("line", 
                    pile.centerX - iconSize/2 - 1, 
                    pile.centerY - iconSize/2 - 1, 
                    iconSize + 2, 
                    iconSize + 2)
            else
                -- Multiple items - draw circular outline around the pile
                local pileRadius = math.max(15, itemCount * 3) -- Scale radius with item count
                love.graphics.setColor(1, 1, 0, 0.8) -- Yellow outline
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", pile.centerX, pile.centerY, pileRadius)
                love.graphics.setLineWidth(1)
                
                -- Draw item count indicator
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.circle("fill", pile.centerX + pileRadius - 5, pile.centerY - pileRadius + 5, 8)
                love.graphics.setColor(0, 0, 0, 1)
                local font = love.graphics.getFont()
                local countText = tostring(itemCount)
                local textWidth = font:getWidth(countText)
                love.graphics.print(countText, pile.centerX + pileRadius - 5 - textWidth/2, pile.centerY - pileRadius + 5 - 6)
            end
            
            love.graphics.setColor(1, 1, 1) -- Reset color
            break -- Only outline one pile at a time
        end
    end
end

-- Get ground items at position (now returns the closest pile)
function world.getGroundItemAtPosition(worldX, worldY, groundItems)
    local checkRadius = 20 -- pixels - increased for better interaction
    local piles = world.groupItemsByLocation(groundItems)

    -- Find the closest pile within interaction range
    for _, pile in ipairs(piles) do
        local distance = lume.distance(pile.centerX, pile.centerY, worldX, worldY)
        if distance <= checkRadius then
            -- Return the first item from the pile and its index in the original groundItems array
            if pile.items and #pile.items > 0 then
                local firstItem = pile.items[1]
                -- Find the index in the original groundItems array
                for i, groundItem in ipairs(groundItems) do
                    if groundItem == firstItem then
                        return groundItem, i, pile -- Return the pile as well for multi-pickup
                    end
                end
            end
        end
    end
    return nil
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

-- Draw chickens
function world.drawChickens(chickens, camera, GAME_WIDTH, GAME_HEIGHT, playerX, playerY, playerTarget, mouseWorldX, mouseWorldY)
    -- Calculate visible world bounds to only check chickens that might be on screen
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

    -- Find closest interactable chicken for outline
    local closestChicken = nil
    local closestDistance = math.huge
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    -- First pass: find closest chicken within interaction range (only check visible area)
    local startTileX = math.max(1, math.floor(topLeftWorldX / constants.TILE_SIZE) + 1)
    local startTileY = math.max(1, math.floor(topLeftWorldY / constants.TILE_SIZE) + 1)
    local endTileX = math.min(tilesX, math.ceil(bottomRightWorldX / constants.TILE_SIZE) + 1)
    local endTileY = math.min(tilesY, math.ceil(bottomRightWorldY / constants.TILE_SIZE) + 1)

    for x = startTileX, endTileX do
        for y = startTileY, endTileY do
            if chickens[x] and chickens[x][y] and chickens[x][y].alive then
                local chick = chickens[x][y]
                local distance = lume.distance(chick.worldX, chick.worldY, playerX, playerY)
                if distance <= constants.INTERACTION_DISTANCE and distance < closestDistance then -- 75 is INTERACTION_DISTANCE
                    closestDistance = distance
                    closestChicken = chick
                end
            end
        end
    end

    -- Second pass: draw chickens in visible area, highlight the closest one
    for x = startTileX, endTileX do
        for y = startTileY, endTileY do
            if chickens[x] and chickens[x][y] then
                local chick = chickens[x][y]
                local isInteractable = (chick == closestChicken)
                local isTargeted = (playerTarget and playerTarget.entity == chick)
                local isHovered = false
                local distance_to_mouse = lume.distance(chick.worldX, chick.worldY, mouseWorldX, mouseWorldY)
                if distance_to_mouse <= chick.size then
                    isHovered = true
                end

                chicken.draw(chickens[x][y], camera, isInteractable, isTargeted, isHovered)
            end
        end
    end
end

return world
