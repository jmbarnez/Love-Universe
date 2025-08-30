-- Player module for Love2D RPG
-- Handles player creation, movement, and player-specific logic

local player = {}
local constants = require("src.constants")
local pathfinding = require("src.pathfinding")

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
        flashTimer = nil,
        -- Equipment/items
        selectedHotbarSlot = nil  -- Which hotbar slot is currently selected (1-10)
    }

    return p
end

-- Update player (includes flash effects and click-to-move)
function player.update(p, dt, isWalkable, isInWorld, movementTarget, attackRange, game)
    local moveX, moveY = 0, 0

    -- Handle movement target (click-to-move only)
    if movementTarget then
        -- If it's an attack target, update the target's position to the entity's current position
        if movementTarget.isAttackTarget and movementTarget.targetEntity then
            movementTarget.x = movementTarget.targetEntity.worldX
            movementTarget.y = movementTarget.targetEntity.worldY
        end

        -- Calculate direction to movement target
        local dx = movementTarget.x - p.x
        local dy = movementTarget.y - p.y
        local distance = math.sqrt(dx * dx + dy * dy)

        local stopDistance = 10
        if movementTarget.isAttackTarget then
            local constants = require("src.constants")
            stopDistance = constants.ATTACK_RANGE - 15 -- Stop 15 pixels before max range to ensure we're in range
        end

        -- Check if we've reached the target
        if distance <= stopDistance then
            -- Clear movement target
            movementTarget.reached = true
            -- If this was an attack target, start combat and attack immediately
            if movementTarget.isAttackTarget then
                if game then
                    game.startCombat(p)
                    -- Trigger immediate attack when reaching target
                    game.executeAttackOnTarget(movementTarget.targetEntity)
                end
                print("Player reached enemy and attacking!")
            end
        else
            -- Use pathfinding for better navigation around obstacles
            moveX, moveY = pathfinding.getNextDirection(p.x, p.y, movementTarget.x, movementTarget.y, isWalkable, isInWorld)
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

-- Pick up single item
function player.pickupItem(p, groundItems, inventory, itemIndex)
    local item_to_pick_up = groundItems[itemIndex]
    if not item_to_pick_up then return end

    local inventory_module = require("src.inventory")
    local ui = require("src.ui")
    
    if inventory_module.addItem(inventory, item_to_pick_up.item) then
        table.remove(groundItems, itemIndex)
        
        -- Show pickup message
        local itemName = item_to_pick_up.item.name or "Unknown Item"
        local quantityText = (item_to_pick_up.item.count and item_to_pick_up.item.count > 1) and (" x" .. item_to_pick_up.item.count) or ""
        ui.addChatMessage("Picked up " .. itemName .. quantityText, {0, 1, 0})
    else
        ui.addChatMessage("Cannot pick up item - inventory full", {1, 0.5, 0.5})
    end
end

-- Draw player
function player.draw(p, camera)
    -- World coordinates are already converted to screen by game's translate
    local screenX = p.x
    local screenY = p.y
    
    -- Calculate flash color multiplier
    local flashR, flashG, flashB = 1, 1, 1
    if p.flashTimer and p.flashTimer > 0 then
        flashR, flashG, flashB = 1.5, 1.5, 1.5 -- Bright white flash
    end
    
    -- Player body color - changes when sprinting or flashing
    local bodyR, bodyG, bodyB = p.color[1], p.color[2], p.color[3]
    if p.isSprinting then
        -- Sprinting color (lighter/different shade)
        bodyR, bodyG, bodyB = p.color[1] * 1.3, p.color[2] * 1.3, p.color[3] * 0.8
    end
    
    local finalR = bodyR * flashR
    local finalG = bodyG * flashG  
    local finalB = bodyB * flashB
    
    -- Draw basic hero model
    player.drawHeroModel(screenX, screenY, finalR, finalG, finalB, p)
    
    -- Draw combat UI (health bar and label) if in combat or damaged
    local entity_ui = require("src.entity_ui")
    entity_ui.drawCombatUI(p, screenX, screenY)
end

function player.drawHeroModel(x, y, r, g, b, p)
    -- Scale factor based on player size (default was 20, now we scale based on actual size)
    local scale = p.size / 20  -- Scale relative to original size of 20
    
    -- Define colors
    local skinColor = {0.9, 0.7, 0.6}
    local armorColor = {r, g, b}
    local shortsColor = {0.2, 0.4, 0.8}  -- Blue shorts
    local outlineColor = {0.3, 0.3, 0.3}

    -- Draw legs (behind body, scaled) - blue shorts
    love.graphics.setColor(shortsColor)
    love.graphics.rectangle("fill", x - 3 * scale, y + 6 * scale, 2.5 * scale, 8 * scale)  -- Left leg
    love.graphics.rectangle("fill", x + 0.5 * scale, y + 6 * scale, 2.5 * scale, 8 * scale)  -- Right leg
    
    -- Draw body/torso (scaled) - now skin color to show only shorts
    love.graphics.setColor(skinColor)
    love.graphics.rectangle("fill", x - 4 * scale, y - 2 * scale, 8 * scale, 10 * scale)
    
    -- Draw arms (scaled)
    love.graphics.setColor(skinColor)
    love.graphics.rectangle("fill", x - 6 * scale, y - 1 * scale, 2 * scale, 6 * scale)  -- Left arm
    love.graphics.rectangle("fill", x + 4 * scale, y - 1 * scale, 2 * scale, 6 * scale)  -- Right arm
    
    -- Draw head (scaled)
    love.graphics.setColor(skinColor)
    love.graphics.circle("fill", x, y - 6 * scale, 3 * scale)
    
    -- Draw simple face (scaled)
    love.graphics.setColor(0, 0, 0)
    love.graphics.circle("fill", x - 1 * scale, y - 6.5 * scale, 0.5 * scale)  -- Left eye
    love.graphics.circle("fill", x + 1 * scale, y - 6.5 * scale, 0.5 * scale)  -- Right eye
    
    -- Draw held item if any
    if p.selectedHotbarSlot then
        local hotbarPanel = require("src.inventory").panelSystem.getPanel("hotbar")
        if hotbarPanel and hotbarPanel.items[p.selectedHotbarSlot] then
            local heldItem = hotbarPanel.items[p.selectedHotbarSlot]
            player.drawHeldItem(x, y, heldItem, scale)
        end
    end
    
    -- Draw outlines for definition (scaled)
    love.graphics.setColor(outlineColor)
    love.graphics.setLineWidth(math.max(1, scale * 0.5))  -- Scale line width too
    
    -- Body outline
    love.graphics.rectangle("line", x - 4 * scale, y - 2 * scale, 8 * scale, 10 * scale)
    -- Head outline  
    love.graphics.circle("line", x, y - 6 * scale, 3 * scale)
    -- Arm outlines
    love.graphics.rectangle("line", x - 6 * scale, y - 1 * scale, 2 * scale, 6 * scale)
    love.graphics.rectangle("line", x + 4 * scale, y - 1 * scale, 2 * scale, 6 * scale)
    -- Leg outlines
    love.graphics.rectangle("line", x - 3 * scale, y + 6 * scale, 2.5 * scale, 8 * scale)
    love.graphics.rectangle("line", x + 0.5 * scale, y + 6 * scale, 2.5 * scale, 8 * scale)
    
    -- Reset line width
    love.graphics.setLineWidth(1)
end

function player.drawHeldItem(x, y, item, scale)
    if not item or not item.icon then
        return
    end

    scale = scale or 1  -- Default scale if not provided

    -- Draw item icon in right hand (scaled) - bigger and closer to hand
    love.graphics.setColor(1, 1, 1)
    local itemSize = 12 * scale  -- Increased from 8 to 12 for bigger items
    local handX = x + 3 * scale  -- Moved closer (from 5 to 3) for better hand positioning
    local handY = y + 1 * scale

    love.graphics.draw(item.icon, handX, handY, 0, itemSize/32, itemSize/32)
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
