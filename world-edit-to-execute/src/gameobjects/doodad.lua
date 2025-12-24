-- Doodad Class
-- Represents trees, destructibles, and decorative objects from war3map.doo.
-- Wraps parsed doodad data with methods for querying visibility, solidity, etc.
--
-- Implementation: 206b-implement-doodad-class
--
-- Parser output fields (from src/parsers/doo.lua):
--   id: 4-char type ID (e.g., "LTlt" for Lordaeron tree)
--   name: optional friendly name from COMMON_DOODADS lookup
--   variation: int, model variation index
--   position: {x, y, z} world coordinates
--   angle: float, rotation in radians
--   scale: {x, y, z} scaling factors
--   flags: 0=invisible_non_solid, 1=visible_non_solid, 2=normal(visible+solid)
--   flags_name: string description of flags
--   life: percentage 0-100
--   creation_number: unique editor ID
--   item_table_pointer: (v8 only) index into item drop table, -1 if none
--   item_sets_count: (v8 only) number of item sets dropped

-- {{{ Doodad class
local Doodad = {}
Doodad.__index = Doodad

-- {{{ new
-- Create a new Doodad from parsed doodad data.
-- @param data Table from doo.parse() containing doodad fields
-- @return Doodad instance
function Doodad.new(data)
    local self = setmetatable({}, Doodad)

    -- Core identification
    self.id = data.id
    self.name = data.name  -- friendly name if known
    self.variation = data.variation or 0
    self.creation_number = data.creation_number

    -- Position and orientation
    -- Copy position table to avoid external mutation
    if data.position then
        self.position = {
            x = data.position.x,
            y = data.position.y,
            z = data.position.z,
        }
    else
        self.position = { x = 0, y = 0, z = 0 }
    end
    self.angle = data.angle or 0

    -- Scale
    -- Copy scale table to avoid external mutation
    if data.scale then
        self.scale = {
            x = data.scale.x,
            y = data.scale.y,
            z = data.scale.z,
        }
    else
        self.scale = { x = 1, y = 1, z = 1 }
    end

    -- Visibility and collision flags
    -- 0 = invisible, non-solid
    -- 1 = visible, non-solid
    -- 2 = normal (visible, solid)
    self.flags = data.flags or 2

    -- Life percentage (0-100)
    self.life = data.life or 100

    -- Version 8 item drop fields (optional)
    self.item_table_pointer = data.item_table_pointer
    self.item_sets_count = data.item_sets_count

    -- Runtime state (not from parser, used during game execution)
    self.current_life = nil
    self.destroyed = false

    return self
end
-- }}}

-- {{{ is_visible
-- Check if doodad is rendered (visible to players).
-- Flags: 0=invisible, 1+=visible
-- @return boolean
function Doodad:is_visible()
    return self.flags >= 1
end
-- }}}

-- {{{ is_solid
-- Check if doodad has collision/pathing (blocks movement).
-- Flags: 0,1=non-solid, 2=solid
-- @return boolean
function Doodad:is_solid()
    return self.flags >= 2
end
-- }}}

-- {{{ get_max_life
-- Get the maximum life percentage of this doodad.
-- For destructibles, this represents initial health.
-- For decorations, typically 100.
-- @return number (0-100)
function Doodad:get_max_life()
    return self.life
end
-- }}}

-- {{{ get_current_life
-- Get the current life of this doodad during runtime.
-- Returns nil if game hasn't started (no runtime state).
-- @return number or nil
function Doodad:get_current_life()
    return self.current_life
end
-- }}}

-- {{{ is_destroyed
-- Check if doodad has been destroyed during gameplay.
-- @return boolean
function Doodad:is_destroyed()
    return self.destroyed
end
-- }}}

-- {{{ has_item_drops
-- Check if this doodad can drop items when destroyed (v8 only).
-- @return boolean
function Doodad:has_item_drops()
    return self.item_table_pointer ~= nil and self.item_table_pointer >= 0
end
-- }}}

-- {{{ get_angle_degrees
-- Get rotation angle in degrees (convenience method).
-- @return number
function Doodad:get_angle_degrees()
    return self.angle * (180 / math.pi)
end
-- }}}

-- {{{ __tostring
function Doodad:__tostring()
    local visibility = ""
    if not self:is_visible() then
        visibility = " [invisible]"
    elseif not self:is_solid() then
        visibility = " [non-solid]"
    end
    return string.format("Doodad<%s @ %.0f,%.0f%s>",
        self.id or "?",
        self.position.x,
        self.position.y,
        visibility)
end
-- }}}
-- }}}

return Doodad
