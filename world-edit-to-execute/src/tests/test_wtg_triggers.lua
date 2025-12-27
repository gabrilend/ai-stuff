-- war3map.wtg Trigger Metadata Parser Test (Issue 301c)
-- Tests the wtg parser trigger metadata parsing with synthetic data.
-- Run from project root: luajit src/tests/test_wtg_triggers.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local wtg = require("parsers.wtg")

-- {{{ Test utilities
local tests_run = 0
local tests_passed = 0

local function print_separator(title)
    print("\n" .. string.rep("=", 60))
    print(title)
    print(string.rep("=", 60))
end

local function test(name, fn)
    io.write("Testing " .. name .. "... ")
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("PASS")
        return true
    else
        print("FAIL: " .. tostring(err))
        return false
    end
end

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            message or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end

local function assert_not_nil(value, message)
    if value == nil then
        error(message or "Expected non-nil value")
    end
end

local function assert_true(value, message)
    if value ~= true then
        error(message or "Expected true")
    end
end

local function assert_false(value, message)
    if value ~= false then
        error(message or "Expected false")
    end
end
-- }}}

-- {{{ Synthetic WTG data generators
-- Pack a 32-bit unsigned integer as little-endian bytes
local function pack_uint32(n)
    local b1 = n % 256
    local b2 = math.floor(n / 256) % 256
    local b3 = math.floor(n / 65536) % 256
    local b4 = math.floor(n / 16777216) % 256
    return string.char(b1, b2, b3, b4)
end

-- Pack a 32-bit signed integer as little-endian bytes
local function pack_int32(n)
    if n < 0 then
        n = n + 4294967296  -- Convert to unsigned representation
    end
    return pack_uint32(n)
end

-- Create a simple parameter (no sub-params, no array)
local function make_simple_param(value)
    local parts = {}
    parts[#parts + 1] = pack_int32(3)             -- type = string
    parts[#parts + 1] = value .. "\0"             -- value
    parts[#parts + 1] = pack_uint32(0)            -- has_sub = false
    parts[#parts + 1] = pack_uint32(0)            -- is_array = false
    return table.concat(parts)
end

-- Create a simple ECA (event, condition, or action) with no params and no children
local function make_simple_eca(eca_type, func_name)
    local parts = {}
    parts[#parts + 1] = pack_uint32(eca_type)     -- type (0=event, 1=condition, 2=action)
    parts[#parts + 1] = func_name .. "\0"         -- function name
    parts[#parts + 1] = pack_uint32(1)            -- is_enabled = true
    parts[#parts + 1] = pack_uint32(0)            -- param_count = 0
    parts[#parts + 1] = pack_uint32(0)            -- nested_count = 0
    return table.concat(parts)
end

-- Create an ECA with one simple parameter
local function make_eca_with_param(eca_type, func_name, param_value)
    local parts = {}
    parts[#parts + 1] = pack_uint32(eca_type)     -- type
    parts[#parts + 1] = func_name .. "\0"         -- function name
    parts[#parts + 1] = pack_uint32(1)            -- is_enabled = true
    parts[#parts + 1] = pack_uint32(1)            -- param_count = 1
    parts[#parts + 1] = make_simple_param(param_value)
    parts[#parts + 1] = pack_uint32(0)            -- nested_count = 0
    return table.concat(parts)
end

-- Create a trigger with metadata and ECAs
local function make_trigger(name, desc, flags, category, ecas)
    local parts = {}
    parts[#parts + 1] = name .. "\0"              -- name
    parts[#parts + 1] = desc .. "\0"              -- description
    parts[#parts + 1] = pack_uint32(flags.is_comment and 1 or 0)
    parts[#parts + 1] = pack_uint32(flags.is_enabled and 1 or 0)
    parts[#parts + 1] = pack_uint32(flags.is_custom_text and 1 or 0)
    parts[#parts + 1] = pack_uint32(flags.is_initially_on and 1 or 0)
    parts[#parts + 1] = pack_uint32(flags.run_on_init and 1 or 0)
    parts[#parts + 1] = pack_uint32(category)     -- category_index
    parts[#parts + 1] = pack_uint32(#ecas)        -- eca_count
    for _, eca in ipairs(ecas) do
        parts[#parts + 1] = eca
    end
    return table.concat(parts)
end

-- Create WTG with no triggers
local function make_wtg_no_triggers()
    local parts = {}
    -- Header
    parts[#parts + 1] = "WTG!"
    parts[#parts + 1] = pack_uint32(7)            -- version
    -- Categories
    parts[#parts + 1] = pack_uint32(1)            -- category count
    parts[#parts + 1] = pack_uint32(0)            -- index
    parts[#parts + 1] = "Default\0"               -- name
    parts[#parts + 1] = pack_uint32(0)            -- type
    -- Variables
    parts[#parts + 1] = pack_uint32(0)            -- variable count
    -- Triggers
    parts[#parts + 1] = pack_uint32(0)            -- trigger count
    return table.concat(parts)
end

-- Create WTG with one simple trigger (no ECAs)
local function make_wtg_simple_trigger()
    local parts = {}
    -- Header
    parts[#parts + 1] = "WTG!"
    parts[#parts + 1] = pack_uint32(7)
    -- Categories
    parts[#parts + 1] = pack_uint32(1)
    parts[#parts + 1] = pack_uint32(0)
    parts[#parts + 1] = "Initialization\0"
    parts[#parts + 1] = pack_uint32(0)
    -- Variables
    parts[#parts + 1] = pack_uint32(0)
    -- Triggers
    parts[#parts + 1] = pack_uint32(1)
    parts[#parts + 1] = make_trigger(
        "Test Trigger",
        "A simple test trigger",
        { is_comment = false, is_enabled = true, is_custom_text = false,
          is_initially_on = true, run_on_init = true },
        0, -- category
        {} -- no ECAs
    )
    return table.concat(parts)
end

-- Create WTG with trigger that has ECAs
local function make_wtg_trigger_with_ecas()
    local parts = {}
    -- Header
    parts[#parts + 1] = "WTG!"
    parts[#parts + 1] = pack_uint32(7)
    -- Categories
    parts[#parts + 1] = pack_uint32(1)
    parts[#parts + 1] = pack_uint32(0)
    parts[#parts + 1] = "Combat\0"
    parts[#parts + 1] = pack_uint32(0)
    -- Variables
    parts[#parts + 1] = pack_uint32(0)
    -- Triggers
    parts[#parts + 1] = pack_uint32(1)

    local ecas = {
        make_simple_eca(0, "TriggerRegisterTimerEvent"),           -- event
        make_simple_eca(1, "IsUnitAlive"),                         -- condition
        make_eca_with_param(2, "DisplayTextToPlayer", "Hello"),    -- action with param
    }

    parts[#parts + 1] = make_trigger(
        "Combat Trigger",
        "Handles combat events",
        { is_comment = false, is_enabled = true, is_custom_text = false,
          is_initially_on = true, run_on_init = false },
        0, -- category
        ecas
    )
    return table.concat(parts)
end

-- Create WTG with multiple triggers with different flags
local function make_wtg_multiple_triggers()
    local parts = {}
    -- Header
    parts[#parts + 1] = "WTG!"
    parts[#parts + 1] = pack_uint32(7)
    -- Categories
    parts[#parts + 1] = pack_uint32(2)
    parts[#parts + 1] = pack_uint32(0)
    parts[#parts + 1] = "Initialization\0"
    parts[#parts + 1] = pack_uint32(0)
    parts[#parts + 1] = pack_uint32(1)
    parts[#parts + 1] = "// Disabled\0"
    parts[#parts + 1] = pack_uint32(1)            -- comment category
    -- Variables
    parts[#parts + 1] = pack_uint32(0)
    -- Triggers
    parts[#parts + 1] = pack_uint32(3)

    -- Trigger 1: Normal init trigger
    parts[#parts + 1] = make_trigger(
        "Melee Initialization",
        "",
        { is_comment = false, is_enabled = true, is_custom_text = false,
          is_initially_on = true, run_on_init = true },
        0, -- category
        { make_simple_eca(2, "MeleeStartingVisibility") }
    )

    -- Trigger 2: Disabled trigger
    parts[#parts + 1] = make_trigger(
        "Debug Trigger",
        "For debugging only",
        { is_comment = false, is_enabled = false, is_custom_text = false,
          is_initially_on = false, run_on_init = false },
        1, -- category (disabled)
        {}
    )

    -- Trigger 3: Custom text trigger
    parts[#parts + 1] = make_trigger(
        "Custom JASS",
        "Uses custom JASS code",
        { is_comment = false, is_enabled = true, is_custom_text = true,
          is_initially_on = true, run_on_init = false },
        0, -- category
        {}
    )

    return table.concat(parts)
end
-- }}}

-- {{{ Main test suite
local function run_tests()
    print_separator("WTG Trigger Metadata Parser Tests (301c)")

    -- Test 1: Parse WTG with 0 triggers
    test("Parse WTG with 0 triggers", function()
        local data = make_wtg_no_triggers()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_not_nil(result.triggers, "triggers array missing")
        assert_eq(#result.triggers, 0, "trigger count")
        -- _trigger_eca_offsets is cleaned up after ECA pass (301d)
        -- For metadata-only parsing, use parse_eca=false
    end)

    -- Test 2: Parse simple trigger (no ECAs)
    test("Parse simple trigger with no ECAs", function()
        local data = make_wtg_simple_trigger()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_eq(#result.triggers, 1, "trigger count")

        local trig = result.triggers[1]
        assert_eq(trig.name, "Test Trigger", "name")
        assert_eq(trig.description, "A simple test trigger", "description")
        assert_false(trig.is_comment, "is_comment")
        assert_true(trig.is_enabled, "is_enabled")
        assert_false(trig.is_custom_text, "is_custom_text")
        assert_true(trig.is_initially_on, "is_initially_on")
        assert_true(trig.run_on_init, "run_on_init")
        assert_eq(trig.category_index, 0, "category_index")
        assert_eq(trig.eca_count, 0, "eca_count")
    end)

    -- Test 3: Parse trigger with ECAs (now parsed by 301d)
    test("Parse trigger with ECAs", function()
        local data = make_wtg_trigger_with_ecas()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_eq(#result.triggers, 1, "trigger count")

        local trig = result.triggers[1]
        assert_eq(trig.name, "Combat Trigger", "name")
        assert_eq(trig.eca_count, 3, "eca_count")

        -- ECA arrays are populated by 301d (enabled by default)
        assert_eq(#trig.events, 1, "events count")
        assert_eq(#trig.conditions, 1, "conditions count")
        assert_eq(#trig.actions, 1, "actions count")

        -- Verify ECA function names
        assert_eq(trig.events[1].name, "TriggerRegisterTimerEvent", "event name")
        assert_eq(trig.conditions[1].name, "IsUnitAlive", "condition name")
        assert_eq(trig.actions[1].name, "DisplayTextToPlayer", "action name")
    end)

    -- Test 4: Parse multiple triggers with different flags
    test("Parse multiple triggers with flags", function()
        local data = make_wtg_multiple_triggers()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_eq(#result.triggers, 3, "trigger count")

        -- Trigger 1: Normal init
        local t1 = result.triggers[1]
        assert_eq(t1.name, "Melee Initialization", "t1 name")
        assert_true(t1.is_enabled, "t1 is_enabled")
        assert_true(t1.run_on_init, "t1 run_on_init")

        -- Trigger 2: Disabled
        local t2 = result.triggers[2]
        assert_eq(t2.name, "Debug Trigger", "t2 name")
        assert_false(t2.is_enabled, "t2 is_enabled")
        assert_false(t2.is_initially_on, "t2 is_initially_on")
        assert_eq(t2.category_index, 1, "t2 category_index")

        -- Trigger 3: Custom text
        local t3 = result.triggers[3]
        assert_eq(t3.name, "Custom JASS", "t3 name")
        assert_true(t3.is_custom_text, "t3 is_custom_text")
    end)

    -- Test 5: Category validation
    test("Category validation", function()
        local data = make_wtg_multiple_triggers()
        local result = wtg.parse(data)
        assert_not_nil(result, "parse should succeed")

        local valid, errors = wtg.validate_categories(result)
        assert_true(valid, "all categories should be valid")
        assert_eq(#errors, 0, "no errors")
    end)

    -- Test 6: ECA offsets are recorded (when using metadata-only parsing)
    test("ECA offsets recorded for each trigger (parse_eca=false)", function()
        local data = make_wtg_multiple_triggers()
        -- Use parse_eca=false to test metadata-only parsing (301c behavior)
        local result = wtg.parse(data, { parse_eca = false })
        assert_not_nil(result, "parse should succeed")

        assert_eq(#result._trigger_eca_offsets, 3, "eca_offsets count = trigger count")

        -- Offsets should be ascending (each trigger's ECAs follow the previous)
        for i = 2, #result._trigger_eca_offsets do
            assert(result._trigger_eca_offsets[i] >= result._trigger_eca_offsets[i-1],
                "offsets should be non-decreasing")
        end
    end)

    -- Test 7: Format function includes triggers
    test("Format function shows triggers", function()
        local data = make_wtg_multiple_triggers()
        local result = wtg.parse(data)
        assert_not_nil(result, "parse should succeed")

        local formatted = wtg.format(result)
        assert_not_nil(formatted, "format should return string")
        assert(formatted:find("Trigger Count: 3"), "should show trigger count")
        assert(formatted:find("Melee Initialization"), "should show trigger name")
        assert(formatted:find("Debug Trigger"), "should show disabled trigger")
        assert(formatted:find("disabled"), "should show disabled flag")
        assert(formatted:find("custom"), "should show custom flag")

        print("")
        print("  --- Formatted Output (first 25 lines) ---")
        local line_count = 0
        for line in formatted:gmatch("[^\n]+") do
            print("  " .. line)
            line_count = line_count + 1
            if line_count >= 25 then
                print("  ...")
                break
            end
        end
    end)

    -- Test 8: Internal functions exposed
    test("Internal functions are exposed", function()
        assert_not_nil(wtg._parse_triggers, "_parse_triggers should be exposed")
        assert_not_nil(wtg._skip_parameter, "_skip_parameter should be exposed")
        assert_not_nil(wtg._skip_single_eca, "_skip_single_eca should be exposed")
        assert_not_nil(wtg._skip_eca_section, "_skip_eca_section should be exposed")
    end)

    -- Test 9: ECA type constants exposed
    test("ECA type constants exposed", function()
        assert_not_nil(wtg.ECA_TYPE, "ECA_TYPE should be exposed")
        assert_eq(wtg.ECA_TYPE.EVENT, 0, "EVENT = 0")
        assert_eq(wtg.ECA_TYPE.CONDITION, 1, "CONDITION = 1")
        assert_eq(wtg.ECA_TYPE.ACTION, 2, "ACTION = 2")

        assert_not_nil(wtg.ECA_TYPE_NAMES, "ECA_TYPE_NAMES should be exposed")
        assert_eq(wtg.ECA_TYPE_NAMES[0], "event", "0 = event")
        assert_eq(wtg.ECA_TYPE_NAMES[1], "condition", "1 = condition")
        assert_eq(wtg.ECA_TYPE_NAMES[2], "action", "2 = action")
    end)

    -- Summary
    print_separator("Results")
    print(string.format("Passed: %d / %d", tests_passed, tests_run))
    if tests_passed < tests_run then
        print("SOME TESTS FAILED")
        return false
    else
        print("ALL TESTS PASSED")
        return true
    end
end
-- }}}

-- Run tests
local ok = run_tests()
os.exit(ok and 0 or 1)
