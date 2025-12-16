-- Simple Vector2 test without any dependencies
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

function Vector2:lerp(other, t)
    return Vector2:new(
        self.x + (other.x - self.x) * t,
        self.y + (other.y - self.y) * t
    )
end

-- Test
print("Creating vectors...")
local start = Vector2:new(100, 200)
local end_point = Vector2:new(400, 300)

print("Testing lerp...")
local result = start:lerp(end_point, 0.5)
print("Result:", result.x, result.y)

print("SUCCESS")