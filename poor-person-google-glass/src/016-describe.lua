-- 016-describe.lua - a description in words, in; a model and a report, out.
--
-- In plain terms: reads a description file (input/descriptions/NAME.txt),
-- hands it to the reader (013), the solver (014) and the builder (015), and
-- writes the model as glTF and a report of every part's numbers into
-- output/described/. If any sentence was refused, every refusal is printed
-- and nothing is written but the goodbye receipt. Run by the `describe`
-- script in the project folder:
--   luajit src/016-describe.lua <project-dir> <description-file>

local project_dir, description_path = arg[1], arg[2]
if project_dir == nil or description_path == nil then
    error("usage: luajit 016-describe.lua <project-dir> <description-file>", 0)
end
package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path

local reader = require("013-reading-a-description")
local solver = require("014-solving-the-relations")
local builder = require("015-building-the-solids")
local gltf = require("005-gltf")

local AXIS_WORDS = { y = "upright", x = "left to right", z = "front to back" }

-- {{{ local function write_file()
local function write_file(path, text)
    local file, problem = io.open(path, "w")
    if file == nil then error("cannot write " .. path .. ": " .. tostring(problem), 0) end
    file:write(text)
    file:close()
end
-- }}}

-- {{{ local function say_goodbye()
-- The receipt: when, which description, and what came of it.
local function say_goodbye(fields)
    local lines = { "goodbye from describe (src/016-describe.lua)",
        "written      " .. os.date("%Y-%m-%d %H:%M:%S"),
        "seed         none (describing uses no randomness)" }
    for _, pair in ipairs(fields) do lines[#lines + 1] = string.format("%-12s %s", pair[1], tostring(pair[2])) end
    write_file(project_dir .. "/output/goodbye", table.concat(lines, "\n") .. "\n")
end
-- }}}

-- {{{ local function report()
-- The report: the description as written, every part's numbers, and every
-- assumption (what the description did not say and a default filled in).
local function report(name, description, solved, shape)
    local out = {
        "<!-- made by describe (src/016-describe.lua) on " .. os.date("%Y-%m-%d %H:%M") .. " from " .. description_path
            .. ", so the numbers behind the model can be read without opening it -->",
        "# " .. name, "",
        "Measured in " .. shape.units .. ". Triangles: " .. shape.triangle_count .. ".", "",
        "## The description", "", "```", (description:gsub("%s+$", "")), "```", "",
        "## The parts", "",
        "| part | kind | colour | axis | middle (x, y, z) | along | across | deep |",
        "|---|---|---|---|---|---|---|---|",
    }
    for _, part in ipairs(solved.parts) do
        local c, e = part.centre, part.extents
        out[#out + 1] = string.format("| %s | %s | %s | %s | %.3g, %.3g, %.3g | %.3g | %.3g | %.3g |",
            part.name, part.kind, part.colour_word, AXIS_WORDS[part.axis], c[1], c[2], c[3], e.along, e.across, e.deep)
    end
    out[#out + 1] = ""
    out[#out + 1] = "## Assumed (not said in the description)"
    out[#out + 1] = ""
    if #solved.assumptions == 0 then out[#out + 1] = "Nothing." end
    for _, a in ipairs(solved.assumptions) do out[#out + 1] = "- " .. a.part .. ": " .. a.text end
    out[#out + 1] = ""
    out[#out + 1] = "The middle of everything is the " .. tostring(solved.anchor) .. " (the first part named that no sentence places)."
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ run
local name = description_path:match("([^/]+)$"):gsub("%.[^.]*$", "")
local file, problem = io.open(description_path)
if file == nil then error("cannot read " .. description_path .. ": " .. tostring(problem), 0) end
local description = file:read("*a")
file:close()

local model, refusals = reader.read(description)
local solved = nil
-- the solver runs only on a description read whole: solving around a
-- refused sentence would refuse again for the same reason, louder
if #refusals == 0 then solved, refusals = solver.solve(model) end
if #refusals > 0 then
    io.stderr:write(description_path .. ": " .. #refusals .. " sentence problem(s); nothing was made\n")
    for _, r in ipairs(refusals) do io.stderr:write(string.format("  line %d: %s\n", r.line, r.message)) end
    say_goodbye({ { "description", description_path }, { "refused", #refusals }, { "made", "nothing" } })
    os.exit(1)
end

local shape = builder.build(solved, name)
local out_dir = project_dir .. "/output/described"
os.execute("mkdir -p '" .. out_dir .. "'")
local made_by = "made by describe (poor-person-google-glass, src/016-describe.lua) from " .. description_path
write_file(out_dir .. "/" .. name .. ".gltf", gltf.write(shape, made_by, shape.units))
write_file(out_dir .. "/" .. name .. ".report.md", report(name, description, solved, shape))
print(out_dir .. "/" .. name .. ".gltf")
print(out_dir .. "/" .. name .. ".report.md")
print(string.format("%d parts, %d triangles, %d assumptions", #solved.parts, shape.triangle_count, #solved.assumptions))
say_goodbye({ { "description", description_path }, { "parts", #solved.parts }, { "triangles", shape.triangle_count },
    { "assumed", #solved.assumptions }, { "model", out_dir .. "/" .. name .. ".gltf" } })
-- }}}
