--[[
Pathing Grid Construction

Converts w3e terrain data into a pathing grid data structure suitable for
pathfinding algorithms. Each cell contains walkability and other pathing
properties derived from terrain tile data.

WC3 terrain tiles are 128 world units. Height differences between adjacent
tiles with different cliff levels create impassable barriers unless a ramp
connects them.
]]

local grid = {}

-- {{{ Constants
-- WC3 tile size in world units
local TILE_SIZE = 128

-- Water depth below which units can wade (shallow water)
-- Above this depth, only amphibious/swimming units can pass
local WADE_DEPTH = 64

-- Cliff level difference that blocks movement (without ramp)
local CLIFF_BLOCK_THRESHOLD = 1
-- }}}

-- {{{ Cell constructor
-- {{{ make_cell
-- Create a default pathing cell with all permissions enabled.
local function make_cell()
    return {
        walkable = true,      -- Ground units can traverse
        flyable = true,       -- Air units can traverse (always true)
        buildable = true,     -- Buildings can be placed
        water = false,        -- Tile contains water
        water_depth = 0,      -- Depth of water (affects wading vs swimming)
        cliff_level = 0,      -- Cliff height level for ramp detection
        is_ramp = false,      -- Tile is a ramp connecting cliff levels
        is_blight = false,    -- Tile is blighted (affects undead building)
    }
end
-- }}}
-- }}}

-- {{{ Walkability determination
-- {{{ is_tile_walkable
-- Determines if a tile is walkable based on w3e tile data and neighbors.
-- A tile is NOT walkable if:
-- 1. It has deep water (above wade depth)
-- 2. It has a cliff edge to an adjacent tile without a ramp
-- 3. It's a map boundary tile
--
-- @param tile The current tile data from terrain:get_tile()
-- @param neighbors Array of adjacent tile data (4 cardinal directions)
-- @return boolean
local function is_tile_walkable(tile, neighbors)
    if not tile then
        return false
    end

    -- Boundary tiles are not walkable
    if tile.is_boundary or tile.boundary then
        return false
    end

    -- Deep water blocks ground units
    if tile.has_water and tile.water_level > WADE_DEPTH then
        return false
    end

    -- Check cliff edges with neighbors
    -- If any neighbor has a different cliff level and neither tile is a ramp,
    -- there's an impassable cliff edge
    local my_level = tile.layer_height or 0

    for _, neighbor in ipairs(neighbors) do
        if neighbor then
            local their_level = neighbor.layer_height or 0
            local level_diff = math.abs(my_level - their_level)

            if level_diff >= CLIFF_BLOCK_THRESHOLD then
                -- Different cliff levels - check for ramp
                local my_ramp = tile.is_ramp or false
                local their_ramp = neighbor.is_ramp or false

                -- If neither side is a ramp, it's an impassable cliff
                if not my_ramp and not their_ramp then
                    return false
                end
            end
        end
    end

    return true
end
-- }}}

-- {{{ is_tile_buildable
-- Determines if a tile can have buildings placed on it.
-- A tile is NOT buildable if:
-- 1. It has water
-- 2. It's a map boundary
-- 3. It's on a ramp (buildings can't be placed on ramps)
--
-- @param tile The tile data from terrain:get_tile()
-- @return boolean
local function is_tile_buildable(tile)
    if not tile then
        return false
    end

    -- Boundary tiles can't be built on
    if tile.is_boundary or tile.boundary then
        return false
    end

    -- Water tiles can't be built on
    if tile.has_water then
        return false
    end

    -- Ramps can't be built on
    if tile.is_ramp then
        return false
    end

    return true
end
-- }}}
-- }}}

-- {{{ Neighbor collection
-- {{{ get_neighbor_tiles
-- Get the 4 cardinal neighbor tiles for a given position.
--
-- @param terrain The terrain object
-- @param x Grid X coordinate
-- @param y Grid Y coordinate
-- @return Array of neighbor tile data (may contain nils for edges)
local function get_neighbor_tiles(terrain, x, y)
    local neighbors = {}
    local dirs = {
        {0, -1},  -- South
        {0, 1},   -- North
        {-1, 0},  -- West
        {1, 0},   -- East
    }

    for _, dir in ipairs(dirs) do
        local nx, ny = x + dir[1], y + dir[2]
        -- get_tile returns nil for out-of-bounds, which is fine
        neighbors[#neighbors + 1] = terrain:get_tile(nx, ny)
    end

    return neighbors
end
-- }}}
-- }}}

-- {{{ Grid construction
-- {{{ grid.build_from_terrain
-- Build a pathing grid from parsed w3e terrain data.
--
-- The grid uses the same coordinate system as the terrain:
-- - X increases to the east
-- - Y increases to the north
-- - (0,0) is the southwest corner
--
-- @param terrain Terrain object from w3e.parse()
-- @return Pathing grid table
function grid.build_from_terrain(terrain)
    if not terrain then
        error("build_from_terrain: terrain is nil")
    end

    local result = {
        width = terrain.width,
        height = terrain.height,
        tile_size = TILE_SIZE,
        -- World coordinate offset of grid origin
        -- Terrain offset is typically negative (centered at 0,0)
        offset_x = terrain.offset_x,
        offset_y = terrain.offset_y,
        cells = {},
    }

    -- First pass: create all cells with basic properties from tile data
    for y = 0, terrain.height - 1 do
        result.cells[y] = {}
        for x = 0, terrain.width - 1 do
            local tile = terrain:get_tile(x, y)
            local cell = make_cell()

            if tile then
                cell.cliff_level = tile.layer_height or 0
                cell.water = tile.has_water or false
                cell.water_depth = tile.water_level or 0
                cell.is_ramp = tile.is_ramp or false
                cell.is_blight = tile.is_blight or false
                cell.flyable = true  -- Air units can go anywhere
            else
                -- Out of bounds or invalid tile - mark as impassable
                cell.walkable = false
                cell.buildable = false
            end

            result.cells[y][x] = cell
        end
    end

    -- Second pass: determine walkability (needs neighbor data)
    for y = 0, terrain.height - 1 do
        for x = 0, terrain.width - 1 do
            local tile = terrain:get_tile(x, y)
            local neighbors = get_neighbor_tiles(terrain, x, y)
            local cell = result.cells[y][x]

            cell.walkable = is_tile_walkable(tile, neighbors)
            cell.buildable = is_tile_buildable(tile)
        end
    end

    return result
end
-- }}}
-- }}}

-- {{{ Grid accessors
-- {{{ grid.get_cell
-- Get a cell from the pathing grid with bounds checking.
--
-- @param pathing_grid The pathing grid
-- @param x Grid X coordinate
-- @param y Grid Y coordinate
-- @return Cell table or nil if out of bounds
function grid.get_cell(pathing_grid, x, y)
    if not pathing_grid then
        return nil
    end
    if x < 0 or x >= pathing_grid.width then
        return nil
    end
    if y < 0 or y >= pathing_grid.height then
        return nil
    end
    local row = pathing_grid.cells[y]
    return row and row[x]
end
-- }}}

-- {{{ grid.is_walkable
-- Check if a grid cell is walkable.
--
-- @param pathing_grid The pathing grid
-- @param x Grid X coordinate
-- @param y Grid Y coordinate
-- @return boolean
function grid.is_walkable(pathing_grid, x, y)
    local cell = grid.get_cell(pathing_grid, x, y)
    return cell and cell.walkable or false
end
-- }}}

-- {{{ grid.is_flyable
-- Check if a grid cell is flyable.
--
-- @param pathing_grid The pathing grid
-- @param x Grid X coordinate
-- @param y Grid Y coordinate
-- @return boolean (always true for valid cells - air units can go anywhere)
function grid.is_flyable(pathing_grid, x, y)
    local cell = grid.get_cell(pathing_grid, x, y)
    return cell and cell.flyable or false
end
-- }}}

-- {{{ grid.is_buildable
-- Check if a grid cell is buildable.
--
-- @param pathing_grid The pathing grid
-- @param x Grid X coordinate
-- @param y Grid Y coordinate
-- @return boolean
function grid.is_buildable(pathing_grid, x, y)
    local cell = grid.get_cell(pathing_grid, x, y)
    return cell and cell.buildable or false
end
-- }}}

-- {{{ grid.has_water
-- Check if a grid cell has water.
--
-- @param pathing_grid The pathing grid
-- @param x Grid X coordinate
-- @param y Grid Y coordinate
-- @return boolean
function grid.has_water(pathing_grid, x, y)
    local cell = grid.get_cell(pathing_grid, x, y)
    return cell and cell.water or false
end
-- }}}

-- {{{ grid.get_cliff_level
-- Get the cliff level at a grid cell.
--
-- @param pathing_grid The pathing grid
-- @param x Grid X coordinate
-- @param y Grid Y coordinate
-- @return number or nil if out of bounds
function grid.get_cliff_level(pathing_grid, x, y)
    local cell = grid.get_cell(pathing_grid, x, y)
    return cell and cell.cliff_level
end
-- }}}
-- }}}

-- {{{ Grid caching
-- Cache for rebuilt grids (terrain rarely changes during gameplay)
local cached_grid = nil
local cached_terrain = nil

-- {{{ grid.build_cached
-- Build a pathing grid with caching.
-- Returns cached grid if terrain hasn't changed.
--
-- @param terrain The terrain object
-- @return Pathing grid table
function grid.build_cached(terrain)
    -- Simple identity check - same terrain object means same data
    if cached_grid and cached_terrain == terrain then
        return cached_grid
    end

    cached_grid = grid.build_from_terrain(terrain)
    cached_terrain = terrain
    return cached_grid
end
-- }}}

-- {{{ grid.invalidate_cache
-- Clear the cached pathing grid.
-- Call this if terrain is modified during gameplay.
function grid.invalidate_cache()
    cached_grid = nil
    cached_terrain = nil
end
-- }}}
-- }}}

-- {{{ Statistics
-- {{{ grid.stats
-- Get statistics about a pathing grid.
--
-- @param pathing_grid The pathing grid
-- @return Stats table
function grid.stats(pathing_grid)
    local stats = {
        width = pathing_grid.width,
        height = pathing_grid.height,
        total_cells = pathing_grid.width * pathing_grid.height,
        walkable_cells = 0,
        buildable_cells = 0,
        water_cells = 0,
        ramp_cells = 0,
        blight_cells = 0,
        cliff_levels = {},
    }

    for y = 0, pathing_grid.height - 1 do
        for x = 0, pathing_grid.width - 1 do
            local cell = pathing_grid.cells[y][x]
            if cell.walkable then
                stats.walkable_cells = stats.walkable_cells + 1
            end
            if cell.buildable then
                stats.buildable_cells = stats.buildable_cells + 1
            end
            if cell.water then
                stats.water_cells = stats.water_cells + 1
            end
            if cell.is_ramp then
                stats.ramp_cells = stats.ramp_cells + 1
            end
            if cell.is_blight then
                stats.blight_cells = stats.blight_cells + 1
            end

            -- Track cliff level distribution
            local level = cell.cliff_level
            stats.cliff_levels[level] = (stats.cliff_levels[level] or 0) + 1
        end
    end

    return stats
end
-- }}}
-- }}}

-- {{{ Constants export
grid.TILE_SIZE = TILE_SIZE
grid.WADE_DEPTH = WADE_DEPTH
grid.CLIFF_BLOCK_THRESHOLD = CLIFF_BLOCK_THRESHOLD
-- }}}

return grid
