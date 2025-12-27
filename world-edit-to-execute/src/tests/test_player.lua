--[[
Test suite for Player State Management (Issue 407)

Tests player initialization, queries, state management, alliances,
state transitions, and victory conditions.
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

-- {{{ Alliance Constants Tests
print("\n-- Alliance Constants Tests --")

test("ALLIANCE_FLAG constants defined", function()
    assert_eq("passive", player.ALLIANCE_FLAG.PASSIVE, "PASSIVE")
    assert_eq("shared_vision", player.ALLIANCE_FLAG.SHARED_VISION, "SHARED_VISION")
    assert_eq("shared_control", player.ALLIANCE_FLAG.SHARED_CONTROL, "SHARED_CONTROL")
    assert_eq("shared_victory", player.ALLIANCE_FLAG.SHARED_VICTORY, "SHARED_VICTORY")
    assert_eq("shared_xp", player.ALLIANCE_FLAG.SHARED_XP, "SHARED_XP")
end)
-- }}}

-- {{{ Alliance Set/Get Tests
print("\n-- Alliance Set/Get Tests --")

test("set_alliance correctly sets flag", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    local ok = player.set_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE, true)
    assert_true(ok, "set_alliance returns true")
    assert_true(player.get_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE), "flag is set")
end)

test("get_alliance returns false for unset flags", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    assert_false(player.get_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE), "unset flag")
end)

test("set_alliance returns false for missing source", function()
    player.init_manual({
        { slot = 0 },
    })

    local ok, err = player.set_alliance(5, 0, player.ALLIANCE_FLAG.PASSIVE, true)
    assert_false(ok, "returns false")
    assert_eq("Source player not found", err, "error message")
end)

test("set_alliance returns false for missing target", function()
    player.init_manual({
        { slot = 0 },
    })

    local ok, err = player.set_alliance(0, 5, player.ALLIANCE_FLAG.PASSIVE, true)
    assert_false(ok, "returns false")
    assert_eq("Target player not found", err, "error message")
end)

test("alliances are asymmetric by default", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    player.set_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE, true)

    assert_true(player.get_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE), "0->1 set")
    assert_false(player.get_alliance(1, 0, player.ALLIANCE_FLAG.PASSIVE), "1->0 not set")
end)

test("set_mutual_alliance sets both directions", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    player.set_mutual_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE, true)

    assert_true(player.get_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE), "0->1 set")
    assert_true(player.get_alliance(1, 0, player.ALLIANCE_FLAG.PASSIVE), "1->0 set")
end)

test("set_team_alliance sets all pairs", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
        { slot = 2 },
    })

    player.set_team_alliance({0, 1, 2}, player.ALLIANCE_FLAG.SHARED_VISION, true)

    assert_true(player.get_alliance(0, 1, player.ALLIANCE_FLAG.SHARED_VISION), "0->1")
    assert_true(player.get_alliance(0, 2, player.ALLIANCE_FLAG.SHARED_VISION), "0->2")
    assert_true(player.get_alliance(1, 0, player.ALLIANCE_FLAG.SHARED_VISION), "1->0")
    assert_true(player.get_alliance(1, 2, player.ALLIANCE_FLAG.SHARED_VISION), "1->2")
    assert_true(player.get_alliance(2, 0, player.ALLIANCE_FLAG.SHARED_VISION), "2->0")
    assert_true(player.get_alliance(2, 1, player.ALLIANCE_FLAG.SHARED_VISION), "2->1")
end)
-- }}}

-- {{{ Alliance Convenience Tests
print("\n-- Alliance Convenience Tests --")

test("is_ally returns true for mutual passive", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    player.set_mutual_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE, true)
    assert_true(player.is_ally(0, 1), "0 ally of 1")
    assert_true(player.is_ally(1, 0), "1 ally of 0")
end)

test("is_ally returns false if only one direction", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    player.set_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE, true)
    -- Only 0->1, not 1->0
    assert_false(player.is_ally(0, 1), "not mutual")
    assert_false(player.is_ally(1, 0), "not mutual (reverse)")
end)

test("is_ally returns true for same slot", function()
    player.init_manual({
        { slot = 0 },
    })

    assert_true(player.is_ally(0, 0), "self is always ally")
end)

test("is_enemy is inverse of is_ally", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    -- No alliances set - enemies
    assert_true(player.is_enemy(0, 1), "enemies by default")

    -- Set mutual alliance
    player.set_mutual_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE, true)
    assert_false(player.is_enemy(0, 1), "not enemies after alliance")
end)

test("has_vision checks correct direction", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    -- Player 1 shares vision with player 0 (so 0 can see 1's units)
    player.set_alliance(1, 0, player.ALLIANCE_FLAG.SHARED_VISION, true)

    assert_true(player.has_vision(0, 1), "0 can see 1")
    assert_false(player.has_vision(1, 0), "1 cannot see 0")
end)

test("has_vision true for same slot", function()
    player.init_manual({
        { slot = 0 },
    })

    assert_true(player.has_vision(0, 0), "can see own units")
end)

test("can_control checks correct direction", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    -- Player 1 shares control with player 0 (so 0 can control 1's units)
    player.set_alliance(1, 0, player.ALLIANCE_FLAG.SHARED_CONTROL, true)

    assert_true(player.can_control(0, 1), "0 can control 1")
    assert_false(player.can_control(1, 0), "1 cannot control 0")
end)

test("can_control true for same slot", function()
    player.init_manual({
        { slot = 0 },
    })

    assert_true(player.can_control(0, 0), "can control own units")
end)
-- }}}

-- {{{ Alliance Query Tests
print("\n-- Alliance Query Tests --")

test("get_allies returns correct list", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
        { slot = 2 },
    })

    player.set_mutual_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE, true)
    -- Slot 2 not allied with 0

    local allies = player.get_allies(0)
    -- Should include: 0 (self), 1 (ally)
    assert_eq(2, #allies, "2 allies (self + 1)")
end)

test("get_enemies excludes neutrals", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    -- No alliances - everyone is enemy except neutral
    local enemies = player.get_enemies(0)
    -- Should include slot 1 but not neutral (15)
    local found_1 = false
    local found_15 = false
    for _, p in ipairs(enemies) do
        if p.slot == 1 then found_1 = true end
        if p.slot == 15 then found_15 = true end
    end
    assert_true(found_1, "slot 1 is enemy")
    assert_false(found_15, "neutral excluded")
end)
-- }}}

-- {{{ Alliance from W3I Tests
print("\n-- Alliance from W3I Tests --")

test("init_from_w3i applies allied flag", function()
    local w3i = {
        players = {
            { number = 0, name = "P1", type = "human", race = "human" },
            { number = 1, name = "P2", type = "human", race = "orc" },
        },
        forces = {
            { number = 1, name = "Team", players = {0, 1}, flags = { allied = true } },
        }
    }
    player.init_from_w3i(w3i)

    assert_true(player.is_ally(0, 1), "0 and 1 are allies")
    assert_true(player.get_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE), "0->1 passive")
    assert_true(player.get_alliance(1, 0, player.ALLIANCE_FLAG.PASSIVE), "1->0 passive")
end)

test("init_from_w3i applies shared_vision flag", function()
    local w3i = {
        players = {
            { number = 0, name = "P1", type = "human", race = "human" },
            { number = 1, name = "P2", type = "human", race = "orc" },
        },
        forces = {
            { number = 1, name = "Team", players = {0, 1}, flags = { share_vision = true } },
        }
    }
    player.init_from_w3i(w3i)

    assert_true(player.has_vision(0, 1), "0 sees 1")
    assert_true(player.has_vision(1, 0), "1 sees 0")
end)

test("init_from_w3i applies allied_victory flag", function()
    local w3i = {
        players = {
            { number = 0, name = "P1", type = "human", race = "human" },
            { number = 1, name = "P2", type = "human", race = "orc" },
        },
        forces = {
            { number = 1, name = "Team", players = {0, 1}, flags = { allied_victory = true } },
        }
    }
    player.init_from_w3i(w3i)

    assert_true(player.get_alliance(0, 1, player.ALLIANCE_FLAG.SHARED_VICTORY), "0->1 victory")
    assert_true(player.get_alliance(1, 0, player.ALLIANCE_FLAG.SHARED_VICTORY), "1->0 victory")
end)

test("init_from_w3i multiple forces independent", function()
    local w3i = {
        players = {
            { number = 0, name = "P1", type = "human", race = "human" },
            { number = 1, name = "P2", type = "human", race = "orc" },
            { number = 2, name = "P3", type = "human", race = "undead" },
            { number = 3, name = "P4", type = "human", race = "nightelf" },
        },
        forces = {
            { number = 1, name = "Team A", players = {0, 1}, flags = { allied = true } },
            { number = 2, name = "Team B", players = {2, 3}, flags = { allied = true } },
        }
    }
    player.init_from_w3i(w3i)

    -- Team A allies
    assert_true(player.is_ally(0, 1), "0 ally with 1")
    -- Team B allies
    assert_true(player.is_ally(2, 3), "2 ally with 3")
    -- Cross-team enemies
    assert_true(player.is_enemy(0, 2), "0 enemy of 2")
    assert_true(player.is_enemy(1, 3), "1 enemy of 3")
end)
-- }}}

-- {{{ Alliance Event Hook Tests
print("\n-- Alliance Event Hook Tests --")

test("alliance change fires event hook", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    local events = {}
    player._on_alliance_changed = function(from, to, flag, value)
        events[#events + 1] = { from = from, to = to, flag = flag, value = value }
    end

    player.set_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE, true)

    assert_eq(1, #events, "one event fired")
    assert_eq(0, events[1].from, "from slot")
    assert_eq(1, events[1].to, "to slot")
    assert_eq(player.ALLIANCE_FLAG.PASSIVE, events[1].flag, "flag")
    assert_true(events[1].value, "value")

    -- Cleanup
    player._on_alliance_changed = nil
end)

test("no event for unchanged alliance", function()
    player.init_manual({
        { slot = 0 },
        { slot = 1 },
    })

    local event_count = 0
    player._on_alliance_changed = function(from, to, flag, value)
        event_count = event_count + 1
    end

    -- Set to true
    player.set_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE, true)
    assert_eq(1, event_count, "first set fires")

    -- Set to true again (no change)
    player.set_alliance(0, 1, player.ALLIANCE_FLAG.PASSIVE, true)
    assert_eq(1, event_count, "no event for unchanged")

    -- Cleanup
    player._on_alliance_changed = nil
end)
-- }}}

-- {{{ State Transition Tests (407d)
print("\n-- State Transition Tests --")

test("set_state changes state correctly", function()
    player.init_manual({
        { slot = 0 },
    })

    local ok = player.set_state(0, player.PLAYER_STATE.DEFEATED)
    assert_true(ok, "set_state returns true")
    assert_eq("defeated", player.get(0).state, "state changed")
end)

test("set_state fires player_state_changed event", function()
    player.init_manual({
        { slot = 0 },
    })

    local events = {}
    player.on("player_state_changed", function(slot, old_state, new_state)
        events[#events + 1] = { slot = slot, old = old_state, new = new_state }
    end)

    player.set_state(0, player.PLAYER_STATE.DEFEATED)

    assert_eq(1, #events, "one event fired")
    assert_eq(0, events[1].slot, "correct slot")
    assert_eq("active", events[1].old, "old state")
    assert_eq("defeated", events[1].new, "new state")
end)

test("set_state prevents transition from terminal states", function()
    player.init_manual({
        { slot = 0 },
    })

    player.set_state(0, player.PLAYER_STATE.DEFEATED)

    local ok, err = player.set_state(0, player.PLAYER_STATE.ACTIVE)
    assert_false(ok, "returns false")
    assert_true(err:find("terminal state"), "error mentions terminal")
end)

test("set_state no change for same state", function()
    player.init_manual({
        { slot = 0 },
    })

    local event_count = 0
    player.on("player_state_changed", function()
        event_count = event_count + 1
    end)

    local ok = player.set_state(0, player.PLAYER_STATE.ACTIVE)
    assert_true(ok, "returns true for no-op")
    assert_eq(0, event_count, "no event for same state")
end)

test("set_state rejects invalid state", function()
    player.init_manual({
        { slot = 0 },
    })

    local ok, err = player.set_state(0, "invalid")
    assert_false(ok, "returns false")
    assert_true(err:find("Invalid state"), "error mentions invalid")
end)
-- }}}

-- {{{ Defeat Function Tests
print("\n-- Defeat Function Tests --")

test("defeat marks player as defeated", function()
    player.init_manual({
        { slot = 0 },
    })

    local ok = player.defeat(0)
    assert_true(ok, "defeat returns true")
    assert_eq("defeated", player.get(0).state, "state is defeated")
end)

test("defeat fires player_defeated event", function()
    player.init_manual({
        { slot = 0 },
    })

    local defeated_slot = nil
    player.on("player_defeated", function(slot)
        defeated_slot = slot
    end)

    player.defeat(0)
    assert_eq(0, defeated_slot, "correct slot in event")
end)

test("defeat fails for non-active player", function()
    player.init_manual({
        { slot = 0 },
    })

    player.defeat(0)  -- First defeat succeeds
    local ok, err = player.defeat(0)  -- Second fails
    assert_false(ok, "returns false")
    assert_true(err:find("not active"), "error mentions not active")
end)

test("defeat calls victory condition check", function()
    player.init_manual({
        { slot = 0 },
    })

    local check_called = false
    player._check_victory_conditions = function()
        check_called = true
    end

    player.defeat(0)
    assert_true(check_called, "victory check called")
end)

test("defeat handles units hook", function()
    player.init_manual({
        { slot = 0 },
    })

    local handle_called = false
    local handle_slot = nil
    local handle_options = nil
    player._handle_defeated_units = function(slot, options)
        handle_called = true
        handle_slot = slot
        handle_options = options
    end

    player.defeat(0, { destroy_units = true })

    assert_true(handle_called, "handle called")
    assert_eq(0, handle_slot, "correct slot")
    assert_true(handle_options.destroy_units, "options passed")
end)
-- }}}

-- {{{ Victory Function Tests
print("\n-- Victory Function Tests --")

test("set_victorious marks player as victorious", function()
    player.init_manual({
        { slot = 0 },
    })

    local ok = player.set_victorious(0)
    assert_true(ok, "returns true")
    assert_eq("victorious", player.get(0).state, "state is victorious")
end)

test("set_victorious fires player_victorious event", function()
    player.init_manual({
        { slot = 0 },
    })

    local victorious_slot = nil
    player.on("player_victorious", function(slot)
        victorious_slot = slot
    end)

    player.set_victorious(0)
    assert_eq(0, victorious_slot, "correct slot in event")
end)

test("set_victorious fails for defeated player", function()
    player.init_manual({
        { slot = 0 },
    })

    player.defeat(0)
    local ok, err = player.set_victorious(0)
    assert_false(ok, "returns false")
    assert_true(err:find("defeated"), "error mentions defeated")
end)

test("set_victorious idempotent", function()
    player.init_manual({
        { slot = 0 },
    })

    player.set_victorious(0)
    local ok = player.set_victorious(0)  -- Already victorious
    assert_true(ok, "returns true for already victorious")
end)
-- }}}

-- {{{ Leave Function Tests
print("\n-- Leave Function Tests --")

test("leave marks player as left", function()
    player.init_manual({
        { slot = 0 },
    })

    local ok = player.leave(0)
    assert_true(ok, "returns true")
    assert_eq("left", player.get(0).state, "state is left")
end)

test("leave fires player_left event", function()
    player.init_manual({
        { slot = 0 },
    })

    local left_slot = nil
    player.on("player_left", function(slot)
        left_slot = slot
    end)

    player.leave(0)
    assert_eq(0, left_slot, "correct slot in event")
end)

test("leave fails for non-active player", function()
    player.init_manual({
        { slot = 0 },
    })

    player.defeat(0)
    local ok, err = player.leave(0)
    assert_false(ok, "returns false")
    assert_true(err:find("not active"), "error mentions not active")
end)

test("leave handles units hook", function()
    player.init_manual({
        { slot = 0 },
    })

    local handle_called = false
    player._handle_left_units = function(slot, options)
        handle_called = true
    end

    player.leave(0)
    assert_true(handle_called, "handle called")
end)
-- }}}

-- {{{ Convenience State Check Tests
print("\n-- Convenience State Check Tests --")

test("is_active returns true for active player", function()
    player.init_manual({
        { slot = 0 },
    })

    assert_true(player.is_active(0), "active player")
end)

test("is_active returns false for defeated player", function()
    player.init_manual({
        { slot = 0 },
    })

    player.defeat(0)
    assert_false(player.is_active(0), "defeated player not active")
end)

test("is_active returns false for missing player", function()
    player.init_manual({})

    assert_false(player.is_active(5), "missing player not active")
end)

test("is_playing returns true for active player", function()
    player.init_manual({
        { slot = 0 },
    })

    assert_true(player.is_playing(0), "active player playing")
end)

test("is_playing returns true for victorious player", function()
    player.init_manual({
        { slot = 0 },
    })

    player.set_victorious(0)
    assert_true(player.is_playing(0), "victorious player playing")
end)

test("is_playing returns false for defeated player", function()
    player.init_manual({
        { slot = 0 },
    })

    player.defeat(0)
    assert_false(player.is_playing(0), "defeated player not playing")
end)

test("is_playing returns false for left player", function()
    player.init_manual({
        { slot = 0 },
    })

    player.leave(0)
    assert_false(player.is_playing(0), "left player not playing")
end)
-- }}}

-- {{{ Event System Tests
print("\n-- Event System Tests --")

test("on registers multiple callbacks", function()
    player.init_manual({
        { slot = 0 },
    })

    local count = 0
    player.on("player_defeated", function() count = count + 1 end)
    player.on("player_defeated", function() count = count + 1 end)

    player.defeat(0)
    assert_eq(2, count, "both callbacks called")
end)

test("clear_events removes callbacks", function()
    player.init_manual({
        { slot = 0 },
    })

    local count = 0
    player.on("player_defeated", function() count = count + 1 end)
    player.clear_events()
    player.defeat(0)

    assert_eq(0, count, "callback not called after clear")
end)

test("reset clears events", function()
    player.init_manual({
        { slot = 0 },
    })

    local count = 0
    player.on("player_defeated", function() count = count + 1 end)
    player.reset()
    player.init_manual({ { slot = 0 } })
    player.defeat(0)

    assert_eq(0, count, "callback not called after reset")
end)
-- }}}

-- {{{ Victory Conditions Tests (407e)
print("\n-- Victory Conditions Tests --")

test("check_victory_conditions does nothing before game start", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 2 },
    })

    -- Defeat player 1, leaving only team 1
    player.get(1).state = "defeated"

    -- Game not started, so no victory should be declared
    local ended = player.check_victory_conditions()
    assert_false(ended, "game not ended")
    assert_false(player.is_game_ended(), "is_game_ended false")
end)

test("check_victory_conditions does nothing after game end", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 2 },
    })

    player.start_game()
    player.get(1).state = "defeated"
    player.check_victory_conditions()  -- This ends the game

    -- Try to check again
    local event_count = 0
    player.on("game_over", function() event_count = event_count + 1 end)

    local ended = player.check_victory_conditions()
    assert_false(ended, "check returns false")
    assert_eq(0, event_count, "no duplicate event")
end)

test("single team remaining triggers victory", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 2 },
    })

    player.start_game()
    player.get(1).state = "defeated"  -- Team 2 eliminated

    local ended = player.check_victory_conditions()

    assert_true(ended, "game ended")
    assert_true(player.is_game_ended(), "is_game_ended true")
    local result = player.get_game_result()
    assert_eq(1, result.winning_team, "team 1 wins")
    assert_eq("elimination", result.end_reason, "elimination reason")
end)

test("victorious players marked correctly", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 1 },  -- Same team
        { slot = 2, team = 2 },
    })

    player.start_game()
    player.get(2).state = "defeated"  -- Team 2 eliminated

    player.check_victory_conditions()

    assert_eq("victorious", player.get(0).state, "p0 victorious")
    assert_eq("victorious", player.get(1).state, "p1 victorious")
end)

test("no teams remaining triggers draw", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 2 },
    })

    player.start_game()
    player.get(0).state = "defeated"
    player.get(1).state = "defeated"

    local ended = player.check_victory_conditions()

    assert_true(ended, "game ended")
    local result = player.get_game_result()
    assert_nil(result.winning_team, "no winner")
    assert_eq("draw", result.end_reason, "draw reason")
end)

test("force_victory ends game immediately", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 2 },
    })

    local ok = player.force_victory(0, false)

    assert_true(ok, "force_victory returns true")
    assert_true(player.is_game_ended(), "game ended")
    assert_eq("victorious", player.get(0).state, "winner victorious")
end)

test("force_victory marks losers as defeated", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 2 },
    })

    player.force_victory(0, false)

    assert_eq("defeated", player.get(1).state, "loser defeated")
end)

test("force_victory team mode", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 1 },
        { slot = 2, team = 2 },
    })

    player.force_victory(1, true)  -- Team 1 wins

    assert_eq("victorious", player.get(0).state, "team member victorious")
    assert_eq("victorious", player.get(1).state, "team member victorious")
    assert_eq("defeated", player.get(2).state, "other team defeated")
end)

test("force_victory fails if game ended", function()
    player.init_manual({
        { slot = 0, team = 1 },
    })

    player.force_victory(0, false)
    local ok, err = player.force_victory(0, false)

    assert_false(ok, "returns false")
    assert_true(err:find("already ended"), "error message")
end)

test("force_defeat triggers normal defeat flow", function()
    player.init_manual({
        { slot = 0 },
    })

    local ok = player.force_defeat(0)

    assert_true(ok, "returns true")
    assert_eq("defeated", player.get(0).state, "player defeated")
end)

test("defeat_team defeats all players on team", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 1 },
        { slot = 2, team = 2 },
    })

    local count = player.defeat_team(1)

    assert_eq(2, count, "2 players defeated")
    assert_eq("defeated", player.get(0).state, "p0 defeated")
    assert_eq("defeated", player.get(1).state, "p1 defeated")
    assert_eq("active", player.get(2).state, "p2 still active")
end)

test("defeat_team triggers victory check", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 2 },
    })

    player.start_game()
    player.defeat_team(1)

    assert_true(player.is_game_ended(), "game ended")
    assert_eq("victorious", player.get(1).state, "remaining player wins")
end)

test("game_over event fires with correct info", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 2 },
    })

    local event_data = nil
    player.on("game_over", function(data)
        event_data = data
    end)

    player.start_game()
    player.get(1).state = "defeated"
    player.check_victory_conditions()

    assert_not_nil(event_data, "event fired")
    assert_eq(1, event_data.winner, "correct winner")
    assert_eq("elimination", event_data.reason, "correct reason")
end)

test("game_over event fires on force_victory", function()
    player.init_manual({
        { slot = 0, team = 1 },
    })

    local event_data = nil
    player.on("game_over", function(data)
        event_data = data
    end)

    player.force_victory(0, false)

    assert_not_nil(event_data, "event fired")
    assert_eq("custom", event_data.reason, "custom reason")
end)

test("get_winning_players returns victorious list", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 1 },
        { slot = 2, team = 2 },
    })

    player.start_game()
    player.get(2).state = "defeated"
    player.check_victory_conditions()

    local winners = player.get_winning_players()
    assert_eq(2, #winners, "2 winners")
end)

test("get_winning_players empty before game end", function()
    player.init_manual({
        { slot = 0, team = 1 },
    })

    local winners = player.get_winning_players()
    assert_eq(0, #winners, "no winners before end")
end)

test("get_game_result returns correct state", function()
    player.init_manual({
        { slot = 0, team = 1 },
    })

    local result = player.get_game_result()
    assert_false(result.ended, "not ended initially")
    assert_nil(result.winning_team, "no winner")
    assert_nil(result.end_reason, "no reason")

    player.force_victory(0, false)

    result = player.get_game_result()
    assert_true(result.ended, "ended")
    assert_eq(1, result.winning_team, "winner team")
    assert_eq("custom", result.end_reason, "reason")
end)

test("start_game enables victory checking", function()
    player.init_manual({
        { slot = 0, team = 1 },
    })

    assert_false(player.is_game_started(), "not started initially")
    player.start_game()
    assert_true(player.is_game_started(), "started after call")
end)

test("reset clears game state", function()
    player.init_manual({
        { slot = 0, team = 1 },
    })

    player.start_game()
    player.force_victory(0, false)

    player.reset()

    assert_false(player.is_game_started(), "started reset")
    assert_false(player.is_game_ended(), "ended reset")
    local result = player.get_game_result()
    assert_nil(result.winning_team, "no winner after reset")
end)

test("victory check integrates with player.defeat", function()
    player.init_manual({
        { slot = 0, team = 1 },
        { slot = 1, team = 2 },
    })

    player.start_game()

    -- Defeat should trigger victory check automatically
    player.defeat(1)

    assert_true(player.is_game_ended(), "game ended via defeat")
    assert_eq("victorious", player.get(0).state, "winner via defeat integration")
end)

test("neutral players excluded from team counting", function()
    player.init_manual({
        { slot = 0, team = 1 },
    })
    -- Neutral is slot 15, type "neutral"

    player.start_game()

    -- Only team 1 active (neutral doesn't count)
    local ended = player.check_victory_conditions()

    -- With only one team, should trigger victory
    assert_true(ended, "game ends")
    assert_eq("victorious", player.get(0).state, "player victorious")
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
