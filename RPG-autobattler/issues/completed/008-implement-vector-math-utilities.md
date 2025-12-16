# Issue #008: Implement Vector Math Utilities

## Current Behavior
No vector math utilities exist for positioning, movement, and collision calculations.

## Intended Behavior
A comprehensive vector math library should provide essential 2D vector operations needed for game mechanics.

## Implementation Details

### Vector2 Class (src/utils/vector2.lua)
```lua
local Vector2 = {}
Vector2.__index = Vector2

function Vector2:new(x, y)
    local vec = {
        x = x or 0,
        y = y or 0
    }
    setmetatable(vec, Vector2)
    return vec
end

function Vector2:length()
    return math.sqrt(self.x * self.x + self.y * self.y)
end

function Vector2:normalize()
    local len = self:length()
    if len > 0 then
        return Vector2:new(self.x / len, self.y / len)
    end
    return Vector2:new(0, 0)
end

function Vector2:distance_to(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    return math.sqrt(dx * dx + dy * dy)
end

function Vector2:add(other)
    return Vector2:new(self.x + other.x, self.y + other.y)
end

function Vector2:subtract(other)
    return Vector2:new(self.x - other.x, self.y - other.y)
end

function Vector2:multiply(scalar)
    return Vector2:new(self.x * scalar, self.y * scalar)
end

function Vector2:dot(other)
    return self.x * other.x + self.y * other.y
end

function Vector2:angle_to(other)
    return math.atan2(other.y - self.y, other.x - self.x)
end

return Vector2
```

### Math Utilities (src/utils/math_utils.lua)
```lua
local MathUtils = {}

function MathUtils.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function MathUtils.lerp(a, b, t)
    return a + (b - a) * t
end

function MathUtils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function MathUtils.angle_between(x1, y1, x2, y2)
    return math.atan2(y2 - y1, x2 - x1)
end

function MathUtils.point_in_circle(px, py, cx, cy, radius)
    local dx = px - cx
    local dy = py - cy
    return (dx * dx + dy * dy) <= (radius * radius)
end

function MathUtils.point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

return MathUtils
```

### Collision Detection (src/utils/collision.lua)
```lua
local Collision = {}

function Collision.circle_circle(x1, y1, r1, x2, y2, r2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance <= (r1 + r2)
end

function Collision.rect_rect(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end

function Collision.point_in_circle(px, py, cx, cy, radius)
    local dx = px - cx
    local dy = py - cy
    return (dx * dx + dy * dy) <= (radius * radius)
end

return Collision
```

### Essential Operations
1. Vector addition, subtraction, multiplication
2. Distance calculations
3. Normalization and length
4. Angle calculations
5. Linear interpolation
6. Collision detection helpers

### Considerations
- Optimize for performance (avoid unnecessary sqrt calls)
- Include comprehensive test cases
- Handle edge cases (zero vectors, etc.)
- Consider using metatables for operator overloading
- Plan for 3D expansion if needed later

### Tool Suggestions
- Use Write tool to create vector and math utility files
- Create test cases to verify all operations
- Test performance with large numbers of operations
- Verify accuracy of trigonometric functions

### Acceptance Criteria
- [ ] All vector operations work correctly
- [ ] Distance and angle calculations are accurate
- [ ] Collision detection functions work reliably
- [ ] Performance is acceptable for game use
- [ ] Edge cases are handled properly
- [ ] Code is well-documented and easy to use