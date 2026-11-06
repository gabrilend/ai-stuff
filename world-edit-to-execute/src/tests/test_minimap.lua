-- test_minimap.lua - the minimap fits the map, shows units and the camera's view, and moves the camera (issues 507a, 507c, 507d, 507e)
--
-- In plain terms: a map's points go to the minimap and back, on a square
-- map and on maps twice as wide and twice as tall, fitted as WC3 fits
-- them (one scale, centred, the rest dark); the interface draws a dot per
-- unit at its point, in its owner's colour or the ally colours, larger
-- for buildings; the box for the camera's view comes from the real camera
-- (camera.c), moves and changes shape with it and is cut to the map; and
-- clicking, dragging and right-clicking on the minimap move the camera
-- and order the selection to the right point. A fake game, no window.
-- Needs gcc for the camera.
--
-- Run with: luajit src/tests/test_minimap.lua [DIR] [BUILD]
-- DIR defaults to the project this file is in. Builds in BUILD, or in
-- $WETE_TEST_BUILD/minimap when that is set, or in DIR/tmp/minimap.

local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local env_build = os.getenv("WETE_TEST_BUILD")
local BUILD = arg[2] or (env_build and env_build ~= "" and env_build .. "/minimap") or (DIR .. "/tmp/minimap")
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local minimap = require("ui.wc3.minimap")
local hud_mod = require("ui.wc3.hud")
local designs = require("geometry.designs")
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

local function near(a, b, tol) return a ~= nil and b ~= nil and math.abs(a - b) <= (tol or 0.001) end
local function pt(a, b) return string.format("%.3f, %.3f", a or 0 / 0, b or 0 / 0) end
-- }}}

-- {{{ 507a: a square map
print("a square map")
local RECT = { x = 38, y = 500, w = 176, h = 176 }
local mm = minimap.new({ x0 = -4096, y0 = -4096, x1 = 4096, y1 = 4096 }, RECT)
local p = mm.picture
test("the picture fills the square", p.x == 38 and p.y == 500 and p.w == 176 and p.h == 176)
local px, py = mm:to_minimap(-4096, 4096)
test("the north-west corner is the top left", near(px, 38) and near(py, 500), pt(px, py))
px, py = mm:to_minimap(4096, -4096)
test("the south-east corner is the bottom right", near(px, 214) and near(py, 676), pt(px, py))
px, py = mm:to_minimap(0, 0)
test("the middle is the middle", near(px, 126) and near(py, 588))
px, py = mm:to_minimap(1024, 2048)
test("north is up, east is right", near(px, 126 + 22) and near(py, 588 - 44), pt(px, py))
local x, y = mm:to_world(126 + 22, 588 - 44)
test("and back", near(x, 1024, 0.01) and near(y, 2048, 0.01), pt(x, y))
-- }}}

-- {{{ 507a: maps that are not square
print("maps that are not square")
mm = minimap.new({ x0 = 0, y0 = 0, x1 = 8192, y1 = 4096 }, RECT)
p = mm.picture
test("twice as wide: the full width, half the height, centred", near(p.x, 38) and near(p.w, 176)
    and near(p.h, 88) and near(p.y, 544), pt(p.y, p.h))
px, py = mm:to_minimap(0, 4096)
test("its north-west corner at the picture's top left", near(px, 38) and near(py, 544), pt(px, py))
px, py = mm:to_minimap(8192, 0)
test("its south-east corner at the picture's bottom right", near(px, 214) and near(py, 632), pt(px, py))
px, py = mm:to_minimap(4096, 1024)
test("one scale across and down", near(px, 126) and near(py, 544 + 66), pt(px, py))
x, y = mm:to_world(126, 610)
test("and back", near(x, 4096, 0.01) and near(y, 1024, 0.01), pt(x, y))
x, y = mm:to_world(100, 510)
test("a point in the dark margin above is the map's north edge", near(y, 4096) and near(x, (100 - 38) / 176 * 8192, 0.01), pt(x, y))
x, y = mm:to_world(10, 700)
test("a point past the corner is the map's corner", near(x, 0) and near(y, 0), pt(x, y))
test("the margin is still the minimap", mm:inside(100, 510) and not mm:inside(100, 499) and not mm:inside(214, 600))
test("its top left pixel is in, the pixels past its right and bottom are out", mm:inside(38, 500)
    and not mm:inside(37.9, 600) and not mm:inside(100, 676) and mm:inside(213.9, 675.9))
x, y = mm:to_world(300, 588)
test("a point past the right is the map's east edge", near(x, 8192) and near(y, 2048, 0.01), pt(x, y))
local flat = minimap.new({ x0 = 5, y0 = 5, x1 = 5, y1 = 900 }, RECT)
test("a map with no width fills the square rather than breaking", flat.picture.w == 176 and flat.picture.h == 176
    and flat.picture.x == 38)
flat = minimap.new({ x0 = 5, y0 = 5, x1 = 900, y1 = 5 }, RECT)
test("nor with no height", flat.picture.w == 176 and flat.picture.h == 176)

mm = minimap.new({ x0 = -1000, y0 = -3000, x1 = 1000, y1 = 1000 }, RECT)
p = mm.picture
test("twice as tall: the full height, half the width, centred", near(p.y, 500) and near(p.h, 176)
    and near(p.w, 88) and near(p.x, 82), pt(p.x, p.w))
px, py = mm:to_minimap(-1000, 1000)
test("its north-west corner at the picture's top left", near(px, 82) and near(py, 500), pt(px, py))
px, py = mm:to_minimap(0, -1000)
test("its middle at the middle", near(px, 126) and near(py, 588), pt(px, py))
x, y = mm:to_world(50, 588)
test("a point in the dark margin left is the map's west edge", near(x, -1000) and near(y, -1000), pt(x, y))
-- }}}

-- {{{ a fake game and a recorder
local function fake_game(extent)
    local g = { player = 0, orders = {}, camera_at = { 0, 0 } }
    local function unit(id, spec, player, x0, y0) return { id = id, spec = spec, player = player, x = x0, y = y0, z = 0, name = id } end
    g.units = {
        unit("hfoo", { design = "unit", archetype = "infantry" }, 0, 2048, 1024),
        unit("hbar", { design = "building", size = "medium" }, 0, 6144, 3072),
        unit("ogru", { design = "unit", archetype = "infantry" }, 1, 4096, 2048),
        unit("nban", { design = "unit", archetype = "infantry" }, 12, 1024, 3072),
        unit("hpea", { design = "unit", archetype = "worker" }, 0, 7000, 500),
    }
    g.units[5].alive = false
    g.db = {
        unit_list = function() return {} end,
        unit_button = function(id) return { name = id } end,
        ability_button = function(id) return { name = id } end,
    }
    g.to_screen = function(x0, y0) return x0 / 10, -y0 / 10, true end
    g.to_ground = function(sx, sy) return sx * 10, -sy * 10 end
    g.camera = function() return g.camera_at[1], g.camera_at[2], 1650 end
    g.set_camera = function(x0, y0) g.camera_at = { x0, y0 } end
    g.order = function(list, kind, x0, y0) g.orders[#g.orders + 1] = { list = list, kind = kind, x = x0, y = y0 } end
    g.resources = function() return { gold = 0, lumber = 0, food = 0, food_cap = 0 } end
    g.time_of_day = function() return 8 end
    g.minimap = extent
    g.players = { { number = 0, name = "Red", team = 1 }, { number = 1, name = "Blue", team = 2 } }
    g.quests = { main = {}, optional = {} }
    g.portrait = function() end
    g.quit = function() end
    return g
end

local function recorder()
    local calls = { rect = {}, line = {}, image = {} }
    local ui = setmetatable({
        ui_rect = function(...) calls.rect[#calls.rect + 1] = { ... } end,
        ui_line = function(...) calls.line[#calls.line + 1] = { ... } end,
        ui_image = function(...) calls.image[#calls.image + 1] = { ... } end,
        ui_text_width = function(s, size) return #s * size / 2 end,
    }, { __index = function() return function() end end })
    return ui, calls
end

local W, H = 1280, 720
local on_minimap      -- a line drawn in the minimap's square, its edges in
local EXTENT = { x0 = 0, y0 = 0, x1 = 8192, y1 = 4096 }
local g = fake_game(EXTENT)
local hud = hud_mod.new(g, W, H)
local r = hud.r.minimap
local fitted = minimap.new(EXTENT, r)
function on_minimap(c) return c[1] >= r.x and c[1] <= r.x + r.w and c[2] >= r.y and c[2] <= r.y + r.h end
-- }}}

-- {{{ the interface uses the fitted minimap
print("the interface's minimap")
px, py = hud:world_to_minimap(4096, 1024)
local fx, fy = fitted:to_minimap(4096, 1024)
test("the interface puts map points where the fitted minimap does", near(px, fx) and near(py, fy), pt(px, py))
x, y = hud:minimap_to_world(fx, fy)
test("and back", near(x, 4096, 0.01) and near(y, 1024, 0.01))
g.minimap.image = "terrain"
local ui, calls = recorder()
hud:draw(ui)
local img = calls.image[1]
test("the terrain picture is drawn over the fitted rectangle, not the whole square", img and img[1] == "terrain"
    and near(img[2], fitted.picture.x) and near(img[3], fitted.picture.y) and near(img[4], fitted.picture.w) and near(img[5], fitted.picture.h),
    img and pt(img[3], img[5]))
local dark = false
for _, c in ipairs(calls.rect) do
    if near(c[1], r.x) and near(c[2], r.y) and near(c[3], r.w) and near(c[4], r.h) and c[5] == 8 and c[6] == 8 and c[7] == 10 then dark = true end
end
test("the whole square is darkened first", dark)
hud:key("T", { alt = true })
ui, calls = recorder()
hud:draw(ui)
test("with the terrain toggled off, no picture", #calls.image == 0, #calls.image)
hud:key("T", { alt = true })
g.minimap.image = nil
-- }}}

-- {{{ 507c: unit dots
print("unit dots")
local function dot_at(cs, wx, wy)
    local cx, cy = fitted:to_minimap(wx, wy)
    for _, c in ipairs(cs.rect) do
        if near(c[1] + c[3] / 2, cx) and near(c[2] + c[4] / 2, cy) and c[3] <= 3 then return c end
    end
end
ui, calls = recorder()
hud:draw(ui)
local foot = dot_at(calls, 2048, 1024)
local red = designs.TEAM[0]
test("a dot at a unit's point, in its owner's colour", foot and foot[3] == 2 and foot[5] == red[1] and foot[6] == red[2] and foot[7] == red[3])
local bar = dot_at(calls, 6144, 3072)
test("a building's dot is larger", bar and bar[3] == 3)
local grunt = dot_at(calls, 4096, 2048)
local blue = designs.TEAM[1]
test("another player's in theirs", grunt and grunt[5] == blue[1] and grunt[6] == blue[2])
test("a creep's is drawn", dot_at(calls, 1024, 3072) ~= nil)
test("a dead unit has none", dot_at(calls, 7000, 500) == nil)
g.units[1].x = 3000
ui, calls = recorder()
hud:draw(ui)
test("the dot follows the unit", dot_at(calls, 3000, 1024) ~= nil and dot_at(calls, 2048, 1024) == nil)
hud:key("A", { alt = true })
ui, calls = recorder()
hud:draw(ui)
foot, grunt = dot_at(calls, 3000, 1024), dot_at(calls, 4096, 2048)
local creep = dot_at(calls, 1024, 3072)
test("the ally colours: own units green", foot and foot[5] == 60 and foot[6] == 220)
test("enemies red", grunt and grunt[5] == 230 and grunt[6] == 60)
test("creeps yellow", creep and creep[5] == 240 and creep[6] == 220)
hud:key("A", { alt = true })
hud:key("R", { alt = true })
ui, calls = recorder()
hud:draw(ui)
test("creeps hidden by their toggle", dot_at(calls, 1024, 3072) == nil and dot_at(calls, 4096, 2048) ~= nil)
hud:key("R", { alt = true })
-- }}}

-- {{{ 507d: the camera's view
print("the camera's view")
local build_ok, lib = pcall(function() return camera.open(camera.build(DIR, BUILD)) end)
test("the camera builds", build_ok, lib)
local big = minimap.new({ x0 = 0, y0 = 0, x1 = 16384, y1 = 8192 }, r)   -- room for the whole view
local cam = lib.new(8192, 4096, 0)
local function inside_picture(box)
    local q = fitted.picture
    for _, v in ipairs(box) do
        if v[1] < q.x - 1e-3 or v[1] > q.x + q.w + 1e-3 or v[2] < q.y - 1e-3 or v[2] > q.y + q.h + 1e-3 then return false end
    end
    return true
end
local quad = cam:view_quad(W, H)
local box = big:view_box(quad)
local want = {}
for i = 1, 7, 2 do want[#want + 1] = { big:to_minimap(quad[i], quad[i + 1]) } end
local same = #box == 4
for i = 1, 4 do same = same and box[i] and near(box[i][1], want[i][1]) and near(box[i][2], want[i][2]) end
test("in the map's middle the box is the view's four corners", same, #box)
test("wider at the top than the bottom, as the camera looks north", box[2][1] - box[1][1] > box[3][1] - box[4][1])
cam:look_at(9192, 4096)
local moved = big:view_box(cam:view_quad(W, H))
test("the box moves with the camera", near(moved[1][1] - box[1][1], 1000 / 16384 * 176, 0.01) and near(moved[1][2], box[1][2]))
cam.c.distance = 3000
local far = big:view_box(cam:view_quad(W, H))
test("and grows zoomed out", far[2][1] - far[1][1] > moved[2][1] - moved[1][1] and far[3][2] - far[1][2] > moved[3][2] - moved[1][2])
cam.c.distance, cam.c.rotation = 1650, 0
local turned = big:view_box(cam:view_quad(W, H))
test("and turns with it: looking east, the wide side is east", turned[1][1] > turned[4][1] and turned[2][1] > turned[3][1])
cam = lib.new(200, 3900, 0)
box = fitted:view_box(cam:view_quad(W, H))
test("at the map's corner the box is cut to the picture", #box >= 3 and inside_picture(box), #box)
test("and none of it is lost on the map", near(box[1][1], fitted.picture.x) or near(box[1][2], fitted.picture.y))
-- cut exactly: a diamond over the west edge, and one over the north edge
local sq = minimap.new({ x0 = 0, y0 = 0, x1 = 4096, y1 = 4096 }, RECT)
local function has(b, wx, wy)
    local hx, hy = sq:to_minimap(wx, wy)
    for _, v in ipairs(b) do if near(v[1], hx) and near(v[2], hy) then return true end end
    return false
end
box = sq:view_box({ 256, 3072, 1280, 2048, 256, 1024, -768, 2048 })
test("over the west edge it is cut where its sides cross it", #box == 5 and has(box, 0, 1280) and has(box, 0, 2816)
    and has(box, 256, 3072) and has(box, 1280, 2048) and has(box, 256, 1024), #box)
box = sq:view_box({ 3840, 1024, 2816, 2048, 3840, 3072, 4864, 2048 })
test("over the east edge too", #box == 5 and has(box, 4096, 2816) and has(box, 4096, 1280), #box)
box = sq:view_box({ 2048, 4864, 3072, 3840, 2048, 2816, 1024, 3840 })
test("over the north edge it is cut where its sides cross it", #box == 5 and has(box, 2816, 4096) and has(box, 1280, 4096), #box)
box = sq:view_box({ 2048, 1280, 3072, 256, 2048, -768, 1024, 256 })
test("over the south edge too", #box == 5 and has(box, 2816, 0) and has(box, 1280, 0), #box)
box = sq:view_box({ 0, 4096, 4096, 4096, 4096, 0, 0, 0 })
test("a box on the map's very edges keeps its four corners, no more", #box == 4 and has(box, 0, 4096) and has(box, 4096, 0), #box)
box = fitted:view_box({ -9000, -9000, -8000, -9000, -8000, -8000, -9000, -8000 })
test("a view off the map has no box", #box == 0)

-- the interface draws it, from the camera's quad when the screen sees no ground
g.to_ground = function() return nil end
cam = lib.new(4096, 2048, 0)
g.view_quad = function() return (cam:view_quad(W, H)) end
ui, calls = recorder()
hud:draw(ui)
local lines = {}
for _, c in ipairs(calls.line) do
    if c[5] == 1 and c[6] == 255 and c[7] == 255 and c[8] == 255 and on_minimap(c) then lines[#lines + 1] = c end
end
box = fitted:view_box(cam:view_quad(W, H))
test("the interface draws the box's four sides when the screen's corners see no ground",
    #lines == 4 and near(lines[1][1], box[1][1]) and near(lines[1][3], box[2][1]) and near(lines[4][3], box[1][1]), #lines)
-- the screen's corners on the ground come first, when they all see it
local seen = {}
for _, sp in ipairs({ { 0, hud.r.top.h }, { W, hud.r.top.h }, { W, hud.r.console.y }, { 0, hud.r.console.y } }) do
    seen[#seen + 1] = sp[1] * 10 + 1000; seen[#seen + 1] = 3000 - sp[2] * 2
end
g.to_ground = function(sx, sy) return sx * 10 + 1000, 3000 - sy * 2 end
ui, calls = recorder()
hud:draw(ui)
lines = {}
for _, c in ipairs(calls.line) do
    if c[5] == 1 and c[6] == 255 and c[7] == 255 and c[8] == 255 and on_minimap(c) then lines[#lines + 1] = c end
end
box = fitted:view_box(seen)
local follows = #lines == #box and #box >= 3
for i = 1, #lines do
    local b2 = box[i % #box + 1]
    follows = follows and near(lines[i][1], box[i][1]) and near(lines[i][2], box[i][2]) and near(lines[i][3], b2[1]) and near(lines[i][4], b2[2])
        and lines[i][9] == 255
end
test("when the screen's corners all see ground, the box is theirs, not the camera's", follows, #lines .. " vs " .. #box)
g.to_ground = function() return nil end
g.view_quad = nil
ui, calls = recorder()
hud:draw(ui)
lines = 0
for _, c in ipairs(calls.line) do
    if c[5] == 1 and c[6] == 255 and c[7] == 255 and on_minimap(c) then lines = lines + 1 end
end
test("and none with no ground and no camera quad", lines == 0, lines)
g.to_ground = function(sx, sy) return sx * 10, -sy * 10 end
-- }}}

-- {{{ 507e: clicking on the minimap
print("clicking on the minimap")
local function frame(input) input.keys = input.keys or {}; hud:update(input, 0.02) end
px, py = fitted:to_minimap(6000, 1000)
frame({ mx = px, my = py, lp = true, ld = true, lr = true })
test("a click moves the camera to that point of the map", near(g.camera_at[1], 6000, 1) and near(g.camera_at[2], 1000, 1), pt(g.camera_at[1], g.camera_at[2]))
px, py = fitted:to_minimap(1500, 3500)
frame({ mx = px, my = py, ld = true })
test("dragging moves it along", near(g.camera_at[1], 1500, 1) and near(g.camera_at[2], 3500, 1))
frame({ mx = r.x + 50, my = r.y + 2, ld = true })
test("dragging into the dark margin holds it to the map's edge", near(g.camera_at[2], 4096, 0.01))
hud:select({ g.units[1] })
px, py = fitted:to_minimap(5000, 2500)
frame({ mx = px, my = py, rp = true })
local o = g.orders[#g.orders]
test("a right-click orders the selection there", o and o.kind == "move" and near(o.x, 5000, 1) and near(o.y, 2500, 1)
    and o.list[1] == g.units[1], o and pt(o.x, o.y))
local before = #g.orders
hud:select({ g.units[3] })
frame({ mx = px, my = py, rp = true })
test("another player's units are not ordered", #g.orders == before)
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("minimap: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
