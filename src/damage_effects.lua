-- Damage Effects module for Love2D RPG
-- Handles floating damage numbers and flash effects

local damage_effects = {}
local constants = require("src.constants")

-- Damage number properties
local DAMAGE_NUMBER_LIFETIME = 2.0 -- How long damage numbers last (seconds)
local DAMAGE_NUMBER_SPEED = 50 -- How fast damage numbers float upward (pixels per second)
local DAMAGE_NUMBER_FADE_START = 1.0 -- When to start fading (seconds before end)
local DAMAGE_NUMBER_FONT_SIZE = 16

-- Flash effect properties
local FLASH_DURATION = 0.2 -- How long flash lasts (seconds)

-- Create a new damage number
function damage_effects.createDamageNumber(worldX, worldY, damage, color)
    return {
        worldX = worldX,
        worldY = worldY,
        damage = damage,
        color = color or {1, 0.3, 0.3}, -- Default red color
        lifetime = DAMAGE_NUMBER_LIFETIME,
        initialY = worldY
    }
end

-- Update damage number
function damage_effects.updateDamageNumber(damageNum, dt)
    damageNum.lifetime = damageNum.lifetime - dt
    -- Move upward over time (pixels per second)
    damageNum.worldY = damageNum.initialY - (DAMAGE_NUMBER_LIFETIME - damageNum.lifetime) * DAMAGE_NUMBER_SPEED
    return damageNum.lifetime > 0
end

-- Draw damage number
function damage_effects.drawDamageNumber(damageNum, camera)
    if damageNum.lifetime <= 0 then return end

    -- World coordinates are already converted to screen by game's translate
    local screenX = damageNum.worldX
    local screenY = damageNum.worldY

    -- Calculate alpha based on lifetime
    local alpha = 1.0
    if damageNum.lifetime < DAMAGE_NUMBER_FADE_START then
        alpha = damageNum.lifetime / DAMAGE_NUMBER_FADE_START
    end

    -- Set font for damage numbers (scaled)
    love.graphics.setColor(damageNum.color[1], damageNum.color[2], damageNum.color[3], alpha)
    local scale = constants.UI_SCALE or 1.0
    local scaledFontSize = math.max(12, math.floor(DAMAGE_NUMBER_FONT_SIZE * scale))
    love.graphics.setFont(love.graphics.newFont(scaledFontSize))

    -- Draw damage number with slight shadow for better visibility
    love.graphics.setColor(0, 0, 0, alpha * 0.7)
    love.graphics.print(tostring(damageNum.damage), screenX + 1, screenY + 1)

    love.graphics.setColor(damageNum.color[1], damageNum.color[2], damageNum.color[3], alpha)
    love.graphics.print(tostring(damageNum.damage), screenX, screenY)

    -- Reset font
    love.graphics.setFont(love.graphics.getFont())
end

-- Add flash effect to an entity
function damage_effects.addFlash(entity)
    entity.flashTimer = FLASH_DURATION
end

-- Update flash effect
function damage_effects.updateFlash(entity, dt)
    if entity.flashTimer then
        entity.flashTimer = entity.flashTimer - dt
        if entity.flashTimer <= 0 then
            entity.flashTimer = nil
        end
    end
end

-- Check if entity is flashing
function damage_effects.isFlashing(entity)
    return entity.flashTimer and entity.flashTimer > 0
end

-- Get flash color multiplier
function damage_effects.getFlashColor(entity)
    if not damage_effects.isFlashing(entity) then
        return 1, 1, 1
    end

    -- Flash effect: brighter white
    return 1.5, 1.5, 1.5
end

return damage_effects
