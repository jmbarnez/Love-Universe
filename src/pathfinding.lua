-- Simple pathfinding module for Love2D RPG
-- Provides basic obstacle avoidance and path smoothing

local pathfinding = {}
local constants = require("src.constants")
local lume = require("lib.lume")

-- Calculate a simple path with basic obstacle avoidance
function pathfinding.findPath(startX, startY, targetX, targetY, isWalkable, isInWorld)
    -- Simple direct path first
    local dx = targetX - startX
    local dy = targetY - startY
    local distance = lume.distance(startX, startY, targetX, targetY)
    
    if distance == 0 then
        return {{x = startX, y = startY}}
    end
    
    local dirX = dx / distance
    local dirY = dy / distance
    
    -- Check if direct path is clear
    if pathfinding.isPathClear(startX, startY, targetX, targetY, isWalkable, isInWorld) then
        return {{x = targetX, y = targetY}}
    end
    
    -- Try simple obstacle avoidance - check perpendicular directions
    local avoidanceDistance = 30 -- pixels to try moving around obstacles
    
    -- Try going around the obstacle by moving perpendicular first
    local perpDirX1 = -dirY
    local perpDirY1 = dirX
    local perpDirX2 = dirY
    local perpDirY2 = -dirX
    
    -- Try path 1: move perpendicular, then toward target
    local midX1 = startX + perpDirX1 * avoidanceDistance
    local midY1 = startY + perpDirY1 * avoidanceDistance
    
    if isInWorld(midX1, midY1) and isWalkable(midX1, midY1) and 
       pathfinding.isPathClear(midX1, midY1, targetX, targetY, isWalkable, isInWorld) then
        return {{x = midX1, y = midY1}, {x = targetX, y = targetY}}
    end
    
    -- Try path 2: move other perpendicular direction, then toward target
    local midX2 = startX + perpDirX2 * avoidanceDistance
    local midY2 = startY + perpDirY2 * avoidanceDistance
    
    if isInWorld(midX2, midY2) and isWalkable(midX2, midY2) and 
       pathfinding.isPathClear(midX2, midY2, targetX, targetY, isWalkable, isInWorld) then
        return {{x = midX2, y = midY2}, {x = targetX, y = targetY}}
    end
    
    -- Fallback: return direct path even if blocked
    return {{x = targetX, y = targetY}}
end

-- Check if a straight line path is clear of obstacles
function pathfinding.isPathClear(startX, startY, endX, endY, isWalkable, isInWorld)
    local dx = endX - startX
    local dy = endY - startY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance == 0 then return true end
    
    local stepSize = 10 -- Check every 10 pixels along the path
    local steps = math.floor(distance / stepSize)
    
    for i = 1, steps do
        local t = i / steps
        local checkX = startX + dx * t
        local checkY = startY + dy * t
        
        if not isInWorld(checkX, checkY) or not isWalkable(checkX, checkY) then
            return false
        end
    end
    
    return true
end

-- Get next movement direction toward target with obstacle avoidance
function pathfinding.getNextDirection(currentX, currentY, targetX, targetY, isWalkable, isInWorld)
    -- Use simple pathfinding to get next waypoint
    local path = pathfinding.findPath(currentX, currentY, targetX, targetY, isWalkable, isInWorld)
    
    if #path == 0 then
        return 0, 0
    end
    
    local nextPoint = path[1]
    local dx = nextPoint.x - currentX
    local dy = nextPoint.y - currentY
    local distance = lume.distance(currentX, currentY, nextPoint.x, nextPoint.y)
    
    if distance == 0 then
        return 0, 0
    end
    
    return dx / distance, dy / distance
end

return pathfinding