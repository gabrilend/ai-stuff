--[[
Pathfinding Module - Main API

Provides terrain-aware pathfinding for WC3 entities.
Converts terrain data to pathing grids and finds paths
respecting movement types (foot, fly, float, amphibious).

Usage:
    local pathfinding = require("runtime.pathfinding")

    -- Build pathing grid from terrain
    local grid = pathfinding.build_grid(terrain)

    -- Check walkability
    if pathfinding.is_walkable(grid, x, y) then
        -- Path is clear
    end

    -- Find path (provided by 403b)
    local path = pathfinding.find_path(grid, start_x, start_y, goal_x, goal_y)
]]

local pathfinding = {}

-- {{{ Load sub-modules
local grid_mod = require("runtime.pathfinding.grid")
local astar_mod = require("runtime.pathfinding.astar")
local coords_mod = require("runtime.pathfinding.coords")
local movement_mod = require("runtime.pathfinding.movement")
-- }}}

-- {{{ Grid construction exports
pathfinding.build_grid = grid_mod.build_from_terrain
pathfinding.build_grid_cached = grid_mod.build_cached
pathfinding.invalidate_cache = grid_mod.invalidate_cache
-- }}}

-- {{{ Grid accessor exports
pathfinding.get_cell = grid_mod.get_cell
pathfinding.is_walkable = grid_mod.is_walkable
pathfinding.is_flyable = grid_mod.is_flyable
pathfinding.is_buildable = grid_mod.is_buildable
pathfinding.has_water = grid_mod.has_water
pathfinding.get_cliff_level = grid_mod.get_cliff_level
-- }}}

-- {{{ Statistics export
pathfinding.grid_stats = grid_mod.stats
-- }}}

-- {{{ Constants export
pathfinding.TILE_SIZE = grid_mod.TILE_SIZE
pathfinding.WADE_DEPTH = grid_mod.WADE_DEPTH
pathfinding.CLIFF_BLOCK_THRESHOLD = grid_mod.CLIFF_BLOCK_THRESHOLD
-- }}}

-- {{{ A* pathfinding exports
pathfinding.find_path = astar_mod.find_path
pathfinding.find_path_simple = astar_mod.find_path_simple
pathfinding.path_length = astar_mod.path_length
pathfinding.path_to_string = astar_mod.path_to_string
-- }}}

-- {{{ A* internals export (for testing/advanced use)
pathfinding.PriorityQueue = astar_mod.PriorityQueue
pathfinding.manhattan_distance = astar_mod.manhattan_distance
pathfinding.euclidean_distance = astar_mod.euclidean_distance
pathfinding.chebyshev_distance = astar_mod.chebyshev_distance
-- }}}

-- {{{ Coordinate conversion exports
pathfinding.set_grid = coords_mod.set_grid
pathfinding.get_grid = coords_mod.get_grid
pathfinding.clear_grid = coords_mod.clear_grid
pathfinding.world_to_grid = coords_mod.world_to_grid
pathfinding.grid_to_world = coords_mod.grid_to_world
pathfinding.grid_to_world_corner = coords_mod.grid_to_world_corner
pathfinding.is_in_bounds = coords_mod.is_in_bounds
pathfinding.is_tile_in_bounds = coords_mod.is_tile_in_bounds
pathfinding.get_grid_bounds = coords_mod.get_grid_bounds
pathfinding.world_to_grid_clamped = coords_mod.world_to_grid_clamped
pathfinding.path_to_world = coords_mod.path_to_world
pathfinding.path_to_grid = coords_mod.path_to_grid
-- }}}

-- {{{ Distance calculation exports
pathfinding.world_distance = coords_mod.world_distance
pathfinding.world_distance_squared = coords_mod.world_distance_squared
pathfinding.grid_distance_manhattan = coords_mod.grid_distance_manhattan
pathfinding.grid_distance_chebyshev = coords_mod.grid_distance_chebyshev
pathfinding.tiles_to_world_distance = coords_mod.tiles_to_world_distance
pathfinding.world_to_tiles_distance = coords_mod.world_to_tiles_distance
-- }}}

-- {{{ Movement type exports
pathfinding.movement = movement_mod
-- }}}

-- {{{ Movement-aware pathfinding

-- {{{ pathfinding.is_passable
-- Checks if a world position is passable for a movement type.
--
-- @param world_x World X coordinate
-- @param world_y World Y coordinate
-- @param move_type Movement type string (default: "foot")
-- @return boolean true if passable
function pathfinding.is_passable(world_x, world_y, move_type)
    local grid = coords_mod.get_grid()
    if not grid then
        return false
    end

    local gx, gy = coords_mod.world_to_grid(world_x, world_y, grid)
    if not gx then
        return false
    end

    return movement_mod.can_pass(grid, gx, gy, move_type or "foot")
end
-- }}}

-- {{{ pathfinding.find_path_for_type
-- Finds a path between world positions for a specific movement type.
-- Converts coordinates, applies movement rules, and returns world path.
--
-- @param start Table with x, y world coordinates
-- @param goal Table with x, y world coordinates
-- @param move_type Movement type string (default: "foot")
-- @param options Optional A* settings (heuristic, diagonal, max_iterations)
-- @return Array of {x, y} world waypoints, cost, or nil and error message
function pathfinding.find_path_for_type(start, goal, move_type, options)
    move_type = move_type or "foot"
    options = options or {}

    local grid = coords_mod.get_grid()
    if not grid then
        return nil, nil, "No pathing grid set"
    end

    -- Convert world to grid coordinates
    local start_gx, start_gy, start_err = coords_mod.world_to_grid(start.x, start.y, grid)
    if not start_gx then
        return nil, nil, "Start position out of bounds: " .. (start_err or "")
    end

    local goal_gx, goal_gy, goal_err = coords_mod.world_to_grid(goal.x, goal.y, grid)
    if not goal_gx then
        return nil, nil, "Goal position out of bounds: " .. (goal_err or "")
    end

    -- Create movement-specific passability function
    local can_pass = movement_mod.make_can_pass(grid, move_type)

    -- Run A* with movement-aware passability
    local path, cost, err = astar_mod.find_path(
        grid,
        start_gx, start_gy,
        goal_gx, goal_gy,
        {
            can_pass = can_pass,
            heuristic = options.heuristic,
            max_iterations = options.max_iterations,
            diagonal = options.diagonal,
        }
    )

    if not path then
        return nil, nil, err or "No path found"
    end

    -- Convert path back to world coordinates
    local world_path = coords_mod.path_to_world(path, grid)

    return world_path, cost
end
-- }}}
-- }}}

return pathfinding
