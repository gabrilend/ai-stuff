#!/usr/bin/env lua
--[[
JASS-to-Lua Transpiler Test Runner

Meta-test script that runs all transpiler test suites in succession.
This aggregates results from:
- test_transpiler_infra.lua (306a - infrastructure)
- test_transpiler_decl.lua (306b - declarations)
- test_transpiler_expr.lua (306d - expressions)
- test_transpiler_stmt.lua (306c - statements)

Run from project root: lua src/tests/test_transpiler.lua
]]

-- {{{ Configuration
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local TEST_DIR = DIR .. "/src/tests"
-- }}}

-- {{{ Test suites to run
-- Order matches dependency chain: infrastructure -> declarations -> expressions -> statements
local TEST_SUITES = {
    {file = "test_transpiler_infra.lua", name = "Infrastructure (306a)", expected = 87},
    {file = "test_transpiler_decl.lua", name = "Declarations (306b)", expected = 43},
    {file = "test_transpiler_expr.lua", name = "Expressions (306d)", expected = 69},
    {file = "test_transpiler_stmt.lua", name = "Statements (306c)", expected = 27},
}
-- }}}

-- {{{ run_test_suite
-- Run a single test suite and capture results.
-- @param suite Table with file, name, expected fields
-- @return passed count, total count, success boolean
local function run_test_suite(suite)
    local cmd = string.format("cd %q && lua %s/%s 2>&1",
        DIR, TEST_DIR, suite.file)

    local handle = io.popen(cmd)
    if not handle then
        return 0, 0, false, "Failed to execute: " .. suite.file
    end

    local output = handle:read("*a")
    local success, exit_type, code = handle:close()

    -- Parse results from output
    -- Looking for pattern: "=== Results: X/Y tests passed ==="
    local passed, total = output:match("Results:%s*(%d+)/(%d+)%s*tests passed")

    if passed and total then
        passed = tonumber(passed)
        total = tonumber(total)
        local ok = (passed == total)
        return passed, total, ok, output
    else
        -- Fallback: check if output contains "All tests passed"
        if output:find("All tests passed") then
            return suite.expected, suite.expected, true, output
        else
            return 0, suite.expected, false, output
        end
    end
end
-- }}}

-- {{{ Main
print("=" .. string.rep("=", 58))
print("  JASS-to-Lua Transpiler Test Suite")
print("=" .. string.rep("=", 58))
print("")

local total_passed = 0
local total_tests = 0
local all_success = true
local failed_suites = {}

for i, suite in ipairs(TEST_SUITES) do
    io.write(string.format("[%d/%d] Running %s... ",
        i, #TEST_SUITES, suite.name))
    io.flush()

    local passed, total, success, output = run_test_suite(suite)

    total_passed = total_passed + passed
    total_tests = total_tests + total

    if success then
        print(string.format("PASS (%d/%d)", passed, total))
    else
        print(string.format("FAIL (%d/%d)", passed, total))
        all_success = false
        failed_suites[#failed_suites + 1] = {
            suite = suite,
            passed = passed,
            total = total,
            output = output,
        }
    end
end

print("")
print(string.rep("-", 60))
print(string.format("Total: %d/%d tests passed across %d suites",
    total_passed, total_tests, #TEST_SUITES))
print(string.rep("-", 60))

-- Show failed suite details
if #failed_suites > 0 then
    print("")
    print("FAILED SUITES:")
    for _, fail in ipairs(failed_suites) do
        print("")
        print("  " .. fail.suite.name .. " (" .. fail.suite.file .. "):")
        -- Show last 20 lines of output for debugging
        local lines = {}
        for line in fail.output:gmatch("[^\n]+") do
            lines[#lines + 1] = line
        end
        local start = math.max(1, #lines - 20)
        for j = start, #lines do
            print("    " .. lines[j])
        end
    end
end

print("")
if all_success then
    print("ALL TRANSPILER TESTS PASSED!")
    os.exit(0)
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
