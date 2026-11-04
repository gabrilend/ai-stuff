#!/usr/bin/env luajit

-- Tests for libs/output.lua (Issue 10-075): a line said to "both" reaches
-- the terminal and the log, "terminal" only the terminal, "log" only the
-- log; an unknown place is an error; a log that cannot be written is an
-- error; a program that stops with an error leaves the error in the log.
-- Each case runs in its own luajit, as a program would.
--
-- Run directly:  luajit libs/output.test.lua [--dir PATH]

-- {{{ local function setup()
-- The project folder from --dir PATH, or nil when it was not given (the
-- default below is then used); a stray word on the command line stops the
-- program, named (libs/project-dir.lua, Issue 10-076).
local PROJECT_DIR_ARG = (function()
    local own = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
    local dir = dofile(own .. "../libs/project-dir.lua").read(arg, "")
    if dir == "" then return nil end
    return dir
end)()

local function setup()
    local this = debug.getinfo(1, "S").source:sub(2)
    local libs_dir = this:match("(.*/)") or "./"
    return (PROJECT_DIR_ARG or libs_dir:gsub("libs/$", "")):gsub("/$", "")
end
-- }}}

local DIR = setup()
local SCRATCH = DIR .. "/tmp/shared-memory/output-test"
os.execute(string.format("rm -rf %q && mkdir -p %q", SCRATCH, SCRATCH))

local passed, failed = 0, 0
-- {{{ local function check()
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

-- {{{ local function run()
-- Runs a few lines of Lua as their own program with the run's log set;
-- returns what it printed, its exit status, and the log.
local function run(code, log)
    local script = SCRATCH .. "/case.lua"
    local f = assert(io.open(script, "w"))
    f:write(string.format("package.path = %q .. '/libs/?.lua;' .. package.path\n", DIR), code)
    f:close()
    local p = assert(io.popen(string.format("NEOCITIES_RUN_LOG=%q luajit %q 2>&1; echo \"exit=$?\"", log, script)))
    local out = p:read("*a")
    p:close()
    local lf = io.open(log)
    local logged = lf and lf:read("*a") or ""
    if lf then lf:close() end
    return out, tonumber(out:match("exit=(%d+)")), logged
end
-- }}}

do
    local log = SCRATCH .. "/one.log"
    local out, status, logged = run([[
local o = require("output")
o.say("to both", "both")
o.say("to the terminal", "terminal")
o.say("to the log", "log")
]], log)
    check("the program exits 0", status == 0, out)
    check("'both' reaches the terminal and the log", out:find("to both", 1, true) and logged:find("to both", 1, true))
    check("'terminal' reaches only the terminal", out:find("to the terminal", 1, true) and not logged:find("to the terminal", 1, true))
    check("'log' reaches only the log", logged:find("to the log", 1, true) and not out:find("to the log", 1, true))
    check("every log line is stamped with the time", logged:match("^%d%d:%d%d:%d%d to both\n") ~= nil, logged)
end

do
    local out, status = run([[require("output").say("x", "somewhere")]], SCRATCH .. "/two.log")
    check("an unknown place is an error", status ~= 0 and out:find("where must be", 1, true), out)
end

do
    local out, status = run([[require("output").say("x", "log")]], SCRATCH .. "/no-such-folder/three.log")
    check("a log that cannot be written is an error", status ~= 0 and out:find("cannot open the run's log", 1, true), out)
end

do
    local log = SCRATCH .. "/four.log"
    local out, status, logged = run([[
require("output").guard("demo", function() error("the poems are missing") end)
]], log)
    check("a stopping error still stops the program", status ~= 0, out)
    check("the error and its traceback are in the log",
        logged:find("== demo failed", 1, true) and logged:find("the poems are missing", 1, true)
        and logged:find("traceback", 1, true), logged)
    check("the start is logged", logged:find("== demo start", 1, true) ~= nil)
end

do
    local log = SCRATCH .. "/five.log"
    local _, status, logged = run([[
local utils = require("utils")
utils.log_info("an info line")
utils.log_warn("a warning")
]], log)
    check("the message helpers write to the log", status == 0
        and logged:find("[INFO] an info line", 1, true) and logged:find("[WARN] a warning", 1, true), logged)
end

os.execute(string.format("rm -rf %q", SCRATCH))
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
