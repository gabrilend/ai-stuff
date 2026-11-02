-- {{{ Mana Efficiency Test Suite
-- Checks issue 044 without a window: abilities spend only the mana their
-- effect is worth (no overkill, no overheal), never less than a tenth of
-- the bar, skip redundant buffs, scale area abilities by their targets, and
-- keep statistics.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_mana_efficiency').run_all()"
local TestSuite = {}

local ManaComponent = require("src.components.mana")
local ManaEfficiency = require("src.systems.mana_efficiency")

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ local function full_bar
local function full_bar(ability)
    local mana = ManaComponent({{type = ability.type, max_mana = ability.max_mana}})
    mana.bars[1].current = ability.max_mana
    return mana
end
-- }}}

local STRIKE = {type = "damage", power = 50, max_mana = 100}
local MEND = {type = "heal", power = 40, max_mana = 80}

-- {{{ TestSuite.test_damage_overkill
function TestSuite.test_damage_overkill()
    local plan = ManaEfficiency.plan(STRIKE, {{current_health = 20, max_health = 120}}, 100)
    assert(plan.can_execute, "Can strike")
    assert_near(plan.mana_to_use, 40, "20 of 50 damage needed: 40% of the bar")
    assert_near(plan.amount, 20, "Deals exactly what is needed")

    local healthy = ManaEfficiency.plan(STRIKE, {{current_health = 120, max_health = 120}}, 100)
    assert_near(healthy.mana_to_use, 100, "A healthy target takes the whole bar")
    assert_near(healthy.amount, 50, "Full power")

    local dead = ManaEfficiency.plan(STRIKE, {{current_health = 0, max_health = 120}}, 100)
    assert(not dead.can_execute and dead.reason == "target_dead", "No mana on a dead target")

    print("✓ Damage overkill test passed")
end
-- }}}

-- {{{ TestSuite.test_heal_overheal
function TestSuite.test_heal_overheal()
    local plan = ManaEfficiency.plan(MEND, {{current_health = 110, max_health = 120}}, 80)
    assert_near(plan.mana_to_use, 20, "10 of 40 healing needed: a quarter of 80 mana")
    assert_near(plan.amount, 10, "Heals exactly to full")

    local full = ManaEfficiency.plan(MEND, {{current_health = 120, max_health = 120}}, 80)
    assert(not full.can_execute and full.reason == "target_full_health", "No mana on a full ally")

    print("✓ Heal overheal test passed")
end
-- }}}

-- {{{ TestSuite.test_minimum_share
function TestSuite.test_minimum_share()
    local plan = ManaEfficiency.plan(STRIKE, {{current_health = 1, max_health = 120}}, 100)
    assert_near(plan.mana_to_use, 10, "Never less than a tenth of the bar")
    assert(plan.amount >= 1, "Still enough to finish the target")

    print("✓ Minimum share test passed")
end
-- }}}

-- {{{ TestSuite.test_buffs_skip_redundant
function TestSuite.test_buffs_skip_redundant()
    local rally = {type = "buff", power = 1, max_mana = 60}
    local fresh = ManaEfficiency.plan(rally, {{current_health = 50, max_health = 100}}, 60)
    assert(fresh.can_execute and fresh.mana_to_use == 60, "A buff on a fresh target uses the bar")

    local again = ManaEfficiency.plan(rally, {{current_health = 50, max_health = 100, has_effect = true}}, 60)
    assert(not again.can_execute and again.reason == "already_affected", "No mana on a target that has it")

    print("✓ Buffs skip redundant test passed")
end
-- }}}

-- {{{ TestSuite.test_area_scales_with_targets
function TestSuite.test_area_scales_with_targets()
    local blast = {type = "area", power = 30, max_mana = 100, max_targets = 4}
    local healthy = {current_health = 100, max_health = 100}
    local weak = {current_health = 15, max_health = 100}

    local full = ManaEfficiency.plan(blast, {healthy, healthy, healthy, healthy}, 100)
    assert_near(full.mana_to_use, 100, "Four useful targets use the whole bar")

    local two = ManaEfficiency.plan(blast, {healthy, healthy}, 100)
    assert_near(two.mana_to_use, 50, "Two of four targets use half")

    local mixed = ManaEfficiency.plan(blast, {healthy, weak}, 100)
    assert_near(mixed.mana_to_use, 100 * (1 + 0.5) / 4, "A weak target counts for what it can take")

    local many = ManaEfficiency.plan(blast, {healthy, healthy, healthy, healthy, healthy, healthy}, 100)
    assert_near(many.mana_to_use, 100, "Targets beyond the limit add nothing")
    assert(many.targets_hit == 4, "Only max_targets are hit")

    local heal_wave = {type = "area", area_effect = "heal", power = 20, max_mana = 100, max_targets = 2}
    local plan = ManaEfficiency.plan(heal_wave, {{current_health = 90, max_health = 100}, {current_health = 100, max_health = 100}}, 100)
    assert_near(plan.mana_to_use, 100 * 0.5 / 2, "Area healing counts missing health")

    local none = ManaEfficiency.plan(blast, {}, 100)
    assert(not none.can_execute and none.reason == "no_useful_targets", "No targets, no mana")

    print("✓ Area scales with targets test passed")
end
-- }}}

-- {{{ TestSuite.test_cast_spends_and_records
function TestSuite.test_cast_spends_and_records()
    local mana = full_bar(STRIKE)
    local stats = ManaEfficiency.new_stats()

    local plan = ManaEfficiency.cast(mana, 1, STRIKE, {{current_health = 25, max_health = 120}}, stats)
    assert(plan.can_execute, "Cast went ahead")
    assert_near(mana.bars[1].current, 50, "Half the bar remains for the next charge")

    local refused = ManaEfficiency.cast(mana, 1, STRIKE, {{current_health = 0, max_health = 120}}, stats)
    assert(not refused.can_execute, "Refused cast")
    assert_near(mana.bars[1].current, 50, "A refused cast spends nothing")

    local short = ManaEfficiency.cast(mana, 1, STRIKE, {{current_health = 120, max_health = 120}}, stats)
    assert(not short.can_execute and short.reason == "not_enough_mana", "Half a bar can't pay for a full strike")

    assert(stats.casts == 1, "One cast recorded")
    assert_near(stats.mana_spent, 50, "Mana spent recorded")
    assert_near(stats.mana_saved, 50, "Mana saved recorded")
    assert(stats.refused.target_dead == 1 and stats.refused.not_enough_mana == 1, "Refusals by reason")
    assert(stats.by_type.damage.casts == 1, "Per-type statistics")

    print("✓ Cast spends and records test passed")
end
-- }}}

-- {{{ TestSuite.test_performance
function TestSuite.test_performance()
    local stats = ManaEfficiency.new_stats()
    local targets = {{current_health = 40, max_health = 100}, {current_health = 80, max_health = 100}}
    local blast = {type = "area", power = 30, max_mana = 100}
    local start = os.clock()
    for i = 1, 10000 do
        local mana = full_bar(i % 2 == 0 and STRIKE or blast)
        ManaEfficiency.cast(mana, 1, i % 2 == 0 and STRIKE or blast, targets, stats)
    end
    local elapsed = os.clock() - start
    print(string.format("  10000 casts: %.3fs", elapsed))
    assert(elapsed < 1.0, "Planning casts is cheap")

    print("✓ Performance test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Mana Efficiency Tests...")
    print(string.rep("=", 40))

    TestSuite.test_damage_overkill()
    TestSuite.test_heal_overheal()
    TestSuite.test_minimum_share()
    TestSuite.test_buffs_skip_redundant()
    TestSuite.test_area_scales_with_targets()
    TestSuite.test_cast_spends_and_records()
    TestSuite.test_performance()

    print(string.rep("=", 40))
    print("✅ All mana efficiency tests passed!")
end
-- }}}

return TestSuite
-- }}}
