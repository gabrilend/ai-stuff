#!/usr/bin/env luajit
-- {{{ test_309c_parser.lua
-- Integration test runner for JASS parser (Issue 309c)
-- Runs all parser test suites from 305 and aggregates results.
-- Run from project root: luajit src/tests/test_309c_parser.lua

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

    local handle = io.popen(string.format('luajit "%s" 2>&1', full_path))
    if not handle then
        print("FAIL (could not run)")
        failed_suites = failed_suites + 1
        return 0, 0
    end

    local output = handle:read("*a")
    local success, exit_type, exit_code = handle:close()

    -- Extract test counts from output
    local passed, failed, total = output:match("Tests:%s*(%d+)%s+passed,%s*(%d+)%s+failed,%s*(%d+)%s+total")

    if not passed then
        passed, total = output:match("(%d+)/(%d+)%s+tests%s+passed")
        if passed then
            failed = total - passed
        end
    end

    if not passed then
        passed = 0
        failed = 0
        for line in output:gmatch("[^\n]+") do
            if line:match("%[PASS%]") then
                passed = passed + 1
            elseif line:match("%[FAIL%]") then
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
            print("FAIL (exit code " .. tostring(exit_code) .. ")")
        end
    end

    return passed, failed
end
-- }}}
-- }}}

-- {{{ Main
print("===========================================================")
print("  Issue 309c: JASS Parser Integration Tests")
print("===========================================================\n")

local total_passed = 0
local total_failed = 0

-- Run all parser test suites
local suites = {
    {"Infrastructure (305a)", "test_parser_infra.lua"},
    {"Declarations (305b)", "test_parser_decl.lua"},
    {"Expressions (305c)", "test_parser_expr.lua"},
    {"Statements (305d)", "test_parser_stmt.lua"},
    {"Comprehensive (305e)", "test_parser.lua"},
}

for _, suite in ipairs(suites) do
    local passed, failed = run_test_suite(suite[1], suite[2])
    total_passed = total_passed + passed
    total_failed = total_failed + failed
end

-- Summary
print("\n" .. string.rep("-", 60))
print(string.format("Total: %d/%d tests passed across %d suites",
    total_passed, total_passed + total_failed, total_suites))
print(string.rep("-", 60))

if failed_suites > 0 then
    print("\nSOME PARSER TESTS FAILED!")
    os.exit(1)
else
    print("\nALL PARSER TESTS PASSED!")
    os.exit(0)
end
-- }}}
