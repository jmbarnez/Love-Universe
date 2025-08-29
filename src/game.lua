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

local scroll = require("src.items.scroll")
local gem = require("src.items.gem")
local sword = require("src.items.sword")
local potion = require("src.items.potion")
local armor = require("src.items.armor")
local bow = require("src.items.bow")
local shield = require("src.items.shield")
local mana_potion = require("src.items.mana_potion")
local Camera = require("lib.hump.camera")
local Timer = require("lib.hump.timer")
local lume = require("lib.lume")
local suit = require("lib.suit")
local ui = require("src.ui")

-- Game state
local gameState = {
    player = nil,
    camera = nil, -- Will be initialized as hump.camera
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
    -- Set up UI handlers to avoid circular dependencies
    ui.handleGroundItemSelectionMenuClick = game.handleGroundItemSelectionMenuClick
    -- Use nearest filtering to prevent sub-pixel rendering issues
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineStyle("rough")

    -- Disable any potential debug visuals that might show grids
    love.graphics.setWireframe(false)

    -- Generate the world
    gameState.world, gameState.objects, gameState.chickens, gameState.groundItems = world.generate()
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
        player.update(gameState.player, dt,
            function(x, y) return world.isWalkable(x, y, gameState.world) end,
            world.isInWorld,
            gameState.movementTarget,
            constants.INTERACTION_DISTANCE, game)

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
    
    -- Update UI system
    ui.update(dt)

    -- Update inventory system
    if gameState.inventory then
        inventory.update(dt)
    end

    -- Update ground items (remove expired ones)
    world.updateGroundItems(dt)
    
    
    -- Update ground item hover state for tooltips
    world.updateGroundItemHover(dt, gameState.mouse.worldX, gameState.mouse.worldY, gameState.groundItems)
    
    -- Update ground item selection menu
    game.updateGroundItemSelectionMenu(dt)
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
                local distance = lume.distance(chick.worldX, chick.worldY, playerX, playerY)
                if distance <= constants.INTERACTION_DISTANCE and distance < closestDistance then -- 75 is INTERACTION_DISTANCE
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
        local clickedChicken, _, _ = game.getChickenAtPosition(worldX, worldY)
        local clickedItem, itemIndex, pile = world.getGroundItemAtPosition(worldX, worldY, gameState.groundItems)

        if clickedChicken then
            gameState.movementTarget = {
                x = clickedChicken.worldX,
                y = clickedChicken.worldY,
                isAttackTarget = true,
                targetEntity = clickedChicken
            }
            gameState.playerTarget = {
                entity = clickedChicken,
                tileX = math.floor(clickedChicken.worldX / constants.TILE_SIZE) + 1,
                tileY = math.floor(clickedChicken.worldY / constants.TILE_SIZE) + 1
            }
        elseif clickedItem then
            player.pickupItemPile(gameState.player, gameState.groundItems, gameState.inventory, pile or {{item = clickedItem, index = itemIndex}})
        else
            gameState.movementTarget = {x = worldX, y = worldY}
        end
    elseif button == 2 then -- Right-click
        local worldX, worldY = gameState.camera:worldCoords(x, y)
        local clickedItem, itemIndex, pile = world.getGroundItemAtPosition(worldX, worldY, gameState.groundItems)
        
        if clickedItem and pile and #pile.items > 1 then
            -- Multiple items stacked - show selection menu
            game.showGroundItemSelectionMenu(pile, x, y)
        elseif clickedItem then
            -- Single item - also show context menu (right-click should never pickup directly)
            game.showGroundItemSelectionMenu(pile or {items = {{item = clickedItem, index = itemIndex}}}, x, y)
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

    -- Draw chickens
    world.drawChickens(gameState.chickens, gameState.camera, constants.GAME_WIDTH, constants.GAME_HEIGHT, gameState.player.x, gameState.player.y, gameState.playerTarget, gameState.mouse.worldX, gameState.mouse.worldY)

    -- Draw player
    if gameState.player then
        player.draw(gameState.player, gameState.camera)
    end

    -- Draw damage numbers
    game.drawDamageNumbers()

    -- Draw ground items
    world.drawGroundItems(gameState.groundItems, gameState.camera)
    
    
    -- Draw ground item interaction outlines
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
    
    -- Draw ground item selection menu (after UI)
    game.drawGroundItemSelectionMenu()
    
    -- Debug messages now handled by chat window
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

    -- Debug: print("Updating auto attack...")  -- Commented out to reduce spam

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
            -- If a new target is found, and we can attack, attack immediately
            if game.canPlayerAttack() then
                game.performAutoAttack()
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
                local distance = lume.distance(chick.worldX, chick.worldY, playerX, playerY)
                if distance <= constants.INTERACTION_DISTANCE and distance < closestDistance then -- 75 is INTERACTION_DISTANCE
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
    local distance = lume.distance(target.entity.worldX, target.entity.worldY, playerX, playerY)

    return distance <= constants.INTERACTION_DISTANCE -- INTERACTION_DISTANCE
end

-- Perform an automatic attack on the current target
function game.performAutoAttack()
    if not gameState.playerTarget or not gameState.playerTarget.entity then return end

    local target = gameState.playerTarget.entity
    local tileX = gameState.playerTarget.tileX
    local tileY = gameState.playerTarget.tileY

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

function game.startCombat(player)
    player.inCombat = true
end

-- Execute attack on a specific target entity
function game.executeAttackOnTarget(targetEntity)
    if not targetEntity or not targetEntity.alive then return end
    
    -- Find the target in our chickens array
    local tilesX = math.ceil(constants.WORLD_WIDTH / constants.TILE_SIZE)
    local tilesY = math.ceil(constants.WORLD_HEIGHT / constants.TILE_SIZE)
    
    for x = 1, tilesX do
        for y = 1, tilesY do
            if gameState.chickens[x] and gameState.chickens[x][y] == targetEntity then
                -- Set the target for auto-attacking system
                gameState.playerTarget = {
                    entity = targetEntity,
                    tileX = x,
                    tileY = y
                }
                
                -- Execute immediate attack if off cooldown
                if game.canPlayerAttack() then
                    local died = chicken.attack(targetEntity, gameState.player, gameState.gameTime, game.addDamageNumber)
                    if died then
                        gameState.chickens[x][y] = nil
                        gameState.targetClearTime = gameState.gameTime + 2.0
                        gameState.player.inCombat = false
                    end
                    gameState.lastPlayerAttackTime = gameState.gameTime
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

-- Ground item selection system
local groundItemSelectionMenu = nil

function game.showGroundItemSelectionMenu(pile, screenX, screenY)
    if not pile or not pile.items or #pile.items < 1 then
        return
    end
    
    groundItemSelectionMenu = {
        pile = pile,
        screenX = screenX,
        screenY = screenY,
        createdTime = love.timer.getTime()
    }
end

function game.updateGroundItemSelectionMenu(dt)
    if groundItemSelectionMenu then
        -- Auto-close menu after 5 seconds
        if love.timer.getTime() - groundItemSelectionMenu.createdTime > 5.0 then
            groundItemSelectionMenu = nil
        end
    end
end

function game.drawGroundItemSelectionMenu()
    if not groundItemSelectionMenu then
        return
    end
    
    local menu = groundItemSelectionMenu
    local itemHeight = 25
    local menuWidth = 250  -- Increased width to accommodate "Pickup [item name]" text
    local menuHeight = #menu.pile.items * itemHeight + 10
    
    -- Position menu near mouse but keep on screen
    local menuX = menu.screenX + 10
    local menuY = menu.screenY - menuHeight / 2
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    if menuX + menuWidth > screenWidth then
        menuX = menu.screenX - menuWidth - 10
    end
    if menuY < 0 then
        menuY = 10
    elseif menuY + menuHeight > screenHeight then
        menuY = screenHeight - menuHeight - 10
    end
    
    -- Draw menu background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
    
    -- Draw menu border
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setLineWidth(1)
    
    -- Draw items
    local mouseX, mouseY = love.mouse.getPosition()
    for i, groundItem in ipairs(menu.pile.items) do
        local itemY = menuY + 5 + (i - 1) * itemHeight
        local isHovered = mouseX >= menuX and mouseX <= menuX + menuWidth and
                         mouseY >= itemY and mouseY <= itemY + itemHeight
        
        -- Highlight hovered item
        if isHovered then
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.rectangle("fill", menuX, itemY, menuWidth, itemHeight)
        end
        
        -- Draw item icon if available
        if groundItem.item.icon then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(groundItem.item.icon, menuX + 5, itemY + 2, 0, 0.6, 0.6)
        end
        
        -- Draw action text with item name and count
        love.graphics.setColor(1, 1, 1)
        local itemName = groundItem.item.name or "Unknown Item"
        if groundItem.item.count and groundItem.item.count > 1 then
            itemName = itemName .. " x" .. groundItem.item.count
        end
        local actionText = "Pickup " .. itemName
        love.graphics.print(actionText, menuX + 25, itemY + 5)
        
    end
end

function game.handleGroundItemSelectionMenuClick(x, y, button)
    if not groundItemSelectionMenu then
        return false
    end
    
    
    -- When menu is open, consume ALL clicks (don't let any pass through to world)
    if button ~= 1 then
        return true -- Block non-left clicks but don't do anything
    end
    
    local menu = groundItemSelectionMenu
    local itemHeight = 25
    local menuWidth = 250  -- Increased width to accommodate "Pickup [item name]" text
    local menuHeight = #menu.pile.items * itemHeight + 10
    
    -- Position menu near mouse but keep on screen
    local menuX = menu.screenX + 10
    local menuY = menu.screenY - menuHeight / 2
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    if menuX + menuWidth > screenWidth then
        menuX = menu.screenX - menuWidth - 10
    end
    if menuY < 0 then
        menuY = 10
    elseif menuY + menuHeight > screenHeight then
        menuY = screenHeight - menuHeight - 10
    end
    
    -- Check if click is within menu bounds
    if x >= menuX and x <= menuX + menuWidth and
       y >= menuY and y <= menuY + menuHeight then
        
        -- Check which item was clicked
        for i, groundItem in ipairs(menu.pile.items) do
            local itemY = menuY + 5 + (i - 1) * itemHeight
            if y >= itemY and y <= itemY + itemHeight then
                player.pickupItemPile(gameState.player, gameState.groundItems, gameState.inventory, {items = {groundItem}})
                groundItemSelectionMenu = nil
                return true -- Consumed the click
            end
        end
        -- Click was in menu area but not on an item - just consume the click
        return true 
    else
        -- Click outside menu - close it but still consume the click to prevent world interaction
        groundItemSelectionMenu = nil
        return true -- Block the click from reaching the world
    end
end

return game
