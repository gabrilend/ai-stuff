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

-- Collision module reference (set during integration check)
-- The movement system can optionally use collision for slide movement.
-- If collision is not initialized, movement proceeds without collision checks.
local collision = nil

-- {{{ try_load_collision
-- Attempt to load collision module. Called lazily to avoid circular deps.
local function try_load_collision()
    if collision then
        return collision
    end
    local ok, col = pcall(require, "runtime.collision")
    if ok and col and col.is_initialized and col.is_initialized() then
        collision = col
    end
    return collision
end
-- }}}

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
-- collision_radius: Radius for unit collision/avoidance (404d)
-- blocked: True if movement was blocked by collision this tick (405d)
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
    collision_radius = 32,
    blocked = false,
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

-- Arrival threshold - minimum distance to consider "arrived" at waypoint.
-- Prevents oscillation around waypoints due to floating-point precision.
movement.ARRIVAL_THRESHOLD = 4.0
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

-- {{{ update_facing (local helper for system update)
-- Rotates entity toward the current waypoint based on turn_rate.
-- Called each tick by the movement system.
--
-- @param pos position component
-- @param mov movement component
-- @param waypoint current target waypoint {x, y}
-- @param dt delta time in seconds
-- @param movement_module reference to movement table for constants
local function update_facing(pos, mov, waypoint, dt, movement_module)
    -- Calculate angle to waypoint
    local dx = waypoint.x - pos.x
    local dy = waypoint.y - pos.y
    local target_facing = math.atan2(dy, dx)

    -- Calculate shortest rotation direction
    local diff = target_facing - pos.facing

    -- Normalize to -pi..pi
    while diff > math.pi do diff = diff - 2 * math.pi end
    while diff < -math.pi do diff = diff + 2 * math.pi end

    -- Apply turn rate limit
    local max_turn = mov.turn_rate * dt
    if math.abs(diff) <= max_turn then
        pos.facing = target_facing
    elseif diff > 0 then
        pos.facing = pos.facing + max_turn
    else
        pos.facing = pos.facing - max_turn
    end

    -- Normalize facing to 0..2pi
    while pos.facing < 0 do pos.facing = pos.facing + 2 * math.pi end
    while pos.facing >= 2 * math.pi do pos.facing = pos.facing - 2 * math.pi end
end
-- }}}

-- {{{ update_movement (local helper for system update)
-- Moves entity along path toward current waypoint.
-- Advances to next waypoint when close enough.
-- Called each tick by the movement system.
-- If collision system is active, uses slide_move to respect solid entities.
--
-- @param entity entity ID (needed for collision checks)
-- @param pos position component
-- @param mov movement component
-- @param dt delta time in seconds
-- @param movement_module reference to movement table for constants
-- @return boolean true if still moving, false if path complete
local function update_movement(entity, pos, mov, dt, movement_module)
    -- Not moving if no path or past end
    if not mov.path or mov.path_index > #mov.path then
        return false
    end

    local waypoint = mov.path[mov.path_index]
    local dx = waypoint.x - pos.x
    local dy = waypoint.y - pos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    -- Check if arrived at waypoint
    if dist <= movement_module.ARRIVAL_THRESHOLD then
        mov.path_index = mov.path_index + 1
        -- Check if path complete
        if mov.path_index > #mov.path then
            mov.path = nil
            mov.target = nil
            return false
        end
        -- Recurse to handle next waypoint in same tick
        return update_movement(entity, pos, mov, dt, movement_module)
    end

    -- Calculate movement this tick
    local speed = mov.speed * math.max(movement_module.MIN_SPEED_MODIFIER,
                                        math.min(movement_module.MAX_SPEED_MODIFIER, mov.speed_modifier))
    speed = math.min(speed, movement_module.SPEED.MAX)
    local move_dist = speed * dt

    -- Don't overshoot waypoint
    if move_dist > dist then
        move_dist = dist
    end

    -- Calculate desired position
    local ratio = move_dist / dist
    local desired_x = pos.x + dx * ratio
    local desired_y = pos.y + dy * ratio

    -- Attempt to use collision system for slide movement (405d integration)
    -- If collision is available and initialized, use slide_move
    -- Otherwise fall back to direct movement
    local col = try_load_collision()
    if col and col.slide_move then
        local actual_x, actual_y = col.slide_move(entity, desired_x, desired_y)
        pos.x = actual_x
        pos.y = actual_y

        -- If completely blocked (no movement), consider stopping at this waypoint
        -- This prevents infinite looping when blocked
        if actual_x == mov.last_x and actual_y == mov.last_y then
            -- Store blocked flag for external systems to detect
            mov.blocked = true
        else
            mov.blocked = false
        end
    else
        -- Direct movement (no collision checking)
        pos.x = desired_x
        pos.y = desired_y
    end

    return true
end
-- }}}

-- {{{ Movement system update
-- Runs each tick on entities with both position and movement components.
-- Updates interpolation data (last_x/last_y), rotates toward waypoints,
-- and moves entities along their paths.
-- Collision integration (405d): Uses slide_move when collision system is active.
local function movement_system_update(iter, dt)
    for entity, pos, mov in iter do
        -- Store position at tick start for interpolation.
        -- This MUST happen before any position changes in this tick.
        mov.last_x = pos.x
        mov.last_y = pos.y

        -- Path following logic (404b) with collision integration (405d)
        if mov.path and mov.path_index <= #mov.path then
            local waypoint = mov.path[mov.path_index]

            -- Rotate toward waypoint (pass movement table for constants access)
            update_facing(pos, mov, waypoint, dt, movement)

            -- Move toward waypoint with collision checking (pass entity for slide_move)
            update_movement(entity, pos, mov, dt, movement)
        end
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

-- {{{ movement.set_path
-- Sets a new movement path for the entity.
-- Overwrites any existing path. Sets target to final waypoint.
--
-- @param entity entity ID
-- @param path array of {x, y} waypoints
-- @return boolean true if path was set, false if entity lacks movement or path empty
function movement.set_path(entity, path)
    local mov = ecs.get_component(entity, "movement")
    if not mov then
        return false
    end
    if not path or #path == 0 then
        return false
    end

    mov.path = path
    mov.path_index = 1
    mov.target = path[#path]  -- Final destination
    return true
end
-- }}}

-- {{{ movement.distance_to_point
-- Calculates distance from entity's current position to a point.
--
-- @param entity entity ID
-- @param x target x coordinate
-- @param y target y coordinate
-- @return number distance, or nil if entity lacks position
function movement.distance_to_point(entity, x, y)
    local pos = ecs.get_component(entity, "position")
    if not pos then
        return nil
    end
    local dx = x - pos.x
    local dy = y - pos.y
    return math.sqrt(dx * dx + dy * dy)
end
-- }}}

-- {{{ movement.distance_to_next_waypoint
-- Returns distance to the current waypoint being moved towards.
--
-- @param entity entity ID
-- @return number distance, or nil if not moving
function movement.distance_to_next_waypoint(entity)
    local waypoint = movement.get_current_waypoint(entity)
    if not waypoint then
        return nil
    end
    return movement.distance_to_point(entity, waypoint.x, waypoint.y)
end
-- }}}

-- {{{ movement.distance_to_target
-- Returns distance to the final movement destination.
--
-- @param entity entity ID
-- @return number distance, or nil if not moving
function movement.distance_to_target(entity)
    local target = movement.get_target(entity)
    if not target then
        return nil
    end
    return movement.distance_to_point(entity, target.x, target.y)
end
-- }}}

-- {{{ movement.time_to_destination
-- Estimates time to reach final destination at current speed.
-- Uses straight-line distance (actual path may take longer).
--
-- @param entity entity ID
-- @return number estimated seconds, or nil if not moving
function movement.time_to_destination(entity)
    local dist = movement.distance_to_target(entity)
    if not dist then
        return nil
    end
    local speed = movement.get_effective_speed(entity)
    if speed <= 0 then
        return nil
    end
    return dist / speed
end
-- }}}

-- {{{ movement.is_blocked
-- Returns true if entity's movement was blocked by collision this tick.
-- (405d integration) This is set when slide_move cannot find any valid position.
--
-- @param entity entity ID
-- @return boolean true if blocked, false otherwise
function movement.is_blocked(entity)
    local mov = ecs.get_component(entity, "movement")
    if not mov then
        return false
    end
    return mov.blocked == true
end
-- }}}

-- {{{ Exports
movement.DEFAULTS = MOVEMENT_DEFAULTS
-- }}}

return movement
