-- Spatial Index Module
-- Grid-based spatial indexing for efficient proximity queries.
-- Used by ObjectRegistry for get_objects_in_radius and similar queries.
-- Compatible with LuaJIT and Lua 5.3+.

local SpatialIndex = {}
SpatialIndex.__index = SpatialIndex

-- {{{ new
-- Create a new spatial index with specified cell size.
-- cell_size: Size of each grid cell in game units (default 512).
-- Larger cells = fewer cells to check but more objects per cell.
-- Smaller cells = more precise but more overhead for large queries.
function SpatialIndex.new(cell_size)
    local self = setmetatable({}, SpatialIndex)
    self.cell_size = cell_size or 512
    self.cells = {}
    self.count = 0
    return self
end
-- }}}

-- {{{ _cell_key
-- Calculate the cell key for a given position.
-- Returns a string key like "3,-2" for the cell containing (x, y).
function SpatialIndex:_cell_key(x, y)
    local cx = math.floor(x / self.cell_size)
    local cy = math.floor(y / self.cell_size)
    return cx .. "," .. cy
end
-- }}}

-- {{{ _cell_coords
-- Calculate cell coordinates (integers) for a position.
-- Used internally for iteration over cell ranges.
function SpatialIndex:_cell_coords(x, y)
    return math.floor(x / self.cell_size), math.floor(y / self.cell_size)
end
-- }}}

-- {{{ insert
-- Insert an object into the spatial index.
-- Object must have position.x and position.y fields.
function SpatialIndex:insert(object)
    if not object.position then
        error("Object must have position field")
    end
    if not object.position.x or not object.position.y then
        error("Object position must have x and y fields")
    end

    local key = self:_cell_key(object.position.x, object.position.y)

    if not self.cells[key] then
        self.cells[key] = {}
    end

    table.insert(self.cells[key], object)
    self.count = self.count + 1
end
-- }}}

-- {{{ remove
-- Remove an object from the spatial index.
-- Returns true if found and removed, false otherwise.
-- Note: Uses reference equality, not value comparison.
function SpatialIndex:remove(object)
    if not object.position then
        return false
    end

    local key = self:_cell_key(object.position.x, object.position.y)
    local cell = self.cells[key]

    if not cell then
        return false
    end

    for i, obj in ipairs(cell) do
        if obj == object then
            table.remove(cell, i)
            self.count = self.count - 1
            return true
        end
    end

    return false
end
-- }}}

-- {{{ query_radius
-- Find all objects within a circular area.
-- x, y: Center of the search area.
-- radius: Search radius in game units.
-- Returns: Array of objects within the radius.
function SpatialIndex:query_radius(x, y, radius)
    local result = {}
    local radius_sq = radius * radius

    -- Calculate bounding cells
    local min_cx, min_cy = self:_cell_coords(x - radius, y - radius)
    local max_cx, max_cy = self:_cell_coords(x + radius, y + radius)

    -- Check all cells that might contain objects in radius
    for cx = min_cx, max_cx do
        for cy = min_cy, max_cy do
            local key = cx .. "," .. cy
            local cell = self.cells[key]

            if cell then
                for _, obj in ipairs(cell) do
                    local dx = obj.position.x - x
                    local dy = obj.position.y - y
                    local dist_sq = dx * dx + dy * dy

                    if dist_sq <= radius_sq then
                        result[#result + 1] = obj
                    end
                end
            end
        end
    end

    return result
end
-- }}}

-- {{{ query_rect
-- Find all objects within a rectangular area.
-- left, bottom, right, top: Bounds of the search area.
-- Returns: Array of objects within the rectangle.
function SpatialIndex:query_rect(left, bottom, right, top)
    local result = {}

    -- Calculate covered cells
    local min_cx, min_cy = self:_cell_coords(left, bottom)
    local max_cx, max_cy = self:_cell_coords(right, top)

    -- Check all cells that might contain objects in rect
    for cx = min_cx, max_cx do
        for cy = min_cy, max_cy do
            local key = cx .. "," .. cy
            local cell = self.cells[key]

            if cell then
                for _, obj in ipairs(cell) do
                    local px, py = obj.position.x, obj.position.y

                    if px >= left and px <= right and py >= bottom and py <= top then
                        result[#result + 1] = obj
                    end
                end
            end
        end
    end

    return result
end
-- }}}

-- {{{ query_point
-- Find all objects at a specific cell (useful for exact position checks).
-- x, y: Position to query.
-- Returns: Array of objects in the same cell as (x, y).
function SpatialIndex:query_point(x, y)
    local key = self:_cell_key(x, y)
    local cell = self.cells[key]

    if not cell then
        return {}
    end

    -- Return a copy to prevent external modification
    local result = {}
    for i, obj in ipairs(cell) do
        result[i] = obj
    end
    return result
end
-- }}}

-- {{{ clear
-- Remove all objects from the index.
function SpatialIndex:clear()
    self.cells = {}
    self.count = 0
end
-- }}}

-- {{{ get_count
-- Return the total number of indexed objects.
function SpatialIndex:get_count()
    return self.count
end
-- }}}

-- {{{ get_cell_count
-- Return the number of non-empty cells.
function SpatialIndex:get_cell_count()
    local count = 0
    for _ in pairs(self.cells) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ debug_info
-- Return debug information about the index state.
function SpatialIndex:debug_info()
    local cell_count = self:get_cell_count()
    local max_cell_size = 0
    local min_cell_size = math.huge

    for _, cell in pairs(self.cells) do
        local size = #cell
        if size > max_cell_size then max_cell_size = size end
        if size < min_cell_size then min_cell_size = size end
    end

    if cell_count == 0 then
        min_cell_size = 0
    end

    return {
        cell_size = self.cell_size,
        object_count = self.count,
        cell_count = cell_count,
        avg_per_cell = cell_count > 0 and (self.count / cell_count) or 0,
        max_per_cell = max_cell_size,
        min_per_cell = min_cell_size,
    }
end
-- }}}

return SpatialIndex
