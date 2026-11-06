-- {{{ Mana Test Suite
-- Checks issue 041 without a window: one bar per ability (1 to 4), the
-- primary bar always charging, secondary bars charging only when the
-- unit's condition holds (ranged: standing still; melee: an enemy within
-- reach), full bars holding, spending, and bar colors by ability type.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_mana').run_all()"
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

-- {{{ local function two_abilities
local function two_abilities()
    return {
        {name = "strike", type = "damage", max_mana = 100, mana_rate = 20},
        {name = "rally", type = "buff", max_mana = 50, mana_rate = 10}
    }
end
-- }}}

-- {{{ local function new_unit
local function new_unit(em, x, y, team, unit_type, abilities)
    local unit = Unit.create_basic_unit(em, x, y, team, unit_type)
    em:add_component(unit, "mana", ManaComponent(abilities or two_abilities()))
    return unit
end
-- }}}

-- {{{ local function set_velocity
local function set_velocity(em, unit, vx, vy)
    local moveable = em:get_component(unit, "moveable")
    moveable.velocity_x, moveable.velocity_y = vx, vy
end
-- }}}

-- {{{ TestSuite.test_component_shape
function TestSuite.test_component_shape()
    local mana = ManaComponent(two_abilities())
    assert(#mana.bars == 2, "One bar per ability")
    assert(mana.bars[1].is_primary and not mana.bars[2].is_primary, "The first ability is the primary")
    assert(mana.bars[1].current == 0 and mana.bars[2].max == 50, "Bars start empty with their own maximum")

    local defaults = ManaComponent({{}})
    assert(defaults.bars[1].max == 100 and defaults.bars[1].rate == 10, "Defaults fill in")

    assert(not pcall(ManaComponent, {}), "At least one ability is required")
    assert(not pcall(ManaComponent, {{}, {}, {}, {}, {}}), "At most four abilities")
    assert(pcall(ManaComponent, {{}, {}, {}, {}}), "Four abilities are allowed")
    assert(not pcall(ManaComponent, {{max_mana = 0}}), "A bar needs a positive maximum")

    print("✓ Component shape test passed")
end
-- }}}

-- {{{ TestSuite.test_primary_always_charges
function TestSuite.test_primary_always_charges()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local ranged = new_unit(em, 100, 100, 1, "ranged")
    local melee = new_unit(em, 300, 100, 1, "melee")
    set_velocity(em, ranged, 40, 0)     -- moving, no enemies anywhere

    system:update(1.0)
    local ranged_mana = em:get_component(ranged, "mana")
    local melee_mana = em:get_component(melee, "mana")
    assert_near(ranged_mana.bars[1].current, 20, "Moving ranged primary charges")
    assert_near(melee_mana.bars[1].current, 20, "Lone melee primary charges")
    assert(ranged_mana.bars[2].current == 0, "Moving ranged secondary waits")
    assert(melee_mana.bars[2].current == 0, "Melee secondary waits with no enemy near")

    print("✓ Primary always charges test passed")
end
-- }}}

-- {{{ TestSuite.test_ranged_secondary_when_still
function TestSuite.test_ranged_secondary_when_still()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local ranged = new_unit(em, 100, 100, 1, "ranged")
    local support = new_unit(em, 120, 100, 1, "support")
    local mana = em:get_component(ranged, "mana")

    set_velocity(em, ranged, 0, 0)
    -- Ranged units must first stand still for STILL_TIME (issue 043).
    system:update(ManaSystem.STILL_TIME)
    assert(mana.bars[2].current == 0, "Nothing until still for a quarter second")
    system:update(1.0)
    assert_near(mana.bars[2].current, 10, "Standing still charges the secondary")
    assert_near(em:get_component(support, "mana").bars[2].current, 10, "Support units follow the ranged rule")

    set_velocity(em, ranged, 0, 30)
    system:update(1.0)
    assert_near(mana.bars[2].current, 10, "Moving stops the secondary charging")
    assert(not mana.bars[2].charging, "The bar reports it is not charging")

    print("✓ Ranged secondary when still test passed")
end
-- }}}

-- {{{ TestSuite.test_melee_secondary_when_enemy_in_reach
function TestSuite.test_melee_secondary_when_enemy_in_reach()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local melee = new_unit(em, 100, 100, 1, "melee")
    local mana = em:get_component(melee, "mana")
    set_velocity(em, melee, 50, 0)      -- moving does not matter for melee

    Unit.create_basic_unit(em, 105, 100, 1, "melee")                -- an ally right beside it
    local enemy = Unit.create_basic_unit(em, 130, 100, 2, "melee")   -- 30 away: beyond reach 12
    system:update(1.0)
    assert(mana.bars[2].current == 0, "Allies and distant enemies do not count")

    local pos = em:get_component(enemy, "position")
    pos.x = 110                                          -- 10 away: within reach
    system:update(1.0)
    assert_near(mana.bars[2].current, 10, "An enemy within reach charges the secondary, even while moving")

    Unit.damage_unit(em, enemy, 1000)
    system:update(1.0)
    assert_near(mana.bars[2].current, 10, "A dead enemy does not count")

    local tank = new_unit(em, 500, 500, 1, "tank")
    Unit.create_basic_unit(em, 514, 500, 2, "melee")    -- 14 away: inside a tank's reach of 15
    system:update(1.0)
    assert_near(em:get_component(tank, "mana").bars[2].current, 10, "Tanks use their own, longer reach")

    print("✓ Melee secondary when enemy in reach test passed")
end
-- }}}

-- {{{ TestSuite.test_full_bars_hold_and_spend
function TestSuite.test_full_bars_hold_and_spend()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local ranged = new_unit(em, 100, 100, 1, "ranged")
    local mana = em:get_component(ranged, "mana")

    system:update(10.0)
    assert(ManaSystem.is_full(mana, 1) and ManaSystem.is_full(mana, 2), "Both bars fill")
    assert(mana.bars[1].current == 100, "Mana never goes past the top")
    system:update(5.0)
    assert(mana.bars[1].current == 100 and not mana.bars[1].charging, "A full bar holds")

    assert_near(ManaSystem.spend(mana, 1, 30), 30, "Spending part of a bar")
    assert_near(ManaSystem.get_fraction(mana, 1), 0.7, "Fraction after spending")
    assert_near(ManaSystem.spend(mana, 1, 500), 70, "Cannot spend more than the bar holds")
    assert(ManaSystem.spend(mana, 9, 10) == 0, "Spending from a missing bar does nothing")

    system:update(1.0)
    assert_near(mana.bars[1].current, 20, "An emptied bar charges again")

    print("✓ Full bars hold and spend test passed")
end
-- }}}

-- {{{ TestSuite.test_dead_units_do_not_charge
function TestSuite.test_dead_units_do_not_charge()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local unit = new_unit(em, 100, 100, 1, "melee")
    Unit.damage_unit(em, unit, 1000)
    system:update(1.0)
    assert(em:get_component(unit, "mana").bars[1].current == 0, "Dead units gain no mana")

    print("✓ Dead units do not charge test passed")
end
-- }}}

-- {{{ TestSuite.test_bar_colors
function TestSuite.test_bar_colors()
    local mana = ManaComponent({
        {type = "damage"}, {type = "heal"}, {type = "buff"}, {type = "debuff"}
    })
    local seen = {}
    for index = 1, 4 do
        local color = ManaSystem.get_bar_color(mana, index)
        local key = table.concat(color, ",")
        assert(not seen[key], "Each ability type has its own color")
        seen[key] = true
    end
    assert(ManaSystem.TYPE_COLORS.area, "Area abilities have a color too")

    print("✓ Bar colors test passed")
end
-- }}}

-- {{{ TestSuite.test_performance
function TestSuite.test_performance()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    for i = 1, 60 do
        new_unit(em, (i % 10) * 20, math.floor(i / 10) * 20, (i % 2) + 1, i % 3 == 0 and "ranged" or "melee")
    end
    local start = os.clock()
    for _ = 1, 60 do
        system:update(1 / 60)
    end
    local elapsed = os.clock() - start
    print(string.format("  60 units, 60 frames: %.3fs", elapsed))
    assert(elapsed < 1.0, "Mana updates stay cheap with 50+ units")

    print("✓ Performance test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Mana Tests...")
    print(string.rep("=", 40))

    TestSuite.test_component_shape()
    TestSuite.test_primary_always_charges()
    TestSuite.test_ranged_secondary_when_still()
    TestSuite.test_melee_secondary_when_enemy_in_reach()
    TestSuite.test_full_bars_hold_and_spend()
    TestSuite.test_dead_units_do_not_charge()
    TestSuite.test_bar_colors()
    TestSuite.test_performance()

    print(string.rep("=", 40))
    print("✅ All mana tests passed!")
end
-- }}}

return TestSuite
-- }}}
