-- test_camera_controls.lua - the arrow keys, the screen's edges and the wheel move the camera as WC3's do (issue 505c)
--
-- In plain terms: feeds the camera (camera.c) frames of input, as the
-- window would read them, and checks where it ends up: panning the way
-- the view looks at the stand-in speed, faster zoomed out; the screen's
-- outer pixels scrolling only when edges are on; the wheel zooming in
-- steps within the limits; never past the map's camera bounds. Then the
-- interface's keys that bring the view to the selection (a hero's key
-- twice, a control group's number twice, the idle worker's key), on a
-- fake game. Needs gcc; no raylib, no window.
--
-- Run with: luajit src/tests/test_camera_controls.lua [DIR] [BUILD]
-- DIR defaults to the project this file is in. Builds in BUILD, or in
-- $WETE_TEST_BUILD/camera-controls when that is set, or in
-- DIR/tmp/camera-controls.

local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local env_build = os.getenv("WETE_TEST_BUILD")
local BUILD = arg[2] or (env_build and env_build ~= "" and env_build .. "/camera-controls") or (DIR .. "/tmp/camera-controls")
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

local function near(a, b, tol) return a ~= nil and b ~= nil and math.abs(a - b) <= (tol or 0.01) end
local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local W, H = 1280, 720
-- }}}

-- {{{ builds
print("builds")
local src = DIR .. "/src/render/"
os.execute("mkdir -p " .. q(BUILD))
local ok = os.execute("gcc -std=c99 -Wall -Wextra -Werror -pedantic -c -o " .. q(BUILD .. "/camera_input.o") .. " " .. q(src .. "camera_input.c"))
test("camera_input.c builds alone, strict C99, no raylib", ok == 0 or ok == true)
local lib = camera.open(camera.build(DIR, BUILD))
local function at(x, y) return lib.new(x or 0, y or 0, 0) end
local function where(cam) return string.format("%.2f, %.2f, %.1f", cam.c.x, cam.c.y, cam.c.distance) end
-- }}}

-- {{{ the keys
print("the arrow keys")
local cam = at()
cam:step({}, 1)
test("no input moves nothing", near(cam.c.x, 0) and near(cam.c.y, 0) and near(cam.c.distance, 1650), where(cam))
cam:step({ up = true }, 1)
test("up for a second, looking north: 1400 north", near(cam.c.x, 0) and near(cam.c.y, 1400), where(cam))
cam:step({ down = true }, 0.5)
test("down for half a second: 700 back south", near(cam.c.x, 0) and near(cam.c.y, 700), where(cam))
cam:step({ right = true }, 1)
test("right: east", near(cam.c.x, 1400) and near(cam.c.y, 700), where(cam))
cam:step({ left = true }, 0.25)
test("left: west", near(cam.c.x, 1050) and near(cam.c.y, 700), where(cam))
cam:step({ left = true, right = true }, 1)
test("left and right together cancel", near(cam.c.x, 1050) and near(cam.c.y, 700), where(cam))
cam = at()
cam:step({ up = true, right = true }, 1)
test("up and right together go both ways", near(cam.c.x, 1400) and near(cam.c.y, 1400), where(cam))
cam:step({ up = true }, 0)
test("no time, no move", near(cam.c.x, 1400) and near(cam.c.y, 1400))
cam = at()
cam.c.distance = 3300
cam:step({ up = true }, 1)
test("zoomed out to twice the distance, twice the speed", near(cam.c.y, 2800), where(cam))
cam = at()
cam.c.rotation = 0
cam:step({ up = true }, 1)
test("looking east, up goes east", near(cam.c.x, 1400) and near(cam.c.y, 0), where(cam))
cam:step({ right = true }, 1)
test("and right goes south", near(cam.c.x, 1400) and near(cam.c.y, -1400), where(cam))
cam = at()
cam.c.rotation = 180
cam:step({ up = true, left = true }, 1)
test("looking west, up goes west and left goes south", near(cam.c.x, -1400) and near(cam.c.y, -1400), where(cam))
-- }}}

-- {{{ the screen's edges
print("the screen's edges")
local function ways(mx, my, edges)
    return lib.new(0, 0, 0):step({ edges = edges ~= false, mouse_x = mx, mouse_y = my, width = W, height = H }, 0)
end
test("the mouse in the middle scrolls nothing", ways(640, 360) == 0)
test("at the left edge: left", ways(0, 360) == 1)
test("the left edge is three pixels wide", ways(2, 360) == 1 and ways(3, 360) == 0)
test("at the right edge: right", ways(W - 1, 360) == 2 and ways(W - 3, 360) == 2 and ways(W - 4, 360) == 0)
test("at the top: up", ways(640, 0) == 4 and ways(640, 2) == 4 and ways(640, 3) == 0)
test("at the bottom: down", ways(640, H - 1) == 8 and ways(640, H - 3) == 8 and ways(640, H - 4) == 0)
test("in a corner: both ways", ways(0, 0) == 5 and ways(W - 1, H - 1) == 10)
test("with edges off, the edges scroll nothing", ways(0, 0, false) == 0 and ways(W - 1, H - 1, false) == 0)
cam = at()
cam:step({ edges = true, mouse_x = W - 1, mouse_y = 0, width = W, height = H }, 1)
test("at the top right corner for a second: north-east", near(cam.c.x, 1400) and near(cam.c.y, 1400), where(cam))
cam = at()
test("the keys still count with edges on", cam:step({ edges = true, down = true, mouse_x = 640, mouse_y = 360, width = W, height = H }, 1) == 8
    and near(cam.c.y, -1400))
-- }}}

-- {{{ the wheel
print("the wheel")
cam = at()
cam:step({ wheel = 1 }, 0.016)
test("a notch forward comes 150 closer", near(cam.c.distance, 1500), where(cam))
cam:step({ wheel = -3 }, 0.016)
test("three back go 450 further", near(cam.c.distance, 1950), where(cam))
cam:step({ wheel = 100 }, 0.016)
test("no closer than the nearest", near(cam.c.distance, 250), where(cam))
cam:step({ wheel = -100 }, 0.016)
test("no further than the furthest", near(cam.c.distance, 9000), where(cam))
test("zooming doesn't pan", near(cam.c.x, 0) and near(cam.c.y, 0))
-- }}}

-- {{{ the map's camera bounds
print("the map's camera bounds")
cam = at(0, 0)
cam:bounds_from_w3i({ -2000, -1000, 2000, 1000, -2000, 1000, 2000, -1000 })
cam:step({ up = true, right = true }, 10)
test("panning stops at the bounds' corner", near(cam.c.x, 2000) and near(cam.c.y, 1000), where(cam))
cam:step({ left = true }, 1)
test("and leaves along the edge", near(cam.c.x, 600) and near(cam.c.y, 1000), where(cam))
cam:step({ edges = true, mouse_x = 0, mouse_y = H - 1, width = W, height = H }, 10)
test("the edges stop there too", near(cam.c.x, -2000) and near(cam.c.y, -1000), where(cam))
-- }}}

-- {{{ the keys that bring the view to the selection (the interface)
print("to the selection")
local hud_mod = require("ui.wc3.hud")
local function fake_game()
    local g = { player = 0, camera_at = { 0, 0 } }
    local function unit(id, spec, x, y) return { id = id, spec = spec, player = 0, x = x, y = y, z = 0, name = id } end
    g.units = {
        unit("hfoo", { design = "unit", archetype = "infantry" }, 3000, -3000),
        unit("Hpal", { design = "unit", archetype = "infantry", hero = true }, 3600, -2400),
        unit("hpea", { design = "unit", archetype = "worker" }, 3800, -1500),
    }
    g.db = {
        unit_list = function() return {} end,
        unit_button = function(id) return { name = id } end,
        ability_button = function(id) return { name = id } end,
    }
    g.to_screen = function(x, y) return x / 10, -y / 10, true end
    g.to_ground = function(sx, sy) return sx * 10, -sy * 10 end
    g.camera = function() return g.camera_at[1], g.camera_at[2], 1650 end
    g.set_camera = function(x, y) g.camera_at = { x, y } end
    g.order = function() end
    g.resources = function() return { gold = 0, lumber = 0, food = 0, food_cap = 0 } end
    g.time_of_day = function() return 8 end
    g.minimap = { x0 = -10000, y0 = -10000, x1 = 10000, y1 = 10000 }
    g.players = { { number = 0, name = "Red", team = 1 } }
    g.quests = { main = {}, optional = {} }
    g.portrait = function() end
    g.quit = function() end
    return g
end
local g = fake_game()
local hud = hud_mod.new(g, W, H)
local foot, pal, pea = g.units[1], g.units[2], g.units[3]
local none = {}
hud:key("F1", none)
test("a hero's key once selects the hero, the view stays", hud.selection[1] == pal and near(g.camera_at[1], 0) and near(g.camera_at[2], 0))
hud:key("F1", none)
test("twice brings the view to it", near(g.camera_at[1], pal.x) and near(g.camera_at[2], pal.y))
g.camera_at = { 0, 0 }
hud:select({ foot })
hud:key("1", { ctrl = true })
hud:select({ pal })
hud.time = 10
hud:key("1", none)
test("a group's number once selects the group, the view stays", hud.selection[1] == foot and near(g.camera_at[1], 0))
hud.time = 10.3
hud:key("1", none)
test("twice quickly brings the view to it", near(g.camera_at[1], foot.x) and near(g.camera_at[2], foot.y))
g.camera_at = { 0, 0 }
hud.time = 20
hud:key("1", none)
hud.time = 21
hud:key("1", none)
test("twice slowly does not", near(g.camera_at[1], 0) and near(g.camera_at[2], 0))
hud:key("F8", none)
test("the idle worker's key selects it and brings the view to it", hud.selection[1] == pea
    and near(g.camera_at[1], pea.x) and near(g.camera_at[2], pea.y))
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("camera controls: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
