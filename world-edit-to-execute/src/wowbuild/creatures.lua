--[[
creatures.lua - a WC3 map's units as the server's creatures (issue W02b)

Reads the map's placed units (parsers/unitsdoo.lua: war3mapUnits.doo) and
its players and forces (war3map.w3i), and decides the server-side rows a
converted map needs: one creature template per WC3 unit type the map
places, its model (through wowbuild/models.lua, as a display id of the
map's own), one faction per WC3 force, and one spawn per placed unit.
wowbuild.creatures.sql writes them as SQL for AzerothCore's world database.

W02h (decided 2026-09-23: "an empty database ... Filled only with what we
need") shapes it: the SQL writes only what this map uses, nothing borrowed
from a stock world database, and can be run again: it first deletes this
map's spawns and its blocks of template and model rows.

Rules (decided 2026-11-04, W02b; the owner's to overturn):
  ids        W02c's scheme (wowbuild/registration.lua): each converted map
             of a build folder takes a slot, 0-99, and every id is a block
             of it. The SQL names three of them as SQL variables at the top
             of the file, so a map's rows can be moved by changing one line:
               @MAP      the map id (Map.dbc)        900 + slot
               @ENTRY    the first creature template 9000000 + slot x 10000
               @GUID     the first spawn             1000000 + slot x 50000
             display ids (50000 + slot x 1000) and faction templates
             (3000 + slot x 100) are numbers here, since the client's tables
             (written by W02c from the same numbers) can't read SQL
             variables. Spawns are in the map's unit order; templates in
             type-id order, then faction order
  templates  one per WC3 type and faction placed: AzerothCore keeps a
             creature's faction in its template, so red's footmen and blue's
             are two templates of one type (custom types keep their own id, so
             a map's changed footman is its own template too). Name: the map's
             change (unam, its TRIGSTR resolved through war3map.wts), else
             the model table's row name, else the reader's list of common
             names, else the type id. Level: the map's change (ulev), else 1;
             stock values (hit points, level, speed) come from the player's
             WC3 install at load time (W02's open question 7) and are W02e's
             and W02h's to apply, so the template keeps AzerothCore's
             defaults for them
  models     the same lookup as doodads (wowbuild.placements.find_row with
             the unit's umdl field); a type with no row gets
             models.units.fallback, counted as unmapped, so the server can
             still spawn it. One display id per distinct model path; the
             placement list gives each display id's path and scale, which
             W02c writes into the client's CreatureDisplayInfo and
             CreatureModelData tables
  factions   one per WC3 force (war3map.w3i's forces when the map uses custom
             forces; otherwise every player slot is its own force, as melee
             games start), plus Neutral Hostile (hostile to every force) and
             Neutral Passive (hostile to none). A force's players are allied
             when its "allied" flag is set; every force is hostile to every
             other. Players 12-15 are the neutrals in maps saved before the
             24-player editor (w3i version below 28), 24-27 after
  spawns     the unit's WC3 position through wowbuild.coords, standing on
             the converted ground (the WC3 height field there; the server
             puts creatures on its own ground anyway); orientation from the
             WC3 facing (wowbuild.placements.orientation); a week to respawn
             (preplaced WC3 units don't come back; W02e's rules decide)
  left out   start locations (sloc: listed as start_locations instead),
             placed items (ids the map's item table or the reader's item
             list knows, YYI*, iDNR) and random units (YYU*, uDNR), each
             counted

    local creatures = require("wowbuild.creatures")
    local C = creatures.prepare(map, layout, job, models, opts)
    -- map: { units = parsers.unitsdoo's, info = parsers.w3i's, objects = { units = w3u, items = w3t },
    --        strings = parsers.wts's (or nil), has_file = fn(path) -> name or nil }
    local sql = creatures.sql(C, { map_dir = "WC3_DAoW_2_1" })
    C:counts()
]]

local unitsdoo = require("parsers.unitsdoo")
local placements = require("wowbuild.placements")

local creatures = {}

-- slot 0 of W02c's id scheme (wowbuild.convert passes the map's own slot)
do
    local ids = require("wowbuild.registration").ids(0)
    local S = require("wowbuild.registration").SCHEME
    creatures.DEFAULTS = {
        map_id = ids.map, entry_base = ids.entry, guid_base = ids.guid,
        display_base = ids.display, faction_base = ids.faction,
        entry_width = S.entry.width, guid_width = S.guid.width, display_width = S.display.width,
        faction_width = S.faction.width,
        respawn = 7 * 24 * 3600,
    }
end

-- {{{ helpers
local function resolve_string(v, strings)
    if type(v) ~= "string" then return v end
    local n = v:match("^TRIGSTR_(%-?%d+)$")
    if n and strings then
        local s = (strings.get and strings:get(tonumber(n))) or (strings.strings and strings.strings[tonumber(n)])
            or strings[tonumber(n)]
        if type(s) == "table" then s = s.text or s.value end
        if type(s) == "string" then return s end
    end
    return v
end

local function is_item(id, items)
    if id:sub(1, 3) == "YYI" or id == "iDNR" then return true end
    if items and items.has and items:has(id) then return true end
    return unitsdoo.COMMON_ITEMS[id] ~= nil
end

local function is_random(u)
    return u.random_unit ~= nil or u.id:sub(1, 3) == "YYU" or u.id == "uDNR"
end
-- }}}

creatures.resolve_string = resolve_string

-- {{{ creatures.factions
-- One faction per WC3 force, then the neutrals. Returns the list and a
-- player number -> faction lookup.
function creatures.factions(info, faction_base, strings)
    faction_base = faction_base or creatures.DEFAULTS.faction_base
    local list, by_player = {}, {}
    local neutral = (info and (info.version or 25) >= 28) and 24 or 12
    local function add(f)
        f.template = faction_base + #list
        list[#list + 1] = f
        for _, p in ipairs(f.players) do by_player[p] = f end
        return f
    end
    local custom = info and info.flags and info.flags.use_custom_forces and info.forces and #info.forces > 0
    if custom then
        for i, force in ipairs(info.forces) do
            local players = {}
            for _, p in ipairs(force.players or {}) do
                if p < neutral then players[#players + 1] = p end
            end
            local fname = resolve_string(force.name, strings)
            add({ name = (fname and fname ~= "" and not fname:match("^TRIGSTR_")) and fname or ("Force " .. i), force = i, players = players,
                  allied = force.flags and force.flags.allied or false })
        end
    end
    -- every player slot no force holds is a force of its own
    for _, p in ipairs(info and info.players or {}) do
        if not by_player[p.number] and p.number < neutral then
            local pname = resolve_string(p.name, strings)
            add({ name = (pname and pname ~= "" and not pname:match("^TRIGSTR_")) and pname or ("Player " .. (p.number + 1)),
                  players = { p.number }, allied = false })
        end
    end
    add({ name = "Neutral Hostile", players = { neutral }, neutral = "hostile", allied = true })
    add({ name = "Neutral Passive", players = { neutral + 1, neutral + 2, neutral + 3 }, neutral = "passive", allied = true })
    for _, f in ipairs(list) do
        f.enemies = {}
        for _, g in ipairs(list) do
            if g ~= f and f.neutral ~= "passive" and g.neutral ~= "passive" then f.enemies[#f.enemies + 1] = g.template end
        end
    end
    return list, by_player, neutral
end
-- }}}

-- {{{ creatures.prepare
function creatures.prepare(map, layout, job, models, opts)
    opts = opts or {}
    local D = creatures.DEFAULTS
    local C = setmetatable({
        map_id = opts.map_id or D.map_id, entry_base = opts.entry_base or D.entry_base,
        guid_base = opts.guid_base or D.guid_base, display_base = opts.display_base or D.display_base,
        respawn = D.respawn,
        templates = {}, by_type = {}, displays = {}, spawns = {}, start_locations = {},
        n = { units = 0, spawned = 0, start_locations = 0, items = 0, random = 0, unmapped = 0, outside = 0 },
        unmapped = {}, used = {},
    }, { __index = creatures.C })
    local info = map.info
    C.factions, C.faction_of = creatures.factions(info, opts.faction_base or D.faction_base, map.strings)
    local objects = map.objects and map.objects.units
    local items = map.objects and map.objects.items
    local mtable = models.units or {}
    local L = layout

    -- start locations: war3map.w3i's (every map has them), in player order
    for _, p in ipairs(info and info.players or {}) do
        local X, Y = L:to_wow(p.start_x or 0, p.start_y or 0)
        C.start_locations[#C.start_locations + 1] = { player = p.number, wc3 = { p.start_x, p.start_y },
            world = { X, Y, job and job:height_at(p.start_x or 0, p.start_y or 0) or 0 } }
    end

    local units = map.units and map.units.units or {}
    local types = {}
    for _, u in ipairs(units) do
        C.n.units = C.n.units + 1
        if u.id == "sloc" then
            C.n.start_locations = C.n.start_locations + 1
        elseif is_item(u.id, items) then
            C.n.items = C.n.items + 1
        elseif is_random(u) then
            C.n.random = C.n.random + 1
        else
            local wx, wy = u.position.x, u.position.y
            local col = (wx - L.offset_x) / 128
            local row = (L.H - 1) - (wy - L.offset_y) / 128
            if row < 0 or col < 0 or row >= L.nty * 128 or col >= L.ntx * 128 then
                C.n.outside = C.n.outside + 1
            else
                local f = C.faction_of[u.player] or C.factions[#C.factions - 1]   -- unknown players: Neutral Hostile
                local key = u.id .. "@" .. string.format("%06d", f.template)
                types[key] = { id = u.id, faction = f }
                C.spawns[#C.spawns + 1] = { unit = u, key = key, faction = f }
            end
        end
    end

    -- templates, in type-id order, then faction order
    local keys = {}
    for key in pairs(types) do keys[#keys + 1] = key end
    table.sort(keys)
    local display_of, row_of = {}, {}
    for k, key in ipairs(keys) do
        local id, faction = types[key].id, types[key].faction
        local found = row_of[id]
        if not found then
            local row, source, wc3_model = placements.find_row(id, mtable, objects, "umdl", map.has_file)
            if not row then
                row, source = mtable.fallback or { name = "Unmapped unit", wow = "", checked = false }, "fallback"
                C.n.unmapped = C.n.unmapped + 1
                C.unmapped[id] = true
            end
            found = { row, source, wc3_model }
            row_of[id] = found
        end
        local row, source, wc3_model = found[1], found[2], found[3]
        local base = (objects and objects.custom and objects.custom[id] and objects.custom[id].parent_id) or id
        local name = objects and objects.get_modification and objects:get_modification(id, "unam")
        name = resolve_string(name, map.strings)
        if type(name) ~= "string" or name == "" then
            name = (source ~= "fallback" and source ~= "map" and row.name) or unitsdoo.COMMON_UNITS[base] or id
        end
        name = name:gsub("%c", " ")          -- a name is one line in the client
        local level = objects and objects.get_modification and objects:get_modification(id, "ulev")
        level = tonumber(level) or 1
        local scale = (row.scale or 1) * (tonumber(objects and objects.get_modification and objects:get_modification(id, "usca")) or 1)
        local dkey = row.wow .. "|" .. string.format("%.4f", scale)
        local display = display_of[dkey]
        if not display then
            display = { id = C.display_base + #C.displays, wow = row.wow, scale = scale,
                        radius = row.radius or 1, reach = row.reach or 1.5, own = row.own or nil,
                        checked = row.checked and true or false, baseline = row.baseline }
            C.displays[#C.displays + 1] = display
            display_of[dkey] = display
        end
        C.used[row.wow] = row
        local t = { entry = C.entry_base + k - 1, offset = k - 1, id = id, base = base, name = name, level = level,
                    display = display, source = source, wc3_model = wc3_model, hero = unitsdoo.is_hero(id),
                    faction = faction }
        C.templates[k] = t
        C.by_type[key] = t
    end

    local D2 = creatures.DEFAULTS
    if #C.templates > D2.entry_width then
        error(string.format("%d creature templates: a map's block holds %d (wowbuild/registration.lua)", #C.templates, D2.entry_width), 0)
    end
    if #C.spawns > D2.guid_width then
        error(string.format("%d spawns: a map's block holds %d (wowbuild/registration.lua)", #C.spawns, D2.guid_width), 0)
    end
    if #C.displays > D2.display_width then
        error(string.format("%d creature looks: a map's block holds %d (wowbuild/registration.lua)", #C.displays, D2.display_width), 0)
    end

    -- spawns, in the map's order
    for n, s in ipairs(C.spawns) do
        local u = s.unit
        local t = C.by_type[s.key]
        local X, Y = L:to_wow(u.position.x, u.position.y)
        local Z = job and job:height_at(u.position.x, u.position.y) or (u.position.z * require("wowbuild.coords").YARDS_PER_UNIT)
        s.guid = C.guid_base + n - 1
        s.offset = n - 1
        s.template = t
        s.key = nil
        s.world = { X, Y, Z }
        s.orientation = placements.orientation(u.angle)
        s.unit = nil
        s.id, s.player, s.creation_number = u.id, u.player, u.creation_number
        s.wc3 = { u.position.x, u.position.y, u.position.z }
        s.hero_level = u.hero_data and u.hero_data.level or nil
        C.n.spawned = C.n.spawned + 1
    end
    return C
end
-- }}}

creatures.C = {}

-- {{{ C:counts
function creatures.C:counts()
    local ids = {}
    for id in pairs(self.unmapped) do ids[#ids + 1] = id end
    table.sort(ids)
    local unchecked = 0
    for _, d in ipairs(self.displays) do if not d.checked then unchecked = unchecked + 1 end end
    local types = {}
    for _, t in ipairs(self.templates) do types[t.id] = true end
    local n_types = 0
    for _ in pairs(types) do n_types = n_types + 1 end
    local n = self.n
    return {
        units = n.units, spawned = n.spawned, templates = #self.templates, displays = #self.displays,
        displays_unchecked = unchecked, factions = #self.factions, start_locations = #self.start_locations,
        sloc_units = n.start_locations, items_left_out = n.items, random_left_out = n.random,
        outside = n.outside, unmapped_ids = ids, unmapped = n.unmapped,
        unit_types = n_types,
        ids = { map = self.map_id, entry = self.entry_base, guid = self.guid_base, display = self.display_base,
                faction = self.factions[1] and self.factions[1].template or nil },
    }
end
-- }}}

-- {{{ creatures.sql
local function q(s)
    return "'" .. tostring(s):gsub("\\", "\\\\"):gsub("'", "''"):gsub("%z", "") .. "'"
end
-- text after "--": a map's names and paths are the map maker's, so a line
-- break (or any control character) in one must not end the comment
local function note(s)
    return (tostring(s):gsub("%c", " "))
end
local function num(v)
    if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return string.format("%d", v) end
    return string.format("%.4f", v)
end

creatures.TEMPLATE_COLUMNS = { "entry", "difficulty_entry_1", "difficulty_entry_2", "difficulty_entry_3",
    "KillCredit1", "KillCredit2", "name", "subname", "IconName", "gossip_menu_id", "minlevel", "maxlevel",
    "exp", "faction", "npcflag", "speed_walk", "speed_run", "speed_swim", "speed_flight", "detection_range",
    "rank", "dmgschool", "DamageModifier", "BaseAttackTime", "RangeAttackTime", "BaseVariance",
    "RangeVariance", "unit_class", "unit_flags", "unit_flags2", "dynamicflags", "family", "type",
    "type_flags", "lootid", "pickpocketloot", "skinloot", "PetSpellDataId", "VehicleId", "mingold",
    "maxgold", "AIName", "MovementType", "HoverHeight", "HealthModifier", "ManaModifier", "ArmorModifier",
    "ExperienceModifier", "RacialLeader", "movementId", "RegenHealth", "CreatureImmunitiesId",
    "flags_extra", "ScriptName", "VerifiedBuild" }

local function cols(list)
    local out = {}
    for i, c in ipairs(list) do out[i] = "`" .. c .. "`" end
    return "(" .. table.concat(out, ", ") .. ")"
end

-- C: creatures.prepare's; opts.map_dir names the map in the comments
function creatures.sql(C, opts)
    opts = opts or {}
    local o = {}
    local function w(line) o[#o + 1] = line end
    local n_t, n_s = #C.templates, #C.spawns
    w("-- W02b: the creatures of " .. tostring(opts.map_dir or "a converted WC3 map") .. " (src/wowbuild/creatures.lua)")
    w("-- For AzerothCore's world database. Only what this map uses (W02h); it can be run again.")
    w(string.format("-- %d templates, %d spawns, %d models, %d factions (faction templates %d-%d, display ids %d-%d:",
        n_t, n_s, #C.displays, #C.factions, C.factions[1].template, C.factions[#C.factions].template,
        C.display_base, C.display_base + math.max(#C.displays, 1) - 1))
    w("-- both are rows of the client's tables, which W02c writes from the same numbers: DBFilesClient/,")
    w("-- server/dbc.sql and patch-W.MPQ)")
    w("")
    w(string.format("SET @MAP := %d;        -- the map id (Map.dbc, W02c's scheme: 900 + the map's slot)", C.map_id))
    w(string.format("SET @ENTRY := %d;  -- the first creature template", C.entry_base))
    w(string.format("SET @GUID := %d;   -- the first spawn", C.guid_base))
    w("")
    w("-- {{{ this map's old rows")
    w("DELETE FROM `creature` WHERE `map` = @MAP;")
    local D = creatures.DEFAULTS
    w(string.format("DELETE FROM `creature_template` WHERE `entry` BETWEEN @ENTRY AND @ENTRY + %d;", D.entry_width - 1))
    w(string.format("DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN @ENTRY AND @ENTRY + %d;", D.entry_width - 1))
    w(string.format("DELETE FROM `creature_model_info` WHERE `DisplayID` BETWEEN %d AND %d;", C.display_base, C.display_base + D.display_width - 1))
    w("-- }}}")
    if n_t > 0 then
        w("")
        w("-- {{{ creature_template: one per WC3 unit type placed")
        w("INSERT INTO `creature_template` " .. cols(creatures.TEMPLATE_COLUMNS) .. " VALUES")
        for k, t in ipairs(C.templates) do
            local f = t.faction.template
            local v = { "@ENTRY + " .. t.offset, 0, 0, 0, 0, 0, q(t.name), q(""), "NULL", 0, t.level, t.level,
                0, f, 0, 1, "1.14286", 1, 1, 20,
                t.hero and 1 or 0, 0, 1, 2000, 2000, 1,
                1, 1, 0, 2048, 0, 0, 7,
                0, 0, 0, 0, 0, 0, 0,
                0, q(""), 0, 1, 1, 1, 1,
                1, 0, 0, 1, 0,
                0, q(""), 0 }
            for i = 1, #v do v[i] = tostring(v[i]) end
            w("  (" .. table.concat(v, ", ") .. ")" .. (k < n_t and "," or ";") .. "  -- " .. note(t.id ..
                (t.base ~= t.id and (" (copies " .. t.base .. ")") or "") .. ", " .. t.faction.name .. ", model by " .. t.source))
        end
        w("-- }}}")
        w("")
        w("-- {{{ creature_template_model: each template's model (display ids are the map's own)")
        w("INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES")
        for k, t in ipairs(C.templates) do
            w(string.format("  (@ENTRY + %d, 0, %d, 1, 1)%s  -- %s", t.offset, t.display.id, k < n_t and "," or ";", note(t.display.wow)))
        end
        w("-- }}}")
        w("")
        w("-- {{{ creature_model_info: the server checks every display id has a row")
        w("INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`) VALUES")
        for k, d in ipairs(C.displays) do
            w(string.format("  (%d, %s, %s, 2, 0)%s", d.id, num(d.radius * d.scale), num(d.reach * d.scale), k < #C.displays and "," or ";"))
        end
        w("-- }}}")
    end
    if n_s > 0 then
        w("")
        w("-- {{{ creature: one spawn per placed unit")
        w("INSERT INTO `creature` (`guid`, `id`, `map`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `Comment`) VALUES")
        for k, s in ipairs(C.spawns) do
            w(string.format("  (@GUID + %d, @ENTRY + %d, @MAP, 1, 1, %.3f, %.3f, %.3f, %.4f, %d, %s)%s",
                s.offset, s.template.offset, s.world[1], s.world[2], s.world[3], s.orientation, C.respawn,
                q(string.format("W02b: %s, WC3 unit %d, player %d", s.id, s.creation_number or -1, s.player or -1)),
                k < n_s and "," or ";"))
        end
        w("-- }}}")
    end
    w("")
    return table.concat(o, "\n")
end
-- }}}

return creatures
