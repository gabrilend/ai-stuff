-- {{{ Mana Conditions Test Suite
-- Checks issues 042 and 043 without a window: ranged units must stand
-- still for a quarter second before their secondary bars charge, combat
-- bonuses speed charging up, changes of state take effect at once, a dead
-- unit's mana empties, and a hundred units stay cheap.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_mana_conditions').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Unit = require("src.entities.unit")
local ManaComponent = require("src.components.mana")
local ManaSystem = require("src.systems.mana_system")

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ local function new_unit
-- A unit with a primary bar and one secondary bar, both 10 mana a second
-- and large enough not to fill during a test.
local function new_unit(em, x, y, team, unit_type)
    local unit = Unit.create_basic_unit(em, x, y, team, unit_type)
    em:add_component(unit, "mana", ManaComponent({
        {name = "attack", type = "damage", max_mana = 1000, mana_rate = 10},
        {name = "special", type = "buff", max_mana = 1000, mana_rate = 10}
    }))
    return unit
end
-- }}}

-- {{{ local function set_velocity
local function set_velocity(em, unit, vx, vy)
    local moveable = em:get_component(unit, "moveable")
    moveable.velocity_x, moveable.velocity_y = vx, vy
end
-- }}}

-- {{{ local function secondary
local function secondary(em, unit)
    return em:get_component(unit, "mana").bars[2]
end
-- }}}

-- {{{ TestSuite.test_ranged_must_settle
function TestSuite.test_ranged_must_settle()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local archer = new_unit(em, 100, 100, 1, "ranged")

    system:update(0.2)
    assert(secondary(em, archer).current == 0, "0.2 s still is not enough")
    system:update(0.2)
    assert_near(secondary(em, archer).current, 10 * 0.15, "Only the time past 0.25 s counts")

    set_velocity(em, archer, 20, 0)
    system:update(0.1)
    local held = secondary(em, archer).current
    assert(em:get_component(archer, "mana").still_time == 0, "Moving resets the still time")
    set_velocity(em, archer, 0, 0)
    system:update(0.2)
    assert_near(secondary(em, archer).current, held, "After moving it must settle again")

    print("✓ Ranged must settle test passed")
end
-- }}}

-- {{{ TestSuite.test_ranged_combat_bonus
function TestSuite.test_ranged_combat_bonus()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local archer = new_unit(em, 100, 100, 1, "ranged")
    system:update(ManaSystem.STILL_TIME)

    system:update(1.0)
    assert_near(secondary(em, archer).current, 10, "Still with no enemy near: normal rate")
    assert(em:get_component(archer, "mana").secondary_reason == "still", "Reason: still")

    Unit.create_basic_unit(em, 125, 100, 2, "melee")     -- 25 away: inside shooting range 30
    system:update(1.0)
    assert_near(secondary(em, archer).current, 22, "An enemy in range adds 20%")
    assert(em:get_component(archer, "mana").secondary_reason == "still, in combat", "Reason: in combat")
    assert_near(em:get_component(archer, "mana").bars[1].current, 22.5, "The primary bar gets no bonus (2.25 s at 10)")

    print("✓ Ranged combat bonus test passed")
end
-- }}}

-- {{{ TestSuite.test_melee_outnumbered_bonus
function TestSuite.test_melee_outnumbered_bonus()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local fighter = new_unit(em, 100, 100, 1, "melee")

    Unit.create_basic_unit(em, 110, 100, 2, "melee")
    system:update(1.0)
    assert_near(secondary(em, fighter).current, 10, "One enemy in reach: normal rate")

    Unit.create_basic_unit(em, 100, 110, 2, "melee")
    system:update(1.0)
    assert_near(secondary(em, fighter).current, 21.5, "Two enemies in reach add 15%")
    assert(em:get_component(fighter, "mana").secondary_reason == "outnumbered", "Reason: outnumbered")

    print("✓ Melee outnumbered bonus test passed")
end
-- }}}

-- {{{ TestSuite.test_leaving_reach_stops_charging
function TestSuite.test_leaving_reach_stops_charging()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local fighter = new_unit(em, 100, 100, 1, "melee")
    local enemy = Unit.create_basic_unit(em, 110, 100, 2, "melee")

    system:update(0.5)
    assert_near(secondary(em, fighter).current, 5, "Charging while the enemy is near")
    em:get_component(enemy, "position").x = 200
    system:update(0.5)
    assert_near(secondary(em, fighter).current, 5, "Stops the frame the enemy leaves reach")
    assert(not secondary(em, fighter).charging, "Bar reports it stopped")
    em:get_component(enemy, "position").x = 105
    system:update(0.5)
    assert_near(secondary(em, fighter).current, 10, "Starts again the frame it returns")

    print("✓ Leaving reach stops charging test passed")
end
-- }}}

-- {{{ TestSuite.test_death_empties_mana
function TestSuite.test_death_empties_mana()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local unit = new_unit(em, 100, 100, 1, "ranged")
    system:update(2.0)
    assert(em:get_component(unit, "mana").bars[1].current > 0, "Mana built up")

    Unit.damage_unit(em, unit, 1000)
    system:update(0.1)
    local mana = em:get_component(unit, "mana")
    assert(mana.bars[1].current == 0 and mana.bars[2].current == 0, "A dead unit's mana empties")

    print("✓ Death empties mana test passed")
end
-- }}}

-- {{{ TestSuite.test_no_enemies_no_allies
function TestSuite.test_no_enemies_no_allies()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local lone = new_unit(em, 100, 100, 1, "tank")
    system:update(1.0)
    assert(secondary(em, lone).current == 0, "A lone melee-style unit's secondary waits")
    assert_near(em:get_component(lone, "mana").bars[1].current, 10, "Its primary still charges")

    print("✓ No enemies, no allies test passed")
end
-- }}}

-- {{{ TestSuite.test_performance_hundred_units
function TestSuite.test_performance_hundred_units()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local types = {"melee", "ranged", "tank", "support", "special"}
    for i = 1, 120 do
        new_unit(em, (i % 12) * 10, math.floor(i / 12) * 10, (i % 2) + 1, types[(i % 5) + 1])
    end
    local start = os.clock()
    for _ = 1, 60 do
        system:update(1 / 60)
    end
    local elapsed = os.clock() - start
    print(string.format("  120 units, 60 frames: %.3fs", elapsed))
    assert(elapsed < 2.0, "One second of play for 120 units stays well under two seconds")

    print("✓ Performance with a hundred units test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Mana Conditions Tests...")
    print(string.rep("=", 40))

    TestSuite.test_ranged_must_settle()
    TestSuite.test_ranged_combat_bonus()
    TestSuite.test_melee_outnumbered_bonus()
    TestSuite.test_leaving_reach_stops_charging()
    TestSuite.test_death_empties_mana()
    TestSuite.test_no_enemies_no_allies()
    TestSuite.test_performance_hundred_units()

    print(string.rep("=", 40))
    print("✅ All mana conditions tests passed!")
end
-- }}}

return TestSuite
-- }}}
