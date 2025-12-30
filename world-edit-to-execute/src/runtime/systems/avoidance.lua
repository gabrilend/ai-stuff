--[[
Local Avoidance System (Issue 404d)

Provides collision avoidance between moving units using separation-based steering.
Units push away from each other when they get too close, preventing overlap.

This is a simple separation behavior suitable for small groups. For large-scale
RTS with many units, consider upgrading to RVO (Reciprocal Velocity Obstacles)
or flow field-based avoidance.

Usage:
    local avoidance = require("runtime.systems.avoidance")

    -- Calculate steering force to avoid nearby entities
    local steer_x, steer_y = avoidance.calculate_steering(entity, nearby_entities)

    -- Apply steering to entity position
    avoidance.apply_steering(entity, steer_x, steer_y, dt)

The avoidance system runs automatically after the movement system, pushing
entities apart that would otherwise overlap.
]]

local ecs = require("runtime.ecs")
local movement = require("runtime.systems.movement")

local avoidance = {}

-- {{{ Constants
-- Default collision radius for units without explicit radius.
-- WC3 units typically have radii between 16 (small) and 48 (large).
avoidance.DEFAULT_RADIUS = 32

-- Strength of the avoidance force.
-- Higher values = more aggressive separation.
avoidance.AVOIDANCE_STRENGTH = 1.5

-- Maximum steering force as fraction of unit speed.
-- Prevents avoidance from completely overriding intended movement.
avoidance.MAX_STEERING = 0.5
-- }}}

-- {{{ avoidance.get_collision_radius
-- Returns the collision radius for an entity.
-- Falls back to DEFAULT_RADIUS if not specified.
--
-- @param entity entity ID
-- @return number collision radius
function avoidance.get_collision_radius(entity)
    local mov = ecs.get_component(entity, "movement")
    if mov and mov.collision_radius then
        return mov.collision_radius
    end
    return avoidance.DEFAULT_RADIUS
end
-- }}}

-- {{{ avoidance.calculate_steering
-- Calculates steering force to avoid nearby units.
-- Uses simple separation behavior - pushes away from entities within collision range.
--
-- @param entity entity ID to calculate steering for
-- @param nearby_entities array of entity IDs to check for collision
-- @return steer_x, steer_y steering force vector (0,0 if no steering needed)
function avoidance.calculate_steering(entity, nearby_entities)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        return 0, 0
    end

    local steer_x, steer_y = 0, 0
    local radius = mov.collision_radius or avoidance.DEFAULT_RADIUS

    for _, other in ipairs(nearby_entities) do
        if other ~= entity then
            local other_pos = ecs.get_component(other, "position")
            local other_mov = ecs.get_component(other, "movement")

            if other_pos then
                local dx = pos.x - other_pos.x
                local dy = pos.y - other_pos.y
                local dist = math.sqrt(dx * dx + dy * dy)

                local other_radius = other_mov and other_mov.collision_radius or avoidance.DEFAULT_RADIUS
                local min_dist = radius + other_radius

                if dist < min_dist and dist > 0 then
                    -- Separation force (stronger when closer)
                    -- Inverse relationship: closer = stronger push
                    local strength = (min_dist - dist) / min_dist * avoidance.AVOIDANCE_STRENGTH

                    -- Normalize direction and apply strength
                    steer_x = steer_x + (dx / dist) * strength
                    steer_y = steer_y + (dy / dist) * strength
                elseif dist == 0 then
                    -- Entities exactly overlapping - push in random direction
                    -- Use entity IDs to create deterministic "random" direction
                    local angle = (entity + other) * 0.1
                    steer_x = steer_x + math.cos(angle) * avoidance.AVOIDANCE_STRENGTH
                    steer_y = steer_y + math.sin(angle) * avoidance.AVOIDANCE_STRENGTH
                end
            end
        end
    end

    return steer_x, steer_y
end
-- }}}

-- {{{ avoidance.apply_steering
-- Applies steering force to entity's position.
-- Limits steering magnitude to prevent extreme corrections.
--
-- @param entity entity ID
-- @param steer_x x component of steering force
-- @param steer_y y component of steering force
-- @param dt delta time in seconds
-- @return boolean true if steering was applied, false if entity invalid
function avoidance.apply_steering(entity, steer_x, steer_y, dt)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        return false
    end

    -- Limit steering strength based on unit speed and dt
    local speed = mov.speed * (mov.speed_modifier or 1.0)
    local max_steer = speed * avoidance.MAX_STEERING * dt

    local mag = math.sqrt(steer_x * steer_x + steer_y * steer_y)

    if mag > 0 then
        if mag > max_steer then
            -- Normalize and scale to max
            steer_x = (steer_x / mag) * max_steer
            steer_y = (steer_y / mag) * max_steer
        else
            -- Apply full steering scaled by dt
            steer_x = steer_x * dt
            steer_y = steer_y * dt
        end

        pos.x = pos.x + steer_x
        pos.y = pos.y + steer_y
    end

    return true
end
-- }}}

-- {{{ avoidance.are_colliding
-- Checks if two entities are colliding (overlapping).
--
-- @param entity1 first entity ID
-- @param entity2 second entity ID
-- @return boolean true if colliding
function avoidance.are_colliding(entity1, entity2)
    local pos1 = ecs.get_component(entity1, "position")
    local pos2 = ecs.get_component(entity2, "position")

    if not pos1 or not pos2 then
        return false
    end

    local dx = pos2.x - pos1.x
    local dy = pos2.y - pos1.y
    local dist = math.sqrt(dx * dx + dy * dy)

    local r1 = avoidance.get_collision_radius(entity1)
    local r2 = avoidance.get_collision_radius(entity2)

    return dist < (r1 + r2)
end
-- }}}

-- {{{ avoidance.get_distance
-- Returns distance between two entities' centers.
--
-- @param entity1 first entity ID
-- @param entity2 second entity ID
-- @return number distance, or nil if either entity lacks position
function avoidance.get_distance(entity1, entity2)
    local pos1 = ecs.get_component(entity1, "position")
    local pos2 = ecs.get_component(entity2, "position")

    if not pos1 or not pos2 then
        return nil
    end

    local dx = pos2.x - pos1.x
    local dy = pos2.y - pos1.y
    return math.sqrt(dx * dx + dy * dy)
end
-- }}}

-- {{{ Avoidance system update
-- Runs after movement system, applying separation forces to moving entities.
-- Only affects entities that are currently moving.
local function avoidance_system_update(iter, dt)
    -- Collect all entities into array for neighbor lookup
    -- (iter can only be consumed once)
    local entities = {}
    local all_data = {}

    for entity, pos, mov in iter do
        entities[#entities + 1] = entity
        all_data[entity] = {pos = pos, mov = mov}
    end

    -- Apply avoidance to each moving entity
    for _, entity in ipairs(entities) do
        local data = all_data[entity]

        -- Only apply avoidance to moving entities
        if movement.is_moving(entity) then
            local steer_x, steer_y = avoidance.calculate_steering(entity, entities)

            if steer_x ~= 0 or steer_y ~= 0 then
                avoidance.apply_steering(entity, steer_x, steer_y, dt)
            end
        end
    end
end
-- }}}

-- {{{ Register avoidance system
-- Priority 12 runs after movement system (priority 10) but before orders (priority 15).
-- This allows movement to happen first, then we correct for collisions.
ecs.register_system(
    "avoidance",
    {"position", "movement"},
    avoidance_system_update,
    {priority = 12}
)
-- }}}

return avoidance
