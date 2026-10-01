--[[
Tests for new maps (Issue 911b): the map info written back byte for byte
on every test map; a new melee map made from nothing (map info, ground,
pathing, shadows, doodads, script, archive and header), opened in the
editor, edited and saved; played: each player's town hall and workers by
its start, gold mines, the melee AI only for the map's computer players,
and it builds; a custom (not melee) map starts empty; the command line.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

local mpq = require("mpq")
local w3i = require("parsers.w3i")
local new_map = require("editor.new_map")
local editor = require("editor")

-- {{{ Map info written back
test_section("war3map.w3i written back")
do
    local maps = io.popen('ls "' .. DIR .. '/assets/"*.w3x'):read("*a")
    local n, same = 0, 0
    for m in maps:gmatch("[^\n]+") do
        local a = mpq.open(m)
        local d = a:extract("war3map.w3i")
        a:close()
        n = n + 1
        if w3i.write(w3i.parse(d)) == d then same = same + 1 end
    end
    test("every test map's, byte for byte", n > 10 and same == n, same .. "/" .. n)
end
-- }}}

local function play(path, ticks)
    local s = require("demo.wc3map.scene").load(path)
    local g = require("demo.wc3map.game").new(s, { player = 0, placed = false, minimap = false, vision = false })
    local V = g.run_script({ ai = "auto" })
    for _ = 1, ticks or 0 do g.tick(0.1) end
    return g, V
end

local function count(g, player, id)
    local n = 0
    for _, u in ipairs(g.units) do
        if u.player == player and u.id == id and u.alive ~= false then n = n + 1 end
    end
    return n
end

-- {{{ A new melee map
test_section("A new melee map")
local P = os.tmpname() .. ".w3x"
do
    local ok, files, L = new_map.create(P, { name = "Two Rivers", author = "Tester", width = 64, height = 64,
        tileset = "L", melee = true,
        players = { { race = "human" }, { race = "orc", computer = true }, { race = "undead", computer = true } } })
    test("made", ok and io.open(P, "rb") ~= nil, tostring(files))
    local wrap = require("mpq.map_wrapper").read(P)
    test("its header: name and players", wrap and wrap.map_name == "Two Rivers" and wrap.max_players == 3)
    local a = mpq.open(P)
    local info = w3i.parse(a:extract("war3map.w3i"))
    test("its info", info.name == "Two Rivers" and info.author == "Tester" and info.playable_width == 64
        and info.width == 76 and #info.players == 3 and info.players[2].type == "computer"
        and info.players[3].race == "undead" and info.flags.melee_map)
    local t = require("parsers.w3e").parse(a:extract("war3map.w3e"))
    test("its ground: 77 by 77 points, flat, dry", t.width == 77 and t.height == 77 and t.tilepoints[30][30].height == 0
        and not t.tilepoints[30][30].has_water and t.tilepoints[0][0].boundary and not t.tilepoints[30][30].boundary)
    local wpm = require("demo.wc3map.footprint").parse_wpm(a:extract("war3map.wpm"))
    test("its pathing: open inside, closed at the edge", wpm.w == 304 and wpm.bytes:byte(150 * 304 + 151) == 0x40
        and wpm.bytes:byte(1) == 0xCE)
    test("no shadows, no doodads", #a:extract("war3map.shd") == 304 * 304 and #a:extract("war3map.doo") == 24)
    local j = a:extract("war3map.j")
    test("its script: start locations, slots, melee", j:find("DefineStartLocation(2,", 1, true)
        and j:find("SetPlayerRacePreference(Player(2), RACE_PREF_UNDEAD)", 1, true)
        and j:find("call MeleeStartingUnits()", 1, true) ~= nil)
    a:close()

    local g, V = play(P, 0)
    test("the script runs", V and #V.errors == 0, V and V.errors[1] and V.errors[1].message)
    test("the human's hall and five peasants", count(g, 0, "htow") == 1 and count(g, 0, "hpea") == 5)
    test("the orc's", count(g, 1, "ogre") == 1 and count(g, 1, "opeo") == 5)
    test("the undead's", count(g, 2, "unpl") == 1 and count(g, 2, "uaco") == 3 and count(g, 2, "ugho") == 1)
    test("a gold mine by each", count(g, 15, "ngol") == 3)
    local hall = nil
    for _, u in ipairs(g.units) do if u.id == "htow" then hall = u end end
    test("the hall at its start location", hall and math.abs(hall.x - L.players[1].x) < 1 and math.abs(hall.y - L.players[1].y) < 1)
    local r = g.ai_manager:report()
    local ais = {}
    for _, x in ipairs(r) do ais[#ais + 1] = x.player end
    test("the melee AI for the two computers only", #ais == 2 and ais[1] == 1 and ais[2] == 2, table.concat(ais, ","))
    for _ = 1, 400 do g.tick(0.1) end
    local built = 0
    for _, u in ipairs(g.units) do
        if u.player == 1 and u.alive ~= false and u.spec.design == "building" and u.id ~= "ogre" then built = built + 1 end
    end
    test("in forty seconds the orc AI has built", built >= 1, tostring(built))
end
-- }}}

-- {{{ Edited
test_section("Opened in the editor, edited, saved, played")
do
    local E = assert(editor.open(P))
    test("opened: the gold mines as the script's units", #E.script_units == 3)
    local mine = E.script_units[1]
    E:select({ mine })
    E:move_selection(128, 0)
    E:set_tool("raise")
    E:stroke_begin(nil, 0, 0); E:stroke(0, 0); E:stroke_end()
    local t = E:new_trigger("Welcome")
    E:add_block(t, "events", "map_init")
    E:add_block(t, "actions", "display_text", { text = "Welcome to Two Rivers" })
    local P2 = os.tmpname() .. ".w3x"
    assert(E:save(P2))
    local g, V = play(P2, 1)
    local moved = false
    for _, u in ipairs(g.units) do
        if u.id == "ngol" and math.abs(u.x - mine.x) < 1 and math.abs(u.y - mine.y) < 1 then moved = true end
    end
    test("the moved mine where it was put", moved)
    local said = false
    for _, m in ipairs(V.messages) do if tostring(m.text):find("Welcome to Two Rivers", 1, true) then said = true end end
    test("the trigger's welcome", said)
    test("still no script errors", #V.errors == 0, V.errors[1] and V.errors[1].message)
    os.remove(P2)
end
os.remove(P)
-- }}}

-- {{{ A custom map, and the command line
test_section("A custom map; the command line")
do
    local P3 = os.tmpname() .. ".w3x"
    assert(new_map.create(P3, { name = "Empty", melee = false, width = 32, height = 32, tileset = "N",
                                players = { { race = "nightelf" } } }))
    local g, V = play(P3, 0)
    local owned = 0
    for _, u in ipairs(g.units) do if u.player == 0 then owned = owned + 1 end end
    test("no melee start: nothing owned", owned == 0 and #V.errors == 0)
    local a = mpq.open(P3)
    local t = require("parsers.w3e").parse(a:extract("war3map.w3e"))
    a:close()
    test("Northrend's ground", t.tileset_code == "N" and t.ground_tilesets[1] == "Ndrt")
    os.remove(P3)
    local P4 = os.tmpname() .. ".w3x"
    local out = io.popen('cd "' .. DIR .. '" && luajit src/editor/new_map.lua "' .. P4
        .. '" --name "Cli Map" --size 48 --players human,nightelf:computer 2>&1'):read("*a")
    local w = require("mpq.map_wrapper").read(P4)
    test("made from the command line", out:find("made", 1, true) and w and w.map_name == "Cli Map" and w.max_players == 2, out)
    os.remove(P4)
end
-- }}}

print(string.format("\n%d/%d tests passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
