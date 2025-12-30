# Issue 016i: Integration Tests

## Current Behavior

No tests exist for the attribute system since it hasn't been implemented yet.

## Intended Behavior

A comprehensive test suite that:
- Tests each component in isolation
- Tests component interactions (registry → getters → setters → modifiers → derived)
- Tests WC3 and WoW config correctness
- Tests cross-system mapping accuracy
- Provides regression protection for formula changes

## Suggested Implementation Steps

### 1. Test Infrastructure

```lua
-- src/tests/test_attributes.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/?.lua;" .. DIR .. "/?/init.lua;" .. package.path

-- {{{ Test Framework
local tests_run = 0
local tests_passed = 0
local tests_failed = 0
local current_suite = ""

local function suite(name)
    current_suite = name
    print("\n=== " .. name .. " ===")
end

local function test(name, fn)
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("  ✓ " .. name)
    else
        tests_failed = tests_failed + 1
        print("  ✗ " .. name)
        print("    Error: " .. tostring(err))
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

local function assert_near(actual, expected, tolerance, msg)
    tolerance = tolerance or 0.001
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s: expected ~%s, got %s (tolerance: %s)",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual),
            tostring(tolerance)))
    end
end

local function assert_true(condition, msg)
    if not condition then
        error(msg or "Expected true")
    end
end

local function assert_false(condition, msg)
    if condition then
        error(msg or "Expected false")
    end
end
-- }}}
```

### 2. Registry Tests

```lua
-- {{{ Registry Tests
suite("Attribute Registry")

test("register single attribute", function()
    local registry = require("src.libs.attributes.registry")
    registry.clear()  -- Reset for testing

    local schema = registry.register({
        id = "test_attr",
        type = "integer",
        min = 0, max = 100,
        default = 50,
    })

    assert_eq(schema.id, "test_attr")
    assert_eq(schema.default, 50)
    assert_true(schema.index ~= nil, "Should have numeric index")
end)

test("bulk registration", function()
    local registry = require("src.libs.attributes.registry")
    registry.clear()

    registry.register_bulk({
        attr_a = { type = "integer", default = 10 },
        attr_b = { type = "integer", default = 20 },
        attr_c = { type = "float", default = 1.5 },
    })

    assert_eq(registry.get("attr_a").default, 10)
    assert_eq(registry.get("attr_b").default, 20)
    assert_near(registry.get("attr_c").default, 1.5)
end)

test("create container with defaults", function()
    local registry = require("src.libs.attributes.registry")
    registry.clear()

    registry.register({ id = "health", default = 100 })
    registry.register({ id = "mana", default = 50 })

    local container = registry.create_container()

    local getters = require("src.libs.attributes.getters")
    assert_eq(getters.get(container, "health"), 100)
    assert_eq(getters.get(container, "mana"), 50)
end)

test("dependency graph tracking", function()
    local registry = require("src.libs.attributes.registry")
    registry.clear()

    registry.register({ id = "strength", default = 10 })
    registry.register({
        id = "attack_power",
        derived_from = { "strength" },
        formula = function(get) return get("strength") * 2 end,
    })

    local deps = registry.get_dependents("strength")
    assert_true(#deps > 0, "Should have dependents")
    assert_eq(deps[1], "attack_power")
end)
-- }}}
```

### 3. Getter/Setter Tests

```lua
-- {{{ Getter/Setter Tests
suite("Getters and Setters")

test("basic get and set", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    registry.register({ id = "value", default = 0, min = 0, max = 100 })
    local container = registry.create_container()

    setters.set(container, "value", 42)
    assert_eq(getters.get(container, "value"), 42)
end)

test("validation rejects out of range", function()
    local registry = require("src.libs.attributes.registry")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    registry.register({ id = "capped", min = 0, max = 100 })
    local container = registry.create_container()

    local ok, err = setters.set(container, "capped", 150)
    assert_false(ok, "Should reject value above max")
    assert_true(err:find("max"), "Error should mention max")
end)

test("clamp option", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    registry.register({ id = "clamped", min = 0, max = 100 })
    local container = registry.create_container()

    setters.set(container, "clamped", 999, { clamp = true })
    assert_eq(getters.get(container, "clamped"), 100)
end)

test("adjust adds to current value", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    registry.register({ id = "counter", default = 10 })
    local container = registry.create_container()

    setters.adjust(container, "counter", 5)
    assert_eq(getters.get(container, "counter"), 15)

    setters.adjust(container, "counter", -3)
    assert_eq(getters.get(container, "counter"), 12)
end)

test("batch set_many", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    registry.register({ id = "a", default = 0 })
    registry.register({ id = "b", default = 0 })
    registry.register({ id = "c", default = 0 })
    local container = registry.create_container()

    setters.set_many(container, { a = 1, b = 2, c = 3 })

    assert_eq(getters.get(container, "a"), 1)
    assert_eq(getters.get(container, "b"), 2)
    assert_eq(getters.get(container, "c"), 3)
end)
-- }}}
```

### 4. Modifier Tests

```lua
-- {{{ Modifier Tests
suite("Modifier Stack")

test("flat modifier adds to base", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local modifiers = require("src.libs.attributes.modifiers")
    registry.clear()

    registry.register({ id = "damage", default = 10 })
    local container = registry.create_container()

    modifiers.add_modifier(container, "damage", {
        source = "weapon:sword",
        type = "flat",
        value = 5,
    })

    assert_eq(getters.get(container, "damage"), 15)
end)

test("percent modifier scales value", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local modifiers = require("src.libs.attributes.modifiers")
    registry.clear()

    registry.register({ id = "power", default = 100 })
    local container = registry.create_container()

    modifiers.add_modifier(container, "power", {
        source = "buff:might",
        type = "percent",
        value = 20,  -- 20%
    })

    assert_eq(getters.get(container, "power"), 120)
end)

test("modifier application order", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local modifiers = require("src.libs.attributes.modifiers")
    registry.clear()

    registry.register({ id = "stat", default = 100 })
    local container = registry.create_container()

    -- Order: (base + flat) * (1 + percent/100) * multiplier
    modifiers.add_modifier(container, "stat", {
        source = "item:ring",
        type = "flat",
        value = 50,
    })
    modifiers.add_modifier(container, "stat", {
        source = "buff:blessing",
        type = "percent",
        value = 10,
    })
    modifiers.add_modifier(container, "stat", {
        source = "aura:might",
        type = "multiplier",
        value = 1.5,
    })

    -- (100 + 50) * (1 + 10/100) * 1.5 = 150 * 1.1 * 1.5 = 247.5
    assert_near(getters.get(container, "stat"), 247.5)
end)

test("remove modifier by source", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local modifiers = require("src.libs.attributes.modifiers")
    registry.clear()

    registry.register({ id = "armor", default = 100 })
    local container = registry.create_container()

    modifiers.add_modifier(container, "armor", {
        source = "item:shield",
        type = "flat",
        value = 50,
    })
    assert_eq(getters.get(container, "armor"), 150)

    modifiers.remove_modifier(container, "armor", "item:shield")
    assert_eq(getters.get(container, "armor"), 100)
end)

test("stacking modifiers", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local modifiers = require("src.libs.attributes.modifiers")
    registry.clear()

    registry.register({ id = "stacks", default = 10 })
    local container = registry.create_container()

    -- Add stacking buff (max 5 stacks)
    for i = 1, 7 do  -- Try to add 7, should cap at 5
        modifiers.add_modifier(container, "stacks", {
            source = "buff:sunder",
            type = "flat",
            value = 2,
            max_stacks = 5,
        })
    end

    -- Base 10 + (2 * 5 stacks) = 20
    assert_eq(getters.get(container, "stacks"), 20)
end)
-- }}}
```

### 5. Derived Attribute Tests

```lua
-- {{{ Derived Attribute Tests
suite("Derived Attributes")

test("simple derived calculation", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    registry.register({ id = "strength", default = 10 })
    registry.register({
        id = "attack_power",
        derived_from = { "strength" },
        formula = function(get) return get("strength") * 2 end,
    })
    getters.rebuild()

    local container = registry.create_container()
    assert_eq(getters.get(container, "attack_power"), 20)

    setters.set(container, "strength", 25)
    assert_eq(getters.get(container, "attack_power"), 50)
end)

test("multi-level derivation", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    registry.register({ id = "base", default = 10 })
    registry.register({
        id = "level1",
        derived_from = { "base" },
        formula = function(get) return get("base") * 2 end,
    })
    registry.register({
        id = "level2",
        derived_from = { "level1" },
        formula = function(get) return get("level1") + 5 end,
    })
    getters.rebuild()

    local container = registry.create_container()

    -- base=10 -> level1=20 -> level2=25
    assert_eq(getters.get(container, "level2"), 25)

    setters.set(container, "base", 20)
    -- base=20 -> level1=40 -> level2=45
    assert_eq(getters.get(container, "level2"), 45)
end)

test("derived with modifiers on dependency", function()
    local registry = require("src.libs.attributes.registry")
    local getters = require("src.libs.attributes.getters")
    local modifiers = require("src.libs.attributes.modifiers")
    registry.clear()

    registry.register({ id = "stamina", default = 20 })
    registry.register({
        id = "max_health",
        derived_from = { "stamina" },
        formula = function(get) return get("stamina") * 10 end,
    })
    getters.rebuild()

    local container = registry.create_container()
    assert_eq(getters.get(container, "max_health"), 200)

    modifiers.add_modifier(container, "stamina", {
        source = "item:fortitude",
        type = "flat",
        value = 10,
    })

    -- stamina = 20 + 10 = 30, max_health = 30 * 10 = 300
    assert_eq(getters.get(container, "max_health"), 300)
end)
-- }}}
```

### 6. WC3 Config Tests

```lua
-- {{{ WC3 Config Tests
suite("WC3 Attribute Config")

test("hero class application", function()
    local registry = require("src.libs.attributes.registry")
    local wc3 = require("src.libs.attributes.configs.wc3")
    local getters = require("src.libs.attributes.getters")
    registry.clear()

    wc3.register_all()
    getters.rebuild()

    local container = registry.create_container()
    wc3.apply_hero_class(container, "paladin", 1)

    assert_eq(getters.get(container, "level"), 1)
    assert_eq(getters.get(container, "primary_stat"), "strength")
    assert_eq(getters.get(container, "strength"), 24)
end)

test("stat gains per level", function()
    local registry = require("src.libs.attributes.registry")
    local wc3 = require("src.libs.attributes.configs.wc3")
    local getters = require("src.libs.attributes.getters")
    registry.clear()

    wc3.register_all()
    getters.rebuild()

    local container = registry.create_container()
    wc3.apply_hero_class(container, "archmage", 10)

    -- Archmage: base INT 24, 3.2 per level, 9 levels gained
    -- INT = 24 + floor(3.2 * 9) = 24 + 28 = 52
    assert_eq(getters.get(container, "intelligence"), 52)
end)

test("WC3 health formula", function()
    local registry = require("src.libs.attributes.registry")
    local wc3 = require("src.libs.attributes.configs.wc3")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    wc3.register_all()
    getters.rebuild()

    local container = registry.create_container()
    setters.set(container, "base_health", 100)
    setters.set(container, "strength", 20)

    -- max_health = base_health + (strength * 25) = 100 + 500 = 600
    assert_eq(getters.get(container, "max_health"), 600)
end)

test("WC3 armor formula", function()
    local registry = require("src.libs.attributes.registry")
    local wc3 = require("src.libs.attributes.configs.wc3")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    wc3.register_all()
    getters.rebuild()

    local container = registry.create_container()
    setters.set(container, "base_armor", 5)
    setters.set(container, "agility", 30)

    -- armor = base_armor + (agility / 3) = 5 + 10 = 15
    assert_near(getters.get(container, "armor"), 15)
end)
-- }}}
```

### 7. WoW Config Tests

```lua
-- {{{ WoW Config Tests
suite("WoW Attribute Config")

test("health from stamina", function()
    local registry = require("src.libs.attributes.registry")
    local wow = require("src.libs.attributes.configs.wow")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    wow.register_all()
    getters.rebuild()

    local container = registry.create_container()
    setters.set(container, "base_health", 100)
    setters.set(container, "stamina", 50)

    -- max_health = base + 20 + (stamina - 20) * 10 = 100 + 20 + 300 = 420
    assert_eq(getters.get(container, "max_health"), 420)
end)

test("crit from rating and agility", function()
    local registry = require("src.libs.attributes.registry")
    local wow = require("src.libs.attributes.configs.wow")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    wow.register_all()
    getters.rebuild()

    local container = registry.create_container()
    setters.set(container, "class", "warrior")
    setters.set(container, "crit_rating", 110)  -- ~5%
    setters.set(container, "agility", 66)       -- ~2% for warrior

    -- 5% base + 5% from rating + 2% from agi = 12%
    assert_near(getters.get(container, "crit_chance"), 12, 0.5)
end)

test("attack power calculation", function()
    local registry = require("src.libs.attributes.registry")
    local wow = require("src.libs.attributes.configs.wow")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    wow.register_all()
    getters.rebuild()

    local container = registry.create_container()
    setters.set(container, "class", "rogue")
    setters.set(container, "strength", 50)
    setters.set(container, "agility", 100)
    setters.set(container, "base_attack_power", 200)

    -- Rogue: AP = base + (str * 2) + agi = 200 + 100 + 100 = 400
    assert_eq(getters.get(container, "attack_power"), 400)
end)
-- }}}
```

### 8. Cross-System Mapping Tests

```lua
-- {{{ Cross-System Mapping Tests
suite("Cross-System Mapping")

test("parallel attribute conversion", function()
    local mapper = require("src.libs.attributes.mapping")

    local result = mapper.convert_value("wc3", "wow", "strength", 50)
    assert_eq(result.target, "strength")
    assert_eq(result.value, 50)  -- 1:1 mapping
end)

test("armor scaling between systems", function()
    local mapper = require("src.libs.attributes.mapping")

    -- WC3 armor 10 -> WoW armor 100 (factor 10x)
    local result = mapper.convert_value("wc3", "wow", "armor", 10)
    assert_eq(result.target, "armor")
    assert_eq(result.value, 100)
end)

test("bidirectional conversion", function()
    local mapper = require("src.libs.attributes.mapping")

    -- WC3 -> WoW
    local forward = mapper.convert_value("wc3", "wow", "armor", 10)
    assert_eq(forward.value, 100)

    -- WoW -> WC3 (should reverse)
    local backward = mapper.convert_value("wow", "wc3", "armor", 100)
    assert_eq(backward.value, 10)
end)

test("semantic mapping application", function()
    local registry = require("src.libs.attributes.registry")
    local wc3 = require("src.libs.attributes.configs.wc3")
    local mapper = require("src.libs.attributes.mapping")
    local getters = require("src.libs.attributes.getters")
    local setters = require("src.libs.attributes.setters")
    registry.clear()

    wc3.register_all()
    getters.rebuild()

    local container = registry.create_container()
    setters.set(container, "base_health", 100)
    setters.set(container, "strength", 40)

    -- Apply semantic mapping to derive WoW stamina
    local result = mapper.apply_semantic_mapping(container, "wc3_to_wow_stamina")
    assert_true(result ~= nil, "Should produce result")
    assert_eq(result.target, "stamina")
    -- Value should be derived from WC3 max_health formula
end)
-- }}}
```

### 9. Test Runner

```lua
-- {{{ Run All Tests
print("\n" .. string.rep("=", 60))
print("  ATTRIBUTE SYSTEM INTEGRATION TESTS")
print(string.rep("=", 60))

-- Tests are run as they're defined above

print("\n" .. string.rep("=", 60))
print(string.format("  Results: %d passed, %d failed, %d total",
    tests_passed, tests_failed, tests_run))
print(string.rep("=", 60))

if tests_failed > 0 then
    os.exit(1)
end
-- }}}
```

## Related Documents

- Issue 016a through 016h - All component issues
- `src/tests/` - Test directory structure

## Acceptance Criteria

- [ ] Registry tests: registration, lookup, container creation
- [ ] Getter tests: get, get_raw, get_many
- [ ] Setter tests: set, adjust, validate, clamp
- [ ] Modifier tests: flat, percent, multiplier, stacking, removal
- [ ] Derived tests: simple, multi-level, with modifiers
- [ ] WC3 tests: formulas match expected values
- [ ] WoW tests: formulas match expected values
- [ ] Mapping tests: conversion accuracy both directions
- [ ] All tests pass with 0 failures

---

**Status:** Pending
**Dependencies:** 016a-016h (all components)

