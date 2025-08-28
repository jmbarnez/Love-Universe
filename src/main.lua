-- Love2D Top-Down RPG
-- A RuneScape Classic/RPGMO inspired game

-- Set up package path to find modules in the src directory and subdirectories
-- Use a simple and reliable approach
package.path = package.path .. ";./src/?.lua;./src/enemies/?.lua;src/?.lua;src/enemies/?.lua"

-- Also try to add the full path if we can determine it
local source_dir = love.filesystem.getSource()
if source_dir then
    -- Remove main.lua from the path to get the directory
    local game_dir = source_dir:match("(.*/)[^/]*$") or source_dir:match("(.*/)[^/]*$")
    if game_dir then
        package.path = package.path .. ";" .. game_dir .. "src/?.lua"
    end
end


-- Try to load the game module
local success, game = pcall(require, "game")
if not success then

    -- Load all modules manually using love.filesystem
    local modules = {
        {name = "constants", path = "src/constants.lua"},
        {name = "player", path = "src/player.lua"},
        {name = "world", path = "src/world.lua"},
        {name = "hud", path = "src/hud.lua"},
        {name = "chicken", path = "src/enemies/chicken.lua"},
        {name = "damage_effects", path = "src/damage_effects.lua"},
        {name = "game", path = "src/game.lua"}
    }

    -- First, preload all modules into package.loaded to prevent require errors
    for _, module_info in ipairs(modules) do
        if not package.loaded[module_info.name] then
            if love.filesystem.getInfo(module_info.path) then
                local chunk, err = love.filesystem.load(module_info.path)
                if chunk then
                    local module = chunk()
                    package.loaded[module_info.name] = module
                    _G[module_info.name] = module
                end
            end
        end
    end

    -- Now try to load the game module again with all dependencies preloaded
    local chunk, err = love.filesystem.load("src/game.lua")
    if chunk then
        game = chunk()
        package.loaded.game = game
        _G.game = game
    end

    game = package.loaded.game or _G.game
end

if not game then
    error("Could not load game module!")
end

-- Love2D callbacks
function love.load()
    game.setWindow()
    game.init()
end

function love.update(dt)
    game.update(dt)
end

function love.draw()
    game.draw()
end

function love.keypressed(key)
    game.handleKeyPress(key)
end

function love.mousepressed(x, y, button)
    game.handleMousePress(x, y, button)
end
