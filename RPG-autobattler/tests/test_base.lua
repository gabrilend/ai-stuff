-- {{{ Base Entity Test Suite
-- Checks the base entity (issue 036) without a window: health pool size,
-- damage sections, integrity, base types, self-repair and the victory event.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_base').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Base = require("src.entities.base")
local BaseHealthSystem = require("src.systems.base_health_system")

-- These tests look at the core alone, so their bases are built without
-- shields; tests/test_defense_shield.lua covers the shields (issue 037).
local CORE_ONLY = {shield_count = 0}

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ local function new_world
local function new_world()
    local entity_manager = EntityManager:new()
    local base_a = Base.create_base(entity_manager, 1, {x = 50, y = 300}, "standard", CORE_ONLY)
    local base_b = Base.create_base(entity_manager, 2, {x = 950, y = 300}, "standard", CORE_ONLY)
    return entity_manager, base_a, base_b
end
-- }}}

-- {{{ TestSuite.test_core_health_pool
function TestSuite.test_core_health_pool()
    local entity_manager, base_a = new_world()
    local health = entity_manager:get_component(base_a, "health")

    assert(Base.AVERAGE_UNIT_HEALTH > 0, "Average unit health should be positive")
    assert_near(health.max_hp, Base.AVERAGE_UNIT_HEALTH * 5, "Standard core holds five average units")
    assert(health.current_hp == health.max_hp, "Base starts at full health")
    assert(Base.is_base(entity_manager, base_a), "Entity should be recognised as a base")
    assert(entity_manager:get_component(base_a, "position").is_static, "Bases do not move")

    print("✓ Core health pool test passed")
end
-- }}}

-- {{{ TestSuite.test_base_types
function TestSuite.test_base_types()
    local entity_manager = EntityManager:new()
    local seen_health = {}
    for base_type, type_data in pairs(Base.TYPES) do
        local entity = Base.create_base(entity_manager, 1, {x = 0, y = 0}, base_type)
        local health = entity_manager:get_component(entity, "health")
        assert_near(health.max_hp, Base.get_core_max_health(base_type), base_type .. " health")
        seen_health[base_type] = health.max_hp
    end
    assert(seen_health.fortress > seen_health.standard, "Fortress should outlast standard")
    assert(seen_health.command_center > seen_health.fortified, "Command center has the largest pool")

    local ok = pcall(Base.create_base, entity_manager, 1, {x = 0, y = 0}, "sandcastle")
    assert(not ok, "Unknown base types should be refused")

    print("✓ Base types test passed")
end
-- }}}

-- {{{ TestSuite.test_damage_reduction
function TestSuite.test_damage_reduction()
    local entity_manager = EntityManager:new()
    local standard = Base.create_base(entity_manager, 1, {x = 0, y = 0}, "standard", CORE_ONLY)
    local fortress = Base.create_base(entity_manager, 2, {x = 0, y = 0}, "fortress", CORE_ONLY)

    assert_near(Base.apply_damage(entity_manager, standard, 100, 2), 100, "Standard takes full damage")
    assert_near(Base.apply_damage(entity_manager, fortress, 100, 1), 75, "Fortress shrugs off a quarter")
    assert(Base.apply_damage(entity_manager, standard, 0, 2) == 0, "Zero damage does nothing")
    assert(Base.apply_damage(entity_manager, standard, -5, 2) == 0, "Negative damage does nothing")

    print("✓ Damage reduction test passed")
end
-- }}}

-- {{{ TestSuite.test_damage_sections_and_integrity
function TestSuite.test_damage_sections_and_integrity()
    local entity_manager, base_a = new_world()
    local base = entity_manager:get_component(base_a, "base")
    local max_hp = entity_manager:get_component(base_a, "health").max_hp

    assert(base.damage_section == "pristine", "Starts pristine")
    assert(Base.get_effectiveness(entity_manager, base_a) == 1.0, "Pristine base is fully effective")

    local expected = {
        {fraction = 0.7, section = "damaged"},
        {fraction = 0.5, section = "battered"},
        {fraction = 0.3, section = "critical"},
        {fraction = 0.1, section = "failing"}
    }
    local last_effectiveness = 1.0
    for _, step in ipairs(expected) do
        local health = entity_manager:get_component(base_a, "health")
        Base.apply_damage(entity_manager, base_a, health.current_hp - max_hp * step.fraction, 2)
        assert(base.damage_section == step.section,
            "At " .. step.fraction .. " health expected " .. step.section .. ", got " .. base.damage_section)
        local effectiveness = Base.get_effectiveness(entity_manager, base_a)
        assert(effectiveness < last_effectiveness, "Integrity should fall with each section")
        last_effectiveness = effectiveness
    end

    local dim = Base.get_render_color(entity_manager, base_a)
    local renderable = entity_manager:get_component(base_a, "renderable")
    assert(dim[1] <= renderable.color[1] and dim[3] <= renderable.color[3], "Damaged base draws dimmer")

    print("✓ Damage sections and integrity test passed")
end
-- }}}

-- {{{ TestSuite.test_regeneration
function TestSuite.test_regeneration()
    local entity_manager, base_a = new_world()
    local health = entity_manager:get_component(base_a, "health")
    local base = entity_manager:get_component(base_a, "base")

    Base.apply_damage(entity_manager, base_a, 50, 2)
    local damaged_hp = health.current_hp

    Base.update(entity_manager, base_a, Base.REGEN_DELAY - 1)
    assert_near(health.current_hp, damaged_hp, "No repair while recently damaged")

    Base.update(entity_manager, base_a, 1)     -- reaches the delay
    Base.update(entity_manager, base_a, 10)    -- ten seconds of repair
    assert_near(health.current_hp, damaged_hp + base.regen_rate * 10, "Repairs at regen_rate per second")

    Base.update(entity_manager, base_a, 1000)
    assert_near(health.current_hp, health.max_hp, "Repair stops at full health")

    Base.apply_damage(entity_manager, base_a, 20, 2)
    assert(base.time_since_damage == 0, "A new hit restarts the repair delay")

    print("✓ Regeneration test passed")
end
-- }}}

-- {{{ TestSuite.test_destruction_and_victory
function TestSuite.test_destruction_and_victory()
    local entity_manager, base_a, base_b = new_world()
    local system = BaseHealthSystem:new(entity_manager)

    system:update(0.1)
    assert(not system:is_game_over(), "No winner while both bases stand")
    assert(system:get_base_for_team(2) == base_b, "Can find a team's base")

    local health_b = entity_manager:get_component(base_b, "health")
    local dealt = Base.apply_damage(entity_manager, base_b, health_b.max_hp * 10, 1)
    assert_near(dealt, health_b.max_hp, "Overkill only removes remaining health")
    assert(Base.is_destroyed(entity_manager, base_b), "Base should be destroyed")
    assert(health_b.alive == false, "Destroyed base is not alive")
    assert(Base.get_effectiveness(entity_manager, base_b) == 0, "Destroyed base has no effectiveness")
    assert(Base.apply_damage(entity_manager, base_b, 10, 1) == 0, "Destroyed base takes no more damage")

    Base.update(entity_manager, base_b, 1000)
    assert(health_b.current_hp == 0, "Destroyed base never repairs")

    system:update(0.1)
    assert(system:is_game_over(), "Game should be over")
    assert(system:get_winner() == 1, "Team 1 destroyed team 2's base")

    local events = system:pop_events()
    assert(#events == 2, "Expected base_destroyed and victory events, got " .. #events)
    assert(events[1].type == "base_destroyed" and events[1].team == 2, "First event names the fallen base")
    assert(events[2].type == "victory" and events[2].winner == 1, "Second event names the winner")

    system:update(0.1)
    assert(#system:pop_events() == 0, "A destroyed base is reported once")

    print("✓ Destruction and victory test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Base Entity Tests...")
    print(string.rep("=", 40))

    TestSuite.test_core_health_pool()
    TestSuite.test_base_types()
    TestSuite.test_damage_reduction()
    TestSuite.test_damage_sections_and_integrity()
    TestSuite.test_regeneration()
    TestSuite.test_destruction_and_victory()

    print(string.rep("=", 40))
    print("✅ All base entity tests passed!")
end
-- }}}

return TestSuite
-- }}}
