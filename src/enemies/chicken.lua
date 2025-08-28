-- Chicken module for Love2D RPG
-- Handles chicken entities, spawning, interaction, and combat

local chicken = {}
local constants = require("src.constants")
local combat = require("src.combat")
local lume = require("lib.lume")

-- Chicken properties
local CHICKEN_SIZE = 16 -- Small size for cute chickens
local CHICKEN_COLOR = {1.0, 1.0, 1.0} -- White color for cute chickens
local CHICKEN_OUTLINE_COLOR = {0.8, 0.8, 0.8} -- Light gray outline
local CHICKEN_HEALTH = 3 -- Reduced to 3 HP like RuneScape
local CHICKEN_ATTACK_DAMAGE = 1 -- Chicken deals 1 damage
local PLAYER_ATTACK_DAMAGE = 1 -- Player deals 1 damage per hit
local CHICKEN_ATTACK_COOLDOWN = 2.0 -- 2 second cooldown between chicken attacks
local CHICKEN_RETALIATION_DELAY = 1.0 -- 1 second delay before chicken retaliates

-- Create a new chicken at specified world coordinates
function chicken.create(worldX, worldY)
    local chick = {
        worldX = worldX,
        worldY = worldY,
        health = CHICKEN_HEALTH,
        maxHealth = CHICKEN_HEALTH,
        size = CHICKEN_SIZE,
        color = CHICKEN_COLOR,
        outlineColor = CHICKEN_OUTLINE_COLOR,
        alive = true,
        attackDamage = 1, -- Chicken deals 1 damage
        -- Entity info
        type = "chicken",
        name = "Chicken",
        level = 1,
        lootTable = {
            {item = "feather", min = 1, max = 2, chance = 1.0}
        }
    }

    -- Initialize combat state
    chick.combatState = combat.initCombatState(chick)

    return chick
end

-- Update chicken (combat AI and timers)
function chicken.update(chick, dt, currentTime, playerX, playerY, player, onDamage)
    if not chick.alive then return end

    -- Use the new combat system
    combat.update(chick, dt, currentTime, playerX, playerY, player, onDamage)

    if chick.health <= 0 and chick.alive then
        chicken.die(chick)
    end
end

-- Called when a chicken dies
function chicken.die(chick)
    chick.alive = false
    local world = require("src.world")
    local item_definitions = {
        feather = require("src.items.feather")
    }

    for _, drop in ipairs(chick.lootTable) do
        if love.math.random() <= drop.chance then
            local item_def = item_definitions[drop.item]
            if item_def then
                local num_items = love.math.random(drop.min, drop.max)
                if num_items > 0 then
                    local item_drop = item_def.new()
                    item_drop.count = num_items
                    world.addGroundItem(item_drop, chick.worldX, chick.worldY)
                end
            end
        end
    end
end

-- Draw a chicken
function chicken.draw(chick, camera, isInteractable, isTargeted, isHovered)
    if not chick.alive then return end

    -- Draw chicken at its world position (camera translation is handled by game.draw)
    local screenX = chick.worldX
    local screenY = chick.worldY

    local interaction_outline = require("src.interaction_outline")

    -- Draw interaction outline if this chicken is the target
    if isTargeted then
        interaction_outline.draw(chick, screenX, screenY, {1, 0, 0}) -- Red
    elseif isHovered then
        interaction_outline.draw(chick, screenX, screenY, {1, 1, 1}) -- White
    elseif isInteractable then
        interaction_outline.draw(chick, screenX, screenY)
    end

    -- Draw chicken body (oval shape)
    love.graphics.setColor(1, 1, 1) -- White body
    love.graphics.ellipse("fill", screenX, screenY, chick.size/2, chick.size/3)

    -- Draw chicken head
    love.graphics.setColor(1, 1, 1) -- White head
    love.graphics.circle("fill", screenX + chick.size/4, screenY - chick.size/4, chick.size/4)

    -- Draw beak
    love.graphics.setColor(1, 0.8, 0) -- Orange beak
    love.graphics.polygon("fill",
        screenX + chick.size/4 + chick.size/8, screenY - chick.size/4,
        screenX + chick.size/4 + chick.size/6, screenY - chick.size/4 - chick.size/12,
        screenX + chick.size/4 + chick.size/6, screenY - chick.size/4 + chick.size/12)

    -- Draw eye
    love.graphics.setColor(0, 0, 0) -- Black eye
    love.graphics.circle("fill", screenX + chick.size/4 + chick.size/12, screenY - chick.size/4 - chick.size/16, chick.size/16)

    -- Draw legs
    love.graphics.setColor(1, 0.8, 0) -- Orange legs
    love.graphics.rectangle("fill", screenX - chick.size/8, screenY + chick.size/3, 2, chick.size/4)
    love.graphics.rectangle("fill", screenX + chick.size/8 - 2, screenY + chick.size/3, 2, chick.size/4)

    -- UI now handled by tooltip system in HUD
    -- Removed entity UI elements above chicken heads

    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

-- Check if player is close enough to interact with chicken
function chicken.canInteract(playerX, playerY, chick)
    if not chick.alive then return false end

    local distance = lume.distance(playerX, playerY, chick.worldX, chick.worldY)
    return distance <= constants.INTERACTION_DISTANCE
end

-- Attack a chicken (damage it)
function chicken.attack(chick, player, currentTime, onDamage)
    if not chick.alive then return false end

    -- Use the new combat system for player attacks
    local died = combat.playerAttack(chick, player, currentTime, onDamage)
    
    -- If the chicken died, call the die function immediately
    if died and chick.alive then
        chicken.die(chick)
    end
    
    return died
end

-- Chicken attacks player (now handled by combat system)

-- Get all chickens (for external access)
function chicken.getChickens(chickens)
    return chickens
end

return chicken
