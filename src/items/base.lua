-- Base items module - shared functionality for all items
local base = {}

-- Icon cache to avoid recreating the same icons
local iconCache = {}

-- Create a simple icon canvas
function base.createIconCanvas()
    return love.graphics.newCanvas(32, 32)
end

-- Get cached icon or create new one
function base.getCachedIcon(key, createFunc)
    if iconCache[key] then
        return iconCache[key]
    end
    
    local icon = createFunc()
    iconCache[key] = icon
    return icon
end

-- Clear icon cache (useful for cleanup)
function base.clearIconCache()
    iconCache = {}
end

return base