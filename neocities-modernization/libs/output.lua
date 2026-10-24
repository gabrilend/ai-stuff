-- output.lua: everything a program says goes through here, to the terminal,
-- the run's log, or both (Issue 10-075).
--
-- Owner, 2026-10-23, llm-transcripts: "not do it through bash" -- each line
-- is sent with where it belongs, instead of rerouting the terminal: messages,
-- warnings and errors to both; a progress bar's redraws to the terminal only
-- (the bars keep animating, and the log stays readable); a stage's start and
-- end to the log only (run.sh prints its own banners).
--
-- The log: one file per run in RAM, tmp/shared-memory/logs/, named by the
-- moment the run started (run-2026-10-23_14-05-09.log) and kept until a
-- reboot. run.sh names it and hands it to every stage in NEOCITIES_RUN_LOG,
-- so a whole run lands in one file; a program run on its own starts its own.
-- Every line in it is stamped with the time. A write to the log that fails
-- is an error: a log that silently stops is worse than none.
--
-- Safe in every Lua state (the page workers each open the file to append;
-- each line goes out in one write).

local M = {}

local WHERE = { terminal = true, log = true, both = true }

-- {{{ local function project_dir()
-- This file's project: the folder above libs/.
local function project_dir()
    local here = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
    return here .. ".."
end
-- }}}

local log_path = nil
local log_file = nil

-- {{{ function M.path
-- The run's log file: NEOCITIES_RUN_LOG when run.sh set it, else a new file
-- named by this moment (made once per program).
function M.path()
    if log_path then return log_path end
    log_path = os.getenv("NEOCITIES_RUN_LOG")
    if not log_path or log_path == "" then
        local dir = project_dir() .. "/tmp/shared-memory/logs"
        os.execute(string.format("mkdir -p %q", dir))
        log_path = string.format("%s/run-%s.log", dir, os.date("%Y-%m-%d_%H-%M-%S"))
    end
    return log_path
end
-- }}}

-- {{{ local function write_log()
local function write_log(text)
    if not log_file then
        local path = M.path()
        log_file = io.open(path, "a")
        if not log_file then error("output: cannot open the run's log " .. path) end
        log_file:setvbuf("line")
    end
    local stamp = os.date("%H:%M:%S")
    for line in (tostring(text) .. "\n"):gmatch("(.-)\n") do
        local ok, err = log_file:write(stamp, " ", line, "\n")
        if not ok then error("output: writing the run's log failed: " .. tostring(err)) end
    end
end
-- }}}

-- {{{ function M.say
-- text  : the line(s) to say (string)
-- where : "terminal", "log" or "both" (required: where a line belongs is a
--         decision, not a default)
function M.say(text, where)
    if not WHERE[where] then
        error("output.say: where must be terminal, log or both (got " .. tostring(where) .. ")")
    end
    if where ~= "log" then print(text) end
    if where ~= "terminal" then write_log(text) end
end
-- }}}

-- {{{ function M.stage
-- A stage's start or end, to the log only: run.sh prints its banners itself.
-- name: the program or stage (string); event: "start", "end" or a word.
function M.stage(name, event)
    write_log(string.format("== %s %s", name, event))
end
-- }}}

-- {{{ function M.guard
-- Runs main(); an error that stops it is written to the log with its
-- traceback before it is raised again, so a crash leaves its reason in the
-- log as well as on the terminal.
function M.guard(name, main, ...)
    M.stage(name, "start")
    local results = { xpcall(main, debug.traceback, ...) }
    if not results[1] then
        write_log(string.format("== %s failed:\n%s", name, tostring(results[2])))
        error(results[2], 0)
    end
    M.stage(name, "end")
    return unpack(results, 2)
end
-- }}}

return M
