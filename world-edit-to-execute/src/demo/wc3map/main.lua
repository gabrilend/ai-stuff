--[[
WC3 Map Scene Script (Issue 517e)

Run by src/render/scene_viewer.c (see src/render/run-map). Loads a map
(SCENE_ARG, else WC3_MAP, else the project's DAoW 5.4b), builds its
landscape, paints every doodad and script-placed unit with the geometry
designs once, and bakes them into chunk meshes. The camera starts over
player 1's start location.
]]

local render = require("render")
local kit = require("geometry.kit")
local map_scene = require("demo.wc3map.scene")

local ROOT = SCENE_ROOT or "."
local path = SCENE_ARG or os.getenv("WC3_MAP") or (ROOT .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")

local clock = os.clock()
local s = map_scene.load(path)
print("[map] " .. map_scene.summary(s))

local t = s.terrain
local heights, colors, water = map_scene.terrain_arrays(s)
local chunks = render.land_build(t.width, t.height, t.offset_x, t.offset_y, 128,
                                 kit.RENDER_SCALE, heights, colors, water)

local prims = map_scene.prims(s)
local painted = kit.emit_prims(prims, render, false, 0)
local baked = render.geo_bake(16)   -- 16 tiles (2048 WC3 units) a chunk
print(string.format("[map] %d land chunks, %d primitives in %d chunks, %.1fs",
    chunks, painted, baked, os.clock() - clock))

-- {{{ start: player 1's start location, else the middle of the map
local start = s.map.players and s.map.players[1]
if start and start.start_x then
    CAMERA_START = { start.start_x, start.start_y, 2200 }
else
    CAMERA_START = { t.offset_x + t.width * 64, t.offset_y + t.height * 64, 2200 }
end
-- }}}

local status = string.format("%s  |  %d doodads, %d units  |  guessed: %d",
    s.name or "map", s.counts.doodads, s.counts.units, s.counts.by.guess or 0)

-- {{{ Viewer entry points
function scene_tick(_) end
function scene_paint() end
function scene_status() return status end
function scene_key(_) end
function scene_ground(x, y)
    return math.max(s.sample.ground_at(x, y), s.sample.water_at(x, y))
end
-- }}}
