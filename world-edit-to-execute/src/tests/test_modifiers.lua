#!/usr/bin/env lua
-- Modifier Stack System Unit Tests (Issue 016d)
-- Tests for modifier management: add, remove, stacking, expiry, conditions.
-- Run with: lua src/tests/test_modifiers.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local schema_module = require("libs.attributes.schema")
local registry = require("libs.attributes.registry")
local getters = require("libs.attributes.getters")
local setters = require("libs.attributes.setters")
local modifiers = require("libs.attributes.modifiers")

local ATTR_TYPE = schema_module.ATTR_TYPE
local ATTR_FLAGS = schema_module.ATTR_FLAGS
local MOD_TYPE = modifiers.MOD_TYPE
local SOURCE_CATEGORY = modifiers.SOURCE_CATEGORY

-- {{{ Test utilities
local test_count = 0
local pass_count = 0

local function test(name, fn)
    test_count = test_count + 1
    local ok, err = pcall(fn)
    if ok then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name)
        print("         " .. tostring(err))
    end
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true")
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "Expected false")
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s",
            msg or "Assertion failed", tostring(value)))
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil")
    end
end

local function assert_approx(actual, expected, tolerance, msg)
    tolerance = tolerance or 0.001
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s: expected ~%s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

local function reset_all()
    registry.reset()
    setters.clear_listeners()
    setters.rebuild()
    getters.rebuild()
end
-- }}}

-- {{{ Setup test attributes
local function setup_test_attributes()
    reset_all()

    registry.register({
        id = "strength",
        type = ATTR_TYPE.INTEGER,
        min = 1,
        max = 999,
        default = 10,
        flags = ATTR_FLAGS.MODIFIABLE,
    })

    registry.register({
        id = "agility",
        type = ATTR_TYPE.INTEGER,
        min = 1,
        max = 999,
        default = 10,
        flags = ATTR_FLAGS.MODIFIABLE,
    })

    registry.register({
        id = "attack_power",
        type = ATTR_TYPE.INTEGER,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "strength", "agility" },
        formula = function(get)
            return get("strength") * 2 + get("agility")
        end,
    })

    registry.register({
        id = "health",
        type = ATTR_TYPE.INTEGER,
        min = 0,
        max = 9999,
        default = 100,
        flags = ATTR_FLAGS.MODIFIABLE,
    })

    registry.register({
        id = "crit_chance",
        type = ATTR_TYPE.FLOAT,
        min = 0.0,
        max = 1.0,
        default = 0.05,
        flags = ATTR_FLAGS.MODIFIABLE,
    })

    setters.rebuild()
    getters.rebuild()
end
-- }}}

-- {{{ Modifier Class Tests
test_section("Modifier Class")

test("Modifier.new() creates modifier with defaults", function()
    local mod = modifiers.Modifier.new({
        source = "test:buff",
        value = 10,
    })

    assert_eq(mod.source, "test:buff")
    assert_eq(mod.value, 10)
    assert_eq(mod.type, MOD_TYPE.FLAT)
    assert_eq(mod.category, SOURCE_CATEGORY.BUFF)
    assert_eq(mod.stacks, 1)
    assert_eq(mod.max_stacks, 1)
end)

test("Modifier.new() requires source", function()
    local ok = pcall(function()
        modifiers.Modifier.new({ value = 10 })
    end)
    assert_false(ok, "Should require source")
end)

test("Modifier:get_value() returns value * stacks", function()
    local mod = modifiers.Modifier.new({
        source = "test",
        value = 10,
        stacks = 3,
        max_stacks = 5,
    })

    assert_eq(mod:get_value(), 30)
end)

test("Modifier:add_stack() increments stacks", function()
    local mod = modifiers.Modifier.new({
        source = "test",
        value = 10,
        max_stacks = 3,
    })

    assert_eq(mod.stacks, 1)
    assert_true(mod:add_stack())
    assert_eq(mod.stacks, 2)
    assert_true(mod:add_stack())
    assert_eq(mod.stacks, 3)
    assert_false(mod:add_stack(), "Should fail at max stacks")
    assert_eq(mod.stacks, 3)
end)

test("Modifier:remove_stack() decrements stacks", function()
    local mod = modifiers.Modifier.new({
        source = "test",
        value = 10,
        stacks = 3,
        max_stacks = 5,
    })

    assert_eq(mod:remove_stack(), 2)
    assert_eq(mod:remove_stack(), 1)
    assert_eq(mod:remove_stack(), 0)
end)

test("Modifier:is_expired() checks expiry", function()
    local mod1 = modifiers.Modifier.new({
        source = "permanent",
        value = 10,
    })
    assert_false(mod1:is_expired())

    local mod2 = modifiers.Modifier.new({
        source = "expired",
        value = 10,
        expires_at = os.time() - 10,
    })
    assert_true(mod2:is_expired())

    local mod3 = modifiers.Modifier.new({
        source = "future",
        value = 10,
        expires_at = os.time() + 3600,
    })
    assert_false(mod3:is_expired())
end)

test("Modifier:is_active() checks expiry and condition", function()
    local mod1 = modifiers.Modifier.new({
        source = "active",
        value = 10,
    })
    assert_true(mod1:is_active({}))

    local mod2 = modifiers.Modifier.new({
        source = "expired",
        value = 10,
        expires_at = os.time() - 10,
    })
    assert_false(mod2:is_active({}))

    local mod3 = modifiers.Modifier.new({
        source = "conditional",
        value = 10,
        condition = function(container)
            return container.test_flag == true
        end,
    })
    assert_false(mod3:is_active({ test_flag = false }))
    assert_true(mod3:is_active({ test_flag = true }))
end)

test("Modifier:refresh_duration() updates expiry", function()
    local mod = modifiers.Modifier.new({
        source = "test",
        value = 10,
        duration = 60,
    })

    local original = mod.expires_at
    -- Wait a tiny bit to ensure time moves
    mod:refresh_duration()
    assert_true(mod.expires_at >= original)
end)

test("Modifier:clone() creates independent copy", function()
    local mod1 = modifiers.Modifier.new({
        source = "test",
        value = 10,
        stacks = 2,
        max_stacks = 5,
    })

    local mod2 = mod1:clone()
    mod1:add_stack()

    assert_eq(mod1.stacks, 3)
    assert_eq(mod2.stacks, 2, "Clone should be independent")
end)

test("Modifier:__tostring() returns descriptive string", function()
    local mod = modifiers.Modifier.new({
        source = "buff:might",
        type = MOD_TYPE.FLAT,
        value = 50,
    })

    local str = tostring(mod)
    assert_true(str:find("buff:might"), "Should include source")
    assert_true(str:find("flat"), "Should include type")
end)
-- }}}

-- {{{ Add Modifier Tests
test_section("Add Modifier")

test("add() creates new modifier", function()
    setup_test_attributes()
    local container = registry.create_container()

    local mod, action = modifiers.add(container, "strength", {
        source = "buff:might",
        type = MOD_TYPE.FLAT,
        value = 20,
    })

    assert_eq(action, "added")
    assert_not_nil(mod)
    assert_eq(mod.source, "buff:might")
end)

test("add() stacks existing modifier", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "buff:sunder",
        type = MOD_TYPE.FLAT,
        value = 10,
        max_stacks = 5,
    })

    local mod, action = modifiers.add(container, "strength", {
        source = "buff:sunder",
        type = MOD_TYPE.FLAT,
        value = 10,
        max_stacks = 5,
    })

    assert_eq(action, "stacked")
    assert_eq(mod.stacks, 2)
end)

test("add() replaces when at max stacks", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- Single stack max
    modifiers.add(container, "strength", {
        source = "buff:single",
        value = 10,
        max_stacks = 1,
    })

    local mod, action = modifiers.add(container, "strength", {
        source = "buff:single",
        value = 20,
        max_stacks = 1,
    })

    assert_eq(action, "replaced")
    assert_eq(mod.value, 20)
end)

test("add() refreshes duration on stack", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "buff:refresh",
        value = 10,
        duration = 60,
        max_stacks = 5,
    })

    local mod1 = modifiers.get(container, "strength", "buff:refresh")
    local original_expiry = mod1.expires_at

    -- Add another stack with new duration
    modifiers.add(container, "strength", {
        source = "buff:refresh",
        value = 10,
        duration = 120,
        max_stacks = 5,
    })

    local mod2 = modifiers.get(container, "strength", "buff:refresh")
    assert_true(mod2.expires_at > original_expiry, "Duration should be refreshed")
end)

test("add() sorts by priority", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- Add in reverse priority order
    modifiers.add(container, "strength", {
        source = "mult",
        type = MOD_TYPE.MULTIPLIER,
        value = 1.5,
    })

    modifiers.add(container, "strength", {
        source = "flat",
        type = MOD_TYPE.FLAT,
        value = 10,
    })

    modifiers.add(container, "strength", {
        source = "pct",
        type = MOD_TYPE.PERCENT,
        value = 20,
    })

    local mods = modifiers.get_all(container, "strength")
    assert_eq(mods[1].source, "flat", "Flat should be first")
    assert_eq(mods[2].source, "pct", "Percent should be second")
    assert_eq(mods[3].source, "mult", "Multiplier should be third")
end)
-- }}}

-- {{{ Remove Modifier Tests
test_section("Remove Modifier")

test("remove() removes by source", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "buff:might",
        value = 20,
    })

    assert_true(modifiers.has(container, "strength", "buff:might"))
    assert_true(modifiers.remove(container, "strength", "buff:might"))
    assert_false(modifiers.has(container, "strength", "buff:might"))
end)

test("remove() returns false if not found", function()
    setup_test_attributes()
    local container = registry.create_container()

    assert_false(modifiers.remove(container, "strength", "nonexistent"))
end)

test("remove_stack() decrements and removes at zero", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "buff:stack",
        value = 10,
        stacks = 3,
        max_stacks = 5,
    })

    assert_eq(modifiers.remove_stack(container, "strength", "buff:stack"), 2)
    assert_eq(modifiers.remove_stack(container, "strength", "buff:stack"), 1)
    assert_eq(modifiers.remove_stack(container, "strength", "buff:stack"), 0)
    assert_false(modifiers.has(container, "strength", "buff:stack"))
end)

test("remove_by_source() removes from all attributes", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "equipment:sword",
        value = 20,
    })
    modifiers.add(container, "agility", {
        source = "equipment:sword",
        value = 10,
    })
    modifiers.add(container, "health", {
        source = "equipment:sword",
        value = 50,
    })
    modifiers.add(container, "strength", {
        source = "equipment:ring",
        value = 5,
    })

    local affected = modifiers.remove_by_source(container, "equipment:sword")

    assert_eq(#affected, 3)
    assert_false(modifiers.has(container, "strength", "equipment:sword"))
    assert_false(modifiers.has(container, "agility", "equipment:sword"))
    assert_false(modifiers.has(container, "health", "equipment:sword"))
    assert_true(modifiers.has(container, "strength", "equipment:ring"))
end)

test("remove_by_category() removes all of category", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "buff:might",
        category = SOURCE_CATEGORY.BUFF,
        value = 20,
    })
    modifiers.add(container, "strength", {
        source = "debuff:weakness",
        category = SOURCE_CATEGORY.DEBUFF,
        value = -10,
    })
    modifiers.add(container, "agility", {
        source = "buff:grace",
        category = SOURCE_CATEGORY.BUFF,
        value = 15,
    })

    local removed = modifiers.remove_by_category(container, SOURCE_CATEGORY.BUFF)

    assert_eq(#removed, 2)
    assert_false(modifiers.has(container, "strength", "buff:might"))
    assert_false(modifiers.has(container, "agility", "buff:grace"))
    assert_true(modifiers.has(container, "strength", "debuff:weakness"))
end)

test("clear() removes all modifiers from attribute", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", { source = "a", value = 1 })
    modifiers.add(container, "strength", { source = "b", value = 2 })
    modifiers.add(container, "strength", { source = "c", value = 3 })

    local count = modifiers.clear(container, "strength")

    assert_eq(count, 3)
    assert_eq(modifiers.count(container, "strength"), 0)
end)

test("clear_all() removes all modifiers", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", { source = "a", value = 1 })
    modifiers.add(container, "agility", { source = "b", value = 2 })
    modifiers.add(container, "health", { source = "c", value = 3 })

    local count = modifiers.clear_all(container)

    assert_eq(count, 3)
    assert_eq(modifiers.count(container, "strength"), 0)
    assert_eq(modifiers.count(container, "agility"), 0)
    assert_eq(modifiers.count(container, "health"), 0)
end)
-- }}}

-- {{{ Expiry Tests
test_section("Expiry System")

test("clean_expired() removes expired modifiers", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "expired",
        value = 10,
        expires_at = os.time() - 10,
    })
    modifiers.add(container, "strength", {
        source = "active",
        value = 20,
        expires_at = os.time() + 3600,
    })
    modifiers.add(container, "strength", {
        source = "permanent",
        value = 30,
    })

    local removed = modifiers.clean_expired(container)

    assert_eq(#removed, 1)
    assert_eq(removed[1].source, "expired")
    assert_false(modifiers.has(container, "strength", "expired"))
    assert_true(modifiers.has(container, "strength", "active"))
    assert_true(modifiers.has(container, "strength", "permanent"))
end)

test("refresh() updates modifier duration", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "buff:test",
        value = 10,
        duration = 60,
    })

    local mod1 = modifiers.get(container, "strength", "buff:test")
    local original = mod1.expires_at

    assert_true(modifiers.refresh(container, "strength", "buff:test", 120))

    local mod2 = modifiers.get(container, "strength", "buff:test")
    assert_true(mod2.expires_at > original)
end)
-- }}}

-- {{{ Query Tests
test_section("Query Functions")

test("get() returns modifier by source", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "buff:might",
        value = 20,
    })

    local mod = modifiers.get(container, "strength", "buff:might")
    assert_not_nil(mod)
    assert_eq(mod.value, 20)
end)

test("get_all() returns all modifiers", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", { source = "a", value = 1 })
    modifiers.add(container, "strength", { source = "b", value = 2 })
    modifiers.add(container, "strength", { source = "c", value = 3 })

    local mods = modifiers.get_all(container, "strength")
    assert_eq(#mods, 3)
end)

test("get_all() filters by category", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "buff:a",
        category = SOURCE_CATEGORY.BUFF,
        value = 1,
    })
    modifiers.add(container, "strength", {
        source = "equipment:b",
        category = SOURCE_CATEGORY.EQUIPMENT,
        value = 2,
    })

    local mods = modifiers.get_all(container, "strength", { category = SOURCE_CATEGORY.BUFF })
    assert_eq(#mods, 1)
    assert_eq(mods[1].source, "buff:a")
end)

test("get_all() filters by type", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "flat",
        type = MOD_TYPE.FLAT,
        value = 10,
    })
    modifiers.add(container, "strength", {
        source = "pct",
        type = MOD_TYPE.PERCENT,
        value = 20,
    })

    local mods = modifiers.get_all(container, "strength", { type = MOD_TYPE.PERCENT })
    assert_eq(#mods, 1)
    assert_eq(mods[1].source, "pct")
end)

test("get_all() filters active_only", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "active",
        value = 10,
    })
    modifiers.add(container, "strength", {
        source = "expired",
        value = 20,
        expires_at = os.time() - 10,
    })

    local mods = modifiers.get_all(container, "strength", { active_only = true })
    assert_eq(#mods, 1)
    assert_eq(mods[1].source, "active")
end)

test("count() returns modifier count", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", { source = "a", value = 1 })
    modifiers.add(container, "strength", { source = "b", value = 2 })

    assert_eq(modifiers.count(container, "strength"), 2)
end)

test("has() checks if modifier exists", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", { source = "exists", value = 1 })

    assert_true(modifiers.has(container, "strength", "exists"))
    assert_false(modifiers.has(container, "strength", "nonexistent"))
end)

test("list_sources() returns unique sources", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "equipment:sword",
        category = SOURCE_CATEGORY.EQUIPMENT,
        name = "Sword of Might",
        value = 20,
    })
    modifiers.add(container, "agility", {
        source = "equipment:sword",
        category = SOURCE_CATEGORY.EQUIPMENT,
        value = 10,
    })
    modifiers.add(container, "health", {
        source = "buff:fort",
        category = SOURCE_CATEGORY.BUFF,
        name = "Fortitude",
        value = 50,
    })

    local sources = modifiers.list_sources(container)
    assert_eq(#sources, 2)

    -- Find sword source
    local sword
    for _, s in ipairs(sources) do
        if s.source == "equipment:sword" then
            sword = s
            break
        end
    end
    assert_not_nil(sword)
    assert_eq(#sword.attr_ids, 2, "Should affect 2 attributes")
end)

test("list_sources() filters by category", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "equipment:sword",
        category = SOURCE_CATEGORY.EQUIPMENT,
        value = 20,
    })
    modifiers.add(container, "health", {
        source = "buff:fort",
        category = SOURCE_CATEGORY.BUFF,
        value = 50,
    })

    local sources = modifiers.list_sources(container, { category = SOURCE_CATEGORY.BUFF })
    assert_eq(#sources, 1)
    assert_eq(sources[1].source, "buff:fort")
end)
-- }}}

-- {{{ Application Tests
test_section("Modifier Application")

test("apply() applies flat modifier", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "test",
        type = MOD_TYPE.FLAT,
        value = 20,
    })

    local result = modifiers.apply(container, "strength", 10)
    assert_eq(result, 30)
end)

test("apply() applies percent modifier", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "test",
        type = MOD_TYPE.PERCENT,
        value = 50,  -- 50%
    })

    local result = modifiers.apply(container, "strength", 100)
    assert_eq(result, 150)
end)

test("apply() applies multiplier", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "test",
        type = MOD_TYPE.MULTIPLIER,
        value = 2,
    })

    local result = modifiers.apply(container, "strength", 50)
    assert_eq(result, 100)
end)

test("apply() applies override (last wins)", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "override1",
        type = MOD_TYPE.OVERRIDE,
        value = 100,
    })
    modifiers.add(container, "strength", {
        source = "override2",
        type = MOD_TYPE.OVERRIDE,
        value = 200,
    })

    local result = modifiers.apply(container, "strength", 10)
    assert_eq(result, 200, "Last override should win")
end)

test("apply() uses correct order", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- (10 + 20) * (1 + 0.5) * 2 = 30 * 1.5 * 2 = 90
    modifiers.add(container, "strength", {
        source = "flat",
        type = MOD_TYPE.FLAT,
        value = 20,
    })
    modifiers.add(container, "strength", {
        source = "pct",
        type = MOD_TYPE.PERCENT,
        value = 50,
    })
    modifiers.add(container, "strength", {
        source = "mult",
        type = MOD_TYPE.MULTIPLIER,
        value = 2,
    })

    local result = modifiers.apply(container, "strength", 10)
    assert_eq(result, 90)
end)

test("apply() considers stacks", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "stacking",
        type = MOD_TYPE.FLAT,
        value = 10,
        stacks = 3,
        max_stacks = 5,
    })

    local result = modifiers.apply(container, "strength", 10)
    assert_eq(result, 40)  -- 10 + (10 * 3)
end)

test("apply() skips inactive modifiers", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "active",
        type = MOD_TYPE.FLAT,
        value = 20,
    })
    modifiers.add(container, "strength", {
        source = "expired",
        type = MOD_TYPE.FLAT,
        value = 100,
        expires_at = os.time() - 10,
    })

    local result = modifiers.apply(container, "strength", 10)
    assert_eq(result, 30)  -- Only active modifier
end)

test("apply() respects conditions", function()
    setup_test_attributes()
    local container = registry.create_container()
    container.is_in_combat = false

    modifiers.add(container, "strength", {
        source = "combat_only",
        type = MOD_TYPE.FLAT,
        value = 50,
        condition = function(c)
            return c.is_in_combat == true
        end,
    })
    modifiers.add(container, "strength", {
        source = "always",
        type = MOD_TYPE.FLAT,
        value = 10,
    })

    -- Out of combat
    local result1 = modifiers.apply(container, "strength", 10)
    assert_eq(result1, 20)  -- Only "always"

    -- In combat
    container.is_in_combat = true
    local result2 = modifiers.apply(container, "strength", 10)
    assert_eq(result2, 70)  -- Both apply
end)
-- }}}

-- {{{ Breakdown Tests
test_section("Modifier Breakdown")

test("get_breakdown() returns detailed info", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "flat",
        type = MOD_TYPE.FLAT,
        value = 20,
        name = "Flat Bonus",
    })
    modifiers.add(container, "strength", {
        source = "pct",
        type = MOD_TYPE.PERCENT,
        value = 50,
        name = "Percent Bonus",
    })

    local breakdown = modifiers.get_breakdown(container, "strength", 10)

    assert_eq(breakdown.base, 10)
    assert_eq(breakdown.flat_total, 20)
    assert_eq(breakdown.percent_total, 50)
    assert_eq(breakdown.multiplier_total, 1)
    assert_nil(breakdown.override)
    assert_eq(breakdown.active_count, 2)
    assert_eq(#breakdown.sources, 2)
    assert_eq(breakdown.final, 45)  -- (10 + 20) * 1.5
end)

test("get_breakdown() shows inactive modifiers", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "active",
        value = 10,
    })
    modifiers.add(container, "strength", {
        source = "expired",
        value = 20,
        expires_at = os.time() - 10,
    })

    local breakdown = modifiers.get_breakdown(container, "strength", 10)

    assert_eq(breakdown.active_count, 1)
    assert_eq(breakdown.inactive_count, 1)
    assert_eq(#breakdown.sources, 2)
end)
-- }}}

-- {{{ Integration with Getters Tests
test_section("Integration with Getters")

test("getters.get() uses modifiers", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- Base strength is 10
    assert_eq(getters.get(container, "strength"), 10)

    modifiers.add(container, "strength", {
        source = "buff:might",
        type = MOD_TYPE.FLAT,
        value = 20,
    })

    assert_eq(getters.get(container, "strength"), 30)
end)

test("modifiers affect derived attributes", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- attack_power = strength * 2 + agility
    -- Initial: 10 * 2 + 10 = 30
    assert_eq(getters.get(container, "attack_power"), 30)

    modifiers.add(container, "strength", {
        source = "buff:might",
        type = MOD_TYPE.FLAT,
        value = 20,
    })

    -- Now: (10 + 20) * 2 + 10 = 70
    -- Note: getters applies modifiers to strength (30), then derived uses that
    assert_eq(getters.get(container, "attack_power"), 70)
end)

test("removing modifier updates derived", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "buff:might",
        type = MOD_TYPE.FLAT,
        value = 20,
    })

    assert_eq(getters.get(container, "attack_power"), 70)

    modifiers.remove(container, "strength", "buff:might")

    assert_eq(getters.get(container, "attack_power"), 30)
end)
-- }}}

-- {{{ set_stacks Tests
test_section("Stack Management")

test("set_stacks() sets stack count", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "stacking",
        value = 10,
        max_stacks = 5,
    })

    local new_stacks = modifiers.set_stacks(container, "strength", "stacking", 3)
    assert_eq(new_stacks, 3)

    local mod = modifiers.get(container, "strength", "stacking")
    assert_eq(mod.stacks, 3)
end)

test("set_stacks() clamps to range", function()
    setup_test_attributes()
    local container = registry.create_container()

    modifiers.add(container, "strength", {
        source = "stacking",
        value = 10,
        max_stacks = 5,
    })

    -- Try to set above max
    local high = modifiers.set_stacks(container, "strength", "stacking", 10)
    assert_eq(high, 5)

    -- Try to set below min
    local low = modifiers.set_stacks(container, "strength", "stacking", 0)
    assert_eq(low, 1)
end)
-- }}}

-- {{{ Test Summary
print("\n=== Test Summary ===")
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", test_count - pass_count))
print(string.format("Total: %d", test_count))

if pass_count == test_count then
    print("All tests PASSED!")
    os.exit(0)
else
    print("Some tests FAILED!")
    os.exit(1)
end
-- }}}
