--[[
Test suite for Player State Management (Issue 407)

Tests player initialization, queries, and state management.
]]

-- {{{ Setup paths
local script_dir = debug.getinfo(1, "S").source:match("@(.*/)")
local project_root = script_dir:match("(.*/)[^/]+/[^/]+/$") or script_dir .. "../../"
package.path = project_root .. "src/?.lua;" .. package.path
-- }}}

-- {{{ Require modules
local player = require("runtime.player")
-- }}}

-- {{{ Test helpers
local tests_run = 0
local tests_passed = 0

local function test(name, fn)
    tests_run = tests_run + 1
    player.reset()  -- Clean state for each test
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print(string.format("  [PASS] %s", name))
    else
        print(string.format("  [FAIL] %s", name))
        print(string.format("         %s", err))
    end
end

local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", msg or "Mismatch", tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true")
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "Expected false")
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s", msg or "Expected nil", tostring(value)))
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil value")
    end
end
-- }}}

-- {{{ Constants Tests
print("-- Constants Tests --")

test("PLAYER_TYPE constants defined", function()
    assert_eq("human", player.PLAYER_TYPE.HUMAN, "HUMAN")
    assert_eq("computer", player.PLAYER_TYPE.COMPUTER, "COMPUTER")
    assert_eq("neutral", player.PLAYER_TYPE.NEUTRAL, "NEUTRAL")
    assert_eq("rescuable", player.PLAYER_TYPE.RESCUABLE, "RESCUABLE")
end)

test("PLAYER_STATE constants defined", function()
    assert_eq("active", player.PLAYER_STATE.ACTIVE, "ACTIVE")
    assert_eq("defeated", player.PLAYER_STATE.DEFEATED, "DEFEATED")
    assert_eq("victorious", player.PLAYER_STATE.VICTORIOUS, "VICTORIOUS")
    assert_eq("left", player.PLAYER_STATE.LEFT, "LEFT")
end)

test("RACE constants defined", function()
    assert_eq("human", player.RACE.HUMAN, "HUMAN")
    assert_eq("orc", player.RACE.ORC, "ORC")
    assert_eq("undead", player.RACE.UNDEAD, "UNDEAD")
    assert_eq("nightelf", player.RACE.NIGHTELF, "NIGHTELF")
    assert_eq("random", player.RACE.RANDOM, "RANDOM")
    assert_eq("neutral", player.RACE.NEUTRAL, "NEUTRAL")
end)

test("NEUTRAL_SLOT is 15", function()
    assert_eq(15, player.NEUTRAL_SLOT, "NEUTRAL_SLOT")
end)

test("MAX_PLAYERS is 16", function()
    assert_eq(16, player.MAX_PLAYERS, "MAX_PLAYERS")
end)
-- }}}

-- {{{ Empty Initialization Tests
print("\n-- Empty Initialization Tests --")

test("init with empty w3i creates default player + neutral", function()
    player.init_from_w3i({})
    assert_eq(2, player.count(), "player count")
    assert_not_nil(player.get(0), "player 0 exists")
    assert_not_nil(player.get(15), "neutral exists")
end)

test("init with nil creates default player + neutral", function()
    player.init_from_w3i(nil)
    assert_eq(2, player.count(), "player count")
    assert_not_nil(player.get(0), "player 0 exists")
    assert_not_nil(player.get(15), "neutral exists")
end)

test("default player has correct values", function()
    player.init_from_w3i(nil)
    local p = player.get(0)
    assert_eq(0, p.slot, "slot")
    assert_eq("Player 1", p.name, "name")
    assert_eq("human", p.type, "type")
    assert_eq("human", p.race, "race")
    assert_eq("active", p.state, "state")
end)

test("neutral player has correct values", function()
    player.init_from_w3i(nil)
    local n = player.get(15)
    assert_eq(15, n.slot, "slot")
    assert_eq("Neutral", n.name, "name")
    assert_eq("neutral", n.type, "type")
    assert_eq("neutral", n.race, "race")
    assert_eq(-1, n.team, "team")
end)
-- }}}

-- {{{ W3I Initialization Tests
print("\n-- W3I Initialization Tests --")

test("init from w3i with players", function()
    local w3i = {
        players = {
            { number = 0, name = "Alice", type = "human", race = "human" },
            { number = 1, name = "Bob", type = "computer", race = "orc" },
        }
    }
    player.init_from_w3i(w3i)
    assert_eq(3, player.count(), "player count (2 + neutral)")

    local p0 = player.get(0)
    assert_eq("Alice", p0.name, "p0 name")
    assert_eq("human", p0.type, "p0 type")
    assert_eq("human", p0.race, "p0 race")

    local p1 = player.get(1)
    assert_eq("Bob", p1.name, "p1 name")
    assert_eq("computer", p1.type, "p1 type")
    assert_eq("orc", p1.race, "p1 race")
end)

test("init from w3i with start positions", function()
    local w3i = {
        players = {
            { number = 0, name = "Test", type = "human", race = "human", start_x = 100.5, start_y = 200.5 },
        }
    }
    player.init_from_w3i(w3i)

    local p = player.get(0)
    assert_eq(100.5, p.start_x, "start_x")
    assert_eq(200.5, p.start_y, "start_y")
end)

test("init from w3i with forces sets teams", function()
    local w3i = {
        players = {
            { number = 0, name = "P1", type = "human", race = "human" },
            { number = 1, name = "P2", type = "human", race = "orc" },
            { number = 2, name = "P3", type = "human", race = "undead" },
        },
        forces = {
            { number = 1, name = "Team A", players = {0, 1} },
            { number = 2, name = "Team B", players = {2} },
        }
    }
    player.init_from_w3i(w3i)

    assert_eq(1, player.get(0).team, "p0 team")
    assert_eq(1, player.get(1).team, "p1 team")
    assert_eq(2, player.get(2).team, "p2 team")
    assert_eq("Team A", player.get(0).team_name, "p0 team_name")
    assert_eq("Team B", player.get(2).team_name, "p2 team_name")
end)

test("race mapping from strings", function()
    local w3i = {
        players = {
            { number = 0, name = "H", type = "human", race = "human" },
            { number = 1, name = "O", type = "human", race = "orc" },
            { number = 2, name = "U", type = "human", race = "undead" },
            { number = 3, name = "N", type = "human", race = "night_elf" },
            { number = 4, name = "R", type = "human", race = "random" },
        }
    }
    player.init_from_w3i(w3i)

    assert_eq("human", player.get(0).race, "human")
    assert_eq("orc", player.get(1).race, "orc")
    assert_eq("undead", player.get(2).race, "undead")
    assert_eq("nightelf", player.get(3).race, "nightelf")
    assert_eq("random", player.get(4).race, "random")
end)

test("type mapping from strings", function()
    local w3i = {
        players = {
            { number = 0, name = "H", type = "human", race = "human" },
            { number = 1, name = "C", type = "computer", race = "human" },
            { number = 2, name = "N", type = "neutral", race = "neutral" },
            { number = 3, name = "R", type = "rescuable", race = "human" },
        }
    }
    player.init_from_w3i(w3i)

    assert_eq("human", player.get(0).type, "human")
    assert_eq("computer", player.get(1).type, "computer")
    assert_eq("neutral", player.get(2).type, "neutral")
    assert_eq("rescuable", player.get(3).type, "rescuable")
end)

test("race mapping from integers", function()
    assert_eq("human", player._map_race(0), "0 -> human")
    assert_eq("orc", player._map_race(1), "1 -> orc")
    assert_eq("undead", player._map_race(2), "2 -> undead")
    assert_eq("nightelf", player._map_race(3), "3 -> nightelf")
    assert_eq("random", player._map_race(4), "4 -> random")
end)
-- }}}

-- {{{ Manual Initialization Tests
print("\n-- Manual Initialization Tests --")

test("init_manual creates players", function()
    player.init_manual({
        { slot = 0, name = "Test1", type = "human", race = "orc", team = 1 },
        { slot = 1, name = "Test2", type = "computer", race = "undead", team = 2 },
    })

    assert_eq(3, player.count(), "count (2 + neutral)")
    assert_eq("Test1", player.get(0).name, "p0 name")
    assert_eq("orc", player.get(0).race, "p0 race")
    assert_eq(1, player.get(0).team, "p0 team")
end)

test("init_manual ensures neutral", function()
    player.init_manual({
        { slot = 0, name = "Test" },
    })

    assert_not_nil(player.get(15), "neutral exists")
    assert_eq(-1, player.get(15).team, "neutral team")
end)

test("init_manual with color", function()
    player.init_manual({
        { slot = 0, name = "Test", color = 5 },
    })

    assert_eq(5, player.get(0).color, "custom color")
end)
-- }}}

-- {{{ Basic Query Tests
print("\n-- Basic Query Tests --")

test("get returns nil for missing slot", function()
    player.init_from_w3i(nil)
    assert_nil(player.get(7), "slot 7 not found")
end)

test("exists returns correct boolean", function()
    player.init_from_w3i(nil)
    assert_true(player.exists(0), "slot 0 exists")
    assert_true(player.exists(15), "slot 15 exists")
    assert_false(player.exists(7), "slot 7 not exists")
end)

test("count returns correct number", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
        { slot = 2 },
    })
    assert_eq(4, player.count(), "3 players + neutral")
end)

test("get_all returns all players", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })
    local all = player.get_all()
    assert_eq(3, #all, "3 players total")
end)
-- }}}

-- {{{ Query by Type Tests
print("\n-- Query by Type Tests --")

test("get_by_type human", function()
    player.init_manual({
        { slot = 0, type = "human" },
        { slot = 1, type = "computer" },
        { slot = 2, type = "human" },
    })
    local humans = player.get_by_type("human")
    assert_eq(2, #humans, "2 humans")
end)

test("get_by_type computer", function()
    player.init_manual({
        { slot = 0, type = "human" },
        { slot = 1, type = "computer" },
        { slot = 2, type = "computer" },
    })
    local computers = player.get_by_type("computer")
    assert_eq(2, #computers, "2 computers")
end)

test("get_humans convenience", function()
    player.init_manual({
        { slot = 0, type = "human" },
        { slot = 1, type = "computer" },
    })
    local humans = player.get_humans()
    assert_eq(1, #humans, "1 human")
    assert_eq("human", humans[1].type, "is human")
end)

test("get_computers convenience", function()
    player.init_manual({
        { slot = 0, type = "human" },
        { slot = 1, type = "computer" },
    })
    local computers = player.get_computers()
    assert_eq(1, #computers, "1 computer")
    assert_eq("computer", computers[1].type, "is computer")
end)

test("get_neutral returns slot 15", function()
    player.init_from_w3i(nil)
    local n = player.get_neutral()
    assert_not_nil(n, "neutral exists")
    assert_eq(15, n.slot, "neutral is slot 15")
end)
-- }}}

-- {{{ Query by Team Tests
print("\n-- Query by Team Tests --")

test("get_by_team returns matching players", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 2 },
        { slot = 2, team = 1 },
    })

    local team1 = player.get_by_team(1)
    assert_eq(2, #team1, "2 on team 1")

    local team2 = player.get_by_team(2)
    assert_eq(1, #team2, "1 on team 2")
end)

test("get_by_team returns empty for missing team", function()
    player.init_manual({
        { slot = 0, team = 1 },
    })
    local team99 = player.get_by_team(99)
    assert_eq(0, #team99, "no team 99")
end)
-- }}}

-- {{{ Active Player Tests
print("\n-- Active Player Tests --")

test("get_active returns only active players", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
        { slot = 2 },
    })

    -- Manually set some as defeated
    player.get(1).state = "defeated"

    local active = player.get_active()
    -- slot 0, 2, and neutral (15) should be active
    assert_eq(3, #active, "3 active (0, 2, neutral)")
end)

test("all players start as active", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    assert_eq("active", player.get(0).state, "p0 active")
    assert_eq("active", player.get(1).state, "p1 active")
    assert_eq("active", player.get(15).state, "neutral active")
end)
-- }}}

-- {{{ Local Player Tests
print("\n-- Local Player Tests --")

test("default local player is slot 0", function()
    player.init_from_w3i(nil)
    assert_eq(0, player.get_local_slot(), "local slot")
    assert_eq(player.get(0), player.get_local(), "local player")
end)

test("set_local changes local player", function()
    player.init_manual({
        { slot = 0, name = "P1" },
        { slot = 1, name = "P2" },
    })

    player.set_local(1)
    assert_eq(1, player.get_local_slot(), "local slot")
    assert_eq("P2", player.get_local().name, "local name")
end)
-- }}}

-- {{{ Iterator Tests
print("\n-- Iterator Tests --")

test("iter iterates all players", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    local count = 0
    local slots = {}
    for slot, p in player.iter() do
        count = count + 1
        slots[slot] = true
    end

    assert_eq(3, count, "3 players iterated")
    assert_true(slots[0], "slot 0 seen")
    assert_true(slots[1], "slot 1 seen")
    assert_true(slots[15], "slot 15 seen")
end)
-- }}}

-- {{{ Reset Tests
print("\n-- Reset Tests --")

test("reset clears all players", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })
    assert_eq(3, player.count(), "3 before reset")

    player.reset()
    assert_eq(0, player.count(), "0 after reset")
end)

test("reset clears local player", function()
    player.init_manual({ { slot = 0 }, { slot = 1 } })
    player.set_local(1)
    player.reset()
    assert_eq(0, player.get_local_slot(), "local reset to 0")
end)
-- }}}

-- {{{ Edge Cases
print("\n-- Edge Cases --")

test("can override neutral player in w3i", function()
    local w3i = {
        players = {
            { number = 15, name = "Custom Neutral", type = "neutral", race = "neutral" },
        }
    }
    player.init_from_w3i(w3i)

    local n = player.get(15)
    assert_eq("Custom Neutral", n.name, "custom neutral name")
    assert_eq(-1, n.team, "neutral still has team -1")
end)

test("player default color matches slot", function()
    player.init_manual({
        { slot = 5, name = "Test" },
    })
    assert_eq(5, player.get(5).color, "color matches slot")
end)

test("empty forces array handled", function()
    local w3i = {
        players = {
            { number = 0, name = "P1", type = "human", race = "human" },
        },
        forces = {}
    }
    player.init_from_w3i(w3i)
    assert_eq(0, player.get(0).team, "default team 0")
end)
-- }}}

-- {{{ Summary
print(string.format("\n=== Results: %d/%d tests passed ===", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print(string.format("FAILED: %d tests failed", tests_run - tests_passed))
    os.exit(1)
end
-- }}}
