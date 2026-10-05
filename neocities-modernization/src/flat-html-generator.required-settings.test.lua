#!/usr/bin/env luajit
-- flat-html-generator.required-settings.test.lua (Issue 10-065a) -- proves the
-- page builder takes its page and storage settings only from config.lua. Its
-- code used to hold numbers of its own (100 poems per page, 500 per
-- chronological page, a 45 GB limit) that a missing setting silently fell back
-- to. Now a config.lua without one stops the builder as it loads, naming every
-- missing setting at once; and with the real config.lua it loads and uses
-- config.lua's values.
--
-- How: a scratch project in RAM whose libs/ and src/ link to the real ones and
-- whose config.lua is the real one with two settings removed. The builder is
-- loaded in a separate luajit with the scratch folder as its project folder.
--
-- Run: luajit src/flat-html-generator.required-settings.test.lua [project-dir]

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

local passed, failed = 0, 0
-- {{{ local function check
local function check(label, ok)
    if ok then
        passed = passed + 1
        print("  ok   - " .. label)
    else
        failed = failed + 1
        print("  FAIL - " .. label)
    end
end
-- }}}

-- {{{ local function run_capture
-- Runs a shell command, returns its combined output (string) and whether it
-- exited 0 (boolean).
local function run_capture(command)
    local pipe = assert(io.popen(command .. " 2>&1; echo \"EXIT:$?\""))
    local out = pipe:read("*a")
    pipe:close()
    local code = out:match("EXIT:(%d+)%s*$")
    return out, code == "0"
end
-- }}}

-- {{{ the scratch project
os.execute(string.format('"%s/scripts/ensure-tmp-symlink" "%s" >/dev/null', DIR, DIR))
local SCRATCH = DIR .. "/tmp/shared-memory/required-settings-test"
os.execute(string.format('rm -rf "%s" && mkdir -p "%s"', SCRATCH, SCRATCH))
for _, name in ipairs({ "libs", "src", "assets", "input", "page-templates" }) do
    os.execute(string.format('ln -s "%s/%s" "%s/%s"', DIR, name, SCRATCH, name))
end
-- config.lua minus two settings: remove the lines that set them
local real = assert(io.open(DIR .. "/config.lua")):read("*a")
local cut = real:gsub("\n%s*poems_per_page = 200,[^\n]*", "\n", 1)
                :gsub("\n%s*limit_gb = [%d%.]+,?[^\n]*", "\n", 1)
check("the scratch config really lacks the two settings",
    cut ~= real and not cut:find("limit_gb = ", 1, true))
local f = assert(io.open(SCRATCH .. "/config.lua", "w"))
f:write(cut)
f:close()
-- }}}

-- A driver file, not `luajit -e`: with -e, a trailing folder argument is taken
-- as a script to run and never reaches the builder, which reads its project
-- folder from the first command-line argument.
local DRIVER = SCRATCH .. "-driver.lua"
f = assert(io.open(DRIVER, "w"))
f:write([[
local dir = arg[1]
package.path = dir .. "/libs/?.lua;" .. dir .. "/src/?.lua;" .. package.path
local g = require("flat-html-generator")
print("PER_PAGE=" .. g.get_pagination_config().poems_per_page
    .. " LIMIT=" .. g.get_storage_config().limit_gb)
]])
f:close()
local function load_with(project)
    return run_capture(string.format('luajit "%s" "%s"', DRIVER, project))
end

-- {{{ a config.lua missing settings stops the builder, naming each
local out, ok = load_with(SCRATCH)
check("a config.lua missing settings stops the builder", not ok)
check("the error names pagination.poems_per_page", out:find("pagination.poems_per_page", 1, true) ~= nil)
check("the error names storage.limit_gb in the same message", out:find("storage.limit_gb", 1, true) ~= nil)
check("the error says where defaults live", out:find("only in config.lua", 1, true) ~= nil)
-- }}}

-- {{{ the real config.lua: loads, and the values are config.lua's
out, ok = load_with(DIR)
local config = dofile(DIR .. "/config.lua")
check("with the real config.lua the builder loads", ok)
check("poems per page is config.lua's value",
    out:find("PER_PAGE=" .. config.pagination.poems_per_page, 1, true) ~= nil)
check("the storage limit is config.lua's value",
    out:find("LIMIT=" .. config.storage.limit_gb, 1, true) ~= nil)
-- }}}

os.execute(string.format('rm -rf "%s" "%s"', SCRATCH, DRIVER))
print(string.format("passed %d, failed %d", passed, failed))
os.exit(failed == 0 and 0 or 1)
