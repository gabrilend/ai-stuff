package.path = package.path .. ';./?.lua'
local Vector2 = require('src.utils.vector2')

print("Step 1: Create vectors")
local start = Vector2:new(100, 200)
local end_point = Vector2:new(400, 300)

print("Step 2: Test lerp directly")
local t = 0.5
local result = start:lerp(end_point, t)
print("Lerp successful:", result.x, result.y)

print("Step 3: Test table operations")
local waypoints = {}
table.insert(waypoints, result)
print("Table insert successful, length:", #waypoints)

print("Step 4: Test loop")
for i = 0, 3 do
    print("Loop iteration:", i)
    local t_val = i / 3
    local point = start:lerp(end_point, t_val)
    table.insert(waypoints, point)
    print("Inserted point:", point.x, point.y)
end

print("SUCCESS: All operations completed")
print("Final waypoints count:", #waypoints)