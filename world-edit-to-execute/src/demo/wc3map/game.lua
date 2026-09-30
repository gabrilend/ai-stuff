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
  stats      opts.stock (gamedata/unit_stock.lua) gives the stock tables'
             values under the map's changes (Issue 525); without it only
             the map's changes are known
  building   workers place and raise structures (demo/wc3map/
             construction.lua, issue 531)
  abilities  casting with the script's spell events, cooldowns, mana,
             regeneration, auras, attack passives, buffs (demo/wc3map/
             abilities.lua, buffs.lua; issue 529)
  heroes     experience, levels, attributes, skills, revival, limits
             (demo/wc3map/heroes.lua, issue 528)
  economy    player state, food and upkeep, gathering, bounty, scores
             (demo/wc3map/economy.lua, issue 527); gameplay constants
             in g.constants (the map's war3mapMisc.txt over the
             install's), object tables in g.data (units, abilities,
             items, upgrades: stock under the map's changes)
  vision     fog of war per player (demo/wc3map/vision.lua; opts.vision =
             false for none): g.shown(u) says whether the local player
             sees u (Issue 524)

    local game = require("demo.wc3map.game").new(scene_data, { player = 0 })
    game.order(units, "move", x, y)
    game.tick(0.02)
]]

local loco = require("runtime.locomotion")
local names = require("ui.wc3.names")
local mpq = require("mpq")
local classify = require("demo.wc3map.classify")
local pathing_mod = require("demo.wc3map.pathing")
local combat = require("demo.wc3map.combat")
local map_scene = require("demo.wc3map.scene")
local production = require("demo.wc3map.production")
local vision_mod = require("demo.wc3map.vision")
local economy = require("demo.wc3map.economy")
local heroes = require("demo.wc3map.heroes")
local abilities = require("demo.wc3map.abilities")
local effects = require("demo.wc3map.effects")
local construction = require("demo.wc3map.construction")
local object_stock = require("gamedata.object_stock")
local game_constants = require("gamedata.game_constants")

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
-- Display name and stats for a unit type: the map's changes, else the
-- stock tables (stock: gamedata/unit_stock.lua, when the install is
-- there; Issue 525), else nothing (combat's stand-ins fill in)
local unit_stats_mod = {}
-- WC3's gameplay constants for heroes' attributes (1.21's)
unit_stats_mod.HP_PER_STR, unit_stats_mod.MANA_PER_INT, unit_stats_mod.ARMOR_PER_AGI = 25, 15, 0.3

local function unit_stats(m, id, stock)
    local t = m.object_data.units
    local from = { map = 0, stock = 0 }
    local function get(code)
        local v, origin
        if stock then
            v, origin = stock:value(id, code)
        else
            v = field(t, id, code)
            origin = v ~= nil and "map" or nil
        end
        if origin then from[origin] = from[origin] + 1 end
        return v
    end
    local s = { name = resolve(m, get("unam")) or names.unit(id) or id }
    s.hp_max = get("uhpm")
    s.mana_max = get("umpm")
    local base, dice, sides = get("ua1b"), get("ua1d"), get("ua1s")
    s.armor = get("udef")
    -- before attributes (heroes work their own out by level: heroes.lua)
    s.hp_raw, s.mana_raw, s.armor_raw, s.dmg_raw = s.hp_max, s.mana_max, s.armor, base
    s.level = get("ulev")
    s.str, s.agi, s.int = get("ustr"), get("uagi"), get("uint")
    s.str_type, s.agi_type, s.int_type = s.str, s.agi, s.int
    s.primary = get("upra")
    -- heroes: attributes add hit points, mana, armour and damage
    if s.str or s.agi or s.int then
        local K = unit_stats_mod
        if s.hp_max and s.str then s.hp_max = s.hp_max + s.str * K.HP_PER_STR end
        if s.int then s.mana_max = (s.mana_max or 0) + s.int * K.MANA_PER_INT end
        if s.armor and s.agi then s.armor = s.armor + s.agi * K.ARMOR_PER_AGI end
        local main = ({ STR = s.str, AGI = s.agi, INT = s.int })[tostring(s.primary or ""):upper()]
        if base and main then base = base + main end
    end
    if base then
        dice, sides = dice or 1, sides or 1
        s.damage = string.format("%d - %d", base + dice, base + dice * sides)
    end
    s.dmg_base, s.dmg_dice, s.dmg_sides = base, dice, sides
    s.cooldown_field = get("ua1c")
    s.range_field = get("ua1r")
    s.acquire_field = get("uacq")
    s.attacks = get("uaen")
    s.attack_point_field = get("udp1")
    s.backswing_field = get("ubs1")
    s.missile_field = get("ua1z")
    s.weapon_type = get("ua1w")
    s.speed = get("umvs")
    s.turn_rate = get("umvr")
    s.sight_day = get("usid")
    s.sight_night = get("usin")
    s.food = get("ufoo")
    s.food_made = get("ufma")
    s.stats_from = from
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

    -- the object tables, stock under the map's changes, and the gameplay
    -- constants (issues 525, 527): opts.chain is the install's game data
    local od = m.object_data or {}
    g.data = {
        units = opts.stock or object_stock.new(opts.chain, od.units, "units"),
        abilities = object_stock.new(opts.chain, od.abilities, "abilities"),
        items = object_stock.new(opts.chain, od.items, "items"),
        upgrades = object_stock.new(opts.chain, od.upgrades, "upgrades"),
        buffs = object_stock.new(opts.chain, od.buffs, "buffs"),
    }
    if not opts.stock then opts.stock = g.data.units end
    -- a stock source that only answers value() (tests, simple ones) gets
    -- list() from it
    if not g.data.units.list then
        local src = g.data.units
        function src.list(self, id, code, level)
            local v = self:value(id, code, level)
            local out = {}
            if type(v) == "string" then
                for x in v:gmatch("[^,%s]+") do if #x == 4 then out[#out + 1] = x end end
            end
            return out
        end
    end
    -- the command card's lists: the map's, else the stock tables', else
    -- the names module's
    do
        local map_list = g.db.unit_list
        function g.db.unit_list(id, code)
            local t = m.object_data and m.object_data.units
            if t and t:has(id) and t:get_modification(id, code) ~= nil then return map_list(id, code) end
            local stock_list = g.data.units:list(id, code)
            if #stock_list > 0 then return stock_list end
            return map_list(id, code)
        end
    end
    g.constants = opts.constants
    if not g.constants then
        local misc
        local ok, archive = pcall(mpq.open, scene.path)
        if ok and archive then
            if archive:has("war3mapMisc.txt") then misc = archive:extract("war3mapMisc.txt") end
            archive:close()
        end
        g.constants = game_constants.load({ chain = opts.chain, map_text = misc })
    end
    -- listeners: g.death_listeners (u, killer), g.made_listeners (u, how),
    -- g.spawn_listeners (u)
    g.death_listeners, g.made_listeners, g.spawn_listeners, g.damage_listeners = {}, {}, {}, {}
    function g.made(u, how)
        for _, f in ipairs(g.made_listeners) do f(u, how) end
    end

    local stats_cache = {}
    g.stock = opts.stock
    local function make_unit(id, spec, player, x, y, z, facing)
        local st = stats_cache[id]
        if not st then
            st = unit_stats(m, id, opts.stock)
            stats_cache[id] = st
        end
        local u = { id = id, spec = spec, player = player, x = x, y = y, z = z, facing = facing }
        for k, v in pairs(st) do u[k] = v end
        return u
    end
    -- the units the script places, as read from it (opts.placed == false:
    -- none, for when the script itself runs and makes them; see g.spawn)
    if opts.placed ~= false then
        for _, su in ipairs(scene.units) do
            g.units[#g.units + 1] = make_unit(su.id, su.spec, su.player, su.x, su.y, su.z, su.facing)
        end
    end

    -- players and forces
    g.players = {}
    for _, p in ipairs(m.players or {}) do
        local name = resolve(m, p.name) or ("Player " .. (p.number + 1))
        g.players[#g.players + 1] = { number = p.number, name = name, team = p.number }
    end
    -- a force's players are allies only when its "allied" flag is set
    -- (issue 519: sharing a force alone put enemies on one side)
    for fi, f in ipairs(m.forces or {}) do
        if f.flags and f.flags.allied then
            for _, pn in pairs(f.players or {}) do
                for _, p in ipairs(g.players) do
                    if p.number == pn then p.team = 100 + fi end
                end
            end
        end
    end
    local team_by = {}
    for _, p in ipairs(g.players) do team_by[p.number] = p.team end
    function g.team_of(n) return team_by[n] or n end
    -- a force flagged to share vision shares it among its players (a
    -- running script's alliances replace this: jass/natives/world.lua)
    local vision_team = {}
    for fi, f in ipairs(m.forces or {}) do
        if f.flags and f.flags.share_vision then
            for _, pn in pairs(f.players or {}) do vision_team[pn] = fi end
        end
    end
    function g.shares_vision(a, b)
        return a == b or (vision_team[a] ~= nil and vision_team[a] == vision_team[b])
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
    -- The top bar's numbers: gold, lumber, food used / made (capped by the
    -- ceiling), upkeep tier (issue 527)
    function g.resources(player)
        local unknown = 0
        for _, u in ipairs(g.units) do
            if u.player == player and u.alive ~= false and not u.food and u.spec.design == "unit" then
                unknown = unknown + 1
            end
        end
        local s = g.state(player)
        local used, cap = g.food(player)
        local tier, gtax = g.upkeep(player)
        return {
            gold = s.gold or 0, lumber = s.lumber or 0,
            food = used, food_cap = cap, food_ceiling = g.food_ceiling(player), food_unknown = unknown,
            upkeep = tier, upkeep_tax = gtax,
        }
    end
    -- }}}

    -- {{{ Units made and unmade (by the script: jass/vm.lua)
    g.bounds = { x0 = t.offset_x, y0 = t.offset_y,
                 x1 = t.offset_x + (t.width - 1) * 128, y1 = t.offset_y + (t.height - 1) * 128 }
    function g.ground_at(x, y) return scene.sample.ground_at(x, y) end

    local spec_cache = {}
    -- the design spec of a unit type (its kind, size ...), without making one
    function g.unit_spec(id)
        local base = spec_cache[id]
        if not base then
            base = map_scene.unit_spec(m, id)
            spec_cache[id] = base
        end
        return base
    end
    -- A new unit of type id (4 characters) for player at (x, y), facing
    -- in radians
    function g.spawn(id, player, x, y, facing)
        local base = spec_cache[id]
        if not base then
            base = map_scene.unit_spec(m, id)
            spec_cache[id] = base
        end
        local spec = {}
        for k, v in pairs(base) do spec[k] = v end
        spec.team = player
        local z = scene.sample.ground_at(x, y)
        if spec.archetype == "ship" then z = math.max(z, scene.sample.water_at(x, y)) end
        local u = make_unit(id, spec, player, x, y, z, facing or 0)
        combat.init_unit(u)
        g.units[#g.units + 1] = u
        for _, f in ipairs(g.spawn_listeners) do f(u) end
        g.spawned = (g.spawned or 0) + 1
        if spec.design == "building" then g.buildings_changed = true end
        return u
    end

    -- Gone at once, no corpse (RemoveUnit)
    function g.remove(u)
        u.removed, u.alive = true, false
        u.order, u.route, u.target = nil, nil, nil
        if u.spec.design == "building" then g.buildings_changed = true end
    end

    function g.kill(u, killer) combat.kill(g, u, killer) end
    function g.damage(source, target, amount, dopts) combat.damage(g, source or target, target, amount, dopts) end
    -- }}}

    function g.time_of_day()
        return (game_mod.DAY_START + g.time / game_mod.DAY_SECONDS * 24) % 24
    end

    -- {{{ movement
    g.pathing = opts.pathing ~= false and pathing_mod.new(t) or nil

    local function ensure_mover(u)
        if not u.mover then
            u.mover = loco.new({ speed = u.speed or 270, turn_rate = u.turn_rate or 0.6, propwin = 60 },
                               u.x, u.y, u.z, u.facing)
        end
        return u.mover
    end

    -- Set u walking to (x, y): flyers straight, the rest by a route around
    -- cliffs and deep water (as close as they can get)
    function g.walk_to(u, x, y)
        if u.spec.design ~= "unit" then return end
        local mv = ensure_mover(u)
        local route
        if u.spec.archetype == "flyer" or not g.pathing then
            route = { { x = x, y = y } }
        else
            route = g.pathing:route(u.x, u.y, x, y)
        end
        u.route = route
        if route then loco.set_route(mv, route) end
    end
    -- }}}

    -- {{{ g.order
    -- kind: move | attack (to a point, fighting on the way) | attack_unit
    -- (target) | patrol | stop | hold. Point orders keep a group's
    -- formation: units keep their places around the group's middle.
    function g.order(list, kind, x, y, target)
        if kind == "gather" then
            local any = false
            for _, u in ipairs(list) do any = g.gather(u, target, x, y) or any end
            return any
        end
        -- any other order ends gathering
        for _, u in ipairs(list) do u.harvest = nil; u.hidden_in_mine = nil end
        local cx, cy, n = 0, 0, 0
        for _, u in ipairs(list) do
            if u.spec.design == "unit" and u.alive ~= false then cx, cy, n = cx + u.x, cy + u.y, n + 1 end
        end
        if n == 0 then return end
        cx, cy = cx / n, cy / n
        for _, u in ipairs(list) do
            if u.spec.design == "unit" and u.alive ~= false then
                u.target, u.swing = nil, nil
                if kind == "stop" or kind == "hold" then
                    u.order = kind == "hold" and { kind = "hold" } or nil
                    u.route = nil
                elseif kind == "attack_unit" then
                    u.order = { kind = "attack_unit" }
                    u.target = target
                else
                    local ox, oy = u.x - cx, u.y - cy
                    local spread = math.sqrt(ox * ox + oy * oy)
                    if spread > 300 then ox, oy = ox / spread * 300, oy / spread * 300 end
                    u.order = { kind = kind, x = x + ox, y = y + oy, fx = u.x, fy = u.y }
                    g.walk_to(u, u.order.x, u.order.y)
                end
            end
        end
    end
    -- }}}

    -- {{{ g.run_script
    -- Run the map's own war3map.j (jass/vm.lua): config() and main() now,
    -- its triggers and timers with every tick after. Use with
    -- opts.placed = false, as the script makes the map's units itself.
    -- Returns the VM, or nil and why not.
    function g.run_script(vm_opts)
        local vm = require("jass.vm")
        vm_opts = vm_opts or {}
        vm_opts.player = vm_opts.player or g.player
        vm_opts.strings = vm_opts.strings or function(k) return m.strings and m.strings:resolve(k) end
        -- files the script names (an imported .ai) are read from the map
        vm_opts.read_file = vm_opts.read_file or function(name)
            local ok, archive = pcall(mpq.open, scene.path)
            if not ok or not archive then return nil end
            local data
            for _, n in ipairs({ name, (name:gsub("/", "\\")), "war3mapImported\\" .. name }) do
                if not data and archive:has(n) then data = archive:extract(n) end
            end
            archive:close()
            return data
        end
        local V = vm.new(g, vm_opts)
        local ok, err = V:load(scene.script or "")
        if not ok then return nil, err end
        g.script = V
        V:run_main()
        -- computer players: vm_opts.ai = "auto" (default: an AI for every
        -- computer player the map leaves without one, from vm_opts.ai_dir's
        -- profile files or derived), "script" (only what the map starts,
        -- as WC3 does) or "none"
        local mode = vm_opts.ai or "auto"
        if mode ~= "none" then
            local manager = require("ai").manager(V)
            manager:fill(mode, vm_opts.ai_dir)
        end
        return V
    end
    -- }}}

    -- {{{ g.tick
    combat.init(g)
    economy.init(g)
    production.init(g)
    heroes.init(g)
    construction.init(g)
    effects.init(g)
    abilities.init(g)
    if opts.vision ~= false then g.vision = vision_mod.new(g) end
    -- how many unit types' stats came from where
    function g.stats_report()
        local r = { types = 0, stock = 0, map = 0, neither = 0 }
        for _, st in pairs(stats_cache) do
            r.types = r.types + 1
            if st.stats_from.stock > 0 then r.stock = r.stock + 1 end
            if st.stats_from.map > 0 then r.map = r.map + 1 end
            if st.stats_from.stock + st.stats_from.map == 0 then r.neither = r.neither + 1 end
        end
        return r
    end
    -- whether the local player sees u (always, without fog of war)
    function g.shown(u)
        return not g.vision or g.vision:sees(g.player, u)
    end
    function g.tick(dt)
        g.time = g.time + dt
        if g.vision then g.vision:update(dt) end
        if g.script then g.script:tick(dt) end
        if g.ai_manager then g.ai_manager:update(dt) end
        if opts.combat ~= false then combat.update(g, dt) end
        production.update(g, dt)
        economy.update(g, dt)
        construction.update(g, dt)
        abilities.update(g, dt)
        effects.update(g, dt)

        local ground = function(x, y) return scene.sample.ground_at(x, y) end
        local keep = {}
        for _, u in ipairs(g.units) do
            if u.alive and u.route and not u.swing and not u.paused and not u.stunned then
                local mv = u.mover
                mv.speed = (u.speed or 270) * (u.speed_mult or 1)
                mv.x, mv.y, mv.facing = u.x, u.y, u.facing
                local done = loco.follow(mv, nil, dt, ground)
                u.x, u.y, u.facing = mv.x, mv.y, mv.facing
                if u.spec.archetype == "ship" then
                    u.z = math.max(scene.sample.ground_at(u.x, u.y), scene.sample.water_at(u.x, u.y))
                else
                    u.z = scene.sample.ground_at(u.x, u.y)
                end
                u.moved = true
                if done then
                    u.route = nil
                    local o = u.order
                    if o and o.kind == "patrol" then
                        o.x, o.y, o.fx, o.fy = o.fx, o.fy, o.x, o.y
                        g.walk_to(u, o.x, o.y)
                    elseif o and (o.kind == "move" or o.kind == "attack") then
                        u.order = nil
                    end
                end
            end
            -- the fallen lie a while, then go (heroes wait to be revived);
            -- removed units go at once
            if not u.removed and (u.alive or u.spec.hero or g.time - u.died_at < combat.CORPSE_TIME) then
                keep[#keep + 1] = u
            elseif g.on_remove then
                g.on_remove(u)
            end
        end
        g.units = keep
    end
    -- }}}
    return g
end
-- }}}

return game_mod
