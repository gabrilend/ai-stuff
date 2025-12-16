-- {{{ Vector2 class
local Vector2 = {}
Vector2.__index = Vector2

-- {{{ Vector2:new
function Vector2:new(x, y)
    local vec = {
        x = x or 0,
        y = y or 0
    }
    setmetatable(vec, Vector2)
    return vec
end
-- }}}

-- {{{ Vector2:copy
function Vector2:copy()
    return Vector2:new(self.x, self.y)
end
-- }}}

-- {{{ Vector2:set
function Vector2:set(x, y)
    self.x = x or 0
    self.y = y or 0
    return self
end
-- }}}

-- {{{ Vector2:length
function Vector2:length()
    return math.sqrt(self.x * self.x + self.y * self.y)
end
-- }}}

-- {{{ Vector2:length_squared
function Vector2:length_squared()
    return self.x * self.x + self.y * self.y
end
-- }}}

-- {{{ Vector2:normalize
function Vector2:normalize()
    local len = self:length()
    if len > 0 then
        return Vector2:new(self.x / len, self.y / len)
    end
    return Vector2:new(0, 0)
end
-- }}}

-- {{{ Vector2:normalize_in_place
function Vector2:normalize_in_place()
    local len = self:length()
    if len > 0 then
        self.x = self.x / len
        self.y = self.y / len
    else
        self.x = 0
        self.y = 0
    end
    return self
end
-- }}}

-- {{{ Vector2:distance_to
function Vector2:distance_to(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    return math.sqrt(dx * dx + dy * dy)
end
-- }}}

-- {{{ Vector2:distance_squared_to
function Vector2:distance_squared_to(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    return dx * dx + dy * dy
end
-- }}}

-- {{{ Vector2:add
function Vector2:add(other)
    return Vector2:new(self.x + other.x, self.y + other.y)
end
-- }}}

-- {{{ Vector2:add_in_place
function Vector2:add_in_place(other)
    self.x = self.x + other.x
    self.y = self.y + other.y
    return self
end
-- }}}

-- {{{ Vector2:subtract
function Vector2:subtract(other)
    return Vector2:new(self.x - other.x, self.y - other.y)
end
-- }}}

-- {{{ Vector2:subtract_in_place
function Vector2:subtract_in_place(other)
    self.x = self.x - other.x
    self.y = self.y - other.y
    return self
end
-- }}}

-- {{{ Vector2:multiply
function Vector2:multiply(scalar)
    return Vector2:new(self.x * scalar, self.y * scalar)
end
-- }}}

-- {{{ Vector2:multiply_in_place
function Vector2:multiply_in_place(scalar)
    self.x = self.x * scalar
    self.y = self.y * scalar
    return self
end
-- }}}

-- {{{ Vector2:divide
function Vector2:divide(scalar)
    if scalar == 0 then
        error("Division by zero in Vector2:divide")
        return Vector2:new(0, 0)
    end
    return Vector2:new(self.x / scalar, self.y / scalar)
end
-- }}}

-- {{{ Vector2:divide_in_place
function Vector2:divide_in_place(scalar)
    if scalar == 0 then
        error("Division by zero in Vector2:divide_in_place")
        self.x = 0
        self.y = 0
    else
        self.x = self.x / scalar
        self.y = self.y / scalar
    end
    return self
end
-- }}}

-- {{{ Vector2:dot
function Vector2:dot(other)
    return self.x * other.x + self.y * other.y
end
-- }}}

-- {{{ Vector2:cross
function Vector2:cross(other)
    -- 2D cross product returns scalar (z-component of 3D cross product)
    return self.x * other.y - self.y * other.x
end
-- }}}

-- {{{ Vector2:angle
function Vector2:angle()
    return math.atan2(self.y, self.x)
end
-- }}}

-- {{{ Vector2:angle_to
function Vector2:angle_to(other)
    return math.atan2(other.y - self.y, other.x - self.x)
end
-- }}}

-- {{{ Vector2:rotate
function Vector2:rotate(angle)
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)
    return Vector2:new(
        self.x * cos_a - self.y * sin_a,
        self.x * sin_a + self.y * cos_a
    )
end
-- }}}

-- {{{ Vector2:rotate_in_place
function Vector2:rotate_in_place(angle)
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)
    local new_x = self.x * cos_a - self.y * sin_a
    local new_y = self.x * sin_a + self.y * cos_a
    self.x = new_x
    self.y = new_y
    return self
end
-- }}}

-- {{{ Vector2:lerp
function Vector2:lerp(other, t)
    return Vector2:new(
        self.x + (other.x - self.x) * t,
        self.y + (other.y - self.y) * t
    )
end
-- }}}

-- {{{ Vector2:reflect
function Vector2:reflect(normal)
    -- Reflect vector across a normal vector
    local dot_product = self:dot(normal)
    return self:subtract(normal:multiply(2 * dot_product))
end
-- }}}

-- {{{ Vector2:project
function Vector2:project(other)
    -- Project this vector onto another vector
    local dot_product = self:dot(other)
    local other_length_squared = other:length_squared()
    
    if other_length_squared == 0 then
        return Vector2:new(0, 0)
    end
    
    local scalar = dot_product / other_length_squared
    return other:multiply(scalar)
end
-- }}}

-- {{{ Vector2:perpendicular
function Vector2:perpendicular()
    -- Return perpendicular vector (90 degrees counter-clockwise)
    return Vector2:new(-self.y, self.x)
end
-- }}}

-- {{{ Vector2:is_zero
function Vector2:is_zero(epsilon)
    epsilon = epsilon or 1e-10
    return math.abs(self.x) < epsilon and math.abs(self.y) < epsilon
end
-- }}}

-- {{{ Vector2:equals
function Vector2:equals(other, epsilon)
    epsilon = epsilon or 1e-10
    return math.abs(self.x - other.x) < epsilon and math.abs(self.y - other.y) < epsilon
end
-- }}}

-- {{{ Vector2:clamp_length
function Vector2:clamp_length(max_length)
    local len = self:length()
    if len > max_length then
        return self:multiply(max_length / len)
    end
    return self:copy()
end
-- }}}

-- {{{ Vector2:clamp_length_in_place
function Vector2:clamp_length_in_place(max_length)
    local len = self:length()
    if len > max_length then
        self:multiply_in_place(max_length / len)
    end
    return self
end
-- }}}

-- {{{ Vector2:to_string
function Vector2:to_string()
    return string.format("Vector2(%.3f, %.3f)", self.x, self.y)
end
-- }}}

-- {{{ Static utility functions

-- {{{ Vector2.zero
function Vector2.zero()
    return Vector2:new(0, 0)
end
-- }}}

-- {{{ Vector2.one
function Vector2.one()
    return Vector2:new(1, 1)
end
-- }}}

-- {{{ Vector2.up
function Vector2.up()
    return Vector2:new(0, -1) -- Negative Y is up in screen coordinates
end
-- }}}

-- {{{ Vector2.down
function Vector2.down()
    return Vector2:new(0, 1)
end
-- }}}

-- {{{ Vector2.left
function Vector2.left()
    return Vector2:new(-1, 0)
end
-- }}}

-- {{{ Vector2.right
function Vector2.right()
    return Vector2:new(1, 0)
end
-- }}}

-- {{{ Vector2.from_angle
function Vector2.from_angle(angle, length)
    length = length or 1
    return Vector2:new(math.cos(angle) * length, math.sin(angle) * length)
end
-- }}}

-- {{{ Vector2.distance
function Vector2.distance(a, b)
    return a:distance_to(b)
end
-- }}}

-- {{{ Vector2.lerp
function Vector2.lerp(a, b, t)
    return a:lerp(b, t)
end
-- }}}

-- }}} End static functions

-- {{{ Metamethods for operator overloading

function Vector2.__add(a, b)
    return a:add(b)
end

function Vector2.__sub(a, b)
    return a:subtract(b)
end

function Vector2.__mul(a, b)
    if type(a) == "number" then
        return b:multiply(a)
    elseif type(b) == "number" then
        return a:multiply(b)
    else
        -- Dot product for vector * vector
        return a:dot(b)
    end
end

function Vector2.__div(a, b)
    if type(b) == "number" then
        return a:divide(b)
    else
        error("Vector2 division only supports scalar divisor")
        return Vector2:new(0, 0)
    end
end

function Vector2.__unm(a)
    return Vector2:new(-a.x, -a.y)
end

function Vector2.__eq(a, b)
    return a:equals(b)
end

function Vector2.__tostring(a)
    return a:to_string()
end

-- }}}

return Vector2
-- }}}