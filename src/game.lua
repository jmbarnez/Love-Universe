-- Game module for Love2D RPG
-- Handles main game state, camera, input, and game loop logic

local game = {}
local player = require("src.player")
local world = require("src.world")
local hud = require("src.hud")
local chicken = require("src.enemies.chicken")
local damage_effects = require("src.damage_effects")
local inventory = require("src.inventory")
local constants = require("src.constants")

-- Game state
local gameState = {
    player = nil,
    camera = {
        x = 0,
        y = 0,
        zoom = 1
    },
    world = {},
    objects = {},
    chickens = {},
    mouse = {
        worldX = 0,
        worldY = 0
    },
    -- Combat state
    lastPlayerAttackTime = 0,
    gameTime = 0,
    playerTarget = nil, -- Current target for auto-attacking
    targetClearTime = 0, -- Time when target should be cleared after death
    -- Movement state
    movementTarget = nil, -- Target position for click-to-move
    -- Damage effects
    damageNumbers = {},
    -- Inventory
    inventory = nil
}

-- Initialize game
function game.init()
    -- Enable smooth rendering to reduce grid appearance
    love.graphics.setDefaultFilter("linear", "linear")
    love.graphics.setLineStyle("smooth")

    -- Disable any potential debug visuals that might show grids
    love.graphics.setWireframe(false)

    -- Generate the world
    gameState.world, gameState.objects, gameState.chickens = world.generate()

    -- Find a safe spawn location on land
    local spawnX, spawnY = world.findSafeSpawn(gameState.world)
    if not spawnX or not spawnY then
        -- Fallback to center if no safe spawn found
        spawnX = constants.WORLD_WIDTH / 2
        spawnY = constants.WORLD_HEIGHT / 2
    end

    gameState.player = player.create(spawnX, spawnY)

    -- Count chickens and ensure max 3 limit
    local chickenCount = 0
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)
    for x = 1, tilesX do
        for y = 1, tilesY do
            if gameState.chickens[x] and gameState.chickens[x][y] then
                chickenCount = chickenCount + 1
            end
        end
    end

    -- Spawn a chicken at center for gameplay only if we have fewer than 3 chickens
    if chickenCount < 3 then
        local centerTileX = math.floor(constants.WORLD_WIDTH / constants.TILE_SIZE / 2)
        local centerTileY = math.floor(constants.WORLD_HEIGHT / constants.TILE_SIZE / 2)
        if not gameState.chickens[centerTileX] then gameState.chickens[centerTileX] = {} end
        local centerChicken = require("src.enemies.chicken").create(
            (centerTileX - 0.5) * constants.TILE_SIZE,
            (centerTileY - 0.5) * constants.TILE_SIZE
        )
        gameState.chickens[centerTileX][centerTileY] = centerChicken
    end

    -- Center camera on player
    game.centerCamera()

    -- Initialize inventory
    gameState.inventory = inventory.create()

    -- Add some test items to inventory
    inventory.addItem(gameState.inventory, {name = "Health Potion", color = {1, 0, 0}, count = 5})
    inventory.addItem(gameState.inventory, {name = "Mana Crystal", color = {0, 0.5, 1}, count = 3})
    inventory.addItem(gameState.inventory, {name = "Iron Sword", color = {0.8, 0.8, 0.8}, count = 1})
    inventory.addItem(gameState.inventory, {name = "Wood Shield", color = {0.6, 0.4, 0.2}, count = 1})
    inventory.addItem(gameState.inventory, {name = "Leather Boots", color = {0.4, 0.2, 0.1}, count = 1})
    inventory.addItem(gameState.inventory, {name = "Magic Ring", color = {1, 0.8, 0}, count = 1})

end

-- Update game state
function game.update(dt)
    -- Update game time
    gameState.gameTime = gameState.gameTime + dt

    -- Update mouse world position
    local mouseX, mouseY = love.mouse.getPosition()
    gameState.mouse.worldX, gameState.mouse.worldY = world.screenToWorld(mouseX, mouseY, gameState.camera)

    -- Update player movement
    if gameState.player then
        player.update(gameState.player, dt,
            function(x, y) return world.isWalkable(x, y, gameState.world) end,
            world.isInWorld,
            gameState.movementTarget)

        -- Clear movement target if reached
        if gameState.movementTarget and gameState.movementTarget.reached then
            gameState.movementTarget = nil
        end
    end

    -- Update chickens
    game.updateChickens(dt)

    -- Update damage numbers
    game.updateDamageNumbers(dt)

    -- Update player flash effect
    damage_effects.updateFlash(gameState.player, dt)

    -- Update camera to follow player with smooth tracking
    game.updateCamera(dt)

    -- Update combat timers
    game.updateCombatTimers(dt)

    -- Handle auto-attacking if player is in combat
    game.updateAutoAttack(dt)
end

-- Update chickens
function game.updateChickens(dt)
    -- Calculate tile dimensions for iterating over chicken grid
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    for x = 1, tilesX do
        for y = 1, tilesY do
            if gameState.chickens[x] and gameState.chickens[x][y] then
                local chick = gameState.chickens[x][y]
                chicken.update(chick, dt, gameState.gameTime,
                              gameState.player.x, gameState.player.y, gameState.player, game.addDamageNumber)
                -- Update flash effect
                damage_effects.updateFlash(chick, dt)
            end
        end
    end
end

-- Update damage numbers
function game.updateDamageNumbers(dt)
    local i = 1
    while i <= #gameState.damageNumbers do
        if damage_effects.updateDamageNumber(gameState.damageNumbers[i], dt) then
            i = i + 1
        else
            table.remove(gameState.damageNumbers, i)
        end
    end
end

-- Add damage number
function game.addDamageNumber(worldX, worldY, damage, color)
    local damageNum = damage_effects.createDamageNumber(worldX, worldY, damage, color)
    table.insert(gameState.damageNumbers, damageNum)
end

-- Update camera position
function game.updateCamera(dt)
    if gameState.player then
        local targetCamX = gameState.player.x - constants.GAME_WIDTH / 2
        local targetCamY = gameState.player.y - constants.GAME_HEIGHT / 2

        -- Smooth camera movement with momentum
        gameState.camera.x = gameState.camera.x + (targetCamX - gameState.camera.x) * constants.CAMERA_FOLLOW_SPEED * dt
        gameState.camera.y = gameState.camera.y + (targetCamY - gameState.camera.y) * constants.CAMERA_FOLLOW_SPEED * dt

        -- Clamp camera to world bounds
        gameState.camera.x = math.max(0, math.min(gameState.camera.x, constants.WORLD_WIDTH - constants.GAME_WIDTH))
        gameState.camera.y = math.max(0, math.min(gameState.camera.y, constants.WORLD_HEIGHT - constants.GAME_HEIGHT))
    end
end

-- Center camera on player
function game.centerCamera()
    if gameState.player then
        gameState.camera.x = gameState.player.x - constants.GAME_WIDTH / 2
        gameState.camera.y = gameState.player.y - constants.GAME_HEIGHT / 2

        -- Clamp camera to world bounds
        gameState.camera.x = math.max(0, math.min(gameState.camera.x, constants.WORLD_WIDTH - constants.GAME_WIDTH))
        gameState.camera.y = math.max(0, math.min(gameState.camera.y, constants.WORLD_HEIGHT - constants.GAME_HEIGHT))
    end
end

-- Check if player can attack (not on cooldown)
function game.canPlayerAttack()
    return gameState.gameTime - gameState.lastPlayerAttackTime >= constants.PLAYER_ATTACK_COOLDOWN
end

-- Draw interaction prompts for nearby chickens (removed to avoid clutter)
function game.drawChickenInteractionPrompts()
    -- Interaction prompts removed as requested - cooldown info is now only in HUD
end

-- Try to attack nearby chickens
function game.tryAttackChicken()
    -- Check if player can attack
    if not game.canPlayerAttack() then
        return -- Still on cooldown
    end

    local playerX = gameState.player.x
    local playerY = gameState.player.y

    -- Calculate tile dimensions for iterating over chicken grid
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    -- Find the closest chicken within interaction range
    local closestChicken = nil
    local closestDistance = math.huge
    local closestTileX, closestTileY = nil, nil

    -- Search for closest chicken within interaction range
    local searchRadius = 3 -- tiles to search around player
    local playerTileX = math.floor(playerX / constants.TILE_SIZE) + 1
    local playerTileY = math.floor(playerY / constants.TILE_SIZE) + 1

    for x = math.max(1, playerTileX - searchRadius), math.min(tilesX, playerTileX + searchRadius) do
        for y = math.max(1, playerTileY - searchRadius), math.min(tilesY, playerTileY + searchRadius) do
            if gameState.chickens[x] and gameState.chickens[x][y] and gameState.chickens[x][y].alive then
                local chick = gameState.chickens[x][y]
                local distance = math.sqrt((chick.worldX - playerX)^2 + (chick.worldY - playerY)^2)
                if distance <= 75 and distance < closestDistance then -- 75 is INTERACTION_DISTANCE
                    closestDistance = distance
                    closestChicken = chick
                    closestTileX, closestTileY = x, y
                end
            end
        end
    end

    -- Attack only the closest chicken (if any)
    if closestChicken then
        -- Set player target for auto-attacking
        gameState.playerTarget = {
            entity = closestChicken,
            tileX = closestTileX,
            tileY = closestTileY
        }

        -- Set player in combat (chicken will handle its own combat state)
        gameState.player.inCombat = true

        local died = chicken.attack(closestChicken, gameState.player, gameState.gameTime, game.addDamageNumber)
        if died then
            -- Remove dead chicken from the game
            gameState.chickens[closestTileX][closestTileY] = nil
            -- Set delay before clearing target so HP bar can show "DEAD"
            gameState.targetClearTime = gameState.gameTime + 2.0 -- Show dead status for 2 seconds
            gameState.player.inCombat = false
        end
        -- Set attack cooldown
        gameState.lastPlayerAttackTime = gameState.gameTime
    end
end

-- Handle mouse input
function game.handleMousePress(x, y, button)
    -- Handle inventory clicks first (if inventory is visible)
    if gameState.inventory.visible then
        inventory.handleClick(gameState.inventory, x, y, button)
        return -- Don't process other mouse events when inventory is open
    end

    if button == 2 then -- Right-click
        -- Convert screen coordinates to world coordinates
        local worldX, worldY = world.screenToWorld(x, y, gameState.camera)

        -- Check if right-click is on a chicken
        local clickedChicken = game.getChickenAtPosition(worldX, worldY)

        if clickedChicken then
            -- Right-clicked on a chicken - move to attack it
            game.moveToAttackChicken(clickedChicken)
        else
            -- Right-clicked on empty space - just move there
            gameState.movementTarget = {x = worldX, y = worldY}
        end
    end
end

-- Handle keyboard input (WASD movement)
function game.handleKeyPress(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        -- Respawn player at safe location
        local spawnX, spawnY = world.findSafeSpawn(gameState.world)
        player.respawn(gameState.player, spawnX, spawnY)
        game.centerCamera()
    elseif key == "e" then
        -- Try to attack nearby chickens
        game.tryAttackChicken()
    elseif key == "tab" then
        -- Toggle inventory visibility
        inventory.toggle(gameState.inventory)
    end
end

-- Draw game world and UI
function game.draw()
    -- Draw world
    love.graphics.push()
    love.graphics.translate(-gameState.camera.x, -gameState.camera.y)

    -- Draw tiles and objects
    world.drawTiles(gameState.world, gameState.camera, constants.GAME_WIDTH, constants.GAME_HEIGHT)
    world.drawObjects(gameState.objects, gameState.camera, constants.GAME_WIDTH, constants.GAME_HEIGHT)

    -- Draw chickens
    world.drawChickens(gameState.chickens, gameState.camera, constants.GAME_WIDTH, constants.GAME_HEIGHT, gameState.player.x, gameState.player.y)

    -- Draw player
    if gameState.player then
        player.draw(gameState.player, gameState.camera)
    end

    -- Draw damage numbers
    game.drawDamageNumbers()

    love.graphics.pop()


    -- Draw interaction prompts for chickens
    game.drawChickenInteractionPrompts()

    -- Draw UI
    love.graphics.setColor(1, 1, 1)

    -- Player HUD
    hud.draw(gameState.player, gameState)

    -- Draw inventory (if visible)
    inventory.draw(gameState.inventory)
end

-- Update combat timers and clear combat flags when appropriate
function game.updateCombatTimers(dt)
    -- Clear player combat flag after 5 seconds of no activity
    if gameState.player and gameState.player.inCombat then
        local timeSinceLastAttack = gameState.gameTime - gameState.lastPlayerAttackTime
        if timeSinceLastAttack > 5.0 then -- 5 seconds of no combat activity
            gameState.player.inCombat = false
        end
    end

    -- Clear chicken combat flags after 5 seconds of no activity
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    for x = 1, tilesX do
        for y = 1, tilesY do
            if gameState.chickens[x] and gameState.chickens[x][y] then
                local chick = gameState.chickens[x][y]
                local combat = require("src.combat")
                if combat.isInCombat(chick) then
                    local timeSinceLastChickenAttack = gameState.gameTime - chick.combatState.lastAttackTime
                    local timeSinceLastPlayerAttack = gameState.gameTime - chick.combatState.lastPlayerAttackTime

                    -- Clear combat if no activity for 5 seconds
                    if timeSinceLastChickenAttack > 5.0 and timeSinceLastPlayerAttack > 5.0 then
                        combat.endCombat(chick)
                    end
                end
            end
        end
    end
end

-- Handle automatic attacking during combat
function game.updateAutoAttack(dt)
    -- Only auto-attack if player is in combat
    if not gameState.player or not gameState.player.inCombat then
        gameState.playerTarget = nil
        return
    end

    -- Find the current target if we don't have one
    if not gameState.playerTarget then
        game.findPlayerTarget()
    end

    -- If we still don't have a target, stop combat
    if not gameState.playerTarget then
        gameState.player.inCombat = false
        return
    end

    -- Check if target is still valid (alive and in range)
    if not game.isTargetValid(gameState.playerTarget) then
        -- Check if we should clear the target due to death delay
        if gameState.targetClearTime > 0 and gameState.gameTime >= gameState.targetClearTime then
            gameState.playerTarget = nil
            gameState.targetClearTime = 0
        end

        if not gameState.playerTarget then
            game.findPlayerTarget()
            -- If no valid target found, stop combat
            if not gameState.playerTarget then
                gameState.player.inCombat = false
                return
            end
        end
    end

    -- Auto-attack if cooldown is ready
    if game.canPlayerAttack() then
        game.performAutoAttack()
    end
end

-- Find the best target for the player (closest chicken in range)
function game.findPlayerTarget()
    local playerX = gameState.player.x
    local playerY = gameState.player.y

    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    local closestChicken = nil
    local closestDistance = math.huge
    local closestTileX, closestTileY = nil, nil

    -- Search for closest chicken within interaction range
    local searchRadius = 3 -- tiles to search around player
    local playerTileX = math.floor(playerX / constants.TILE_SIZE) + 1
    local playerTileY = math.floor(playerY / constants.TILE_SIZE) + 1

    for x = math.max(1, playerTileX - searchRadius), math.min(tilesX, playerTileX + searchRadius) do
        for y = math.max(1, playerTileY - searchRadius), math.min(tilesY, playerTileY + searchRadius) do
            if gameState.chickens[x] and gameState.chickens[x][y] and gameState.chickens[x][y].alive then
                local chick = gameState.chickens[x][y]
                local distance = math.sqrt((chick.worldX - playerX)^2 + (chick.worldY - playerY)^2)
                if distance <= 75 and distance < closestDistance then -- 75 is INTERACTION_DISTANCE
                    closestDistance = distance
                    closestChicken = chick
                    closestTileX, closestTileY = x, y
                end
            end
        end
    end

    -- Set the target and tile coordinates for the target
    if closestChicken then
        gameState.playerTarget = {
            entity = closestChicken,
            tileX = closestTileX,
            tileY = closestTileY
        }
    end
end

-- Check if the current target is still valid
function game.isTargetValid(target)
    if not target or not target.entity then return false end

    -- Check if target is still alive
    if not target.entity.alive then return false end

    -- Check if target is still in range
    local playerX = gameState.player.x
    local playerY = gameState.player.y
    local distance = math.sqrt((target.entity.worldX - playerX)^2 + (target.entity.worldY - playerY)^2)

    return distance <= 75 -- INTERACTION_DISTANCE
end

-- Perform an automatic attack on the current target
function game.performAutoAttack()
    if not gameState.playerTarget or not gameState.playerTarget.entity then return end

    local target = gameState.playerTarget.entity
    local tileX = gameState.playerTarget.tileX
    local tileY = gameState.playerTarget.tileY

            -- Set player in combat (target will handle its own combat state)
        gameState.player.inCombat = true

    -- Perform the attack
    local died = chicken.attack(target, gameState.player, gameState.gameTime, game.addDamageNumber)
    if died then
        -- Remove dead chicken from the game
        gameState.chickens[tileX][tileY] = nil
        -- Set delay before clearing target so HP bar can show "DEAD"
        gameState.targetClearTime = gameState.gameTime + 2.0 -- Show dead status for 2 seconds
        gameState.player.inCombat = false
    end

    -- Set attack cooldown
    gameState.lastPlayerAttackTime = gameState.gameTime
end

-- Get chicken at specific world position
function game.getChickenAtPosition(worldX, worldY)
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    -- Check tiles around the click position
    local checkRadius = 1 -- Check adjacent tiles too for better click detection
    local tileX = math.floor(worldX / constants.TILE_SIZE) + 1
    local tileY = math.floor(worldY / constants.TILE_SIZE) + 1

    for x = math.max(1, tileX - checkRadius), math.min(tilesX, tileX + checkRadius) do
        for y = math.max(1, tileY - checkRadius), math.min(tilesY, tileY + checkRadius) do
            if gameState.chickens[x] and gameState.chickens[x][y] and gameState.chickens[x][y].alive then
                local chick = gameState.chickens[x][y]
                local distance = math.sqrt((chick.worldX - worldX)^2 + (chick.worldY - worldY)^2)

                -- If click is within chicken's hitbox (size + some padding)
                if distance <= chick.size + 5 then
                    return chick, x, y
                end
            end
        end
    end

    return nil
end

-- Move to attack a specific chicken
function game.moveToAttackChicken(chicken)
    -- Set movement target to chicken's position
    gameState.movementTarget = {
        x = chicken.worldX,
        y = chicken.worldY,
        isAttackTarget = true,
        targetEntity = chicken
    }

    -- Set player target for auto-attacking when in range
    gameState.playerTarget = {
        entity = chicken,
        tileX = math.floor(chicken.worldX / constants.TILE_SIZE) + 1,
        tileY = math.floor(chicken.worldY / constants.TILE_SIZE) + 1
    }
end



-- Draw damage numbers
function game.drawDamageNumbers()
    for _, damageNum in ipairs(gameState.damageNumbers) do
        damage_effects.drawDamageNumber(damageNum, gameState.camera)
    end
end

-- Get game state (for external access)
function game.getState()
    return gameState
end

-- Set window properties
function game.setWindow()
    love.window.setTitle(constants.WINDOW_TITLE)
    love.window.setMode(0, 0, {fullscreen = true, fullscreentype = "desktop"})

    -- Update constants with actual screen dimensions
    constants.GAME_WIDTH = love.graphics.getWidth()
    constants.GAME_HEIGHT = love.graphics.getHeight()

    love.graphics.setBackgroundColor(unpack(constants.BACKGROUND_COLOR))
end

return game
