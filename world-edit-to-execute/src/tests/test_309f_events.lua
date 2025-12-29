#!/usr/bin/env luajit
-- {{{ test_309f_events.lua
-- Integration test runner for event dispatch system (Issue 309f)
-- Runs all event test suites from 308 and aggregates results.
-- Run from project root: luajit src/tests/test_309f_events.lua

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

-- {{{ Test runner utilities
local total_suites = 0
local passed_suites = 0
local failed_suites = 0

-- {{{ run_test_suite
local function run_test_suite(name, path)
    total_suites = total_suites + 1

    io.write(string.format("[%d/%d] Running %s... ", total_suites, 5, name))
    io.flush()

    local full_path = DIR .. "/src/tests/" .. path

    -- Check if file exists
    local f = io.open(full_path, "r")
    if not f then
        print("SKIP (file not found)")
        return 0, 0
    end
    f:close()

    local handle = io.popen(string.format('luajit "%s" 2>&1', full_path))
    if not handle then
        print("FAIL (could not run)")
        failed_suites = failed_suites + 1
        return 0, 0
    end

    local output = handle:read("*a")
    local success = handle:close()

    -- Extract test counts
    local passed, failed, total = output:match("Tests:%s*(%d+)%s+passed,%s*(%d+)%s+failed,%s*(%d+)%s+total")

    if not passed then
        passed, total = output:match("(%d+)/(%d+)%s+tests%s+passed")
        if passed then failed = total - passed end
    end

    if not passed then
        passed = 0
        failed = 0
        for line in output:gmatch("[^\n]+") do
            if line:match("%[PASS%]") or line:match("PASS") then
                passed = passed + 1
            elseif line:match("%[FAIL%]") or line:match("FAIL") then
                failed = failed + 1
            end
        end
        total = passed + failed
    end

    passed = tonumber(passed) or 0
    failed = tonumber(failed) or 0
    total = tonumber(total) or (passed + failed)

    if failed == 0 and passed > 0 then
        passed_suites = passed_suites + 1
        print(string.format("PASS (%d/%d)", passed, total))
    elseif passed > 0 or failed > 0 then
        failed_suites = failed_suites + 1
        print(string.format("FAIL (%d/%d)", passed, total))
        for line in output:gmatch("[^\n]+") do
            if line:match("%[FAIL%]") then
                print("    " .. line)
            end
        end
    else
        if success then
            passed_suites = passed_suites + 1
            print("PASS (output format unknown)")
        else
            failed_suites = failed_suites + 1
            print("FAIL (exit code)")
        end
    end

    return passed, failed
end
-- }}}
-- }}}

-- {{{ Main
print("===========================================================")
print("  Issue 309f: Event Dispatch Integration Tests")
print("===========================================================\n")

local total_passed = 0
local total_failed = 0

-- Run all event dispatch test suites
local suites = {
    {"Event Registry Core (308a)", "test_events_308a.lua"},
    {"Timer Events (308b)", "test_events_308b.lua"},
    {"Region Events (308c)", "test_events_308c.lua"},
    {"Unit Events (308d)", "test_events_308d.lua"},
    {"Player Events (308e)", "test_events_308e.lua"},
}

for _, suite in ipairs(suites) do
    local passed, failed = run_test_suite(suite[1], suite[2])
    total_passed = total_passed + passed
    total_failed = total_failed + failed
end

-- Summary
print("\n" .. string.rep("-", 60))
print(string.format("Total: %d/%d tests passed across %d suites",
    total_passed, total_passed + total_failed, passed_suites))
print(string.rep("-", 60))

if failed_suites > 0 then
    print("\nSOME EVENT TESTS FAILED!")
    os.exit(1)
else
    print("\nALL EVENT TESTS PASSED!")
    os.exit(0)
end
-- }}}
