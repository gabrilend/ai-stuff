--[[
Movement Type Support for Pathfinding

Defines WC3 movement types (foot, fly, float, hover, amphibious) and provides
per-type passability rules for the A* pathfinding algorithm. Different unit
types have different terrain restrictions based on their movement capabilities.

Movement Types:
- foot/horse: Standard ground units, blocked by deep water and cliffs
- fly: Air units, bypass all terrain obstacles
- float: Water-only units (ships), blocked by land, need deep water
- hover: Ground units that can cross shallow water
- amphibious: Units that can walk and swim (Naga)
]]

local movement = {}

-- {{{ Movement type definitions
-- Each type defines what terrain the unit can traverse
local MOVEMENT_TYPES = {
    -- {{{ foot
    -- Standard ground unit (footmen, grunts, archers)
    foot = {
        can_walk = true,      -- Can traverse walkable land
        can_fly = false,      -- Cannot bypass obstacles
        can_swim = false,     -- Cannot swim in deep water
        can_hover = false,    -- Cannot hover over water
        max_wade_depth = 64,  -- Can wade through shallow water (up to WADE_DEPTH)
    },
    -- }}}

    -- {{{ horse
    -- Mounted ground unit (knights, raiders) - same as foot, different animation
    horse = {
        can_walk = true,
        can_fly = false,
        can_swim = false,
        can_hover = false,
        max_wade_depth = 64,
    },
    -- }}}

    -- {{{ fly
    -- Air unit (gryphon, dragon, hippogryph)
    -- Can pass over any terrain within map bounds
    fly = {
        can_walk = true,       -- Can land on walkable ground
        can_fly = true,        -- Can bypass all terrain
        can_swim = true,       -- Can pass over water
        can_hover = true,      -- Effectively hovers
        max_wade_depth = math.huge,  -- Water depth irrelevant
    },
    -- }}}

    -- {{{ float
    -- Water-only unit (battleship, frigate, transport)
    -- Cannot traverse land, requires deep water
    float = {
        can_walk = false,      -- Cannot traverse land
        can_fly = false,       -- Cannot fly
        can_swim = true,       -- Can swim
        can_hover = false,     -- Cannot hover
        max_wade_depth = 0,    -- Cannot wade (no legs)
        min_swim_depth = 128,  -- Needs water deeper than this to float
    },
    -- }}}

    -- {{{ hover
    -- Hovering ground unit (destroyer, shades)
    -- Can cross shallow water but not deep
    hover = {
        can_walk = true,       -- Can traverse land
        can_fly = false,       -- Cannot fly
        can_swim = false,      -- Cannot swim in deep water
        can_hover = true,      -- Hovers over shallow water
        max_wade_depth = 256,  -- Can hover over moderately deep water
    },
    -- }}}

    -- {{{ amphibious
    -- Land and water unit (Naga, sea turtle)
    -- Can walk on land and swim in any water
    amphibious = {
        can_walk = true,       -- Can traverse land
        can_fly = false,       -- Cannot fly
        can_swim = true,       -- Can swim in any depth
        can_hover = false,     -- Walks/swims, doesn't hover
        max_wade_depth = math.huge,  -- Can swim in any depth
    },
    -- }}}
}
-- }}}

-- {{{ Passability checking

-- {{{ movement.can_pass
-- Checks if a movement type can pass through a grid cell.
--
-- @param grid Pathing grid from grid.build_from_terrain()
-- @param x Grid X coordinate (tile index)
-- @param y Grid Y coordinate (tile index)
-- @param move_type Movement type string (default: "foot")
-- @return boolean true if passable
function movement.can_pass(grid, x, y, move_type)
    -- Validate grid and get cell
    if not grid or not grid.cells then
        return false
    end
    local row = grid.cells[y]
    if not row then
        return false
    end
    local cell = row[x]
    if not cell then
        return false  -- Out of bounds
    end

    -- Get movement type definition, default to foot
    local mt = MOVEMENT_TYPES[move_type]
    if not mt then
        mt = MOVEMENT_TYPES.foot
    end

    -- Flying units can pass anywhere within grid bounds
    if mt.can_fly then
        return true
    end

    -- Handle water tiles
    if cell.water then
        local depth = cell.water_depth or 0

        -- Floating units need minimum water depth
        if mt.min_swim_depth then
            if depth < mt.min_swim_depth then
                -- Water too shallow for floating unit
                return false
            end
            -- Deep enough to float
            return true
        end

        -- Swimming units can pass any water
        if mt.can_swim then
            return true
        end

        -- Hovering units can cross water up to hover depth
        if mt.can_hover then
            -- max_wade_depth for hover represents hover limit
            if depth <= mt.max_wade_depth then
                return true
            else
                return false  -- Too deep to hover over
            end
        end

        -- Non-swimming, non-hovering units can only wade
        if depth <= mt.max_wade_depth then
            return true  -- Shallow enough to wade
        else
            return false  -- Too deep to wade
        end
    end

    -- Handle land tiles
    if not cell.water then
        -- Floating units cannot traverse land at all
        if not mt.can_walk then
            return false
        end

        -- Check if ground is walkable (considers cliffs, boundaries, etc.)
        if not cell.walkable then
            return false
        end

        -- Walkable land for walking unit
        return true
    end

    -- Shouldn't reach here, but default to impassable
    return false
end
-- }}}

-- {{{ movement.make_can_pass
-- Creates a can_pass callback function for use with A* algorithm.
-- The returned function captures the grid and movement type, providing
-- the signature expected by astar.find_path().
--
-- @param grid Pathing grid
-- @param move_type Movement type string
-- @return function(x, y) -> boolean
function movement.make_can_pass(grid, move_type)
    return function(x, y)
        return movement.can_pass(grid, x, y, move_type)
    end
end
-- }}}
-- }}}

-- {{{ Movement type queries

-- {{{ movement.get_type
-- Returns the definition for a movement type.
--
-- @param name Movement type name
-- @return Table with movement capabilities, or nil if not found
function movement.get_type(name)
    return MOVEMENT_TYPES[name]
end
-- }}}

-- {{{ movement.is_valid_type
-- Checks if a movement type name is valid.
--
-- @param name Movement type name
-- @return boolean
function movement.is_valid_type(name)
    return MOVEMENT_TYPES[name] ~= nil
end
-- }}}

-- {{{ movement.list_types
-- Returns a sorted list of all movement type names.
--
-- @return Array of movement type names
function movement.list_types()
    local names = {}
    for name, _ in pairs(MOVEMENT_TYPES) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end
-- }}}

-- {{{ movement.describe_type
-- Returns a human-readable description of a movement type.
--
-- @param name Movement type name
-- @return Description string
function movement.describe_type(name)
    local mt = MOVEMENT_TYPES[name]
    if not mt then
        return "Unknown movement type: " .. tostring(name)
    end

    local capabilities = {}
    if mt.can_walk then capabilities[#capabilities + 1] = "walk" end
    if mt.can_fly then capabilities[#capabilities + 1] = "fly" end
    if mt.can_swim then capabilities[#capabilities + 1] = "swim" end
    if mt.can_hover then capabilities[#capabilities + 1] = "hover" end

    local desc = name .. ": " .. table.concat(capabilities, ", ")

    if mt.max_wade_depth and mt.max_wade_depth < math.huge then
        desc = desc .. string.format(" (wade depth: %d)", mt.max_wade_depth)
    end
    if mt.min_swim_depth then
        desc = desc .. string.format(" (min swim: %d)", mt.min_swim_depth)
    end

    return desc
end
-- }}}
-- }}}

-- {{{ Custom movement type registration

-- {{{ movement.register
-- Registers a custom movement type.
-- Returns false if the type already exists.
--
-- @param name Movement type name
-- @param definition Table with movement capabilities
-- @return boolean success, string error message
function movement.register(name, definition)
    if MOVEMENT_TYPES[name] then
        return false, "Movement type already exists: " .. name
    end

    if type(definition) ~= "table" then
        return false, "Definition must be a table"
    end

    -- Apply defaults for missing fields
    local mt = {
        can_walk = definition.can_walk or false,
        can_fly = definition.can_fly or false,
        can_swim = definition.can_swim or false,
        can_hover = definition.can_hover or false,
        max_wade_depth = definition.max_wade_depth or 0,
    }

    -- Copy optional fields
    if definition.min_swim_depth then
        mt.min_swim_depth = definition.min_swim_depth
    end

    MOVEMENT_TYPES[name] = mt
    return true
end
-- }}}

-- {{{ movement.unregister
-- Removes a custom movement type.
-- Cannot remove built-in types.
--
-- @param name Movement type name
-- @return boolean success
function movement.unregister(name)
    local builtins = { "foot", "horse", "fly", "float", "hover", "amphibious" }
    for _, builtin in ipairs(builtins) do
        if name == builtin then
            return false, "Cannot unregister built-in type: " .. name
        end
    end

    if not MOVEMENT_TYPES[name] then
        return false, "Movement type not found: " .. name
    end

    MOVEMENT_TYPES[name] = nil
    return true
end
-- }}}
-- }}}

-- {{{ Convenience functions

-- {{{ movement.can_traverse_water
-- Checks if a movement type can traverse water of a given depth.
--
-- @param move_type Movement type string
-- @param depth Water depth
-- @return boolean
function movement.can_traverse_water(move_type, depth)
    local mt = MOVEMENT_TYPES[move_type]
    if not mt then
        mt = MOVEMENT_TYPES.foot
    end

    -- Flying units pass all water
    if mt.can_fly then
        return true
    end

    -- Check minimum depth for floating units
    if mt.min_swim_depth then
        return depth >= mt.min_swim_depth
    end

    -- Swimming units pass all water
    if mt.can_swim then
        return true
    end

    -- Check wade/hover depth
    return depth <= mt.max_wade_depth
end
-- }}}

-- {{{ movement.can_traverse_land
-- Checks if a movement type can traverse land.
--
-- @param move_type Movement type string
-- @return boolean
function movement.can_traverse_land(move_type)
    local mt = MOVEMENT_TYPES[move_type]
    if not mt then
        mt = MOVEMENT_TYPES.foot
    end

    return mt.can_walk or mt.can_fly
end
-- }}}

-- {{{ movement.is_flying
-- Checks if a movement type bypasses terrain.
--
-- @param move_type Movement type string
-- @return boolean
function movement.is_flying(move_type)
    local mt = MOVEMENT_TYPES[move_type]
    return mt and mt.can_fly or false
end
-- }}}
-- }}}

-- {{{ Exports
movement.TYPES = MOVEMENT_TYPES
-- }}}

return movement
