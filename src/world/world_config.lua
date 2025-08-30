-- World Configuration Module
-- Defines world generation settings, enemy spawn rates, item drops, etc.

local world_config = {}

-- Default world configuration
world_config.default = {
    name = "Default World",
    description = "A balanced world with grasslands, forests, and varied biomes",

    -- World generation settings
    seed = nil, -- nil = random seed
    world_size = {
        width = 1600, -- pixels (must match constants.lua)
        height = 1600  -- pixels (must match constants.lua)
    },

    -- Biome generation parameters
    biome_settings = {
        height_map_scale = 0.02,
        height_octaves = 4,
        temperature_base_gradient = 0.7, -- North-south temperature gradient
        temperature_noise_scale = 0.03,
        temperature_noise_amplitude = 0.3,
        humidity_noise_scale = 0.025,
        biome_variation_scale = 0.05
    },

    -- Enemy spawn configuration
    enemies = {
        chicken = {
            spawn_rate = 0.01,      -- 1% chance per suitable tile
            initial_spawn_count = 3, -- Number of chickens to spawn initially
            max_count = 3,          -- Maximum chickens in world
            respawn_time = 60,      -- Time in seconds to respawn a chicken
            biomes = {"grassland", "hills"} -- Biomes where chickens can spawn
        },
        cow = {
            spawn_rate = 0.008,     -- 0.8% chance per suitable tile (slightly rarer)
            initial_spawn_count = 2, -- Number of cows to spawn initially
            max_count = 3,          -- Maximum cows in world
            respawn_time = 120,     -- Time in seconds to respawn a cow (longer than chickens)
            biomes = {"grassland", "hills", "forest"} -- Biomes where cows can spawn
        }
    },

    -- Item spawn configuration
    items = {
        stick = {
            spawn_rate = 0.005,     -- 0.5% chance per suitable tile (much lower)
            max_count = 8,          -- Maximum 8 sticks in world (just a few)
            biomes = {"grassland", "hills", "forest", "dark_forest"} -- Biomes where sticks can spawn
        }
    },

    -- Biome thresholds and colors
    biomes = {
        -- Water biomes
        deep_ocean = {
            threshold = 0.0, -- height < this value
            color = {0.05, 0.15, 0.4},
            walkable = false
        },
        ocean = {
            threshold = 0.1, -- height < this value
            color = {0.05, 0.25, 0.7},
            walkable = false,
            coastal_water_chance = 0.3 -- Chance for coastal variation
        },

        -- Coastal biomes
        beach = {
            threshold = 0.25, -- height < this value
            color = {0.95, 0.9, 0.7},
            walkable = true
        },

        -- Desert biomes
        desert = {
            temperature_threshold = 0.7, -- temperature > this
            humidity_threshold = 0.3,     -- humidity < this
            color = {0.9, 0.8, 0.6},
            walkable = true
        },

        -- Temperate biomes
        grassland = {
            temperature_min = 0.4,
            temperature_max = 0.9,
            humidity_min = 0.3,
            color = {0.25, 0.6, 0.2},
            walkable = true
        },
        hills = {
            temperature_min = 0.4,
            temperature_max = 0.9,
            humidity_min = 0.3,
            height_threshold = 0.6, -- height > this for hills
            color = {0.3, 0.5, 0.2},
            walkable = true
        },

        -- Forest biomes
        forest = {
            temperature_min = 0.3,
            temperature_max = 0.7,
            humidity_min = 0.5,
            height_max = 0.7,
            color = {0.15, 0.4, 0.15},
            walkable = true
        },
        dark_forest = {
            temperature_min = 0.3,
            temperature_max = 0.7,
            humidity_min = 0.5,
            height_min = 0.7,
            color = {0.1, 0.25, 0.1},
            walkable = true
        },

        -- Mountain biomes
        mountain = {
            height_threshold = 0.75,
            color = {0.4, 0.4, 0.4},
            walkable = true
        },
        snow_mountain = {
            height_threshold = 0.75,
            temperature_threshold = 0.3, -- temperature < this for snow
            color = {0.9, 0.9, 0.95},
            walkable = true
        },

        -- Cold biomes
        tundra = {
            temperature_threshold = 0.3, -- temperature < this
            color = {0.6, 0.7, 0.5},
            walkable = true
        }
    },

    -- World objects (trees, rocks, etc.)
    objects = {
        flower = {
            spawn_rate = 0.08,
            biomes = {"grassland", "hills", "forest"}
        },
        cactus = {
            spawn_rate = 0.06,
            biomes = {"desert"}
        },
        palm = {
            spawn_rate = 0.08,
            biomes = {"beach"}
        }
    }
}

-- Alternative world configurations can be added here
world_config.desert_world = {
    name = "Desert World",
    description = "A hot, arid world with vast deserts and few resources",

    -- Override default settings for desert world
    biome_settings = {
        temperature_base_gradient = 0.3, -- Hotter overall
        temperature_noise_amplitude = 0.2,
        humidity_noise_scale = 0.02, -- Less humidity variation
    },

    enemies = {
        chicken = {
            spawn_rate = 0.005, -- Fewer chickens
            max_count = 2,
            biomes = {"grassland"} -- Only in rare grassland oases
        }
    },

    items = {
        stick = {
            spawn_rate = 0.03, -- Fewer sticks
            max_count = 20,
            biomes = {"grassland", "hills"}
        }
    }
}

-- Get a world configuration by name
function world_config.get(name)
    return world_config[name] or world_config.default
end

-- Get the default world configuration
function world_config.get_default()
    return world_config.default
end

return world_config
