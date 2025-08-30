-- Combat module for Love2D RPG
-- Handles all combat interactions between entities

local combat = {}
local constants = require("src.constants")
local lume = require("lib.lume")

-- Combat constants
local PLAYER_ATTACK_DAMAGE = 1 -- Player deals 1 damage per hit

-- Initialize combat state for an entity
function combat.initCombatState(entity)
    return {
        inCombat = false,
        combatTimer = 0,
        isPlayerTurn = true, -- Player always goes first
        lastTurnTime = 0
    }
end

-- Update combat state for turn-based combat
function combat.update(entity, dt, currentTime, playerX, playerY, player, onDamage)
    if not entity.alive or not entity.combatState or not entity.combatState.inCombat then return end
    
    -- Check if player is still in range
    local distance = lume.distance(entity.worldX, entity.worldY, playerX, playerY)
    if distance > constants.ATTACK_RANGE then
        combat.endCombat(entity)
        return
    end
    
    -- Update combat timer
    entity.combatState.combatTimer = entity.combatState.combatTimer + dt
    
    -- Check for turn timing (1 second per turn)
    if entity.combatState.combatTimer >= 1.0 then
        entity.combatState.combatTimer = 0
        
        -- Execute current turn
        if entity.combatState.isPlayerTurn then
            -- Player's turn - player auto-attacks
            local playerDied = combat.playerAutoAttack(entity, player, currentTime, onDamage)
            if not playerDied then
                -- Switch to enemy turn after player attack
                entity.combatState.isPlayerTurn = false
            end
        else
            -- Enemy's turn - enemy attacks player
            combat.attackPlayer(entity, player, onDamage)
            -- Switch to player turn after enemy attack
            entity.combatState.isPlayerTurn = true
        end
    end
end

-- Enemy attacks player
function combat.attackPlayer(entity, player, onDamage)
    if not entity.alive or not player then return end

    local damage = 1 -- Enemies deal 1 damage
    player.health = math.max(0, player.health - damage)

    -- Trigger damage effect at player's position
    if onDamage then
        onDamage(player.x, player.y, damage, {1, 0.8, 0.2}) -- Orange for enemy damage
    end

    -- Add flash effect to player
    if player then
        player.flashTimer = 0.2 -- 0.2 second flash
    end

    -- If player dies, end combat
    if player.health <= 0 then
        combat.endCombat(entity)
    end
end

-- Player auto-attack during turn-based combat
function combat.playerAutoAttack(entity, player, currentTime, onDamage)
    if not entity.alive then return false end
    
    local damage = PLAYER_ATTACK_DAMAGE
    entity.health = entity.health - damage

    -- Trigger damage effect
    if onDamage then
        onDamage(entity.worldX, entity.worldY, damage, {1, 0.3, 0.3}) -- Red for player damage
    end

    -- Add flash effect
    local damage_effects = require("src.damage_effects")
    damage_effects.addFlash(entity)

    if entity.health <= 0 then
        -- End combat when entity dies
        combat.endCombat(entity)
        return true -- Entity died
    end

    return false -- Entity still alive
end

-- Player attacks entity (manual attack, not auto-attack)
function combat.playerAttack(entity, player, currentTime, onDamage)
    if not entity.alive then return false end
    
    -- Start combat if not already started
    if not entity.combatState.inCombat then
        entity.combatState.inCombat = true
        entity.combatState.combatTimer = 0
        entity.combatState.isPlayerTurn = love.math.random() < 0.5 -- 50% chance for player to go first
    end
    
    -- Only allow manual attack on player's turn
    if not entity.combatState.isPlayerTurn then
        return false -- Not player's turn
    end

    local damage = PLAYER_ATTACK_DAMAGE
    entity.health = entity.health - damage

    -- Trigger damage effect
    if onDamage then
        onDamage(entity.worldX, entity.worldY, damage, {1, 0.3, 0.3}) -- Red for player damage
    end

    -- Add flash effect
    local damage_effects = require("src.damage_effects")
    damage_effects.addFlash(entity)

    if entity.health <= 0 then
        -- Don't set alive = false here, let the entity's own update function handle death
        return true -- Entity died
    end

    return false -- Entity still alive
end

-- Check if entity is in combat
function combat.isInCombat(entity)
    return entity.combatState and entity.combatState.inCombat
end

-- End combat for an entity (simplified)
function combat.endCombat(entity)
    if entity.combatState then
        entity.combatState.inCombat = false
    end
end

-- Check if it's the player's turn
function combat.isPlayerTurn(entity)
    return entity.combatState and entity.combatState.inCombat and entity.combatState.isPlayerTurn
end

-- Get combat status for debugging
function combat.getCombatStatus(entity)
    if not entity.combatState then return "No combat state" end
    local turnInfo = entity.combatState.inCombat and (entity.combatState.isPlayerTurn and " (Player's turn)" or " (Enemy's turn)") or ""
    return "Combat: " .. tostring(entity.combatState.inCombat) .. turnInfo
end

return combat