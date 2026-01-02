-- test_wow_config.lua
-- Unit tests for WoW attribute configuration module.
--
-- Tests the complete WoW (TBC-era) attribute system including primary stats,
-- rating conversions, derived attributes, and class configurations.

package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local attributes = require("libs.attributes")
local wow = require("libs.attributes.configs.wow")

-- {{{ Test infrastructure
local tests_run = 0
local tests_passed = 0
local current_test = ""

-- {{{ assert_eq
local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end
-- }}}

-- {{{ assert_near
local function assert_near(expected, actual, tolerance, msg)
    tolerance = tolerance or 0.001
    if math.abs(expected - actual) > tolerance then
        error(string.format("%s: expected %.4f, got %.4f (tolerance %.4f)",
            msg or "Assertion failed",
            expected, actual, tolerance))
    end
end
-- }}}

-- {{{ assert_true
local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true, got false")
    end
end
-- }}}

-- {{{ assert_false
local function assert_false(value, msg)
    if value then
        error(msg or "Expected false, got true")
    end
end
-- }}}

-- {{{ assert_nil
local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s",
            msg or "Assertion failed",
            tostring(value)))
    end
end
-- }}}

-- {{{ assert_contains
local function assert_contains(tbl, value, msg)
    for i = 1, #tbl do
        if tbl[i] == value then
            return true
        end
    end
    error(string.format("%s: table does not contain %s",
        msg or "Assertion failed", tostring(value)))
end
-- }}}

-- {{{ run_test
local function run_test(name, fn)
    tests_run = tests_run + 1
    current_test = name
    local success, err = pcall(fn)
    if success then
        tests_passed = tests_passed + 1
        print(string.format("  [PASS] %s", name))
    else
        print(string.format("  [FAIL] %s", name))
        print(string.format("    Error: %s", err))
    end
end
-- }}}

-- {{{ setup
local function setup()
    attributes.reset()
    wow.reset()
    wow.register_all()
    attributes.rebuild_getters()
    attributes.rebuild_setters()
end
-- }}}

-- }}}

-- {{{ Test: Registration

print("\n=== Registration ===")

-- {{{ test: register_all registers all attributes
run_test("register_all registers all attributes", function()
    attributes.reset()
    wow.reset()

    assert_false(wow.is_registered(), "should not be registered initially")

    local ok = wow.register_all()
    assert_true(ok, "registration should succeed")
    assert_true(wow.is_registered(), "should be registered after")
end)
-- }}}

-- {{{ test: register_all fails on double registration
run_test("register_all fails on double registration", function()
    attributes.reset()
    wow.reset()

    wow.register_all()
    local ok, err = wow.register_all()
    assert_false(ok, "should fail on second registration")
    assert_true(err:find("already registered"), "should have error message")
end)
-- }}}

-- {{{ test: all primary stats registered
run_test("all primary stats registered", function()
    setup()

    assert_true(attributes.has("strength"), "strength registered")
    assert_true(attributes.has("agility"), "agility registered")
    assert_true(attributes.has("stamina"), "stamina registered")
    assert_true(attributes.has("intellect"), "intellect registered")
    assert_true(attributes.has("spirit"), "spirit registered")
end)
-- }}}

-- {{{ test: all rating stats registered
run_test("all rating stats registered", function()
    setup()

    assert_true(attributes.has("crit_rating"), "crit_rating registered")
    assert_true(attributes.has("hit_rating"), "hit_rating registered")
    assert_true(attributes.has("haste_rating"), "haste_rating registered")
    assert_true(attributes.has("defense_rating"), "defense_rating registered")
    assert_true(attributes.has("expertise_rating"), "expertise_rating registered")
    assert_true(attributes.has("resilience_rating"), "resilience_rating registered")
end)
-- }}}

-- {{{ test: all resource stats registered
run_test("all resource stats registered", function()
    setup()

    assert_true(attributes.has("health"), "health registered")
    assert_true(attributes.has("mana"), "mana registered")
    assert_true(attributes.has("rage"), "rage registered")
    assert_true(attributes.has("energy"), "energy registered")
    assert_true(attributes.has("combo_points"), "combo_points registered")
end)
-- }}}

-- {{{ test: all derived stats registered
run_test("all derived stats registered", function()
    setup()

    assert_true(attributes.has("max_health"), "max_health registered")
    assert_true(attributes.has("max_mana"), "max_mana registered")
    assert_true(attributes.has("attack_power"), "attack_power registered")
    assert_true(attributes.has("crit_chance"), "crit_chance registered")
    assert_true(attributes.has("spell_crit_chance"), "spell_crit_chance registered")
    assert_true(attributes.has("armor"), "armor registered")
    assert_true(attributes.has("armor_reduction"), "armor_reduction registered")
    assert_true(attributes.has("dps"), "dps registered")
end)
-- }}}

-- }}}

-- {{{ Test: Derived Attribute Formulas

print("\n=== Derived Attribute Formulas ===")

-- {{{ test: max_health formula (first 20 sta = 1 HP each, then 10)
run_test("max_health formula (stamina scaling)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_health", 100)
    attributes.set_value(container, "stamina", 10)

    -- sta <= 20: base + sta = 100 + 10 = 110
    local max_health = attributes.get_value(container, "max_health")
    assert_eq(110, max_health, "low stamina: max_health should be 110")

    -- Now with 50 stamina: base + 20 + (30 * 10) = 100 + 20 + 300 = 420
    attributes.set_value(container, "stamina", 50)
    max_health = attributes.get_value(container, "max_health")
    assert_eq(420, max_health, "high stamina: max_health should be 420")
end)
-- }}}

-- {{{ test: max_mana formula (first 20 int = 1 mana each, then 15)
run_test("max_mana formula (intellect scaling)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_mana", 100)
    attributes.set_value(container, "intellect", 15)

    -- int <= 20: base + int = 100 + 15 = 115
    local max_mana = attributes.get_value(container, "max_mana")
    assert_eq(115, max_mana, "low int: max_mana should be 115")

    -- Now with 60 intellect: base + 20 + (40 * 15) = 100 + 20 + 600 = 720
    attributes.set_value(container, "intellect", 60)
    max_mana = attributes.get_value(container, "max_mana")
    assert_eq(720, max_mana, "high int: max_mana should be 720")
end)
-- }}}

-- {{{ test: attack_power formula (str * 2 + agi for rogues)
run_test("attack_power formula (class-based)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_attack_power", 100)
    attributes.set_value(container, "strength", 50)
    attributes.set_value(container, "agility", 30)
    attributes.set_value(container, "class", "warrior")

    -- Warrior: base + str * 2 = 100 + 100 = 200
    local ap = attributes.get_value(container, "attack_power")
    assert_eq(200, ap, "warrior AP should be 200")

    -- Rogue: base + str * 2 + agi = 100 + 100 + 30 = 230
    attributes.set_value(container, "class", "rogue")
    ap = attributes.get_value(container, "attack_power")
    assert_eq(230, ap, "rogue AP should be 230")
end)
-- }}}

-- {{{ test: crit_chance formula (rating + agility)
run_test("crit_chance formula (rating + agility)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "crit_rating", 110)  -- 5% from rating
    attributes.set_value(container, "agility", 100)
    attributes.set_value(container, "class", "rogue")  -- 40 agi per 1%

    -- base 5% + rating 5% + agi 2.5% = 12.5%
    local crit = attributes.get_value(container, "crit_chance")
    assert_near(12.5, crit, 0.5, "crit_chance should be ~12.5%")
end)
-- }}}

-- {{{ test: spell_crit_chance formula (rating + intellect)
run_test("spell_crit_chance formula", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "crit_rating", 44)   -- 2% from rating
    attributes.set_value(container, "intellect", 160)    -- 2% from int

    -- rating 2% + int 2% = 4%
    local spell_crit = attributes.get_value(container, "spell_crit_chance")
    assert_near(4, spell_crit, 0.5, "spell_crit should be ~4%")
end)
-- }}}

-- {{{ test: hit_chance formula
run_test("hit_chance formula", function()
    setup()
    local container = attributes.create_container()

    -- 15.77 rating per 1% hit
    attributes.set_value(container, "hit_rating", 79)  -- ~5%

    local hit = attributes.get_value(container, "hit_chance")
    assert_near(5, hit, 0.5, "hit_chance should be ~5%")
end)
-- }}}

-- {{{ test: haste_percent formula
run_test("haste_percent formula", function()
    setup()
    local container = attributes.create_container()

    -- 15.77 rating per 1% haste
    attributes.set_value(container, "haste_rating", 158)  -- ~10%

    local haste = attributes.get_value(container, "haste_percent")
    assert_near(10, haste, 0.5, "haste should be ~10%")
end)
-- }}}

-- {{{ test: armor formula (base + agi * 2)
run_test("armor formula (base + agi * 2)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_armor", 1000)
    attributes.set_value(container, "agility", 100)

    -- armor = 1000 + (100 * 2) = 1200
    local armor = attributes.get_value(container, "armor")
    assert_eq(1200, armor, "armor should be 1200")
end)
-- }}}

-- {{{ test: armor_reduction formula (75% cap)
run_test("armor_reduction formula (with cap)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_armor", 10000)
    attributes.set_value(container, "agility", 0)
    attributes.set_value(container, "level", 70)

    -- At level 70: constant = 400 + 85*70 = 6350
    -- DR = 10000 / (10000 + 6350) * 100 = 61.2%
    local dr = attributes.get_value(container, "armor_reduction")
    assert_near(61.2, dr, 1, "armor DR should be ~61%")

    -- Test cap at 75%
    attributes.set_value(container, "base_armor", 100000)
    dr = attributes.get_value(container, "armor_reduction")
    assert_eq(75, dr, "armor DR should be capped at 75%")
end)
-- }}}

-- {{{ test: block_value formula
run_test("block_value formula", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "strength", 100)

    -- 1 block value per 20 strength = 5
    local bv = attributes.get_value(container, "block_value")
    assert_eq(5, bv, "block_value should be 5")
end)
-- }}}

-- {{{ test: mana_regen formula
run_test("mana_regen formula", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "intellect", 400)
    attributes.set_value(container, "spirit", 200)
    attributes.set_value(container, "mp5", 50)

    -- spirit_regen = 5 * sqrt(400) * 200 * 0.009327 = 5 * 20 * 200 * 0.009327 = 186.54
    -- total = 186.54 + 50 = 236.54
    local regen = attributes.get_value(container, "mana_regen")
    assert_near(236.5, regen, 1, "mana_regen should be ~236")
end)
-- }}}

-- {{{ test: dps calculation
run_test("dps calculation", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_damage_min", 100)
    attributes.set_value(container, "base_damage_max", 150)
    attributes.set_value(container, "base_attack_speed", 2.0)
    attributes.set_value(container, "base_attack_power", 0)
    attributes.set_value(container, "strength", 0)
    attributes.set_value(container, "agility", 0)
    attributes.set_value(container, "haste_rating", 0)

    -- AP = 0, avg_dmg = 125, speed = 2.0, dps = 62.5
    local dps = attributes.get_value(container, "dps")
    assert_near(62.5, dps, 0.5, "dps should be ~62.5")
end)
-- }}}

-- }}}

-- {{{ Test: Class Configuration

print("\n=== Class Configuration ===")

-- {{{ test: list_classes returns all classes
run_test("list_classes returns all classes", function()
    local classes = wow.list_classes()

    assert_eq(9, #classes, "should have 9 classes")
    assert_contains(classes, "warrior", "should have warrior")
    assert_contains(classes, "mage", "should have mage")
    assert_contains(classes, "druid", "should have druid")
end)
-- }}}

-- {{{ test: get_class returns class data
run_test("get_class returns class data", function()
    local warrior = wow.get_class("warrior")

    assert_true(warrior ~= nil, "warrior should exist")
    assert_eq(23, warrior.strength, "warrior base strength")
    assert_eq("rage", warrior.resource_type, "warrior uses rage")
    assert_eq(80, warrior.base_health, "warrior base health")
end)
-- }}}

-- {{{ test: get_class returns nil for unknown
run_test("get_class returns nil for unknown", function()
    local result = wow.get_class("nonexistent")
    assert_nil(result, "should return nil for unknown class")
end)
-- }}}

-- {{{ test: apply_class sets stats
run_test("apply_class sets stats", function()
    setup()
    local container = attributes.create_container()

    local ok = wow.apply_class(container, "mage", 1)
    assert_true(ok, "apply should succeed")

    local level = attributes.get_value(container, "level")
    local class = attributes.get_value(container, "class")
    local int = attributes.get_value(container, "intellect")
    local resource = attributes.get_value(container, "resource_type")

    assert_eq(1, level, "level should be 1")
    assert_eq("mage", class, "class should be mage")
    assert_eq(24, int, "intellect should be mage base (24)")
    assert_eq("mana", resource, "resource should be mana")
end)
-- }}}

-- {{{ test: apply_class at level 70
run_test("apply_class at level 70", function()
    setup()
    local container = attributes.create_container()

    wow.apply_class(container, "warrior", 70)

    local level = attributes.get_value(container, "level")
    local str = attributes.get_value(container, "strength")

    assert_eq(70, level, "level should be 70")

    -- Warrior: base 23, +2.2 per level, 69 levels gained
    -- str = floor(23 + 2.2 * 69) = floor(174.8) = 174
    assert_eq(174, str, "strength at level 70 should be 174")
end)
-- }}}

-- {{{ test: apply_class fails for unknown
run_test("apply_class fails for unknown", function()
    setup()
    local container = attributes.create_container()

    local ok, err = wow.apply_class(container, "nonexistent", 1)
    assert_false(ok, "should fail for unknown class")
    assert_true(err:find("Unknown class"), "should have error message")
end)
-- }}}

-- {{{ test: apply_class clamps level
run_test("apply_class clamps level", function()
    setup()
    local container = attributes.create_container()

    wow.apply_class(container, "warrior", 100)  -- Over max

    local level = attributes.get_value(container, "level")
    assert_eq(70, level, "level should be clamped to 70")
end)
-- }}}

-- {{{ test: calculate_stats_at_level
run_test("calculate_stats_at_level", function()
    local stats = wow.calculate_stats_at_level("priest", 60)

    assert_eq(60, stats.level, "level should be 60")
    assert_eq("priest", stats.class, "class should be priest")
    assert_eq("mana", stats.resource_type, "resource should be mana")

    -- Priest: base 24 spirit, +2.4 per level, 59 levels gained
    -- spirit = floor(24 + 2.4 * 59) = floor(165.6) = 165
    assert_eq(165, stats.spirit, "spirit at level 60")
end)
-- }}}

-- {{{ test: calculate_stats_at_level fails for unknown
run_test("calculate_stats_at_level fails for unknown", function()
    local stats, err = wow.calculate_stats_at_level("nonexistent", 50)
    assert_nil(stats, "should return nil")
    assert_true(err:find("Unknown class"), "should have error")
end)
-- }}}

-- }}}

-- {{{ Test: Experience Table

print("\n=== Experience Table ===")

-- {{{ test: get_xp_for_level returns correct values
run_test("get_xp_for_level returns correct values", function()
    assert_eq(0, wow.get_xp_for_level(1), "level 1 requires 0 XP")
    assert_eq(400, wow.get_xp_for_level(2), "level 2 requires 400 XP")
    assert_eq(6500, wow.get_xp_for_level(10), "level 10 requires 6500 XP")
    assert_eq(172000, wow.get_xp_for_level(60), "level 60 requires 172000 XP")
    assert_eq(290000, wow.get_xp_for_level(61), "level 61 requires 290000 XP")
    assert_eq(717000, wow.get_xp_for_level(70), "level 70 requires 717000 XP")
end)
-- }}}

-- {{{ test: get_xp_for_level handles edge cases
run_test("get_xp_for_level handles edge cases", function()
    assert_eq(0, wow.get_xp_for_level(0), "level 0 returns 0")
    assert_eq(0, wow.get_xp_for_level(-5), "negative level returns 0")
    assert_eq(717000, wow.get_xp_for_level(80), "over max returns max XP")
end)
-- }}}

-- {{{ test: get_level_for_xp returns correct level
run_test("get_level_for_xp returns correct level", function()
    assert_eq(1, wow.get_level_for_xp(0), "0 XP is level 1")
    assert_eq(1, wow.get_level_for_xp(300), "300 XP is still level 1")
    assert_eq(2, wow.get_level_for_xp(400), "400 XP is level 2")
    assert_eq(60, wow.get_level_for_xp(172000), "172000 XP is level 60")
    assert_eq(70, wow.get_level_for_xp(717000), "717000 XP is level 70")
    assert_eq(70, wow.get_level_for_xp(1000000), "1000000 XP is level 70")
end)
-- }}}

-- {{{ test: get_xp_to_next_level
run_test("get_xp_to_next_level", function()
    assert_eq(400, wow.get_xp_to_next_level(0), "0 XP needs 400 more")
    assert_eq(100, wow.get_xp_to_next_level(300), "300 XP needs 100 more")
    assert_eq(0, wow.get_xp_to_next_level(717000), "max level needs 0")
end)
-- }}}

-- {{{ test: get_xp_progress
run_test("get_xp_progress", function()
    assert_near(0, wow.get_xp_progress(0), 0.1, "0 XP is 0% progress")
    assert_near(50, wow.get_xp_progress(200), 0.1, "200 XP is 50% of 0-400")
    assert_eq(100, wow.get_xp_progress(717000), "max level is 100%")
end)
-- }}}

-- }}}

-- {{{ Test: Level Up

print("\n=== Level Up ===")

-- {{{ test: level_up increases stats
run_test("level_up increases stats", function()
    setup()
    local container = attributes.create_container()

    wow.apply_class(container, "rogue", 1)

    local agi_before = attributes.get_value(container, "agility")

    local ok, info = wow.level_up(container, "rogue")
    assert_true(ok, "level_up should succeed")

    local level = attributes.get_value(container, "level")
    local agi_after = attributes.get_value(container, "agility")

    assert_eq(2, level, "level should be 2")
    assert_eq(2, info.agility_gained, "should gain 2 agility (floor of 2.6)")
    assert_eq(agi_before + 2, agi_after, "agility should increase by 2")
end)
-- }}}

-- {{{ test: level_up fails at max level
run_test("level_up fails at max level", function()
    setup()
    local container = attributes.create_container()

    wow.apply_class(container, "warrior", 70)

    local ok, err = wow.level_up(container, "warrior")
    assert_false(ok, "should fail at max level")
    assert_true(err:find("max level"), "should have error message")
end)
-- }}}

-- {{{ test: level_up fails for unknown class
run_test("level_up fails for unknown class", function()
    setup()
    local container = attributes.create_container()

    wow.apply_class(container, "warrior", 1)

    local ok, err = wow.level_up(container, "nonexistent")
    assert_false(ok, "should fail for unknown class")
end)
-- }}}

-- }}}

-- {{{ Test: Rating Conversions

print("\n=== Rating Conversions ===")

-- {{{ test: get_rating_conversion returns correct values
run_test("get_rating_conversion returns correct values at 70", function()
    local crit = wow.get_rating_conversion("crit", 70)
    assert_near(22.08, crit, 0.1, "crit rating at 70")

    local hit = wow.get_rating_conversion("hit", 70)
    assert_near(15.77, hit, 0.1, "hit rating at 70")
end)
-- }}}

-- {{{ test: get_rating_conversion scales with level
run_test("get_rating_conversion scales with level", function()
    local crit_70 = wow.get_rating_conversion("crit", 70)
    local crit_60 = wow.get_rating_conversion("crit", 60)

    -- At level 60, ratings should be more efficient (lower value)
    assert_true(crit_60 < crit_70, "crit rating at 60 should be more efficient")
end)
-- }}}

-- {{{ test: get_rating_conversion returns nil for unknown
run_test("get_rating_conversion returns nil for unknown", function()
    local result = wow.get_rating_conversion("nonexistent", 70)
    assert_nil(result, "should return nil for unknown stat")
end)
-- }}}

-- }}}

-- {{{ Test: Integration

print("\n=== Integration ===")

-- {{{ test: full character lifecycle
run_test("full character lifecycle", function()
    setup()
    local container = attributes.create_container()

    -- Create a level 1 hunter
    wow.apply_class(container, "hunter", 1)

    -- Check initial derived stats
    local max_health = attributes.get_value(container, "max_health")
    local max_mana = attributes.get_value(container, "max_mana")

    -- Hunter: sta 21, int 20, base_health 56, base_mana 85
    -- max_health = 56 + 20 + ((21-20) * 10) = 56 + 20 + 10 = 86
    -- max_mana = 85 + 20 = 105 (20 int is at threshold)
    assert_eq(86, max_health, "hunter max_health at level 1")
    assert_eq(105, max_mana, "hunter max_mana at level 1")

    -- Level up
    wow.level_up(container, "hunter")

    -- Check updated stats
    local new_level = attributes.get_value(container, "level")
    assert_eq(2, new_level, "should be level 2")
end)
-- }}}

-- {{{ test: modifiers affect derived stats
run_test("modifiers affect derived stats", function()
    setup()
    local container = attributes.create_container()

    wow.apply_class(container, "warrior", 1)

    local base_max_health = attributes.get_value(container, "max_health")

    -- Add a +30 stamina modifier (above threshold, so +300 HP)
    attributes.add_modifier(container, "stamina", {
        source = "test_item",
        type = "flat",
        value = 30,
    })

    local new_max_health = attributes.get_value(container, "max_health")
    assert_eq(base_max_health + 300, new_max_health, "max_health should increase by 300")

    -- Remove modifier
    attributes.remove_modifier(container, "stamina", "test_item")

    local final_max_health = attributes.get_value(container, "max_health")
    assert_eq(base_max_health, final_max_health, "max_health should return to base")
end)
-- }}}

-- {{{ test: all classes can be applied
run_test("all classes can be applied", function()
    setup()

    local classes = wow.list_classes()
    for i = 1, #classes do
        local class_name = classes[i]
        local container = attributes.create_container()

        local ok = wow.apply_class(container, class_name, 1)
        assert_true(ok, "should apply " .. class_name)

        local level = attributes.get_value(container, "level")
        assert_eq(1, level, class_name .. " should be level 1")
    end
end)
-- }}}

-- {{{ test: XP table is monotonically increasing
run_test("XP table is monotonically increasing", function()
    local prev = -1
    for lvl = 1, 70 do
        local xp = wow.get_xp_for_level(lvl)
        assert_true(xp > prev, "XP should increase at level " .. lvl)
        prev = xp
    end
end)
-- }}}

-- {{{ test: TBC XP jump at level 61
run_test("TBC XP jump at level 61", function()
    local xp_60 = wow.get_xp_for_level(60)
    local xp_61 = wow.get_xp_for_level(61)

    -- There's a significant jump at 61 (TBC content)
    local ratio = xp_61 / xp_60
    assert_true(ratio > 1.5, "XP requirement should increase significantly at 61")
end)
-- }}}

-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d/%d passed", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print(string.format("%d tests failed", tests_run - tests_passed))
    os.exit(1)
end
-- }}}
