-- 025-materials.lua - the materials table, loaded and checked.
--
-- In plain terms: input/materials.lua names each material the parts may be
-- made of and gives its fundamentals (how much it grows when warmed, how
-- heavy, how stiff, how it bends light), each with its tolerance and where
-- the number came from. This loads it and refuses it, naming every problem,
-- if any value is malformed, so a joint never works out with a broken
-- material quietly.
--
-- A material: { property name = { value, minus, plus, unit, from } }, the
-- unit from the calculations' list (019).

local checks = require("019-a-calculation-and-its-checks")

local M = {}

-- {{{ function M.load()
-- project_dir -> { material name -> material }.
function M.load(project_dir)
    local path = project_dir .. "/input/materials.lua"
    local chunk, problem = loadfile(path)
    if chunk == nil then error("cannot load " .. path .. ": " .. tostring(problem), 0) end
    local materials = chunk()
    local problems = {}
    for name, material in pairs(materials) do
        for property, v in pairs(material) do
            local label = name .. "." .. property
            if type(v.value) ~= "number" then problems[#problems + 1] = label .. ": value is not a number" end
            if type(v.minus) ~= "number" or v.minus < 0 or type(v.plus) ~= "number" or v.plus < 0 then
                problems[#problems + 1] = label .. ": minus and plus must be numbers, zero or more"
            end
            if not checks.UNITS[v.unit] then problems[#problems + 1] = label .. ": unit '" .. tostring(v.unit) .. "' is not in the list" end
            if type(v.from) ~= "string" or v.from == "" then problems[#problems + 1] = label .. ": no 'from'" end
        end
    end
    table.sort(problems)
    if #problems > 0 then error(path .. ":\n  " .. table.concat(problems, "\n  "), 0) end
    return materials
end
-- }}}

return M
