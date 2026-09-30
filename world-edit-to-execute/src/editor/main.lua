--[[
The Map Editor's Window (Issue 901)

Run by src/render/scene_viewer.c (see src/render/run-editor): opens a map
(SCENE_ARG, else the project's Daow 4.4) for editing through the
editor's core (src/editor/init.lua) and interface (src/editor/ui.lua).
The ground is drawn from the terrain being edited and drawn again after
each change; doodads and units are drawn with the geometry designs,
baked in blocks of the map, and a block is baked again when an object in
it changes. The camera is the viewer's: arrows and the screen's edges
pan, the wheel zooms.

Saving writes EDITOR_OUT, else <map>-edited.w3x beside the map; testing
(F5) saves a copy and plays it in the game with the viewer named by
WC3_VIEWER (run-editor sets it).
]]

local render = require("render")
local kit = require("geometry.kit")
local designs = require("geometry.designs")
local figures = require("geometry.figures")
local map_scene = require("demo.wc3map.scene")
local editor = require("editor")
local editor_ui = require("editor.ui")

local ROOT = SCENE_ROOT or "."
local path = SCENE_ARG or os.getenv("WC3_MAP") or (ROOT .. "/assets/Daow4.4.w3x")
local clock = os.clock()
local E = assert(editor.open(path))
-- the map's object data, for the designs' types
local s0 = map_scene.load(path)
print(string.format("[editor] %s: %d objects, %d of them units the script places (%.1fs)",
    path, #E:objects(), #E.script_units, os.clock() - clock))

-- {{{ the ground
local view = { terrain = E.terrain, sample = map_scene.sampler(E.terrain) }
local function build_ground()
    local t = E.terrain
    local heights, colors, water = map_scene.terrain_arrays(view)
    render.land_build(t.width, t.height, t.offset_x, t.offset_y, 128, kit.RENDER_SCALE, heights, colors, water)
end
build_ground()
local ground_dirty, ground_at = false, 0
local w3e = require("parsers.w3e")
local function take_ground_changes()
    local t = E.terrain
    for _, k in ipairs(E:take_changed_tiles()) do
        local i, j = k % t.width, math.floor(k / t.width)
        local tp = t.tilepoints[j][i]
        view.sample.ground[k] = w3e.ground_z(tp)
        view.sample.water[k] = tp.has_water and w3e.water_z(tp) or -1e30
        ground_dirty = true
    end
end
-- }}}

-- {{{ objects, baked in blocks
local BLOCK = 2048
local specs = {}
local function spec_of(o)
    local key = o.kind .. ":" .. o.id .. ":" .. tostring(o.variation or 0)
    local sp = specs[key]
    if sp == nil then
        if o.kind == "doodad" then sp = map_scene.doodad_spec(s0.map, o.id, o.variation) or false
        else
            sp = map_scene.unit_spec(s0.map, o.id) or false
        end
        specs[key] = sp
    end
    return sp or nil
end
local function block_of(x, y)
    local t = E.terrain
    return math.floor((x - t.offset_x) / BLOCK) + 1000 * math.floor((y - t.offset_y) / BLOCK)
end
local function bake_block(b)
    render.geo_unbake(100 + b)
    local list = {}
    for _, o in ipairs(E.objs) do
        if not o.deleted and block_of(o.x, o.y) == b then
            local sp = spec_of(o)
            if sp then
                local spec = sp
                if o.player and sp.team ~= o.player then
                    spec = {}
                    for k, v in pairs(sp) do spec[k] = v end
                    spec.team = o.player
                end
                local sc = o.scale or 1
                for _, p in ipairs(designs.build(spec, o.x, o.y, E:ground_z(o.x, o.y), o.facing,
                                                  o.kind == "doodad" and { sc, sc, sc } or 1)) do
                    list[#list + 1] = p
                end
            end
        end
    end
    kit.emit_prims(list, render, false, 0)
    render.geo_bake(16, 100 + b)
end
local function bake_all()
    local blocks = {}
    for _, o in ipairs(E.objs) do blocks[block_of(o.x, o.y)] = true end
    for b in pairs(blocks) do bake_block(b) end
end
bake_all()
-- where each object was last baked, to know which blocks to bake again
local baked_at = {}
local function note_places() for _, o in ipairs(E.objs) do baked_at[o] = block_of(o.x, o.y) end end
note_places()
local function rebake_changed()
    local blocks = {}
    for _, o in ipairs(E.objs) do
        local b = block_of(o.x, o.y)
        if baked_at[o] ~= b or o.deleted ~= (baked_at[o] == false) then
            blocks[b] = true
            if baked_at[o] then blocks[baked_at[o]] = true end
        end
        baked_at[o] = o.deleted and false or b
    end
    -- selected ones may have turned or scaled in place
    for _, o in ipairs(E.selection) do blocks[block_of(o.x, o.y)] = true end
    for b in pairs(blocks) do bake_block(b) end
end
print(string.format("[editor] ready in %.1fs", os.clock() - clock))
-- }}}

-- {{{ the interface
local sw, sh = render.ui_screen()
local out = os.getenv("EDITOR_OUT")
local ui = editor_ui.new(E, sw, sh, {
    to_ground = function(mx, my) return viewer.to_ground(mx, my) end,
    save_path = out, root = ROOT, viewer = os.getenv("WC3_VIEWER"),
})
local t = E.terrain
CAMERA_START = { t.offset_x + t.width * 64, t.offset_y + t.height * 64, 2400 }
for _, p in ipairs(s0.map.players or {}) do
    if p.number == 0 and p.start_x then CAMERA_START = { p.start_x, p.start_y, 2400 } end
end
-- }}}

-- {{{ scripted input for unattended runs (SCENE_ACTIONS="t:what;...")
--   tool:NAME  stroke:x,y (a whole stroke there)  place_doodad:x,y
--   place_unit:x,y  select:x,y  move:dx,dy  camera:x,y[,d]  save:  undo:
local actions = {}
for item in (os.getenv("SCENE_ACTIONS") or ""):gmatch("[^;]+") do
    local at, what = item:match("^%s*([%d%.]+)%s*:(.+)$")
    if at then actions[#actions + 1] = { at = tonumber(at), what = what } end
end
table.sort(actions, function(a, b) return a.at < b.at end)
local function scripted(what)
    local kind, rest = what:match("^([%w_]+):?(.*)$")
    local n = {}
    for v in rest:gmatch("[%-%d%.]+") do n[#n + 1] = tonumber(v) end
    if kind == "tool" then E:set_tool(rest)
    elseif kind == "stroke" then E:stroke_begin(nil, n[1], n[2]); E:stroke(n[1], n[2]); E:stroke_end()
    elseif kind == "place_doodad" then E:place_doodad(ui.doodad, n[1], n[2])
    elseif kind == "place_unit" then E:place_unit(ui.unit, 0, n[1], n[2], math.rad(270))
    elseif kind == "select" then E:select({ E:pick(n[1], n[2], 200) })
    elseif kind == "move" then E:move_selection(n[1], n[2])
    elseif kind == "camera" then viewer.set_camera(n[1], n[2], n[3])
    elseif kind == "save" then ui:save()
    elseif kind == "undo" then E:undo()
    end
    ui:layout()
end
local started = os.clock()
-- }}}

-- {{{ Viewer entry points
local objects_at = 0
local sim = 0
function scene_tick(dt)
    sim = sim + dt
    while actions[1] and actions[1].at <= sim do scripted(table.remove(actions, 1).what) end
end

function scene_paint()
    local mx, my, lp, ld, lr = viewer.mouse()
    local input = { mx = mx, my = my, lp = lp, ld = ld, lr = lr, keys = viewer.keys(),
                    shift = viewer.key_down("SHIFT"), ctrl = viewer.key_down("CTRL") }
    ui:update(input, 1 / 60)
    take_ground_changes()
    local now = os.clock()
    -- the ground again: at once after a stroke, else now and then during one
    if ground_dirty and (not E.stroke_now or now - ground_at > 0.4) then
        build_ground()
        ground_dirty, ground_at = false, now
        E.objects_changed = true   -- objects sit on the new ground
    end
    if E.objects_changed and now - objects_at > 0.15 then
        E.objects_changed = false
        objects_at = now
        rebake_changed()
    end
    local prims = {}
    local function add(list) for _, p in ipairs(list) do prims[#prims + 1] = p end end
    for _, o in ipairs(E.selection) do
        add(figures.ring(o.x, o.y, E:ground_z(o.x, o.y) + 4, o.kind == "doodad" and 48 or 40, { 90, 230, 90 }, 20, 3))
    end
    local g = ui.ground
    if g then
        if E:is_terrain_tool() then
            add(figures.ring(g[1], g[2], E:ground_z(g[1], g[2]) + 6, (E.brush.size + 0.5) * 128, { 240, 200, 90 }, 40, 5))
        elseif E.tool:match("^place") then
            add(figures.ring(g[1], g[2], E:ground_z(g[1], g[2]) + 6, 40, { 120, 200, 255 }, 20, 4))
        end
        if ui.drag and ui.drag.kind == "box" and ui.drag.x1 then
            local d = ui.drag
            for _, c in ipairs({ { d.x0, d.y0 }, { d.x1, d.y0 }, { d.x0, d.y1 }, { d.x1, d.y1 } }) do
                add(figures.ring(c[1], c[2], E:ground_z(c[1], c[2]) + 6, 12, { 90, 230, 90 }, 8, 4))
            end
        end
    end
    -- regions: their outlines while the region tool is in hand (issue 904)
    if E.tool == "regions" then
        local cx, cy, dist = viewer.camera()
        local reach = dist * 2.4
        for _, r in ipairs(E:regions()) do
            if r.right > cx - reach and r.left < cx + reach and r.top > cy - reach and r.bottom < cy + reach then
                local c = r == ui.region and { 240, 200, 90 } or { 120, 170, 255 }
                local function edge(x0, y0, x1, y1)
                    local n = math.max(1, math.floor(math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) / 128))
                    for k = 0, n - 1 do
                        local ax, ay = x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n
                        local bx, by = x0 + (x1 - x0) * (k + 1) / n, y0 + (y1 - y0) * (k + 1) / n
                        local za, zb = scene_ground(ax, ay) + 8, scene_ground(bx, by) + 8
                        local w = 6
                        local dx, dy = bx - ax, by - ay
                        local l = math.sqrt(dx * dx + dy * dy)
                        local nx, ny = -dy / l * w, dx / l * w
                        prims[#prims + 1] = { kind = "quad", color = c, pts = {
                            { ax + nx, ay + ny, za }, { bx + nx, by + ny, zb }, { bx - nx, by - ny, zb }, { ax - nx, ay - ny, za } } }
                    end
                end
                edge(r.left, r.bottom, r.right, r.bottom); edge(r.right, r.bottom, r.right, r.top)
                edge(r.right, r.top, r.left, r.top); edge(r.left, r.top, r.left, r.bottom)
            end
        end
    end
    kit.emit_prims(prims, render, true, 0)
end

function scene_ui() ui:draw(render) end
function scene_status() return "editor" end
function scene_key(_) end
function scene_ground(x, y)
    local i, j = E:tile_at(x, y)
    if not i then return 0 end
    local tp = E.terrain.tilepoints[j][i]
    local z = w3e.ground_z(tp)
    if tp.has_water then z = math.max(z, w3e.water_z(tp)) end
    return z
end
-- }}}
