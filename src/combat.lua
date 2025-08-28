-- Combat module for Love2D RPG
-- Handles all combat interactions between entities

local combat = {}
local constants = require("src.constants")
local lume = require("lib.lume")

-- Combat constants
local ATTACK_COOLDOWN = 2.0 -- Base attack cooldown for enemies
local RETALIATION_DELAY = 1.0 -- Delay before enemy retaliates
local INTERACTION_DISTANCE = 75 -- Distance within which combat can occur
local PLAYER_ATTACK_DAMAGE = 1 -- Player deals 1 damage per hit

-- Initialize combat state for an entity
function combat.initCombatState(entity)
    return {
        inCombat = false,
        lastAttackTime = 0,
        lastPlayerAttackTime = 0,
        retaliationTimer = 0,
        targetPlayer = nil,
        attackCooldown = entity.attackCooldown or ATTACK_COOLDOWN,
        retaliationDelay = entity.retaliationDelay or RETALIATION_DELAY,
        interactionDistance = entity.interactionDistance or INTERACTION_DISTANCE
    }
end

-- Start retaliation against a player
function combat.startRetaliation(entity, player, currentTime)
    if not entity.combatState then
        entity.combatState = combat.initCombatState(entity)
    end

    -- Only start retaliation if not already in combat and not already retaliating
    if not entity.combatState.inCombat and entity.combatState.retaliationTimer <= 0 then
        entity.combatState.retaliationTimer = entity.combatState.retaliationDelay
        -- Don't reset combat state - just start the timer
    end
end

-- Update combat state
function combat.update(entity, dt, currentTime, playerX, playerY, player, onDamage)
    if not entity.alive or not entity.combatState then return end

    -- Handle retaliation timer
    if entity.combatState.retaliationTimer > 0 then
        entity.combatState.retaliationTimer = entity.combatState.retaliationTimer - dt
        if entity.combatState.retaliationTimer <= 0 then
            entity.combatState.inCombat = true
            entity.combatState.targetPlayer = player
        end
    end

    -- Handle attacking player if in combat
    if entity.combatState.inCombat and entity.combatState.targetPlayer then
        local distance = lume.distance(entity.worldX, entity.worldY, playerX, playerY)

        if distance <= entity.combatState.interactionDistance then
            -- Check if enough time has passed since last attack
            local timeSinceLastAttack = currentTime - entity.combatState.lastAttackTime

            if timeSinceLastAttack >= entity.combatState.attackCooldown then
                combat.attackPlayer(entity, player, onDamage)
                entity.combatState.lastAttackTime = currentTime
            end
        else
            -- Player moved out of range, end combat
            entity.combatState.inCombat = false
            entity.combatState.targetPlayer = nil
        end
    end
end

-- Entity attacks player
function combat.attackPlayer(entity, player, onDamage)
    if not entity.alive or not player then return end

    local damage = entity.attackDamage or 1
    local oldHealth = player.health
    player.health = math.max(0, player.health - damage)

    -- Trigger damage effect at player's position
    if onDamage then
        onDamage(player.x, player.y, damage, {1, 0.8, 0.2}) -- Orange for enemy damage
    end

    -- Add flash effect to player
    if player then
        player.flashTimer = 0.2 -- 0.2 second flash
    end

    -- If player dies, stop combat
    if player.health <= 0 then
        combat.endCombat(entity)
    end
end

-- Player attacks entity
function combat.playerAttack(entity, player, currentTime, onDamage)
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

    -- Start retaliation if this is the first attack
    combat.startRetaliation(entity, player, currentTime)

    entity.combatState.lastPlayerAttackTime = currentTime

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

-- End combat for an entity
function combat.endCombat(entity)
    if entity.combatState then
        entity.combatState.inCombat = false
        entity.combatState.targetPlayer = nil
        entity.combatState.retaliationTimer = 0
    end
end

-- Get combat status for debugging
function combat.getCombatStatus(entity)
    if not entity.combatState then return "No combat state" end

    return string.format("Combat: %s, Timer: %.1f, Target: %s",
        tostring(entity.combatState.inCombat),
        entity.combatState.retaliationTimer,
        tostring(entity.combatState.targetPlayer ~= nil))
end

return combat
