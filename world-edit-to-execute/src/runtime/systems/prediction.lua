--[[
Movement Prediction System (Issue 404d)

Provides movement prediction for entities, useful for:
- Multiplayer lag compensation (predict where unit will be)
- AI systems (anticipate enemy positions)
- Leading shots for projectiles
- Smooth interpolation during network updates

The prediction follows the entity's current path using linear extrapolation
at the entity's effective speed.

Usage:
    local prediction = require("runtime.systems.prediction")

    -- Predict position 1 second in the future
    local future_pos = prediction.predict_position(entity, 1.0)

    -- Estimate time to reach destination
    local eta = prediction.time_to_arrival(entity)
]]

local ecs = require("runtime.ecs")
local movement = require("runtime.systems.movement")

local prediction = {}

-- {{{ prediction.predict_position
-- Predicts entity position at a future time.
-- Uses linear prediction along the current path.
--
-- @param entity entity ID
-- @param time_ahead seconds to predict into the future
-- @return table {x, y} predicted position, or nil if entity invalid
function prediction.predict_position(entity, time_ahead)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        return nil
    end

    -- Handle negative time by returning current position
    if time_ahead <= 0 then
        return { x = pos.x, y = pos.y }
    end

    -- If not moving, return current position
    if not movement.is_moving(entity) then
        return { x = pos.x, y = pos.y }
    end

    -- Calculate effective speed
    local speed = movement.get_effective_speed(entity)
    if speed <= 0 then
        return { x = pos.x, y = pos.y }
    end

    -- Distance we'll travel in the given time
    local distance = speed * time_ahead

    -- Walk along the path, consuming distance
    local current_x, current_y = pos.x, pos.y
    local remaining = distance

    for i = mov.path_index, #mov.path do
        local waypoint = mov.path[i]
        local dx = waypoint.x - current_x
        local dy = waypoint.y - current_y
        local wp_dist = math.sqrt(dx * dx + dy * dy)

        if remaining <= wp_dist then
            -- Predicted position is along this segment
            if wp_dist > 0 then
                local ratio = remaining / wp_dist
                return {
                    x = current_x + dx * ratio,
                    y = current_y + dy * ratio,
                }
            else
                return { x = current_x, y = current_y }
            end
        end

        -- Move to this waypoint and continue
        remaining = remaining - wp_dist
        current_x, current_y = waypoint.x, waypoint.y
    end

    -- Reached end of path before time elapsed
    return { x = current_x, y = current_y }
end
-- }}}

-- {{{ prediction.time_to_arrival
-- Estimates time to reach the final destination.
-- Calculates total path distance and divides by effective speed.
--
-- @param entity entity ID
-- @return number estimated seconds to arrival, or nil if not moving
function prediction.time_to_arrival(entity)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        return nil
    end

    if not movement.is_moving(entity) then
        return nil
    end

    local speed = movement.get_effective_speed(entity)
    if speed <= 0 then
        return nil
    end

    -- Calculate total remaining path distance
    local total_dist = 0
    local current_x, current_y = pos.x, pos.y

    for i = mov.path_index, #mov.path do
        local waypoint = mov.path[i]
        local dx = waypoint.x - current_x
        local dy = waypoint.y - current_y
        total_dist = total_dist + math.sqrt(dx * dx + dy * dy)
        current_x, current_y = waypoint.x, waypoint.y
    end

    return total_dist / speed
end
-- }}}

-- {{{ prediction.time_to_point
-- Estimates time to reach a specific point along the path.
-- Returns nil if the point is not on the path.
--
-- @param entity entity ID
-- @param target_x x coordinate
-- @param target_y y coordinate
-- @param threshold distance threshold to consider "at" the point
-- @return number estimated seconds, or nil if not reachable
function prediction.time_to_point(entity, target_x, target_y, threshold)
    threshold = threshold or movement.ARRIVAL_THRESHOLD

    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        return nil
    end

    if not movement.is_moving(entity) then
        -- Check if already at target
        local dx = target_x - pos.x
        local dy = target_y - pos.y
        if math.sqrt(dx * dx + dy * dy) <= threshold then
            return 0
        end
        return nil
    end

    local speed = movement.get_effective_speed(entity)
    if speed <= 0 then
        return nil
    end

    -- Walk along path looking for the target
    local total_dist = 0
    local current_x, current_y = pos.x, pos.y

    for i = mov.path_index, #mov.path do
        local waypoint = mov.path[i]
        local dx = waypoint.x - current_x
        local dy = waypoint.y - current_y
        local seg_dist = math.sqrt(dx * dx + dy * dy)

        -- Check if target is along this segment
        local target_dx = target_x - current_x
        local target_dy = target_y - current_y
        local target_dist = math.sqrt(target_dx * target_dx + target_dy * target_dy)

        -- Project target onto segment
        if seg_dist > 0 then
            local dot = (target_dx * dx + target_dy * dy) / seg_dist
            if dot >= 0 and dot <= seg_dist then
                -- Target is along this segment
                -- Calculate perpendicular distance
                local proj_x = current_x + (dx / seg_dist) * dot
                local proj_y = current_y + (dy / seg_dist) * dot
                local perp_dist = math.sqrt((target_x - proj_x)^2 + (target_y - proj_y)^2)

                if perp_dist <= threshold then
                    return (total_dist + dot) / speed
                end
            end
        end

        total_dist = total_dist + seg_dist
        current_x, current_y = waypoint.x, waypoint.y

        -- Check if target is at this waypoint
        local to_target = math.sqrt((target_x - current_x)^2 + (target_y - current_y)^2)
        if to_target <= threshold then
            return total_dist / speed
        end
    end

    return nil
end
-- }}}

-- {{{ prediction.will_pass_through
-- Checks if entity will pass through a given area.
-- Useful for setting up ambushes or interception points.
--
-- @param entity entity ID
-- @param area_x center x of area
-- @param area_y center y of area
-- @param radius radius of area to check
-- @return boolean true if path passes through area
function prediction.will_pass_through(entity, area_x, area_y, radius)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        return false
    end

    if not movement.is_moving(entity) then
        return false
    end

    -- Check each path segment for intersection with circle
    local current_x, current_y = pos.x, pos.y

    for i = mov.path_index, #mov.path do
        local waypoint = mov.path[i]

        -- Line segment from current to waypoint
        local dx = waypoint.x - current_x
        local dy = waypoint.y - current_y
        local seg_len = math.sqrt(dx * dx + dy * dy)

        if seg_len > 0 then
            -- Vector from current to area center
            local fx = area_x - current_x
            local fy = area_y - current_y

            -- Project onto segment
            local t = math.max(0, math.min(1, (fx * dx + fy * dy) / (seg_len * seg_len)))

            -- Closest point on segment
            local closest_x = current_x + t * dx
            local closest_y = current_y + t * dy

            -- Distance from closest point to area center
            local dist = math.sqrt((area_x - closest_x)^2 + (area_y - closest_y)^2)

            if dist <= radius then
                return true
            end
        end

        current_x, current_y = waypoint.x, waypoint.y
    end

    return false
end
-- }}}

-- {{{ prediction.get_intercept_point
-- Calculates where to intercept a moving entity.
-- Given an interceptor speed, finds the optimal intercept point.
--
-- @param target_entity entity to intercept
-- @param interceptor_pos {x, y} position of interceptor
-- @param interceptor_speed speed of interceptor
-- @return table {x, y, time} intercept point and time, or nil if impossible
function prediction.get_intercept_point(target_entity, interceptor_pos, interceptor_speed)
    local pos = ecs.get_component(target_entity, "position")
    local mov = ecs.get_component(target_entity, "movement")

    if not pos or not mov then
        return nil
    end

    -- If target not moving, just go to their position
    if not movement.is_moving(target_entity) then
        local dx = pos.x - interceptor_pos.x
        local dy = pos.y - interceptor_pos.y
        local dist = math.sqrt(dx * dx + dy * dy)
        return {
            x = pos.x,
            y = pos.y,
            time = dist / interceptor_speed,
        }
    end

    local target_speed = movement.get_effective_speed(target_entity)

    -- Binary search for intercept time
    local lo, hi = 0, 30  -- Search up to 30 seconds ahead
    local iterations = 20

    for i = 1, iterations do
        local mid = (lo + hi) / 2
        local predicted = prediction.predict_position(target_entity, mid)

        if not predicted then
            return nil
        end

        local dx = predicted.x - interceptor_pos.x
        local dy = predicted.y - interceptor_pos.y
        local dist_to_intercept = math.sqrt(dx * dx + dy * dy)

        local time_to_reach = dist_to_intercept / interceptor_speed

        if time_to_reach < mid then
            hi = mid
        else
            lo = mid
        end
    end

    local intercept_time = (lo + hi) / 2
    local intercept_pos = prediction.predict_position(target_entity, intercept_time)

    if intercept_pos then
        return {
            x = intercept_pos.x,
            y = intercept_pos.y,
            time = intercept_time,
        }
    end

    return nil
end
-- }}}

return prediction
