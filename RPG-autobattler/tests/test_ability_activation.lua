-- {{{ Ability Activation Test Suite
-- Checks issue 048 without a window: abilities fire the moment their bar
-- is full and a target is there, the primary goes first and one ability
-- fires at a time, mana is spent by ManaEfficiency's plan, disabled units
-- don't fire, failures are recorded with reasons, and two hundred units
-- stay cheap.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_ability_activation').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local SystemManager = require("src.systems.system_manager")
local Unit = require("src.entities.unit")
local UnitAbilities = require("src.components.unit_abilities")
local ManaSystem = require("src.systems.mana_system")
local AbilityActivationSystem = require("src.systems.ability_activation_system")

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ local function world
local function world(options)
    local em = EntityManager:new()
    local mana = ManaSystem:new(em)
    local activation = AbilityActivationSystem:new(em, options)
    local function step(dt)
        mana:update(dt)
        activation:update(dt)
    end
    return em, activation, step
end
-- }}}

-- {{{ local function fill_all
local function fill_all(em, unit)
    for _, bar in ipairs(em:get_component(unit, "mana").bars) do
        bar.current = bar.max
    end
end
-- }}}

-- {{{ TestSuite.test_fires_when_full
function TestSuite.test_fires_when_full()
    local em, activation, step = world()
    local fighter = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    UnitAbilities.attach(em, fighter, {{name = "strike", type = "damage", power = 20, max_mana = 50, mana_rate = 10, range = 15}})
    local enemy = Unit.create_basic_unit(em, 10, 0, 2, "melee")

    local fired_at = nil
    for i = 1, 60 do
        step(0.1)
        local events = activation:pop_events()
        if #events > 0 then
            fired_at = i * 0.1
            local event = events[1]
            assert(event.caster == fighter and event.targets[1].entity == enemy, "Aimed at the enemy")
            assert(event.index == 1 and event.ability.name == "strike", "The strike fired")
            assert_near(event.mana_spent, 50, "A healthy target takes the whole bar")
            break
        end
    end
    assert(fired_at and math.abs(fired_at - 5.0) < 1e-6, "Fires the update the bar fills (5 s at 10 a second), got " .. tostring(fired_at))
    assert_near(em:get_component(fighter, "mana").bars[1].current, 0, "The bar is spent")
    assert(em:get_component(fighter, "abilities").last_target == enemy, "Remembers its target")

    print("✓ Fires when full test passed")
end
-- }}}

-- {{{ TestSuite.test_waits_for_a_target
function TestSuite.test_waits_for_a_target()
    local em, activation, step = world()
    local archer = Unit.create_basic_unit(em, 0, 0, 1, "ranged")
    UnitAbilities.attach(em, archer, {{name = "shot", type = "damage", range = 30}})
    local enemy = Unit.create_basic_unit(em, 100, 0, 2, "melee")
    fill_all(em, archer)

    for _ = 1, 10 do step(0.1) end
    assert(#activation:pop_events() == 0, "Nothing in range, nothing fired")
    assert(activation.stats.failure_reasons.no_targets == 1, "The wait is recorded once, not every frame")
    assert_near(em:get_component(archer, "mana").bars[1].current, 100, "The bar stays full")

    em:get_component(enemy, "position").x = 25
    step(0.1)
    assert(#activation:pop_events() == 1, "Fires the moment a target arrives")

    print("✓ Waits for a target test passed")
end
-- }}}

-- {{{ TestSuite.test_priority_and_one_at_a_time
function TestSuite.test_priority_and_one_at_a_time()
    local em, activation, step = world()
    local cleric = Unit.create_basic_unit(em, 0, 0, 1, "support")
    UnitAbilities.attach(em, cleric, {
        {name = "smite", type = "damage", range = 30, mana_rate = 0},
        {name = "mend", type = "heal", range = 30, mana_rate = 0}
    })
    local ally = Unit.create_basic_unit(em, 10, 0, 1, "melee")
    Unit.damage_unit(em, ally, 50)
    Unit.create_basic_unit(em, 20, 0, 2, "melee")
    fill_all(em, cleric)

    step(0.01)
    local events = activation:pop_events()
    assert(#events == 1 and events[1].ability.name == "smite", "The primary fires first, and alone")
    step(0.1)
    assert(#activation:pop_events() == 0, "The global cooldown holds the second")
    step(0.15)
    events = activation:pop_events()
    assert(#events == 1 and events[1].ability.name == "mend" and events[1].targets[1].entity == ally, "Then the heal")

    -- An ability's own priority can put it first.
    local em2, activation2, step2 = world({abilities_per_update = 2, global_cooldown = 0})
    local medic = Unit.create_basic_unit(em2, 0, 0, 1, "support")
    UnitAbilities.attach(em2, medic, {
        {name = "smite", type = "damage", range = 30, mana_rate = 0},
        {name = "mend", type = "heal", range = 30, mana_rate = 0, priority = 0}
    })
    Unit.damage_unit(em2, Unit.create_basic_unit(em2, 10, 0, 1, "melee"), 50)
    Unit.create_basic_unit(em2, 20, 0, 2, "melee")
    fill_all(em2, medic)
    step2(0.01)
    events = activation2:pop_events()
    assert(#events == 2 and events[1].ability.name == "mend", "Configured to fire two, the heal first")

    print("✓ Priority and one at a time test passed")
end
-- }}}

-- {{{ TestSuite.test_efficiency
function TestSuite.test_efficiency()
    local em, activation, step = world()
    local fighter = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    UnitAbilities.attach(em, fighter, {{name = "strike", type = "damage", power = 50, range = 15, mana_rate = 0}})
    local enemy = Unit.create_basic_unit(em, 10, 0, 2, "melee")
    em:get_component(enemy, "health").current_hp = 20
    fill_all(em, fighter)

    step(0.01)
    local event = activation:pop_events()[1]
    assert_near(event.mana_spent, 40, "20 of 50 damage needed: 40 of 100 mana")
    assert_near(event.plan.effect_power, 0.4, "The effect is planned at 40% strength")
    assert_near(em:get_component(fighter, "mana").bars[1].current, 60, "The rest stays in the bar")
    assert_near(activation.mana_stats.mana_saved, 60, "Saved mana is counted")

    local em2, activation2, step2 = world()
    local healer = Unit.create_basic_unit(em2, 0, 0, 1, "support")
    UnitAbilities.attach(em2, healer, {{name = "mend", type = "heal", range = 30, mana_rate = 0}})
    Unit.create_basic_unit(em2, 10, 0, 1, "melee")
    fill_all(em2, healer)
    step2(0.01)
    assert(#activation2:pop_events() == 0, "No heal when nobody is hurt")
    assert(activation2.stats.failure_reasons.target_full_health == 1, "Recorded as target_full_health")

    print("✓ Efficiency test passed")
end
-- }}}

-- {{{ TestSuite.test_disabled_units
function TestSuite.test_disabled_units()
    local em, activation, step = world()
    local function armed(x)
        local unit = Unit.create_basic_unit(em, x, 0, 1, "melee")
        UnitAbilities.attach(em, unit, {{name = "strike", type = "damage", range = 15, mana_rate = 0}})
        Unit.create_basic_unit(em, x + 10, 0, 2, "melee")
        fill_all(em, unit)
        return unit
    end
    local stunned = armed(0)
    em:get_component(stunned, "unit_data").is_stunned = true
    local silenced = armed(100)
    em:add_component(silenced, "effects", {active = {hush = {silence = true}}})
    local fleeing = armed(200)
    em:get_component(fleeing, "unit_data").combat_state = "retreating"
    local hesitant = armed(300)
    em:get_component(hesitant, "abilities").abilities[1].activation_conditions = {{type = "health_percentage", operator = "<", value = 50}}

    step(0.01)
    assert(#activation:pop_events() == 0, "None of them fire")
    assert(em:get_component(stunned, "abilities").blocked_reason == "stunned", "Stunned")
    assert(em:get_component(silenced, "abilities").blocked_reason == "silenced", "Silenced")
    assert(em:get_component(fleeing, "abilities").blocked_reason == "retreating", "Retreating")
    assert(activation.stats.failure_reasons["condition_failed:health_percentage"] == 1, "A failed condition is recorded")

    em:get_component(stunned, "unit_data").is_stunned = false
    step(0.01)
    local events = activation:pop_events()
    assert(#events == 1 and events[1].caster == stunned, "Fires once the stun ends")

    print("✓ Disabled units test passed")
end
-- }}}

-- {{{ TestSuite.test_cooldown
function TestSuite.test_cooldown()
    local em, activation, step = world()
    local fighter = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    UnitAbilities.attach(em, fighter, {{name = "cleave", type = "damage", max_mana = 10, mana_rate = 100, cooldown = 2, range = 15}})
    Unit.create_basic_unit(em, 10, 0, 2, "tank")

    local times = {}
    for i = 1, 50 do
        step(0.1)
        for _ = 1, #activation:pop_events() do
            table.insert(times, i * 0.1)
        end
    end
    assert(#times >= 2, "Fired more than once")
    assert(times[2] - times[1] >= 2 - 1e-6, "The cooldown spaces casts even when the bar refills at once")

    print("✓ Cooldown test passed")
end
-- }}}

-- {{{ TestSuite.test_integration
function TestSuite.test_integration()
    local received = {}
    local effects = {process_ability_activation = function(self, event) table.insert(received, event) end}
    local em = EntityManager:new()
    local manager = SystemManager:new(em)
    local mana = ManaSystem:new(em)
    mana.name, mana.is_enabled = "mana", function() return true end
    local activation = AbilityActivationSystem:new(em, {effect_system = effects})
    manager:add_system(mana, 1)
    manager:add_system(activation, 2)

    local fighter = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    UnitAbilities.attach(em, fighter, {{name = "strike", type = "damage", range = 15, max_mana = 10, mana_rate = 10}})
    Unit.create_basic_unit(em, 10, 0, 2, "melee")
    for _ = 1, 11 do manager:update(0.1) end
    assert(#received == 1 and received[1].ability.name == "strike", "A SystemManager runs it and the effect system gets the event")

    local called = 0
    local direct = AbilityActivationSystem:new(em, {on_activate = function() called = called + 1 end})
    fill_all(em, fighter)
    direct:update(0.3)     -- past the global cooldown from the last cast
    assert(called == 1, "on_activate is called")

    print("✓ Integration test passed")
end
-- }}}

-- {{{ TestSuite.test_performance
function TestSuite.test_performance()
    local em, activation, step = world()
    local configs = {
        {type = "damage", range = 30, mana_rate = 150},
        {type = "heal", range = 30, mana_rate = 30},
        {type = "area", range = 40, area_radius = 15, mana_rate = 20}
    }
    for i = 1, 200 do
        local unit = Unit.create_basic_unit(em, (i % 20) * 12, math.floor(i / 20) * 12, (i % 2) + 1, "melee")
        UnitAbilities.attach(em, unit, configs)
    end
    local start = os.clock()
    for _ = 1, 60 do
        step(1 / 60)
    end
    local elapsed = os.clock() - start
    print(string.format("  200 units, 60 frames: %.3fs, %d activations", elapsed, activation.stats.activations))
    assert(activation.stats.activations > 0, "Abilities fired")
    assert(elapsed < 3.0, "One second of play for 200 units stays cheap")

    print("✓ Performance test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Ability Activation Tests...")
    print(string.rep("=", 40))

    TestSuite.test_fires_when_full()
    TestSuite.test_waits_for_a_target()
    TestSuite.test_priority_and_one_at_a_time()
    TestSuite.test_efficiency()
    TestSuite.test_disabled_units()
    TestSuite.test_cooldown()
    TestSuite.test_integration()
    TestSuite.test_performance()

    print(string.rep("=", 40))
    print("✅ All ability activation tests passed!")
end
-- }}}

return TestSuite
-- }}}
