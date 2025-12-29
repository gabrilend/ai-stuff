#!/usr/bin/env luajit
-- {{{ test_309d_transpiler.lua
-- Integration test runner for JASS transpiler (Issue 309d)
-- Runs the meta-test runner from 306f which aggregates all transpiler tests.
-- Run from project root: luajit src/tests/test_309d_transpiler.lua

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

-- {{{ Main
print("===========================================================")
print("  Issue 309d: JASS Transpiler Integration Tests")
print("===========================================================\n")

-- Run the existing meta-test runner from 306f
local test_path = DIR .. "/src/tests/test_transpiler.lua"
local handle = io.popen(string.format('luajit "%s" 2>&1', test_path))
if not handle then
    print("ERROR: Could not run transpiler tests")
    os.exit(1)
end

local output = handle:read("*a")
local success = handle:close()

-- Forward output
print(output)

-- Exit with same code
if success then
    os.exit(0)
else
    os.exit(1)
end
-- }}}
