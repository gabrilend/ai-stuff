#!/usr/bin/env lua
--[[
Trigger Framework Test Runner

Meta-test script that runs all trigger test suites in succession.
This aggregates results from:
- test_triggers_307a.lua (data structure)
- test_triggers_307b.lua (lifecycle API)
- test_triggers_307c.lua (condition/action system)
- test_triggers_307d.lua (context system)

Run from project root: lua src/tests/test_triggers.lua
]]

-- {{{ Configuration
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local TEST_DIR = DIR .. "/src/tests"
-- }}}

-- {{{ Test suites to run
-- Order matches dependency chain: data structure -> lifecycle -> condition/action -> context
local TEST_SUITES = {
    {file = "test_triggers_307a.lua", name = "Data Structure (307a)", expected = 34},
    {file = "test_triggers_307b.lua", name = "Lifecycle API (307b)", expected = 37},
    {file = "test_triggers_307c.lua", name = "Condition/Action (307c)", expected = 47},
    {file = "test_triggers_307d.lua", name = "Context System (307d)", expected = 36},
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
        if output:find("ALL 307") and output:find("PASSED") then
            return suite.expected, suite.expected, true, output
        else
            return 0, suite.expected, false, output
        end
    end
end
-- }}}

-- {{{ Main
print("=" .. string.rep("=", 58))
print("  Trigger Framework Test Suite (Issue 307)")
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
    print("ALL TRIGGER FRAMEWORK TESTS PASSED!")
    os.exit(0)
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
