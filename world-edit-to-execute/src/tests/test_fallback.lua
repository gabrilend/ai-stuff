#!/usr/bin/env luajit
-- test_fallback.lua - wire-frame shapes when an asset is missing (issue 602)
--
-- In plain terms: each kind of object is drawn as its shape (a box, a
-- tree, an asterisk, a diamond) in its own colour, with its letter over it;
-- a flyer shows a line down to the ground; terrain is a grid of lines that
-- grow wider where the ground is higher; a region is a dashed outline with
-- its name; a selected object gets a thicker green outline; the debug
-- overlay adds ids and coordinates; objects whose model will be drawn are
-- left out unless wire-frame mode is forced; a missing texture becomes a
-- checkerboard and is reported as using the fallback; and the shapes and
-- labels go to the renderer's own calls. No window: the renderer is a
-- recorder.
--
-- Run: luajit src/tests/test_fallback.lua [DIR]
-- Issue: issues/completed/602-wireframe-fallback-renderer.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local fallback = require("assets.fallback")
local loader = require("assets.loader")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function sh(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function same(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function count_color(out, color)
    local n = 0
    for _, p in ipairs(out.prims) do if same(p.color, color) then n = n + 1 end end
    return n
end
local function labels(out)
    local t = {}
    for _, l in ipairs(out.labels) do t[#t + 1] = l.text end
    return table.concat(t, ",")
end

-- {{{ Kinds and colours
print("\n=== Kinds and colours ===")
test("a type id with a capital is a hero", fallback.kind_of({ type_id = "Hpal" }) == "hero")
test("lower case is a unit", fallback.kind_of({ type_id = "hfoo" }) == "unit")
test("flags make a building, a flyer, a tree, a doodad",
    fallback.kind_of({ type_id = "htow", building = true }) == "building"
    and fallback.kind_of({ type_id = "hgry", flying = true }) == "flyer"
    and fallback.kind_of({ doodad = true, tree = true }) == "tree"
    and fallback.kind_of({ doodad = true }) == "doodad")
test("a kind given wins", fallback.kind_of({ kind = "item", type_id = "Hpal" }) == "item")
local seen, distinct = {}, true
for kind, c in pairs(fallback.COLORS) do
    local k = c[1] .. "," .. c[2] .. "," .. c[3]
    if seen[k] then distinct = false end
    seen[k] = kind
end
test("every kind has its own colour", distinct)
test("an unknown kind is magenta", same(fallback.color_for("nonsense"), fallback.COLORS.unknown))
-- }}}

-- {{{ Shapes
print("\n=== Shapes ===")
local F = fallback.new()
local function one(obj) return F:build({ objects = { obj } }) end
local u = one({ x = 0, y = 0, type_id = "hfoo" })
test("a unit: a box of 12 lines in blue, U over it", u.lines == 12 and count_color(u, fallback.COLORS.unit) == 12
    and labels(u) == "U", u.lines .. " " .. labels(u))
local b = one({ x = 0, y = 0, type_id = "htow", building = true })
test("a building: 12 brown lines, B", b.lines == 12 and count_color(b, fallback.COLORS.building) == 12 and labels(b) == "B")
local h = one({ x = 0, y = 0, type_id = "Hpal" })
test("a hero: gold, H", count_color(h, fallback.COLORS.hero) == 12 and labels(h) == "H")
local fl = one({ x = 100, y = 0, type_id = "hgry", flying = true })
local top = -math.huge
for _, p in ipairs(fl.prims) do for _, pt in ipairs(p.pts) do top = math.max(top, pt[3]) end end
test("a flyer: cyan, drawn at fly height, a line to the ground and a cross there",
    fl.lines == 15 and count_color(fl, fallback.COLORS.flyer) == 15
    and near(top, fallback.FLY_HEIGHT + fallback.SIZES.flyer[3]), fl.lines .. " " .. top)
local tr = one({ x = 0, y = 0, doodad = true, tree = true })
test("a tree: four green lines (/|\\)", tr.lines == 4 and count_color(tr, fallback.COLORS.tree) == 4 and #tr.labels == 0)
local dd = one({ x = 0, y = 0, doodad = true })
test("a doodad: a grey asterisk of four lines", dd.lines == 4 and count_color(dd, fallback.COLORS.doodad) == 4)
local it = one({ kind = "item", x = 0, y = 0 })
test("an item: a small purple box, I", it.lines == 12 and count_color(it, fallback.COLORS.item) == 12 and labels(it) == "I")
local wp = F:build({ waypoints = { { x = 0, y = 0, name = "rally" } } })
test("a waypoint: a yellow diamond and its name", wp.lines == 4 and count_color(wp, fallback.COLORS.waypoint) == 4
    and labels(wp) == "rally")
local cam = F:build({ cameras = { { name = "Intro", x = 0, y = -900, z = 600, target_x = 0, target_y = 0 } } })
test("a camera: red box, a line down, a line to what it looks at, C and its name",
    cam.lines == 16 and count_color(cam, fallback.COLORS.camera) == 16 and labels(cam) == "C,Intro", cam.lines .. " " .. labels(cam))
local reg = F:build({ regions = { { name = "Spawn", x1 = 0, y1 = 0, x2 = 512, y2 = 256 } } })
local per = function(len) return math.ceil(len / (fallback.DASH + fallback.GAP)) end
test("a region: a dashed orange outline and its name", reg.lines == 2 * per(512) + 2 * per(256)
    and count_color(reg, fallback.COLORS.region) == reg.lines and labels(reg) == "Spawn", tostring(reg.lines))
test("drawn counts each kind", F:build({ objects = { { x = 0, y = 0 }, { x = 1, y = 1 }, { doodad = true, x = 0, y = 0 } } })
    .drawn.unit == 2)
-- }}}

-- {{{ Lines
print("\n=== Lines ===")
local L1 = fallback.new():build({ waypoints = {} })
local ctx_out = fallback.new():build({ objects = { { x = 0, y = 0 } } })
local flat, upright = nil, nil
for _, p in ipairs(ctx_out.prims) do
    local z1, z2, z3, z4 = p.pts[1][3], p.pts[2][3], p.pts[3][3], p.pts[4][3]
    if z1 == z2 and z2 == z3 and z3 == z4 then flat = flat or p else upright = upright or p end
end
local function dist(a, b) return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2) end
test("a line along the ground lies flat, LINE wide", flat and near(dist(flat.pts[1], flat.pts[2]), fallback.LINE))
test("a vertical edge stands up, LINE wide", upright and near(dist(upright.pts[1], upright.pts[2]), fallback.LINE)
    and upright.pts[1][2] == upright.pts[2][2])
test("an empty scene draws nothing", #L1.prims == 0 and #L1.labels == 0)
-- }}}

-- {{{ Terrain
print("\n=== Terrain ===")
local g = F:build({ terrain = fallback.blank(4, 4) })
local dots = 0
for _, p in ipairs(g.prims) do if p.kind == "box" then dots = dots + 1 end end
test("a blank 4 by 4 map: 40 grey lines and 25 vertex dots", g.lines == 40 and dots == 25
    and count_color(g, fallback.COLORS.grid) == 40, g.lines .. " " .. dots)
local hills = { width = 2, height = 1, x0 = 0, y0 = 0, tile = 128,
                height_at = function(ix) return ix == 2 and 512 or 0 end }
local hg = F:build({ terrain = hills })
local widths = {}
for _, p in ipairs(hg.prims) do
    if p.kind == "quad" then widths[#widths + 1] = dist(p.pts[1], p.pts[2]) end
end
table.sort(widths)
test("the grid follows the ground's height, and is wider where it is higher",
    near(widths[1], fallback.LINE) and widths[#widths] > fallback.LINE * 1.4, widths[1] .. ".." .. widths[#widths])
local up = F:build({ terrain = hills, objects = { { x = 256, y = 0 } } })
local lowest = math.huge
for _, p in ipairs(up.prims) do
    if same(p.color, fallback.COLORS.unit) then for _, pt in ipairs(p.pts) do lowest = math.min(lowest, pt[3]) end end
end
test("a unit stands on the ground's height", lowest == 512, tostring(lowest))
local big = F:build({ terrain = fallback.blank(128, 128) })
test("a 128 by 128 map: lines for every tile edge, no dots (too many)", big.lines == 2 * 129 * 128
    and #big.prims == big.lines)
local coarse = F:build({ terrain = (function() local t = fallback.blank(128, 128); t.every = 4; return t end)() })
test("every = 4 draws a quarter of the lines each way", coarse.lines == 2 * 33 * 32, tostring(coarse.lines))
-- }}}

-- {{{ Selection, overlay, models, painters
print("\n=== Selection, overlay, models, painters ===")
local sel = one({ x = 0, y = 0, selected = true })
local thick = 0
for _, p in ipairs(sel.prims) do
    if same(p.color, fallback.COLORS.selected) and p.pts[1][3] == p.pts[2][3]
        and near(dist(p.pts[1], p.pts[2]), fallback.SELECTED_LINE) then thick = thick + 1 end
end
test("selected: a second, thicker green box around it", count_color(sel, fallback.COLORS.selected) == 12 and thick >= 8)
F:set_debug_overlay(true)
local ov = one({ x = 100.4, y = -50, type_id = "hfoo", id = 7 })
test("the debug overlay adds the type, id and position", labels(ov) == "U,hfoo #7 (100, -50)", labels(ov))
F:set_debug_overlay(false)
local M = fallback.new({ has_model = function(obj) return obj.type_id == "hfoo" end })
local mixed = M:build({ objects = { { x = 0, y = 0, type_id = "hfoo" }, { x = 0, y = 0, type_id = "hkni" } } })
test("an object with its model is left to the renderer", mixed.skipped == 1 and mixed.drawn.unit == 1)
M:force_wireframe(true)
local forced = M:build({ objects = { { x = 0, y = 0, type_id = "hfoo" }, { x = 0, y = 0, type_id = "hkni" } } })
test("forced wire-frame draws it anyway", forced.skipped == 0 and forced.drawn.unit == 2)
local custom = fallback.new()
custom:register("unit", function(obj, ctx) ctx:label(obj.x, obj.y, 0, "mine"); return 0, 1, 1, 1 end)
test("a registered painter draws its kind", labels(custom:build({ objects = { { x = 0, y = 0 } } })) == "mine")
custom:register("unit", nil)
test("registering nil puts the built-in back", custom:build({ objects = { { x = 0, y = 0 } } }).lines == 12)
test("register wants a function", not pcall(custom.register, custom, "unit", "draw it please"))
-- }}}

-- {{{ Textures and models through the loader
print("\n=== Missing textures and models ===")
local ph = fallback.texture("hero")
test("a placeholder texture: 8 by 8, RGBA, a checker of the kind's colour", ph.width == 8 and ph.height == 8
    and #ph.rgba == 256 and ph.rgba:sub(1, 3) == string.char(235, 190, 40) and ph.rgba:sub(9, 11) == string.char(20, 20, 24)
    and ph.placeholder)
local SCR = os.tmpname()
os.remove(SCR)
local PACK = SCR .. "/asset-packs/mine"
os.execute("mkdir -p " .. sh(PACK .. "/textures"))
local fh = assert(io.open(PACK .. "/textures/real.tga", "wb"))
fh:write(string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 32, 0x28) .. string.char(10, 20, 30, 255))
fh:close()
local LL = loader.new({ packs = { "mine" }, data = SCR, root = DIR })
local FL = fallback.new({ loader = LL })
local real, from = FL:texture("Textures\\Real.tga")
test("a texture that is there: the loader's", from == "pack:mine" and real.width == 1 and not real.placeholder
    and not FL:is_active("textures/real.tga"))
local miss, mfrom = FL:texture("Textures\\Gone.blp", "tree")
test("a missing one: a placeholder, and the fallback is active for it", mfrom == "fallback" and miss.placeholder
    and FL:is_active("Textures\\Gone.blp") and FL:is_active("textures/gone.blp"))
local nothing = FL:model("units/nobody.mdx")
test("a missing model: nil, and the fallback is active", nothing == nil and FL:is_active("Units\\Nobody.mdx"))
test("the loader's own misses count too", (function() LL:get("other/missing.blp"); return FL:is_active("other/missing.blp") end)())
FL:force_wireframe(true)
local forced_tex, ffrom = FL:texture("Textures\\Real.tga")
test("forced: a placeholder even for a texture that is there", ffrom == "fallback" and forced_tex.placeholder
    and FL:is_active("textures/real.tga"))
LL:close()
os.execute("rm -rf " .. sh(SCR))
-- }}}

-- {{{ To the renderer
print("\n=== To the renderer ===")
local calls = { quad = 0, box = 0, text = {} }
local render = {
    geo_quad = function(...) calls.quad = calls.quad + 1; calls.last_quad = { ... }; return calls.quad end,
    geo_box = function(...) calls.box = calls.box + 1; return calls.box end,
    geo_wedge = function() error("no wedges here") end,
    ui_text = function(text, x, y, size, r, g, bb) calls.text[#calls.text + 1] = { text, x, y } end,
    ui_text_width = function(text, size) return #text * 8 end,
}
local scene = F:build({ terrain = fallback.blank(2, 2), objects = { { x = 0, y = 0 } } })
local painted = fallback.emit(scene, render, true, 0.05)
test("every primitive is painted through geo_quad and geo_box", painted == #scene.prims
    and calls.quad == scene.lines and calls.box == 9)
test("painted in the per-frame layer when asked", calls.last_quad[#calls.last_quad] == true)
local function to_screen(x, y, z) if y < -1000 then return 0, 0, false end return x + 400, 300 - z, true end
local drawn = fallback.draw_labels({ { x = 0, y = 0, z = 100, text = "U", color = { 1, 2, 3 } },
                                     { x = 0, y = -5000, z = 0, text = "behind", color = { 1, 2, 3 } } }, render, to_screen)
test("labels are centred on their screen point; those behind the camera are skipped", drawn == 1
    and calls.text[1][1] == "U" and calls.text[1][2] == 400 - 4 and calls.text[1][3] == 200 - 7)
-- }}}

-- {{{ The demo scene, run without a window
print("\n=== The demo scene loads and draws its labels ===")
local painted_n, texts = 0, {}
package.loaded.render = {
    geo_clear = function() end,
    geo_quad = function() painted_n = painted_n + 1; return painted_n end,
    geo_box = function() painted_n = painted_n + 1; return painted_n end,
    geo_wedge = function() painted_n = painted_n + 1; return painted_n end,
    ui_text = function(t) texts[#texts + 1] = t end,
    ui_text_width = function(t) return #t * 8 end,
}
local pressed = { "O" }
viewer = {
    keys = function() local k = pressed; pressed = {}; return k end,
    to_screen = function(x, y, z) return x / 4 + 640, 360 - y / 4, true end,
    quit = function() end,
}
local _print = print
print = function() end
local ok_demo, err_demo = pcall(dofile, DIR .. "/src/demo/fallback/main.lua")
print = _print
test("the demo builds and paints its scene", ok_demo and painted_n > 1000, tostring(err_demo))
if ok_demo then
    scene_ui()
    local joined = table.concat(texts, "|")
    test("its interface draws the letters, names and the overlay's ids (O pressed)", joined:find("Spawn", 1, true)
        and joined:find("Intro", 1, true) and joined:find("hfoo #1", 1, true) and joined:find("overlay on", 1, true), joined:sub(1, 200))
end
viewer = nil
package.loaded.render = nil
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
