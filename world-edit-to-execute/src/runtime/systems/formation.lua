--[[
Formation Movement System (Issue 404d)

Provides formation movement for groups of units. Supports line, box, wedge,
and column formations commonly used in RTS games like WC3.

WC3's formations are relatively simple - position offsets from a center point.
This implementation matches that simplicity while providing a foundation for
more complex formation behaviors if needed.

Usage:
    local formation = require("runtime.systems.formation")

    -- Calculate formation positions
    local positions = formation.calculate_positions(entities, target, formation.TYPE.LINE)

    -- Move entire group in formation
    formation.move_group(entities, target, formation.TYPE.WEDGE)
]]

local ecs = require("runtime.ecs")

local formation = {}

-- {{{ Formation type constants
-- Types of formations that can be used for group movement.
formation.TYPE = {
    LINE = "line",       -- Horizontal line centered on target
    BOX = "box",         -- Square/rectangular grid
    WEDGE = "wedge",     -- V-shaped with leader at point
    COLUMN = "column",   -- Single file line
}
-- }}}

-- {{{ Formation spacing
-- Default spacing between units in formation (in world units).
-- WC3 uses approximately 64 units between formation positions.
formation.DEFAULT_SPACING = 64
-- }}}

-- {{{ formation.calculate_positions
-- Calculates formation positions for a group of entities.
-- Returns an array of {x, y} positions indexed by entity order.
--
-- @param entities array of entity IDs
-- @param target center target position {x, y}
-- @param formation_type one of formation.TYPE values (default: LINE)
-- @param spacing optional spacing between units (default: DEFAULT_SPACING)
-- @return array of {x, y} positions (same length as entities)
function formation.calculate_positions(entities, target, formation_type, spacing)
    formation_type = formation_type or formation.TYPE.LINE
    spacing = spacing or formation.DEFAULT_SPACING
    local positions = {}
    local count = #entities

    if count == 0 then
        return positions
    end

    if formation_type == formation.TYPE.LINE then
        positions = formation._calculate_line(entities, target, spacing)
    elseif formation_type == formation.TYPE.BOX then
        positions = formation._calculate_box(entities, target, spacing)
    elseif formation_type == formation.TYPE.WEDGE then
        positions = formation._calculate_wedge(entities, target, spacing)
    elseif formation_type == formation.TYPE.COLUMN then
        positions = formation._calculate_column(entities, target, spacing)
    else
        -- Unknown formation type, fall back to line
        positions = formation._calculate_line(entities, target, spacing)
    end

    return positions
end
-- }}}

-- {{{ formation._calculate_line
-- Internal: Calculate line formation positions.
-- Units arranged horizontally, centered on target.
--
-- @param entities array of entity IDs
-- @param target center position {x, y}
-- @param spacing distance between units
-- @return array of {x, y} positions
function formation._calculate_line(entities, target, spacing)
    local positions = {}
    local count = #entities

    -- Calculate total width and offset to center
    local total_width = (count - 1) * spacing
    local start_x = target.x - total_width / 2

    for i, entity in ipairs(entities) do
        positions[i] = {
            x = start_x + (i - 1) * spacing,
            y = target.y,
        }
    end

    return positions
end
-- }}}

-- {{{ formation._calculate_box
-- Internal: Calculate box/grid formation positions.
-- Units arranged in a square grid, centered on target.
--
-- @param entities array of entity IDs
-- @param target center position {x, y}
-- @param spacing distance between units
-- @return array of {x, y} positions
function formation._calculate_box(entities, target, spacing)
    local positions = {}
    local count = #entities

    -- Calculate grid dimensions (prefer square)
    local cols = math.ceil(math.sqrt(count))
    local rows = math.ceil(count / cols)

    -- Calculate offsets to center the grid
    local offset_x = (cols - 1) * spacing / 2
    local offset_y = (rows - 1) * spacing / 2

    local idx = 1
    for row = 1, rows do
        for col = 1, cols do
            if idx <= count then
                positions[idx] = {
                    x = target.x + (col - 1) * spacing - offset_x,
                    y = target.y + (row - 1) * spacing - offset_y,
                }
                idx = idx + 1
            end
        end
    end

    return positions
end
-- }}}

-- {{{ formation._calculate_wedge
-- Internal: Calculate wedge/V formation positions.
-- Leader at the point, wings extending back diagonally.
--
-- @param entities array of entity IDs
-- @param target leader position {x, y}
-- @param spacing distance between ranks
-- @return array of {x, y} positions
function formation._calculate_wedge(entities, target, spacing)
    local positions = {}
    local count = #entities

    -- Leader at the front/point
    positions[1] = { x = target.x, y = target.y }

    if count == 1 then
        return positions
    end

    -- Arrange remaining units in V pattern behind leader
    local row = 1
    local idx = 2

    while idx <= count do
        -- Left wing
        if idx <= count then
            positions[idx] = {
                x = target.x - row * spacing * 0.7,  -- Angled back
                y = target.y - row * spacing,        -- Behind leader
            }
            idx = idx + 1
        end

        -- Right wing
        if idx <= count then
            positions[idx] = {
                x = target.x + row * spacing * 0.7,
                y = target.y - row * spacing,
            }
            idx = idx + 1
        end

        row = row + 1
    end

    return positions
end
-- }}}

-- {{{ formation._calculate_column
-- Internal: Calculate column/single-file formation positions.
-- Units arranged vertically, with leader at front.
--
-- @param entities array of entity IDs
-- @param target leader position {x, y}
-- @param spacing distance between units
-- @return array of {x, y} positions
function formation._calculate_column(entities, target, spacing)
    local positions = {}
    local count = #entities

    for i, entity in ipairs(entities) do
        positions[i] = {
            x = target.x,
            y = target.y - (i - 1) * spacing,  -- Line up behind leader
        }
    end

    return positions
end
-- }}}

-- {{{ formation.move_group
-- Issues move orders to a group of entities in formation.
-- Requires the orders module to be available.
--
-- @param entities array of entity IDs
-- @param target center/leader position {x, y}
-- @param formation_type one of formation.TYPE values
-- @param options optional table with:
--   spacing: custom spacing between units
--   queue: if true, queue orders instead of replacing
-- @return boolean success
function formation.move_group(entities, target, formation_type, options)
    options = options or {}

    -- Calculate formation positions
    local positions = formation.calculate_positions(
        entities, target, formation_type, options.spacing
    )

    if #positions == 0 then
        return false
    end

    -- Try to load orders module
    local ok, orders = pcall(require, "runtime.orders")
    if not ok then
        -- Orders module not available, can't issue orders
        return false
    end

    -- Issue move orders to each entity
    local all_success = true
    for i, entity in ipairs(entities) do
        local pos = positions[i]
        if pos then
            local success = orders.move(entity, pos, {queue = options.queue})
            if not success then
                all_success = false
            end
        end
    end

    return all_success
end
-- }}}

-- {{{ formation.get_formation_size
-- Returns the approximate bounding size of a formation.
-- Useful for checking if formation fits in available space.
--
-- @param entity_count number of entities
-- @param formation_type one of formation.TYPE values
-- @param spacing optional custom spacing
-- @return width, height of formation bounds
function formation.get_formation_size(entity_count, formation_type, spacing)
    spacing = spacing or formation.DEFAULT_SPACING

    if entity_count <= 0 then
        return 0, 0
    end

    if formation_type == formation.TYPE.LINE then
        return (entity_count - 1) * spacing, 0
    elseif formation_type == formation.TYPE.BOX then
        local cols = math.ceil(math.sqrt(entity_count))
        local rows = math.ceil(entity_count / cols)
        return (cols - 1) * spacing, (rows - 1) * spacing
    elseif formation_type == formation.TYPE.WEDGE then
        local rows = math.ceil((entity_count - 1) / 2) + 1
        local max_width = (rows - 1) * spacing * 0.7 * 2
        local height = (rows - 1) * spacing
        return max_width, height
    elseif formation_type == formation.TYPE.COLUMN then
        return 0, (entity_count - 1) * spacing
    end

    return 0, 0
end
-- }}}

-- {{{ formation.rotate_positions
-- Rotates formation positions around a center point.
-- Useful for facing formations toward a direction.
--
-- @param positions array of {x, y} positions
-- @param center center point {x, y} to rotate around
-- @param angle rotation angle in radians
-- @return array of rotated {x, y} positions
function formation.rotate_positions(positions, center, angle)
    local rotated = {}
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)

    for i, pos in ipairs(positions) do
        -- Translate to origin
        local dx = pos.x - center.x
        local dy = pos.y - center.y

        -- Rotate
        local rx = dx * cos_a - dy * sin_a
        local ry = dx * sin_a + dy * cos_a

        -- Translate back
        rotated[i] = {
            x = center.x + rx,
            y = center.y + ry,
        }
    end

    return rotated
end
-- }}}

return formation
