--[[
Core Movement System (Issue 404a)

Provides movement component definition, system registration, and interpolation
support for smooth rendering. The actual movement logic (path following) is
implemented in 404b.

This module:
- Defines the movement component schema with speed, path, and interpolation fields
- Registers the movement system to run each tick
- Stores previous positions for rendering interpolation
- Provides helper functions for movement state queries

Usage:
    local movement = require("runtime.systems.movement")

    -- Add movement to an entity
    ecs.add_component(entity, "movement", {
        speed = movement.SPEED.FAST,
        pathing_type = movement.PATHING_TYPE.FLY,
    })

    -- Query movement state
    if movement.is_moving(entity) then
        local x, y = movement.get_interpolated_position(entity, alpha)
    end
]]

local ecs = require("runtime.ecs")

local movement = {}

-- {{{ Movement component defaults
-- These values are applied when a movement component is created without overrides.
-- speed: Base movement speed in world units per second (WC3 normal is 270)
-- speed_modifier: Multiplier from buffs/debuffs (1.0 = normal)
-- target: Current movement destination {x, y} or nil if idle
-- path: Array of waypoints from pathfinding or nil
-- path_index: Current waypoint index (1-based)
-- pathing_type: Movement type for pathfinding (foot, fly, etc)
-- turn_rate: Rotation speed in radians per second
-- last_x, last_y: Position at start of tick for interpolation
local MOVEMENT_DEFAULTS = {
    speed = 270,
    speed_modifier = 1.0,
    target = nil,
    path = nil,
    path_index = 1,
    pathing_type = "foot",
    turn_rate = 0.6,
    last_x = 0,
    last_y = 0,
}
-- }}}

-- {{{ Speed constants
-- WC3 movement speed reference values (world units per second).
-- These match observed WC3 behavior for common unit types.
movement.SPEED = {
    VERY_SLOW = 150,   -- Slow siege units, loaded transports
    SLOW = 220,        -- Heavy infantry, siege weapons
    NORMAL = 270,      -- Standard infantry
    FAST = 320,        -- Cavalry, light units
    VERY_FAST = 400,   -- Fast flying units, scouts
    MAX = 522,         -- WC3's hard cap (cannot exceed this)
}

-- Speed modifier limits.
-- MIN prevents complete immobility from stacking slows.
-- MAX prevents absurd speeds from stacking buffs.
movement.MIN_SPEED_MODIFIER = 0.1
movement.MAX_SPEED_MODIFIER = 4.0
-- }}}

-- {{{ Pathing type constants
-- Movement types that affect which terrain is passable.
-- These integrate with the pathfinding system (403).
movement.PATHING_TYPE = {
    FOOT = "foot",           -- Ground units, blocked by cliffs/water
    HORSE = "horse",         -- Mounted units, similar to foot but faster
    FLY = "fly",             -- Flying units, ignore terrain
    FLOAT = "float",         -- Ships, require deep water
    HOVER = "hover",         -- Hover units, ignore shallow water
    AMPHIBIOUS = "amphibious", -- Can traverse land and water
}
-- }}}

-- {{{ Register movement component
-- The component is registered with the ECS so entities can have movement data.
-- Check if already registered (wc3_components.lua may have registered it first).
-- If already registered, we extend the existing registration rather than override.
local existing = ecs.get_component_defaults("movement")
if not existing then
    ecs.register_component("movement", MOVEMENT_DEFAULTS)
end
-- }}}

-- {{{ Movement system update
-- Runs each tick on entities with both position and movement components.
-- Currently only updates interpolation data (last_x/last_y).
-- Actual movement logic is added in 404b.
local function movement_system_update(iter, dt)
    for entity, pos, mov in iter do
        -- Store position at tick start for interpolation.
        -- This MUST happen before any position changes in this tick.
        mov.last_x = pos.x
        mov.last_y = pos.y

        -- Path following logic will be added in 404b.
        -- The system skeleton is here to ensure interpolation data is always updated.
    end
end
-- }}}

-- {{{ Register movement system
-- Priority 10 puts it after input/AI systems but before rendering.
-- The system requires both position and movement components.
ecs.register_system(
    "movement",
    {"position", "movement"},
    movement_system_update,
    {priority = 10}
)
-- }}}

-- {{{ movement.create_component
-- Creates a movement component with specified overrides.
-- Useful when you need to construct component data before adding to entity.
--
-- @param overrides table of values to override defaults
-- @return table movement component data
function movement.create_component(overrides)
    local component = {}
    for k, v in pairs(MOVEMENT_DEFAULTS) do
        component[k] = v
    end
    if overrides then
        for k, v in pairs(overrides) do
            component[k] = v
        end
    end
    return component
end
-- }}}

-- {{{ movement.get_interpolated_position
-- Returns interpolated position for smooth rendering between ticks.
-- alpha of 0.0 returns position at tick start, 1.0 returns current position.
--
-- @param entity entity ID
-- @param alpha interpolation factor (0.0 to 1.0)
-- @return x, y interpolated coordinates or nil, nil if entity lacks components
function movement.get_interpolated_position(entity, alpha)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        return nil, nil
    end

    -- Clamp alpha to valid range
    alpha = math.max(0, math.min(1, alpha or 1))

    -- Linear interpolation between last position and current position
    local x = mov.last_x + (pos.x - mov.last_x) * alpha
    local y = mov.last_y + (pos.y - mov.last_y) * alpha

    return x, y
end
-- }}}

-- {{{ movement.is_moving
-- Returns true if entity is currently moving along a path.
--
-- @param entity entity ID
-- @return boolean true if moving, false otherwise
function movement.is_moving(entity)
    local mov = ecs.get_component(entity, "movement")
    if not mov then
        return false
    end
    return mov.path ~= nil and mov.path_index <= #mov.path
end
-- }}}

-- {{{ movement.get_target
-- Returns the current movement target position.
--
-- @param entity entity ID
-- @return table {x, y} target position or nil if not moving
function movement.get_target(entity)
    local mov = ecs.get_component(entity, "movement")
    if not mov then
        return nil
    end
    return mov.target
end
-- }}}

-- {{{ movement.get_effective_speed
-- Returns the current effective movement speed after modifiers.
--
-- @param entity entity ID
-- @return number effective speed in world units per second
function movement.get_effective_speed(entity)
    local mov = ecs.get_component(entity, "movement")
    if not mov then
        return 0
    end

    -- Apply modifier with clamping
    local modifier = math.max(movement.MIN_SPEED_MODIFIER,
                              math.min(movement.MAX_SPEED_MODIFIER, mov.speed_modifier))
    local effective = mov.speed * modifier

    -- Enforce WC3's max speed cap
    return math.min(effective, movement.SPEED.MAX)
end
-- }}}

-- {{{ movement.get_current_waypoint
-- Returns the current waypoint the entity is moving towards.
--
-- @param entity entity ID
-- @return table {x, y} current waypoint or nil if not moving
function movement.get_current_waypoint(entity)
    local mov = ecs.get_component(entity, "movement")
    if not mov or not mov.path then
        return nil
    end
    if mov.path_index > #mov.path then
        return nil
    end
    return mov.path[mov.path_index]
end
-- }}}

-- {{{ movement.get_remaining_waypoints
-- Returns the number of waypoints remaining in the current path.
--
-- @param entity entity ID
-- @return number remaining waypoint count (0 if not moving)
function movement.get_remaining_waypoints(entity)
    local mov = ecs.get_component(entity, "movement")
    if not mov or not mov.path then
        return 0
    end
    return math.max(0, #mov.path - mov.path_index + 1)
end
-- }}}

-- {{{ movement.set_speed_modifier
-- Sets the speed modifier (from buffs/debuffs).
-- Value is clamped to MIN_SPEED_MODIFIER..MAX_SPEED_MODIFIER.
--
-- @param entity entity ID
-- @param modifier speed multiplier (1.0 = normal)
-- @return boolean true if modifier was set, false if entity lacks movement
function movement.set_speed_modifier(entity, modifier)
    local mov = ecs.get_component(entity, "movement")
    if not mov then
        return false
    end

    mov.speed_modifier = math.max(movement.MIN_SPEED_MODIFIER,
                                   math.min(movement.MAX_SPEED_MODIFIER, modifier))
    return true
end
-- }}}

-- {{{ movement.clear_path
-- Clears the current path and target, stopping movement.
-- Does not reset speed or other properties.
--
-- @param entity entity ID
-- @return boolean true if path was cleared, false if entity lacks movement
function movement.clear_path(entity)
    local mov = ecs.get_component(entity, "movement")
    if not mov then
        return false
    end

    mov.path = nil
    mov.path_index = 1
    mov.target = nil
    return true
end
-- }}}

-- {{{ Exports
movement.DEFAULTS = MOVEMENT_DEFAULTS
-- }}}

return movement
