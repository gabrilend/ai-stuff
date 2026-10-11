-- 019-a-calculation-and-its-checks.lua - reads one calculation file and
-- refuses it if it breaks the format.
--
-- In plain terms: a calculation file (input/calculations/NAME.lua, format in
-- docs/tolerances.md) is a question, a list of inputs each with its
-- tolerance and its source, a list of outputs each with an optional limit,
-- and a formula. This file loads one and checks every field, reporting every
-- problem at once with the input's or output's name, so a slip in a long
-- file is found in one round.
--
-- A calculation, once checked:
--   { name = string (the file's name), question = string,
--     inputs = list of { name, nominal, unit, minus, plus, from,
--                        condition (true for what cannot be made more
--                        exactly: temperature, the wearer; else absent) },
--     outputs = list of { name, unit, at_least (number or nil),
--                         at_most (number or nil) },
--     compute = function(values by input name) -> values by output name }

local M = {}

-- The units a calculation may use (docs/tolerances.md); a set.
M.UNITS = {}
for _, unit in ipairs({ "mm", "mm2", "mm3", "um", "deg", "arcmin", "mrad", "C", "per-C",
                        "GPa", "MPa", "g", "ratio", "count", "percent" }) do
    M.UNITS[unit] = true
end

-- {{{ function M.check()
-- Returns the calculation, or raises listing every problem found.
function M.check(calculation, name)
    local problems = {}
    local function problem(text) problems[#problems + 1] = text end
    if type(calculation) ~= "table" then error(name .. ": the file must return a table", 0) end
    if type(calculation.question) ~= "string" then problem("no question (a sentence saying what this answers)") end
    if type(calculation.compute) ~= "function" then problem("no compute function") end
    if type(calculation.inputs) ~= "table" or #calculation.inputs == 0 then problem("no inputs") end
    if type(calculation.outputs) ~= "table" or #calculation.outputs == 0 then problem("no outputs") end

    local seen = {}
    for index, input in ipairs(calculation.inputs or {}) do
        local label = "input " .. index .. " (" .. tostring(input.name) .. ")"
        if type(input.name) ~= "string" then problem(label .. ": no name") end
        if seen[input.name] then problem(label .. ": a second input with this name") end
        seen[input.name] = true
        if type(input.nominal) ~= "number" then problem(label .. ": nominal is not a number") end
        if not M.UNITS[input.unit] then problem(label .. ": unit '" .. tostring(input.unit) .. "' is not in the list (docs/tolerances.md)") end
        for _, side in ipairs({ "minus", "plus" }) do
            if type(input[side]) ~= "number" or input[side] < 0 then problem(label .. ": " .. side .. " must be a number, zero or more") end
        end
        -- a number with no source is the one thing never allowed: a guess
        -- must say it is a guess
        if input.condition ~= nil and type(input.condition) ~= "boolean" then problem(label .. ": condition must be true or false") end
        if type(input.from) ~= "string" or input.from == "" then problem(label .. ": no 'from' (a datasheet, docs/sizes.md, or 'guess: why')") end
    end
    for index, output in ipairs(calculation.outputs or {}) do
        local label = "output " .. index .. " (" .. tostring(output.name) .. ")"
        if type(output.name) ~= "string" then problem(label .. ": no name") end
        if not M.UNITS[output.unit] then problem(label .. ": unit '" .. tostring(output.unit) .. "' is not in the list") end
        if output.at_least ~= nil and type(output.at_least) ~= "number" then problem(label .. ": at_least is not a number") end
        if output.at_most ~= nil and type(output.at_most) ~= "number" then problem(label .. ": at_most is not a number") end
    end
    -- 2^n corners are tried; past 16 inputs that is too many to try them all
    if #(calculation.inputs or {}) > 16 then problem("more than 16 inputs; split the calculation") end

    if #problems > 0 then error(name .. ":\n  " .. table.concat(problems, "\n  "), 0) end
    calculation.name = name
    return calculation
end
-- }}}

-- {{{ function M.load()
-- Loads and checks a calculation file. path (string) -> calculation.
function M.load(path)
    local name = path:match("([^/]+)%.lua$") or path
    local chunk, problem = loadfile(path)
    if chunk == nil then error("cannot load " .. path .. ": " .. tostring(problem), 0) end
    return M.check(chunk(), name)
end
-- }}}

return M
