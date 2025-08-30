-- Chicken module for Love2D RPG
-- Handles chicken entities, spawning, interaction, and combat

local chicken = {}
local constants = require("src.constants")
local combat = require("src.combat")
local lume = require("lib.lume")

-- Chicken properties
local CHICKEN_SIZE = 8 -- Half size for proper scaling with larger player
local CHICKEN_COLOR = {1.0, 1.0, 1.0} -- White color for cute chickens
local CHICKEN_OUTLINE_COLOR = {0.8, 0.8, 0.8} -- Light gray outline
local CHICKEN_HEALTH = 3 -- Reduced to 3 HP like RuneScape

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
        -- Entity info
        type = "chicken",
        name = "Chicken",
        level = 1,
        lootTable = {
            {item = "feather", min = 1, max = 2, chance = 1.0},
            {item = "chicken_skull", min = 1, max = 1, chance = 1.0} -- Guaranteed drop
        }
    }

    -- Initialize combat state
    chick.combatState = combat.initCombatState(chick)

    -- Create a simple icon for the chicken (white oval with details)
    chick.icon = chicken.createIcon()

    return chick
end

-- Create a simple icon for the chicken
function chicken.createIcon()
    local iconSize = 32
    local canvas = love.graphics.newCanvas(iconSize, iconSize)

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0) -- Transparent background

    -- Draw chicken body (oval shape)
    love.graphics.setColor(1, 1, 1) -- White body
    love.graphics.ellipse("fill", iconSize/2, iconSize/2 + 2, 8, 6)

    -- Draw chicken head
    love.graphics.setColor(1, 1, 1) -- White head
    love.graphics.circle("fill", iconSize/2 + 4, iconSize/2 - 2, 4)

    -- Draw beak
    love.graphics.setColor(1, 0.8, 0) -- Orange beak
    love.graphics.polygon("fill",
        iconSize/2 + 4 + 2, iconSize/2 - 2,
        iconSize/2 + 4 + 3, iconSize/2 - 2 - 1,
        iconSize/2 + 4 + 3, iconSize/2 - 2 + 1)

    -- Draw eye
    love.graphics.setColor(0, 0, 0) -- Black eye
    love.graphics.circle("fill", iconSize/2 + 4 + 1, iconSize/2 - 2 - 0.5, 0.5)

    -- Draw legs
    love.graphics.setColor(1, 0.8, 0) -- Orange legs
    love.graphics.rectangle("fill", iconSize/2 - 2, iconSize/2 + 6, 1, 3)
    love.graphics.rectangle("fill", iconSize/2 + 2, iconSize/2 + 6, 1, 3)

    love.graphics.setCanvas() -- Reset to main canvas
    return canvas
end

-- Update chicken (turn-based combat)
function chicken.update(chick, dt, currentTime, playerX, playerY, player, onDamage, groundItems)
    if not chick.alive then return end

    -- Update combat state for turn-based combat
    combat.update(chick, dt, currentTime, playerX, playerY, player, onDamage)

    -- Check if chicken died
    if chick.health <= 0 and chick.alive then
        chicken.die(chick, groundItems)
    end
end

-- Called when a chicken dies
function chicken.die(chick, groundItems)
    chick.alive = false
    local world = require("src.world")
    local item_definitions = {
        feather = require("src.items.feather"),
        chicken_skull = require("src.items.chicken_skull")
    }

    -- Collect all items to drop first
    local itemsToDrop = {}
    for _, drop in ipairs(chick.lootTable) do
        if love.math.random() <= drop.chance then
            local item_def = item_definitions[drop.item]
            if item_def then
                local num_items = love.math.random(drop.min, drop.max)
                if num_items > 0 then
                    local item_drop = item_def.new()
                    item_drop.count = num_items
                    table.insert(itemsToDrop, item_drop)
                end
            end
        end
    end
    
    -- Drop items in scattered positions around the death location
    for i, item_drop in ipairs(itemsToDrop) do
        local scatterRadius = 20 -- pixels to scatter items around death location
        local angle = (i - 1) * (math.pi * 2 / #itemsToDrop) -- Evenly distribute around circle
        local distance = love.math.random(5, scatterRadius) -- Random distance within radius
        
        local offsetX = math.cos(angle) * distance
        local offsetY = math.sin(angle) * distance
        
        local dropX = chick.worldX + offsetX
        local dropY = chick.worldY + offsetY
        
        world.addGroundItem(groundItems, item_drop, dropX, dropY, false) -- false = temporary
    end
end



-- Check if player is close enough to interact with chicken
function chicken.canInteract(playerX, playerY, chick)
    if not chick.alive then return false end

    local distance = lume.distance(playerX, playerY, chick.worldX, chick.worldY)
    return distance <= constants.INTERACTION_DISTANCE
end

-- Attack a chicken (damage it) - DEPRECATED: Only used for manual debugging
-- Normal combat should go through the turn-based combat.update system
function chicken.attack(chick, player, currentTime, onDamage, groundItems)
    if not chick.alive then return false end
    
    -- Check if player is within attack range
    local distance = lume.distance(chick.worldX, chick.worldY, player.x, player.y)
    if distance > constants.ATTACK_RANGE then
        return false -- Attack failed, player is too far away
    end

    -- This function should not be used for normal gameplay
    -- It bypasses the turn-based system
    print("WARNING: chicken.attack called - should use turn-based combat instead")
    
    -- Use the new combat system for player attacks
    local died = combat.playerAttack(chick, player, currentTime, onDamage)

    -- If the chicken died, call the die function immediately
    if died and chick.alive then
        chicken.die(chick, groundItems)
    end

    return died
end

-- Chicken attacks player (now handled by combat system)

-- Get all chickens (for external access)
function chicken.getChickens(chickens)
    return chickens
end

return chicken
