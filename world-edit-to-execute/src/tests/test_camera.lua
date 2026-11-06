-- test_camera.lua - the camera's numbers give the ground points worked out by hand (issue 501d)
--
-- In plain terms: puts WC3's default camera over known points and asks it
-- which ground point is under known screen points, and which ground is in
-- view. The answers must match the ones this test works out by itself
-- from the camera's angles (plain trigonometry, not the camera's own
-- vectors); a screen point taken to the ground and back must land where
-- it started; the target must stay inside the map's camera bounds. Needs
-- gcc; no raylib, no window.
--
-- Run with: luajit src/tests/test_camera.lua [DIR] [BUILD]
-- DIR defaults to the project this file is in. Builds in BUILD, or in
-- $WETE_TEST_BUILD/camera when that is set, or in DIR/tmp/camera.

local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local env_build = os.getenv("WETE_TEST_BUILD")
local BUILD = arg[2] or (env_build and env_build ~= "" and env_build .. "/camera") or (DIR .. "/tmp/camera")
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local camera = require("render.camera")

-- {{{ Test utilities
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. tostring(msg) or ""))
    end
end

local function near(a, b, tol) return a ~= nil and b ~= nil and math.abs(a - b) <= (tol or 0.05) end
local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function run(command)
    local ok = os.execute(command)
    return ok == 0 or ok == true
end
local rad = math.pi / 180
local W, H = 1280, 720
-- }}}

-- {{{ builds
print("builds")
local src = DIR .. "/src/render/"
os.execute("mkdir -p " .. q(BUILD))
test("camera.c builds alone, strict C99, no raylib", run("gcc -std=c99 -Wall -Wextra -Werror -pedantic -c -o "
    .. q(BUILD .. "/camera.o") .. " " .. q(src .. "camera.c")))
local lib = camera.open(camera.build(DIR, BUILD))
-- }}}

-- {{{ WC3's default camera
print("WC3's default camera")
local cam = lib.new(0, 0, 0)
local c = cam.c
test("distance 1650, angle of attack 304, rotation 90, fov 70, far clip 5000",
    near(c.distance, 1650) and near(c.aoa, 304) and near(c.rotation, 90) and near(c.fov, 70) and near(c.farz, 5000))
test("no bounds until a map gives them", not c.has_bounds)

-- worked out by hand: the eye is 1650 back along a line 56 degrees down,
-- looking north, so it is south of the target and above it
local DOWN = 56
local eye_y, eye_z = -1650 * math.cos(DOWN * rad), 1650 * math.sin(DOWN * rad)
local f = cam:frame(W, H)
test("the eye is south of the target and above it", near(f.eye[0], 0) and near(f.eye[1], eye_y) and near(f.eye[2], eye_z),
    string.format("%.2f %.2f %.2f", f.eye[0], f.eye[1], f.eye[2]))

local x, y = cam:screen_to_ground(W, H, W / 2, H / 2)
test("the screen's centre is the target", near(x, 0) and near(y, 0), tostring(x) .. ", " .. tostring(y))

-- a point on the centre column a quarter of the screen up or down: its
-- ray is atan(0.5 * tan 35) further from the view's line
local off = math.atan(0.5 * math.tan(35 * rad)) / rad
local function along_column(angle) return eye_y + eye_z / math.tan(angle * rad) end
x, y = cam:screen_to_ground(W, H, W / 2, H / 4)
test("a quarter up the centre: north of the target, where the angle says", near(x, 0) and near(y, along_column(DOWN - off), 0.1),
    tostring(y) .. " vs " .. along_column(DOWN - off))
x, y = cam:screen_to_ground(W, H, W / 2, H * 3 / 4)
test("a quarter down: south of it, where the angle says", near(x, 0) and near(y, along_column(DOWN + off), 0.1),
    tostring(y) .. " vs " .. along_column(DOWN + off))

-- a point on the centre row a quarter of the screen right: east, by the
-- view's half width at the target's depth (1650) times a half
local half_w = 1650 * math.tan(35 * rad) * W / H
x, y = cam:screen_to_ground(W, H, W * 3 / 4, H / 2)
test("a quarter right on the centre row: east, at the target's latitude", near(x, half_w / 2, 0.1) and near(y, 0),
    tostring(x) .. " vs " .. half_w / 2)
local sx, sy = cam:world_to_screen(W, H, 0, 0, 0)
test("the target is drawn at the screen's centre", near(sx, W / 2) and near(sy, H / 2))
sx, sy = cam:world_to_screen(W, H, 0, along_column(DOWN - off), 0)
test("and the point a quarter up, a quarter up", near(sx, W / 2) and near(sy, H / 4), tostring(sx) .. ", " .. tostring(sy))
-- }}}

-- {{{ the target elsewhere, and the ground's height
print("moved, and on high ground")
cam = lib.new(1000, -500, 100)
x, y = cam:screen_to_ground(W, H, W / 2, H / 2)
test("the centre is the target, on ground at the target's height", near(x, 1000) and near(y, -500))
x, y = cam:screen_to_ground(W, H, W / 2, H / 2, 0)
test("on lower ground the centre's ray goes on past the target, north", near(x, 1000) and y > -500
    and near(y, -500 + 100 / math.tan(DOWN * rad), 0.1), tostring(y))
-- }}}

-- {{{ there and back, turned and tilted
print("there and back")
cam = lib.new(-2300, 4100, 30)
cam.c.rotation, cam.c.aoa, cam.c.distance = 31, 320, 2400
local all_back, worst = true, 0
for _, p in ipairs({ { 0, 360 }, { 640, 360 }, { 1279, 719 }, { 100, 500 }, { 900, 200 }, { 1200, 600 } }) do
    local gx, gy = cam:screen_to_ground(W, H, p[1], p[2])
    local bx, by
    if gx then bx, by = cam:world_to_screen(W, H, gx, gy, 30) end
    if not bx then all_back = false
    else worst = math.max(worst, math.abs(bx - p[1]), math.abs(by - p[2])) end
end
test("screen to ground and back lands within a hundredth of a pixel", all_back and worst < 0.01, tostring(worst))
-- facing east (rotation 0), up the screen is further east
cam = lib.new(0, 0, 0)
cam.c.rotation = 0
x, y = cam:screen_to_ground(W, H, W / 2, H / 4)
test("facing east, up the screen is east", near(y, 0) and near(x, along_column(DOWN - off), 0.1) and x > 0, tostring(x))
x, y = cam:screen_to_ground(W, H, W * 3 / 4, H / 2)
test("facing east, the screen's right is south", near(x, 0) and near(y, -half_w / 2, 0.1), tostring(y))
-- }}}

-- {{{ nothing to answer
print("nothing to answer")
cam = lib.new(0, 0, 0)
cam.c.aoa = 350                                       -- ten degrees down: the top of the screen looks up
x = cam:screen_to_ground(W, H, W / 2, 0)
test("above the horizon there is no ground point", x == nil)
x = cam:screen_to_ground(W, H, W / 2, H / 2, 10000)
test("nor for ground above the eye", x == nil)
x = cam:screen_to_ground(W, H, W / 2, 0, 10000)
test("nor for a rising ray under ground above the eye", x == nil)
f = cam:frame(1, 0.5)
test("a screen twice as wide as high has a view twice as wide", near(f.tan_x, 2 * f.tan_y, 1e-6))
f = cam:frame(W, 0)
test("a screen of no height has a square view, not a broken one", near(f.tan_x, f.tan_y, 1e-6))
cam = lib.new(0, 0, 0)
test("a point behind the eye is not drawn", cam:world_to_screen(W, H, 0, -5000, 0) == nil)
test("a point beside the eye, level with it, is not drawn", cam:world_to_screen(W, H, 300, eye_y, eye_z) == nil)
-- }}}

-- {{{ the ground in view
print("the ground in view")
cam = lib.new(0, 0, 0)
local quad, reached = cam:view_quad(W, H)
test("all four corners reach the ground at the default distance", reached == 4, reached)
local top_y, bottom_y = along_column(DOWN - 35), along_column(DOWN + 35)
test("the top corners at the top edge's distance, the bottom ones at the bottom's",
    near(quad[2], top_y, 0.5) and near(quad[4], top_y, 0.5) and near(quad[6], bottom_y, 0.5) and near(quad[8], bottom_y, 0.5),
    string.format("%.1f %.1f / %.1f %.1f", quad[2], quad[6], top_y, bottom_y))
test("left and right mirror each other", near(quad[1], -quad[3], 0.01) and near(quad[7], -quad[5], 0.01))
test("a trapezoid: wider at the far edge", quad[3] - quad[1] > quad[5] - quad[7] and quad[5] > quad[7])
test("in order: top left, top right, bottom right, bottom left", quad[1] < 0 and quad[3] > 0 and quad[5] > 0 and quad[7] < 0)
local r = cam:view_rect(W, H)
test("the rectangle around it", near(r.min_x, quad[1]) and near(r.max_x, quad[3]) and near(r.min_y, quad[6]) and near(r.max_y, quad[2]))
-- zoomed out, the top edge looks past the far clip
cam.c.distance = 5000
quad, reached = cam:view_quad(W, H)
test("zoomed out, only the bottom corners reach the ground", reached == 2, reached)
local ey9, tan_y = -5000 * math.cos(DOWN * rad), math.tan(35 * rad)
local far_y = ey9 + 5000 * (math.cos(DOWN * rad) + math.sin(DOWN * rad) * tan_y)
test("the top ones are where they cross the far clip", near(quad[2], far_y, 0.5) and near(quad[1], -5000 * tan_y * W / H, 0.5),
    string.format("%.1f vs %.1f", quad[2], far_y))
test("and the bottom ones still on the ground", near(quad[6], ey9 + 5000 * math.sin(DOWN * rad) / math.tan((DOWN + 35) * rad), 0.5))
r = cam:view_rect(W, H)
test("its rectangle holds all four", r.min_x <= quad[7] and r.max_x >= quad[3] and r.max_y >= quad[2] and r.min_y <= quad[6])
-- turned, each side of the rectangle comes from a different corner
cam = lib.new(700, -300, 0)
cam.c.rotation, cam.c.aoa = 31, 315
quad = cam:view_quad(W, H)
r = cam:view_rect(W, H)
local lo_x, hi_x, lo_y, hi_y = math.huge, -math.huge, math.huge, -math.huge
for i = 1, 7, 2 do
    lo_x, hi_x = math.min(lo_x, quad[i]), math.max(hi_x, quad[i])
    lo_y, hi_y = math.min(lo_y, quad[i + 1]), math.max(hi_y, quad[i + 1])
end
test("turned, the rectangle is the corners' least and greatest", near(r.min_x, lo_x) and near(r.max_x, hi_x)
    and near(r.min_y, lo_y) and near(r.max_y, hi_y), string.format("%.1f %.1f %.1f %.1f", r.min_x, r.min_y, r.max_x, r.max_y))
local every_way = true
for _, turn in ipairs({ 121, 211, 301, 0, 180 }) do
    cam.c.rotation = turn
    quad = cam:view_quad(W, H)
    r = cam:view_rect(W, H)
    lo_x, hi_x, lo_y, hi_y = math.huge, -math.huge, math.huge, -math.huge
    for i = 1, 7, 2 do
        lo_x, hi_x = math.min(lo_x, quad[i]), math.max(hi_x, quad[i])
        lo_y, hi_y = math.min(lo_y, quad[i + 1]), math.max(hi_y, quad[i + 1])
    end
    every_way = every_way and near(r.min_x, lo_x) and near(r.max_x, hi_x) and near(r.min_y, lo_y) and near(r.max_y, hi_y)
end
test("and turned every other way", every_way)
-- tilted to the horizon, nothing reaches it
cam = lib.new(0, 0, 0)
cam.c.aoa = 360
quad, reached = cam:view_quad(W, H)
test("looking level, no corner reaches the ground", reached == 0, reached)
-- }}}

-- {{{ the map's camera bounds
print("the map's camera bounds")
-- as war3map.w3i stores them: lower left, upper right, upper left, lower right
local BOUNDS = { -3000, -2500, 3200, 2800, -3000, 2800, 3200, -2500 }
cam = lib.new(5000, -9000, 0)
cam:bounds_from_w3i(BOUNDS)
test("the bounds are the rectangle of the four corners", cam.c.has_bounds and near(cam.c.bounds.min_x, -3000)
    and near(cam.c.bounds.min_y, -2500) and near(cam.c.bounds.max_x, 3200) and near(cam.c.bounds.max_y, 2800))
test("a target outside is brought in when the bounds are given", near(cam.c.x, 3200) and near(cam.c.y, -2500))
cam:look_at(-4000, 3000)
test("looking at a point past the corner stops at the corner", near(cam.c.x, -3000) and near(cam.c.y, 2800))
cam:look_at(100, 200)
test("a point inside is looked at as given", near(cam.c.x, 100) and near(cam.c.y, 200))
cam:look_at(3200, -2500)
test("the edges are inside", near(cam.c.x, 3200) and near(cam.c.y, -2500))
cam:bounds_from_w3i({ 500, 400, -100, -200, -100, 400, 500, -200 })
test("corners in any order give the same rectangle", near(cam.c.bounds.min_x, -100) and near(cam.c.bounds.max_x, 500)
    and near(cam.c.bounds.min_y, -200) and near(cam.c.bounds.max_y, 400) and near(cam.c.x, 500) and near(cam.c.y, -200))
cam.c.distance = 20
cam:clamp()
test("the distance is held to its nearest", near(cam.c.distance, 250))
cam.c.distance = 20000
cam:clamp()
test("and to its furthest", near(cam.c.distance, 9000))
cam:bounds_from_w3i({ 0, 0, 10, 10, 5, 20, 30, -40 })
test("the last corner counts as much as the first", near(cam.c.bounds.min_x, 0) and near(cam.c.bounds.max_x, 30)
    and near(cam.c.bounds.min_y, -40) and near(cam.c.bounds.max_y, 20))
lib.C.camera_init(cam.c, 1, 2, 3)
test("starting again forgets the bounds", not cam.c.has_bounds and near(cam.c.bounds.max_x, 0) and near(cam.c.bounds.min_y, 0)
    and near(cam.c.bounds.min_x, 0) and near(cam.c.bounds.max_y, 0))
local free = lib.new(0, 0, 0)
free:look_at(-90000, 90000)
test("with no bounds the target goes anywhere", near(free.c.x, -90000) and near(free.c.y, 90000))
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("camera: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
