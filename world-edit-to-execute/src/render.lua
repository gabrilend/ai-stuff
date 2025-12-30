-- src/render.lua
-- {{{ render module
-- High-level rendering interface wrapping the C bridge (508c)
--
-- This module provides entity-centric operations instead of raw slot manipulation.
-- It tracks entity_id -> slot_index mappings automatically.
--
-- Usage:
--   local render = require("render_lua")
--   render.create(entity_id, "cube", x, y, z)
--   render.move(entity_id, new_x, new_y, new_z)
--   render.destroy(entity_id)

local render_c = require("render")  -- C module via bridge

local render = {}

-- {{{ Entity tracking
-- Maps entity_id -> slot_index for O(1) lookup
local entity_slots = {}

-- Reverse mapping: slot_index -> entity_id (for cleanup validation)
local slot_entities = {}
-- }}}

-- {{{ Mesh type name to ID mapping
render.MESH_TYPES = {
    circle = render_c.MESH_CIRCLE,
    cube = render_c.MESH_CUBE,
    triangle = render_c.MESH_TRIANGLE,
    cylinder = render_c.MESH_CYLINDER,
}
-- }}}

-- {{{ Team colors (WC3-style palette)
render.TEAM_COLORS = {
    [0] = {255, 3, 3},       -- Red
    [1] = {0, 66, 255},      -- Blue
    [2] = {28, 230, 185},    -- Teal
    [3] = {84, 0, 129},      -- Purple
    [4] = {255, 252, 1},     -- Yellow
    [5] = {254, 138, 14},    -- Orange
    [6] = {32, 192, 0},      -- Green
    [7] = {229, 91, 176},    -- Pink
    [8] = {149, 150, 151},   -- Gray
    [9] = {126, 191, 241},   -- Light Blue
    [10] = {16, 98, 70},     -- Dark Green
    [11] = {78, 42, 4},      -- Brown
}
-- }}}

-- {{{ render.create
-- Creates a render entity linked to the given entity_id.
-- @param entity_id  Unique game entity identifier
-- @param mesh_type  String: "circle", "cube", "triangle", "cylinder"
-- @param x, y, z    World position
-- @return slot_index on success, nil on failure
function render.create(entity_id, mesh_type, x, y, z)
    -- Validate entity isn't already tracked
    if entity_slots[entity_id] then
        print("[render.lua] Warning: entity " .. entity_id .. " already has a slot")
        return entity_slots[entity_id]
    end

    -- Resolve mesh type
    local mesh_id = render.MESH_TYPES[mesh_type] or render_c.MESH_CUBE

    -- Create via C bridge
    local slot = render_c.create_entity(entity_id, mesh_id, x or 0, y or 0, z or 0)
    if slot < 0 then
        print("[render.lua] Error: failed to allocate slot for entity " .. entity_id)
        return nil
    end

    -- Track the mapping
    entity_slots[entity_id] = slot
    slot_entities[slot] = entity_id

    return slot
end
-- }}}

-- {{{ render.destroy
-- Destroys the render entity for the given entity_id.
-- @param entity_id  Entity to remove from rendering
function render.destroy(entity_id)
    local slot = entity_slots[entity_id]
    if not slot then
        return  -- Already destroyed or never created
    end

    -- Clean up via C bridge
    render_c.destroy_entity(slot)

    -- Remove from tracking
    slot_entities[slot] = nil
    entity_slots[entity_id] = nil
end
-- }}}

-- {{{ render.move
-- Updates entity position.
-- @param entity_id  Entity to move
-- @param x, y, z    New world position
function render.move(entity_id, x, y, z)
    local slot = entity_slots[entity_id]
    if slot then
        render_c.set_position(slot, x, y, z)
    end
end
-- }}}

-- {{{ render.set_color
-- Updates entity color.
-- @param entity_id  Entity to color
-- @param r, g, b    RGB values (0-255)
-- @param a          Alpha (optional, defaults to 255)
function render.set_color(entity_id, r, g, b, a)
    local slot = entity_slots[entity_id]
    if slot then
        render_c.set_color(slot, r, g, b, a or 255)
    end
end
-- }}}

-- {{{ render.select
-- Sets entity selection state (shows selection ring).
-- @param entity_id  Entity to select/deselect
-- @param selected   Boolean selection state
function render.select(entity_id, selected)
    local slot = entity_slots[entity_id]
    if slot then
        render_c.set_selected(slot, selected)
    end
end
-- }}}

-- {{{ render.show
-- Sets entity visibility.
-- @param entity_id  Entity to show/hide
-- @param visible    Boolean visibility state
function render.show(entity_id, visible)
    local slot = entity_slots[entity_id]
    if slot then
        render_c.set_visible(slot, visible)
    end
end
-- }}}

-- {{{ render.scale
-- Sets entity scale.
-- @param entity_id  Entity to scale
-- @param scale      Uniform scale factor
function render.scale(entity_id, scale)
    local slot = entity_slots[entity_id]
    if slot then
        render_c.set_scale(slot, scale)
    end
end
-- }}}

-- {{{ render.set_team
-- Sets entity team (for team coloring).
-- @param entity_id  Entity to set team for
-- @param team_id    Team index (0-11), or -1 for no team
function render.set_team(entity_id, team_id)
    local slot = entity_slots[entity_id]
    if slot then
        render_c.set_team(slot, team_id)

        -- Optionally apply team color automatically
        local color = render.TEAM_COLORS[team_id]
        if color then
            render_c.set_color(slot, color[1], color[2], color[3])
        end
    end
end
-- }}}

-- {{{ render.rotate
-- Sets entity rotation angles.
-- @param entity_id  Entity to rotate
-- @param rotation   Clock rotation (around diagonal axis)
-- @param spin       In-place spin (around Y axis)
-- @param facing     Direction facing (for sprites)
function render.rotate(entity_id, rotation, spin, facing)
    local slot = entity_slots[entity_id]
    if slot then
        render_c.set_rotation(slot, rotation or 0, spin or 0, facing or 0)
    end
end
-- }}}

-- {{{ render.set_mesh
-- Changes entity mesh type.
-- @param entity_id  Entity to modify
-- @param mesh_type  String: "circle", "cube", "triangle", "cylinder"
function render.set_mesh(entity_id, mesh_type)
    local slot = entity_slots[entity_id]
    if slot then
        local mesh_id = render.MESH_TYPES[mesh_type] or render_c.MESH_CUBE
        render_c.set_mesh(slot, mesh_id)
    end
end
-- }}}

-- {{{ render.get_slot
-- Gets the slot index for an entity (for low-level access).
-- @param entity_id  Entity to query
-- @return slot_index or nil
function render.get_slot(entity_id)
    return entity_slots[entity_id]
end
-- }}}

-- {{{ render.has_entity
-- Checks if an entity has a render slot.
-- @param entity_id  Entity to check
-- @return boolean
function render.has_entity(entity_id)
    return entity_slots[entity_id] ~= nil
end
-- }}}

-- {{{ render.get_stats
-- Returns rendering statistics.
-- @return active_count, max_slots, tracked_entities
function render.get_stats()
    local active, max = render_c.get_slot_count()
    local tracked = 0
    for _ in pairs(entity_slots) do
        tracked = tracked + 1
    end
    return active, max, tracked
end
-- }}}

-- {{{ render.destroy_all
-- Destroys all tracked entities. Call during cleanup.
function render.destroy_all()
    for entity_id, slot in pairs(entity_slots) do
        render_c.destroy_entity(slot)
    end
    entity_slots = {}
    slot_entities = {}
end
-- }}}

-- {{{ render.each
-- Iterates over all tracked entities.
-- @param callback  function(entity_id, slot_index)
function render.each(callback)
    for entity_id, slot in pairs(entity_slots) do
        callback(entity_id, slot)
    end
end
-- }}}

-- Expose C module constants
render.MAX_SLOTS = render_c.MAX_SLOTS
render.MESH_CIRCLE = render_c.MESH_CIRCLE
render.MESH_CUBE = render_c.MESH_CUBE
render.MESH_TRIANGLE = render_c.MESH_TRIANGLE
render.MESH_CYLINDER = render_c.MESH_CYLINDER

return render
-- }}}
