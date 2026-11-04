-- 028-joints.lua - finds a model's joints and works out the filled ones.
--
-- In plain terms: `find` reads a model, finds every pair of parts that
-- touch or nearly touch (026) and merges them into the model's joint
-- records (027), adding empty spots and never touching what a person wrote.
-- `work` takes every joint whose equation has been written, fills the
-- calculation's inputs from the joint's measures and its parts' materials,
-- works it out (020), and writes the answers to
-- output/joints/MODEL.results.lua and a readable MODEL.report.md, which the
-- viewer reads to colour each joint. With neither word, both are done.
--
--   luajit src/028-joints.lua <project-dir> [find|work] MODEL-FILE [--distance D]
--
-- A joint that cannot be worked out (an input bound to a material not yet
-- assigned, a measure that does not exist, a unit that does not match) is
-- a problem: every problem is listed and nothing is written, so no answer
-- is ever made from a quietly filled-in value.

local project_dir = arg[1]
if project_dir == nil then error("usage: luajit 028-joints.lua <project-dir> [find|work] MODEL-FILE [--distance D]", 0) end
-- the code is found beside this file, not in the project folder given: the
-- project folder holds the data (models' records, materials, calculations)
-- and may be any folder of that shape, such as the tests' one in RAM
local code_dir = (arg[0]:match("^(.*)/[^/]+$") or ".")
package.path = code_dir .. "/?.lua;" .. code_dir .. "/../libs/?.lua;" .. package.path

local any_file = require("006-read-any-cad-file")
local checks = require("019-a-calculation-and-its-checks")
local engine = require("020-working-out-tolerances")
local data = require("024-writing-lua-data")
local materials_table = require("025-materials")
local finder = require("026-finding-joints")
local records = require("027-joint-records")

-- The structure measures a joint's inputs may be bound to, all lengths.
local MEASURES = { "gap", "reach_a", "reach_b", "contact_size" }
local IS_MEASURE = {}
for _, name in ipairs(MEASURES) do IS_MEASURE[name] = true end

-- {{{ local function find()
local function find(model_path, distance)
    local shape = any_file.read(model_path)
    local model = records.model_name(model_path)
    local size = 0
    for axis = 1, 3 do size = math.max(size, shape.bounds.max[axis] - shape.bounds.min[axis]) end
    -- default contact distance: half a percent of the model's size
    distance = distance or size * 0.005
    local started = os.clock()
    local found = finder.find(shape, distance)
    local record, counts = records.merge(records.read(project_dir, model), model, shape, found, distance)
    local names = {}
    for name in pairs(materials_table.load(project_dir)) do names[#names + 1] = name end
    table.sort(names)
    records.write(project_dir, record, MEASURES, names)
    print(string.format("%s: %d joints found in %.2f s (contact distance %.4g): %d new, %d refreshed, %d no longer found",
        model, #found, os.clock() - started, distance, counts.added, counts.refreshed, counts.lost))
    print("records: " .. records.path(project_dir, model))
    return #found
end
-- }}}

-- {{{ local function bound_calculation()
-- The joint's calculation with its bound inputs filled in, or nil and the
-- list of problems.
local function bound_calculation(record, joint, materials)
    local problems = {}
    local ok, calculation = pcall(checks.load, project_dir .. "/input/calculations/" .. joint.equation .. ".lua")
    if not ok then return nil, { "equation '" .. joint.equation .. "': " .. tostring(calculation) } end
    local by_name = {}
    for _, input in ipairs(calculation.inputs) do by_name[input.name] = input end
    for name, binding in pairs(joint.inputs) do
        local input = by_name[name]
        if input == nil then
            problems[#problems + 1] = "input '" .. name .. "' is not an input of " .. joint.equation
        elseif type(binding) == "number" then
            input.nominal = binding
            input.from = "a number written in the joint's record"
        elseif type(binding) == "string" and binding:match("^structure%.") then
            local measure = binding:match("^structure%.(.+)$")
            if not IS_MEASURE[measure] then
                problems[#problems + 1] = name .. ": no structure measure '" .. measure .. "' (" .. table.concat(MEASURES, ", ") .. ")"
            elseif record.millimetres_per_unit == nil or record.millimetres_per_unit <= 0 then
                problems[#problems + 1] = name .. ": millimetres_per_unit is still an empty spot; the model's unit in mm is needed"
            elseif input.unit ~= "mm" then
                problems[#problems + 1] = name .. ": a structure measure is in mm, but the input's unit is " .. input.unit
            else
                input.nominal = joint.found[measure] * record.millimetres_per_unit
                input.from = "this joint's " .. measure .. ", measured from the model (tolerance kept from " .. joint.equation .. ")"
            end
        elseif type(binding) == "string" and binding:match("^[ab]%.") then
            local side, property = binding:match("^([ab])%.(.+)$")
            local part = joint[side]
            local material_name = record.materials[part]
            local material = materials[material_name]
            if material_name == nil or material_name == "unassigned" then
                problems[#problems + 1] = name .. ": part '" .. part .. "' has no material yet (an empty spot in materials)"
            elseif material == nil then
                problems[#problems + 1] = name .. ": no material '" .. material_name .. "' in input/materials.lua"
            elseif material[property] == nil then
                problems[#problems + 1] = name .. ": " .. material_name .. " has no '" .. property .. "'"
            elseif material[property].unit ~= input.unit then
                problems[#problems + 1] = name .. ": " .. material_name .. "." .. property .. " is in " .. material[property].unit .. ", the input in " .. input.unit
            else
                local v = material[property]
                input.nominal, input.minus, input.plus = v.value, v.minus, v.plus
                input.from = material_name .. "." .. property .. " (input/materials.lua): " .. v.from
            end
        else
            problems[#problems + 1] = name .. ": a binding must be a number, \"structure.MEASURE\", \"a.PROPERTY\" or \"b.PROPERTY\""
        end
    end
    if #problems > 0 then return nil, problems end
    return calculation
end
-- }}}

-- {{{ local function work()
local function work(model_path)
    local model = records.model_name(model_path)
    local record = records.read(project_dir, model)
    if record == nil then error(model .. ": no joint records yet; run ./joints find " .. model_path .. " first", 0) end
    local materials = materials_table.load(project_dir)
    local answers, problems, empty = {}, {}, 0
    for _, joint in ipairs(record.joints) do
        if joint.equation == "" then
            empty = empty + 1
        else
            local calculation, why = bound_calculation(record, joint, materials)
            if calculation == nil then
                for _, p in ipairs(why) do problems[#problems + 1] = joint.a .. " / " .. joint.b .. ": " .. p end
            else
                local results = engine.work_out(calculation)
                local verdict = "pass"
                for _, r in ipairs(results) do if r.worst_verdict == "fail" then verdict = "fail" end end
                local inputs = {}
                for i, input in ipairs(calculation.inputs) do
                    inputs[i] = { name = input.name, nominal = input.nominal, minus = input.minus, plus = input.plus, unit = input.unit, from = input.from }
                end
                answers[#answers + 1] = { a = joint.a, b = joint.b, equation = joint.equation, question = calculation.question,
                    verdict = verdict, results = results, inputs = inputs, signature = records.signature(record, joint) }
            end
        end
    end
    if #problems > 0 then
        io.stderr:write(model .. ": " .. #problems .. " problem(s); nothing was written\n")
        for _, p in ipairs(problems) do io.stderr:write("  " .. p .. "\n") end
        os.exit(1)
    end
    local out = project_dir .. "/output/joints"
    os.execute("mkdir -p '" .. out .. "'")
    local made = os.date("%Y-%m-%d %H:%M")
    data.write_file(out .. "/" .. model .. ".results.lua", "-- made by src/028-joints.lua on " .. made .. " from input/joints/" .. model
        .. ".lua: the answers of every filled joint (format: docs/joints.md)", { model = model, made = made, joints = answers })
    -- {{{ the report
    local lines = { "<!-- made by src/028-joints.lua on " .. made .. " from input/joints/" .. model .. ".lua and output/joints/" .. model
        .. ".results.lua, so each joint's answer can be read without the viewer -->", "# Joints of " .. model, "",
        string.format("%d joints: %d with an equation, %d still empty.", #record.joints, #answers, empty), "" }
    for _, answer in ipairs(answers) do
        lines[#lines + 1] = "## " .. answer.a .. " / " .. answer.b .. ": " .. answer.verdict
        lines[#lines + 1] = ""
        lines[#lines + 1] = "**" .. answer.question .. "** (" .. answer.equation .. ")"
        lines[#lines + 1] = ""
        lines[#lines + 1] = "| answer | nominal | worst case | usual spread | verdict |"
        lines[#lines + 1] = "|---|---|---|---|---|"
        for _, r in ipairs(answer.results) do
            lines[#lines + 1] = string.format("| %s (%s) | %.4g | %.4g to %.4g | %.4g to %.4g | %s |", r.name, r.unit, r.nominal,
                r.worst.low, r.worst.high, r.spread.low, r.spread.high, r.worst_verdict)
        end
        lines[#lines + 1] = ""
        for _, input in ipairs(answer.inputs) do
            lines[#lines + 1] = string.format("- %s = %.4g %s (−%.4g, +%.4g): %s", input.name, input.nominal, input.unit, input.minus, input.plus, input.from)
        end
        lines[#lines + 1] = ""
    end
    local file = io.open(out .. "/" .. model .. ".report.md", "w")
    file:write(table.concat(lines, "\n") .. "\n")
    file:close()
    -- }}}
    local passes, fails = 0, 0
    for _, answer in ipairs(answers) do if answer.verdict == "pass" then passes = passes + 1 else fails = fails + 1 end end
    print(string.format("%s: %d joints worked out (%d pass, %d fail), %d still empty", model, #answers, passes, fails, empty))
    print("answers: " .. out .. "/" .. model .. ".report.md")
    return #answers, passes, fails, empty
end
-- }}}

-- {{{ run
local action, model_path, distance = nil, nil, nil
local i = 2
while i <= #arg do
    local word = arg[i]
    if word == "find" or word == "work" then action = word
    elseif word == "--distance" then distance = tonumber(arg[i + 1]); i = i + 1
    else model_path = word end
    i = i + 1
end
if model_path == nil then error("which model? usage: joints [find|work] MODEL-FILE [--distance D]", 0) end
local summary = {}
if action == nil or action == "find" then summary[#summary + 1] = { "found", find(model_path, distance) } end
if action == nil or action == "work" then
    local answered, passes, fails, empty = work(model_path)
    summary[#summary + 1] = { "worked out", answered }
    summary[#summary + 1] = { "pass", passes }
    summary[#summary + 1] = { "fail", fails }
    summary[#summary + 1] = { "empty", empty }
end
local goodbye = { "goodbye from joints (src/028-joints.lua)", "written      " .. os.date("%Y-%m-%d %H:%M:%S"),
    "seed         none (no randomness)", "model        " .. model_path }
for _, pair in ipairs(summary) do goodbye[#goodbye + 1] = string.format("%-12s %d", pair[1], pair[2]) end
local file = io.open(project_dir .. "/output/goodbye", "w")
file:write(table.concat(goodbye, "\n") .. "\n")
file:close()
-- }}}
