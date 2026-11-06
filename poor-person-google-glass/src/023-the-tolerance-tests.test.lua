-- 023-the-tolerance-tests.test.lua - checks the calculation format and its
-- engine against answers known by hand.
--
-- In plain terms: a stack of three lengths has a worst case that is the sum
-- of their tolerances and a spread that is the root of the sum of their
-- squares; the engine must say exactly that. Broken calculation files must
-- be refused with every problem named. Every calculation in
-- input/calculations/ must load and work out, the same way twice.
--
-- Run with LuaJIT (scripts/run-tests does this):
--   luajit src/023-the-tolerance-tests.test.lua <project-dir>

local project_dir = arg[1]
if project_dir == nil then error("usage: luajit 023-the-tolerance-tests.test.lua <project-dir>", 0) end
package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path

local checks = require("019-a-calculation-and-its-checks")
local engine = require("020-working-out-tolerances")

local tests = {}
local function test(name, body) tests[#tests + 1] = { name = name, body = body } end

-- {{{ helpers
local function expect(condition, message) if not condition then error(message, 2) end end
local function near(a, b) return math.abs(a - b) < 1e-9 * math.max(1, math.abs(a), math.abs(b)) end
local function expect_error(fragment, body)
    local ok, problem = pcall(body)
    if ok then error("expected an error mentioning '" .. fragment .. "', got none", 2) end
    if not tostring(problem):find(fragment, 1, true) then error("expected '" .. fragment .. "', got: " .. tostring(problem), 2) end
end
-- {{{ local function stack()
-- a + b - c, each with its own tolerance: the textbook stack-up
local function stack(limit)
    return checks.check({
        question = "a test stack",
        inputs = {
            { name = "a", nominal = 10, unit = "mm", minus = 0.1, plus = 0.1, from = "test" },
            { name = "b", nominal = 5, unit = "mm", minus = 0.2, plus = 0.2, from = "test" },
            { name = "c", nominal = 14, unit = "mm", minus = 0.05, plus = 0.05, from = "test" },
        },
        outputs = { { name = "gap", unit = "mm", at_least = limit } },
        compute = function(v) return { gap = v.a + v.b - v.c } end,
    }, "stack")
end
-- }}}
-- }}}

test("a linear stack: worst case is the sum of tolerances", function()
    local r = engine.work_out(stack())[1]
    expect(near(r.nominal, 1), "nominal " .. r.nominal)
    expect(near(r.worst.low, 1 - 0.35) and near(r.worst.high, 1 + 0.35), string.format("worst %.6f to %.6f", r.worst.low, r.worst.high))
end)

test("a linear stack: spread is the root-sum-square", function()
    local r = engine.work_out(stack())[1]
    local rss = math.sqrt(0.1 ^ 2 + 0.2 ^ 2 + 0.05 ^ 2)
    expect(near(r.spread.high - r.spread.centre, rss), "spread " .. (r.spread.high - r.spread.centre) .. ", wanted " .. rss)
    expect(r.shares[1].input == "b" and near(r.shares[1].percent, 100 * 0.04 / 0.0525), "largest share should be b")
end)

test("verdicts: the worst case can fail while the spread passes", function()
    local r = engine.work_out(stack(0.7))[1]
    expect(r.worst_verdict == "fail" and r.spread_verdict == "pass", r.worst_verdict .. " / " .. r.spread_verdict)
end)

test("a size (bends back at zero) still has a spread", function()
    local calculation = checks.check({
        question = "a size", inputs = { { name = "x", nominal = 0, unit = "mm", minus = 1, plus = 1, from = "test" } },
        outputs = { { name = "size", unit = "mm" } }, compute = function(v) return { size = math.abs(v.x) } end,
    }, "size")
    local r = engine.work_out(calculation)[1]
    expect(near(r.spread.high - r.spread.centre, 1), "spread " .. (r.spread.high - r.spread.centre) .. ", wanted 1")
end)

test("a broken calculation is refused with every problem named", function()
    expect_error("no 'from'", function()
        checks.check({ question = "q", outputs = { { name = "o", unit = "mm" } }, compute = function() return {} end,
            inputs = { { name = "x", nominal = 1, unit = "furlongs", minus = -1, plus = 0 } } }, "broken")
    end)
    local ok, problem = pcall(checks.check, { question = "q", outputs = { { name = "o", unit = "mm" } }, compute = function() return {} end,
        inputs = { { name = "x", nominal = 1, unit = "furlongs", minus = -1, plus = 0 } } }, "broken")
    expect(problem:find("furlongs", 1, true) and problem:find("minus", 1, true) and problem:find("from", 1, true), "not every problem named: " .. problem)
end)

test("a formula giving no number for an output is refused", function()
    local calculation = checks.check({ question = "q", inputs = { { name = "x", nominal = 1, unit = "mm", minus = 0, plus = 0, from = "test" } },
        outputs = { { name = "o", unit = "mm" } }, compute = function() return {} end }, "empty")
    expect_error("no finite number for 'o'", function() engine.work_out(calculation) end)
end)

test("every calculation in input/calculations works out, the same twice", function()
    local count = 0
    for file in io.popen("ls '" .. project_dir .. "/input/calculations'"):lines() do
        local path = project_dir .. "/input/calculations/" .. file
        local first = engine.work_out(checks.load(path))
        local second = engine.work_out(checks.load(path))
        for i, r in ipairs(first) do
            expect(r.worst.low == second[i].worst.low and r.spread.high == second[i].spread.high, file .. ": two runs differ")
        end
        count = count + 1
    end
    expect(count >= 6, "calculations found: " .. count)
end)

-- {{{ run them
local failed = 0
for _, entry in ipairs(tests) do
    local ok, problem = pcall(entry.body)
    if ok then print("pass  " .. entry.name) else failed = failed + 1; print("FAIL  " .. entry.name .. "\n      " .. tostring(problem)) end
end
print(string.format("%d of %d passed", #tests - failed, #tests))
os.exit(failed == 0 and 0 or 1)
-- }}}
