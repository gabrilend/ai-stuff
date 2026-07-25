-- 031-stats-test.lua — proof for the measurer.
--
-- What this is, generally: the one measurer must itself be honest —
-- its measured render matches the runner's bytes, its wall clock
-- moves forward, and its summary counts what the reports hold.
-- Run: luajit src/031-stats-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local stats = require("030-stats")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name)
    end
end
-- }}}

-- the wall clock moves forward, finely
local a = stats.wall()
local b = stats.wall()
check("the wall clock moves forward", b > a)
check("the wall clock reads finer than whole seconds",
      a % 1 ~= 0 or b % 1 ~= 0)

-- a measured render tells the same story as the runner's report
local bytes, facts = stats.measure(DIR, "orbit", 0)
check("the measured render is a real gif", #bytes > 1000)
check("measured facts carry the stage clocks",
      facts.sim_seconds ~= nil and facts.wall_seconds > 0)
check("the measured byte count is the file's truth",
      facts.bytes == #bytes)

-- the summary counts what the reports hold (orbit and two-clocks
-- were rendered by earlier phases; more may exist)
local counted = stats.summarize(DIR)
check("the summary counts at least the two reference renders",
      counted >= 2)

print(string.format("stats: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
