-- Ground Items Module
-- Handles ground item management, spawning, updating, and interaction

local ground_items = {}
local lume = require("lib.lume")

-- Ground items storage (will be set by game module)
ground_items.items = nil

-- Ground item hover state for tooltips (now handles piles)
local ground_item_hover = {
    pile = nil, -- Now stores the entire pile instead of single item
    time = 0,
    tooltip_delay = 0.15,
    x = 0,
    y = 0
}

-- Add a ground item to the world
function ground_items.add_item(ground_items_list, item, x, y, permanent)
    if ground_items_list then
        table.insert(ground_items_list, {
            item = item,
            x = x,
            y = y,
            rotation = permanent and (love.math.random() * 2 * math.pi) or 0, -- Random rotation for permanent items
            created_time = love.timer.getTime(), -- Timestamp when item was dropped
            expire_time = permanent and nil or 30.0 -- Permanent items don't expire, others expire in 30 seconds
        })
    end
end

-- Update ground items and remove expired ones
function ground_items.update(ground_items_list, dt)
    if not ground_items_list then
        return
    end

    local current_time = love.timer.getTime()
    local i = 1
    while i <= #ground_items_list do
        local ground_item = ground_items_list[i]
        if ground_item.created_time and ground_item.expire_time then
            local age = current_time - ground_item.created_time
            if age >= ground_item.expire_time then
                -- Item has expired, remove it
                table.remove(ground_items_list, i)
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
end

-- Draw ground items
function ground_items.draw(ground_items_list, camera)
    if not ground_items_list then
        return
    end

    for i, ground_item in ipairs(ground_items_list) do
        local item = ground_item.item

        if item.icon then
            -- Draw the actual icon image with rotation if it's a permanent item
            love.graphics.setColor(1, 1, 1, 1)
            local icon_size = 24 -- Size of ground item icon
            local icon_scale = icon_size / 32 -- Scale from 32x32 to desired size
            local rotation = ground_item.rotation or 0
            love.graphics.draw(item.icon,
                              ground_item.x, ground_item.y,
                              rotation,
                              icon_scale, icon_scale,
                              16, 16) -- Origin at center of 32x32 icon
        else
            -- Fallback: draw colored rectangle if no icon (with rotation for permanent items)
            local item_color = item.color or {0.8, 0.8, 0.8, 1}
            love.graphics.setColor(item_color)
            local icon_size = 20
            local rotation = ground_item.rotation or 0
            if rotation > 0 then
                love.graphics.push()
                love.graphics.translate(ground_item.x, ground_item.y)
                love.graphics.rotate(rotation)
                love.graphics.rectangle("fill", -icon_size/2, -icon_size/2, icon_size, icon_size)
                love.graphics.pop()
            else
                love.graphics.rectangle("fill", ground_item.x - icon_size/2, ground_item.y - icon_size/2, icon_size, icon_size)
            end
        end

        -- Draw item count if stackable and count > 1
        if item.count and item.count > 1 then
            love.graphics.setColor(1, 1, 1, 1)
            local count_text = tostring(item.count)
            local font = love.graphics.getFont()
            local text_width = font:getWidth(count_text)
            local text_height = font:getHeight()

            -- Draw dark background for text
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle("fill", ground_item.x + 8, ground_item.y + 8, text_width + 4, text_height + 2)

            -- Draw count text
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(count_text, ground_item.x + 10, ground_item.y + 9)
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

-- Update ground item hover state for tooltips (now handles piles)
function ground_items.update_hover(dt, mouse_world_x, mouse_world_y, ground_items_list)
    if not ground_items_list then
        ground_item_hover.pile = nil
        ground_item_hover.time = 0
        return
    end

    local hovered_pile = nil
    local check_radius = 20 -- pixels - interaction radius
    local piles = ground_items.group_by_location(ground_items_list)

    -- Check if mouse is over any item pile
    for _, pile in ipairs(piles) do
        local distance = lume.distance(pile.centerX, pile.centerY, mouse_world_x, mouse_world_y)
        if distance <= check_radius then
            hovered_pile = pile
            break
        end
    end

    if hovered_pile then
        if ground_item_hover.pile and
           ground_item_hover.pile.centerX == hovered_pile.centerX and
           ground_item_hover.pile.centerY == hovered_pile.centerY then
            ground_item_hover.time = ground_item_hover.time + dt
        else
            ground_item_hover.pile = hovered_pile
            ground_item_hover.time = 0
            ground_item_hover.x = mouse_world_x
            ground_item_hover.y = mouse_world_y
        end
    else
        ground_item_hover.pile = nil
        ground_item_hover.time = 0
    end
end

-- Draw ground item tooltip (now handles item piles with stacked tooltips)
function ground_items.draw_tooltip(camera)
    if not ground_item_hover.pile or ground_item_hover.time < ground_item_hover.tooltip_delay then
        return
    end

    local pile = ground_item_hover.pile
    if not pile or not pile.items or #pile.items == 0 then return end

    -- Convert world position to screen position for tooltip
    local screen_x, screen_y = ground_items.world_to_screen(ground_item_hover.x, ground_item_hover.y, camera)
    local tooltip_x = screen_x + 15
    local tooltip_y = screen_y - 10

    -- Build tooltip content for all items in the pile
    local lines = {}
    local item_counts = {} -- Track item types and their total counts

    -- Group items by name and sum their counts
    for _, ground_item in ipairs(pile.items) do
        local item = ground_item.item
        local item_name = item.name or "Unknown Item"

        if not item_counts[item_name] then
            item_counts[item_name] = {
                item = item,
                count = 0
            }
        end
        item_counts[item_name].count = item_counts[item_name].count + (item.count or 1)
    end

    -- If multiple item types, show pile header
    if next(item_counts, next(item_counts)) then -- More than one item type
        table.insert(lines, "=== Item Pile (" .. #pile.items .. " items) ===")
        table.insert(lines, "") -- Empty line for spacing
    end

    -- Add each unique item type to tooltip
    for item_name, item_data in pairs(item_counts) do
        local item = item_data.item
        local total_count = item_data.count

        -- Item name with count if > 1
        if total_count > 1 then
            table.insert(lines, item_name .. " (x" .. total_count .. ")")
        else
            table.insert(lines, item_name)
        end

        -- Add item details for first occurrence (avoid repetition)
        if item.description then
            table.insert(lines, "  " .. item.description)
        end

        if item.type then
            table.insert(lines, "  Type: " .. item.type)
        end

        if item.rarity then
            table.insert(lines, "  Rarity: " .. item.rarity)
        end

        table.insert(lines, "") -- Empty line between item types
    end

    -- Remove last empty line
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines)
    end

    -- Calculate tooltip dimensions
    local font = love.graphics.getFont()
    local max_width = 0
    local total_height = 0
    local line_height = font:getHeight() + 2

    for _, line in ipairs(lines) do
        local width = font:getWidth(line)
        max_width = math.max(max_width, width)
        total_height = total_height + line_height
    end

    local tooltip_width = max_width + 16
    local tooltip_height = total_height + 8

    -- Keep tooltip on screen
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()

    if tooltip_x + tooltip_width > screen_width then
        tooltip_x = screen_x - tooltip_width - 15
    end

    if tooltip_y + tooltip_height > screen_height then
        tooltip_y = screen_y - tooltip_height - 10
    end

    if tooltip_y < 0 then
        tooltip_y = screen_y + 20
    end

    -- Get UI colors from ui module if available
    local ui = require("src.ui")
    local colors = (ui and ui.uiState and ui.uiState.theme and ui.uiState.theme.colors) or {
        panel = {0.12, 0.12, 0.18, 0.95},
        border = {0.4, 0.3, 0.2, 1.0},
        text = {0.9, 0.85, 0.8, 1.0}
    }

    -- Draw tooltip background
    love.graphics.setColor(colors.panel)
    if ui and ui.drawRoundedRect then
        ui.drawRoundedRect(tooltip_x, tooltip_y, tooltip_width, tooltip_height, 6)
    else
        love.graphics.rectangle("fill", tooltip_x, tooltip_y, tooltip_width, tooltip_height)
    end

    -- Draw tooltip border
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    if ui and ui.drawRoundedRectOutline then
        ui.drawRoundedRectOutline(tooltip_x, tooltip_y, tooltip_width, tooltip_height, 6)
    else
        love.graphics.rectangle("line", tooltip_x, tooltip_y, tooltip_width, tooltip_height)
    end
    love.graphics.setLineWidth(1)

    -- Draw tooltip text
    love.graphics.setColor(colors.text)
    local y_offset = tooltip_y + 6
    for _, line in ipairs(lines) do
        love.graphics.print(line, tooltip_x + 8, y_offset)
        y_offset = y_offset + line_height
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

-- Group nearby items into piles for better interaction handling
function ground_items.group_by_location(ground_items_list)
    local piles = {}
    local pile_radius = 25 -- pixels - items within this distance are grouped together

    for _, ground_item in ipairs(ground_items_list) do
        local found_pile = false

        -- Check if this item belongs to an existing pile
        for _, pile in ipairs(piles) do
            local distance = lume.distance(ground_item.x, ground_item.y, pile.centerX, pile.centerY)
            if distance <= pile_radius then
                table.insert(pile.items, ground_item)
                -- Update pile center to average of all items
                local total_x, total_y = 0, 0
                for _, item in ipairs(pile.items) do
                    total_x = total_x + item.x
                    total_y = total_y + item.y
                end
                pile.centerX = total_x / #pile.items
                pile.centerY = total_y / #pile.items
                found_pile = true
                break
            end
        end

        -- If no pile found, create a new one
        if not found_pile then
            table.insert(piles, {
                centerX = ground_item.x,
                centerY = ground_item.y,
                items = {ground_item}
            })
        end
    end

    return piles
end

-- Draw interaction outline for ground items (handles item piles)
function ground_items.draw_outlines(ground_items_list, mouse_world_x, mouse_world_y, interaction_outline)
    if not ground_items_list or not interaction_outline then
        return
    end

    local check_radius = 20 -- pixels - interaction radius
    local piles = ground_items.group_by_location(ground_items_list)

    -- Find the closest pile within interaction range
    for _, pile in ipairs(piles) do
        local distance = lume.distance(pile.centerX, pile.centerY, mouse_world_x, mouse_world_y)
        if distance <= check_radius then
            local item_count = #pile.items

            if item_count == 1 then
                -- Single item - draw tight outline around icon
                local item = pile.items[1].item
                local icon_size = item.icon and 24 or 20

                love.graphics.setColor(1, 1, 0, 0.8) -- Yellow outline
                love.graphics.rectangle("line",
                    pile.centerX - icon_size/2 - 1,
                    pile.centerY - icon_size/2 - 1,
                    icon_size + 2,
                    icon_size + 2)
            else
                -- Multiple items - draw circular outline around the pile
                local pile_radius = math.max(15, item_count * 3) -- Scale radius with item count
                love.graphics.setColor(1, 1, 0, 0.8) -- Yellow outline
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", pile.centerX, pile.centerY, pile_radius)
                love.graphics.setLineWidth(1)

                -- Draw item count indicator
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.circle("fill", pile.centerX + pile_radius - 5, pile.centerY - pile_radius + 5, 8)
                love.graphics.setColor(0, 0, 0, 1)
                local font = love.graphics.getFont()
                local count_text = tostring(item_count)
                local text_width = font:getWidth(count_text)
                love.graphics.print(count_text, pile.centerX + pile_radius - 5 - text_width/2, pile.centerY - pile_radius + 5 - 6)
            end

            love.graphics.setColor(1, 1, 1) -- Reset color
            break -- Only outline one pile at a time
        end
    end
end

-- Get ground items at position (now returns the closest pile)
function ground_items.get_at_position(world_x, world_y, ground_items_list)
    local check_radius = 20 -- pixels - increased for better interaction
    local piles = ground_items.group_by_location(ground_items_list)

    -- Find the closest pile within interaction range
    for _, pile in ipairs(piles) do
        local distance = lume.distance(pile.centerX, pile.centerY, world_x, world_y)
        if distance <= check_radius then
            -- Return the first item from the pile and its index in the original groundItems array
            if pile.items and #pile.items > 0 then
                local first_item = pile.items[1]
                -- Find the index in the original groundItems array
                for i, ground_item in ipairs(ground_items_list) do
                    if ground_item == first_item then
                        return ground_item, i, pile -- Return the pile as well for multi-pickup
                    end
                end
            end
        end
    end
    return nil
end

-- Convert world coordinates to screen coordinates (pixel-based)
function ground_items.world_to_screen(world_x, world_y, camera)
    -- Use hump camera for coordinate conversion
    return camera:screenCoords(world_x, world_y)
end

return ground_items
