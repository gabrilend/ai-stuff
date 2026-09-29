--[[
Map Game State (Issue 518c)

What the WC3 interface (ui/wc3/hud.lua) needs from a loaded map scene
(demo/wc3map/scene.lua), without a window:

  units      every placed object, with its display name and the stats the
             map defines (hit points, mana, damage, armour, level, hero
             attributes); movers for units given orders
  db         the command card's questions: ability, train and build lists
             and button placements, from the map's object data, else the
             stock lists in ui/wc3/names.lua
  orders     move, attack (moves; no combat yet), patrol, stop, hold,
             carried out with runtime/locomotion.lua in a straight line
             over the ground (no pathfinding yet)
  resources  gold and lumber: WC3's melee starting 500 and 150 unless the
             script sets them with a literal; food from the map's food
             fields where it defines them
  clock      the day starts at 8:00 and lasts 480 seconds (from memory of
             the game; see 516d)
  players, forces, quests (CreateQuestBJ titles from the script), minimap

    local game = require("demo.wc3map.game").new(scene_data, { player = 0 })
    game.order(units, "move", x, y)
    game.tick(0.02)
]]

local loco = require("runtime.locomotion")
local names = require("ui.wc3.names")
local mpq = require("mpq")
local classify = require("demo.wc3map.classify")

local game_mod = {}

game_mod.DAY_SECONDS = 480    -- one game day (from memory; 516d)
game_mod.DAY_START = 8        -- hour the game starts at
game_mod.FOOD_MAX = 100

-- {{{ Object data access
local function field(t, id, code)
    if not t or not t:has(id) then return nil end
    return t:get_modification(id, code)
end

local function resolve(m, v)
    if type(v) == "string" and v:find("TRIGSTR_") then
        return (v:gsub("TRIGSTR_%d+", function(k) return m.strings:resolve(k) or k end))
    end
    return v
end

local function split(v)
    local out = {}
    if type(v) ~= "string" then return out end
    for id in v:gmatch("[^,%s]+") do
        if #id == 4 then out[#out + 1] = id end
    end
    return out
end
-- }}}

-- {{{ make_db
-- The command card's view of the map's object data
local function make_db(m)
    local units, abilities = m.object_data.units, m.object_data.abilities
    local db = {}

    function db.unit_list(id, code)
        local list = split(field(units, id, code))
        if #list > 0 then return list end
        if code == "ubui" and names.BUILDS[id] then return names.BUILDS[id] end
        if code == "utra" and names.TRAINS[id] then return names.TRAINS[id] end
        return {}
    end

    function db.unit_button(id)
        local spec = classify.unit(id, {
            name = resolve(m, field(units, id, "unam")), model = field(units, id, "umdl") })
        return {
            archetype = spec.archetype,
            name = resolve(m, field(units, id, "unam")) or names.unit(id) or id,
            hotkey = field(units, id, "uhot"),
            x = field(units, id, "ubpx"), y = field(units, id, "ubpy"),
            tip = resolve(m, field(units, id, "utub")),
        }
    end

    function db.ability_button(id)
        local parent = abilities and abilities:has(id) and abilities:get_parent(id)
        local parent_id = type(parent) == "table" and (parent.id or parent.original_id) or parent
        return {
            name = resolve(m, field(abilities, id, "anam")) or names.ability(id)
                or (parent_id and names.ability(parent_id)) or id,
            hotkey = field(abilities, id, "ahky"),
            x = field(abilities, id, "abpx"), y = field(abilities, id, "abpy"),
            rx = field(abilities, id, "arpx"), ry = field(abilities, id, "arpy"),
            tip = resolve(m, field(abilities, id, "aub1")),
        }
    end
    return db
end
-- }}}

-- {{{ unit_stats
-- Display name and the stats the map defines for a unit type
local function unit_stats(m, id)
    local t = m.object_data.units
    local s = { name = resolve(m, field(t, id, "unam")) or names.unit(id) or id }
    s.hp_max = field(t, id, "uhpm")
    s.mana_max = field(t, id, "umpm")
    local base, dice, sides = field(t, id, "ua1b"), field(t, id, "ua1d"), field(t, id, "ua1s")
    if base then
        dice, sides = dice or 1, sides or 1
        s.damage = string.format("%d - %d", base + dice, base + dice * sides)
    end
    s.armor = field(t, id, "udef")
    s.level = field(t, id, "ulev")
    s.str, s.agi, s.int = field(t, id, "ustr"), field(t, id, "uagi"), field(t, id, "uint")
    s.speed = field(t, id, "umvs")
    s.turn_rate = field(t, id, "umvr")
    s.food = field(t, id, "ufoo")
    s.food_made = field(t, id, "ufma")
    return s
end
-- }}}

-- {{{ script_extras
-- Quests (CreateQuestBJ(type, title, ...): types 0-1 required, 2-3
-- optional) and literal starting gold/lumber for the local player
local function script_extras(m, path, player)
    local script = ""
    local ok, archive = pcall(mpq.open, path)
    if ok and archive then
        script = archive:has("war3map.j") and archive:extract("war3map.j")
            or (archive:has("scripts\\war3map.j") and archive:extract("scripts\\war3map.j")) or ""
        archive:close()
    end
    local quests = { main = {}, optional = {} }
    for kind, title in script:gmatch('CreateQuestBJ%(%s*([%w_]+)%s*,%s*"([^"]*)"') do
        local n = tonumber(kind) or (kind:find("OPT") and 2 or 0)
        table.insert(n >= 2 and quests.optional or quests.main, resolve(m, title))
    end
    local res = {}
    for which, amount in script:gmatch("SetPlayerState%(%s*Player%(" .. player .. "%)%s*,%s*PLAYER_STATE_RESOURCE_(%u+)%s*,%s*(%d+)%s*%)") do
        res[which:lower()] = tonumber(amount)
    end
    return quests, res
end
-- }}}

-- {{{ minimap_image
-- A size x size RGBA picture of the ground, north up (a string)
local function minimap_image(scene, size)
    local ffi = require("ffi")
    local t = scene.terrain
    local w3e = require("parsers.w3e")
    local map_scene = require("demo.wc3map.scene")
    local buf = ffi.new("uint8_t[?]", size * size * 4)
    for py = 0, size - 1 do
        for px = 0, size - 1 do
            local i = math.floor(px / size * (t.width - 1))
            local j = math.floor((size - 1 - py) / size * (t.height - 1))
            local tp = t:get_tile(i, j)
            local c
            if tp.is_boundary or tp.boundary then
                c = { 0, 0, 0 }
            elseif w3e.is_wet(tp) then
                local depth = math.min(1, (w3e.water_z(tp) - w3e.ground_z(tp)) / 256)
                c = { 60 - 40 * depth, 130 - 70 * depth, 190 - 50 * depth }
            else
                local g = map_scene.ground_color(t.ground_tilesets[tp.ground_texture + 1])
                local k = 0.75 + math.max(-0.2, math.min(0.35, w3e.ground_z(tp) / 1200))
                c = { g[1] * k, g[2] * k, g[3] * k }
            end
            local o = (py * size + px) * 4
            buf[o], buf[o + 1], buf[o + 2], buf[o + 3] =
                math.min(255, c[1]), math.min(255, c[2]), math.min(255, c[3]), 255
        end
    end
    return ffi.string(buf, size * size * 4)
end
-- }}}

-- {{{ game_mod.new
-- scene: from map_scene.load. opts: { player = local player number }
function game_mod.new(scene, opts)
    opts = opts or {}
    local m = scene.map
    local t = scene.terrain
    local g = { scene = scene, player = opts.player or 0, units = {}, time = 0 }
    g.db = make_db(m)

    local stats_cache = {}
    for _, su in ipairs(scene.units) do
        local st = stats_cache[su.id]
        if not st then
            st = unit_stats(m, su.id)
            stats_cache[su.id] = st
        end
        local u = { id = su.id, spec = su.spec, player = su.player, x = su.x, y = su.y, z = su.z,
                    facing = su.facing }
        for k, v in pairs(st) do u[k] = v end
        g.units[#g.units + 1] = u
    end

    -- players and forces
    g.players = {}
    for _, p in ipairs(m.players or {}) do
        local name = resolve(m, p.name) or ("Player " .. (p.number + 1))
        g.players[#g.players + 1] = { number = p.number, name = name, team = p.number }
    end
    for fi, f in ipairs(m.forces or {}) do
        for _, pn in pairs(f.players or {}) do
            for _, p in ipairs(g.players) do
                if p.number == pn then p.team = 100 + fi end
            end
        end
    end
    for _, p in ipairs(g.players) do if p.number == g.player then g.team = p.team end end

    g.quests, g.start_resources = script_extras(m, scene.path, g.player)
    g.minimap = {
        x0 = t.offset_x, y0 = t.offset_y,
        x1 = t.offset_x + (t.width - 1) * 128, y1 = t.offset_y + (t.height - 1) * 128,
        size = 256,
    }
    if opts.minimap ~= false then g.minimap.rgba = minimap_image(scene, g.minimap.size) end

    -- {{{ g.resources
    function g.resources(player)
        local food, cap, unknown = 0, 0, 0
        for _, u in ipairs(g.units) do
            if u.player == player then
                if u.food then food = food + u.food elseif u.spec.design == "unit" then unknown = unknown + 1 end
                if u.food_made then cap = cap + u.food_made end
            end
        end
        return {
            gold = g.start_resources.gold or 500, lumber = g.start_resources.lumber or 150,
            food = food, food_cap = math.min(game_mod.FOOD_MAX, cap), food_unknown = unknown,
        }
    end
    -- }}}

    function g.time_of_day()
        return (game_mod.DAY_START + g.time / game_mod.DAY_SECONDS * 24) % 24
    end

    -- {{{ g.order
    -- Formation: units keep their places relative to the group's middle,
    -- as WC3's formation movement keeps a group together
    function g.order(list, kind, x, y)
        local cx, cy, n = 0, 0, 0
        for _, u in ipairs(list) do
            if u.spec.design == "unit" then cx, cy, n = cx + u.x, cy + u.y, n + 1 end
        end
        if n == 0 then return end
        cx, cy = cx / n, cy / n
        for _, u in ipairs(list) do
            if u.spec.design == "unit" then
                if kind == "stop" or kind == "hold" then
                    u.order = kind == "hold" and { kind = "hold" } or nil
                else
                    local ox, oy = u.x - cx, u.y - cy
                    local spread = math.sqrt(ox * ox + oy * oy)
                    if spread > 300 then ox, oy = ox / spread * 300, oy / spread * 300 end
                    if not u.mover then
                        u.mover = loco.new({ speed = u.speed or 270, turn_rate = u.turn_rate or 0.6, propwin = 60 },
                                           u.x, u.y, u.z, u.facing)
                    end
                    u.order = { kind = kind, x = x + ox, y = y + oy, fx = u.x, fy = u.y }
                end
            end
        end
    end
    -- }}}

    -- {{{ g.tick
    function g.tick(dt)
        g.time = g.time + dt
        local ground = function(x, y) return scene.sample.ground_at(x, y) end
        for _, u in ipairs(g.units) do
            local o = u.order
            if o and o.x then
                local mv = u.mover
                mv.x, mv.y, mv.facing = u.x, u.y, u.facing
                if loco.step(mv, o.x, o.y, dt, ground) then
                    if o.kind == "patrol" then
                        o.x, o.y, o.fx, o.fy = o.fx, o.fy, o.x, o.y
                    else
                        u.order = nil
                    end
                end
                u.x, u.y, u.facing = mv.x, mv.y, mv.facing
                if u.spec.archetype == "ship" then
                    u.z = math.max(scene.sample.ground_at(u.x, u.y), scene.sample.water_at(u.x, u.y))
                else
                    u.z = scene.sample.ground_at(u.x, u.y)
                end
                u.moved = true
            end
        end
    end
    -- }}}
    return g
end
-- }}}

return game_mod
