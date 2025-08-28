-- Player module for Love2D RPG
-- Handles player creation, movement, and player-specific logic

local player = {}
local constants = require("src.constants")

-- Create a new player
function player.create(worldX, worldY)
    local p = {
        -- Position in world coordinates (pixels)
        x = worldX,
        y = worldY,
        -- Movement
        speed = constants.PLAYER_SPEED,
        sprintSpeed = constants.PLAYER_SPRINT_SPEED,
        isSprinting = false,
        -- Appearance
        size = constants.PLAYER_SIZE,
        color = constants.PLAYER_COLOR,
        -- Stats
        health = 10,
        maxHealth = 10,
        mana = 100,
        maxMana = 100,
        stamina = constants.PLAYER_MAX_STAMINA,
        maxStamina = constants.PLAYER_MAX_STAMINA,
        level = 1,
        experience = 0,
        -- Entity info
        type = "player",
        name = "Player",
        inCombat = false,
        -- Effects
        flashTimer = nil
    }

    return p
end

-- Update player (includes flash effects and click-to-move)
function player.update(p, dt, isWalkable, isInWorld, movementTarget)
    local moveX, moveY = 0, 0

    -- Handle movement target (click-to-move only)
    if movementTarget then
        -- Calculate direction to movement target
        local dx = movementTarget.x - p.x
        local dy = movementTarget.y - p.y
        local distance = math.sqrt(dx * dx + dy * dy)

        -- Check if we've reached the target (within 10 pixels)
        if distance <= 10 then
            -- Clear movement target
            movementTarget.reached = true
            -- If this was an attack target, start combat
            if movementTarget.isAttackTarget then
                p.inCombat = true
            end
        else
            -- Move towards target
            moveX = dx / distance
            moveY = dy / distance
        end
    end

    -- Check for sprinting (Shift key)
    local isTryingToSprint = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    local canSprint = isTryingToSprint and p.stamina > 0

    -- Normalize diagonal movement
    if moveX ~= 0 or moveY ~= 0 then
        local length = math.sqrt(moveX * moveX + moveY * moveY)
        moveX = moveX / length
        moveY = moveY / length

        -- Determine current speed based on sprinting
        local currentSpeed = p.speed
        if canSprint then
            currentSpeed = p.sprintSpeed
            p.isSprinting = true
            -- Drain stamina while sprinting
            p.stamina = math.max(0, p.stamina - constants.STAMINA_DRAIN_RATE * dt)
        else
            p.isSprinting = false
            -- Recover stamina while walking/not sprinting
            if p.stamina < p.maxStamina then
                p.stamina = math.min(p.maxStamina, p.stamina + constants.STAMINA_RECOVERY_RATE * dt)
            end
        end

        -- Calculate new position
        local newX = p.x + moveX * currentSpeed * dt
        local newY = p.y + moveY * currentSpeed * dt

        -- Check if new position is walkable
        if isInWorld(newX, newY) and isWalkable(newX, newY) then
            p.x = newX
            p.y = newY
        end
        -- If not walkable, player stays in place (collision)
    else
        -- Not moving, recover stamina faster
        p.isSprinting = false
        if p.stamina < p.maxStamina then
            p.stamina = math.min(p.maxStamina, p.stamina + constants.STAMINA_RECOVERY_RATE * 1.5 * dt)
        end
    end

    -- Update flash effect
    if p.flashTimer then
        p.flashTimer = p.flashTimer - dt
        if p.flashTimer <= 0 then
            p.flashTimer = nil
        end
    end
end

-- Draw player
function player.draw(p, camera)
    -- World coordinates are already converted to screen by game's translate
    local screenX = p.x
    local screenY = p.y

    -- Player shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", screenX + 1, screenY + 1, p.size / 2)

    -- Calculate flash color multiplier
    local flashR, flashG, flashB = 1, 1, 1
    if p.flashTimer and p.flashTimer > 0 then
        flashR, flashG, flashB = 1.5, 1.5, 1.5 -- Bright white flash
    end

    -- Player body - changes color when sprinting or flashing
    local bodyR, bodyG, bodyB = p.color[1], p.color[2], p.color[3]
    if p.isSprinting then
        -- Sprinting color (lighter/different shade)
        bodyR, bodyG, bodyB = p.color[1] * 1.3, p.color[2] * 1.3, p.color[3] * 0.8
    end

    love.graphics.setColor(bodyR * flashR, bodyG * flashG, bodyB * flashB)
    love.graphics.circle("fill", screenX, screenY, p.size / 2)

    -- Player outline - also changes when sprinting or flashing
    local outlineR, outlineG, outlineB = 1, 1, 1
    if p.isSprinting then
        outlineR, outlineG, outlineB = 1, 0.8, 0 -- Orange outline when sprinting
    end

    love.graphics.setColor(outlineR * flashR, outlineG * flashG, outlineB * flashB)
    love.graphics.circle("line", screenX, screenY, p.size / 2)

    -- Draw combat UI (health bar and label) if in combat or damaged
    local entity_ui = require("src.entity_ui")
    entity_ui.drawCombatUI(p, screenX, screenY)
end

-- Respawn player
function player.respawn(p, spawnX, spawnY)
    p.x = spawnX
    p.y = spawnY
    p.health = p.maxHealth
    p.mana = p.maxMana
    p.stamina = p.maxStamina
    p.isSprinting = false
    p.flashTimer = nil
end

return player
