--[[
WC3 Map Scene (Issue 517d)

Loads a .w3x/.w3m and turns it into things to draw, in WC3 world units:

  terrain  - every tilepoint's ground and water height (w3e, with the
             layer and flag fixes of 517a) and a colour per cell from its
             ground tileset
  doodads  - trees, rocks, props and structures from war3map.doo, each
             stood in for by a design (geometry/designs.lua)
  units    - the units and buildings the map's own script places:
             every CreateUnit(player, 'id', x, y, facing) call in war3map.j
             with a literal position. The script is read, not run; units
             that triggers create later are not here.

Headless: nothing here draws. map_scene.load() returns the data, and
map_scene.prims() the primitives to paint.

    local map_scene = require("demo.wc3map.scene")
    local s = map_scene.load("assets/Daow4.4.w3x")
    print(map_scene.summary(s))
]]

local Map = require("data")
local mpq = require("mpq")
local w3e = require("parsers.w3e")
local designs = require("geometry.designs")
local classify = require("demo.wc3map.classify")

local map_scene = {}

-- {{{ Player numbers in scripts
local PLAYER_CONSTANTS = {
    PLAYER_NEUTRAL_AGGRESSIVE = 12, bj_PLAYER_NEUTRAL_VICTIM = 13,
    bj_PLAYER_NEUTRAL_EXTRA = 14, PLAYER_NEUTRAL_PASSIVE = 15,
}

-- "3", "$A", "0x0A" or a constant's name -> player number (nil if unknown)
function map_scene.player_number(text)
    text = text:gsub("%s", "")
    if PLAYER_CONSTANTS[text] then return PLAYER_CONSTANTS[text] end
    if text:match("^%$%x+$") then return tonumber(text:sub(2), 16) end
    if text:match("^0[xX]%x+$") then return tonumber(text:sub(3), 16) end
    return tonumber(text)
end
-- }}}

-- {{{ map_scene.script_units
-- Every CreateUnit call in the script with a literal position, and the
-- player it was for: { {id, x, y, facing, player}, ... }. The player is an
-- inline Player(n), or the last Player(n) assigned to the variable passed.
function map_scene.script_units(script)
    local events = {}
    -- assignments: set v=Player(n), and local player v=Player(n)
    for _, form in ipairs({ "set%s+([%w_]+)%s*=%s*Player%(([^%)]+)%)",
                            "local%s+player%s+([%w_]+)%s*=%s*Player%(([^%)]+)%)" }) do
        local pos = 1
        while true do
            local s, e, var, arg = script:find(form, pos)
            if not s then break end
            events[#events + 1] = { at = s, var = var, player = map_scene.player_number(arg) }
            pos = e + 1
        end
    end
    -- creations
    local pos
    local num = "(%-?[%d%.]+)"
    local call = "CreateUnit%(%s*([^,]-)%s*,%s*'(....)'%s*,%s*" .. num .. "%s*,%s*" .. num .. "%s*,%s*" .. num .. "%s*%)"
    pos = 1
    while true do
        local s, e, who, id, x, y, f = script:find(call, pos)
        if not s then break end
        events[#events + 1] = { at = s, who = who, id = id, x = tonumber(x), y = tonumber(y), facing = tonumber(f) }
        pos = e + 1
    end
    table.sort(events, function(a, b) return a.at < b.at end)

    local vars, units = {}, {}
    for _, ev in ipairs(events) do
        if ev.var then
            vars[ev.var] = ev.player
        elseif ev.x and ev.y then
            local inline = ev.who:match("^Player%((.+)%)$")
            local player = inline and map_scene.player_number(inline) or vars[ev.who] or 15
            units[#units + 1] = { id = ev.id, x = ev.x, y = ev.y, facing = ev.facing or 270, player = player }
        end
    end
    return units
end
-- }}}

-- {{{ Ground colours
-- By the last three letters of a ground tileset's id (its texture), then
-- by keyword. Look only: stand-ins for textures, not measured from them.
local GROUND = {
    { { "grs", "gra", "grd", "gras", "lgb" }, { 86, 142, 62 } },   -- grass
    { { "lvd", "lvs", "lea" }, { 58, 104, 58 } },                  -- leaves
    { { "drt", "dir", "drh", "dtr", "dru" }, { 128, 98, 64 } },    -- dirt
    { { "rck", "rok", "rk", "rb" }, { 118, 112, 104 } },           -- rock
    { { "sno", "snw", "sn" }, { 226, 230, 236 } },                 -- snow
    { { "san", "snd" }, { 196, 176, 120 } },                       -- sand
    { { "ice", "ki" }, { 176, 206, 226 } },                        -- ice
    { { "sqd", "sq", "til", "brk", "bri" }, { 150, 146, 140 } },   -- tiles, bricks
    { { "cbp", "cb", "cob" }, { 128, 118, 104 } },                 -- cobbles
    { { "c" }, { 108, 100, 92 } },                                 -- cliff textures used as ground
}
local DEFAULT_GROUND = { 110, 120, 80 }
local BLIGHT = { 94, 70, 96 }

function map_scene.ground_color(tileset)
    tileset = (tileset or ""):lower()
    local texture = tileset:sub(2)
    for _, entry in ipairs(GROUND) do
        for _, key in ipairs(entry[1]) do
            if texture:find(key, 1, true) == 1 or (#key > 1 and texture:find(key, 1, true)) then
                return entry[2]
            end
        end
    end
    if tileset:sub(1, 1) == "c" then return GROUND[#GROUND][2] end
    return DEFAULT_GROUND
end
-- }}}

-- {{{ Object info from the map's own tables
local function object_info(m, table_name, id, name_code, model_code, depth)
    local t = m.object_data and m.object_data[table_name]
    if not t or not t:has(id) or (depth or 0) > 3 then return nil end
    local name = t:get_modification(id, name_code)
    if type(name) == "string" and name:find("^TRIGSTR_") then
        name = m.strings:resolve(name)
    end
    local parent = t:get_parent(id)
    local parent_id = type(parent) == "table" and (parent.id or parent.original_id) or parent
    if parent_id == id then parent_id = nil end
    return {
        name = type(name) == "string" and name or nil,
        model = t:get_modification(id, model_code),
        parent = parent_id,
        parent_info = parent_id and object_info(m, table_name, parent_id, name_code, model_code, (depth or 0) + 1),
    }
end
-- }}}

-- {{{ Terrain sampling
-- Ground (and water) height at WC3 (x, y), bilinear between tilepoints
local function sampler(t)
    local w, h = t.width, t.height
    local x0, y0 = t.offset_x, t.offset_y
    local ground, water = {}, {}
    for j = 0, h - 1 do
        for i = 0, w - 1 do
            local tp = t:get_tile(i, j)
            ground[j * w + i] = w3e.ground_z(tp)
            water[j * w + i] = tp.has_water and w3e.water_z(tp) or -1e30
        end
    end
    local function at(grid, x, y)
        local fx = math.max(0, math.min(w - 1.001, (x - x0) / 128))
        local fy = math.max(0, math.min(h - 1.001, (y - y0) / 128))
        local i, j = math.floor(fx), math.floor(fy)
        local u, v = fx - i, fy - j
        local a, b = grid[j * w + i], grid[j * w + i + 1]
        local c, d = grid[(j + 1) * w + i], grid[(j + 1) * w + i + 1]
        return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v
    end
    return {
        ground = ground, water = water,
        ground_at = function(x, y) return at(ground, x, y) end,
        water_at = function(x, y) return at(water, x, y) end,
    }
end
-- }}}

-- {{{ map_scene.load
function map_scene.load(path)
    local m = Map.load(path)
    local t = m.terrain
    local s = {
        path = path, map = m, terrain = t,
        name = m.strings and m.strings:resolve(m.name or "") or m.name,
        doodads = {}, units = {},
        counts = { doodads = 0, skipped = 0, units = 0, by = {} },
    }
    s.sample = sampler(t)

    -- doodads and destructables
    for _, d in ipairs(m.registry.doodads or {}) do
        local info = object_info(m, "destructibles", d.id, "bnam", "bfil")
            or object_info(m, "doodads", d.id, "dnam", "dfil")
        local spec = classify.doodad(d.id, info)
        if spec then
            spec.variant = d.variation
            s.doodads[#s.doodads + 1] = { spec = spec, x = d.position.x, y = d.position.y,
                z = d.position.z, facing = d.angle or 0,
                scale = { d.scale.x or 1, d.scale.y or 1, d.scale.z or 1 } }
            s.counts.doodads = s.counts.doodads + 1
            s.counts.by[spec.by] = (s.counts.by[spec.by] or 0) + 1
        else
            s.counts.skipped = s.counts.skipped + 1
        end
    end

    -- units the script places
    local archive = mpq.open(path)
    local script = archive:has("war3map.j") and archive:extract("war3map.j")
        or (archive:has("scripts\\war3map.j") and archive:extract("scripts\\war3map.j")) or ""
    archive:close()
    for _, u in ipairs(map_scene.script_units(script)) do
        local info = object_info(m, "units", u.id, "unam", "umdl")
        local spec = classify.unit(u.id, info)
        spec.team = u.player
        local ground = s.sample.ground_at(u.x, u.y)
        local z = ground
        if spec.archetype == "ship" then z = math.max(ground, s.sample.water_at(u.x, u.y)) end
        s.units[#s.units + 1] = { spec = spec, id = u.id, x = u.x, y = u.y, z = z,
            facing = math.rad(u.facing), player = u.player }
        s.counts.units = s.counts.units + 1
        s.counts.by[spec.by] = (s.counts.by[spec.by] or 0) + 1
    end
    return s
end
-- }}}

-- {{{ map_scene.terrain_arrays
-- Packed arrays for render.land_build: heights, cell colours, water
-- (LuaJIT FFI; returns strings)
function map_scene.terrain_arrays(s)
    local ffi = require("ffi")
    local t = s.terrain
    local w, h = t.width, t.height
    local heights = ffi.new("float[?]", w * h)
    local water = ffi.new("float[?]", w * h)
    for k = 0, w * h - 1 do
        heights[k] = s.sample.ground[k]
        water[k] = s.sample.water[k]
    end
    local colors = ffi.new("uint8_t[?]", (w - 1) * (h - 1) * 3)
    for j = 0, h - 2 do
        for i = 0, w - 2 do
            local tp = t:get_tile(i, j)
            local c = map_scene.ground_color(t.ground_tilesets[tp.ground_texture + 1])
            if tp.is_blight then c = BLIGHT end
            -- a little variation per cell, from the texture's variation
            local k = 0.94 + (tp.texture_details % 5) * 0.03
            local o = (j * (w - 1) + i) * 3
            colors[o] = math.min(255, c[1] * k)
            colors[o + 1] = math.min(255, c[2] * k)
            colors[o + 2] = math.min(255, c[3] * k)
        end
    end
    return ffi.string(heights, w * h * 4), ffi.string(colors, (w - 1) * (h - 1) * 3),
           ffi.string(water, w * h * 4)
end
-- }}}

-- {{{ map_scene.prims
-- Every doodad and unit as primitives (WC3 units)
function map_scene.prims(s)
    local list = {}
    local function add(p)
        for _, q in ipairs(p) do list[#list + 1] = q end
    end
    for _, d in ipairs(s.doodads) do
        add(designs.build(d.spec, d.x, d.y, d.z, d.facing, d.scale))
    end
    for _, u in ipairs(s.units) do
        add(designs.build(u.spec, u.x, u.y, u.z, u.facing, 1))
    end
    return list
end
-- }}}

-- {{{ map_scene.summary
function map_scene.summary(s)
    local by = {}
    for k, v in pairs(s.counts.by) do by[#by + 1] = k .. " " .. v end
    table.sort(by)
    return string.format("%s: %dx%d, %d doodads (%d blockers skipped), %d units; decided by %s",
        s.name or "?", s.terrain.width, s.terrain.height, s.counts.doodads, s.counts.skipped,
        s.counts.units, table.concat(by, ", "))
end
-- }}}

return map_scene
