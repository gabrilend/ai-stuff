-- war3map.wtg Variable Parser Test (Issue 301b)
-- Tests the wtg parser variable parsing with synthetic data.
-- Run from project root: luajit src/tests/test_wtg_variables.lua

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

local function assert_nil(value, message)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s",
            message or "Assertion failed", tostring(value)))
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

-- Create WTG with no categories, no variables, and no triggers
local function make_empty_wtg()
    local parts = {}
    parts[#parts + 1] = "WTG!"                    -- magic
    parts[#parts + 1] = pack_uint32(7)            -- version (TFT)
    parts[#parts + 1] = pack_uint32(0)            -- category count = 0
    parts[#parts + 1] = pack_uint32(0)            -- variable count = 0
    parts[#parts + 1] = pack_uint32(0)            -- trigger count = 0 (301c)
    return table.concat(parts)
end

-- Create a single variable entry
local function make_variable(name, var_type, is_array, array_size, is_initialized, initial_value)
    local parts = {}
    parts[#parts + 1] = name .. "\0"                          -- name
    parts[#parts + 1] = var_type .. "\0"                      -- type
    parts[#parts + 1] = pack_uint32(1)                        -- unknown field (always 1)
    parts[#parts + 1] = pack_uint32(is_array and 1 or 0)      -- is_array
    parts[#parts + 1] = pack_uint32(array_size or 0)          -- array_size
    parts[#parts + 1] = pack_uint32(is_initialized and 1 or 0) -- is_initialized
    if is_initialized then
        parts[#parts + 1] = (initial_value or "") .. "\0"     -- initial_value
    end
    return table.concat(parts)
end

-- Create WTG with various variable types
local function make_wtg_with_variables()
    local parts = {}
    -- Header
    parts[#parts + 1] = "WTG!"                    -- magic
    parts[#parts + 1] = pack_uint32(7)            -- version (TFT)
    -- Categories (1 category)
    parts[#parts + 1] = pack_uint32(1)            -- category count
    parts[#parts + 1] = pack_uint32(0)            -- index
    parts[#parts + 1] = "Initialization\0"        -- name
    parts[#parts + 1] = pack_uint32(0)            -- type (normal)
    -- Variables (4 variables)
    parts[#parts + 1] = pack_uint32(4)            -- variable count

    -- Variable 1: Simple integer, not initialized
    parts[#parts + 1] = make_variable("Counter", "integer", false, 0, false)

    -- Variable 2: Unit variable, not initialized
    parts[#parts + 1] = make_variable("Hero", "unit", false, 0, false)

    -- Variable 3: Integer array with size 10
    parts[#parts + 1] = make_variable("Scores", "integer", true, 10, false)

    -- Variable 4: Integer with initial value
    parts[#parts + 1] = make_variable("Difficulty", "integer", false, 0, true, "2")

    -- Triggers (301c)
    parts[#parts + 1] = pack_uint32(0)            -- trigger count = 0

    return table.concat(parts)
end

-- Create WTG with all common variable types
local function make_wtg_many_types()
    local parts = {}
    -- Header
    parts[#parts + 1] = "WTG!"
    parts[#parts + 1] = pack_uint32(7)
    -- No categories
    parts[#parts + 1] = pack_uint32(0)
    -- Many variable types
    local types = {"unit", "integer", "real", "string", "boolean", "location", "rect", "group", "timer"}
    parts[#parts + 1] = pack_uint32(#types)
    for i, t in ipairs(types) do
        parts[#parts + 1] = make_variable("Var" .. i, t, false, 0, false)
    end
    -- Triggers (301c)
    parts[#parts + 1] = pack_uint32(0)            -- trigger count = 0
    return table.concat(parts)
end

-- Create WTG with initialized variables of different types
local function make_wtg_with_init_values()
    local parts = {}
    -- Header
    parts[#parts + 1] = "WTG!"
    parts[#parts + 1] = pack_uint32(7)
    -- No categories
    parts[#parts + 1] = pack_uint32(0)
    -- Variables with initial values
    parts[#parts + 1] = pack_uint32(4)

    -- Integer initialized
    parts[#parts + 1] = make_variable("IntVar", "integer", false, 0, true, "42")

    -- Real initialized
    parts[#parts + 1] = make_variable("RealVar", "real", false, 0, true, "3.14")

    -- Boolean initialized
    parts[#parts + 1] = make_variable("BoolVar", "boolean", false, 0, true, "true")

    -- String initialized
    parts[#parts + 1] = make_variable("StrVar", "string", false, 0, true, "Hello World")

    -- Triggers (301c)
    parts[#parts + 1] = pack_uint32(0)            -- trigger count = 0

    return table.concat(parts)
end

-- Create WTG with array variables
local function make_wtg_with_arrays()
    local parts = {}
    -- Header
    parts[#parts + 1] = "WTG!"
    parts[#parts + 1] = pack_uint32(7)
    -- No categories
    parts[#parts + 1] = pack_uint32(0)
    -- Array variables
    parts[#parts + 1] = pack_uint32(3)

    -- Small array
    parts[#parts + 1] = make_variable("SmallArray", "integer", true, 5, false)

    -- Large array
    parts[#parts + 1] = make_variable("LargeArray", "unit", true, 100, false)

    -- Location array
    parts[#parts + 1] = make_variable("SpawnPoints", "location", true, 20, false)

    -- Triggers (301c)
    parts[#parts + 1] = pack_uint32(0)            -- trigger count = 0

    return table.concat(parts)
end
-- }}}

-- {{{ Main test suite
local function run_tests()
    print_separator("WTG Variable Parser Tests (301b)")

    -- Test 1: Empty variables section
    test("Parse WTG with 0 variables", function()
        local data = make_empty_wtg()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_not_nil(result.variables, "variables array missing")
        assert_eq(#result.variables, 0, "variable count")
    end)

    -- Test 2: Parse various variable types
    test("Parse WTG with 4 variables", function()
        local data = make_wtg_with_variables()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_eq(#result.variables, 4, "variable count")

        -- Check variable 1: Counter (integer, not array, not initialized)
        local v1 = result.variables[1]
        assert_eq(v1.name, "Counter", "v1 name")
        assert_eq(v1.type, "integer", "v1 type")
        assert_false(v1.is_array, "v1 is_array")
        assert_eq(v1.array_size, 0, "v1 array_size")
        assert_false(v1.is_initialized, "v1 is_initialized")
        assert_nil(v1.initial_value, "v1 initial_value")

        -- Check variable 2: Hero (unit, not array, not initialized)
        local v2 = result.variables[2]
        assert_eq(v2.name, "Hero", "v2 name")
        assert_eq(v2.type, "unit", "v2 type")
        assert_false(v2.is_array, "v2 is_array")

        -- Check variable 3: Scores (integer array size 10)
        local v3 = result.variables[3]
        assert_eq(v3.name, "Scores", "v3 name")
        assert_eq(v3.type, "integer", "v3 type")
        assert_true(v3.is_array, "v3 is_array")
        assert_eq(v3.array_size, 10, "v3 array_size")

        -- Check variable 4: Difficulty (integer initialized to "2")
        local v4 = result.variables[4]
        assert_eq(v4.name, "Difficulty", "v4 name")
        assert_eq(v4.type, "integer", "v4 type")
        assert_false(v4.is_array, "v4 is_array")
        assert_true(v4.is_initialized, "v4 is_initialized")
        assert_eq(v4.initial_value, "2", "v4 initial_value")
    end)

    -- Test 3: Many type strings
    test("Parse variables with various type strings", function()
        local data = make_wtg_many_types()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_eq(#result.variables, 9, "variable count")

        -- Verify all types were preserved
        local expected_types = {"unit", "integer", "real", "string", "boolean", "location", "rect", "group", "timer"}
        for i, expected in ipairs(expected_types) do
            assert_eq(result.variables[i].type, expected, "variable " .. i .. " type")
        end
    end)

    -- Test 4: Initialized variables with different value types
    test("Parse initialized variables", function()
        local data = make_wtg_with_init_values()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_eq(#result.variables, 4, "variable count")

        -- Check integer initial value
        assert_eq(result.variables[1].initial_value, "42", "int initial value")

        -- Check real initial value
        assert_eq(result.variables[2].initial_value, "3.14", "real initial value")

        -- Check boolean initial value
        assert_eq(result.variables[3].initial_value, "true", "bool initial value")

        -- Check string initial value
        assert_eq(result.variables[4].initial_value, "Hello World", "string initial value")
    end)

    -- Test 5: Array variables
    test("Parse array variables", function()
        local data = make_wtg_with_arrays()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_eq(#result.variables, 3, "variable count")

        -- Check small array
        assert_true(result.variables[1].is_array, "v1 is_array")
        assert_eq(result.variables[1].array_size, 5, "v1 array_size")

        -- Check large array
        assert_true(result.variables[2].is_array, "v2 is_array")
        assert_eq(result.variables[2].array_size, 100, "v2 array_size")

        -- Check location array
        assert_true(result.variables[3].is_array, "v3 is_array")
        assert_eq(result.variables[3].array_size, 20, "v3 array_size")
        assert_eq(result.variables[3].type, "location", "v3 type")
    end)

    -- Test 6: Offset advances correctly
    test("Offset advances past variables", function()
        local data = make_wtg_with_variables()
        local result = wtg.parse(data)
        assert_not_nil(result, "parse should succeed")

        -- Offset should be at end of data
        -- We can verify by checking it's greater than the variables section start
        assert(result._offset > 20, "_offset should advance significantly")
        print("")
        print("  Final offset: " .. result._offset)
        print("  Data length: " .. #data)
    end)

    -- Test 7: Format function includes variables
    test("Format function shows variables", function()
        local data = make_wtg_with_variables()
        local result = wtg.parse(data)
        assert_not_nil(result, "parse should succeed")

        local formatted = wtg.format(result)
        assert_not_nil(formatted, "format should return string")
        assert(formatted:find("Variable Count: 4"), "should show variable count")
        assert(formatted:find("Counter"), "should show Counter variable")
        assert(formatted:find("Hero"), "should show Hero variable")
        assert(formatted:find("Scores.*%[10%]"), "should show Scores array with size")
        assert(formatted:find("Difficulty.*="), "should show Difficulty with init value")

        print("")
        print("  --- Formatted Output ---")
        for line in formatted:gmatch("[^\n]+") do
            print("  " .. line)
        end
    end)

    -- Test 8: Internal function exposed
    test("_parse_variables is exposed", function()
        assert_not_nil(wtg._parse_variables, "_parse_variables should be exposed")
    end)

    -- Test 9: VARIABLE_TYPES constant exposed
    test("VARIABLE_TYPES constant exposed", function()
        assert_not_nil(wtg.VARIABLE_TYPES, "VARIABLE_TYPES should be exposed")
        assert(#wtg.VARIABLE_TYPES > 0, "VARIABLE_TYPES should not be empty")
        -- Check some expected types
        local found_unit = false
        local found_integer = false
        for _, t in ipairs(wtg.VARIABLE_TYPES) do
            if t == "unit" then found_unit = true end
            if t == "integer" then found_integer = true end
        end
        assert(found_unit, "VARIABLE_TYPES should include 'unit'")
        assert(found_integer, "VARIABLE_TYPES should include 'integer'")
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
