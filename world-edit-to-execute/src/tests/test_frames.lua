--[[
Test Suite: Frame-Based Direction Encoding

Validates the frame encoding system for pathfinding:
- Cardinal and ordinal direction encoding
- Roundtrip conversion (path → frames → path)
- ASCII art visualization
- Momentum operations
]]

-- {{{ Setup paths
package.path = package.path .. ";/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/?.lua"
package.path = package.path .. ";/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/?/init.lua"
-- }}}

local frames = require("runtime.pathfinding.frames")

-- {{{ Test utilities
local tests_run = 0
local tests_passed = 0

-- {{{ test
local function test(name, condition, expected, actual)
    tests_run = tests_run + 1
    if condition then
        tests_passed = tests_passed + 1
        print(string.format("  ✓ %s", name))
    else
        print(string.format("  ✗ %s", name))
        if expected and actual then
            print(string.format("    Expected: %s", tostring(expected)))
            print(string.format("    Actual:   %s", tostring(actual)))
        end
    end
end
-- }}}

-- {{{ section
local function section(name)
    print(string.format("\n[%s]", name))
end
-- }}}
-- }}}

-- {{{ Test: Cardinal Direction Constants
section("Cardinal Direction Constants")

test("NORTH = 0x0F", frames.NORTH == 0x0F, "0x0F", string.format("0x%02X", frames.NORTH))
test("SOUTH = 0xF0", frames.SOUTH == 0xF0, "0xF0", string.format("0x%02X", frames.SOUTH))
test("EAST = 0xCC", frames.EAST == 0xCC, "0xCC", string.format("0x%02X", frames.EAST))
test("WEST = 0x33", frames.WEST == 0x33, "0x33", string.format("0x%02X", frames.WEST))
-- }}}

-- {{{ Test: Ordinal Direction Constants
section("Ordinal Direction Constants")

test("NORTHEAST = 0x4C", frames.NORTHEAST == 0x4C, "0x4C", string.format("0x%02X", frames.NORTHEAST))
test("NORTHWEST = 0x1C", frames.NORTHWEST == 0x1C, "0x1C", string.format("0x%02X", frames.NORTHWEST))
test("SOUTHEAST = 0xC4", frames.SOUTHEAST == 0xC4, "0xC4", string.format("0x%02X", frames.SOUTHEAST))
test("SOUTHWEST = 0xC1", frames.SOUTHWEST == 0xC1, "0xC1", string.format("0x%02X", frames.SOUTHWEST))
-- }}}

-- {{{ Test: Special Frames
section("Special Frames")

test("ORIGIN = 0xFF (all near)", frames.ORIGIN == 0xFF, "0xFF", string.format("0x%02X", frames.ORIGIN))
test("OVERSHOOT = 0x00 (all far)", frames.OVERSHOOT == 0x00, "0x00", string.format("0x%02X", frames.OVERSHOOT))
-- }}}

-- {{{ Test: Frame to Vector Conversion
section("Frame to Vector Conversion")

local function test_frame_to_vec(name, frame, expected_dx, expected_dy)
    local dx, dy = frames.frame_to_vector(frame)
    local ok = (dx == expected_dx and dy == expected_dy)
    test(name, ok,
        string.format("(%d, %d)", expected_dx, expected_dy),
        string.format("(%d, %d)", dx, dy))
end

test_frame_to_vec("NORTH → (0, 1)", frames.NORTH, 0, 1)
test_frame_to_vec("SOUTH → (0, -1)", frames.SOUTH, 0, -1)
test_frame_to_vec("EAST → (1, 0)", frames.EAST, 1, 0)
test_frame_to_vec("WEST → (-1, 0)", frames.WEST, -1, 0)
test_frame_to_vec("NORTHEAST → (1, 1)", frames.NORTHEAST, 1, 1)
test_frame_to_vec("NORTHWEST → (-1, 1)", frames.NORTHWEST, -1, 1)
test_frame_to_vec("SOUTHEAST → (1, -1)", frames.SOUTHEAST, 1, -1)
test_frame_to_vec("SOUTHWEST → (-1, -1)", frames.SOUTHWEST, -1, -1)
test_frame_to_vec("ORIGIN → (0, 0)", frames.ORIGIN, 0, 0)
-- }}}

-- {{{ Test: Vector to Frame Conversion
section("Vector to Frame Conversion")

local function test_vec_to_frame(name, dx, dy, expected_frame)
    local frame = frames.vector_to_frame(dx, dy)
    test(name, frame == expected_frame,
        string.format("0x%02X", expected_frame),
        string.format("0x%02X", frame))
end

test_vec_to_frame("(0, 1) → NORTH", 0, 1, frames.NORTH)
test_vec_to_frame("(0, -1) → SOUTH", 0, -1, frames.SOUTH)
test_vec_to_frame("(1, 0) → EAST", 1, 0, frames.EAST)
test_vec_to_frame("(-1, 0) → WEST", -1, 0, frames.WEST)
test_vec_to_frame("(1, 1) → NORTHEAST", 1, 1, frames.NORTHEAST)
test_vec_to_frame("(-1, 1) → NORTHWEST", -1, 1, frames.NORTHWEST)
test_vec_to_frame("(1, -1) → SOUTHEAST", 1, -1, frames.SOUTHEAST)
test_vec_to_frame("(-1, -1) → SOUTHWEST", -1, -1, frames.SOUTHWEST)
test_vec_to_frame("(0, 0) → ORIGIN", 0, 0, frames.ORIGIN)
-- }}}

-- {{{ Test: Roundtrip Conversion
section("Roundtrip: Frame → Vector → Frame")

local function test_roundtrip(name, original_frame)
    local dx, dy = frames.frame_to_vector(original_frame)
    local recovered = frames.vector_to_frame(dx, dy)
    test(name, recovered == original_frame,
        string.format("0x%02X", original_frame),
        string.format("0x%02X", recovered))
end

test_roundtrip("NORTH roundtrip", frames.NORTH)
test_roundtrip("SOUTH roundtrip", frames.SOUTH)
test_roundtrip("EAST roundtrip", frames.EAST)
test_roundtrip("WEST roundtrip", frames.WEST)
test_roundtrip("NORTHEAST roundtrip", frames.NORTHEAST)
test_roundtrip("NORTHWEST roundtrip", frames.NORTHWEST)
test_roundtrip("SOUTHEAST roundtrip", frames.SOUTHEAST)
test_roundtrip("SOUTHWEST roundtrip", frames.SOUTHWEST)
-- }}}

-- {{{ Test: Path to Frames Conversion
section("Path to Frames Conversion")

local path = {
    { x = 0, y = 0 },
    { x = 1, y = 0 },  -- East
    { x = 2, y = 0 },  -- East
    { x = 3, y = 1 },  -- Northeast
    { x = 3, y = 2 },  -- North
}

local frame_path = frames.path_to_frames(path)

test("Start position captured",
    frame_path.start.x == 0 and frame_path.start.y == 0,
    "(0, 0)", string.format("(%d, %d)", frame_path.start.x, frame_path.start.y))

test("Frame count = path length - 1",
    #frame_path.frames == #path - 1,
    #path - 1, #frame_path.frames)

test("First step is EAST",
    frame_path.frames[1] == frames.EAST,
    "EAST", frames.frame_to_glyph(frame_path.frames[1]))

test("Second step is EAST",
    frame_path.frames[2] == frames.EAST,
    "EAST", frames.frame_to_glyph(frame_path.frames[2]))

test("Third step is NORTHEAST",
    frame_path.frames[3] == frames.NORTHEAST,
    "NORTHEAST", frames.frame_to_glyph(frame_path.frames[3]))

test("Fourth step is NORTH",
    frame_path.frames[4] == frames.NORTH,
    "NORTH", frames.frame_to_glyph(frame_path.frames[4]))
-- }}}

-- {{{ Test: Frames to Path Conversion (Roundtrip)
section("Frames to Path Conversion (Roundtrip)")

local recovered_path = frames.frames_to_path(frame_path)

test("Recovered path length matches original",
    #recovered_path == #path,
    #path, #recovered_path)

local positions_match = true
for i, wp in ipairs(path) do
    if recovered_path[i].x ~= wp.x or recovered_path[i].y ~= wp.y then
        positions_match = false
        print(string.format("    Mismatch at %d: expected (%d,%d), got (%d,%d)",
            i, wp.x, wp.y, recovered_path[i].x, recovered_path[i].y))
    end
end
test("All positions match after roundtrip", positions_match)
-- }}}

-- {{{ Test: ASCII Visualization
section("ASCII Visualization")

local ascii = frames.path_to_ascii(frame_path)
test("Path to ASCII produces arrows",
    ascii == "→→↗↑",
    "→→↗↑", ascii)

test("NORTH glyph is ↑", frames.frame_to_glyph(frames.NORTH) == "↑")
test("SOUTH glyph is ↓", frames.frame_to_glyph(frames.SOUTH) == "↓")
test("EAST glyph is →", frames.frame_to_glyph(frames.EAST) == "→")
test("WEST glyph is ←", frames.frame_to_glyph(frames.WEST) == "←")
test("ORIGIN glyph is ○", frames.frame_to_glyph(frames.ORIGIN) == "○")
test("OVERSHOOT glyph is ×", frames.frame_to_glyph(frames.OVERSHOOT) == "×")
-- }}}

-- {{{ Test: Frame Difference
section("Frame Difference (Similarity Metric)")

test("Same frame = 0 difference",
    frames.frame_difference(frames.NORTH, frames.NORTH) == 0)

test("NORTH vs SOUTH has high difference",
    frames.frame_difference(frames.NORTH, frames.SOUTH) > 100)

test("EAST vs WEST has high difference",
    frames.frame_difference(frames.EAST, frames.WEST) > 100)

test("NORTH vs NORTHEAST has moderate difference",
    frames.frame_difference(frames.NORTH, frames.NORTHEAST) > 0 and
    frames.frame_difference(frames.NORTH, frames.NORTHEAST) < 200)
-- }}}

-- {{{ Test: Momentum Structure
section("Momentum Structure")

local momentum = frames.Momentum.new(frames.EAST, 5)

test("Momentum direction is EAST",
    momentum.direction == frames.EAST)

test("Momentum count is 5",
    momentum.count == 5)

test("Momentum is not stationary",
    not momentum:is_stationary())

local vx, vy = momentum:get_vector()
test("Momentum vector is (5, 0)",
    vx == 5 and vy == 0,
    "(5, 0)", string.format("(%d, %d)", vx, vy))

momentum:decay(3)
test("After decay(3), count is 2",
    momentum.count == 2)

momentum:apply_force(frames.NORTH)
test("After apply_force(NORTH), count is 3",
    momentum.count == 3)

local new_mom = frames.Momentum.new(frames.ORIGIN, 0)
test("Zero momentum is stationary",
    new_mom:is_stationary())
-- }}}

-- {{{ Test: Apply Frame
section("Apply Frame to Position")

local x, y = frames.apply_frame(5, 5, frames.EAST)
test("apply_frame(5,5,EAST) = (6,5)",
    x == 6 and y == 5,
    "(6, 5)", string.format("(%d, %d)", x, y))

x, y = frames.apply_frame(5, 5, frames.NORTHEAST, 3)
test("apply_frame(5,5,NE,3) = (8,8)",
    x == 8 and y == 8,
    "(8, 8)", string.format("(%d, %d)", x, y))

x, y = frames.apply_frame(5, 5, frames.ORIGIN)
test("apply_frame with ORIGIN doesn't move",
    x == 5 and y == 5,
    "(5, 5)", string.format("(%d, %d)", x, y))
-- }}}

-- {{{ Test: Position Independence
section("Position Independence (Shape Preservation)")

-- Same frame sequence from different origins should produce same relative motion
local shape = { frames.EAST, frames.EAST, frames.NORTH, frames.NORTH }

local path_a = frames.frames_to_path({ start = { x = 0, y = 0 }, frames = shape })
local path_b = frames.frames_to_path({ start = { x = 100, y = 50 }, frames = shape })

-- Calculate displacement for each path
local disp_a = { x = path_a[#path_a].x - path_a[1].x, y = path_a[#path_a].y - path_a[1].y }
local disp_b = { x = path_b[#path_b].x - path_b[1].x, y = path_b[#path_b].y - path_b[1].y }

test("Same shape produces same displacement",
    disp_a.x == disp_b.x and disp_a.y == disp_b.y,
    string.format("(%d, %d)", disp_a.x, disp_a.y),
    string.format("(%d, %d)", disp_b.x, disp_b.y))

test("Displacement is (2, 2) for EENN shape",
    disp_a.x == 2 and disp_a.y == 2,
    "(2, 2)", string.format("(%d, %d)", disp_a.x, disp_a.y))
-- }}}

-- {{{ Summary
print(string.format("\n========================================"))
print(string.format("Tests: %d passed / %d total", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed! ✓")
    os.exit(0)
else
    print(string.format("FAILED: %d tests", tests_run - tests_passed))
    os.exit(1)
end
-- }}}
