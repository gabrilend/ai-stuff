-- {{{ Shield Destruction Mechanics Test Suite
-- Checks issue 039 without a window: each vulnerability trigger, what a
-- vulnerability window does, the warning events, and the 30-second seal
-- that stops a base losing shields too quickly.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_shield_destruction').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Base = require("src.entities.base")
local DefenseShield = require("src.entities.defense_shield")
local Mechanics = require("src.systems.shield_destruction_mechanics")

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
    return entity_manager, base, Base.get_shields(entity_manager, base)
end
-- }}}

-- {{{ local function vulnerable_events
local function vulnerable_events(entity_manager, base)
    local found = {}
    for _, event in ipairs(Base.pop_events(entity_manager, base)) do
        if event.type == "shield_vulnerable" then
            table.insert(found, event)
        end
    end
    return found
end
-- }}}

-- {{{ TestSuite.test_light_pressure_opens_nothing
function TestSuite.test_light_pressure_opens_nothing()
    local em, base, shields = new_base()
    for _ = 1, 3 do
        Base.apply_damage(em, base, 10, 1, 101)   -- one attacker, small hits
        Base.update(em, base, 1.0)
    end
    assert(not Mechanics.is_vulnerable(shields[1]), "A single light attacker opens no window")
    assert(#vulnerable_events(em, base) == 0, "No warning without a trigger")

    print("✓ Light pressure opens nothing test passed")
end
-- }}}

-- {{{ TestSuite.test_concentrated_fire
function TestSuite.test_concentrated_fire()
    local em, base, shields = new_base()
    Base.apply_damage(em, base, 5, 1, 101)
    Base.apply_damage(em, base, 5, 1, 102)
    assert(not Mechanics.is_vulnerable(shields[1]), "Two attackers are not enough")
    Base.apply_damage(em, base, 5, 1, 103)
    assert(Mechanics.is_vulnerable(shields[1]), "Three attackers within two seconds open a window")

    local events = vulnerable_events(em, base)
    assert(#events == 1, "One warning event")
    assert(events[1].reason == "concentrated" and events[1].shield_index == 1, "Warning names the trigger")
    assert(events[1].duration == Mechanics.VULNERABLE_DURATION, "Warning says how long")

    local em2, base2, shields2 = new_base()
    Base.apply_damage(em2, base2, 5, 1, 101)
    Base.update(em2, base2, Mechanics.HIT_WINDOW + 0.5)
    Base.apply_damage(em2, base2, 5, 1, 102)
    Base.apply_damage(em2, base2, 5, 1, 103)
    assert(not Mechanics.is_vulnerable(shields2[1]), "Hits spread over time are not concentrated")

    print("✓ Concentrated fire test passed")
end
-- }}}

-- {{{ TestSuite.test_overload
function TestSuite.test_overload()
    local em, base, shields = new_base()
    local threshold = shields[1].max_hp * Mechanics.OVERLOAD_FRACTION
    Base.apply_damage(em, base, threshold * 0.6, 1, 101)
    assert(not Mechanics.is_vulnerable(shields[1]), "Under the overload amount")
    Base.apply_damage(em, base, threshold * 0.6, 1, 101)
    assert(Mechanics.is_vulnerable(shields[1]), "A fifth of a shield's health in two seconds overloads it")
    assert(shields[1].vulnerable_reason == "overload", "Reason is overload")

    print("✓ Overload test passed")
end
-- }}}

-- {{{ TestSuite.test_critical_health
function TestSuite.test_critical_health()
    local em, base, shields = new_base()
    local shield = shields[1]
    -- Wear the shield down slowly so no other trigger fires first.
    while shield.current_hp > shield.max_hp * 0.3 do
        Base.apply_damage(em, base, 10, 1, 101)
        Base.update(em, base, 1.0)
    end
    assert(not Mechanics.is_vulnerable(shield), "Not vulnerable above a quarter")
    Base.apply_damage(em, base, shield.current_hp - shield.max_hp * 0.2, 1, 101)
    assert(Mechanics.is_vulnerable(shield) and shield.vulnerable_reason == "critical",
        "Dropping below a quarter opens a window")

    -- Once the window closes, more chip damage below a quarter does not
    -- reopen it: the trigger fires once until the shield repairs past half.
    Base.update(em, base, Mechanics.VULNERABLE_DURATION)
    Base.apply_damage(em, base, 1, 1, 101)
    assert(not Mechanics.is_vulnerable(shield), "Critical fires once per dip")

    print("✓ Critical health test passed")
end
-- }}}

-- {{{ TestSuite.test_synchronized_assault
function TestSuite.test_synchronized_assault()
    local em, base, shields = new_base()
    Base.damage_shield(em, base, shields[2], 5, 1, 101)
    assert(not Mechanics.is_vulnerable(shields[2]), "One shield under attack is not synchronized")
    Base.damage_shield(em, base, shields[3], 5, 1, 102)
    assert(Mechanics.is_vulnerable(shields[3]) and shields[3].vulnerable_reason == "synchronized",
        "A second shield hit within two seconds is vulnerable")

    print("✓ Synchronized assault test passed")
end
-- }}}

-- {{{ TestSuite.test_window_effects
function TestSuite.test_window_effects()
    local em, base, shields = new_base()
    local shield = shields[1]
    Base.apply_damage(em, base, 5, 1, 101)
    Base.apply_damage(em, base, 5, 1, 102)
    Base.apply_damage(em, base, 5, 1, 103)
    assert(Mechanics.is_vulnerable(shield), "Window open")

    local before = shield.current_hp
    local dealt = Base.apply_damage(em, base, 10, 1, 101)
    assert_near(dealt, 15, "Vulnerable shields take 50% more damage")
    assert_near(shield.current_hp, before - 15, "Health reflects the raised damage")

    -- No repair while the window is open, even long after the last hit.
    local held = shield.current_hp
    Base.update(em, base, Mechanics.VULNERABLE_DURATION - 0.1)
    assert_near(shield.current_hp, held, "No repair inside the window")
    assert(DefenseShield.get_status(shields)[1].vulnerable, "Status rows show the window for drawing")

    Base.update(em, base, 0.2)
    assert(not Mechanics.is_vulnerable(shield), "Window closes after five seconds")
    assert_near(Base.apply_damage(em, base, 10, 1, 104), 10, "Damage back to normal")

    print("✓ Window effects test passed")
end
-- }}}

-- {{{ TestSuite.test_destruction_seal
function TestSuite.test_destruction_seal()
    local em, base, shields = new_base()
    Base.apply_damage(em, base, shields[1].max_hp, 1, 101)
    assert(not shields[1].active, "First shield breaks")
    assert(Mechanics.is_sealed(em:get_component(base, "base"), 0), "Base is sealed")

    local dealt = Base.apply_damage(em, base, shields[2].max_hp * 5, 1, 101)
    assert(shields[2].active, "A sealed shield cannot fall")
    assert_near(shields[2].current_hp, 1, "It is held at 1 health")
    assert_near(dealt, shields[2].max_hp - 1, "Damage still lands up to that point")
    assert(Base.apply_damage(em, base, 50, 1, 101) == 0, "Nothing more gets through while sealed")

    local health = em:get_component(base, "health")
    assert_near(health.current_hp, health.max_hp, "The core is still protected")

    -- The held shield repairs while the seal lasts, so break it with a
    -- full-sized hit once the seal is over.
    Base.update(em, base, Mechanics.DESTRUCTION_COOLDOWN)
    assert(not Mechanics.is_sealed(em:get_component(base, "base"), em:get_component(base, "base").clock),
        "Seal lifts after 30 seconds")
    Base.apply_damage(em, base, shields[2].max_hp, 1, 101)
    assert(not shields[2].active, "After 30 seconds the next shield can fall")

    print("✓ Destruction seal test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Shield Destruction Mechanics Tests...")
    print(string.rep("=", 40))

    TestSuite.test_light_pressure_opens_nothing()
    TestSuite.test_concentrated_fire()
    TestSuite.test_overload()
    TestSuite.test_critical_health()
    TestSuite.test_synchronized_assault()
    TestSuite.test_window_effects()
    TestSuite.test_destruction_seal()

    print(string.rep("=", 40))
    print("✅ All shield destruction mechanics tests passed!")
end
-- }}}

return TestSuite
-- }}}
