-- Game Constants
-- All configurable values for the Love2D RPG

local constants = {}

-- Display Configuration
constants.WINDOW_TITLE = "Love2D RPG"

-- Window mode settings
constants.DISPLAY_CONFIG = {
    -- Available window modes
    modes = {
        {name = "Windowed 1024x768", width = 1024, height = 768, fullscreen = false},
        {name = "Windowed 1280x720", width = 1280, height = 720, fullscreen = false},
        {name = "Windowed 1600x900", width = 1600, height = 900, fullscreen = false},
        {name = "Windowed 1920x1080", width = 1920, height = 1080, fullscreen = false},
        {name = "Fullscreen Desktop", width = 0, height = 0, fullscreen = true, fullscreentype = "desktop"},
        {name = "Fullscreen Exclusive", width = 0, height = 0, fullscreen = true, fullscreentype = "exclusive"}
    },
    current = 2, -- Default to 1280x720 windowed
    uiScale = 1.0 -- UI scaling factor
}

-- Dynamic window dimensions (set at runtime)
constants.GAME_WIDTH = 1280
constants.GAME_HEIGHT = 720

-- World settings (now pixel-based)
constants.WORLD_WIDTH = 1600  -- Total world width in pixels
constants.WORLD_HEIGHT = 1600 -- Total world height in pixels
constants.TILE_SIZE = 32      -- Size of visual tiles for rendering

-- Player settings
constants.PLAYER_SPEED = 100 -- Normal walking speed (pixels per second)
constants.PLAYER_SPRINT_SPEED = 200 -- 2x speed when sprinting (pixels per second)
constants.PLAYER_SIZE = 32  -- Perfect size for detailed hero model
constants.PLAYER_COLOR = {0.4, 1.0, 0.4} -- Brighter green player for better visibility
constants.PLAYER_MAX_STAMINA = 100
constants.STAMINA_DRAIN_RATE = 20 -- Stamina drained per second while sprinting
constants.STAMINA_RECOVERY_RATE = 15 -- Stamina recovered per second while walking

-- Camera settings
constants.CAMERA_FOLLOW_SPEED = 8.0  -- Increased for faster camera following

-- Movement settings
constants.MOVEMENT_ARRIVAL_THRESHOLD = 0.08
constants.MOVEMENT_DECELERATION_DISTANCE = 1.0
constants.MOVEMENT_DECELERATION_FACTOR = 0.7

-- World generation settings (increased randomness for more varied biomes)
constants.HEIGHT_MAP_SCALE = 0.08      -- Higher scale = more varied terrain
constants.HEIGHT_OCTAVES = 5          -- More octaves = more detail
constants.TEMPERATURE_NOISE_SCALE = 0.05 -- Higher scale = more temperature variation
constants.HUMIDITY_NOISE_SCALE = 0.06    -- Higher scale = more humidity variation
constants.TEMPERATURE_BASE_GRADIENT = 0.6 -- Less extreme north-south gradient
constants.TEMPERATURE_NOISE_AMPLITUDE = 0.4 -- More temperature variation

-- Biome settings (expanded for new biome types)
constants.DEEP_OCEAN_THRESHOLD = 0.25        -- Deep ocean level
constants.OCEAN_THRESHOLD = 0.35            -- Ocean level
constants.BEACH_THRESHOLD = 0.42            -- Beach/coastal level
constants.MOUNTAIN_HEIGHT_THRESHOLD = 0.75  -- Lower mountain threshold for more hills
constants.COLD_TEMPERATURE_THRESHOLD = 0.35 -- Warmer cold threshold
constants.HOT_TEMPERATURE_THRESHOLD = 0.65  -- Cooler hot threshold
constants.DRY_HUMIDITY_THRESHOLD = 0.45     -- Less extreme dry threshold
constants.WET_HUMIDITY_THRESHOLD = 0.55     -- Less extreme wet threshold
constants.HIGH_HEIGHT_THRESHOLD = 0.65      -- Higher threshold for elevated areas
constants.MODERATE_HEIGHT_THRESHOLD = 0.55  -- Higher threshold for moderate areas

-- Additional biome randomness settings
constants.BIOME_VARIATION_SCALE = 0.1       -- Extra noise for biome edges
constants.COASTAL_WATER_CHANCE = 0.15       -- Chance of coastal water tiles

-- Object spawn rates (balanced for better distribution)
constants.TREE_SPAWN_RATE = 0.12  -- 12% chance for trees in forests
constants.ROCK_SPAWN_RATE = 0.025 -- 2.5% chance for rocks in mountains (much rarer)
constants.FLOWER_SPAWN_RATE = 0.08 -- 8% chance for flowers in grasslands
constants.CACTUS_SPAWN_RATE = 0.06 -- 6% chance for cacti in deserts
constants.PALM_SPAWN_RATE = 0.08  -- 8% chance for palm trees on beaches
constants.CHICKEN_SPAWN_RATE = 0.01 -- 1% chance for chickens in grasslands (very rare)
constants.STICK_SPAWN_RATE = 0.08 -- 8% chance for sticks in grasslands
constants.PLAYER_ATTACK_COOLDOWN = 2.0 -- 2 second cooldown between player attacks
constants.INTERACTION_DISTANCE = 75 -- Interaction distance in pixels (about 2.5 tiles)

-- Object properties
constants.TREE_SIZE = 8
constants.TREE_COLOR = {0.2, 0.5, 0.2}
constants.ROCK_SIZE = 6
constants.ROCK_COLOR = {0.5, 0.5, 0.5}
constants.FLOWER_SIZE = 4
constants.CACTUS_SIZE = 6
constants.CACTUS_COLOR = {0.3, 0.6, 0.2}
constants.PALM_SIZE = 10
constants.PALM_COLOR = {0.4, 0.7, 0.1}

-- UI settings
constants.HEALTH_BAR_WIDTH = 200
constants.HEALTH_BAR_HEIGHT = 20

-- UI scaling - will be updated at runtime
constants.UI_SCALE = 1.0

-- Base UI dimensions (unscaled)
constants.BASE_HUD_BAR_WIDTH = 200
constants.BASE_HUD_BAR_HEIGHT = 20
constants.BASE_HUD_BAR_SPACING = 30
constants.BASE_HUD_START_Y = 20
constants.BASE_HUD_MARGIN_X = 10
constants.BASE_INVENTORY_HINT_Y_OFFSET = 25
constants.BASE_TOOLTIP_Y_OFFSET = 20
constants.BASE_HEALTH_BAR_Y_OFFSET = 32
constants.BASE_CHAT_BOTTOM_MARGIN = 10
constants.BASE_HOTBAR_BOTTOM_MARGIN = 60

-- Scaled UI values (updated at runtime)
constants.HUD_BAR_WIDTH = 200
constants.HUD_BAR_HEIGHT = 20
constants.HUD_BAR_SPACING = 30
constants.HUD_START_Y = 20
constants.HUD_MARGIN_X = 10
constants.INVENTORY_HINT_Y_OFFSET = 25
constants.TOOLTIP_Y_OFFSET = 20
constants.HEALTH_BAR_Y_OFFSET = 32
constants.CHAT_BOTTOM_MARGIN = 10
constants.HOTBAR_BOTTOM_MARGIN = 60

-- Function to update UI scaling
function constants.updateUIScale()
    -- Combine automatic scaling with manual scaling factor
    local autoScale = math.min(constants.GAME_WIDTH / 1280, constants.GAME_HEIGHT / 720)
    constants.UI_SCALE = autoScale * constants.DISPLAY_CONFIG.uiScale

    -- Update scaled HUD values
    constants.HUD_BAR_WIDTH = math.floor(constants.BASE_HUD_BAR_WIDTH * constants.UI_SCALE)
    constants.HUD_BAR_HEIGHT = math.floor(constants.BASE_HUD_BAR_HEIGHT * constants.UI_SCALE)
    constants.HUD_BAR_SPACING = math.floor(constants.BASE_HUD_BAR_SPACING * constants.UI_SCALE)
    constants.HUD_START_Y = math.floor(constants.BASE_HUD_START_Y * constants.UI_SCALE)
    constants.HUD_MARGIN_X = math.floor(constants.BASE_HUD_MARGIN_X * constants.UI_SCALE)
    constants.INVENTORY_HINT_Y_OFFSET = math.floor(constants.BASE_INVENTORY_HINT_Y_OFFSET * constants.UI_SCALE)
    constants.TOOLTIP_Y_OFFSET = math.floor(constants.BASE_TOOLTIP_Y_OFFSET * constants.UI_SCALE)
    constants.HEALTH_BAR_Y_OFFSET = math.floor(constants.BASE_HEALTH_BAR_Y_OFFSET * constants.UI_SCALE)
    constants.CHAT_BOTTOM_MARGIN = math.floor(constants.BASE_CHAT_BOTTOM_MARGIN * constants.UI_SCALE)
    constants.HOTBAR_BOTTOM_MARGIN = math.floor(constants.BASE_HOTBAR_BOTTOM_MARGIN * constants.UI_SCALE)

    -- Update scaled UI sizes
    constants.TOOLTIP_WIDTH = math.floor(250 * constants.UI_SCALE)
    constants.TOOLTIP_HEIGHT = math.floor(60 * constants.UI_SCALE)
    constants.CHAT_WIDTH = math.floor(400 * constants.UI_SCALE)
    constants.CHAT_HEIGHT = math.floor(150 * constants.UI_SCALE)
    constants.DIALOG_WIDTH = math.floor(300 * constants.UI_SCALE)
    constants.DIALOG_HEIGHT = math.floor(120 * constants.UI_SCALE)
    constants.INVENTORY_SLOT_SIZE = math.floor(40 * constants.UI_SCALE)
    constants.INVENTORY_SLOT_PADDING = math.floor(2 * constants.UI_SCALE)
    constants.INVENTORY_MARGIN = math.floor(10 * constants.UI_SCALE)
end

-- Graphics settings
constants.BACKGROUND_COLOR = {0.1, 0.1, 0.1}
constants.TILE_COLOR_BLEND_FACTOR = 0.95
constants.WATER_SHADING_FACTOR = 1.1
constants.WATER_TRANSPARENCY = 0.7

-- Spawn settings
constants.SPAWN_OFFSET_RANGE = 0.6
constants.SAFE_SPAWN_SEARCH_RADIUS_MAX = 25

return constants
