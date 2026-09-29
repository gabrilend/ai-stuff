--[[
Fort Demo Harness (Issue 516e)

Run by src/render/scene_viewer.c (its default scene) after it has
registered the "render" module. Lays the ground (a real map's terrain when
it loads, else plain grass), paints the fort once, and gives the viewer
four functions:

    scene_tick(dt)     one simulation tick (the viewer calls it at 50 Hz)
    scene_paint()      paint this frame's units and arrows
    scene_status()     a line for the HUD
    scene_key(name)    "rings": cycle range rings

Environment:
    FORT_MAP   path of a .w3x/.w3m for the ground ("none": plain grass;
               default: assets/DAoW-5.4b-PUBLIC-TEST.w3x)
]]

local render = require("render")
local fort = require("demo.fort.scene")

local ROOT = SCENE_ROOT or "."
local GROUND = 0.05   -- render height of the terrain's top

-- {{{ lay_ground
-- The map's terrain, north up, centred on the fort; plain grass if the map
-- can't be read.
local function lay_ground()
    local path = os.getenv("FORT_MAP") or (ROOT .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")
    if path ~= "none" then
        local ok, result = pcall(function()
            local Map = require("data")
            local map_renderer = require("demo.map_renderer")
            local map = Map.load(path)
            return map_renderer.load_terrain(map, true) and map.name
        end)
        if ok and result then
            print("[fort] ground from " .. path)
            return
        end
        print("[fort] no map ground (" .. tostring(result) .. "); plain grass")
    end
    local size = 64
    render.terrain_create(size, size, 1.0)
    render.terrain_set_offset(-size / 2, -size / 2)
    local tiles = {}
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local shade = ((x + y) % 2 == 0) and 0 or 8
            tiles[#tiles + 1] = { x, y, 70 + shade, 128 + shade, 60 }
        end
    end
    render.terrain_set_tiles(tiles)
end
-- }}}

lay_ground()
local scene = fort.build()
local painted = scene.world:emit(render, GROUND)
print(string.format("[fort] %d stones painted, %d posts", painted, #scene.posts))

-- {{{ C entry points
function scene_tick(dt)
    fort.update(scene, dt)
end

function scene_paint()
    fort.paint(scene, render, GROUND)
end

function scene_status()
    return fort.status(scene)
end

function scene_key(name)
    if name == "rings" then fort.cycle_rings(scene) end
end
-- }}}
