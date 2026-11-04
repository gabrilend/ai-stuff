--[[
Fallback Demo (Issue 602)

Every wire-frame fallback shape on a blank map, for the scene viewer:

    scene_viewer PROJECT_ROOT src/demo/fallback/main.lua
    (scene_viewer built as src/render/run-fort builds it)

A grid of a blank 32 by 32 map (a hill in one corner), one of each kind
of object, a selected unit, a flyer, a region, a camera and a waypoint,
with their letters and names over them. Keys: O the debug overlay (ids
and coordinates), Esc quit.

Not yet seen on a screen: the test (src/tests/test_fallback.lua) checks
the shapes and calls, not how they look.
]]

local render = require("render")
local fallback = require("assets.fallback")

local GROUND = 0.0

-- {{{ the scene
local terrain = fallback.blank(32, 32)
terrain.height_at = function(ix, iy)
    local dx, dy = ix - 26, iy - 26
    return math.max(0, 384 - (dx * dx + dy * dy) * 24)
end

local scene = {
    terrain = terrain,
    objects = {
        { x = -768, y = 512, type_id = "hfoo", id = 1 },
        { x = -512, y = 512, type_id = "hkni", id = 2, selected = true },
        { x = -256, y = 512, type_id = "Hpal", id = 3 },
        { x = 0, y = 512, type_id = "hgry", id = 4, flying = true },
        { x = 384, y = 512, type_id = "htow", id = 5, building = true },
        { x = -768, y = 0, doodad = true, tree = true, type_id = "LTlt", id = 6 },
        { x = -512, y = 0, doodad = true, tree = true, type_id = "LTlt", id = 7 },
        { x = -256, y = 0, doodad = true, type_id = "LOrb", id = 8 },
        { x = 0, y = 0, kind = "item", type_id = "ckng", id = 9 },
        { x = 1600, y = 1600, type_id = "hfoo", id = 10 },   -- on the hill
    },
    regions = { { name = "Spawn", x1 = -1024, y1 = -1024, x2 = -256, y2 = -512 } },
    cameras = { { name = "Intro", x = 512, y = -1200, z = 500, target_x = 0, target_y = 0 } },
    waypoints = { { x = 256, y = -256, name = "rally" } },
}
-- }}}

local F = fallback.new()
local out

local function rebuild()
    render.geo_clear(false)
    out = F:build(scene)
    fallback.emit(out, render, false, GROUND)
end
rebuild()
print(string.format("[fallback] %d lines, %d labels", out.lines, #out.labels))

CAMERA_START = { 0, 0, 2600 }

-- {{{ entry points
function scene_ground(x, y)
    return 0
end

function scene_tick(dt) end

function scene_paint() end

function scene_status()
    return string.format("fallback demo: %d lines, overlay %s", out.lines, F.overlay and "on" or "off")
end

function scene_key(name) end

function scene_ui()
    for _, key in ipairs(viewer.keys()) do
        if key == "O" then
            F:set_debug_overlay(not F.overlay)
            rebuild()
        elseif key == "ESCAPE" then
            viewer.quit()
        end
    end
    fallback.draw_labels(out.labels, render, viewer.to_screen)
    render.ui_text(scene_status() .. "  |  O overlay  Esc quit", 12, 8, 18, 250, 190, 110, 255)
end
-- }}}
