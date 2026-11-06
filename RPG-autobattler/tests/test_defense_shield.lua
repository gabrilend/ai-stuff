-- {{{ Defense Shield Test Suite
-- Checks the three defence shields of a base (issue 037) without a window:
-- their health, the order they fall in, that the core is safe while any
-- stands, repair, and the "shield_destroyed" events.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_defense_shield').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Base = require("src.entities.base")
local DefenseShield = require("src.entities.defense_shield")
local BaseHealthSystem = require("src.systems.base_health_system")
local ShieldMechanics = require("src.systems.shield_destruction_mechanics")

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ local function new_base
local function new_base()
    local entity_manager = EntityManager:new()
    local base = Base.create_base(entity_manager, 2, {x = 900, y = 300}, "standard")
    return entity_manager, base
end
-- }}}

-- {{{ TestSuite.test_three_shields_make_twenty_units
function TestSuite.test_three_shields_make_twenty_units()
    local entity_manager, base = new_base()
    local shields = Base.get_shields(entity_manager, base)

    assert(#shields == 3, "A base has three shields by default")
    for _, shield in ipairs(shields) do
        assert_near(shield.max_hp, Base.AVERAGE_UNIT_HEALTH * 5, "Each shield holds five average units")
        assert(shield.active, "Shields start standing")
    end

    local _, maximum = Base.get_total_health(entity_manager, base)
    assert_near(maximum / Base.AVERAGE_UNIT_HEALTH, 20, "Core plus shields is twenty average units")

    print("✓ Three shields make twenty units test passed")
end
-- }}}

-- {{{ TestSuite.test_shields_face_the_enemy
function TestSuite.test_shields_face_the_enemy()
    local entity_manager, base = new_base()
    local position = entity_manager:get_component(base, "position")
    local shields = Base.get_shields(entity_manager, base)

    -- Team 2 faces left by default, so its front shield is left of the base.
    assert(shields[1].x < position.x, "Front shield sits between the base and the enemy")
    assert_near(shields[1].y, position.y, "Front shield is straight ahead")
    assert(shields[2].y ~= shields[3].y, "Side shields sit on opposite sides")
    for _, shield in ipairs(shields) do
        local dx, dy = shield.x - position.x, shield.y - position.y
        assert_near(math.sqrt(dx * dx + dy * dy), DefenseShield.RING_RADIUS, "Shields ring the base", 1e-4)
    end

    print("✓ Shields face the enemy test passed")
end
-- }}}

-- {{{ TestSuite.test_core_safe_while_shields_stand
function TestSuite.test_core_safe_while_shields_stand()
    local entity_manager, base = new_base()
    local health = entity_manager:get_component(base, "health")
    local shields = Base.get_shields(entity_manager, base)

    local dealt = Base.apply_damage(entity_manager, base, 100, 1)
    assert_near(dealt, 100, "The hit is absorbed in full")
    assert_near(health.current_hp, health.max_hp, "Core untouched while a shield stands")
    assert_near(shields[1].current_hp, shields[1].max_hp - 100, "Front shield took the hit")
    assert_near(shields[2].current_hp, shields[2].max_hp, "Second shield untouched")

    print("✓ Core safe while shields stand test passed")
end
-- }}}

-- {{{ TestSuite.test_shields_fall_one_at_a_time
function TestSuite.test_shields_fall_one_at_a_time()
    local entity_manager, base = new_base()
    local health = entity_manager:get_component(base, "health")
    local shields = Base.get_shields(entity_manager, base)

    -- A hit far bigger than a shield breaks only the front one; the rest
    -- is lost, so each shield's fall gets its own reset.
    local dealt = Base.apply_damage(entity_manager, base, shields[1].max_hp * 10, 1)
    assert_near(dealt, shields[1].max_hp, "Only the front shield's health is removed")
    assert(not shields[1].active, "Front shield is down")
    assert(shields[2].active and shields[3].active, "Other shields still stand")
    assert(shields[1].destroyed_by == 1, "Shield remembers who broke it")

    -- After each fall the others are sealed for a while (issue 039), so
    -- let that pass before breaking the next one.
    Base.update(entity_manager, base, ShieldMechanics.DESTRUCTION_COOLDOWN)
    Base.apply_damage(entity_manager, base, shields[2].max_hp, 1)
    assert(not shields[2].active and shields[3].active, "Shields fall in order")
    Base.update(entity_manager, base, ShieldMechanics.DESTRUCTION_COOLDOWN)
    Base.apply_damage(entity_manager, base, shields[3].max_hp, 1)
    assert(DefenseShield.count_active(shields) == 0, "All shields down")
    assert_near(health.current_hp, health.max_hp, "Core still untouched")

    Base.apply_damage(entity_manager, base, 50, 1)
    assert_near(health.current_hp, health.max_hp - 50, "With shields gone, hits reach the core")

    print("✓ Shields fall one at a time test passed")
end
-- }}}

-- {{{ TestSuite.test_direct_shield_attack
function TestSuite.test_direct_shield_attack()
    local entity_manager, base = new_base()
    local shields = Base.get_shields(entity_manager, base)

    Base.damage_shield(entity_manager, base, shields[3], shields[3].max_hp, 1)
    assert(not shields[3].active, "A side shield can be attacked directly")
    assert(DefenseShield.get_front_shield(shields) == shields[1], "Front shield is still shield 1")
    assert(Base.damage_shield(entity_manager, base, shields[3], 10, 1) == 0, "A fallen shield takes no damage")

    print("✓ Direct shield attack test passed")
end
-- }}}

-- {{{ TestSuite.test_shield_regeneration
function TestSuite.test_shield_regeneration()
    local entity_manager, base = new_base()
    local shields = Base.get_shields(entity_manager, base)

    Base.apply_damage(entity_manager, base, 40, 1)
    local damaged = shields[1].current_hp

    Base.update(entity_manager, base, DefenseShield.REGEN_DELAY)
    assert_near(shields[1].current_hp, damaged, "No repair until the delay has passed")
    Base.update(entity_manager, base, 5)
    assert_near(shields[1].current_hp, damaged + DefenseShield.REGEN_RATE * 5, "Repairs 2 health per second")
    Base.update(entity_manager, base, 1000)
    assert_near(shields[1].current_hp, shields[1].max_hp, "Repair stops at full")

    Base.apply_damage(entity_manager, base, shields[1].max_hp, 1)
    Base.update(entity_manager, base, 1000)
    assert(not shields[1].active and shields[1].current_hp == 0, "A destroyed shield never comes back")

    print("✓ Shield regeneration test passed")
end
-- }}}

-- {{{ TestSuite.test_shield_events
function TestSuite.test_shield_events()
    local entity_manager, base = new_base()
    local system = BaseHealthSystem:new(entity_manager)
    local shields = Base.get_shields(entity_manager, base)

    Base.apply_damage(entity_manager, base, shields[1].max_hp, 1)
    system:update(0.016)
    local events = system:pop_events()
    assert(#events == 1, "One event per fallen shield, got " .. #events)
    local event = events[1]
    assert(event.type == "shield_destroyed", "Event type")
    assert(event.team == 2 and event.destroyed_by == 1, "Event names defender and attacker")
    assert(event.shield_index == 1 and event.shields_remaining == 2, "Event names the shield and what is left")

    system:update(0.016)
    assert(#system:pop_events() == 0, "Events are reported once")
    assert(not system:is_game_over(), "Losing a shield does not end the match")

    local status = DefenseShield.get_status(shields)
    assert(#status == 3 and status[1].active == false and status[2].fraction == 1, "Status rows for drawing")

    print("✓ Shield events test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Defense Shield Tests...")
    print(string.rep("=", 40))

    TestSuite.test_three_shields_make_twenty_units()
    TestSuite.test_shields_face_the_enemy()
    TestSuite.test_core_safe_while_shields_stand()
    TestSuite.test_shields_fall_one_at_a_time()
    TestSuite.test_direct_shield_attack()
    TestSuite.test_shield_regeneration()
    TestSuite.test_shield_events()

    print(string.rep("=", 40))
    print("✅ All defense shield tests passed!")
end
-- }}}

return TestSuite
-- }}}
