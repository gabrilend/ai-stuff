-- {{{ Base Turret Test Suite
-- Checks the base's automatic turret (issue 038) without a window: range,
-- the three targeting modes, turning before firing, projectiles, accuracy,
-- slower reload on a battered base, and silence once the base falls.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_base_turret').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Base = require("src.entities.base")
local Unit = require("src.entities.unit")
local BaseTurretSystem = require("src.systems.base_turret_system")

-- {{{ local function always_hit / always_miss
local function always_hit() return 0 end
local function always_miss() return 1 end
-- }}}

-- {{{ local function new_world
-- Team 1's base at (100, 300), facing right toward team 2.
local function new_world(random, base_options)
    local entity_manager = EntityManager:new()
    local base = Base.create_base(entity_manager, 1, {x = 100, y = 300}, "standard", base_options)
    local system = BaseTurretSystem:new(entity_manager, {random = random or always_hit})
    return entity_manager, base, system
end
-- }}}

-- {{{ local function run_for
local function run_for(system, seconds, step)
    step = step or 1 / 60
    local elapsed = 0
    while elapsed < seconds - 1e-9 do
        system:update(step)
        elapsed = elapsed + step
    end
end
-- }}}

-- {{{ TestSuite.test_turret_defaults
function TestSuite.test_turret_defaults()
    local _, base, system = new_world()
    local turret = system:get_turret(base)
    assert(turret.range == 100, "Range reaches 60 past the 40-pixel shield ring, got " .. turret.range)
    assert(turret.range - 40 > 45, "Turret outranges the longest ranged unit (45) shooting at a shield")
    assert(turret.damage == 25 and turret.accuracy == 0.9, "Damage and accuracy from the issue")
    assert(turret.angle == 0, "Team 1's turret starts facing right, toward the enemy")
    assert(turret.targeting_mode == "closest", "Default mode is closest")

    local ok = pcall(system.set_targeting_mode, system, base, "random")
    assert(not ok, "Unknown targeting modes are refused")

    print("✓ Turret defaults test passed")
end
-- }}}

-- {{{ TestSuite.test_target_selection_closest
function TestSuite.test_target_selection_closest()
    local em, base, system = new_world()
    local turret = system:get_turret(base)

    local friend = Unit.create_basic_unit(em, 120, 300, 1, "melee")
    local far_enemy = Unit.create_basic_unit(em, 250, 300, 2, "melee")      -- 150 away: out of range
    local near_enemy = Unit.create_basic_unit(em, 170, 300, 2, "melee")     -- 70 away
    local nearer_dead = Unit.create_basic_unit(em, 150, 300, 2, "melee")
    Unit.damage_unit(em, nearer_dead, 1000)

    assert(system:select_target(base, turret) == near_enemy, "Closest living enemy in range is chosen")
    assert(not system:is_valid_target(base, turret, friend), "Own units are never targets")
    assert(not system:is_valid_target(base, turret, far_enemy), "Units out of range are not targets")

    print("✓ Closest target selection test passed")
end
-- }}}

-- {{{ TestSuite.test_targeting_modes
function TestSuite.test_targeting_modes()
    local em, base, system = new_world()
    local turret = system:get_turret(base)

    local close_melee = Unit.create_basic_unit(em, 160, 300, 2, "melee")
    local far_ranged = Unit.create_basic_unit(em, 190, 300, 2, "ranged")
    local mid_tank = Unit.create_basic_unit(em, 175, 300, 2, "tank")
    Unit.damage_unit(em, mid_tank, 190) -- 10 health left

    system:set_targeting_mode(base, "highest_threat")
    assert(system:select_target(base, turret) == far_ranged, "Highest threat prefers the ranged unit")

    system:set_targeting_mode(base, "weakest")
    assert(system:select_target(base, turret) == mid_tank, "Weakest picks the unit with least health")

    system:set_targeting_mode(base, "closest")
    assert(system:select_target(base, turret) == close_melee, "Closest picks the nearest unit")

    print("✓ Targeting modes test passed")
end
-- }}}

-- {{{ TestSuite.test_turns_before_firing
function TestSuite.test_turns_before_firing()
    local em, base, system = new_world()
    local turret = system:get_turret(base)

    -- An enemy straight behind the base: the turret must turn half a circle
    -- at pi radians per second, so about one second passes before it fires.
    Unit.create_basic_unit(em, 30, 300, 2, "melee")
    run_for(system, 0.5)
    assert(system.stats.shots == 0, "No shot while still turning")
    run_for(system, 0.6)
    assert(system.stats.shots == 1, "Fires once lined up, got " .. system.stats.shots)
    assert(math.abs(math.abs(turret.angle) - math.pi) < 1e-6, "Turret now faces the enemy")
    local fired = system:pop_events()
    assert(#fired == 1 and fired[1].type == "turret_fired", "Firing is reported for effects")

    print("✓ Turns before firing test passed")
end
-- }}}

-- {{{ TestSuite.test_projectile_hits_and_misses
function TestSuite.test_projectile_hits_and_misses()
    local em, base, system = new_world(always_hit)
    local enemy = Unit.create_basic_unit(em, 170, 300, 2, "melee")
    local health = em:get_component(enemy, "health")

    system:update(1 / 60)
    assert(#system:get_projectiles() == 1, "A projectile is in flight")
    assert(system:get_turret(base).muzzle_flash > 0, "Muzzle flash shows right after firing")
    assert(health.current_hp == 120, "Damage waits for the projectile to arrive")
    run_for(system, 0.5)
    assert(health.current_hp == 95, "A hit removes 25 health, got " .. health.current_hp)
    assert(system.stats.hits == 1, "Hit counted")

    local em2, _, misser = new_world(always_miss)
    local enemy2 = Unit.create_basic_unit(em2, 170, 300, 2, "melee")
    run_for(misser, 0.5)
    assert(em2:get_component(enemy2, "health").current_hp == 120, "A missed shot does no damage")
    assert(misser.stats.misses == 1, "Miss counted")

    print("✓ Projectile hits and misses test passed")
end
-- }}}

-- {{{ TestSuite.test_kills_and_retargets
function TestSuite.test_kills_and_retargets()
    local em, base, system = new_world()
    local first = Unit.create_basic_unit(em, 160, 300, 2, "support")   -- 60 health
    local second = Unit.create_basic_unit(em, 180, 300, 2, "support")

    run_for(system, 3.5)
    assert(not Unit.is_alive(em, first), "Turret kills the first enemy")
    assert(system.stats.kills >= 1, "Kill counted")
    assert(system:get_turret(base).target == second, "Turret moves on to the next enemy")

    print("✓ Kills and retargets test passed")
end
-- }}}

-- {{{ TestSuite.test_battered_base_reloads_slower
function TestSuite.test_battered_base_reloads_slower()
    local em_a, _, healthy = new_world(always_miss, {shield_count = 0})
    Unit.create_basic_unit(em_a, 170, 300, 2, "tank")
    run_for(healthy, 10)

    local em_b, base_b, battered = new_world(always_miss, {shield_count = 0})
    Unit.create_basic_unit(em_b, 170, 300, 2, "tank")
    local health = em_b:get_component(base_b, "health")
    Base.apply_damage(em_b, base_b, health.max_hp * 0.9, 2)    -- failing: 40% effective
    run_for(battered, 10)

    assert(healthy.stats.shots == 10, "Healthy base fires once a second, got " .. healthy.stats.shots)
    assert(battered.stats.shots == 4, "Failing base reloads in 2.5 s, got " .. battered.stats.shots)

    print("✓ Battered base reloads slower test passed")
end
-- }}}

-- {{{ TestSuite.test_destroyed_base_is_silent
function TestSuite.test_destroyed_base_is_silent()
    local em, base, system = new_world(always_hit, {shield_count = 0})
    Unit.create_basic_unit(em, 170, 300, 2, "melee")
    local health = em:get_component(base, "health")
    Base.apply_damage(em, base, health.max_hp, 2)

    run_for(system, 3)
    assert(system.stats.shots == 0, "A destroyed base's turret never fires")

    print("✓ Destroyed base is silent test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Base Turret Tests...")
    print(string.rep("=", 40))

    TestSuite.test_turret_defaults()
    TestSuite.test_target_selection_closest()
    TestSuite.test_targeting_modes()
    TestSuite.test_turns_before_firing()
    TestSuite.test_projectile_hits_and_misses()
    TestSuite.test_kills_and_retargets()
    TestSuite.test_battered_base_reloads_slower()
    TestSuite.test_destroyed_base_is_silent()

    print(string.rep("=", 40))
    print("✅ All base turret tests passed!")
end
-- }}}

return TestSuite
-- }}}
