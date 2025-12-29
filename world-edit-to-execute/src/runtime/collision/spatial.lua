--[[
Spatial Hash Grid - Efficient Broad-Phase Collision Detection

Partitions world space into fixed-size cells for O(1) average-case
lookup of nearby entities. Entities are inserted into all cells they
overlap based on their collision bounds.

Usage:
    local spatial = require("runtime.collision.spatial")
    spatial.set_cell_size(256)
    spatial.update_all(ecs)  -- Rebuild from all entities
    local nearby = spatial.get_nearby(x, y, radius)
]]

local spatial = {}

-- {{{ Configuration
-- Cell size in world units. Larger = fewer cells, more entities per cell.
-- Rule of thumb: 2-4x largest expected entity radius.
local CELL_SIZE = 256
-- }}}

-- {{{ State
-- The spatial hash table
-- Key: "cell_x,cell_y" string
-- Value: array of entity IDs
local hash = {}

-- Statistics for debugging
local stats = {
    entity_count = 0,
    cell_count = 0,
    max_entities_per_cell = 0,
}
-- }}}

-- {{{ cell_key
-- Generate unique string key for a cell.
-- Using string concat for simplicity; could optimize with integer packing.
local function cell_key(cx, cy)
    return cx .. "," .. cy
end
-- }}}

-- {{{ spatial.world_to_cell
-- Convert world coordinates to cell coordinates.
function spatial.world_to_cell(x, y)
    return math.floor(x / CELL_SIZE), math.floor(y / CELL_SIZE)
end
-- }}}

-- {{{ spatial.cell_to_world
-- Convert cell coordinates to world coordinates (cell center).
function spatial.cell_to_world(cx, cy)
    return (cx + 0.5) * CELL_SIZE, (cy + 0.5) * CELL_SIZE
end
-- }}}

-- {{{ spatial.get_cell
-- Get entities in a specific cell (returns empty table if none).
function spatial.get_cell(cx, cy)
    return hash[cell_key(cx, cy)] or {}
end
-- }}}

-- {{{ insert_into_cell
-- Add entity to a cell.
local function insert_into_cell(cx, cy, entity)
    local key = cell_key(cx, cy)
    if not hash[key] then
        hash[key] = {}
        stats.cell_count = stats.cell_count + 1
    end
    local cell = hash[key]
    cell[#cell + 1] = entity

    if #cell > stats.max_entities_per_cell then
        stats.max_entities_per_cell = #cell
    end
end
-- }}}

-- {{{ spatial.get_occupied_cells
-- Get all cells an entity occupies based on its collision bounds.
-- Entities near cell boundaries may occupy 2-4 cells.
function spatial.get_occupied_cells(x, y, radius)
    local cells = {}

    -- Calculate bounds
    local min_cx = math.floor((x - radius) / CELL_SIZE)
    local max_cx = math.floor((x + radius) / CELL_SIZE)
    local min_cy = math.floor((y - radius) / CELL_SIZE)
    local max_cy = math.floor((y + radius) / CELL_SIZE)

    -- Collect all cells the entity touches
    for cx = min_cx, max_cx do
        for cy = min_cy, max_cy do
            cells[#cells + 1] = {cx, cy}
        end
    end

    return cells
end
-- }}}

-- {{{ spatial.update_all
-- Rebuild entire spatial hash from scratch.
-- Simple approach: clear and re-insert all entities.
-- Called once per frame before collision queries.
function spatial.update_all(ecs)
    -- Clear existing hash
    hash = {}
    stats.entity_count = 0
    stats.cell_count = 0
    stats.max_entities_per_cell = 0

    -- Insert all entities with collision and position components
    for entity in ecs.query_single("collision") do
        local pos = ecs.get_component(entity, "position")
        local col = ecs.get_component(entity, "collision")

        if pos and col then
            -- Get radius (use max of radius, width/2, height/2)
            local radius = col.radius or 0
            if col.shape == "rect" then
                -- Use half-diagonal for rect bounding
                radius = math.sqrt(col.width * col.width + col.height * col.height) / 2
            end

            -- Insert into all occupied cells
            local cells = spatial.get_occupied_cells(pos.x, pos.y, radius)
            for _, cell in ipairs(cells) do
                insert_into_cell(cell[1], cell[2], entity)
            end

            stats.entity_count = stats.entity_count + 1
        end
    end
end
-- }}}

-- {{{ spatial.get_nearby
-- Get all entities potentially within radius of a point.
-- Returns candidates only - caller must do precise collision check.
-- Uses seen table to avoid duplicates from multi-cell entities.
function spatial.get_nearby(x, y, radius)
    local results = {}
    local seen = {}  -- Avoid duplicates from multi-cell entities

    -- Calculate cell range to check
    local min_cx = math.floor((x - radius) / CELL_SIZE)
    local max_cx = math.floor((x + radius) / CELL_SIZE)
    local min_cy = math.floor((y - radius) / CELL_SIZE)
    local max_cy = math.floor((y + radius) / CELL_SIZE)

    -- Collect entities from all relevant cells
    for cx = min_cx, max_cx do
        for cy = min_cy, max_cy do
            local cell = spatial.get_cell(cx, cy)
            for _, entity in ipairs(cell) do
                if not seen[entity] then
                    seen[entity] = true
                    results[#results + 1] = entity
                end
            end
        end
    end

    return results
end
-- }}}

-- {{{ spatial.get_in_rect
-- Get all entities potentially within a rectangle.
-- x, y: center of rectangle
-- width, height: dimensions
function spatial.get_in_rect(x, y, width, height)
    local results = {}
    local seen = {}

    local hw, hh = width / 2, height / 2

    -- Calculate cell range to check
    local min_cx = math.floor((x - hw) / CELL_SIZE)
    local max_cx = math.floor((x + hw) / CELL_SIZE)
    local min_cy = math.floor((y - hh) / CELL_SIZE)
    local max_cy = math.floor((y + hh) / CELL_SIZE)

    -- Collect entities from all relevant cells
    for cx = min_cx, max_cx do
        for cy = min_cy, max_cy do
            local cell = spatial.get_cell(cx, cy)
            for _, entity in ipairs(cell) do
                if not seen[entity] then
                    seen[entity] = true
                    results[#results + 1] = entity
                end
            end
        end
    end

    return results
end
-- }}}

-- {{{ spatial.get_at_point
-- Get all entities in the cell containing a point.
-- Useful for point queries with small search radius.
function spatial.get_at_point(x, y)
    local cx, cy = spatial.world_to_cell(x, y)
    return spatial.get_cell(cx, cy)
end
-- }}}

-- {{{ spatial.set_cell_size
-- Configure cell size (call before update_all).
-- Clears existing hash since cell assignments would be invalid.
function spatial.set_cell_size(size)
    if size <= 0 then
        error("Cell size must be positive")
    end
    CELL_SIZE = size
    hash = {}
    stats.cell_count = 0
end
-- }}}

-- {{{ spatial.get_cell_size
-- Get current cell size.
function spatial.get_cell_size()
    return CELL_SIZE
end
-- }}}

-- {{{ spatial.clear
-- Clear all data from the spatial hash.
function spatial.clear()
    hash = {}
    stats.entity_count = 0
    stats.cell_count = 0
    stats.max_entities_per_cell = 0
end
-- }}}

-- {{{ spatial.get_stats
-- Get statistics about the spatial hash.
function spatial.get_stats()
    return {
        entity_count = stats.entity_count,
        cell_count = stats.cell_count,
        max_entities_per_cell = stats.max_entities_per_cell,
        cell_size = CELL_SIZE,
    }
end
-- }}}

-- {{{ spatial.debug_dump
-- Dump spatial hash contents for debugging.
function spatial.debug_dump()
    local lines = {}
    lines[#lines + 1] = "=== Spatial Hash Debug ==="
    lines[#lines + 1] = string.format("Cell size: %d", CELL_SIZE)
    lines[#lines + 1] = string.format("Cells: %d, Entities: %d", stats.cell_count, stats.entity_count)
    lines[#lines + 1] = ""

    for key, cell in pairs(hash) do
        lines[#lines + 1] = string.format("Cell %s: %d entities", key, #cell)
    end

    return table.concat(lines, "\n")
end
-- }}}

return spatial
