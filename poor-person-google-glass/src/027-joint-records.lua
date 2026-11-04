-- 027-joint-records.lua - a model's joint records: made, merged, read.
--
-- In plain terms: each model keeps a file of its joints
-- (input/joints/MODEL.lua, format in docs/joints.md): what was measured
-- where two parts meet, and an empty spot where a person writes the
-- calculation that says whether the joint works. Finding the joints again
-- (after the model changes) must never lose what a person wrote, so this
-- merges: new joints are added with empty spots, measurements are
-- refreshed, and a joint no longer found is kept and marked so.
--
-- The empty spot is the empty string: `equation = ""`. (A missing field
-- would vanish from the file, and an empty spot has to be seen to be
-- filled.)

local data = require("024-writing-lua-data")

local M = {}

-- {{{ function M.path()
function M.path(project_dir, model) return project_dir .. "/input/joints/" .. model .. ".lua" end
-- }}}

-- {{{ function M.model_name()
-- A model's name from its file: "crown-sketch.gltf" -> "crown-sketch".
function M.model_name(file_name) return (file_name:match("([^/]+)$"):gsub("%.[^.]*$", "")) end
-- }}}

-- {{{ local function same_pair()
local function same_pair(joint, a, b) return (joint.a == a and joint.b == b) or (joint.a == b and joint.b == a) end
-- }}}

-- {{{ function M.merge()
-- existing: the record table already on disk, or nil. Returns the merged
-- record table, and counts { added, refreshed, lost } (whole numbers).
function M.merge(existing, model, shape, found, contact_distance)
    local record = existing or {
        model = model, materials = {}, joints = {},
        -- millimetres in one of the model's units: known when the model says
        -- its units are millimetres; otherwise an empty spot (-1) that
        -- working out refuses until a person fills it
        millimetres_per_unit = (shape.units == "millimetres") and 1 or -1,
    }
    record.contact_distance = contact_distance
    for _, part in ipairs(shape.parts) do
        if record.materials[part.name] == nil then record.materials[part.name] = "unassigned" end
    end
    local counts = { added = 0, refreshed = 0, lost = 0 }
    local seen = {}
    for _, f in ipairs(found) do
        local entry = nil
        for index, joint in ipairs(record.joints) do
            if same_pair(joint, f.a, f.b) then entry = joint; seen[index] = true end
        end
        -- measures rounded to 6 significant figures: a person reads and edits
        -- this file, and more digits than the model's own accuracy are noise
        local function r(v) return tonumber(string.format("%.6g", v)) end
        local function r3(v) return { r(v[1]), r(v[2]), r(v[3]) } end
        local measured = { gap = r(f.gap), contact_point = r3(f.contact_point), normal = r3(f.normal), reach_a = r(f.reach_a),
            reach_b = r(f.reach_b), contact_size = r(f.contact_size), still_found = true }
        if entry then
            -- found before: refresh what was measured, keep what was written;
            -- if the pair is stored the other way round, the measures that
            -- belong to a side are swapped to match
            if entry.a ~= f.a then
                measured.reach_a, measured.reach_b = measured.reach_b, measured.reach_a
                measured.normal = { -measured.normal[1], -measured.normal[2], -measured.normal[3] }
            end
            entry.found = measured
            counts.refreshed = counts.refreshed + 1
        else
            record.joints[#record.joints + 1] = { a = f.a, b = f.b, found = measured, equation = "", inputs = {}, note = "" }
            seen[#record.joints] = true
            counts.added = counts.added + 1
        end
    end
    for index, joint in ipairs(record.joints) do
        if not seen[index] and joint.found.still_found then
            joint.found.still_found = false
            counts.lost = counts.lost + 1
        end
    end
    return record, counts
end
-- }}}

-- {{{ function M.write()
-- Writes the records with a header saying what may be written where.
function M.write(project_dir, record, measures, material_names)
    os.execute("mkdir -p '" .. project_dir .. "/input/joints'")
    local header = table.concat({
        "-- " .. record.model .. ".lua - joint records for the model " .. record.model .. " (format: docs/joints.md).",
        "-- Made and refreshed by ./joints find, which never changes what a person wrote:",
        "-- each part's material, and each joint's equation, inputs and note.",
        "-- Write notes in a joint's `note`, not as comments: this file is rewritten.",
        "--",
        "-- To fill a joint: equation = \"NAME\" (a calculation in input/calculations/),",
        "-- inputs = { INPUT = \"structure.MEASURE\" or \"a.PROPERTY\" or \"b.PROPERTY\" or a number }.",
        "--   structure measures (in mm): " .. table.concat(measures, ", "),
        "--   materials (input/materials.lua): " .. table.concat(material_names, ", "),
        "-- An empty spot is \"\" (an equation) or \"unassigned\" (a material) or -1 (millimetres_per_unit).",
    }, "\n")
    data.write_file(M.path(project_dir, record.model), header, record)
end
-- }}}

-- {{{ function M.read()
-- The records for a model, or nil if it has none yet.
function M.read(project_dir, model) return data.read_file(M.path(project_dir, model)) end
-- }}}

-- {{{ function M.signature()
-- A text standing for everything a joint's answer depends on: its
-- equation, inputs, the two materials, the measures and the unit. Stored
-- with the answer, and compared later, so a record changed after it was
-- worked out shows as waiting rather than with a stale verdict.
function M.signature(record, joint)
    return data.serialise({ joint.equation, joint.inputs, record.materials[joint.a], record.materials[joint.b],
        joint.found.gap, joint.found.reach_a, joint.found.reach_b, joint.found.contact_size, record.millimetres_per_unit })
end
-- }}}

return M
