-- 029-parallel-test.lua — proof for the many-hands pipeline.
--
-- What this is, generally: renders the orbit reference three ways —
-- the sequential runner, one worker, three workers — and demands
-- all three yield byte-identical gifs. Determinism surviving
-- parallelism is the pipeline's honesty; nothing else it does
-- matters if this fails. Run: luajit src/029-parallel-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local score = require("022-score")
local compile = require("024-compile")
local main = require("026-render-main")
local parallel = require("028-parallel")

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

-- three roads, one destination. each render recompiles from disk:
-- compiled scores carry live per-track emission carries, and a
-- reused timeline would leak one render's fractions into the next
local sequential = main.render_to_gif(
    compile.score(score.read(DIR .. "/input/orbit.lua")))
local one_hand, one_facts = parallel.render_to_gif(
    compile.score(score.read(DIR .. "/input/orbit.lua")), DIR, 1)
local many_hands, many_facts = parallel.render_to_gif(
    compile.score(score.read(DIR .. "/input/orbit.lua")), DIR, 3)

check("one worker matches the sequential runner byte for byte",
      one_hand == sequential)
check("three workers match one worker byte for byte",
      many_hands == one_hand)
check("the peak population is the same story every time",
      one_facts.peak == many_facts.peak)
check("all frames arrived through the channels",
      one_facts.frames == many_facts.frames
      and many_facts.frames == 75)

-- the floor: zero workers is refused
local compiled = compile.score(score.read(DIR .. "/input/orbit.lua"))
check("zero workers is refused",
      not pcall(parallel.render_to_gif, compiled, DIR, 0))

print(string.format("parallel: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
