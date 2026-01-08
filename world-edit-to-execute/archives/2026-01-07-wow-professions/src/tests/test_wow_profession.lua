--[[
Unit tests for WoW-Mode Profession Configuration (Issue 702e)

Tests cover:
- Skill tier system and progression
- Primary profession limits
- Specialization choices
- Profession perks and bonuses
- Trainer component
]]

-- {{{ Configuration
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

local ecs = require("runtime.ecs")
local events = require("runtime.events")
local professions = require("runtime.systems.professions")
local wow_prof = require("runtime.configs.wow_profession")

-- ============================================================================
-- Test Harness
-- ============================================================================

-- {{{ Test state
local tests_run = 0
local tests_passed = 0
local current_test = ""
-- }}}

-- {{{ assert_eq
local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected: " .. tostring(expected))
        print("    Actual: " .. tostring(actual))
        return false
    end
    return true
end
-- }}}

-- {{{ assert_true
local function assert_true(value, msg)
    if not value then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected truthy value, got: " .. tostring(value))
        return false
    end
    return true
end
-- }}}

-- {{{ assert_false
local function assert_false(value, msg)
    if value then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected falsy value, got: " .. tostring(value))
        return false
    end
    return true
end
-- }}}

-- {{{ assert_nil
local function assert_nil(value, msg)
    if value ~= nil then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected nil, got: " .. tostring(value))
        return false
    end
    return true
end
-- }}}

-- {{{ Initialize systems once
professions.init()
wow_prof.init()
-- }}}

-- {{{ run_test
local function run_test(name, fn)
    current_test = name
    tests_run = tests_run + 1

    -- Reset state before each test
    ecs.reset()
    events.reset()
    professions.reset()
    wow_prof.reset()

    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("  PASS: " .. name)
    else
        print("  FAIL: " .. name)
        print("    Error: " .. tostring(err))
    end
end
-- }}}

-- ============================================================================
-- Test Helpers
-- ============================================================================

-- {{{ create_test_entity
local function create_test_entity()
    local entity = ecs.create_entity()
    ecs.add_component(entity, "professions")
    return entity
end
-- }}}

-- ============================================================================
-- Configuration Tests
-- ============================================================================

print("\n=== Configuration Tests ===")

-- {{{ test: skill tiers defined
run_test("skill tiers defined", function()
    assert_true(#wow_prof.SKILL_TIERS >= 4, "Should have at least 4 tiers")
    assert_eq(wow_prof.SKILL_TIERS[1].name, "Apprentice")
    assert_eq(wow_prof.SKILL_TIERS[2].name, "Journeyman")
    assert_eq(wow_prof.SKILL_TIERS[3].name, "Expert")
    assert_eq(wow_prof.SKILL_TIERS[4].name, "Artisan")
end)
-- }}}

-- {{{ test: tier ranges are continuous
run_test("tier ranges are continuous", function()
    for i = 1, #wow_prof.SKILL_TIERS - 1 do
        local current = wow_prof.SKILL_TIERS[i]
        local next = wow_prof.SKILL_TIERS[i + 1]
        assert_eq(current.skill_range[2] + 1, next.skill_range[1],
            "Tier ranges should be continuous")
    end
end)
-- }}}

-- {{{ test: profession categories exist
run_test("profession categories exist", function()
    assert_true(wow_prof.PROFESSION_CATEGORIES.PRIMARY ~= nil)
    assert_true(wow_prof.PROFESSION_CATEGORIES.SECONDARY ~= nil)
    assert_eq(wow_prof.PROFESSION_CATEGORIES.PRIMARY.max_count, 2)
    assert_nil(wow_prof.PROFESSION_CATEGORIES.SECONDARY.max_count)
end)
-- }}}

-- {{{ test: primary professions list
run_test("primary professions list", function()
    local primaries = wow_prof.PROFESSION_CATEGORIES.PRIMARY.professions
    assert_true(#primaries >= 10, "Should have at least 10 primary professions")

    -- Check for key professions
    local has_mining = false
    local has_blacksmithing = false
    for _, prof in ipairs(primaries) do
        if prof == "mining" then has_mining = true end
        if prof == "blacksmithing" then has_blacksmithing = true end
    end
    assert_true(has_mining, "Should include mining")
    assert_true(has_blacksmithing, "Should include blacksmithing")
end)
-- }}}

-- {{{ test: config object exists
run_test("config object exists", function()
    assert_eq(wow_prof.CONFIG.mode, "wow")
    assert_eq(wow_prof.CONFIG.skill_max_base, 300)
    assert_eq(wow_prof.CONFIG.primary_profession_limit, 2)
    assert_true(wow_prof.CONFIG.tier_training_required)
    assert_true(wow_prof.CONFIG.specialization_enabled)
end)
-- }}}

-- ============================================================================
-- Tier Management Tests
-- ============================================================================

print("\n=== Tier Management Tests ===")

-- {{{ test: get current tier
run_test("get current tier", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")

    local tier = wow_prof.get_current_tier(entity, "mining")
    assert_eq(tier.name, "Apprentice", "New profession should start at Apprentice")
    assert_eq(tier.skill_range[1], 1)
    assert_eq(tier.skill_range[2], 75)
end)
-- }}}

-- {{{ test: current tier updates with skill
run_test("current tier updates with skill", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    professions.add_skill(entity, "mining", 100)

    local tier = wow_prof.get_current_tier(entity, "mining")
    assert_eq(tier.name, "Journeyman", "Skill 101 should be Journeyman tier")
end)
-- }}}

-- {{{ test: get next tier
run_test("get next tier", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")

    local next = wow_prof.get_next_tier(entity, "mining")
    assert_eq(next.name, "Journeyman", "Next tier from Apprentice should be Journeyman")
end)
-- }}}

-- {{{ test: no next tier at max
run_test("no next tier at max", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    professions.add_skill(entity, "mining", 450)

    local next = wow_prof.get_next_tier(entity, "mining")
    assert_nil(next, "Should have no next tier at max")
end)
-- }}}

-- {{{ test: can_train_tier checks skill cap
run_test("can_train_tier checks skill cap", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")

    -- At skill 1, cap 75, cannot train yet
    local can, err = wow_prof.can_train_tier(entity, "mining")
    assert_false(can, "Cannot train tier without reaching cap")
    assert_true(err:find("skill cap"))

    -- At skill cap, can train
    professions.add_skill(entity, "mining", 74)  -- Reach 75
    can, err = wow_prof.can_train_tier(entity, "mining")
    assert_true(can, "Should be able to train at skill cap")
end)
-- }}}

-- {{{ test: train_tier increases cap
run_test("train_tier increases cap", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    professions.add_skill(entity, "mining", 74)  -- Reach cap

    local initial_cap = professions.get_max_skill(entity, "mining")
    assert_eq(initial_cap, 75)

    local ok, tier = wow_prof.train_tier(entity, "mining", nil)
    assert_true(ok, "Training should succeed")
    assert_eq(tier.name, "Journeyman")

    local new_cap = professions.get_max_skill(entity, "mining")
    assert_eq(new_cap, 150, "Cap should increase to Journeyman max")
end)
-- }}}

-- {{{ test: tier trained event fires
run_test("tier trained event fires", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    professions.add_skill(entity, "mining", 74)

    local event_fired = false
    local trigger = {
        events = {},
        fire = function(self, data)
            event_fired = true
            assert_eq(data.entity, entity)
            assert_eq(data.profession, "mining")
            assert_eq(data.tier, "Journeyman")
        end,
    }

    events.register(wow_prof.EVENT.TIER_TRAINED, trigger)
    wow_prof.train_tier(entity, "mining", nil)
    assert_true(event_fired, "TIER_TRAINED event should fire")
end)
-- }}}

-- ============================================================================
-- Primary Profession Limit Tests
-- ============================================================================

print("\n=== Primary Profession Limit Tests ===")

-- {{{ test: get primary count
run_test("get primary count", function()
    local entity = create_test_entity()

    assert_eq(wow_prof.get_primary_count(entity), 0)

    professions.learn_profession(entity, "mining")
    assert_eq(wow_prof.get_primary_count(entity), 1)

    professions.learn_profession(entity, "blacksmithing")
    assert_eq(wow_prof.get_primary_count(entity), 2)
end)
-- }}}

-- {{{ test: can_learn_primary checks limit
run_test("can_learn_primary checks limit", function()
    local entity = create_test_entity()

    local can = wow_prof.can_learn_primary(entity)
    assert_true(can, "Should be able to learn first primary")

    professions.learn_profession(entity, "mining")
    can = wow_prof.can_learn_primary(entity)
    assert_true(can, "Should be able to learn second primary")

    professions.learn_profession(entity, "blacksmithing")
    can, err = wow_prof.can_learn_primary(entity)
    assert_false(can, "Should not be able to learn third primary")
    assert_true(err:find("limit"))
end)
-- }}}

-- {{{ test: secondary professions don't count toward limit
run_test("secondary professions don't count toward limit", function()
    local entity = create_test_entity()

    professions.learn_profession(entity, "mining")
    professions.learn_profession(entity, "blacksmithing")
    professions.learn_profession(entity, "cooking", professions.TYPE.SECONDARY)

    assert_eq(wow_prof.get_primary_count(entity), 2, "Cooking should not count")
end)
-- }}}

-- {{{ test: unlearn profession frees slot
run_test("unlearn profession frees slot", function()
    local entity = create_test_entity()

    professions.learn_profession(entity, "mining")
    professions.learn_profession(entity, "blacksmithing")

    assert_eq(wow_prof.get_primary_count(entity), 2)

    wow_prof.unlearn_profession(entity, "mining")
    assert_eq(wow_prof.get_primary_count(entity), 1, "Should free up a slot")

    local can = wow_prof.can_learn_primary(entity)
    assert_true(can, "Should be able to learn another primary")
end)
-- }}}

-- ============================================================================
-- Specialization Tests
-- ============================================================================

print("\n=== Specialization Tests ===")

-- {{{ test: specializations defined
run_test("specializations defined", function()
    assert_true(wow_prof.SPECIALIZATIONS.blacksmithing ~= nil)
    assert_true(wow_prof.SPECIALIZATIONS.engineering ~= nil)
    assert_true(wow_prof.SPECIALIZATIONS.alchemy ~= nil)
    assert_true(wow_prof.SPECIALIZATIONS.leatherworking ~= nil)
end)
-- }}}

-- {{{ test: get_available_specs requires skill
run_test("get_available_specs requires skill", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")

    -- At skill 1, no specs available
    local specs = wow_prof.get_available_specs(entity, "blacksmithing")
    assert_eq(#specs, 0, "No specs should be available at low skill")

    -- At skill 200, specs available
    professions.add_skill(entity, "blacksmithing", 199)
    specs = wow_prof.get_available_specs(entity, "blacksmithing")
    assert_eq(#specs, 2, "Should have 2 choices at skill 200")
end)
-- }}}

-- {{{ test: choose_specialization works
run_test("choose_specialization works", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")
    professions.add_skill(entity, "blacksmithing", 199)

    local ok, spec = wow_prof.choose_specialization(entity, "blacksmithing", "armorsmith")
    assert_true(ok, "Should be able to choose spec")
    assert_eq(spec.id, "armorsmith")

    local current = wow_prof.get_specialization(entity, "blacksmithing")
    assert_eq(current, "armorsmith")
end)
-- }}}

-- {{{ test: cannot choose spec twice
run_test("cannot choose spec twice", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "engineering")
    professions.add_skill(entity, "engineering", 199)

    wow_prof.choose_specialization(entity, "engineering", "gnomish")

    -- Try to choose again
    local ok, err = wow_prof.choose_specialization(entity, "engineering", "goblin")
    assert_false(ok, "Cannot choose spec twice")
end)
-- }}}

-- {{{ test: spec chosen event fires
run_test("spec chosen event fires", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "alchemy")
    professions.add_skill(entity, "alchemy", 299)

    local event_fired = false
    local trigger = {
        events = {},
        fire = function(self, data)
            event_fired = true
            assert_eq(data.entity, entity)
            assert_eq(data.profession, "alchemy")
            assert_eq(data.specialization, "elixir_master")
        end,
    }

    events.register(wow_prof.EVENT.SPEC_CHOSEN, trigger)
    wow_prof.choose_specialization(entity, "alchemy", "elixir_master")
    assert_true(event_fired, "SPEC_CHOSEN event should fire")
end)
-- }}}

-- ============================================================================
-- Profession Perk Tests
-- ============================================================================

print("\n=== Profession Perk Tests ===")

-- {{{ test: perks defined
run_test("perks defined", function()
    assert_true(wow_prof.PROFESSION_PERKS.mining ~= nil)
    assert_true(wow_prof.PROFESSION_PERKS.skinning ~= nil)
    assert_true(wow_prof.PROFESSION_PERKS.herbalism ~= nil)
    assert_true(wow_prof.PROFESSION_PERKS.enchanting ~= nil)
end)
-- }}}

-- {{{ test: get_active_perks with no professions
run_test("get_active_perks with no professions", function()
    local entity = create_test_entity()
    local perks = wow_prof.get_active_perks(entity)
    assert_eq(#perks, 0, "No perks without professions")
end)
-- }}}

-- {{{ test: get_active_perks returns passive bonuses
run_test("get_active_perks returns passive bonuses", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    professions.add_skill(entity, "mining", 149)

    local perks = wow_prof.get_active_perks(entity)
    assert_true(#perks >= 2, "Should have perks at skill 150")

    -- Should have rank 1 and rank 2 toughness
    local found_rank1 = false
    local found_rank2 = false
    for _, perk in ipairs(perks) do
        if perk.type == "passive" and perk.rank then
            if perk.rank.skill == 75 then found_rank1 = true end
            if perk.rank.skill == 150 then found_rank2 = true end
        end
    end
    assert_true(found_rank1, "Should have rank 1 perk")
    assert_true(found_rank2, "Should have rank 2 perk")
end)
-- }}}

-- {{{ test: apply_perk_bonuses modifies stats
run_test("apply_perk_bonuses modifies stats", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    professions.add_skill(entity, "mining", 149)

    local stats = {stamina = 100}
    stats = wow_prof.apply_perk_bonuses(entity, stats)

    -- Should have +3 from rank 1 and +5 from rank 2 = +8 total
    assert_eq(stats.stamina, 108, "Should add stamina from toughness")
end)
-- }}}

-- {{{ test: ability perks returned
run_test("ability perks returned", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "herbalism")

    local perks = wow_prof.get_active_perks(entity)
    assert_true(#perks >= 1, "Should have lifeblood ability")

    local has_lifeblood = false
    for _, perk in ipairs(perks) do
        if perk.type == "ability" and perk.perk.id == "lifeblood" then
            has_lifeblood = true
        end
    end
    assert_true(has_lifeblood, "Should have lifeblood ability")
end)
-- }}}

-- ============================================================================
-- Component Tests
-- ============================================================================

print("\n=== Component Tests ===")

-- {{{ test: profession_trainer component exists
run_test("profession_trainer component exists", function()
    local trainer = ecs.create_entity()
    ecs.add_component(trainer, "profession_trainer")

    local comp = ecs.get_component(trainer, "profession_trainer")
    assert_true(comp ~= nil, "Should have profession_trainer component")
    assert_eq(comp.trainer_tier, "apprentice")
    assert_true(comp.can_train_tier)
    assert_true(comp.can_teach_recipes)
end)
-- }}}

-- {{{ test: trainer can be configured
run_test("trainer can be configured", function()
    local trainer = ecs.create_entity()
    ecs.add_component(trainer, "profession_trainer")

    local comp = ecs.get_component(trainer, "profession_trainer")
    rawset(comp, "_initialized", true)
    rawset(comp, "profession", "blacksmithing")
    rawset(comp, "trainer_tier", "expert")
    rawset(comp, "recipes_taught", {"iron_sword", "steel_breastplate"})

    assert_eq(comp.profession, "blacksmithing")
    assert_eq(comp.trainer_tier, "expert")
    assert_eq(#comp.recipes_taught, 2)
end)
-- }}}

-- ============================================================================
-- Summary
-- ============================================================================

print("\n=== Test Summary ===")
print(string.format("Passed: %d / %d", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print("Some tests failed.")
    os.exit(1)
end
