-- Biomes Module
-- Handles biome generation, environmental maps, and biome classification

local biomes = {}
local constants = require("src.constants")

-- Generate height map (pixel-based)
function biomes.generate_height_map(world_config)
    local heightMap = {}
    local tilesX = math.ceil(world_config.world_size.width / constants.TILE_SIZE)
    local tilesY = math.ceil(world_config.world_size.height / constants.TILE_SIZE)
    local settings = world_config.biome_settings

    for x = 1, tilesX do
        heightMap[x] = {}
        for y = 1, tilesY do
            -- Use multiple octaves for more natural terrain
            local height = 0
            local amplitude = 1
            local frequency = settings.height_map_scale

            -- Add multiple octaves for detail
            for octave = 1, settings.height_octaves do
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
function biomes.generate_temperature_map(world_config)
    local tempMap = {}
    local tilesX = math.ceil(world_config.world_size.width / constants.TILE_SIZE)
    local tilesY = math.ceil(world_config.world_size.height / constants.TILE_SIZE)
    local settings = world_config.biome_settings

    for x = 1, tilesX do
        tempMap[x] = {}
        for y = 1, tilesY do
            -- Temperature decreases as we go north (lower y values)
            local baseTemp = 1.0 - (y / tilesY) * settings.temperature_base_gradient
            local noise = love.math.noise(x * settings.temperature_noise_scale, y * settings.temperature_noise_scale) * settings.temperature_noise_amplitude
            -- Add some extra variation for more interesting biome distribution
            local extraVariation = love.math.noise(x * settings.biome_variation_scale, y * settings.biome_variation_scale) * 0.1
            tempMap[x][y] = math.max(0, math.min(1, baseTemp + noise + extraVariation))
        end
    end

    return tempMap
end

-- Generate humidity map
function biomes.generate_humidity_map(world_config)
    local humidityMap = {}
    local tilesX = math.ceil(world_config.world_size.width / constants.TILE_SIZE)
    local tilesY = math.ceil(world_config.world_size.height / constants.TILE_SIZE)
    local settings = world_config.biome_settings

    for x = 1, tilesX do
        humidityMap[x] = {}
        for y = 1, tilesY do
            local baseHumidity = love.math.noise(x * settings.humidity_noise_scale, y * settings.humidity_noise_scale)
            -- Add some extra variation for more interesting biome distribution
            local extraVariation = love.math.noise(x * settings.biome_variation_scale + 100, y * settings.biome_variation_scale + 100) * 0.15
            humidityMap[x][y] = math.max(0, math.min(1, baseHumidity + extraVariation))
        end
    end

    return humidityMap
end

-- Determine biome based on height, temperature, and humidity
function biomes.get_biome(height, temperature, humidity, x, y, world_config)
    local biome_config = world_config.biomes

    -- Ocean and deep ocean (lowest elevations)
    if height < biome_config.deep_ocean.threshold then
        return {type = "deep_ocean", color = biome_config.deep_ocean.color, walkable = biome_config.deep_ocean.walkable}
    elseif height < biome_config.ocean.threshold then
        -- Add some coastal water variation
        local coastalNoise = love.math.noise(x * 0.1, y * 0.1)
        if coastalNoise < biome_config.ocean.coastal_water_chance then
            return {type = "ocean", color = {0.05, 0.25, 0.7}, walkable = false}
        else
            return {type = "ocean", color = {0.1, 0.3, 0.8}, walkable = false}
        end
    end

    -- Beach (coastal areas just above water)
    if height < biome_config.beach.threshold then
        return {type = "beach", color = biome_config.beach.color, walkable = biome_config.beach.walkable}
    end

    -- Desert (hot, dry areas)
    if temperature > biome_config.desert.temperature_threshold and humidity < biome_config.desert.humidity_threshold then
        return {type = "desert", color = biome_config.desert.color, walkable = biome_config.desert.walkable}
    end

    -- Grassland (moderate conditions)
    if temperature > biome_config.grassland.temperature_min and temperature < biome_config.grassland.temperature_max and humidity > biome_config.grassland.humidity_min then
        if height > biome_config.hills.height_threshold then
            return {type = "hills", color = biome_config.hills.color, walkable = biome_config.hills.walkable}
        else
            return {type = "grassland", color = biome_config.grassland.color, walkable = biome_config.grassland.walkable}
        end
    end

    -- Forest in temperate, humid areas
    if temperature > biome_config.forest.temperature_min and temperature < biome_config.forest.temperature_max and humidity > biome_config.forest.humidity_min then
        if height > biome_config.dark_forest.height_min then
            return {type = "dark_forest", color = biome_config.dark_forest.color, walkable = biome_config.dark_forest.walkable}
        else
            return {type = "forest", color = biome_config.forest.color, walkable = biome_config.forest.walkable}
        end
    end

    -- Mountains at high elevations
    if height > biome_config.mountain.height_threshold then
        if temperature < biome_config.snow_mountain.temperature_threshold then
            return {type = "snow_mountain", color = biome_config.snow_mountain.color, walkable = biome_config.snow_mountain.walkable}
        else
            return {type = "mountain", color = biome_config.mountain.color, walkable = biome_config.mountain.walkable}
        end
    end

    -- Tundra in cold areas
    if temperature < biome_config.tundra.temperature_threshold then
        return {type = "tundra", color = biome_config.tundra.color, walkable = biome_config.tundra.walkable}
    end

    -- Default to grassland
    return {type = "grassland", color = biome_config.grassland.color, walkable = biome_config.grassland.walkable}
end

-- Generate the complete world based on environmental factors
function biomes.generate_world(world_config)
    -- Generate environmental maps
    local heightMap = biomes.generate_height_map(world_config)
    local tempMap = biomes.generate_temperature_map(world_config)
    local humidityMap = biomes.generate_humidity_map(world_config)

    -- Generate world based on environmental factors
    local gameWorld = {}
    local tilesX = math.ceil(world_config.world_size.width / constants.TILE_SIZE)
    local tilesY = math.ceil(world_config.world_size.height / constants.TILE_SIZE)

    for x = 1, tilesX do
        gameWorld[x] = {}
        for y = 1, tilesY do
            local height = heightMap[x][y]
            local temperature = tempMap[x][y]
            local humidity = humidityMap[x][y]

            gameWorld[x][y] = biomes.get_biome(height, temperature, humidity, x, y, world_config)
        end
    end

    return gameWorld, heightMap, tempMap, humidityMap
end

return biomes
