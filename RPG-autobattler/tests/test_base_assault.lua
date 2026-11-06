-- {{{ Base Assault Test Suite
-- Checks issue 040b without a window: units walk up to the enemy base,
-- hit its front shield with their normal attack, reach the core once the
-- shields are gone, hold off while an enemy unit is in reach, stop while
-- being reset, and three attackers together count as concentrated fire.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_base_assault').run_all()"
local TestSuite = {}

local Base = require("src.entities.base")
local Unit = require("src.entities.unit")
local Match = require("src.systems.match")
local BaseAssaultSystem = require("src.systems.base_assault_system")

local FRAME = 1 / 60

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ local function run
-- Runs the match for `seconds`, returning every event.
local function run(match, seconds)
    local events = {}
    for _ = 1, math.floor(seconds / FRAME + 0.5) do
        match:update(FRAME)
        for _, event in ipairs(match:pop_events()) do
            table.insert(events, event)
        end
    end
    return events
end
-- }}}

-- {{{ local function of_type
local function of_type(events, event_type)
    local found = {}
    for _, event in ipairs(events) do
        if event.type == event_type then
            table.insert(found, event)
        end
    end
    return found
end
-- }}}

-- {{{ local function quiet_match
-- A match whose turrets always miss, so attackers live.
local function quiet_match(options)
    options = options or {}
    options.random = function() return 1 end
    return Match:new(options)
end
-- }}}

-- {{{ TestSuite.test_march_and_hit_the_front_shield
function TestSuite.test_march_and_hit_the_front_shield()
    local match = quiet_match()
    local em = match.entity_manager
    local base = match:get_base(2)
    local front = Base.get_shields(em, base)[1]
    local core = em:get_component(base, "health")
    local unit = match:spawn_unit(1, "melee", front.x - 200, front.y)

    local events = run(match, 1.0)
    assert(#of_type(events, "base_attacked") == 0, "Too far to hit at first")
    assert(em:get_component(unit, "position").x > front.x - 200, "It walks toward the base")

    events = run(match, 10.0)
    local pos = em:get_component(unit, "position")
    local distance = math.sqrt((pos.x - front.x) ^ 2 + (pos.y - front.y) ^ 2)
    assert_near(distance, 15 + BaseAssaultSystem.SHIELD_RADIUS, "It stops at its reach from the shield", 1e-3)

    local hits = of_type(events, "base_attacked")
    assert(#hits >= 3, "It hits once a second after arriving, got " .. #hits)
    assert(hits[1].attacker == unit and hits[1].target == "shield" and hits[1].defending_team == 2, "Hits name the attacker and the shield")
    assert(front.current_hp < front.max_hp, "The front shield took the hits")
    assert(core.current_hp == core.max_hp, "The core is untouched while a shield stands")

    print("✓ March and hit the front shield test passed")
end
-- }}}

-- {{{ TestSuite.test_core_once_shields_fall
function TestSuite.test_core_once_shields_fall()
    local match = quiet_match()
    local em = match.entity_manager
    local base = match:get_base(2)
    for _, shield in ipairs(Base.get_shields(em, base)) do
        shield.active = false
    end
    local pos = em:get_component(base, "position")
    local core = em:get_component(base, "health")
    match:spawn_unit(1, "melee", pos.x - 150, pos.y)

    local events = run(match, 8.0)
    local hits = of_type(events, "base_attacked")
    assert(#hits > 0 and hits[1].target == "core", "With no shields, units hit the core")
    assert(core.current_hp < core.max_hp, "The core took damage")

    print("✓ Core once shields fall test passed")
end
-- }}}

-- {{{ TestSuite.test_enemy_unit_in_reach
function TestSuite.test_enemy_unit_in_reach()
    local match = quiet_match()
    local em = match.entity_manager
    local front = Base.get_shields(em, match:get_base(2))[1]
    local attacker = match:spawn_unit(1, "melee", front.x - 20, front.y)
    local defender = match:spawn_unit(2, "melee", front.x - 30, front.y)

    local events = run(match, 2.0)
    assert(#of_type(events, "base_attacked") == 0, "An enemy unit in reach comes first")
    assert(em:get_component(attacker, "position").x == front.x - 20, "And the attacker doesn't walk past it")

    Unit.damage_unit(em, defender, 10000)
    events = run(match, 2.0)
    assert(#of_type(events, "base_attacked") > 0, "Once the defender falls, the base is next")

    print("✓ Enemy unit in reach test passed")
end
-- }}}

-- {{{ TestSuite.test_reach_by_type
function TestSuite.test_reach_by_type()
    local match = quiet_match()
    local em = match.entity_manager
    local front = Base.get_shields(em, match:get_base(2))[1]
    local archer = match:spawn_unit(1, "ranged", front.x - 200, front.y)
    run(match, 10.0)
    local pos = em:get_component(archer, "position")
    assert_near(front.x - pos.x, 30 + BaseAssaultSystem.SHIELD_RADIUS, "Ranged units stop at their own range", 1e-3)

    local still = quiet_match({march = false})
    local far = still:spawn_unit(1, "melee", 300, 384)
    local events = run(still, 2.0)
    assert(still.entity_manager:get_component(far, "position").x == 300, "With march off, units stay put")
    assert(#of_type(events, "base_attacked") == 0, "And can't reach the base")

    print("✓ Reach by type test passed")
end
-- }}}

-- {{{ TestSuite.test_reset_units_stop
function TestSuite.test_reset_units_stop()
    local match = quiet_match()
    local em = match.entity_manager
    local front = Base.get_shields(em, match:get_base(2))[1]
    local unit = match:spawn_unit(1, "melee", front.x - 20, front.y)
    em:get_component(unit, "unit_data").reset_in_progress = true
    local events = run(match, 2.0)
    assert(#of_type(events, "base_attacked") == 0, "A unit being reset doesn't attack")

    print("✓ Reset units stop test passed")
end
-- }}}

-- {{{ TestSuite.test_concentrated_fire
function TestSuite.test_concentrated_fire()
    local match = quiet_match()
    local em = match.entity_manager
    local front = Base.get_shields(em, match:get_base(2))[1]
    for i = -1, 1 do
        match:spawn_unit(1, "melee", front.x - 20, front.y + i * 5)
    end
    local events = run(match, 3.0)
    local vulnerable = of_type(events, "shield_vulnerable")
    assert(#vulnerable >= 1 and vulnerable[1].reason == "concentrated", "Three attackers together make the shield vulnerable")

    print("✓ Concentrated fire test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Base Assault Tests...")
    print(string.rep("=", 40))

    TestSuite.test_march_and_hit_the_front_shield()
    TestSuite.test_core_once_shields_fall()
    TestSuite.test_enemy_unit_in_reach()
    TestSuite.test_reach_by_type()
    TestSuite.test_reset_units_stop()
    TestSuite.test_concentrated_fire()

    print(string.rep("=", 40))
    print("✅ All base assault tests passed!")
end
-- }}}

return TestSuite
-- }}}
