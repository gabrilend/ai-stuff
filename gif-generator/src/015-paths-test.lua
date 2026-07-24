-- 015-paths-test.lua — proof for the clock-face paths.
--
-- What this is, generally: checks the convention against hand
-- arithmetic — 12 is straight up, hours are 30 degrees, clockwise
-- sweeps pass through the hours in order, tangents stand
-- perpendicular to radii — and that the walls refuse ambiguous arcs
-- and directionless lines. Run: luajit src/015-paths-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local paths = require("014-paths")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name)
    end
end
-- }}}

-- {{{ local function near()
local function near(a, b, eps)
    return math.abs(a - b) < (eps or 1e-9)
end
-- }}}

-- the convention: 12 straight up, 3 due east, 6 down, spoken or bare
check("12 o'clock is straight up",
      near(paths.clock_angle(12) % (2 * math.pi), (3 * math.pi / 2)))
check("3 o'clock is due east", near(paths.clock_angle(3), 0))
check("6 o'clock is straight down (y grows downward)",
      near(paths.clock_angle(6), math.pi / 2))
check("spoken hours read the same as bare numbers",
      near(paths.clock_angle("7 o'clock"), paths.clock_angle(7)))
check("fractional spoken hours are legal",
      near(paths.clock_angle("7.2 o'clock"), paths.clock_angle(7.2)))

-- a clockwise 12-to-7 arc: starts up top, passes 3 at the
-- proportional progress, lands at 7 — sweeping 210 degrees
local arc = paths.arc{ center = {100, 100}, radius = 60,
                       from = 12, to = 7, turn = "clockwise" }
local x0, y0 = arc.at(0)
check("the arc starts at 12 (top of its circle)",
      near(x0, 100, 1e-6) and near(y0, 40, 1e-6))
-- 12→7 clockwise is 7 hours = 210°; 3 o'clock is 3 hours in = 3/7
local x3, y3 = arc.at(3 / 7)
check("the arc passes 3 o'clock at three sevenths of the way",
      near(x3, 160, 1e-6) and near(y3, 100, 1e-6))
local x7, y7 = arc.at(1)
local a7 = paths.clock_angle(7)
check("the arc lands at 7",
      near(x7, 100 + math.cos(a7) * 60, 1e-6)
      and near(y7, 100 + math.sin(a7) * 60, 1e-6))

-- the mirrored hand: counterclockwise 12-to-5 also sweeps 210°,
-- passing 9 o'clock three sevenths of the way (12 → 11 → ... → 5)
local mirror = paths.arc{ center = {100, 100}, radius = 60,
                          from = 12, to = 5, turn = "counterclockwise" }
local mx, my = mirror.at(3 / 7)
local a9 = paths.clock_angle(9)
check("the mirrored arc passes 9 o'clock three sevenths in",
      near(mx, 100 + math.cos(a9) * 60, 1e-6)
      and near(my, 100 + math.sin(a9) * 60, 1e-6))

-- tangents stand perpendicular to radii, and point along the turn
local tx, ty = arc.heading(0)
check("at 12, a clockwise tangent points due east",
      near(tx, 1, 1e-9) and near(ty, 0, 1e-9))
local mtx, mty = mirror.heading(0)
check("at 12, a counterclockwise tangent points due west",
      near(mtx, -1, 1e-9) and near(mty, 0, 1e-9))

-- lines: midpoint and constant unit heading
local line = paths.line{ from = {0, 0}, to = {30, 40} }
local lx, ly = line.at(0.5)
check("a line's midpoint is the midpoint", near(lx, 15) and near(ly, 20))
local lhx, lhy = line.heading(0.5)
check("a line's heading is unit length",
      near(lhx * lhx + lhy * lhy, 1))

-- points: stillness with no direction
local pt = paths.point{ at = {50, 60} }
local px, py = pt.at(0.99)
local phx, phy = pt.heading(0)
check("a point ignores progress", px == 50 and py == 60)
check("a point has no heading", phx == 0 and phy == 0)

-- the walls: ambiguous arcs, directionless lines, unreadable hours
check("an arc without a turn is refused",
      not pcall(paths.arc, { center = {0, 0}, radius = 10,
                             from = 12, to = 7 }))
check("a zero-length line is refused",
      not pcall(paths.line, { from = {5, 5}, to = {5, 5} }))
check("an unreadable clock position is refused",
      not pcall(paths.clock_angle, "half past nine"))

print(string.format("paths: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
