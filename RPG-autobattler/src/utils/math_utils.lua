-- {{{ MathUtils module
local MathUtils = {}

local debug = require("src.utils.debug")

-- Mathematical constants
MathUtils.PI = math.pi
MathUtils.TWO_PI = 2 * math.pi
MathUtils.HALF_PI = math.pi / 2
MathUtils.DEG_TO_RAD = math.pi / 180
MathUtils.RAD_TO_DEG = 180 / math.pi
MathUtils.EPSILON = 1e-10

-- {{{ MathUtils.clamp
function MathUtils.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end
-- }}}

-- {{{ MathUtils.lerp
function MathUtils.lerp(a, b, t)
    return a + (b - a) * t
end
-- }}}

-- {{{ MathUtils.inverse_lerp
function MathUtils.inverse_lerp(a, b, value)
    if math.abs(b - a) < MathUtils.EPSILON then
        return 0
    end
    return (value - a) / (b - a)
end
-- }}}

-- {{{ MathUtils.smoothstep
function MathUtils.smoothstep(edge0, edge1, x)
    local t = MathUtils.clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
end
-- }}}

-- {{{ MathUtils.distance
function MathUtils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end
-- }}}

-- {{{ MathUtils.distance_squared
function MathUtils.distance_squared(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end
-- }}}

-- {{{ MathUtils.angle_between
function MathUtils.angle_between(x1, y1, x2, y2)
    return math.atan2(y2 - y1, x2 - x1)
end
-- }}}

-- {{{ MathUtils.normalize_angle
function MathUtils.normalize_angle(angle)
    while angle > MathUtils.PI do
        angle = angle - MathUtils.TWO_PI
    end
    while angle < -MathUtils.PI do
        angle = angle + MathUtils.TWO_PI
    end
    return angle
end
-- }}}

-- {{{ MathUtils.angle_difference
function MathUtils.angle_difference(a1, a2)
    local diff = a2 - a1
    return MathUtils.normalize_angle(diff)
end
-- }}}

-- {{{ MathUtils.lerp_angle
function MathUtils.lerp_angle(a1, a2, t)
    local diff = MathUtils.angle_difference(a1, a2)
    return a1 + diff * t
end
-- }}}

-- {{{ MathUtils.point_in_circle
function MathUtils.point_in_circle(px, py, cx, cy, radius)
    local dx = px - cx
    local dy = py - cy
    return (dx * dx + dy * dy) <= (radius * radius)
end
-- }}}

-- {{{ MathUtils.point_in_rect
function MathUtils.point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end
-- }}}

-- {{{ MathUtils.point_in_triangle
function MathUtils.point_in_triangle(px, py, x1, y1, x2, y2, x3, y3)
    local denom = (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3)
    if math.abs(denom) < MathUtils.EPSILON then
        return false -- Degenerate triangle
    end
    
    local a = ((y2 - y3) * (px - x3) + (x3 - x2) * (py - y3)) / denom
    local b = ((y3 - y1) * (px - x3) + (x1 - x3) * (py - y3)) / denom
    local c = 1 - a - b
    
    return a >= 0 and b >= 0 and c >= 0
end
-- }}}

-- {{{ MathUtils.line_intersection
function MathUtils.line_intersection(x1, y1, x2, y2, x3, y3, x4, y4)
    local denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    
    if math.abs(denom) < MathUtils.EPSILON then
        return nil -- Lines are parallel
    end
    
    local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
    local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
    
    if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
        local ix = x1 + t * (x2 - x1)
        local iy = y1 + t * (y2 - y1)
        return ix, iy
    end
    
    return nil -- No intersection
end
-- }}}

-- {{{ MathUtils.closest_point_on_line
function MathUtils.closest_point_on_line(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local length_squared = dx * dx + dy * dy
    
    if length_squared < MathUtils.EPSILON then
        return x1, y1 -- Line is a point
    end
    
    local t = ((px - x1) * dx + (py - y1) * dy) / length_squared
    t = MathUtils.clamp(t, 0, 1)
    
    return x1 + t * dx, y1 + t * dy
end
-- }}}

-- {{{ MathUtils.sign
function MathUtils.sign(value)
    if value > 0 then return 1 end
    if value < 0 then return -1 end
    return 0
end
-- }}}

-- {{{ MathUtils.round
function MathUtils.round(value, decimals)
    decimals = decimals or 0
    local multiplier = 10 ^ decimals
    return math.floor(value * multiplier + 0.5) / multiplier
end
-- }}}

-- {{{ MathUtils.approximately_equal
function MathUtils.approximately_equal(a, b, epsilon)
    epsilon = epsilon or MathUtils.EPSILON
    return math.abs(a - b) < epsilon
end
-- }}}

-- {{{ MathUtils.wrap
function MathUtils.wrap(value, min, max)
    local range = max - min
    if range <= 0 then
        return min
    end
    
    value = value - min
    value = value - math.floor(value / range) * range
    return value + min
end
-- }}}

-- {{{ MathUtils.ping_pong
function MathUtils.ping_pong(t, length)
    t = MathUtils.wrap(t, 0, length * 2)
    return length - math.abs(t - length)
end
-- }}}

-- {{{ MathUtils.move_towards
function MathUtils.move_towards(current, target, max_delta)
    if math.abs(target - current) <= max_delta then
        return target
    end
    return current + MathUtils.sign(target - current) * max_delta
end
-- }}}

-- {{{ MathUtils.move_towards_angle
function MathUtils.move_towards_angle(current, target, max_delta)
    local diff = MathUtils.angle_difference(current, target)
    if math.abs(diff) <= max_delta then
        return target
    end
    return current + MathUtils.sign(diff) * max_delta
end
-- }}}

-- {{{ MathUtils.smooth_damp
function MathUtils.smooth_damp(current, target, velocity, smooth_time, dt, max_speed)
    max_speed = max_speed or math.huge
    smooth_time = math.max(0.0001, smooth_time)
    
    local omega = 2 / smooth_time
    local x = omega * dt
    local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
    local change = current - target
    local original_to = target
    
    local max_change = max_speed * smooth_time
    change = MathUtils.clamp(change, -max_change, max_change)
    target = current - change
    
    local temp = (velocity + omega * change) * dt
    velocity = (velocity - omega * temp) * exp
    local output = target + (change + temp) * exp
    
    if (original_to - current > 0) == (output > original_to) then
        output = original_to
        velocity = (output - original_to) / dt
    end
    
    return output, velocity
end
-- }}}

-- {{{ MathUtils.random_range
function MathUtils.random_range(min, max)
    return min + math.random() * (max - min)
end
-- }}}

-- {{{ MathUtils.random_point_in_circle
function MathUtils.random_point_in_circle(cx, cy, radius)
    local angle = math.random() * MathUtils.TWO_PI
    local r = math.sqrt(math.random()) * radius
    return cx + r * math.cos(angle), cy + r * math.sin(angle)
end
-- }}}

-- {{{ MathUtils.random_point_on_circle
function MathUtils.random_point_on_circle(cx, cy, radius)
    local angle = math.random() * MathUtils.TWO_PI
    return cx + radius * math.cos(angle), cy + radius * math.sin(angle)
end
-- }}}

-- {{{ MathUtils.to_degrees
function MathUtils.to_degrees(radians)
    return radians * MathUtils.RAD_TO_DEG
end
-- }}}

-- {{{ MathUtils.to_radians
function MathUtils.to_radians(degrees)
    return degrees * MathUtils.DEG_TO_RAD
end
-- }}}

-- {{{ MathUtils.is_power_of_two
function MathUtils.is_power_of_two(n)
    if n <= 0 then return false end
    return math.floor(math.log(n) / math.log(2)) == math.log(n) / math.log(2)
end
-- }}}

-- {{{ MathUtils.next_power_of_two
function MathUtils.next_power_of_two(n)
    if n <= 0 then return 1 end
    if n == 1 then return 1 end
    
    local power = 1
    while power < n do
        power = power * 2
    end
    return power
end
-- }}}

return MathUtils
-- }}}