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

return pathfinding
