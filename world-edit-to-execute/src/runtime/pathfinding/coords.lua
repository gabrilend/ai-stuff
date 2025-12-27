--[[
Coordinate Conversion for Pathfinding

Converts between world space (game units used by units/triggers) and
grid space (tile indices used by pathfinding). WC3 maps are typically
centered at world origin (0,0), with the grid origin at the bottom-left.

Key concepts:
- World coordinates: floating-point positions in game units (e.g., -1024.5, 512.0)
- Grid coordinates: integer tile indices (e.g., 56, 42)
- Tile size: typically 128 world units per tile
- Grid offset: world position of tile (0,0), typically negative for centered maps
]]

local coords = {}

-- {{{ Active grid reference
-- The coordinate system needs to know grid dimensions for conversions.
-- An active grid can be set once and used for all subsequent conversions,
-- or a grid can be passed explicitly to each function.
local active_grid = nil

-- {{{ coords.set_grid
-- Set the active grid for coordinate conversions.
-- @param grid Pathing grid with width, height, tile_size, offset_x, offset_y
function coords.set_grid(grid)
    active_grid = grid
end
-- }}}

-- {{{ coords.get_grid
-- Get the currently active grid.
-- @return The active pathing grid or nil
function coords.get_grid()
    return active_grid
end
-- }}}

-- {{{ coords.clear_grid
-- Clear the active grid reference.
function coords.clear_grid()
    active_grid = nil
end
-- }}}
-- }}}

-- {{{ World to grid conversion

-- {{{ coords.world_to_grid
-- Converts world coordinates to grid tile indices.
-- Returns nil if the position is outside grid bounds.
--
-- @param world_x World X coordinate
-- @param world_y World Y coordinate
-- @param grid Optional grid (uses active_grid if not provided)
-- @return grid_x, grid_y Integer tile indices, or nil, nil, error_string
function coords.world_to_grid(world_x, world_y, grid)
    grid = grid or active_grid
    if not grid then
        return nil, nil, "No grid set for coordinate conversion"
    end

    -- Calculate tile indices
    -- World position relative to grid origin, divided by tile size
    local tile_x = math.floor((world_x - grid.offset_x) / grid.tile_size)
    local tile_y = math.floor((world_y - grid.offset_y) / grid.tile_size)

    -- Bounds check
    if tile_x < 0 or tile_x >= grid.width then
        return nil, nil, "X coordinate out of bounds"
    end
    if tile_y < 0 or tile_y >= grid.height then
        return nil, nil, "Y coordinate out of bounds"
    end

    return tile_x, tile_y
end
-- }}}

-- {{{ coords.world_to_grid_clamped
-- Like world_to_grid but clamps to grid edges instead of returning nil.
-- Useful when you want the nearest valid tile for out-of-bounds positions.
--
-- @param world_x World X coordinate
-- @param world_y World Y coordinate
-- @param grid Optional grid (uses active_grid if not provided)
-- @return grid_x, grid_y Integer tile indices (always valid)
function coords.world_to_grid_clamped(world_x, world_y, grid)
    grid = grid or active_grid
    if not grid then
        error("No grid set for coordinate conversion")
    end

    local tile_x = math.floor((world_x - grid.offset_x) / grid.tile_size)
    local tile_y = math.floor((world_y - grid.offset_y) / grid.tile_size)

    -- Clamp to valid range [0, size-1]
    tile_x = math.max(0, math.min(grid.width - 1, tile_x))
    tile_y = math.max(0, math.min(grid.height - 1, tile_y))

    return tile_x, tile_y
end
-- }}}
-- }}}

-- {{{ Grid to world conversion

-- {{{ coords.grid_to_world
-- Converts grid tile indices to world coordinates.
-- Returns the center of the tile in world units.
--
-- @param grid_x Grid X coordinate (tile index)
-- @param grid_y Grid Y coordinate (tile index)
-- @param grid Optional grid (uses active_grid if not provided)
-- @return world_x, world_y World coordinates at tile center
function coords.grid_to_world(grid_x, grid_y, grid)
    grid = grid or active_grid
    if not grid then
        error("No grid set for coordinate conversion")
    end

    -- Calculate world position at tile center
    local half_tile = grid.tile_size / 2
    local world_x = grid.offset_x + (grid_x * grid.tile_size) + half_tile
    local world_y = grid.offset_y + (grid_y * grid.tile_size) + half_tile

    return world_x, world_y
end
-- }}}

-- {{{ coords.grid_to_world_corner
-- Converts grid tile indices to world coordinates at tile corner (bottom-left).
-- Useful for placing objects at tile boundaries.
--
-- @param grid_x Grid X coordinate (tile index)
-- @param grid_y Grid Y coordinate (tile index)
-- @param grid Optional grid (uses active_grid if not provided)
-- @return world_x, world_y World coordinates at tile corner
function coords.grid_to_world_corner(grid_x, grid_y, grid)
    grid = grid or active_grid
    if not grid then
        error("No grid set for coordinate conversion")
    end

    local world_x = grid.offset_x + (grid_x * grid.tile_size)
    local world_y = grid.offset_y + (grid_y * grid.tile_size)

    return world_x, world_y
end
-- }}}
-- }}}

-- {{{ Bounds checking

-- {{{ coords.is_in_bounds
-- Checks if a world position is within the grid bounds.
--
-- @param world_x World X coordinate
-- @param world_y World Y coordinate
-- @param grid Optional grid (uses active_grid if not provided)
-- @return boolean true if position is within grid
function coords.is_in_bounds(world_x, world_y, grid)
    grid = grid or active_grid
    if not grid then
        return false
    end

    local min_x = grid.offset_x
    local max_x = grid.offset_x + (grid.width * grid.tile_size)
    local min_y = grid.offset_y
    local max_y = grid.offset_y + (grid.height * grid.tile_size)

    return world_x >= min_x and world_x < max_x and
           world_y >= min_y and world_y < max_y
end
-- }}}

-- {{{ coords.is_tile_in_bounds
-- Checks if a grid tile index is within bounds.
--
-- @param grid_x Grid X coordinate (tile index)
-- @param grid_y Grid Y coordinate (tile index)
-- @param grid Optional grid (uses active_grid if not provided)
-- @return boolean true if tile exists in grid
function coords.is_tile_in_bounds(grid_x, grid_y, grid)
    grid = grid or active_grid
    if not grid then
        return false
    end

    return grid_x >= 0 and grid_x < grid.width and
           grid_y >= 0 and grid_y < grid.height
end
-- }}}

-- {{{ coords.get_grid_bounds
-- Returns the world-space bounding box of the grid.
--
-- @param grid Optional grid (uses active_grid if not provided)
-- @return min_x, min_y, max_x, max_y World coordinates of grid bounds
function coords.get_grid_bounds(grid)
    grid = grid or active_grid
    if not grid then
        return nil, nil, nil, nil
    end

    local min_x = grid.offset_x
    local min_y = grid.offset_y
    local max_x = grid.offset_x + (grid.width * grid.tile_size)
    local max_y = grid.offset_y + (grid.height * grid.tile_size)

    return min_x, min_y, max_x, max_y
end
-- }}}
-- }}}

-- {{{ Path conversion

-- {{{ coords.path_to_world
-- Converts a path of grid coordinates to world coordinates.
-- Each waypoint is converted to tile center.
--
-- @param path Array of {x, y} grid coordinates
-- @param grid Optional grid (uses active_grid if not provided)
-- @return Array of {x, y} world coordinates, or nil if path is nil
function coords.path_to_world(path, grid)
    if not path then
        return nil
    end

    grid = grid or active_grid
    if not grid then
        error("No grid set for coordinate conversion")
    end

    local world_path = {}
    for i, point in ipairs(path) do
        local wx, wy = coords.grid_to_world(point.x, point.y, grid)
        world_path[i] = { x = wx, y = wy }
    end

    return world_path
end
-- }}}

-- {{{ coords.path_to_grid
-- Converts a path of world coordinates to grid coordinates.
-- Each waypoint is converted to the containing tile.
-- Returns nil for any out-of-bounds waypoints.
--
-- @param path Array of {x, y} world coordinates
-- @param grid Optional grid (uses active_grid if not provided)
-- @return Array of {x, y} grid coordinates, or nil, error_string
function coords.path_to_grid(path, grid)
    if not path then
        return nil
    end

    grid = grid or active_grid
    if not grid then
        return nil, "No grid set for coordinate conversion"
    end

    local grid_path = {}
    for i, point in ipairs(path) do
        local gx, gy, err = coords.world_to_grid(point.x, point.y, grid)
        if not gx then
            return nil, string.format("Waypoint %d: %s", i, err)
        end
        grid_path[i] = { x = gx, y = gy }
    end

    return grid_path
end
-- }}}
-- }}}

-- {{{ Distance calculations

-- {{{ coords.world_distance
-- Calculates Euclidean distance between two world positions.
--
-- @param x1, y1 First position
-- @param x2, y2 Second position
-- @return Distance in world units
function coords.world_distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end
-- }}}

-- {{{ coords.world_distance_squared
-- Calculates squared Euclidean distance (avoids sqrt for comparisons).
--
-- @param x1, y1 First position
-- @param x2, y2 Second position
-- @return Distance squared in world units
function coords.world_distance_squared(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end
-- }}}

-- {{{ coords.grid_distance_manhattan
-- Calculates Manhattan distance between two grid positions.
--
-- @param x1, y1 First tile
-- @param x2, y2 Second tile
-- @return Manhattan distance in tiles
function coords.grid_distance_manhattan(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end
-- }}}

-- {{{ coords.grid_distance_chebyshev
-- Calculates Chebyshev distance (diagonal move = 1).
--
-- @param x1, y1 First tile
-- @param x2, y2 Second tile
-- @return Chebyshev distance in tiles
function coords.grid_distance_chebyshev(x1, y1, x2, y2)
    return math.max(math.abs(x2 - x1), math.abs(y2 - y1))
end
-- }}}

-- {{{ coords.tiles_to_world_distance
-- Converts a grid distance (in tiles) to world units.
--
-- @param tile_distance Distance in tiles
-- @param grid Optional grid (uses active_grid if not provided)
-- @return Distance in world units
function coords.tiles_to_world_distance(tile_distance, grid)
    grid = grid or active_grid
    if not grid then
        return tile_distance * 128  -- Default WC3 tile size
    end
    return tile_distance * grid.tile_size
end
-- }}}

-- {{{ coords.world_to_tiles_distance
-- Converts a world distance to tiles.
--
-- @param world_distance Distance in world units
-- @param grid Optional grid (uses active_grid if not provided)
-- @return Distance in tiles (floating point)
function coords.world_to_tiles_distance(world_distance, grid)
    grid = grid or active_grid
    local tile_size = grid and grid.tile_size or 128
    return world_distance / tile_size
end
-- }}}
-- }}}

return coords
