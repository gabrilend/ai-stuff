-- 002-goodbye.test.lua - checks that a run leaves a receipt that reads back
-- the same, and that the receipt refuses what it should.
--
-- In plain terms: starts a pretend program in a throwaway project folder,
-- counts a few things, finishes, then reads output/goodbye back and compares.
-- tests/run-tests points the RAM scratch roots into this project's own
-- scratch space, so nothing is made in the real /tmp or /dev/shm roots.

local PROJECT_DIR = arg[1]
local SCRATCH_DIR = arg[2]
local goodbye = dofile(PROJECT_DIR .. "/src/002-goodbye.lua")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(description, condition, detail)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        io.write("FAILED: ", description, detail and ("\n    " .. detail) or "", "\n")
    end
end
-- }}}

-- a throwaway project with the one folder the receipt needs
local throwaway = SCRATCH_DIR .. "/receipt-project"
os.execute("mkdir -p '" .. throwaway .. "/output'")

local ok, receipt = pcall(goodbye.start, throwaway, "pretend", 42)
check("a run starts", ok, not ok and receipt or nil)
if ok then
    receipt:count("visits")
    receipt:count("visits")
    receipt:count("requests-carried-in", 3)
    receipt:set("answers-carried-out", 7)
    receipt:note("a line for the log")
    local text = receipt:finish()

    local back = goodbye.read(throwaway .. "/output/goodbye")
    check("program read back", back.program == "pretend")
    check("seed read back", back.seed == "42")
    check("ended is a UTC time", back.ended and string.match(back.ended, "^%d+%-%d+%-%d+T%d+:%d+:%d+Z$"),
        tostring(back.ended))
    check("counters read back", back.counters.visits == 2 and back.counters["requests-carried-in"] == 3
        and back.counters["answers-carried-out"] == 7)
    check("counters are sorted by name", string.find(text, "answers%-carried%-out.*requests%-carried%-in.*visits"))

    local named = io.open(throwaway .. "/output/goodbye.pretend", "r")
    check("the per-program receipt exists too", named ~= nil)
    if named then
        check("and holds the same text", named:read("*a") == text)
        named:close()
    end

    local leftover = io.open(throwaway .. "/output/goodbye.writing", "r")
    check("no temporary file is left behind", leftover == nil)
    if leftover then leftover:close() end

    local log = io.open(throwaway .. "/tmp/shared-memory/pretend.log", "r")
    check("the run log is in the RAM scratch space", log ~= nil)
    if log then
        local log_text = log:read("*a")
        log:close()
        check("the log has start, the note, and goodbye",
            string.find(log_text, "start pretend seed 42", 1, true)
            and string.find(log_text, "a line for the log", 1, true)
            and string.find(log_text, " goodbye\n", 1, true))
    end
end

-- refusals
check("no seed is refused", not pcall(goodbye.start, throwaway, "pretend"))
check("a program name with a space is refused", not pcall(goodbye.start, throwaway, "two words", "none"))
local ok_fraction, second = pcall(goodbye.start, throwaway, "fractions", "none")
if ok_fraction then
    check("a fractional count is refused", not pcall(second.count, second, "x", 0.5))
    second:finish()
end
check("reading a missing receipt is an error", not pcall(goodbye.read, throwaway .. "/output/none"))

io.write(string.format("goodbye: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
