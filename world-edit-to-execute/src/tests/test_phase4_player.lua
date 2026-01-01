#!/usr/bin/env lua
--[[
Issue 408c: Unit Tests - Player Systems

Tests for runtime player-related systems:
- Resources (406): gold, lumber, food/supply, spending validation
- Player State (407): players, alliances, state transitions, victory conditions
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local resources = require("runtime.resources")
local player = require("runtime.player")

-- {{{ Test infrastructure
local tests_run = 0
local tests_passed = 0
local current_section = ""

local function section(name)
    current_section = name
    print("\n=== " .. name .. " ===")
end

local function test(name, fn)
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name)
        print("         " .. tostring(err))
    end
end

local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)), 2)
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true", 2)
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "Expected false", 2)
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(msg or "Expected nil, got " .. tostring(value), 2)
    end
end
-- }}}

-- ============================================================================
-- Resource Tests (406)
-- ============================================================================

-- {{{ Resource Initialization Tests
section("Resource Initialization")

test("init_player creates player resources", function()
    resources.reset()
    resources.init_player(0)

    assert_true(resources.has_player(0), "Player 0 should be initialized")
    assert_eq(0, resources.get(0, "gold"), "Gold should start at 0")
    assert_eq(0, resources.get(0, "lumber"), "Lumber should start at 0")
    assert_eq(0, resources.get(0, "food_used"), "Food used should start at 0")
    assert_eq(0, resources.get(0, "food_cap"), "Food cap should start at 0")
end)

test("set and get resources", function()
    resources.reset()
    resources.init_player(0)

    resources.set(0, "gold", 500)
    resources.set(0, "lumber", 150)

    assert_eq(500, resources.get(0, "gold"), "Gold should be 500")
    assert_eq(150, resources.get(0, "lumber"), "Lumber should be 150")
end)

test("get returns 0 for uninitialized player", function()
    resources.reset()

    assert_eq(0, resources.get(99, "gold"), "Should return 0 for non-existent player")
end)

test("reset_player restores defaults", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "gold", 1000)

    resources.reset_player(0)

    assert_eq(0, resources.get(0, "gold"), "Gold should be reset to 0")
end)
-- }}}

-- {{{ Resource Spending Tests
section("Resource Spending")

test("spend valid amount succeeds", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "gold", 500)
    resources.set(0, "lumber", 150)

    local success = resources.spend(0, {gold = 100, lumber = 50})

    assert_true(success, "Should be able to spend 100 gold and 50 lumber")
    assert_eq(400, resources.get(0, "gold"), "Gold should be 400 after spending")
    assert_eq(100, resources.get(0, "lumber"), "Lumber should be 100 after spending")
end)

test("spend more than available fails", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "gold", 500)

    local success, missing = resources.spend(0, {gold = 1000})

    assert_false(success, "Should not be able to spend more than available")
    assert_eq("gold", missing, "Missing resource should be gold")
    assert_eq(500, resources.get(0, "gold"), "Gold unchanged after failed spend")
end)

test("spend is atomic - all or nothing", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "gold", 100)
    resources.set(0, "lumber", 50)

    -- Try to spend more lumber than available
    local success = resources.spend(0, {gold = 50, lumber = 100})

    assert_false(success, "Spend should fail")
    assert_eq(100, resources.get(0, "gold"), "Gold unchanged after atomic failure")
    assert_eq(50, resources.get(0, "lumber"), "Lumber unchanged after atomic failure")
end)
-- }}}

-- {{{ Resource Add and Check Tests
section("Resource Add and Check")

test("add resources", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "gold", 100)

    resources.add(0, "gold", 250)

    assert_eq(350, resources.get(0, "gold"), "Gold should be 350 after adding")
end)

test("subtract resources", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "gold", 500)

    resources.subtract(0, "gold", 200)

    assert_eq(300, resources.get(0, "gold"), "Gold should be 300 after subtracting")
end)

test("can_afford checks correctly", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "gold", 350)

    assert_true(resources.can_afford(0, {gold = 300}), "Should afford 300 gold")
    assert_false(resources.can_afford(0, {gold = 400}), "Should not afford 400 gold")
end)

test("resources clamped to max", function()
    resources.reset()
    resources.init_player(0)

    resources.set(0, "gold", 2000000)  -- Way over max

    local gold = resources.get(0, "gold")
    assert_true(gold <= 999999, "Gold should be clamped to max")
end)

test("resources clamped to min", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "gold", 100)

    resources.subtract(0, "gold", 500)  -- Would go negative

    assert_eq(0, resources.get(0, "gold"), "Gold should be clamped to 0")
end)
-- }}}

-- {{{ Food Supply Tests
section("Food Supply")

test("food supply tracking", function()
    resources.reset()
    resources.init_player(0)

    resources.add_food_supply(0, 10)
    assert_eq(10, resources.get(0, "food_cap"), "Food cap should be 10")

    resources.add_food_used(0, 5)
    assert_eq(5, resources.get(0, "food_used"), "Food used should be 5")
end)

test("food status calculation", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "food_cap", 10)
    resources.set(0, "food_used", 5)

    local status = resources.get_food_status(0)

    assert_eq(5, status.used, "Food used should be 5")
    assert_eq(10, status.cap, "Food cap should be 10")
    assert_eq(5, status.available, "Food available should be 5")
    assert_false(status.is_capped, "Should not be capped at 5/10")
end)

test("food capped detection", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "food_cap", 10)
    resources.set(0, "food_used", 10)

    local status = resources.get_food_status(0)

    assert_true(status.is_capped, "Should be capped at 10/10")
    assert_eq(0, status.available, "No food available when capped")
end)

test("spend with food checks food cap", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "gold", 1000)
    resources.set(0, "food_cap", 10)
    resources.set(0, "food_used", 5)

    -- Can afford 3 food (5+3 = 8 <= 10)
    assert_true(resources.can_afford(0, {food = 3}), "Should afford 3 food")

    -- Cannot afford 6 food (5+6 = 11 > 10)
    assert_false(resources.can_afford(0, {food = 6}), "Should not afford 6 food")

    -- Spend food increases food_used
    local success = resources.spend(0, {food = 3})
    assert_true(success, "Should spend 3 food")
    assert_eq(8, resources.get(0, "food_used"), "Food used should be 8")
end)

test("refund restores resources", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "gold", 400)
    resources.set(0, "food_used", 8)

    resources.refund(0, {gold = 100, food = 3})

    assert_eq(500, resources.get(0, "gold"), "Gold should be refunded")
    assert_eq(5, resources.get(0, "food_used"), "Food should be freed")
end)
-- }}}

-- {{{ Upkeep Tests
section("Upkeep System")

test("upkeep levels", function()
    resources.reset()

    assert_eq("none", resources.get_upkeep_level(0), "0 food = no upkeep")
    assert_eq("none", resources.get_upkeep_level(50), "50 food = no upkeep")
    assert_eq("low", resources.get_upkeep_level(51), "51 food = low upkeep")
    assert_eq("low", resources.get_upkeep_level(80), "80 food = low upkeep")
    assert_eq("high", resources.get_upkeep_level(81), "81 food = high upkeep")
end)

test("upkeep rate for player", function()
    resources.reset()
    resources.init_player(0)

    resources.set(0, "food_used", 30)
    assert_eq(1.0, resources.get_upkeep_rate(0), "No upkeep = 100% rate")

    resources.set(0, "food_used", 60)
    assert_eq(0.7, resources.get_upkeep_rate(0), "Low upkeep = 70% rate")

    resources.set(0, "food_used", 90)
    assert_eq(0.4, resources.get_upkeep_rate(0), "High upkeep = 40% rate")
end)

test("harvest deposit applies upkeep", function()
    resources.reset()
    resources.init_player(0)
    resources.set(0, "food_used", 60)  -- Low upkeep

    local deposited = resources.deposit_harvest(0, "gold", 100)

    assert_eq(70, deposited, "Should receive 70 gold (100 * 0.7)")
    assert_eq(70, resources.get(0, "gold"), "Player should have 70 gold")
end)
-- }}}

-- ============================================================================
-- Player Tests (407)
-- ============================================================================

-- {{{ Player Initialization Tests
section("Player Initialization")

test("init_manual creates players", function()
    player.reset()
    player.init_manual({
        {slot = 0, name = "Player 1", type = "human", race = "human", team = 0},
        {slot = 1, name = "Computer", type = "computer", race = "orc", team = 1},
    })

    assert_true(player.exists(0), "Player 0 should exist")
    assert_true(player.exists(1), "Player 1 should exist")

    local p0 = player.get(0)
    assert_eq("Player 1", p0.name, "Player 0 name")
    assert_eq("human", p0.type, "Player 0 type")
    assert_eq("human", p0.race, "Player 0 race")
    assert_eq(0, p0.team, "Player 0 team")

    local p1 = player.get(1)
    assert_eq("computer", p1.type, "Player 1 type")
    assert_eq("orc", p1.race, "Player 1 race")
end)

test("neutral player created automatically", function()
    player.reset()
    player.init_manual({
        {slot = 0, name = "Player 1"},
    })

    local neutral = player.get_neutral()
    assert_true(neutral ~= nil, "Neutral player should exist")
    assert_eq("neutral", neutral.type, "Neutral player type")
    assert_eq(15, neutral.slot, "Neutral player slot")
end)

test("player count", function()
    player.reset()
    player.init_manual({
        {slot = 0},
        {slot = 1},
        {slot = 2},
    })

    -- 3 players + 1 neutral = 4
    assert_eq(4, player.count(), "Should have 4 players including neutral")
end)
-- }}}

-- {{{ Player Query Tests
section("Player Queries")

test("get_all returns all players", function()
    player.reset()
    player.init_manual({
        {slot = 0},
        {slot = 1},
    })

    local all = player.get_all()
    assert_eq(3, #all, "Should have 3 players (2 + neutral)")
end)

test("get_active returns only active", function()
    player.reset()
    player.init_manual({
        {slot = 0},
        {slot = 1},
        {slot = 2},
    })

    player.set_state(1, "defeated")

    local active = player.get_active()
    -- 2 active + 1 neutral (neutral is active by default)
    local non_neutral_active = 0
    for _, p in ipairs(active) do
        if p.type ~= "neutral" then
            non_neutral_active = non_neutral_active + 1
        end
    end
    assert_eq(2, non_neutral_active, "Should have 2 active non-neutral players")
end)

test("get_by_type", function()
    player.reset()
    player.init_manual({
        {slot = 0, type = "human"},
        {slot = 1, type = "computer"},
        {slot = 2, type = "human"},
    })

    local humans = player.get_by_type("human")
    assert_eq(2, #humans, "Should have 2 human players")

    local computers = player.get_by_type("computer")
    assert_eq(1, #computers, "Should have 1 computer player")
end)

test("get_by_team", function()
    player.reset()
    player.init_manual({
        {slot = 0, team = 0},
        {slot = 1, team = 1},
        {slot = 2, team = 0},
    })

    local team0 = player.get_by_team(0)
    assert_eq(2, #team0, "Should have 2 players on team 0")
end)
-- }}}

-- {{{ Alliance Tests
section("Player Alliances")

test("set_alliance and get_alliance", function()
    player.reset()
    player.init_manual({
        {slot = 0, team = 0},
        {slot = 1, team = 1},
    })

    player.set_alliance(0, 1, "passive", true)

    assert_true(player.get_alliance(0, 1, "passive"), "0->1 should be passive")
    assert_false(player.get_alliance(1, 0, "passive"), "1->0 should not be passive (asymmetric)")
end)

test("set_mutual_alliance", function()
    player.reset()
    player.init_manual({
        {slot = 0},
        {slot = 1},
    })

    player.set_mutual_alliance(0, 1, "passive", true)

    assert_true(player.get_alliance(0, 1, "passive"), "0->1 should be passive")
    assert_true(player.get_alliance(1, 0, "passive"), "1->0 should be passive")
end)

test("is_ally requires mutual passive", function()
    player.reset()
    player.init_manual({
        {slot = 0},
        {slot = 1},
    })

    -- One-way alliance
    player.set_alliance(0, 1, "passive", true)
    assert_false(player.is_ally(0, 1), "One-way passive is not ally")

    -- Make it mutual
    player.set_alliance(1, 0, "passive", true)
    assert_true(player.is_ally(0, 1), "Mutual passive = ally")
end)

test("is_enemy is inverse of is_ally", function()
    player.reset()
    player.init_manual({
        {slot = 0},
        {slot = 1},
    })

    assert_true(player.is_enemy(0, 1), "Without alliance = enemies")

    player.set_mutual_alliance(0, 1, "passive", true)
    assert_false(player.is_enemy(0, 1), "With mutual passive = not enemies")
end)

test("player is always ally with self", function()
    player.reset()
    player.init_manual({
        {slot = 0},
    })

    assert_true(player.is_ally(0, 0), "Player is ally with self")
end)

test("get_allies and get_enemies", function()
    player.reset()
    player.init_manual({
        {slot = 0, team = 0},
        {slot = 1, team = 0},
        {slot = 2, team = 1},
    })

    -- Set team 0 as mutual allies
    player.set_mutual_alliance(0, 1, "passive", true)

    local allies = player.get_allies(0)
    assert_eq(2, #allies, "Player 0 should have 2 allies (self + player 1)")

    local enemies = player.get_enemies(0)
    assert_eq(1, #enemies, "Player 0 should have 1 enemy (player 2)")
end)
-- }}}

-- {{{ State Transition Tests
section("Player State Transitions")

test("initial state is active", function()
    player.reset()
    player.init_manual({
        {slot = 0},
    })

    local p = player.get(0)
    assert_eq("active", p.state, "Initial state should be active")
    assert_true(player.is_active(0), "is_active should return true")
end)

test("defeat changes state", function()
    player.reset()
    player.init_manual({
        {slot = 0},
    })

    local success = player.defeat(0)

    assert_true(success, "Defeat should succeed")
    assert_eq("defeated", player.get(0).state, "State should be defeated")
    assert_false(player.is_active(0), "is_active should return false")
end)

test("set_victorious changes state", function()
    player.reset()
    player.init_manual({
        {slot = 0},
    })

    local success = player.set_victorious(0)

    assert_true(success, "Set victorious should succeed")
    assert_eq("victorious", player.get(0).state, "State should be victorious")
end)

test("leave changes state", function()
    player.reset()
    player.init_manual({
        {slot = 0},
    })

    local success = player.leave(0)

    assert_true(success, "Leave should succeed")
    assert_eq("left", player.get(0).state, "State should be left")
end)

test("cannot transition from terminal states", function()
    player.reset()
    player.init_manual({
        {slot = 0},
    })

    player.defeat(0)
    local success = player.set_state(0, "active")

    assert_false(success, "Cannot transition from defeated")
end)

test("is_playing includes active and victorious", function()
    player.reset()
    player.init_manual({
        {slot = 0},
        {slot = 1},
        {slot = 2},
    })

    player.set_victorious(0)
    player.defeat(1)

    assert_true(player.is_playing(0), "Victorious player is playing")
    assert_false(player.is_playing(1), "Defeated player is not playing")
    assert_true(player.is_playing(2), "Active player is playing")
end)
-- }}}

-- {{{ Victory Condition Tests
section("Victory Conditions")

test("victory requires game started", function()
    player.reset()
    player.init_manual({
        {slot = 0, team = 0},
        {slot = 1, team = 1},
    })

    player.defeat(1)

    -- Game not started, victory should not trigger
    assert_false(player.is_game_ended(), "Game should not end without start_game")
end)

test("team elimination triggers victory", function()
    player.reset()
    player.init_manual({
        {slot = 0, team = 0},
        {slot = 1, team = 0},
        {slot = 2, team = 1},
    })

    player.start_game()
    player.defeat(2)  -- Last player on team 1

    assert_true(player.is_game_ended(), "Game should end")
    local result = player.get_game_result()
    assert_eq(0, result.winning_team, "Team 0 should win")
    assert_eq("elimination", result.end_reason, "Reason should be elimination")
end)

test("winning players marked victorious", function()
    player.reset()
    player.init_manual({
        {slot = 0, team = 0},
        {slot = 1, team = 1},
    })

    player.start_game()
    player.defeat(1)

    local p0 = player.get(0)
    assert_eq("victorious", p0.state, "Winner should be victorious")
end)

test("all teams eliminated = draw", function()
    player.reset()
    player.init_manual({
        {slot = 0, team = 0},
        {slot = 1, team = 1},
    })

    -- Set states manually without triggering victory check
    -- (simulates simultaneous elimination)
    player.get(0).state = "defeated"
    player.get(1).state = "defeated"

    player.start_game()
    local ended = player.check_victory_conditions()

    assert_true(ended, "Game should end")
    local result = player.get_game_result()
    assert_eq("draw", result.end_reason, "Should be a draw")
    assert_nil(result.winning_team, "No winning team in draw")
end)

test("force_victory ends game", function()
    player.reset()
    player.init_manual({
        {slot = 0, team = 0},
        {slot = 1, team = 1},
    })

    player.start_game()
    player.force_victory(1, false)  -- Player 1 wins

    assert_true(player.is_game_ended(), "Game should end")
    local result = player.get_game_result()
    assert_eq("custom", result.end_reason, "Reason should be custom")
    assert_eq("victorious", player.get(1).state, "Player 1 victorious")
    assert_eq("defeated", player.get(0).state, "Player 0 defeated")
end)

test("defeat_team defeats all on team", function()
    player.reset()
    player.init_manual({
        {slot = 0, team = 0},
        {slot = 1, team = 1},
        {slot = 2, team = 1},
    })

    player.start_game()
    local count = player.defeat_team(1)

    assert_eq(2, count, "Should defeat 2 players on team 1")
    assert_eq("defeated", player.get(1).state, "Player 1 defeated")
    assert_eq("defeated", player.get(2).state, "Player 2 defeated")
    assert_eq("victorious", player.get(0).state, "Player 0 victorious")
end)

test("get_winning_players after game end", function()
    player.reset()
    player.init_manual({
        {slot = 0, team = 0},
        {slot = 1, team = 0},
        {slot = 2, team = 1},
    })

    player.start_game()
    player.defeat(2)

    local winners = player.get_winning_players()
    assert_eq(2, #winners, "Should have 2 winners")
end)
-- }}}

-- {{{ Local Player Tests
section("Local Player")

test("set_local and get_local", function()
    player.reset()
    player.init_manual({
        {slot = 0, name = "Player One"},
        {slot = 1, name = "Player Two"},
    })

    player.set_local(1)

    local local_p = player.get_local()
    assert_eq("Player Two", local_p.name, "Local player should be Player Two")
    assert_eq(1, player.get_local_slot(), "Local slot should be 1")
end)
-- }}}

-- {{{ Event Callback Tests
section("Event Callbacks")

test("player_defeated event fires", function()
    player.reset()
    player.init_manual({
        {slot = 0},
    })

    local event_fired = false
    local event_slot = nil
    player.on("player_defeated", function(slot)
        event_fired = true
        event_slot = slot
    end)

    player.defeat(0)

    assert_true(event_fired, "Event should fire")
    assert_eq(0, event_slot, "Event should have correct slot")
end)

test("resource_changed event fires", function()
    resources.reset()
    resources.init_player(0)

    local event_fired = false
    local event_old = nil
    local event_new = nil
    resources.on("resource_changed", function(player_id, resource_name, old_value, new_value)
        event_fired = true
        event_old = old_value
        event_new = new_value
    end)

    resources.set(0, "gold", 500)

    assert_true(event_fired, "Event should fire")
    assert_eq(0, event_old, "Old value should be 0")
    assert_eq(500, event_new, "New value should be 500")
end)
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 60))
print(string.format("Tests: %d passed / %d total", tests_passed, tests_run))
if tests_passed == tests_run then
    print("All tests passed!")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
