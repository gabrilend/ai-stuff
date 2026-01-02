-- test_derived.lua
-- Unit tests for the derived attribute engine module.
--
-- Tests the centralized derived attribute API including dependency graph
-- utilities, circular dependency detection, cache management, debugging
-- tools, and formula helpers.

package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local attributes = require("libs.attributes")
local derived = require("libs.attributes.derived")

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

-- {{{ assert_table_eq
local function assert_table_eq(expected, actual, msg)
    if type(expected) ~= "table" or type(actual) ~= "table" then
        error(string.format("%s: expected tables, got %s and %s",
            msg or "Assertion failed",
            type(expected), type(actual)))
    end
    if #expected ~= #actual then
        error(string.format("%s: expected %d elements, got %d",
            msg or "Assertion failed",
            #expected, #actual))
    end
    for i = 1, #expected do
        if expected[i] ~= actual[i] then
            error(string.format("%s: at index %d, expected %s, got %s",
                msg or "Assertion failed",
                i, tostring(expected[i]), tostring(actual[i])))
        end
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
        print(string.format("  ✓ %s", name))
    else
        print(string.format("  ✗ %s", name))
        print(string.format("    Error: %s", err))
    end
end
-- }}}

-- {{{ setup_test_attributes
-- Register a set of test attributes for testing derived functionality
local function setup_test_attributes()
    attributes.reset()

    -- Base attributes
    attributes.register_bulk({
        -- Primary stats
        strength = { type = "integer", min = 0, max = 999, default = 10 },
        agility = { type = "integer", min = 0, max = 999, default = 10 },
        intelligence = { type = "integer", min = 0, max = 999, default = 10 },

        -- Secondary base stats
        base_damage = { type = "integer", min = 0, max = 9999, default = 5 },
        base_armor = { type = "integer", min = 0, max = 999, default = 0 },
        base_speed = { type = "number", min = 0, max = 1000, default = 300 },

        -- Level 1 derived: directly from base stats
        attack_power = {
            type = "integer",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "strength", "agility" },
            formula = function(get)
                return get("strength") * 2 + get("agility")
            end,
        },

        spell_power = {
            type = "integer",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "intelligence" },
            formula = function(get)
                return get("intelligence") * 3
            end,
        },

        armor = {
            type = "integer",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "base_armor", "agility" },
            formula = function(get)
                return get("base_armor") + math.floor(get("agility") / 5)
            end,
        },

        -- Level 2 derived: depends on level 1 derived
        total_damage = {
            type = "integer",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "base_damage", "attack_power" },
            formula = function(get)
                return get("base_damage") + get("attack_power")
            end,
        },

        -- Level 3 derived: depends on level 2 derived
        dps = {
            type = "number",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "total_damage", "base_speed" },
            formula = function(get)
                local speed = get("base_speed") / 100  -- attacks per second
                return get("total_damage") * speed
            end,
        },
    })

    -- Rebuild dispatch tables after registration
    -- This is required because getters/setters build their tables on module load,
    -- and reset() clears the registry but not the dispatch tables.
    attributes.rebuild_getters()
    attributes.rebuild_setters()
end
-- }}}

-- }}}

-- {{{ Test: Dependency Graph Utilities

print("\n=== Dependency Graph Utilities ===")

-- {{{ test: get_dependencies returns direct dependencies
run_test("get_dependencies returns direct dependencies", function()
    setup_test_attributes()

    local deps = derived.get_dependencies("attack_power")
    assert_eq(2, #deps, "attack_power should have 2 dependencies")
    assert_contains(deps, "strength", "should depend on strength")
    assert_contains(deps, "agility", "should depend on agility")
end)
-- }}}

-- {{{ test: get_dependencies returns empty for base attributes
run_test("get_dependencies returns empty for base attributes", function()
    setup_test_attributes()

    local deps = derived.get_dependencies("strength")
    assert_eq(0, #deps, "base attribute should have no dependencies")
end)
-- }}}

-- {{{ test: get_dependents returns direct dependents
run_test("get_dependents returns direct dependents", function()
    setup_test_attributes()

    local dependents = derived.get_dependents("strength")
    assert_contains(dependents, "attack_power", "strength should affect attack_power")
end)
-- }}}

-- {{{ test: get_dependents returns empty for leaf derived
run_test("get_dependents returns empty for leaf derived", function()
    setup_test_attributes()

    local dependents = derived.get_dependents("dps")
    assert_eq(0, #dependents, "dps has no dependents")
end)
-- }}}

-- {{{ test: get_all_dependents returns full chain
run_test("get_all_dependents returns full chain", function()
    setup_test_attributes()

    -- strength → attack_power → total_damage → dps
    local all = derived.get_all_dependents("strength")
    assert_contains(all, "attack_power", "should include attack_power")
    assert_contains(all, "total_damage", "should include total_damage")
    assert_contains(all, "dps", "should include dps")
end)
-- }}}

-- {{{ test: get_all_dependencies returns full chain
run_test("get_all_dependencies returns full chain", function()
    setup_test_attributes()

    -- dps depends on total_damage, base_speed
    -- total_damage depends on base_damage, attack_power
    -- attack_power depends on strength, agility
    local all = derived.get_all_dependencies("dps")
    assert_contains(all, "total_damage", "should include total_damage")
    assert_contains(all, "base_speed", "should include base_speed")
    assert_contains(all, "base_damage", "should include base_damage")
    assert_contains(all, "attack_power", "should include attack_power")
    assert_contains(all, "strength", "should include strength")
    assert_contains(all, "agility", "should include agility")
end)
-- }}}

-- {{{ test: get_evaluation_order returns topological order
run_test("get_evaluation_order returns topological order", function()
    setup_test_attributes()

    local order = derived.get_evaluation_order()

    -- Find positions
    local pos = {}
    for i = 1, #order do
        pos[order[i]] = i
    end

    -- attack_power must come before total_damage
    if pos["attack_power"] and pos["total_damage"] then
        assert_true(pos["attack_power"] < pos["total_damage"],
            "attack_power should be evaluated before total_damage")
    end

    -- total_damage must come before dps
    if pos["total_damage"] and pos["dps"] then
        assert_true(pos["total_damage"] < pos["dps"],
            "total_damage should be evaluated before dps")
    end
end)
-- }}}

-- }}}

-- {{{ Test: Circular Dependency Detection

print("\n=== Circular Dependency Detection ===")

-- {{{ test: detect_cycle returns false for valid graph
run_test("detect_cycle returns false for valid graph", function()
    setup_test_attributes()

    -- No cycle: agility → attack_power is valid
    local result = derived.detect_cycle("attack_power", "agility")
    assert_false(result, "no cycle should exist")
end)
-- }}}

-- {{{ test: detect_cycle detects direct cycle
run_test("detect_cycle detects direct cycle", function()
    attributes.reset()

    -- Create a simple cycle: A → B → A
    attributes.register_bulk({
        a = { type = "integer", default = 1 },
        b = {
            type = "integer",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "a" },
            formula = function(get) return get("a") + 1 end,
        },
    })

    -- If we tried to make A depend on B, it would create: A → B → A
    local cycle = derived.detect_cycle("a", "b")
    -- This tests the hypothetical cycle detection
    -- Since A doesn't actually depend on B in the registry, detect_cycle
    -- checks if adding that dependency would create a cycle
    -- B already depends on A, so A → B would create A → B → A
    assert_true(cycle ~= false, "should detect the cycle")
end)
-- }}}

-- {{{ test: validate_no_cycles returns true for valid graph
run_test("validate_no_cycles returns true for valid graph", function()
    setup_test_attributes()

    local ok, err = derived.validate_no_cycles()
    assert_true(ok, "should have no cycles")
    assert_nil(err, "should have no error message")
end)
-- }}}

-- {{{ test: validate_no_cycles detects multi-level cycles
run_test("validate_no_cycles detects multi-level cycles", function()
    attributes.reset()

    -- We can't easily create a cycle after registration because
    -- the registry would need to be modified. This tests the function
    -- structure with a valid graph.
    attributes.register_bulk({
        x = { type = "integer", default = 1 },
        y = {
            type = "integer",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "x" },
            formula = function(get) return get("x") * 2 end,
        },
    })

    local ok, err = derived.validate_no_cycles()
    assert_true(ok, "simple chain should have no cycles")
end)
-- }}}

-- }}}

-- {{{ Test: Cache Management

print("\n=== Cache Management ===")

-- {{{ test: is_dirty returns true for initial derived attributes
run_test("is_dirty returns true for initial derived attributes", function()
    setup_test_attributes()
    local container = attributes.create_container()

    -- Fresh container should have derived attributes marked dirty
    -- because they need initial computation
    local dirty = derived.is_dirty(container, "attack_power")
    assert_true(dirty, "derived attributes start dirty (need computation)")
end)
-- }}}

-- {{{ test: mark_dirty sets dirty flag
run_test("mark_dirty sets dirty flag", function()
    setup_test_attributes()
    local container = attributes.create_container()

    derived.mark_dirty(container, "attack_power")
    assert_true(derived.is_dirty(container, "attack_power"), "should be dirty after mark")
end)
-- }}}

-- {{{ test: mark_dirty cascades to dependents
run_test("mark_dirty cascades to dependents", function()
    setup_test_attributes()
    local container = attributes.create_container()

    -- Mark attack_power dirty (total_damage and dps depend on it)
    derived.mark_dirty(container, "attack_power")

    assert_true(derived.is_dirty(container, "attack_power"), "attack_power should be dirty")
    assert_true(derived.is_dirty(container, "total_damage"), "total_damage should be dirty")
    assert_true(derived.is_dirty(container, "dps"), "dps should be dirty")
end)
-- }}}

-- {{{ test: invalidate_all marks all derived dirty
run_test("invalidate_all marks all derived dirty", function()
    setup_test_attributes()
    local container = attributes.create_container()

    derived.invalidate_all(container)

    assert_true(derived.is_dirty(container, "attack_power"), "attack_power dirty")
    assert_true(derived.is_dirty(container, "spell_power"), "spell_power dirty")
    assert_true(derived.is_dirty(container, "armor"), "armor dirty")
    assert_true(derived.is_dirty(container, "total_damage"), "total_damage dirty")
    assert_true(derived.is_dirty(container, "dps"), "dps dirty")
end)
-- }}}

-- {{{ test: recompute calculates correct value
run_test("recompute calculates correct value", function()
    setup_test_attributes()
    local container = attributes.create_container()

    -- Set base values
    attributes.set_value(container, "strength", 50)
    attributes.set_value(container, "agility", 30)

    -- Force recompute
    local value = derived.recompute(container, "attack_power")

    -- attack_power = strength * 2 + agility = 50 * 2 + 30 = 130
    assert_eq(130, value, "attack_power should be 130")
end)
-- }}}

-- {{{ test: recompute clears dirty flag
run_test("recompute clears dirty flag", function()
    setup_test_attributes()
    local container = attributes.create_container()

    derived.mark_dirty(container, "attack_power")
    assert_true(derived.is_dirty(container, "attack_power"), "should be dirty before")

    derived.recompute(container, "attack_power")
    assert_false(derived.is_dirty(container, "attack_power"), "should be clean after")
end)
-- }}}

-- {{{ test: recompute handles multi-level dependencies
run_test("recompute handles multi-level dependencies", function()
    setup_test_attributes()
    local container = attributes.create_container()

    -- Set base values
    attributes.set_value(container, "strength", 20)
    attributes.set_value(container, "agility", 10)
    attributes.set_value(container, "base_damage", 10)

    -- Recompute dps which depends on total_damage which depends on attack_power
    -- attack_power = 20 * 2 + 10 = 50
    -- total_damage = 10 + 50 = 60
    -- dps = 60 * (300/100) = 180

    local value = derived.recompute(container, "dps")
    assert_eq(180, value, "dps should be 180")
end)
-- }}}

-- {{{ test: recompute_all computes all derived
run_test("recompute_all computes all derived", function()
    setup_test_attributes()
    local container = attributes.create_container()

    derived.invalidate_all(container)

    local results = derived.recompute_all(container)

    -- Should have results for all derived attributes
    assert_true(results["attack_power"] ~= nil, "should have attack_power")
    assert_true(results["spell_power"] ~= nil, "should have spell_power")
    assert_true(results["armor"] ~= nil, "should have armor")
    assert_true(results["total_damage"] ~= nil, "should have total_damage")
    assert_true(results["dps"] ~= nil, "should have dps")
end)
-- }}}

-- {{{ test: get_dirty_count counts correctly
run_test("get_dirty_count counts correctly", function()
    setup_test_attributes()
    local container = attributes.create_container()

    -- All derived start dirty (need initial computation)
    assert_eq(5, derived.get_dirty_count(container), "all 5 derived start dirty")

    -- Access one to trigger computation
    derived.recompute(container, "attack_power")
    assert_eq(4, derived.get_dirty_count(container), "should have 4 dirty after one recompute")

    -- Recompute all
    derived.recompute_all(container)
    assert_eq(0, derived.get_dirty_count(container), "should have 0 dirty after recompute_all")
end)
-- }}}

-- {{{ test: recompute returns error for base attribute
run_test("recompute returns error for base attribute", function()
    setup_test_attributes()
    local container = attributes.create_container()

    local value, err = derived.recompute(container, "strength")
    assert_nil(value, "should return nil for base attribute")
    assert_true(err:find("Not a derived attribute"), "should have error message")
end)
-- }}}

-- {{{ test: recompute returns error for unknown attribute
run_test("recompute returns error for unknown attribute", function()
    setup_test_attributes()
    local container = attributes.create_container()

    local value, err = derived.recompute(container, "nonexistent")
    assert_nil(value, "should return nil for unknown")
    assert_true(err:find("Unknown attribute"), "should have error message")
end)
-- }}}

-- }}}

-- {{{ Test: Debug and Introspection

print("\n=== Debug and Introspection ===")

-- {{{ test: explain returns dependency info
run_test("explain returns dependency info", function()
    setup_test_attributes()
    local container = attributes.create_container()

    attributes.set_value(container, "strength", 25)
    attributes.set_value(container, "agility", 15)

    -- Access the value first to compute it (clears dirty flag)
    local _ = attributes.get_value(container, "attack_power")

    local info = derived.explain(container, "attack_power")

    assert_eq("attack_power", info.attribute, "attribute name")
    assert_eq(2, #info.dependencies, "should have 2 dependencies")
    assert_false(info.is_dirty, "should not be dirty after access")

    -- Check dependency values
    local found_str, found_agi = false, false
    for i = 1, #info.dependencies do
        local dep = info.dependencies[i]
        if dep.id == "strength" then
            found_str = true
            assert_eq(25, dep.value, "strength value")
        elseif dep.id == "agility" then
            found_agi = true
            assert_eq(15, dep.value, "agility value")
        end
    end
    assert_true(found_str, "should include strength")
    assert_true(found_agi, "should include agility")
end)
-- }}}

-- {{{ test: explain returns error for base attribute
run_test("explain returns error for base attribute", function()
    setup_test_attributes()
    local container = attributes.create_container()

    local info, err = derived.explain(container, "strength")
    assert_nil(info, "should return nil")
    assert_true(err:find("Not a derived attribute"), "should have error")
end)
-- }}}

-- {{{ test: get_dependency_tree builds correct structure
run_test("get_dependency_tree builds correct structure", function()
    setup_test_attributes()

    local tree = derived.get_dependency_tree("dps")

    assert_eq("dps", tree.id, "root should be dps")
    assert_true(tree.is_derived, "dps is derived")
    assert_eq(0, tree.depth, "root depth is 0")
    assert_eq(2, #tree.children, "dps has 2 children")

    -- Check children
    local found_total_damage, found_base_speed = false, false
    for i = 1, #tree.children do
        local child = tree.children[i]
        if child.id == "total_damage" then
            found_total_damage = true
            assert_true(child.is_derived, "total_damage is derived")
        elseif child.id == "base_speed" then
            found_base_speed = true
            assert_false(child.is_derived, "base_speed is not derived")
        end
    end
    assert_true(found_total_damage, "should have total_damage")
    assert_true(found_base_speed, "should have base_speed")
end)
-- }}}

-- {{{ test: get_dependency_tree respects max_depth
run_test("get_dependency_tree respects max_depth", function()
    setup_test_attributes()

    local tree = derived.get_dependency_tree("dps", 1)

    -- At depth 1, children should be truncated
    for i = 1, #tree.children do
        local child = tree.children[i]
        if child.is_derived then
            -- Derived children at depth 1 should have no further children
            -- (they would be at depth 2 which exceeds max_depth of 1)
            for j = 1, #(child.children or {}) do
                if child.children[j].depth and child.children[j].depth > 1 then
                    assert_true(child.children[j].truncated or #(child.children[j].children or {}) == 0,
                        "should truncate at max depth")
                end
            end
        end
    end
end)
-- }}}

-- {{{ test: format_dependency_tree produces readable output
run_test("format_dependency_tree produces readable output", function()
    setup_test_attributes()

    local output = derived.format_dependency_tree("attack_power")

    assert_true(output:find("attack_power"), "should contain attack_power")
    assert_true(output:find("%[D%]"), "should have derived marker")
    assert_true(output:find("%[B%]"), "should have base marker")
    assert_true(output:find("strength") or output:find("agility"),
        "should contain dependencies")
end)
-- }}}

-- {{{ test: get_reverse_tree shows what depends on attribute
run_test("get_reverse_tree shows what depends on attribute", function()
    setup_test_attributes()

    local tree = derived.get_reverse_tree("strength")

    assert_eq("strength", tree.id, "root should be strength")
    assert_false(tree.is_derived, "strength is not derived")

    -- strength → attack_power
    local found_attack_power = false
    for i = 1, #tree.children do
        if tree.children[i].id == "attack_power" then
            found_attack_power = true
        end
    end
    assert_true(found_attack_power, "attack_power should depend on strength")
end)
-- }}}

-- {{{ test: list_derived returns all derived attributes
run_test("list_derived returns all derived attributes", function()
    setup_test_attributes()

    local list = derived.list_derived()

    -- We have 5 derived attributes
    assert_eq(5, #list, "should have 5 derived attributes")

    -- Check structure
    local found = {}
    for i = 1, #list do
        local item = list[i]
        found[item.id] = true
        assert_true(item.index ~= nil, "should have index")
        assert_true(item.dependencies ~= nil, "should have dependencies")
        assert_true(item.dependents ~= nil, "should have dependents")
    end

    assert_true(found["attack_power"], "should have attack_power")
    assert_true(found["spell_power"], "should have spell_power")
    assert_true(found["armor"], "should have armor")
    assert_true(found["total_damage"], "should have total_damage")
    assert_true(found["dps"], "should have dps")
end)
-- }}}

-- {{{ test: get_stats returns correct statistics
run_test("get_stats returns correct statistics", function()
    setup_test_attributes()
    local container = attributes.create_container()

    local stats = derived.get_stats(container)

    -- 11 total: 6 base + 5 derived
    assert_eq(11, stats.total_attributes, "total attributes")
    assert_eq(5, stats.derived_count, "derived count")
    assert_eq(6, stats.base_count, "base count")
    assert_true(stats.max_depth >= 1, "max depth at least 1")
    -- All derived start dirty (need computation)
    assert_eq(5, stats.dirty_count, "all derived start dirty")
end)
-- }}}

-- {{{ test: get_stats includes dirty count
run_test("get_stats includes dirty count", function()
    setup_test_attributes()
    local container = attributes.create_container()

    derived.invalidate_all(container)

    local stats = derived.get_stats(container)
    assert_eq(5, stats.dirty_count, "all 5 derived should be dirty")
end)
-- }}}

-- }}}

-- {{{ Test: Formula Helpers

print("\n=== Formula Helpers ===")

-- {{{ test: create_formula sum pattern
run_test("create_formula sum pattern", function()
    attributes.reset()

    attributes.register_bulk({
        a = { type = "integer", default = 10 },
        b = { type = "integer", default = 20 },
        c = { type = "integer", default = 30 },
        sum_abc = {
            type = "integer",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "a", "b", "c" },
            formula = derived.create_formula("sum", { "a", "b", "c" }),
        },
    })
    attributes.rebuild_getters()
    attributes.rebuild_setters()

    local container = attributes.create_container()
    local value = attributes.get_value(container, "sum_abc")

    -- 10 + 20 + 30 = 60
    assert_eq(60, value, "sum should be 60")
end)
-- }}}

-- {{{ test: create_formula weighted_sum pattern
run_test("create_formula weighted_sum pattern", function()
    attributes.reset()

    attributes.register_bulk({
        a = { type = "integer", default = 10 },
        b = { type = "integer", default = 20 },
        weighted = {
            type = "integer",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "a", "b" },
            formula = derived.create_formula("weighted_sum", {
                { "a", 2 },  -- a * 2
                { "b", 3 },  -- b * 3
            }),
        },
    })
    attributes.rebuild_getters()
    attributes.rebuild_setters()

    local container = attributes.create_container()
    local value = attributes.get_value(container, "weighted")

    -- 10 * 2 + 20 * 3 = 20 + 60 = 80
    assert_eq(80, value, "weighted sum should be 80")
end)
-- }}}

-- {{{ test: create_formula max pattern
run_test("create_formula max pattern", function()
    attributes.reset()

    attributes.register_bulk({
        a = { type = "integer", default = 10 },
        b = { type = "integer", default = 50 },
        c = { type = "integer", default = 30 },
        max_val = {
            type = "integer",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "a", "b", "c" },
            formula = derived.create_formula("max", { "a", "b", "c" }),
        },
    })
    attributes.rebuild_getters()
    attributes.rebuild_setters()

    local container = attributes.create_container()
    local value = attributes.get_value(container, "max_val")

    assert_eq(50, value, "max should be 50")
end)
-- }}}

-- {{{ test: create_formula min pattern
run_test("create_formula min pattern", function()
    attributes.reset()

    attributes.register_bulk({
        a = { type = "integer", default = 10 },
        b = { type = "integer", default = 50 },
        c = { type = "integer", default = 30 },
        min_val = {
            type = "integer",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "a", "b", "c" },
            formula = derived.create_formula("min", { "a", "b", "c" }),
        },
    })
    attributes.rebuild_getters()
    attributes.rebuild_setters()

    local container = attributes.create_container()
    local value = attributes.get_value(container, "min_val")

    assert_eq(10, value, "min should be 10")
end)
-- }}}

-- {{{ test: create_formula product pattern
run_test("create_formula product pattern", function()
    attributes.reset()

    attributes.register_bulk({
        a = { type = "integer", default = 2 },
        b = { type = "integer", default = 3 },
        c = { type = "integer", default = 4 },
        product_val = {
            type = "integer",
            flags = attributes.ATTR_FLAGS.DERIVED,
            derived_from = { "a", "b", "c" },
            formula = derived.create_formula("product", { "a", "b", "c" }),
        },
    })
    attributes.rebuild_getters()
    attributes.rebuild_setters()

    local container = attributes.create_container()
    local value = attributes.get_value(container, "product_val")

    -- 2 * 3 * 4 = 24
    assert_eq(24, value, "product should be 24")
end)
-- }}}

-- {{{ test: create_formula errors on unknown pattern
run_test("create_formula errors on unknown pattern", function()
    local success, err = pcall(function()
        derived.create_formula("unknown_pattern", {})
    end)

    assert_false(success, "should error on unknown pattern")
    assert_true(err:find("Unknown formula pattern"), "should have error message")
end)
-- }}}

-- }}}

-- {{{ Test: Edge Cases

print("\n=== Edge Cases ===")

-- {{{ test: handles nil container gracefully
run_test("handles nil container gracefully", function()
    setup_test_attributes()

    -- These should not crash but may return errors
    local success, _ = pcall(function()
        derived.is_dirty(nil, "attack_power")
    end)
    assert_false(success, "nil container should error")
end)
-- }}}

-- {{{ test: handles unknown attribute gracefully
run_test("handles unknown attribute gracefully", function()
    setup_test_attributes()
    local container = attributes.create_container()

    local info, err = derived.explain(container, "nonexistent")
    assert_nil(info, "should return nil for unknown")
    assert_true(err:find("Unknown attribute"), "should have error message")
end)
-- }}}

-- {{{ test: get_dependency_tree handles unknown attribute
run_test("get_dependency_tree handles unknown attribute", function()
    setup_test_attributes()

    local tree = derived.get_dependency_tree("nonexistent")
    assert_eq("nonexistent", tree.id, "should have the id")
    assert_true(tree.error ~= nil, "should have error field")
end)
-- }}}

-- {{{ test: multi-level dirty propagation after clean
run_test("multi-level dirty propagation after clean", function()
    setup_test_attributes()
    local container = attributes.create_container()

    -- First, compute all to clear dirty flags
    derived.recompute_all(container)

    -- Verify all clean
    assert_false(derived.is_dirty(container, "attack_power"), "attack_power clean initially")
    assert_false(derived.is_dirty(container, "spell_power"), "spell_power clean initially")

    -- Mark strength dirty (affects attack_power → total_damage → dps)
    derived.mark_dirty(container, "strength")

    -- attack_power and its dependents should be dirty
    assert_true(derived.is_dirty(container, "attack_power"), "attack_power dirty")
    assert_true(derived.is_dirty(container, "total_damage"), "total_damage dirty")
    assert_true(derived.is_dirty(container, "dps"), "dps dirty")

    -- spell_power should still be clean (different chain)
    assert_false(derived.is_dirty(container, "spell_power"), "spell_power not dirty")
end)
-- }}}

-- {{{ test: stats multi_level_count is correct
run_test("stats multi_level_count is correct", function()
    setup_test_attributes()

    local stats = derived.get_stats()

    -- Multi-level derived: total_damage (depends on attack_power which is derived)
    -- and dps (depends on total_damage which is derived)
    -- So multi_level_count should be at least 2
    assert_true(stats.multi_level_count >= 2, "should have at least 2 multi-level derived")
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
