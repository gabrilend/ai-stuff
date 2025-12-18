-- {{{ Collision detection module
local Collision = {}

local debug = require("src.utils.debug")
local MathUtils = require("src.utils.math_utils")

-- {{{ Collision.point_in_circle
function Collision.point_in_circle(px, py, cx, cy, radius)
    local dx = px - cx
    local dy = py - cy
    return (dx * dx + dy * dy) <= (radius * radius)
end
-- }}}

-- {{{ Collision.point_in_rect
function Collision.point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end
-- }}}

-- {{{ Collision.point_in_triangle
function Collision.point_in_triangle(px, py, x1, y1, x2, y2, x3, y3)
    return MathUtils.point_in_triangle(px, py, x1, y1, x2, y2, x3, y3)
end
-- }}}

-- {{{ Collision.circle_circle
function Collision.circle_circle(x1, y1, r1, x2, y2, r2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance_squared = dx * dx + dy * dy
    local radius_sum = r1 + r2
    return distance_squared <= (radius_sum * radius_sum)
end
-- }}}

-- {{{ Collision.circle_circle_detailed
function Collision.circle_circle_detailed(x1, y1, r1, x2, y2, r2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    local radius_sum = r1 + r2
    
    local colliding = distance <= radius_sum
    local overlap = radius_sum - distance
    
    local result = {
        colliding = colliding,
        distance = distance,
        overlap = math.max(0, overlap)
    }
    
    if colliding and distance > 0 then
        -- Normalize collision direction
        result.normal_x = dx / distance
        result.normal_y = dy / distance
        
        -- Contact point (approximate)
        result.contact_x = x1 + result.normal_x * r1
        result.contact_y = y1 + result.normal_y * r1
    end
    
    return result
end
-- }}}

-- {{{ Collision.rect_rect
function Collision.rect_rect(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end
-- }}}

-- {{{ Collision.rect_rect_detailed
function Collision.rect_rect_detailed(x1, y1, w1, h1, x2, y2, w2, h2)
    local colliding = Collision.rect_rect(x1, y1, w1, h1, x2, y2, w2, h2)
    
    local result = {
        colliding = colliding
    }
    
    if colliding then
        -- Calculate overlap
        local overlap_x = math.min(x1 + w1, x2 + w2) - math.max(x1, x2)
        local overlap_y = math.min(y1 + h1, y2 + h2) - math.max(y1, y2)
        
        result.overlap_x = overlap_x
        result.overlap_y = overlap_y
        
        -- Determine separation direction (smallest overlap)
        if overlap_x < overlap_y then
            result.separation_x = x1 < x2 and -overlap_x or overlap_x
            result.separation_y = 0
        else
            result.separation_x = 0
            result.separation_y = y1 < y2 and -overlap_y or overlap_y
        end
    end
    
    return result
end
-- }}}

-- {{{ Collision.circle_rect
function Collision.circle_rect(cx, cy, radius, rx, ry, rw, rh)
    -- Find closest point on rectangle to circle center
    local closest_x = MathUtils.clamp(cx, rx, rx + rw)
    local closest_y = MathUtils.clamp(cy, ry, ry + rh)
    
    -- Check if circle contains the closest point
    return Collision.point_in_circle(closest_x, closest_y, cx, cy, radius)
end
-- }}}

-- {{{ Collision.circle_rect_detailed
function Collision.circle_rect_detailed(cx, cy, radius, rx, ry, rw, rh)
    local closest_x = MathUtils.clamp(cx, rx, rx + rw)
    local closest_y = MathUtils.clamp(cy, ry, ry + rh)
    
    local dx = closest_x - cx
    local dy = closest_y - cy
    local distance_squared = dx * dx + dy * dy
    local radius_squared = radius * radius
    
    local colliding = distance_squared <= radius_squared
    
    local result = {
        colliding = colliding,
        closest_x = closest_x,
        closest_y = closest_y
    }
    
    if colliding then
        local distance = math.sqrt(distance_squared)
        result.distance = distance
        result.overlap = radius - distance
        
        if distance > 0 then
            result.normal_x = -dx / distance
            result.normal_y = -dy / distance
        else
            -- Circle center is inside rectangle
            -- Choose direction based on smallest penetration
            local penetration_left = cx - rx
            local penetration_right = (rx + rw) - cx
            local penetration_top = cy - ry
            local penetration_bottom = (ry + rh) - cy
            
            local min_penetration = math.min(penetration_left, penetration_right, penetration_top, penetration_bottom)
            
            if min_penetration == penetration_left then
                result.normal_x = -1
                result.normal_y = 0
            elseif min_penetration == penetration_right then
                result.normal_x = 1
                result.normal_y = 0
            elseif min_penetration == penetration_top then
                result.normal_x = 0
                result.normal_y = -1
            else
                result.normal_x = 0
                result.normal_y = 1
            end
        end
    end
    
    return result
end
-- }}}

-- {{{ Collision.line_circle
function Collision.line_circle(x1, y1, x2, y2, cx, cy, radius)
    local closest_x, closest_y = MathUtils.closest_point_on_line(cx, cy, x1, y1, x2, y2)
    return Collision.point_in_circle(closest_x, closest_y, cx, cy, radius)
end
-- }}}

-- {{{ Collision.line_rect
function Collision.line_rect(x1, y1, x2, y2, rx, ry, rw, rh)
    -- Check if either endpoint is inside rectangle
    if Collision.point_in_rect(x1, y1, rx, ry, rw, rh) or 
       Collision.point_in_rect(x2, y2, rx, ry, rw, rh) then
        return true
    end
    
    -- Check intersection with rectangle edges
    local rect_edges = {
        {rx, ry, rx + rw, ry},         -- Top edge
        {rx + rw, ry, rx + rw, ry + rh}, -- Right edge
        {rx + rw, ry + rh, rx, ry + rh}, -- Bottom edge
        {rx, ry + rh, rx, ry}           -- Left edge
    }
    
    for _, edge in ipairs(rect_edges) do
        if MathUtils.line_intersection(x1, y1, x2, y2, edge[1], edge[2], edge[3], edge[4]) then
            return true
        end
    end
    
    return false
end
-- }}}

-- {{{ Collision.capsule_point
function Collision.capsule_point(px, py, x1, y1, x2, y2, radius)
    local closest_x, closest_y = MathUtils.closest_point_on_line(px, py, x1, y1, x2, y2)
    return Collision.point_in_circle(px, py, closest_x, closest_y, radius)
end
-- }}}

-- {{{ Collision.capsule_circle
function Collision.capsule_circle(cx, cy, cr, x1, y1, x2, y2, radius)
    local closest_x, closest_y = MathUtils.closest_point_on_line(cx, cy, x1, y1, x2, y2)
    return Collision.circle_circle(cx, cy, cr, closest_x, closest_y, radius)
end
-- }}}

-- {{{ Collision.swept_circle_circle
function Collision.swept_circle_circle(x1, y1, vx1, vy1, r1, x2, y2, vx2, vy2, r2, dt)
    -- Relative velocity
    local rel_vx = vx1 - vx2
    local rel_vy = vy1 - vy2
    
    -- Relative position
    local rel_x = x1 - x2
    local rel_y = y1 - y2
    
    local radius_sum = r1 + r2
    
    -- Quadratic equation coefficients for collision time
    local a = rel_vx * rel_vx + rel_vy * rel_vy
    local b = 2 * (rel_x * rel_vx + rel_y * rel_vy)
    local c = rel_x * rel_x + rel_y * rel_y - radius_sum * radius_sum
    
    -- Check if already colliding
    if c <= 0 then
        return {colliding = true, time = 0}
    end
    
    -- Check if moving apart
    if b >= 0 then
        return {colliding = false}
    end
    
    -- Solve quadratic equation
    local discriminant = b * b - 4 * a * c
    
    if discriminant < 0 or a == 0 then
        return {colliding = false}
    end
    
    local time = (-b - math.sqrt(discriminant)) / (2 * a)
    
    if time >= 0 and time <= dt then
        return {
            colliding = true,
            time = time,
            collision_x = x1 + vx1 * time,
            collision_y = y1 + vy1 * time
        }
    end
    
    return {colliding = false}
end
-- }}}

-- {{{ Collision.ray_circle
function Collision.ray_circle(rx, ry, rdx, rdy, cx, cy, radius)
    -- Vector from ray origin to circle center
    local to_center_x = cx - rx
    local to_center_y = cy - ry
    
    -- Project onto ray direction
    local projection = to_center_x * rdx + to_center_y * rdy
    
    if projection < 0 then
        -- Circle is behind ray origin
        return nil
    end
    
    -- Closest point on ray to circle center
    local closest_x = rx + rdx * projection
    local closest_y = ry + rdy * projection
    
    local distance_squared = (closest_x - cx) * (closest_x - cx) + (closest_y - cy) * (closest_y - cy)
    
    if distance_squared > radius * radius then
        return nil
    end
    
    -- Calculate intersection distance
    local half_chord = math.sqrt(radius * radius - distance_squared)
    local intersection_distance = projection - half_chord
    
    if intersection_distance < 0 then
        intersection_distance = projection + half_chord
    end
    
    return {
        distance = intersection_distance,
        x = rx + rdx * intersection_distance,
        y = ry + rdy * intersection_distance
    }
end
-- }}}

-- {{{ Collision.ray_rect
function Collision.ray_rect(rx, ry, rdx, rdy, rect_x, rect_y, rect_w, rect_h)
    local min_distance = math.huge
    local hit_x, hit_y
    
    -- Check intersection with each edge
    local edges = {
        {rect_x, rect_y, rect_x + rect_w, rect_y},           -- Top
        {rect_x + rect_w, rect_y, rect_x + rect_w, rect_y + rect_h}, -- Right
        {rect_x + rect_w, rect_y + rect_h, rect_x, rect_y + rect_h}, -- Bottom
        {rect_x, rect_y + rect_h, rect_x, rect_y}             -- Left
    }
    
    for _, edge in ipairs(edges) do
        local ix, iy = MathUtils.line_intersection(
            rx, ry, rx + rdx * 1000, ry + rdy * 1000,
            edge[1], edge[2], edge[3], edge[4]
        )
        
        if ix and iy then
            local distance = MathUtils.distance(rx, ry, ix, iy)
            if distance < min_distance then
                min_distance = distance
                hit_x = ix
                hit_y = iy
            end
        end
    end
    
    if hit_x then
        return {
            distance = min_distance,
            x = hit_x,
            y = hit_y
        }
    end
    
    return nil
end
-- }}}

return Collision
-- }}}