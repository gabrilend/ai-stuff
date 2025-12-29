--[[
Collision Shapes - Primitive Collision Detection Functions

Provides basic collision math for circles, rectangles, and points.
All functions use squared distances to avoid expensive sqrt calls.

All rectangles are defined by center (x, y) and full dimensions (width, height).
]]

local shapes = {}

-- {{{ circles_collide
-- Check if two circles overlap.
-- Returns true if distance between centers <= sum of radii.
-- Uses squared distances to avoid sqrt.
function shapes.circles_collide(x1, y1, r1, x2, y2, r2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dist_sq = dx * dx + dy * dy
    local radii_sum = r1 + r2
    return dist_sq <= radii_sum * radii_sum
end
-- }}}

-- {{{ point_in_circle
-- Check if a point is inside or on a circle.
function shapes.point_in_circle(px, py, cx, cy, cr)
    local dx = px - cx
    local dy = py - cy
    return dx * dx + dy * dy <= cr * cr
end
-- }}}

-- {{{ point_in_rect
-- Check if a point is inside or on a rectangle.
-- Rect defined by center (rx, ry) and full dimensions (rw, rh).
function shapes.point_in_rect(px, py, rx, ry, rw, rh)
    local hw, hh = rw / 2, rh / 2
    return px >= rx - hw and px <= rx + hw
       and py >= ry - hh and py <= ry + hh
end
-- }}}

-- {{{ rects_collide
-- Check if two axis-aligned rectangles overlap (AABB test).
-- Rects defined by center and full dimensions.
function shapes.rects_collide(x1, y1, w1, h1, x2, y2, w2, h2)
    local hw1, hh1 = w1 / 2, h1 / 2
    local hw2, hh2 = w2 / 2, h2 / 2
    return math.abs(x1 - x2) <= hw1 + hw2
       and math.abs(y1 - y2) <= hh1 + hh2
end
-- }}}

-- {{{ circle_rect_collide
-- Check if a circle overlaps an axis-aligned rectangle.
-- Find closest point on rect to circle center, then check distance.
function shapes.circle_rect_collide(cx, cy, cr, rx, ry, rw, rh)
    local hw, hh = rw / 2, rh / 2
    -- Find closest point on rect to circle center
    local closest_x = math.max(rx - hw, math.min(cx, rx + hw))
    local closest_y = math.max(ry - hh, math.min(cy, ry + hh))
    -- Check if closest point is within circle
    return shapes.point_in_circle(closest_x, closest_y, cx, cy, cr)
end
-- }}}

-- {{{ distance_squared
-- Calculate squared distance between two points.
-- Avoids sqrt for performance when only comparing distances.
function shapes.distance_squared(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end
-- }}}

-- {{{ distance
-- Calculate actual distance between two points.
-- Use distance_squared when possible for performance.
function shapes.distance(x1, y1, x2, y2)
    return math.sqrt(shapes.distance_squared(x1, y1, x2, y2))
end
-- }}}

-- {{{ get_separation_vector
-- Calculate the separation vector between two circles.
-- Returns: nx, ny (normalized direction), overlap amount (positive if overlapping)
-- The vector points from (x1,y1) toward (x2,y2).
function shapes.get_separation_vector(x1, y1, r1, x2, y2, r2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)

    -- Avoid division by zero when centers coincide
    if dist < 0.001 then
        return 1, 0, r1 + r2
    end

    -- Normalize direction
    local nx = dx / dist
    local ny = dy / dist

    -- Calculate overlap (positive means overlapping)
    local overlap = (r1 + r2) - dist

    return nx, ny, overlap
end
-- }}}

return shapes
