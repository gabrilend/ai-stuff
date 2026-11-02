-- {{{ Ability Balance Test Suite
-- Checks issue 055's harness (src/testing/ability_balance.lua) without a
-- window: seeded battles repeat exactly, a stronger side wins, mirror
-- matches come out even, the confidence interval is right, the report
-- flags only sets whose whole interval is past a threshold, the newer
-- abilities (cleave, zones, emergency healing, misses) all fire in real
-- battles, and a hundred units with abilities stay cheap to simulate.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_ability_balance').run_all()"
local TestSuite = {}

local AbilityBalance = require("src.testing.ability_balance")

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ TestSuite.test_repeatable
function TestSuite.test_repeatable()
    local a = AbilityBalance.random_source(42)
    local b = AbilityBalance.random_source(42)
    for _ = 1, 10 do
        local x = a()
        assert(x == b() and x > 0 and x < 1, "A seed gives the same numbers, between 0 and 1")
    end

    local first = AbilityBalance.run_battle({team_a = "basic_warrior", team_b = "basic_archer", seed = 5})
    local second = AbilityBalance.run_battle({team_a = "basic_warrior", team_b = "basic_archer", seed = 5})
    assert(first.winner == second.winner and first.time == second.time, "The same seed, the same battle")
    assert_near(first.damage[1], second.damage[1], "Down to the damage dealt")
    print("✓ Repeatable battle test passed")
end
-- }}}

-- {{{ TestSuite.test_stronger_side_wins
function TestSuite.test_stronger_side_wins()
    local result = AbilityBalance.run_battle({team_a = {"basic_warrior", "basic_warrior", "basic_warrior", "basic_warrior"},
        team_b = {"basic_warrior"}, seed = 1})
    assert(result.winner == 1, "Four warriors beat one")
    assert(result.survivors[1] > 0 and result.survivors[2] == 0, "The loser has no one standing")
    assert(result.damage[1] > 0 and result.activations > 0, "They fought with abilities")
    assert(result.casts.primary_melee_attack and result.casts.primary_melee_attack > 0, "Casts are counted by name")
    print("✓ Stronger side test passed")
end
-- }}}

-- {{{ TestSuite.test_wilson
function TestSuite.test_wilson()
    local low, high = AbilityBalance.wilson(5, 10)
    assert_near(low, 0.2366, "Wilson low for 5 of 10", 1e-3)
    assert_near(high, 0.7634, "Wilson high for 5 of 10", 1e-3)
    low, high = AbilityBalance.wilson(0, 20)
    assert(low == 0 and high > 0.1 and high < 0.2, "No wins still leaves some doubt")
    low, high = AbilityBalance.wilson(0, 0)
    assert(low == 0 and high == 1, "No battles, no knowledge")
    print("✓ Wilson interval test passed")
end
-- }}}

-- {{{ TestSuite.test_mirror_match
function TestSuite.test_mirror_match()
    local result = AbilityBalance.matchup("basic_archer", "basic_archer", {battles = 10, seed = 3})
    assert(result.wins_a + result.wins_b + result.draws == 10, "Every battle is counted")
    print(string.format("  archer mirror: %d-%d, %d draws", result.wins_a, result.wins_b, result.draws))
    assert(result.low <= 0.5 and result.high >= 0.5, "A mirror match can't be told from even")
    print("✓ Mirror match test passed")
end
-- }}}

-- {{{ TestSuite.test_report
function TestSuite.test_report()
    -- A made-up round robin, to check the thresholds alone.
    local round = {
        sets = {"strong", "even", "feeble"},
        matchups = {{a = "strong", b = "feeble", win_rate_a = 1, low = 0.95, high = 1}},
        overall = {
            strong = {win_rate = 0.9, low = 0.8, high = 0.96},
            even = {win_rate = 0.6, low = 0.4, high = 0.77},
            feeble = {win_rate = 0.1, low = 0.03, high = 0.2}
        }
    }
    local report = AbilityBalance.report(round)
    local verdicts = {}
    for _, row in ipairs(report.recommendations) do
        verdicts[row.set] = row.verdict
    end
    assert(verdicts.strong == "dominant" and verdicts.feeble == "weak", "Sets past the thresholds are flagged")
    assert(verdicts.even == "balanced", "A set whose interval reaches the middle isn't")
    assert(report.recommendations[1].set == "strong", "Best first")
    assert(report.lopsided == 1, "One-sided matchups are listed")
    assert(report.lines[1]:find("balance"), "The report has a heading")

    -- And a real one, small enough to be quick.
    local real = AbilityBalance.round_robin({"basic_warrior", "basic_archer", "brute"}, {battles = 4, seed = 9})
    assert(#real.matchups == 3, "Every pair meets once")
    for _, set in ipairs(real.sets) do
        local row = real.overall[set]
        assert(row.battles == 8 and row.low <= row.win_rate and row.win_rate <= row.high, set .. " has a rate and interval")
    end
    local total = 0
    for _, set in ipairs(real.sets) do
        total = total + real.overall[set].score
    end
    assert_near(total, 12, "Each battle's win is counted once")
    for _, line in ipairs(AbilityBalance.report(real).lines) do
        print("  " .. line)
    end
    print("✓ Report test passed")
end
-- }}}

-- {{{ TestSuite.test_interactions
-- The newer abilities do their part in whole battles.
function TestSuite.test_interactions()
    local storm = AbilityBalance.run_battle({team_a = "storm_caller", team_b = "basic_warrior", seed = 2, keep_world = true})
    assert(storm.world.persistent.stats.zones_added > 0 and storm.world.persistent.stats.zone_hits > 0,
        "Static fields are laid and catch enemies")

    local medics = AbilityBalance.run_battle({team_a = {"field_medic", "basic_warrior", "basic_warrior", "field_medic"},
        team_b = "basic_warrior", seed = 1})
    assert(medics.healing[1] > 0, "Medics heal")
    assert((medics.casts.emergency_heal or 0) > 0, "Emergency heals fire when an ally is badly hurt")

    local axes = AbilityBalance.run_battle({team_a = "berserker", team_b = "basic_warrior", seed = 2, keep_world = true})
    assert(axes.world.effects.stats.cleave_hits > 0, "Axes cleave")

    local slings = AbilityBalance.matchup({"skirmisher", "skirmisher", "skirmisher", "skirmisher"}, "brute",
        {battles = 2, seed = 4})
    assert(slings.damage_a > 0, "Skirmishers fight")

    local any_miss = false
    for seed = 1, 6 do
        local archers = AbilityBalance.run_battle({team_a = "basic_archer", team_b = "brute", seed = seed, keep_world = true})
        if archers.world.effects.stats.projectile_misses > 0 then
            any_miss = true
            break
        end
    end
    assert(any_miss, "Arrows sometimes miss")
    print("✓ Interactions test passed")
end
-- }}}

-- {{{ TestSuite.test_performance
function TestSuite.test_performance()
    local sets = {"basic_warrior", "basic_archer", "support_cleric", "battle_mage", "brute", "druid",
        "skirmisher", "berserker", "crossbowman", "field_medic", "storm_caller"}
    local roster = {}
    for i = 1, 50 do
        roster[i] = sets[(i - 1) % #sets + 1]
    end
    local start = os.clock()
    local result = AbilityBalance.run_battle({team_a = roster, team_b = roster, seed = 7, max_time = 10,
        spacing = 6, gap = 60})
    local elapsed = os.clock() - start
    print(string.format("  100 units with abilities, 10 s of battle in 0.1 s steps: %.3fs, %d activations",
        elapsed, result.activations))
    assert(result.activations > 0, "Abilities fired")
    assert(elapsed < 5.0, "A hundred units stay cheap to simulate")
    print("✓ Performance test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running ability balance tests...")
    TestSuite.test_repeatable()
    TestSuite.test_stronger_side_wins()
    TestSuite.test_wilson()
    TestSuite.test_mirror_match()
    TestSuite.test_report()
    TestSuite.test_interactions()
    TestSuite.test_performance()
    print("✅ All ability balance tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
