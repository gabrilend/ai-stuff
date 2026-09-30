--[[
WC3 Map Scene Script (Issues 517e, 518c, 520)

Run by src/render/scene_viewer.c (see src/render/run-map). Loads a map
(SCENE_ARG, else WC3_MAP, else the project's DAoW 5.4b), builds its
landscape, bakes its doodads and buildings, and plays it through WC3's
interface (ui/wc3/hud.lua) as the local player (WC3_PLAYER, default 0):
select with clicks and drags, order with the command card, hotkeys and
right clicks; the units walk by WC3's movement rules.

Unattended runs (screenshots, tests) can script input with SCENE_ACTIONS:
"time:action;..." where action is one of
    select:hero | select:worker | select:building | select:army
    order:attack_nearest   the selection attack-moves on the nearest enemy
    key:NAME           a key press (hotkeys, F9-F12, ESCAPE, TAB, ...)
    click:x,y  rclick:x,y  drag:x0,y0,x1,y1  hover:x,y   (screen pixels)
    ground:ACTION:x,y  the same at the screen point over WC3 point x, y
    camera:x,y[,d]
    chat:TEXT          the local player says TEXT (to the map's script)
    dialog:N           press button N of the dialog showing
    wait:              (nothing; a marker)

WC3_SCRIPT=0 reads the units from the script's text instead of running it
(issue 520); WC3_SCRIPT_VERBOSE=1 prints the script's errors as they come.
Computer players (issue 521): WC3_AI=auto (default) gives every computer
player the map leaves idle an AI, from ai-profiles/<map>/ when a file is
there, else derived from its faction; WC3_AI=script only runs AI the map
starts itself (as WC3 does); WC3_AI=none, none at all.
]]

local render = require("render")
local kit = require("geometry.kit")
local designs = require("geometry.designs")
local figures = require("geometry.figures")
local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local hud_mod = require("ui.wc3.hud")
local combat = require("demo.wc3map.combat")

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
-- the map's own script runs (jass/vm.lua) and makes its units, unless
-- WC3_SCRIPT=0 (then the units are read from the script's text)
local player = tonumber(os.getenv("WC3_PLAYER") or "0")
-- the art and the stock tables: the map's, then the owner's install
-- (issues 522, 525); WC3_MODELS=0 draws the geometry designs only
local assets_mod = require("assets")
local A = assets_mod.open(path, { root = ROOT })
local stock = require("gamedata.unit_stock").new(A.chain, s.map.object_data and s.map.object_data.units)
-- the ground's textures (issue 526): the install's tilesets, else
-- stand-ins drawn in their layout; WC3_TILES=0 for plain colours
if os.getenv("WC3_TILES") ~= "0" then
    local ground = require("assets.ground")
    local r = ground.apply(render, A, s, { standins = os.getenv("WC3_TILES") == "standin" })
    print(string.format("[ground] %d tilesets: %d from the install, %d stand-ins; %d cells textured, %d triangles",
        r.tilesets, r.real, r.standin, r.cells, r.triangles))
end
if os.getenv("WC3_MODELS") == "0" then A = nil end
-- fog of war (issue 524); WC3_FOG=0 for none
local FOG = os.getenv("WC3_FOG") ~= "0"
local game
if os.getenv("WC3_SCRIPT") ~= "0" then
    game = game_mod.new(s, { player = player, placed = false, vision = FOG, stock = stock })
    local V, err = game.run_script({
        verbose = os.getenv("WC3_SCRIPT_VERBOSE") == "1",
        ai = os.getenv("WC3_AI") or "auto",
        ai_dir = ROOT .. "/ai-profiles/" .. require("ai.faction").map_key(path),
    })
    if V then
        print(string.format("[script] running: %d units made, %d quests, load %.2fs, main %.2fs",
            #game.units, #V.quests, V.stats.load_seconds, V.stats.main_seconds))
        for _, r in ipairs(game.ai_manager and game.ai_manager:report() or {}) do
            print(string.format("[ai] player %d: %s (%s)", r.player, tostring(r.name), tostring(r.how)))
        end
    else
        print("[script] couldn't run the map's script (" .. tostring(err) .. "); units read from its text")
        game = nil
    end
end
game = game or game_mod.new(s, { player = player, vision = FOG, stock = stock })
do
    local r = game.stats_report()
    print(string.format("[stats] stock tables: %s; %d unit types: %d with stock values, %d with the map's, %d stand-ins only",
        stock.available and "read" or ("none (" .. tostring(stock.error or "no install") .. ")"),
        r.types, r.stock, r.map, r.neither))
end
local sw, sh = render.ui_screen()
game.minimap.image = render.ui_image_load(game.minimap.size, game.minimap.size, game.minimap.rgba)

-- {{{ fog of war onto the renderer and the minimap, after each update of
-- what the player sees
local FOG_MAP = 128
local fog_version
if game.vision then
    game.minimap.fog = render.ui_image_load(FOG_MAP, FOG_MAP, string.rep("\0", FOG_MAP * FOG_MAP * 4))
end
local function show_fog()
    local V = game.vision
    if not V or V.version == fog_version then return end
    fog_version = V.version
    if not V.fog then render.fog_off() return end
    local shades = V:mask(game.player)
    render.fog_set(V.w, V.h, V.x0, V.y0, 128, shades)
    local ffi = require("ffi")
    local buf = ffi.new("uint8_t[?]", FOG_MAP * FOG_MAP * 4)
    for py = 0, FOG_MAP - 1 do
        local j = math.floor((FOG_MAP - 1 - py) / FOG_MAP * V.h)
        for px = 0, FOG_MAP - 1 do
            local i = math.floor(px / FOG_MAP * V.w)
            local v = shades:byte(j * V.w + i + 1)
            buf[(py * FOG_MAP + px) * 4 + 3] = math.floor((255 - v) * 0.9)
        end
    end
    render.ui_image_update(game.minimap.fog, FOG_MAP, FOG_MAP, ffi.string(buf, FOG_MAP * FOG_MAP * 4))
end
-- }}}
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

-- {{{ models: the map's and the install's (issue 522); WC3_MODELS=0 for
-- the geometry designs only
local gpu = require("assets.gpu")
local model_cache = A and gpu.new(render, A)
local model_ids = {}
local object_data = s.map.object_data
local function model_of(kind, id, variation)
    if not A then return nil end
    local key = kind .. ":" .. id .. ":" .. tostring(variation or "")
    local v = model_ids[key]
    if v == nil then
        local m, mpath = A:model_for(kind, id, variation, object_data)
        v = m and model_cache:build(m, mpath) or false
        model_ids[key] = v
    end
    return v or nil
end
-- their own animations (issue 523); WC3_ANIMATE=0 for the rest pose
local animate = require("demo.wc3map.animate")
local ANIMATE = os.getenv("WC3_ANIMATE") ~= "0"
local last_paint = nil
local function team_rgb(player)
    local c = designs.TEAM[player] or designs.TEAM[15] or { 200, 200, 200 }
    return c[1], c[2], c[3]
end
-- placed doodads drawn as models, and those left to the designs
local doodad_models, designed_doodads = {}, {}
for _, d in ipairs(s.doodads) do
    local id = d.id and model_of("placed", d.id, d.variation)
    if id then
        doodad_models[#doodad_models + 1] = { id = id, d = d }
    else
        designed_doodads[#designed_doodads + 1] = d
    end
end
if A then
    local r = A:report()
    local typed, drawn = 0, 0
    for _, u in ipairs(game.units) do
        if model_of("unit", u.id) then drawn = drawn + 1 end
    end
    for _, v in pairs(model_ids) do if v then typed = typed + 1 end end
    print(string.format("[models] install: %s%s; %d model types; placed with models: %d of %d units, %d of %d doodads",
        r.install or "none (the map's own imports only)", r.chain_note and (" (" .. r.chain_note .. ")") or "",
        typed, drawn, #game.units, #doodad_models, #s.doodads))
end
-- }}}

-- {{{ bake doodads (group 0) and buildings (group 1: re-baked when one
-- falls); mobile units are drawn each frame
local DOODADS, BUILDINGS = 0, 1
local statics = {}
local function add(list) for _, p in ipairs(list) do statics[#statics + 1] = p end end
for _, d in ipairs(designed_doodads) do add(designs.build(d.spec, d.x, d.y, d.z, d.facing, d.scale)) end
local painted = kit.emit_prims(statics, render, false, 0)
local baked = render.geo_bake(16, DOODADS)

local function bake_buildings()
    render.geo_unbake(BUILDINGS)
    local list = {}
    for _, u in ipairs(game.units) do
        if u.spec.design == "building" and u.alive and not u.hidden and not model_of("unit", u.id) and game.shown(u) then
            for _, p in ipairs(designs.build(u.spec, u.x, u.y, u.z, u.facing, 1)) do list[#list + 1] = p end
        end
    end
    kit.emit_prims(list, render, false, 0)
    return render.geo_bake(16, BUILDINGS), #list
end
local building_chunks, building_prims = bake_buildings()
local last_rebake = 0
statics = nil
print(string.format("[map] %d land chunks, %d doodad primitives in %d chunks, %d building primitives in %d chunks, %.1fs",
    chunks, painted, baked, building_prims, building_chunks, os.clock() - clock))
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
    local said = what:match("^chat:(.*)$")
    if said then
        if game.script then
            hud:message(game.script:player(game.player).name .. ": " .. said)
            game.script:chat(game.player, said)
        end
        return
    end
    local pressed = what:match("^dialog:(%d+)$")
    if pressed then
        local d = game.script and game.script:shown_dialogs()[1]
        local b = d and d.buttons[tonumber(pressed)]
        if b then game.script:click(b, game.player) end
        return
    end
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
    elseif kind == "order" and rest == "attack_nearest" then
        local own = hud:own_selection()
        if own[1] then
            local foe, best
            for _, u in ipairs(game.units) do
                if u.alive and u.spec.design == "unit" and combat.hostile(game, own[1], u) then
                    local d = (u.x - own[1].x) ^ 2 + (u.y - own[1].y) ^ 2
                    if not best or d < best then foe, best = u, d end
                end
            end
            if foe then game.order(own, "attack", foe.x, foe.y) end
        end
    end
end
-- }}}

-- {{{ Viewer entry points
local last_hover = { 0, 0 }
function scene_tick(dt)
    game.tick(dt)
    show_fog()
    if game.buildings_changed and game.time - last_rebake > 1 then
        game.buildings_changed, last_rebake = false, game.time
        bake_buildings()
    end
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
                  chars = viewer.chars and viewer.chars() or "",
                  shift = viewer.key_down("SHIFT"), ctrl = viewer.key_down("CTRL"), alt = viewer.key_down("ALT") }
    end
    hud:update(input, 0)
    hud.time = game.time

    -- units near the camera, and rings under the selected ones
    local cx, cy, dist = viewer.camera()
    local reach = dist * 2.4
    local adt = last_paint and math.max(0, game.time - last_paint) or 0
    last_paint = game.time
    local prims = {}
    local function add_list(list) for _, p in ipairs(list) do prims[#prims + 1] = p end end
    for _, u in ipairs(game.units) do
        if not u.hidden and math.abs(u.x - cx) < reach and math.abs(u.y - cy) < reach and game.shown(u) then
            local mid = model_of("unit", u.id)
            if mid then
                local r, g, b = team_rgb(u.player)
                local rig = ANIMATE and model_cache:rig(mid)
                local pose = rig and animate.unit(rig, u, adt)
                -- posed, the fallen play their death; unposed, they fade
                render.model_draw(mid, u.x, u.y, u.z, u.facing or 0, u.model_scale or 1, r, g, b,
                    (u.alive or pose) and 1 or 0.45, pose)
            elseif u.spec.design ~= "building" then
                -- the fallen lie flat until they go
                add_list(designs.build(u.spec, u.x, u.y, u.z, u.facing, u.alive and 1 or { 1, 1, 0.2 }))
            end
        end
    end
    for _, dm in ipairs(doodad_models) do
        local d = dm.d
        if math.abs(d.x - cx) < reach and math.abs(d.y - cy) < reach then
            local rig = ANIMATE and model_cache:rig(dm.id)
            render.model_draw(dm.id, d.x, d.y, d.z, d.facing or 0, d.scale and d.scale[1] or 1, 255, 255, 255,
                1, rig and animate.still(rig, dm, adt))
        end
    end
    for _, a in ipairs(game.volley.arrows) do
        if math.abs(a.x - cx) < reach and math.abs(a.y - cy) < reach then
            add_list(figures.arrow(a.x, a.y, a.z, a.dx, a.dy, a.dz))
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
