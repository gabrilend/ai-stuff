-- 022-calculate.lua - works out calculations and writes their reports.
--
-- In plain terms: for each calculation file in input/calculations/ (or the
-- ones named), checks it (019), works it out (020), writes the numbers to
-- output/calculations/NAME.results.lua, then has the report (021) read that
-- file back and write NAME.report.md. Prints one line per answer and ends
-- by writing output/goodbye with counts of passes and fails. Run by the
-- `calculate` script:
--   luajit src/022-calculate.lua <project-dir> [NAME...]

local project_dir = arg[1]
if project_dir == nil then error("usage: luajit 022-calculate.lua <project-dir> [NAME...]", 0) end
package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path

local checks = require("019-a-calculation-and-its-checks")
local engine = require("020-working-out-tolerances")
local report = require("021-the-tolerance-report")

local IN, OUT = project_dir .. "/input/calculations", project_dir .. "/output/calculations"

local serialise = require("024-writing-lua-data").serialise

-- {{{ local function write_file()
local function write_file(path, text)
    local file, problem = io.open(path, "w")
    if file == nil then error("cannot write " .. path .. ": " .. tostring(problem), 0) end
    file:write(text)
    file:close()
end
-- }}}

-- {{{ run
local names = {}
for i = 2, #arg do names[#names + 1] = arg[i] end
if #names == 0 then
    for file in io.popen("ls '" .. IN .. "'"):lines() do
        local name = file:match("^(.+)%.lua$")
        if name then names[#names + 1] = name end
    end
end
os.execute("mkdir -p '" .. OUT .. "'")

local passes, fails, informational = 0, 0, 0
local made = os.date("%Y-%m-%d %H:%M")
for _, name in ipairs(names) do
    local calculation = checks.load(IN .. "/" .. name .. ".lua")
    local results = engine.work_out(calculation)
    local inputs = {}
    for i, input in ipairs(calculation.inputs) do
        inputs[i] = { name = input.name, nominal = input.nominal, unit = input.unit, minus = input.minus, plus = input.plus, from = input.from,
            condition = input.condition or false }
    end
    local results_path = OUT .. "/" .. name .. ".results.lua"
    write_file(results_path, "-- made by src/022-calculate.lua on " .. made .. " from input/calculations/" .. name
        .. ".lua: every answer of the calculation (format: src/021-the-tolerance-report.lua)\nreturn "
        .. serialise({ name = name, question = calculation.question, made = made, inputs = inputs, results = results }) .. "\n")
    write_file(OUT .. "/" .. name .. ".report.md", report.write(results_path))
    print(name .. ": " .. calculation.question)
    for _, r in ipairs(results) do
        print(string.format("  %-28s nominal %-10.4g worst %.4g to %.4g  spread %.4g to %.4g %-7s worst %-8s spread %s",
            r.name, r.nominal, r.worst.low, r.worst.high, r.spread.low, r.spread.high, r.unit, r.worst_verdict, r.spread_verdict))
        if r.worst_verdict == "pass" then passes = passes + 1
        elseif r.worst_verdict == "fail" then fails = fails + 1
        else informational = informational + 1 end
    end
end

local goodbye = { "goodbye from calculate (src/022-calculate.lua)", "written      " .. os.date("%Y-%m-%d %H:%M:%S"),
    "seed         none (calculating uses no randomness)",
    string.format("calculations %d", #names),
    string.format("answers      %d pass, %d fail (worst case), %d with no limit", passes, fails, informational) }
write_file(project_dir .. "/output/goodbye", table.concat(goodbye, "\n") .. "\n")
-- }}}
