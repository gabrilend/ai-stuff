--[[
WC3 Map Scene Script (Issues 517e, 518c)

Run by src/render/scene_viewer.c (see src/render/run-map). Loads a map
(SCENE_ARG, else WC3_MAP, else the project's DAoW 5.4b), builds its
landscape, bakes its doodads and buildings, and plays it through WC3's
interface (ui/wc3/hud.lua) as the local player (WC3_PLAYER, default 0):
select with clicks and drags, order with the command card, hotkeys and
right clicks; the units walk by WC3's movement rules.

Unattended runs (screenshots, tests) can script input with SCENE_ACTIONS:
"time:action;..." where action is one of
    select:hero | select:worker | select:building | select:army
    key:NAME           a key press (hotkeys, F9-F12, ESCAPE, TAB, ...)
    click:x,y  rclick:x,y  drag:x0,y0,x1,y1  hover:x,y   (screen pixels)
    ground:ACTION:x,y  the same at the screen point over WC3 point x, y
    camera:x,y[,d]
]]

local render = require("render")
local kit = require("geometry.kit")
local designs = require("geometry.designs")
local figures = require("geometry.figures")
local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local hud_mod = require("ui.wc3.hud")

local ROOT = SCENE_ROOT or "."
local path = SCENE_ARG or os.getenv("WC3_MAP") or (ROOT .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")

local clock = os.clock()
local s = map_scene.load(path)
print("[map] " .. map_scene.summary(s))

-- {{{ ground
local t = s.terrain
local heights, colors, water = map_scene.terrain_arrays(s)
local chunks = render.land_build(t.width, t.height, t.offset_x, t.offset_y, 128,
                                 kit.RENDER_SCALE, heights, colors, water)
-- }}}

-- {{{ the game and its interface
local game = game_mod.new(s, { player = tonumber(os.getenv("WC3_PLAYER") or "0") })
local sw, sh = render.ui_screen()
game.minimap.image = render.ui_image_load(game.minimap.size, game.minimap.size, game.minimap.rgba)
game.to_screen = viewer.to_screen
game.to_ground = viewer.to_ground
game.camera = viewer.camera
game.set_camera = viewer.set_camera
game.quit = viewer.quit

-- the portrait: the unit's design, turned to face the viewer and sized to
-- fill the frame
function game.portrait(u)
    local prims = designs.build(u.spec, 0, 0, 0, -math.pi / 2 + 0.5, 1)
    local top, reach = 1, 1
    for _, p in ipairs(prims) do
        if p.kind == "quad" then
            for _, q in ipairs(p.pts) do top = math.max(top, q[3]); reach = math.max(reach, math.abs(q[1]), math.abs(q[2])) end
        else
            top = math.max(top, p.z + p.hgt)
            reach = math.max(reach, math.abs(p.x) + p.len / 2, math.abs(p.y) + p.wid / 2)
        end
    end
    local k = math.min(118 / top, 70 / reach)
    designs.place(prims, 0, 0, 0, 0, k)
    render.geo_target("portrait")
    kit.emit_prims(prims, render, false, 0)
    render.geo_target("world")
end

local hud = hud_mod.new(game, sw, sh)
-- }}}

-- {{{ bake doodads and buildings; mobile units are drawn each frame
local statics = {}
local function add(list) for _, p in ipairs(list) do statics[#statics + 1] = p end end
for _, d in ipairs(s.doodads) do add(designs.build(d.spec, d.x, d.y, d.z, d.facing, d.scale)) end
local mobile = {}
for _, u in ipairs(game.units) do
    if u.spec.design == "building" then
        add(designs.build(u.spec, u.x, u.y, u.z, u.facing, 1))
    else
        mobile[#mobile + 1] = u
    end
end
local painted = kit.emit_prims(statics, render, false, 0)
local baked = render.geo_bake(16)
statics = nil
print(string.format("[map] %d land chunks, %d primitives baked in %d chunks, %d mobile units, %.1fs",
    chunks, painted, baked, #mobile, os.clock() - clock))
-- }}}

-- {{{ start: the local player's start location, else the middle of the map
local start
for _, p in ipairs(s.map.players or {}) do
    if p.number == game.player then start = p end
end
if start and start.start_x then
    CAMERA_START = { start.start_x, start.start_y, 2200 }
else
    CAMERA_START = { t.offset_x + t.width * 64, t.offset_y + t.height * 64, 2200 }
end
-- }}}

-- {{{ scripted input (SCENE_ACTIONS)
local actions = {}
for item in (os.getenv("SCENE_ACTIONS") or ""):gmatch("[^;]+") do
    local at, what = item:match("^%s*([%d%.]+)%s*:(.+)$")
    if at then actions[#actions + 1] = { at = tonumber(at), what = what } end
end
table.sort(actions, function(a, b) return a.at < b.at end)

local function pick_own(test)
    local list = {}
    for _, u in ipairs(game.units) do
        if u.player == game.player and test(u) then list[#list + 1] = u end
    end
    return list
end

local function nearest_to_camera(list)
    local cx, cy = viewer.camera()
    table.sort(list, function(a, b)
        return (a.x - cx) ^ 2 + (a.y - cy) ^ 2 < (b.x - cx) ^ 2 + (b.y - cy) ^ 2
    end)
    return list
end

-- turn one scripted action into this frame's input
local function scripted(what, input)
    local kind, rest = what:match("^(%a+):?(.*)$")
    if kind == "ground" then
        local inner, gx, gy = rest:match("^(%a+):([%-%d%.]+),([%-%d%.]+)$")
        local sx, sy = viewer.to_screen(tonumber(gx), tonumber(gy), s.sample.ground_at(tonumber(gx), tonumber(gy)))
        return scripted(inner .. ":" .. sx .. "," .. sy, input)
    end
    local n = {}
    for v in rest:gmatch("[%-%d%.]+") do n[#n + 1] = tonumber(v) end
    if kind == "select" then
        local list
        if rest == "hero" then list = pick_own(function(u) return u.spec.hero end)
        elseif rest == "worker" then list = pick_own(function(u) return u.spec.archetype == "worker" end)
        elseif rest == "building" then list = pick_own(function(u) return u.spec.design == "building" and #game.db.unit_list(u.id, "utra") > 0 end)
        else list = pick_own(function(u) return u.spec.design == "unit" and not u.spec.hero end) end
        list = nearest_to_camera(list)
        local take = rest == "army" and 12 or 1
        local chosen = {}
        for i = 1, math.min(take, #list) do chosen[i] = list[i] end
        hud:select(chosen)
        if chosen[1] then viewer.set_camera(chosen[1].x, chosen[1].y - 200) end
    elseif kind == "key" then
        input.keys[#input.keys + 1] = rest
    elseif kind == "click" then
        input.mx, input.my, input.lp, input.ld, input.lr = n[1], n[2], true, true, true
    elseif kind == "rclick" then
        input.mx, input.my, input.rp = n[1], n[2], true
    elseif kind == "hover" then
        input.mx, input.my = n[1], n[2]
    elseif kind == "drag" then
        hud.drag = { x0 = n[1], y0 = n[2], x1 = n[3], y1 = n[4] }
        input.mx, input.my, input.lr = n[3], n[4], true
    elseif kind == "camera" then
        viewer.set_camera(n[1], n[2], n[3])
    end
end
-- }}}

-- {{{ Viewer entry points
local last_hover = { 0, 0 }
function scene_tick(dt)
    game.tick(dt)
end

function scene_paint()
    -- input: real, or scripted when SCENE_ACTIONS is set
    local input = { keys = {} }
    if #actions > 0 or os.getenv("SCENE_ACTIONS") then
        input.mx, input.my = last_hover[1], last_hover[2]
        while actions[1] and actions[1].at <= game.time do
            scripted(table.remove(actions, 1).what, input)
        end
        last_hover = { input.mx, input.my }
    else
        local mx, my, lp, ld, lr, rp = viewer.mouse()
        input = { mx = mx, my = my, lp = lp, ld = ld, lr = lr, rp = rp, keys = viewer.keys(),
                  shift = viewer.key_down("SHIFT"), ctrl = viewer.key_down("CTRL"), alt = viewer.key_down("ALT") }
    end
    hud:update(input, 0)
    hud.time = game.time

    -- units near the camera, and rings under the selected ones
    local cx, cy, dist = viewer.camera()
    local reach = dist * 2.4
    local prims = {}
    local function add_list(list) for _, p in ipairs(list) do prims[#prims + 1] = p end end
    for _, u in ipairs(mobile) do
        if math.abs(u.x - cx) < reach and math.abs(u.y - cy) < reach then
            add_list(designs.build(u.spec, u.x, u.y, u.z, u.facing, 1))
        end
    end
    for _, u in ipairs(hud.selection) do
        local c = u.player == game.player and { 60, 230, 70 }
            or ((u.player == 12 or u.player == 15) and { 240, 220, 60 } or { 230, 60, 50 })
        add_list(figures.ring(u.x, u.y, u.z + 3, u.spec.design == "building" and 200 or 44, c, 24, 3))
        if u.order and u.order.x then
            add_list(figures.ring(u.order.x, u.order.y, s.sample.ground_at(u.order.x, u.order.y) + 3, 16, { 60, 230, 70 }, 8, 3))
        end
    end
    kit.emit_prims(prims, render, true, 0)
    hud:paint_portrait()
end

function scene_ui()
    hud:draw(render)
end

function scene_status() return s.name or "map" end
function scene_key(_) end
function scene_ground(x, y)
    return math.max(s.sample.ground_at(x, y), s.sample.water_at(x, y))
end
-- }}}
