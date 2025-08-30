-- Game module for Love2D RPG
-- Handles main game state, camera, input, and game loop logic

local game = {}
local player = require("src.player")
local world = require("src.world")
local hud = require("src.hud")
local chicken = require("src.enemies.chicken")
local cow = require("src.enemies.cow")
local damage_effects = require("src.damage_effects")
local inventory = require("src.inventory")
local constants = require("src.constants")

local scroll = require("src.items.scroll")
local gem = require("src.items.gem")
local sword = require("src.items.sword")
local potion = require("src.items.potion")
local armor = require("src.items.armor")
local bow = require("src.items.bow")
local shield = require("src.items.shield")
local mana_potion = require("src.items.mana_potion")
local stick = require("src.items.stick")
local Camera = require("lib.hump.camera")
local Timer = require("lib.hump.timer")
local lume = require("lib.lume")
local suit = require("lib.suit")
local ui = require("src.ui")

-- Game state
local gameState = {
    player = nil,
    camera = nil, -- Will be initialized as hump.camera
    cameraZoom = 1.0, -- Camera zoom level (1.0 = normal, >1.0 = zoomed in, <1.0 = zoomed out)
    cameraZoomMin = 0.5, -- Minimum zoom level
    cameraZoomMax = 3.0, -- Maximum zoom level
    cameraZoomSpeed = 0.1, -- How much zoom changes per wheel click
    world = {},
    objects = {},
    chickens = {},
    cows = {},
    mouse = {
        worldX = 0,
        worldY = 0
    },
    -- Combat state
    lastPlayerAttackTime = 0,
    gameTime = 0,
    playerTarget = nil, -- Current target for combat (shows red outline)
    targetClearTime = 0, -- Time when target should be cleared after death
    -- Movement state
    movementTarget = nil, -- Target position for click-to-move
    -- Damage effects
    damageNumbers = {},
    -- Inventory
    inventory = nil,
    -- Respawn timers (initialized in updateEnemyRespawn)
    enemyRespawnTimers = nil
}

-- Initialize game
function game.init()
    -- Use nearest filtering to prevent sub-pixel rendering issues
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineStyle("rough")

    -- Disable any potential debug visuals that might show grids
    love.graphics.setWireframe(false)

    -- Generate the world
    local world_data, objects, chickens, cows, groundItems, height_map, temp_map, humidity_map = world.generate()
    gameState.world = world_data
    gameState.objects = objects
    gameState.chickens = chickens
    gameState.cows = cows
    gameState.groundItems = groundItems
    world.groundItems = gameState.groundItems

    -- Find a safe spawn location on land
    local spawnX, spawnY = world.findSafeSpawn(gameState.world)
    if not spawnX or not spawnY then
        -- Fallback to center if no safe spawn found
        spawnX = constants.WORLD_WIDTH / 2
        spawnY = constants.WORLD_HEIGHT / 2
    end

    gameState.player = player.create(spawnX, spawnY)

    -- Initialize hump camera centered on player
    gameState.camera = Camera()
    gameState.camera:lookAt(spawnX, spawnY)
    gameState.camera:zoomTo(gameState.cameraZoom) -- Apply initial zoom

    -- All enemies are now spawned through world configuration
    -- No hardcoded spawning needed

    -- Center camera on player
    game.centerCamera()

    -- Initialize inventory
    gameState.inventory = inventory.create()

    -- Initialize panel system
    local screenWidth = constants.GAME_WIDTH
    local screenHeight = constants.GAME_HEIGHT

    -- Create and register panels
    local equipmentPanel = inventory.EquipmentPanel.new(10, 100)
    local hotbarPanel = inventory.HotbarPanel.new((screenWidth - 10 * 45) / 2, screenHeight - 60)

    inventory.panelSystem.register("inventory", gameState.inventory)
    inventory.panelSystem.register("equipment", equipmentPanel)
    inventory.panelSystem.register("hotbar", hotbarPanel)

    -- Add some test items to inventory
    local feather = require("src.items.feather")
    inventory.addItem(gameState.inventory, feather.new())
    inventory.addItem(gameState.inventory, stick.new())  -- Add a stick to inventory
    inventory.addItem(gameState.inventory, stick.new())  -- Add another stick to test stacking
    inventory.addItem(gameState.inventory, sword.createSword())
    inventory.addItem(gameState.inventory, potion.createPotion())
    inventory.addItem(gameState.inventory, potion.createPotion())  -- Add another potion to test stacking
    inventory.addItem(gameState.inventory, armor.createArmor())

    -- Add new items to showcase the icon system
    inventory.addItem(gameState.inventory, bow.createBow())
    inventory.addItem(gameState.inventory, shield.createShield())
    inventory.addItem(gameState.inventory, mana_potion.createManaPotion())
    inventory.addItem(gameState.inventory, scroll.createSpellScroll())
    inventory.addItem(gameState.inventory, gem.createGem())

    -- Add some items to equipment panel
    equipmentPanel:addItem(sword.createSword())  -- Weapon slot (1)
    equipmentPanel:addItem(armor.createArmor())  -- Armor slot (2)
    equipmentPanel:addItem(shield.createShield()) -- Shield slot (4)

    -- Add some items to hotbar
    hotbarPanel:addItem(stick.new())  -- Add a stick to hotbar
    hotbarPanel:addItem(potion.createPotion())
    hotbarPanel:addItem(mana_potion.createManaPotion())
    hotbarPanel:addItem(scroll.createSpellScroll())

    -- Initialize UI system
    ui.init()
    
    -- Update inventory constants for scaling
    if inventory.panelSystem and inventory.panelSystem.updateLayout then
        inventory.panelSystem.updateLayout()
    end
    
    -- Add startup messages to chat
    ui.addChatMessage("Welcome to Love2D RPG!", {0, 1, 0}) -- Green
    ui.addChatMessage("TAB: Inventory | C: Equipment | 1-0: Hotbar", {0.7, 0.7, 1}) -- Light blue
    ui.addChatMessage("F1: Console | Drag items between panels!", {0.7, 0.7, 1}) -- Light blue
    ui.addChatMessage("F10: Change resolution | F11: Toggle fullscreen", {0.7, 0.7, 1}) -- Light blue
    ui.addChatMessage("+/-: UI Scale | Current: " .. game.getCurrentDisplayMode().name, {1, 0.8, 0}) -- Gold

end

-- Update game state
function game.update(dt)
    -- Update game time
    gameState.gameTime = gameState.gameTime + dt

    -- Update mouse world position
    local mouseX, mouseY = love.mouse.getPosition()
    gameState.mouse.worldX, gameState.mouse.worldY = gameState.camera:worldCoords(mouseX, mouseY)

    -- Update player movement
    if gameState.player then
        -- Determine the appropriate range based on movement target type
        local range = constants.INTERACTION_DISTANCE
        if gameState.movementTarget and gameState.movementTarget.isAttackTarget then
            range = constants.ATTACK_RANGE
        end
        
        player.update(gameState.player, dt,
            function(x, y) return world.isWalkable(x, y, gameState.world) end,
            world.isInWorld,
            gameState.movementTarget,
            range, game)

        -- Clear movement target if reached
        if gameState.movementTarget and gameState.movementTarget.reached then
            gameState.movementTarget = nil
        end
    end

    -- Update chickens
    game.updateChickens(dt)
    
    -- Update cows
    game.updateCows(dt)

    -- Update damage numbers
    game.updateDamageNumbers(dt)

    -- Update player flash effect
    damage_effects.updateFlash(gameState.player, dt)

    -- Update camera to follow player with smooth tracking
    game.updateCamera(dt)

    
    -- Update UI system
    ui.update(dt)

    -- Update inventory system
    if gameState.inventory then
        inventory.update(dt)
    end

    -- Update ground items (remove expired ones)
    world.updateGroundItems(gameState.groundItems, dt)
    
    
    -- Update ground item hover state for tooltips
    world.updateGroundItemHover(dt, gameState.mouse.worldX, gameState.mouse.worldY, gameState.groundItems)
    

    -- Update chicken respawn timer
    game.updateEnemyRespawn(dt)
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
                              gameState.player.x, gameState.player.y, gameState.player, game.addDamageNumber, gameState.groundItems)
                -- Update flash effect
                damage_effects.updateFlash(chick, dt)
                
                -- Clean up dead chickens and update game state
                if not chick.alive then
                    gameState.chickens[x][y] = nil
                    -- If this was the player's target, clear it
                    if gameState.playerTarget and gameState.playerTarget.entity == chick then
                        gameState.playerTarget = nil
                        gameState.player.inCombat = false
                    end
                end
            end
        end
    end
end

function game.updateCows(dt)
    -- Calculate tile dimensions for iterating over cow grid
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    for x = 1, tilesX do
        for y = 1, tilesY do
            if gameState.cows[x] and gameState.cows[x][y] then
                local c = gameState.cows[x][y]
                cow.update(c, dt, gameState.gameTime,
                          gameState.player.x, gameState.player.y, gameState.player, game.addDamageNumber, gameState.groundItems)
                -- Update flash effect
                damage_effects.updateFlash(c, dt)
                
                -- Clean up dead cows and update game state
                if not c.alive then
                    gameState.cows[x][y] = nil
                    -- If this was the player's target, clear it
                    if gameState.playerTarget and gameState.playerTarget.entity == c then
                        gameState.playerTarget = nil
                        gameState.player.inCombat = false
                    end
                end
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
        -- Smooth camera movement using lume.lerp for interpolation
        local currentX, currentY = gameState.camera:position()
        local targetX = gameState.player.x
        local targetY = gameState.player.y

        local newX = lume.lerp(currentX, targetX, constants.CAMERA_FOLLOW_SPEED * dt)
        local newY = lume.lerp(currentY, targetY, constants.CAMERA_FOLLOW_SPEED * dt)

        -- Clamp camera to world bounds to prevent rendering outside world
        -- Only clamp if the world is larger than the viewport, otherwise center the world
        if constants.WORLD_WIDTH > constants.GAME_WIDTH then
            newX = lume.clamp(newX, constants.GAME_WIDTH / 2, constants.WORLD_WIDTH - constants.GAME_WIDTH / 2)
        else
            newX = constants.WORLD_WIDTH / 2  -- Center camera in smaller world
        end
        
        if constants.WORLD_HEIGHT > constants.GAME_HEIGHT then
            newY = lume.clamp(newY, constants.GAME_HEIGHT / 2, constants.WORLD_HEIGHT - constants.GAME_HEIGHT / 2)
        else
            newY = constants.WORLD_HEIGHT / 2  -- Center camera in smaller world
        end

        gameState.camera:lookAt(newX, newY)
    end
end

-- Center camera on player
function game.centerCamera()
    if gameState.player then
        gameState.camera:lookAt(gameState.player.x, gameState.player.y)
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
    -- No cooldown check needed - turn system handles timing

    local playerX = gameState.player.x
    local playerY = gameState.player.y

    -- Calculate tile dimensions for iterating over chicken grid
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    -- Find the closest enemy (chicken or cow) within interaction range
    local closestEntity = nil
    local closestDistance = math.huge
    local closestTileX, closestTileY = nil, nil
    local closestEntityType = nil

    -- Search for closest enemies within interaction range
    local searchRadius = 3 -- tiles to search around player
    local playerTileX = math.floor(playerX / constants.TILE_SIZE) + 1
    local playerTileY = math.floor(playerY / constants.TILE_SIZE) + 1

    for x = math.max(1, playerTileX - searchRadius), math.min(tilesX, playerTileX + searchRadius) do
        for y = math.max(1, playerTileY - searchRadius), math.min(tilesY, playerTileY + searchRadius) do
            -- Check chickens
            if gameState.chickens[x] and gameState.chickens[x][y] and gameState.chickens[x][y].alive then
                local chick = gameState.chickens[x][y]
                local distance = lume.distance(chick.worldX, chick.worldY, playerX, playerY)
                if distance <= constants.INTERACTION_DISTANCE and distance < closestDistance then
                    closestDistance = distance
                    closestEntity = chick
                    closestTileX, closestTileY = x, y
                    closestEntityType = "chicken"
                end
            end
            
            -- Check cows
            if gameState.cows[x] and gameState.cows[x][y] and gameState.cows[x][y].alive then
                local c = gameState.cows[x][y]
                local distance = lume.distance(c.worldX, c.worldY, playerX, playerY)
                if distance <= constants.INTERACTION_DISTANCE and distance < closestDistance then
                    closestDistance = distance
                    closestEntity = c
                    closestTileX, closestTileY = x, y
                    closestEntityType = "cow"
                end
            end
        end
    end

    -- Handle closest entity (if any)
    if closestEntity then
        local distance = lume.distance(closestEntity.worldX, closestEntity.worldY, playerX, playerY)
        
        -- Set player target for auto-attacking
        gameState.playerTarget = {
            entity = closestEntity,
            tileX = closestTileX,
            tileY = closestTileY,
            entityType = closestEntityType
        }

        -- Check if within attack range
        if distance <= constants.ATTACK_RANGE then
            -- Close enough to start combat - let turn-based system handle attacks
            gameState.player.inCombat = true
            
            -- Start combat if not already started
            if closestEntity.combatState and not closestEntity.combatState.inCombat then
                closestEntity.combatState.inCombat = true
                closestEntity.combatState.combatTimer = 0
                -- Random turn order for initial combat start
                closestEntity.combatState.isPlayerTurn = love.math.random() < 0.5
            end
        else
            -- Too far to attack - move to within attack range
            local dx = closestEntity.worldX - playerX
            local dy = closestEntity.worldY - playerY
            local dist = math.sqrt(dx * dx + dy * dy)
            
            local targetX = closestEntity.worldX
            local targetY = closestEntity.worldY
            
            if dist > 0 then
                -- Move to attack range distance from the target
                local moveDistance = constants.ATTACK_RANGE - 15 -- 15 pixel buffer to ensure we're in range
                targetX = closestEntity.worldX - (dx / dist) * moveDistance
                targetY = closestEntity.worldY - (dy / dist) * moveDistance
            end
            
            gameState.movementTarget = {
                x = targetX,
                y = targetY,
                isAttackTarget = true,
                targetEntity = closestEntity
            }
        end
    end
end

-- Handle mouse input
function game.handleMousePress(x, y, button)
    -- Handle UI clicks first
    local uiConsumedClick = ui.mousepressed(x, y, button)
    if uiConsumedClick then
        return -- UI handled the click, don't process further
    end
    


    -- Check if click is on any inventory panel (blocks world interaction)
    local isOverInventory, panelId, panel = inventory.isMouseOverInventory(x, y)
    if isOverInventory then
        -- Handle inventory panel interactions
        if panel then
            -- For inventory panel, use the override method
            local slotIndex
            if panelId == "inventory" then
                slotIndex = inventory.slotAt(panel, x, y)
            elseif panel.slotAt then
                slotIndex = panel:slotAt(x, y)
            end

            if slotIndex and panel.items and panel.items[slotIndex] then
                local mods = {
                    lctrl = love.keyboard.isDown("lctrl"),
                    rctrl = love.keyboard.isDown("rctrl")
                }

                if button == 1 then
                    -- Start drag operation
                    local success = inventory.startDrag(panel, slotIndex, x, y, mods.lctrl or mods.rctrl, panelId)
                    if success then
                        return -- Block world interaction
                    end
                end
            end
        end
        return -- Block world interaction even if no item was clicked
    end

    if button == 1 then -- Left-click
        local worldX, worldY = gameState.camera:worldCoords(x, y)
        local clickedEntity, tileX, tileY, entityType = game.getEntityAtPosition(worldX, worldY)
        local clickedItem, itemIndex, pile = world.getGroundItemAtPosition(worldX, worldY, gameState.groundItems)

        if clickedEntity then
            local dx = clickedEntity.worldX - gameState.player.x
            local dy = clickedEntity.worldY - gameState.player.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- Set combat target immediately (for red outline)
            gameState.playerTarget = {
                entity = clickedEntity,
                tileX = tileX,
                tileY = tileY,
                entityType = entityType
            }
            gameState.player.inCombat = true
            
            -- Check if already in attack range
            if distance <= constants.ATTACK_RANGE then
                -- Already in range, start combat - turn system will handle attacks
                gameState.player.inCombat = true
                
                -- Start combat if not already started
                if clickedEntity.combatState and not clickedEntity.combatState.inCombat then
                    clickedEntity.combatState.inCombat = true
                    clickedEntity.combatState.combatTimer = 0
                    -- Random turn order for initial combat start
                    clickedEntity.combatState.isPlayerTurn = love.math.random() < 0.5
                end
                return -- Don't set movement target if already in range
            end
            
            -- Calculate position to move to that's within attack range
            local targetX = clickedEntity.worldX
            local targetY = clickedEntity.worldY

            if distance > 0 then
                -- Move to attack range distance from the target with larger buffer
                local moveDistance = constants.ATTACK_RANGE - 15 -- 15 pixel buffer to ensure we're well within range
                targetX = clickedEntity.worldX - (dx / distance) * moveDistance
                targetY = clickedEntity.worldY - (dy / distance) * moveDistance
            end

            -- Set movement target
            gameState.movementTarget = {
                x = targetX,
                y = targetY,
                isAttackTarget = true,
                targetEntity = clickedEntity
            }
            
            -- Set combat target immediately (for red outline)
            gameState.playerTarget = {
                entity = clickedEntity,
                tileX = tileX,
                tileY = tileY,
                entityType = entityType
            }
            
            -- Start combat immediately when targeting
            gameState.player.inCombat = true
        elseif clickedItem then
            -- Simple left-click pickup for single items
            player.pickupItem(gameState.player, gameState.groundItems, gameState.inventory, itemIndex)
        else
            -- Clicking on empty space - clear target and move
            gameState.playerTarget = nil
            gameState.player.inCombat = false
            game.cancelAllCombat()
            gameState.movementTarget = {x = worldX, y = worldY}
        end
    end
end

-- Handle mouse release
function game.handleMouseRelease(x, y, button)
    ui.mousereleased(x, y, button)

    -- Handle drag completion
    if button == 1 then
        inventory.finishDrag(x, y)
    end
end

-- Handle mouse movement
function game.handleMouseMove(x, y, dx, dy, istouch)
    -- Update mouse world position
    if gameState.camera then
        gameState.mouse.worldX, gameState.mouse.worldY = gameState.camera:worldCoords(x, y)
    end

    -- Update drag target if dragging
    local currentDragState = inventory.getDragState()
    if currentDragState and currentDragState.active then
        inventory.updateDragTarget(x, y)
    end
end

-- Handle mouse wheel for camera zoom
function game.handleMouseWheel(x, y)
    -- y > 0 means scroll up (zoom in), y < 0 means scroll down (zoom out)
    if y > 0 then
        gameState.cameraZoom = math.min(gameState.cameraZoomMax, gameState.cameraZoom + gameState.cameraZoomSpeed)
    elseif y < 0 then
        gameState.cameraZoom = math.max(gameState.cameraZoomMin, gameState.cameraZoom - gameState.cameraZoomSpeed)
    end

    -- Apply zoom to camera
    if gameState.camera then
        gameState.camera:zoomTo(gameState.cameraZoom)
    end
end

-- Handle text input
function game.handleTextInput(text)
    ui.textinput(text)
end

-- Handle keyboard input (WASD movement)
function game.handleKeyPress(key)
    ui.keypressed(key)

    -- Handle inventory keyboard shortcuts first (if inventory is visible)
    if gameState.inventory and gameState.inventory.visible then
        if inventory.handleKeyPress(gameState.inventory, key, gameState) then
            return -- Inventory handled the keypress
        end
    end

    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        -- Respawn player at safe location (only if inventory not handling 'r')
        local spawnX, spawnY = world.findSafeSpawn(gameState.world)
        player.respawn(gameState.player, spawnX, spawnY)
        game.centerCamera()
    elseif key == "e" then
        -- Try to attack nearby chickens (only if inventory not handling 'e')
        game.tryAttackChicken()
    elseif key == "tab" then
        -- Toggle inventory visibility
        inventory.toggle(gameState.inventory)
    elseif key == "c" then
        -- Toggle equipment panel visibility
        local equipmentPanel = inventory.panelSystem.getPanel("equipment")
        if equipmentPanel then
            equipmentPanel.visible = not equipmentPanel.visible
        end
    elseif key >= "1" and key <= "9" or key == "0" then
        -- Hotbar shortcuts (1-9, 0) - select item instead of using it
        local hotbarIndex = key == "0" and 10 or tonumber(key)
        local hotbarPanel = inventory.panelSystem.getPanel("hotbar")
        if hotbarPanel then
            local item = hotbarPanel.items[hotbarIndex]
            if item then
                -- Select this hotbar slot
                gameState.player.selectedHotbarSlot = hotbarIndex
                ui.addChatMessage("Selected: " .. (item.name or "Unknown Item"), {0.8, 0.8, 1})
            else
                -- Deselect if slot is empty
                gameState.player.selectedHotbarSlot = nil
                ui.addChatMessage("Deselected item", {0.7, 0.7, 0.7})
            end
        end
    elseif key == "space" then
        -- Use currently selected hotbar item
        if gameState.player.selectedHotbarSlot then
            local hotbarPanel = inventory.panelSystem.getPanel("hotbar")
            if hotbarPanel then
                local item = hotbarPanel.items[gameState.player.selectedHotbarSlot]
                if item and item.onUse then
                    item.onUse(gameState.player, item)
                    ui.addChatMessage("Used: " .. (item.name or "Unknown Item"), {0, 1, 0})
                else
                    ui.addChatMessage("Cannot use this item", {1, 0.5, 0.5})
                end
            end
        else
            ui.addChatMessage("No item selected", {0.7, 0.7, 0.7})
        end
    elseif key == "f11" then
        -- Toggle between windowed and fullscreen
        local currentMode = constants.DISPLAY_CONFIG.current
        local mode = constants.DISPLAY_CONFIG.modes[currentMode]
        if mode.fullscreen then
            game.setDisplayMode(2) -- Switch to windowed 1280x720
        else
            game.setDisplayMode(5) -- Switch to fullscreen desktop
        end
        ui.addChatMessage("Display mode: " .. game.getCurrentDisplayMode().name, {0, 1, 1})
    elseif key == "f10" then
        -- Cycle through display modes
        local nextMode = constants.DISPLAY_CONFIG.current + 1
        if nextMode > #constants.DISPLAY_CONFIG.modes then
            nextMode = 1
        end
        game.setDisplayMode(nextMode)
        ui.addChatMessage("Display mode: " .. game.getCurrentDisplayMode().name, {0, 1, 1})
    elseif key == "kp+" or key == "=" then
        -- Increase UI scale
        game.setUIScale(constants.DISPLAY_CONFIG.uiScale + 0.1)
        constants.updateUIScale()
        if ui and ui.updateLayout then
            ui.updateLayout()
        end
        ui.addChatMessage("UI Scale: " .. string.format("%.1f", constants.DISPLAY_CONFIG.uiScale), {1, 1, 0})
    elseif key == "kp-" or key == "-" then
        -- Decrease UI scale
        game.setUIScale(constants.DISPLAY_CONFIG.uiScale - 0.1)
        constants.updateUIScale()
        if ui and ui.updateLayout then
            ui.updateLayout()
        end
        ui.addChatMessage("UI Scale: " .. string.format("%.1f", constants.DISPLAY_CONFIG.uiScale), {1, 1, 0})
    end
end

-- Draw game world and UI
function game.draw()
    -- Draw world using hump camera
    gameState.camera:set()

    -- Draw tiles and objects
    world.drawTiles(gameState.world, gameState.camera, constants.GAME_WIDTH, constants.GAME_HEIGHT)
    world.drawObjects(gameState.objects, gameState.camera, constants.GAME_WIDTH, constants.GAME_HEIGHT)

    -- Draw ground items first (so they appear under everything else)
    world.drawGroundItems(gameState.groundItems, gameState.camera)

    -- Draw entities (chickens, NPCs, etc.)
    world.drawEntities(gameState.chickens, gameState.camera, constants.GAME_WIDTH, constants.GAME_HEIGHT, gameState.player.x, gameState.player.y, gameState.playerTarget, gameState.mouse.worldX, gameState.mouse.worldY)
    world.drawEntities(gameState.cows, gameState.camera, constants.GAME_WIDTH, constants.GAME_HEIGHT, gameState.player.x, gameState.player.y, gameState.playerTarget, gameState.mouse.worldX, gameState.mouse.worldY)

    -- Draw player
    if gameState.player then
        player.draw(gameState.player, gameState.camera)
    end

    -- Draw damage numbers
    game.drawDamageNumbers()

    -- Draw ground item interaction outlines (on top for visibility)
    local interactionOutline = require("src.interaction_outline")
    world.drawGroundItemOutlines(gameState.groundItems, gameState.mouse.worldX, gameState.mouse.worldY, interactionOutline)
    

    gameState.camera:unset()
    
    -- Draw ground item tooltips (after camera is unset, so they're in screen space)
    world.drawGroundItemTooltip(gameState.camera)


    -- Draw interaction prompts for chickens
    game.drawChickenInteractionPrompts()

    -- Draw UI
    love.graphics.setColor(1, 1, 1)

    -- Player HUD
    hud.draw(gameState.player, gameState)

    -- Draw all panels
    if inventory.panelSystem and inventory.panelSystem.panels then
        for panelId, panel in pairs(inventory.panelSystem.panels) do
        if panel then
            if panel.draw then
                panel:draw()
            else
                -- Fallback for inventory panel
                inventory.draw(panel)
            end
        end
    end
    end

    -- Draw inventory tooltip
    if gameState.inventory and gameState.inventory.visible then
        inventory.drawTooltip(gameState.inventory)
    end

    -- Draw drag ghost (must be drawn after panels to appear on top)
    inventory.drawDragGhost()


    
    -- Draw enhanced UI system
    ui.draw()


    
    -- Debug messages now handled by chat window
end



-- Check if the current target is within attack range
function game.isTargetInAttackRange(target)
    if not target or not target.entity then return false end
    if not target.entity.alive then return false end
    
    local playerX = gameState.player.x
    local playerY = gameState.player.y
    local distance = lume.distance(target.entity.worldX, target.entity.worldY, playerX, playerY)
    
    return distance <= constants.ATTACK_RANGE
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
                local distance = lume.distance(chick.worldX, chick.worldY, worldX, worldY)

                -- If click is within chicken's hitbox (size + some padding)
                if distance <= chick.size + 5 then
                    return chick, x, y
                end
            end
        end
    end

    return nil
end

function game.getEntityAtPosition(worldX, worldY)
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)

    -- Check tiles around the click position
    local checkRadius = 1 -- Check adjacent tiles too for better click detection
    local tileX = math.floor(worldX / constants.TILE_SIZE) + 1
    local tileY = math.floor(worldY / constants.TILE_SIZE) + 1

    for x = math.max(1, tileX - checkRadius), math.min(tilesX, tileX + checkRadius) do
        for y = math.max(1, tileY - checkRadius), math.min(tilesY, tileY + checkRadius) do
            -- Check chickens
            if gameState.chickens[x] and gameState.chickens[x][y] and gameState.chickens[x][y].alive then
                local chick = gameState.chickens[x][y]
                local distance = lume.distance(chick.worldX, chick.worldY, worldX, worldY)
                if distance <= chick.size + 5 then
                    return chick, x, y, "chicken"
                end
            end
            
            -- Check cows
            if gameState.cows[x] and gameState.cows[x][y] and gameState.cows[x][y].alive then
                local c = gameState.cows[x][y]
                local distance = lume.distance(c.worldX, c.worldY, worldX, worldY)
                if distance <= c.size + 5 then
                    return c, x, y, "cow"
                end
            end
        end
    end

    return nil
end


function game.startCombat(player)
    player.inCombat = true
end

-- Cancel all combat (called when player moves)
function game.cancelAllCombat()
    -- Clear player target
    gameState.playerTarget = nil
    
    -- End combat for all chickens and cows
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)
    local combat = require("src.combat")
    
    for x = 1, tilesX do
        for y = 1, tilesY do
            if gameState.chickens[x] and gameState.chickens[x][y] then
                local chick = gameState.chickens[x][y]
                if chick.combatState then
                    combat.endCombat(chick)
                end
            end
            
            if gameState.cows[x] and gameState.cows[x][y] then
                local c = gameState.cows[x][y]
                if c.combatState then
                    combat.endCombat(c)
                end
            end
        end
    end
end

-- Execute attack on a specific target entity
function game.executeAttackOnTarget(targetEntity)
    if not targetEntity or not targetEntity.alive then return end
    
    -- Find the target in our entities arrays
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)
    
    for x = 1, tilesX do
        for y = 1, tilesY do
            -- Check chickens
            if gameState.chickens[x] and gameState.chickens[x][y] == targetEntity then
                -- Set the target for auto-attacking system
                gameState.playerTarget = {
                    entity = targetEntity,
                    tileX = x,
                    tileY = y,
                    entityType = "chicken"
                }
                
                -- Execute attack if within attack range (turn system will handle timing)
                local playerX = gameState.player.x
                local playerY = gameState.player.y
                local distance = lume.distance(targetEntity.worldX, targetEntity.worldY, playerX, playerY)
                
                if distance <= constants.ATTACK_RANGE then
                    -- Start combat if not already started, but don't force turns
                    if targetEntity.combatState and not targetEntity.combatState.inCombat then
                        targetEntity.combatState.inCombat = true
                        targetEntity.combatState.combatTimer = 0
                        -- Random turn order for initial combat start
                        targetEntity.combatState.isPlayerTurn = love.math.random() < 0.5
                    end
                end
                return
            end
            
            -- Check cows
            if gameState.cows[x] and gameState.cows[x][y] == targetEntity then
                -- Set the target for auto-attacking system
                gameState.playerTarget = {
                    entity = targetEntity,
                    tileX = x,
                    tileY = y,
                    entityType = "cow"
                }
                
                -- Execute attack if within attack range (turn system will handle timing)
                local playerX = gameState.player.x
                local playerY = gameState.player.y
                local distance = lume.distance(targetEntity.worldX, targetEntity.worldY, playerX, playerY)
                
                if distance <= constants.ATTACK_RANGE then
                    -- Start combat if not already started, but don't force turns
                    if targetEntity.combatState and not targetEntity.combatState.inCombat then
                        targetEntity.combatState.inCombat = true
                        targetEntity.combatState.combatTimer = 0
                        -- Random turn order for initial combat start
                        targetEntity.combatState.isPlayerTurn = love.math.random() < 0.5
                    end
                end
                return
            end
        end
    end
end



-- Draw damage numbers
function game.drawDamageNumbers()
    for _, damageNum in ipairs(gameState.damageNumbers) do
        damage_effects.drawDamageNumber(damageNum, gameState.camera)
    end
end

-- Add message to chat console
function game.addMessage(text, color)
    ui.addChatMessage(text, color or {1, 1, 1}) -- Default white
end

-- Get game state (for external access)
function game.getState()
    return gameState
end

-- Set window properties
function game.setWindow()
    love.window.setTitle(constants.WINDOW_TITLE)
    
    -- Get current display mode
    local mode = constants.DISPLAY_CONFIG.modes[constants.DISPLAY_CONFIG.current]
    
    if mode.fullscreen then
        -- Fullscreen mode
        love.window.setMode(mode.width, mode.height, {
            fullscreen = true, 
            fullscreentype = mode.fullscreentype or "desktop"
        })
    else
        -- Windowed mode
        love.window.setMode(mode.width, mode.height, {
            fullscreen = false,
            resizable = true,
            minwidth = 800,
            minheight = 600
        })
    end

    -- Update constants with actual screen dimensions
    constants.GAME_WIDTH = love.graphics.getWidth()
    constants.GAME_HEIGHT = love.graphics.getHeight()
    
    -- Update UI scaling based on new dimensions
    constants.updateUIScale()

    -- Update UI layout to reposition elements for new screen size
    if ui and ui.updateLayout then
        ui.updateLayout()
    end

    love.graphics.setBackgroundColor(unpack(constants.BACKGROUND_COLOR))
end

-- Change display mode
function game.setDisplayMode(modeIndex)
    if modeIndex >= 1 and modeIndex <= #constants.DISPLAY_CONFIG.modes then
        constants.DISPLAY_CONFIG.current = modeIndex
        game.setWindow()
    end
end

-- Get current display mode info
function game.getCurrentDisplayMode()
    return constants.DISPLAY_CONFIG.modes[constants.DISPLAY_CONFIG.current]
end

-- Set UI scale
function game.setUIScale(scale)
    constants.DISPLAY_CONFIG.uiScale = math.max(0.5, math.min(3.0, scale))
end

-- Get UI scale
function game.getUIScale()
    return constants.DISPLAY_CONFIG.uiScale
end

-- Handle window resize
function game.onWindowResize(width, height)
    constants.GAME_WIDTH = width
    constants.GAME_HEIGHT = height
    constants.updateUIScale()
    
    -- Update UI layout after scaling changes
    if ui and ui.updateLayout then
        ui.updateLayout()
    end
end


-- Update enemy respawn timers based on world configuration
function game.updateEnemyRespawn(dt)
    local world_config = require("src.world.world_config").get_default()
    local world_generator = require("src.world.world_generator")
    
    -- Initialize respawn timers if not set
    if not gameState.enemyRespawnTimers then
        gameState.enemyRespawnTimers = {}
        for enemyType, config in pairs(world_config.enemies or {}) do
            gameState.enemyRespawnTimers[enemyType] = config.respawn_time
        end
    end
    
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)
    
    -- Process each enemy type
    for enemyType, config in pairs(world_config.enemies or {}) do
        -- Update respawn timer
        gameState.enemyRespawnTimers[enemyType] = gameState.enemyRespawnTimers[enemyType] - dt
        
        if gameState.enemyRespawnTimers[enemyType] <= 0 then
            -- Count current alive enemies of this type
            local currentCount = 0
            local entityArray = nil
            
            if enemyType == "chicken" then
                entityArray = gameState.chickens
            elseif enemyType == "cow" then
                entityArray = gameState.cows
            end
            
            if entityArray then
                for x = 1, tilesX do
                    for y = 1, tilesY do
                        if entityArray[x] and entityArray[x][y] and entityArray[x][y].alive then
                            currentCount = currentCount + 1
                        end
                    end
                end
                
                if currentCount < config.max_count then
                    -- Spawn a new enemy
                    local x, y = world_generator.find_random_spawn_location(gameState.world, config.biomes, tilesX, tilesY)
                    if x and y then
                        local tile_left = (x - 1) * constants.TILE_SIZE
                        local tile_top = (y - 1) * constants.TILE_SIZE
                        local pixel_x = tile_left + love.math.random(0, constants.TILE_SIZE - 1)
                        local pixel_y = tile_top + love.math.random(0, constants.TILE_SIZE - 1)

                        local enemy_module = require("src.enemies." .. enemyType)
                        entityArray[x][y] = enemy_module.create(pixel_x, pixel_y)
                    end
                end
            end
            
            -- Reset respawn timer
            gameState.enemyRespawnTimers[enemyType] = config.respawn_time
        end
    end
end




return game
