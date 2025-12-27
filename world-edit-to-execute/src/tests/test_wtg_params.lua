-- war3map.wtg Parameter Parser Test (Issue 301e)
-- Tests parameter parsing, formatting, and validation for WTG trigger parameters.
-- Run from project root: luajit src/tests/test_wtg_params.lua

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

-- {{{ Synthetic parameter data generators
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
local function make_simple_param(type_id, value)
    local parts = {}
    parts[#parts + 1] = pack_int32(type_id)       -- type
    parts[#parts + 1] = value .. "\0"             -- value
    parts[#parts + 1] = pack_uint32(0)            -- has_sub = false
    parts[#parts + 1] = pack_uint32(0)            -- is_array = false
    return table.concat(parts)
end

-- Create a parameter with sub-parameters (for function calls)
local function make_function_param(value, func_type, func_name, sub_params)
    local parts = {}
    parts[#parts + 1] = pack_int32(2)             -- type = function
    parts[#parts + 1] = value .. "\0"             -- value
    parts[#parts + 1] = pack_uint32(1)            -- has_sub = true
    -- Sub-parameter header
    parts[#parts + 1] = pack_int32(func_type)     -- function type
    parts[#parts + 1] = func_name .. "\0"         -- function name
    parts[#parts + 1] = pack_uint32(1)            -- begin flag
    parts[#parts + 1] = pack_uint32(#sub_params)  -- sub_count
    for _, sub in ipairs(sub_params) do
        parts[#parts + 1] = sub
    end
    parts[#parts + 1] = pack_uint32(0)            -- is_array = false
    return table.concat(parts)
end

-- Create an array variable parameter with index
local function make_array_param(value, index_param)
    local parts = {}
    parts[#parts + 1] = pack_int32(1)             -- type = variable
    parts[#parts + 1] = value .. "\0"             -- variable name
    parts[#parts + 1] = pack_uint32(0)            -- has_sub = false
    parts[#parts + 1] = pack_uint32(1)            -- is_array = true
    parts[#parts + 1] = index_param               -- index parameter
    return table.concat(parts)
end
-- }}}

-- {{{ Main test suite
local function run_tests()
    print_separator("WTG Parameter Parser Tests (301e)")

    -- Test 1: PARAM_TYPE constants exported
    test("PARAM_TYPE constants exported", function()
        assert_not_nil(wtg.PARAM_TYPE, "PARAM_TYPE should be exported")
        assert_eq(wtg.PARAM_TYPE.INVALID, -1, "INVALID = -1")
        assert_eq(wtg.PARAM_TYPE.PRESET, 0, "PRESET = 0")
        assert_eq(wtg.PARAM_TYPE.VARIABLE, 1, "VARIABLE = 1")
        assert_eq(wtg.PARAM_TYPE.FUNCTION, 2, "FUNCTION = 2")
        assert_eq(wtg.PARAM_TYPE.STRING, 3, "STRING = 3")
    end)

    -- Test 2: PARAM_TYPE_NAMES exported
    test("PARAM_TYPE_NAMES exported", function()
        assert_not_nil(wtg.PARAM_TYPE_NAMES, "PARAM_TYPE_NAMES should be exported")
        assert_eq(wtg.PARAM_TYPE_NAMES[-1], "invalid", "-1 = invalid")
        assert_eq(wtg.PARAM_TYPE_NAMES[0], "preset", "0 = preset")
        assert_eq(wtg.PARAM_TYPE_NAMES[1], "variable", "1 = variable")
        assert_eq(wtg.PARAM_TYPE_NAMES[2], "function", "2 = function")
        assert_eq(wtg.PARAM_TYPE_NAMES[3], "string", "3 = string")
    end)

    -- Test 3: Parse preset parameter
    test("Parse preset parameter (type 0)", function()
        local data = make_simple_param(0, "OperatorAdd")
        local param, offset, err = wtg._parse_parameter(data, 1, 0)

        assert_not_nil(param, "parse returned nil: " .. tostring(err))
        assert_eq(param.type, 0, "type")
        assert_eq(param.type_name, "preset", "type_name")
        assert_eq(param.value, "OperatorAdd", "value")
        assert_false(param.has_sub, "has_sub")
        assert_false(param.is_array, "is_array")
    end)

    -- Test 4: Parse variable parameter
    test("Parse variable parameter (type 1)", function()
        local data = make_simple_param(1, "udg_Counter")
        local param, offset, err = wtg._parse_parameter(data, 1, 0)

        assert_not_nil(param, "parse returned nil: " .. tostring(err))
        assert_eq(param.type, 1, "type")
        assert_eq(param.type_name, "variable", "type_name")
        assert_eq(param.value, "udg_Counter", "value")
    end)

    -- Test 5: Parse string parameter
    test("Parse string parameter (type 3)", function()
        local data = make_simple_param(3, "Hello World")
        local param, offset, err = wtg._parse_parameter(data, 1, 0)

        assert_not_nil(param, "parse returned nil: " .. tostring(err))
        assert_eq(param.type, 3, "type")
        assert_eq(param.type_name, "string", "type_name")
        assert_eq(param.value, "Hello World", "value")
    end)

    -- Test 6: Parse invalid parameter (type -1)
    test("Parse invalid parameter (type -1)", function()
        local data = make_simple_param(-1, "disabled")
        local param, offset, err = wtg._parse_parameter(data, 1, 0)

        assert_not_nil(param, "parse returned nil: " .. tostring(err))
        assert_eq(param.type, -1, "type")
        assert_eq(param.type_name, "invalid", "type_name")
    end)

    -- Test 7: Parse function parameter with sub-parameters
    test("Parse function parameter with sub-parameters", function()
        local sub1 = make_simple_param(1, "udg_Counter")
        local sub2 = make_simple_param(0, "OperatorAdd")
        local sub3 = make_simple_param(3, "1")
        local data = make_function_param("OperatorInt", 0, "OperatorInt", {sub1, sub2, sub3})

        local param, offset, err = wtg._parse_parameter(data, 1, 0)

        assert_not_nil(param, "parse returned nil: " .. tostring(err))
        assert_eq(param.type, 2, "type")
        assert_eq(param.type_name, "function", "type_name")
        assert_eq(param.value, "OperatorInt", "value")
        assert_true(param.has_sub, "has_sub")
        assert_not_nil(param.sub_function, "sub_function")
        assert_eq(param.sub_function.name, "OperatorInt", "sub_function name")
        assert_eq(#param.sub_function.parameters, 3, "sub_function param count")

        -- Check sub-parameters
        assert_eq(param.sub_function.parameters[1].type, 1, "sub1 type")
        assert_eq(param.sub_function.parameters[1].value, "udg_Counter", "sub1 value")
        assert_eq(param.sub_function.parameters[2].type, 0, "sub2 type")
        assert_eq(param.sub_function.parameters[3].type, 3, "sub3 type")
    end)

    -- Test 8: Parse array variable parameter
    test("Parse array variable parameter", function()
        local index = make_simple_param(3, "5")
        local data = make_array_param("udg_Units", index)

        local param, offset, err = wtg._parse_parameter(data, 1, 0)

        assert_not_nil(param, "parse returned nil: " .. tostring(err))
        assert_eq(param.type, 1, "type")
        assert_eq(param.type_name, "variable", "type_name")
        assert_eq(param.value, "udg_Units", "value")
        assert_true(param.is_array, "is_array")
        assert_not_nil(param.array_index, "array_index")
        assert_eq(param.array_index.type, 3, "index type")
        assert_eq(param.array_index.value, "5", "index value")
    end)

    -- Test 9: format_parameter for simple parameter
    test("format_parameter for simple parameter", function()
        local data = make_simple_param(1, "udg_TestVar")
        local param = wtg._parse_parameter(data, 1, 0)

        local formatted = wtg.format_parameter(param)
        assert_not_nil(formatted, "format_parameter returned nil")
        assert(formatted:find("variable"), "should contain type name")
        assert(formatted:find("udg_TestVar"), "should contain value")

        print("")
        print("  --- Formatted Parameter ---")
        print("  " .. formatted)
    end)

    -- Test 10: format_parameter for function parameter
    test("format_parameter for function parameter", function()
        local sub1 = make_simple_param(1, "udg_X")
        local sub2 = make_simple_param(3, "100")
        local data = make_function_param("GetUnitX", 0, "GetUnitX", {sub1, sub2})
        local param = wtg._parse_parameter(data, 1, 0)

        local formatted = wtg.format_parameter(param)
        assert_not_nil(formatted, "format_parameter returned nil")
        assert(formatted:find("function"), "should contain type name")
        assert(formatted:find("GetUnitX"), "should contain function name")
        assert(formatted:find("udg_X"), "should contain sub-parameter")

        print("")
        print("  --- Formatted Function Parameter ---")
        for line in formatted:gmatch("[^\n]+") do
            print("  " .. line)
        end
    end)

    -- Test 11: format_parameter for array parameter
    test("format_parameter for array parameter", function()
        local index = make_simple_param(3, "10")
        local data = make_array_param("udg_Units", index)
        local param = wtg._parse_parameter(data, 1, 0)

        local formatted = wtg.format_parameter(param)
        assert_not_nil(formatted, "format_parameter returned nil")
        assert(formatted:find("variable"), "should contain type name")
        assert(formatted:find("udg_Units"), "should contain variable name")
        assert(formatted:find("%[index%]"), "should show array index")
        assert(formatted:find("10"), "should contain index value")

        print("")
        print("  --- Formatted Array Parameter ---")
        for line in formatted:gmatch("[^\n]+") do
            print("  " .. line)
        end
    end)

    -- Test 12: validate_parameter for valid parameter
    test("validate_parameter for valid parameter", function()
        local data = make_simple_param(1, "udg_Hero")
        local param = wtg._parse_parameter(data, 1, 0)

        local valid, issues = wtg.validate_parameter(param)
        assert_true(valid, "should be valid")
        assert_eq(#issues, 0, "should have no issues")
    end)

    -- Test 13: validate_parameter for empty variable name
    test("validate_parameter for empty variable name", function()
        local data = make_simple_param(1, "")  -- empty variable name
        local param = wtg._parse_parameter(data, 1, 0)

        local valid, issues = wtg.validate_parameter(param)
        assert_false(valid, "should be de-selected")
        assert(#issues > 0, "should have issues")
        assert(issues[1]:find("empty name"), "should mention empty name")
    end)

    -- Test 14: validate_parameter recursive validation
    test("validate_parameter recursive validation", function()
        -- Create function with an empty variable sub-parameter
        local empty_var = make_simple_param(1, "")  -- empty variable
        local data = make_function_param("Test", 0, "Test", {empty_var})
        local param = wtg._parse_parameter(data, 1, 0)

        local valid, issues = wtg.validate_parameter(param)
        assert_false(valid, "should be de-selected")
        assert(#issues > 0, "should have issues")
        assert(issues[1]:find("sub"), "should mention sub-parameter")
    end)

    -- Test 15: Internal _parse_parameter exposed
    test("Internal _parse_parameter exposed", function()
        assert_not_nil(wtg._parse_parameter, "_parse_parameter should be exposed")
        assert_not_nil(wtg._parse_parameter_placeholder, "_parse_parameter_placeholder should be exposed (alias)")
    end)

    -- Test 16: Offset advances correctly after parsing
    test("Offset advances correctly after parsing", function()
        local data = make_simple_param(3, "test")
        local param, offset = wtg._parse_parameter(data, 1, 0)

        assert_not_nil(param, "parse should succeed")
        assert_eq(offset, #data + 1, "offset should advance to end of data")
    end)

    -- Test 17: Nested function parameters
    test("Nested function parameters", function()
        -- Create: OperatorInt(OperatorInt(a, b), c)
        local inner_sub1 = make_simple_param(1, "a")
        local inner_sub2 = make_simple_param(1, "b")
        local inner = make_function_param("OperatorInt", 0, "OperatorInt", {inner_sub1, inner_sub2})
        local outer_sub2 = make_simple_param(1, "c")
        local data = make_function_param("OperatorInt", 0, "OperatorInt", {inner, outer_sub2})

        local param, offset, err = wtg._parse_parameter(data, 1, 0)

        assert_not_nil(param, "parse returned nil: " .. tostring(err))
        assert_eq(param.type, 2, "outer type")
        assert_eq(#param.sub_function.parameters, 2, "outer sub count")

        local inner_param = param.sub_function.parameters[1]
        assert_eq(inner_param.type, 2, "inner type")
        assert_eq(#inner_param.sub_function.parameters, 2, "inner sub count")
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
