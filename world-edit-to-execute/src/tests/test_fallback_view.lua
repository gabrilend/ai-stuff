#!/usr/bin/env luajit
-- test_fallback_view.lua - the wire-frame fallback in the viewer and the editor (issue 602a)
--
-- In plain terms: the map viewer's units and doodads and the editor's
-- objects, regions and cameras become the fallback's plain objects, each
-- the right kind; F6 and F7 turn wire-frame and the overlay on and off;
-- the overlay labels what is drawn for real; a new map with nothing
-- placed is blank, and its ground becomes the fallback's grid at the
-- ground's height, thinned on a large map; and the fallback builds all of
-- it without a window. Nothing here is drawn: what the viewer and the
-- editor paint is unseen.
--
-- Run: luajit src/tests/test_fallback_view.lua [DIR]
-- Issue: issues/602a-wireframe-fallback-in-the-viewer-and-editor.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local fallback = require("assets.fallback")
local fv = require("assets.fallback_view")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

-- {{{ Converters
print("\n=== The viewer's and the editor's records, as the fallback's ===")
local footman = { id = "hfoo", x = 100, y = 200, z = 5, facing = 1.5, spec = { design = "footman" } }
local barracks = { id = "hbar", x = 0, y = 0, z = 0, spec = { design = "building" } }
local gryphon = { id = "hgry", x = 0, y = 0, z = 300, spec = { flying = true } }
local paladin = { id = "Hpal", x = 0, y = 0, z = 0, spec = {} }
test("a footman is a unit, at its place", fallback.kind_of(fv.unit(footman)) == "unit" and fv.unit(footman).x == 100
    and fv.unit(footman).z == 5 and fv.unit(footman).type_id == "hfoo")
test("a barracks is a building", fallback.kind_of(fv.unit(barracks)) == "building")
test("a gryphon rider flies", fallback.kind_of(fv.unit(gryphon)) == "flyer")
test("a paladin is a hero (a capital id)", fallback.kind_of(fv.unit(paladin)) == "hero")
test("selected is kept", fv.unit(footman, true).selected == true and fv.unit(footman).selected == nil)
test("the copy doesn't share the unit's table", fv.unit(footman) ~= footman and fv.unit(footman).spec == nil)
test("a tree doodad is a tree", fallback.kind_of(fv.doodad({ id = "LTlt", x = 0, y = 0, z = 0 })) == "tree")
test("a rock doodad is a doodad", fallback.kind_of(fv.doodad({ id = "LOrk", x = 0, y = 0, z = 0 })) == "doodad")
test("a doodad whose spec says tree is a tree", fallback.kind_of(fv.doodad({ id = "x", x = 0, y = 0, spec = { tree = true } })) == "tree")
local eo = fv.editor_object({ kind = "doodad", id = "ATtr", x = 10, y = 20, facing = 0 }, 64)
test("an editor doodad: a tree, on the ground given", fallback.kind_of(eo) == "tree" and eo.z == 64)
test("an editor unit", fallback.kind_of(fv.editor_object({ kind = "unit", id = "ogru", x = 0, y = 0 }, 0)) == "unit")
test("an editor item", fallback.kind_of(fv.editor_object({ kind = "item", id = "ratc", x = 0, y = 0 }, 0)) == "item")
local r = fv.region({ name = "Spawn", left = -512, bottom = -256, right = 0, top = 128 })
test("a region's edges", r.name == "Spawn" and r.x1 == -512 and r.y1 == -256 and r.x2 == 0 and r.y2 == 128)
local c = fv.camera({ name = "Intro", x = 1000, y = 0, distance = 1000, rotation = 90, aoa = 315, zoffset = 50 },
                    function() return 20 end)
test("a camera looks at its target", c.target_x == 1000 and c.target_y == 0 and c.name == "Intro")
test("its eye is behind and above (rotation 90: south of it; 45 degrees down)",
    near(c.x, 1000) and near(c.y, -1000 * math.cos(math.rad(45))) and near(c.z, 70 + 1000 * math.sin(math.rad(45))),
    string.format("%.1f %.1f %.1f", c.x, c.y, c.z))
local cd = fv.camera({ x = 0, y = 0 })
test("a camera with no fields takes WC3's defaults", cd.z > 1000 and cd.y < 0)
-- }}}

-- {{{ Keys
print("\n=== F6 and F7 ===")
local V = fv.new()
test("both off at first", not V.F.force and not V.F.overlay and not V:active() and V:status() == nil)
test("other keys do nothing", V:key({ "O", "ESCAPE" }) == nil and not V:active())
test("F6: wire-frame on", V:key({ "F6" }) == "wire" and V.F.force and V:active())
test("F7: the overlay on", V:key({ "F7" }) == "overlay" and V.F.overlay)
test("the corner says what is on", V:status() == "fallback: wire-frame (F6), overlay (F7)")
V:key({ "F6" }); V:key({ "F7" })
test("pressed again: both off", not V.F.force and not V.F.overlay)
local V2 = fv.new({ keys = { wire = "W", overlay = "O" } })
test("other keys can be given", V2:key({ "W" }) == "wire" and V2.F.force)
-- }}}

-- {{{ Labels and building
print("\n=== What the viewer and the editor build each frame ===")
test("no overlay: no labels", #V:labels({ fv.unit(footman) }) == 0)
V:key({ "F7" })
local labels = V:labels({ fv.unit(footman), fv.doodad({ id = "LTlt", x = 7, y = 8, z = 0 }) })
test("the overlay labels what is drawn for real", #labels == 2 and labels[1].text == "hfoo (100, 200)"
    and labels[1].z == 145 and labels[2].text == "LTlt (7, 8)", labels[1] and labels[1].text)
V:key({ "F7" })
V:key({ "F6" })
local out = V:build({ objects = { fv.unit(footman), fv.unit(barracks), fv.unit(gryphon), fv.unit(paladin, true) },
                      regions = { r }, cameras = { c } })
test("forced: every object drawn, by kind", out.drawn.unit == 1 and out.drawn.building == 1 and out.drawn.flyer == 1
    and out.drawn.hero == 1 and out.drawn.region == 1 and out.drawn.camera == 1)
test("as lines the renderer paints (quads)", #out.prims > 0 and out.prims[1].kind == "quad")
test("the region and the camera are named", (function()
    local names = {}
    for _, l in ipairs(out.labels) do names[l.text] = true end
    return names.Spawn and names.Intro
end)())
-- }}}

-- {{{ The grid, and a blank map
print("\n=== A blank new map shows the grid ===")
local t = { width = 65, height = 65, offset_x = -4096, offset_y = -4096 }
local g = fv.terrain(t, function(i, j) return i == 3 and j == 4 and 128 or 0 end)
test("a 64 by 64 map: every line", g.every == 1 and g.width == 64 and g.height == 64 and g.x0 == -4096 and g.tile == 128)
local grid = fv.new():build({ terrain = g })
test("its grid has 2 x 64 x 65 lines", grid.lines == 2 * 64 * 65, tostring(grid.lines))
local high = false
for _, p in ipairs(grid.prims) do
    for _, pt in ipairs(p.pts or {}) do if pt[3] >= 128 then high = true end end
end
test("at the ground's height (a raised tile point lifts its lines)", high)
local big = fv.terrain({ width = 257, height = 257, offset_x = 0, offset_y = 0 }, function() return 0 end)
local big_out = fv.new():build({ terrain = big })
test("a 256 by 256 map: thinned to stay under the limit", big.every > 1 and big_out.lines <= fv.MAX_GRID_LINES,
    big.every .. " " .. big_out.lines)
test("no objects placed: blank", fv.is_blank({ objs = {} }) and fv.is_blank({}))
test("only deleted ones: blank", fv.is_blank({ objs = { { deleted = true } } }))
test("one placed: not blank", not fv.is_blank({ objs = { { x = 0, y = 0 } } }))
do
    local ok_nm, new_map = pcall(require, "editor.new_map")
    local P = os.tmpname() .. ".w3x"
    if ok_nm and new_map.create(P, { name = "Blank", melee = false, width = 32, height = 32, tileset = "L",
                                    players = { { race = "human" } } }) then
        local E = require("editor").open(P)
        test("a new custom map opens blank in the editor", E and fv.is_blank(E))
        local et = E.terrain
        local eg = fv.terrain(et, function(i, j) return require("parsers.w3e").ground_z(et.tilepoints[j][i]) end)
        local eo2 = fv.new():build({ terrain = eg })
        test("and its ground makes a grid", eo2.lines > 0 and eg.x0 == et.offset_x)
        E:place_unit("hfoo", 0, 0, 0, 0)
        test("a unit placed: no longer blank", not fv.is_blank(E))
        os.remove(P)
    else
        print("  (the new-map writer isn't here: skipped)")
    end
end
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
