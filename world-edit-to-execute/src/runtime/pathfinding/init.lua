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

return pathfinding
