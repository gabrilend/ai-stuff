-- {{{ Unit Reset Test Suite
-- Checks issue 040 without a window: a fallen shield removes every enemy
-- unit through the warning, collection and removal phases, the defenders
-- keep their units, late arrivals are caught, resets queue rather than
-- overlap, and the events and statistics add up.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_unit_reset').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Base = require("src.entities.base")
local Unit = require("src.entities.unit")
local BaseHealthSystem = require("src.systems.base_health_system")
local BaseTurretSystem = require("src.systems.base_turret_system")
local UnitResetSystem = require("src.systems.unit_reset_system")

-- {{{ local function new_world
-- Two bases, three attackers (team 1) at team 2's shields and two of team
-- 2's own defenders.
local function new_world()
    local em = EntityManager:new()
    local world = {
        em = em,
        base_1 = Base.create_base(em, 1, {x = 100, y = 300}, "standard"),
        base_2 = Base.create_base(em, 2, {x = 900, y = 300}, "standard"),
        health_system = BaseHealthSystem:new(em),
        reset = UnitResetSystem:new(em),
        attackers = {
            Unit.create_basic_unit(em, 840, 300, 1, "melee"),
            Unit.create_basic_unit(em, 830, 290, 1, "ranged"),
            Unit.create_basic_unit(em, 830, 310, 1, "tank")
        },
        defenders = {
            Unit.create_basic_unit(em, 880, 280, 2, "melee"),
            Unit.create_basic_unit(em, 880, 320, 2, "support")
        }
    }
    return world
end
-- }}}

-- {{{ local function step
-- One frame of the systems in the order a game would run them.
local function step(world, dt)
    world.health_system:update(dt)
    world.reset:handle_events(world.health_system:pop_events())
    world.reset:update(dt)
end
-- }}}

-- {{{ local function run_for
local function run_for(world, seconds)
    local dt = 1 / 60
    local elapsed = 0
    while elapsed < seconds - 1e-9 do
        step(world, dt)
        elapsed = elapsed + dt
    end
end
-- }}}

-- {{{ local function break_front_shield
local function break_front_shield(world, base, attacker_team)
    local shields = Base.get_shields(world.em, base)
    Base.apply_damage(world.em, base, shields[1].max_hp, attacker_team)
end
-- }}}

-- {{{ local function exists
local function exists(world, entity)
    return world.em:get_entity_by_id(entity.id) ~= nil
end
-- }}}

-- {{{ TestSuite.test_full_reset
function TestSuite.test_full_reset()
    local world = new_world()
    break_front_shield(world, world.base_2, 1)

    step(world, 1 / 60)
    assert(world.reset:is_resetting(), "A fallen shield starts a reset")
    local progress = world.reset:get_progress()
    assert(progress.phase == "warning" and progress.defending_team == 2, "Starts with the warning phase")
    local unit_data = world.em:get_component(world.attackers[1], "unit_data")
    assert(unit_data.state ~= "being_reset", "Units still act during the warning")

    run_for(world, 1.0)
    assert(world.reset:get_progress().phase == "collection", "Collection follows the one-second warning")
    for _, attacker in ipairs(world.attackers) do
        local data = world.em:get_component(attacker, "unit_data")
        local moveable = world.em:get_component(attacker, "moveable")
        assert(data.state == "being_reset" and data.reset_in_progress, "Attackers are marked")
        assert(moveable.speed == 0 and not moveable.is_moving, "Attackers stop moving")
        assert(exists(world, attacker), "Attackers are still on the map while collected")
    end

    run_for(world, 2.0)
    assert(not world.reset:is_resetting(), "Reset finishes after three seconds in all")
    for _, attacker in ipairs(world.attackers) do
        assert(not exists(world, attacker), "Every attacker has been removed")
    end
    for _, defender in ipairs(world.defenders) do
        assert(exists(world, defender), "Defenders keep their units")
        assert(world.em:get_component(defender, "unit_data").state ~= "being_reset", "Defenders are untouched")
    end
    assert(exists(world, world.base_1) and exists(world, world.base_2), "Bases are never removed")

    print("✓ Full reset test passed")
end
-- }}}

-- {{{ TestSuite.test_events_and_stats
function TestSuite.test_events_and_stats()
    local world = new_world()
    break_front_shield(world, world.base_2, 1)
    local seen = {}
    for _ = 1, 4 * 60 do
        step(world, 1 / 60)
        for _, event in ipairs(world.reset:pop_events()) do
            table.insert(seen, event)
        end
    end

    local names = {}
    for _, event in ipairs(seen) do
        table.insert(names, event.type)
    end
    local order = table.concat(names, ",")
    assert(order == "reset_warning,reset_collection,reset_removal,reset_completed",
        "Phase events in order, got " .. order)
    assert(seen[1].units == 3, "Warning says how many units will go")
    assert(seen[4].units_removed == 3, "Completion says how many went")

    local stats = world.reset:get_debug_info()
    assert(stats.resets_completed == 1 and stats.units_removed == 3, "Statistics count the reset")
    assert(world.reset.stats.resets_by_defender[2] == 1, "Statistics name the defender")

    print("✓ Events and stats test passed")
end
-- }}}

-- {{{ TestSuite.test_late_arrivals_are_removed
function TestSuite.test_late_arrivals_are_removed()
    local world = new_world()
    break_front_shield(world, world.base_2, 1)
    step(world, 1 / 60)

    local during_warning = Unit.create_basic_unit(world.em, 700, 300, 1, "melee")
    run_for(world, 1.5)  -- into collection
    local during_collection = Unit.create_basic_unit(world.em, 600, 300, 1, "special")
    step(world, 1 / 60)
    assert(world.em:get_component(during_collection, "unit_data").state == "being_reset",
        "A unit arriving during collection is stopped too")

    run_for(world, 2.0)
    assert(not exists(world, during_warning), "A unit spawned during the warning is removed")
    assert(not exists(world, during_collection), "A unit spawned during collection is removed")

    print("✓ Late arrivals are removed test passed")
end
-- }}}

-- {{{ TestSuite.test_no_enemies_no_reset
function TestSuite.test_no_enemies_no_reset()
    local em = EntityManager:new()
    local reset = UnitResetSystem:new(em)
    Unit.create_basic_unit(em, 880, 300, 2, "melee")
    assert(reset:trigger_reset(2, nil) == false, "Nothing to remove, nothing to run")
    assert(not reset:is_resetting(), "No reset running")
    assert(reset.stats.empty_triggers == 1, "The empty trigger is counted")

    print("✓ No enemies, no reset test passed")
end
-- }}}

-- {{{ TestSuite.test_resets_queue
function TestSuite.test_resets_queue()
    local world = new_world()
    -- Both sides lose a shield in the same frame.
    break_front_shield(world, world.base_2, 1)
    break_front_shield(world, world.base_1, 2)
    step(world, 1 / 60)
    assert(world.reset:get_progress().queued == 1, "The second reset waits its turn")

    run_for(world, 3.0)
    assert(world.reset:is_resetting(), "The queued reset starts when the first ends")
    run_for(world, 3.1)
    assert(not world.reset:is_resetting(), "Both resets finish")
    assert(world.reset.stats.resets_completed == 2, "Both resets ran")

    for _, unit in ipairs(world.attackers) do
        assert(not exists(world, unit), "Team 1's units removed for team 2's shield")
    end
    for _, unit in ipairs(world.defenders) do
        assert(not exists(world, unit), "Team 2's units removed for team 1's shield")
    end

    print("✓ Resets queue test passed")
end
-- }}}

-- {{{ TestSuite.test_turret_shots_fizzle
function TestSuite.test_turret_shots_fizzle()
    local world = new_world()
    local turret = BaseTurretSystem:new(world.em, {random = function() return 0 end})
    turret:update(1 / 60)
    assert(#turret:get_projectiles() >= 1, "Team 2's turret has a shot in flight at an attacker")

    -- What the removal phase does to the attackers.
    for _, attacker in ipairs(world.attackers) do
        world.em:remove_entity(attacker)
    end
    turret:update(1 / 60)
    assert(#turret:get_projectiles() == 0, "Shots at removed units fizzle without error")

    print("✓ Turret shots fizzle test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Unit Reset Tests...")
    print(string.rep("=", 40))

    TestSuite.test_full_reset()
    TestSuite.test_events_and_stats()
    TestSuite.test_late_arrivals_are_removed()
    TestSuite.test_no_enemies_no_reset()
    TestSuite.test_resets_queue()
    TestSuite.test_turret_shots_fizzle()

    print(string.rep("=", 40))
    print("✅ All unit reset tests passed!")
end
-- }}}

return TestSuite
-- }}}
