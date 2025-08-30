-- Cow module for Love2D RPG
-- Handles cow entities, spawning, interaction, and combat

local cow = {}
local constants = require("src.constants")
local combat = require("src.combat")
local lume = require("lib.lume")

-- Cow properties
local COW_SIZE = 40 -- Bigger than player (32)
local COW_COLOR = {0.9, 0.9, 0.9} -- Light gray/white color
local COW_OUTLINE_COLOR = {0.6, 0.6, 0.6} -- Gray outline
local COW_HEALTH = 8 -- More health than chicken

-- Create a new cow at specified world coordinates
function cow.create(worldX, worldY)
    local c = {
        worldX = worldX,
        worldY = worldY,
        health = COW_HEALTH,
        maxHealth = COW_HEALTH,
        size = COW_SIZE,
        color = COW_COLOR,
        outlineColor = COW_OUTLINE_COLOR,
        alive = true,
        -- Entity info
        type = "cow",
        name = "Cow",
        level = 2,
        lootTable = {
            {item = "bone", min = 1, max = 1, chance = 1.0},     -- Guaranteed bone
            {item = "cowhide", min = 1, max = 1, chance = 1.0}  -- Guaranteed cowhide
        }
    }

    -- Initialize combat state
    c.combatState = combat.initCombatState(c)

    -- Create a simple icon for the cow
    c.icon = cow.createIcon()

    return c
end

-- Create a simple icon for the cow
function cow.createIcon()
    local iconSize = 32
    local canvas = love.graphics.newCanvas(iconSize, iconSize)

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0) -- Transparent background

    -- Draw cow body (larger oval shape)
    love.graphics.setColor(0.9, 0.9, 0.9) -- Light gray body
    love.graphics.ellipse("fill", iconSize/2, iconSize/2 + 1, 10, 8)

    -- Draw cow head
    love.graphics.setColor(0.9, 0.9, 0.9) -- Light gray head
    love.graphics.ellipse("fill", iconSize/2 - 6, iconSize/2 - 2, 6, 5)

    -- Draw spots
    love.graphics.setColor(0.3, 0.3, 0.3) -- Dark gray spots
    love.graphics.ellipse("fill", iconSize/2 + 2, iconSize/2 - 1, 2, 1.5)
    love.graphics.ellipse("fill", iconSize/2 - 1, iconSize/2 + 2, 2.5, 2)

    -- Draw eyes
    love.graphics.setColor(0, 0, 0) -- Black eyes
    love.graphics.circle("fill", iconSize/2 - 6, iconSize/2 - 3, 0.5)
    love.graphics.circle("fill", iconSize/2 - 4, iconSize/2 - 3, 0.5)

    -- Draw horns
    love.graphics.setColor(0.7, 0.6, 0.4) -- Brown horns
    love.graphics.polygon("fill",
        iconSize/2 - 7, iconSize/2 - 5,
        iconSize/2 - 8, iconSize/2 - 7,
        iconSize/2 - 6.5, iconSize/2 - 6)
    love.graphics.polygon("fill",
        iconSize/2 - 3, iconSize/2 - 5,
        iconSize/2 - 2, iconSize/2 - 7,
        iconSize/2 - 3.5, iconSize/2 - 6)

    -- Draw legs
    love.graphics.setColor(0.9, 0.9, 0.9) -- Light gray legs
    love.graphics.rectangle("fill", iconSize/2 - 4, iconSize/2 + 6, 1.5, 4)
    love.graphics.rectangle("fill", iconSize/2 - 1, iconSize/2 + 6, 1.5, 4)
    love.graphics.rectangle("fill", iconSize/2 + 2, iconSize/2 + 6, 1.5, 4)
    love.graphics.rectangle("fill", iconSize/2 + 5, iconSize/2 + 6, 1.5, 4)

    love.graphics.setCanvas() -- Reset to main canvas
    return canvas
end

-- Update cow (turn-based combat)
function cow.update(c, dt, currentTime, playerX, playerY, player, onDamage, groundItems)
    if not c.alive then return end

    -- Update combat state for turn-based combat
    combat.update(c, dt, currentTime, playerX, playerY, player, onDamage)

    -- Check if cow died
    if c.health <= 0 and c.alive then
        cow.die(c, groundItems)
    end
end

-- Called when a cow dies
function cow.die(c, groundItems)
    c.alive = false
    local world = require("src.world")
    local item_definitions = {
        bone = require("src.items.bone"),
        cowhide = require("src.items.cowhide")
    }

    -- Collect all items to drop first
    local itemsToDrop = {}
    for _, drop in ipairs(c.lootTable) do
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
        local scatterRadius = 25 -- pixels to scatter items around death location
        local angle = (i - 1) * (math.pi * 2 / #itemsToDrop) -- Evenly distribute around circle
        local distance = love.math.random(5, scatterRadius) -- Random distance within radius
        
        local offsetX = math.cos(angle) * distance
        local offsetY = math.sin(angle) * distance
        
        local dropX = c.worldX + offsetX
        local dropY = c.worldY + offsetY
        
        world.addGroundItem(groundItems, item_drop, dropX, dropY, false) -- false = temporary
    end
end

-- Check if player is close enough to interact with cow
function cow.canInteract(playerX, playerY, c)
    if not c.alive then return false end

    local distance = lume.distance(playerX, playerY, c.worldX, c.worldY)
    return distance <= constants.INTERACTION_DISTANCE
end

-- Attack a cow (damage it) - DEPRECATED: Only used for manual debugging
-- Normal combat should go through the turn-based combat.update system
function cow.attack(c, player, currentTime, onDamage, groundItems)
    if not c.alive then return false end
    
    -- Check if player is within attack range
    local distance = lume.distance(c.worldX, c.worldY, player.x, player.y)
    if distance > constants.ATTACK_RANGE then
        return false -- Attack failed, player is too far away
    end

    -- This function should not be used for normal gameplay
    -- It bypasses the turn-based system
    print("WARNING: cow.attack called - should use turn-based combat instead")

    -- Use the new combat system for player attacks
    local died = combat.playerAttack(c, player, currentTime, onDamage)

    -- If the cow died, call the die function immediately
    if died and c.alive then
        cow.die(c, groundItems)
    end

    return died
end

-- Get all cows (for external access)
function cow.getCows(cows)
    return cows
end

return cow