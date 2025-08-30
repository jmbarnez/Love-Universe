-- World Generator Module
-- Handles world generation using world configurations

local world_generator = {}
local biomes = require("src.world.biomes")
local ground_items = require("src.world.ground_items")
local constants = require("src.constants")

-- Generate scattered objects (chickens and ground items) based on world config
function world_generator.generate_objects(game_world, world_config)
    local objects = {}
    local chickens = {}
    local cows = {}
    local ground_items_list = {}

    -- Initialize empty objects, chickens, and cows tables (still use tile grid for storage)
    local tiles_x = math.ceil(world_config.world_size.width / constants.TILE_SIZE)
    local tiles_y = math.ceil(world_config.world_size.height / constants.TILE_SIZE)

    for x = 1, tiles_x do
        objects[x] = {}
        chickens[x] = {}
        cows[x] = {}
        for y = 1, tiles_y do
            objects[x][y] = nil
            chickens[x][y] = nil
            cows[x][y] = nil
        end
    end

    -- Generate enemies based on configuration
    for enemy_type, enemy_config in pairs(world_config.enemies or {}) do
        world_generator.spawn_enemies(enemy_type, enemy_config, game_world, chickens, cows, tiles_x, tiles_y)
    end

    -- Generate items based on configuration
    for item_type, item_config in pairs(world_config.items or {}) do
        world_generator.spawn_items(item_type, item_config, game_world, ground_items_list, tiles_x, tiles_y)
    end

    -- Generate world objects (trees, flowers, etc.) based on configuration
    world_generator.generate_world_objects(game_world, objects, world_config, tiles_x, tiles_y)



    return objects, chickens, cows, ground_items_list
end

-- Spawn enemies based on configuration
function world_generator.spawn_enemies(enemy_type, enemy_config, game_world, chickens, cows, tiles_x, tiles_y)
    local spawned_count = 0

    if enemy_type == "chicken" then
        -- Spawn initial number of chickens
        for i = 1, enemy_config.initial_spawn_count do
            local x, y = world_generator.find_random_spawn_location(game_world, enemy_config.biomes, tiles_x, tiles_y)
            if x and y then
                local tile_left = (x - 1) * constants.TILE_SIZE
                local tile_top = (y - 1) * constants.TILE_SIZE
                local pixel_x = tile_left + love.math.random(0, constants.TILE_SIZE - 1)
                local pixel_y = tile_top + love.math.random(0, constants.TILE_SIZE - 1)

                local enemy_module = require("src.enemies." .. enemy_type)
                chickens[x][y] = enemy_module.create(pixel_x, pixel_y)
                spawned_count = spawned_count + 1
            end
        end
    elseif enemy_type == "cow" then
        -- Spawn initial number of cows
        for i = 1, enemy_config.initial_spawn_count do
            local x, y = world_generator.find_random_spawn_location(game_world, enemy_config.biomes, tiles_x, tiles_y)
            if x and y then
                local tile_left = (x - 1) * constants.TILE_SIZE
                local tile_top = (y - 1) * constants.TILE_SIZE
                local pixel_x = tile_left + love.math.random(0, constants.TILE_SIZE - 1)
                local pixel_y = tile_top + love.math.random(0, constants.TILE_SIZE - 1)

                local enemy_module = require("src.enemies." .. enemy_type)
                cows[x][y] = enemy_module.create(pixel_x, pixel_y)
                spawned_count = spawned_count + 1
            end
        end
    end
end

-- Find a random spawn location for an entity
function world_generator.find_random_spawn_location(game_world, allowed_biomes, tiles_x, tiles_y)
    for i = 1, 100 do -- Try 100 times to find a valid location
        local x = love.math.random(1, tiles_x)
        local y = love.math.random(1, tiles_y)
        local tile = game_world[x][y]

        if world_generator.is_biome_allowed(tile.type, allowed_biomes) then
            return x, y
        end
    end
    return nil, nil
end

-- Spawn items based on configuration
function world_generator.spawn_items(item_type, item_config, game_world, ground_items_list, tiles_x, tiles_y)
    local spawned_count = 0

    for x = 1, tiles_x do
        for y = 1, tiles_y do
            local tile = game_world[x][y]
            if world_generator.is_biome_allowed(tile.type, item_config.biomes) and spawned_count < item_config.max_count then
                local spawn_chance = love.math.random()
                if spawn_chance < item_config.spawn_rate then
                    -- Spawn item at random pixel coordinates within this tile
                    local tile_left = (x - 1) * constants.TILE_SIZE
                    local tile_top = (y - 1) * constants.TILE_SIZE
                    local pixel_x = tile_left + love.math.random(0, constants.TILE_SIZE - 1)
                    local pixel_y = tile_top + love.math.random(0, constants.TILE_SIZE - 1)

                    -- Create item and add it as a permanent ground item with random rotation
                    local item_module = require("src.items." .. item_type)
                    local item = item_module.new()
                    ground_items.add_item(ground_items_list, item, pixel_x, pixel_y + 2, true) -- true = permanent
                    spawned_count = spawned_count + 1
                end
            end
        end
    end
end

-- Generate world objects (trees, flowers, etc.)
function world_generator.generate_world_objects(game_world, objects, world_config, tiles_x, tiles_y)
    for object_type, object_config in pairs(world_config.objects or {}) do
        local spawned_count = 0
        local max_objects = 100 -- Default max objects per type

        for x = 1, tiles_x do
            for y = 1, tiles_y do
                local tile = game_world[x][y]
                if world_generator.is_biome_allowed(tile.type, object_config.biomes) and spawned_count < max_objects then
                    local spawn_chance = love.math.random()
                    if spawn_chance < object_config.spawn_rate then
                        -- Create object at tile center
                        local pixel_x = (x - 1) * constants.TILE_SIZE + constants.TILE_SIZE / 2
                        local pixel_y = (y - 1) * constants.TILE_SIZE + constants.TILE_SIZE / 2

                        objects[x][y] = world_generator.create_world_object(object_type, pixel_x, pixel_y)
                        spawned_count = spawned_count + 1
                    end
                end
            end
        end
    end
end

-- Create a world object based on type
function world_generator.create_world_object(object_type, x, y)
    local object = {
        x = x,
        y = y,
        type = object_type
    }

    if object_type == "flower" then
        object.color = {0.8, 0.6, 0.8}
        object.size = love.math.random(8, 12)
    elseif object_type == "cactus" then
        object.color = {0.2, 0.6, 0.2}
        object.size = love.math.random(16, 24)
    elseif object_type == "palm" then
        object.color = {0.4, 0.7, 0.3}
        object.size = love.math.random(20, 28)
    end

    return object
end

-- Check if a biome is allowed for spawning
function world_generator.is_biome_allowed(biome_type, allowed_biomes)
    if not allowed_biomes then return true end

    for _, allowed_biome in ipairs(allowed_biomes) do
        if biome_type == allowed_biome then
            return true
        end
    end
    return false
end

-- Generate procedural world with realistic biomes using configuration
function world_generator.generate(world_config)
    -- Set a random seed for unique world generation each time (unless specified in config)
    local world_seed = world_config.seed or love.math.random(1, 1000000)
    love.math.setRandomSeed(world_seed)

    -- Generate world using biomes module
    local game_world, height_map, temp_map, humidity_map = biomes.generate_world(world_config)

    -- Generate scattered objects, enemies, and ground items
    local objects, chickens, cows, ground_items_list = world_generator.generate_objects(game_world, world_config)

    return game_world, objects, chickens, cows, ground_items_list, height_map, temp_map, humidity_map
end

return world_generator
