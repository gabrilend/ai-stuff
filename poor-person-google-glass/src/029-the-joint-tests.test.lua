-- 029-the-joint-tests.test.lua - checks joint finding, records and their
-- working out, end to end, in a small project made in RAM.
--
-- In plain terms: two boxes a known distance apart must be found with that
-- gap; two touching boxes with no gap; finding again must keep what a
-- person wrote; a filled joint must work out from the joint's own measures
-- and its parts' materials; and a joint bound to a material nobody has
-- assigned must be refused rather than worked out with a stand-in.
--
-- Run with LuaJIT (scripts/run-tests does this):
--   luajit src/029-the-joint-tests.test.lua <project-dir>

local project_dir = arg[1]
if project_dir == nil then error("usage: luajit 029-the-joint-tests.test.lua <project-dir>", 0) end
package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path

local record_kit = require("001-the-shape-record")
local kit = require("002-the-test-shapes").kit
local gltf = require("005-gltf")
local data = require("024-writing-lua-data")
local finder = require("026-finding-joints")
local records = require("027-joint-records")

local SCRATCH = project_dir .. "/tmp/shared-memory/joint-tests"
local tests = {}
local function test(name, body) tests[#tests + 1] = { name = name, body = body } end
local function expect(condition, message) if not condition then error(message, 2) end end
local function near(a, b, within) return math.abs(a - b) <= (within or 1e-6) end

-- {{{ local function two_boxes()
-- Two unit-ish boxes side by side along x, `gap` apart (mm).
local function two_boxes(gap)
    local shape = record_kit.new("two-boxes", "made", "y")
    shape.units = "millimetres"
    kit.box(record_kit.add_part(shape, "left"), 0, 0, 0, 10, 4, 4)
    kit.box(record_kit.add_part(shape, "right"), 10 + gap, 0, 0, 20 + gap, 4, 4)
    return record_kit.finish(shape)
end
-- }}}

-- {{{ local function shell()
-- Runs a command; returns whether it succeeded and what it printed.
local function shell(command)
    local pipe = io.popen(command .. " 2>&1")
    local text = pipe:read("*a")
    return pipe:close(), text
end
-- }}}

test("a point's nearest place on a triangle", function()
    local q = finder.closest_on_triangle({ 0.2, 5, 0.2 }, { 0, 0, 0 }, { 1, 0, 0 }, { 0, 0, 1 })
    expect(near(q[1], 0.2) and near(q[2], 0) and near(q[3], 0.2), "foot inside the triangle")
    q = finder.closest_on_triangle({ 3, 0, 3 }, { 0, 0, 0 }, { 1, 0, 0 }, { 0, 0, 1 })
    expect(near(q[1], 0.5) and near(q[3], 0.5), "beyond the long edge: its middle")
end)

test("two boxes 0.3 apart: one joint, gap 0.3, across x", function()
    local joints = finder.find(two_boxes(0.3), 1)
    expect(#joints == 1, "joints: " .. #joints)
    local j = joints[1]
    expect(near(j.gap, 0.3), "gap " .. j.gap)
    expect(near(math.abs(j.normal[1]), 1), "normal not across x")
    expect(near(j.reach_a, 10) and near(j.reach_b, 10), "reaches " .. j.reach_a .. " / " .. j.reach_b)
end)

test("touching boxes: gap 0; boxes further than the contact distance: none", function()
    local touching = finder.find(two_boxes(0), 1)
    expect(#touching == 1 and near(touching[1].gap, 0), "touching gap")
    expect(#finder.find(two_boxes(2), 1) == 0, "boxes 2 apart found at contact distance 1")
end)

test("finding again keeps what a person wrote, and marks a lost joint", function()
    local shape = two_boxes(0.3)
    local record = records.merge(nil, "two-boxes", shape, finder.find(shape, 1), 1)
    record.joints[1].equation = "joint-gap-under-heat"
    record.joints[1].note = "kept"
    record.materials.left = "stainless-304"
    local again = records.merge(record, "two-boxes", shape, finder.find(shape, 1), 1)
    expect(again.joints[1].equation == "joint-gap-under-heat" and again.joints[1].note == "kept", "equation or note lost")
    expect(again.materials.left == "stainless-304", "material lost")
    local apart = two_boxes(5)
    local lost = records.merge(again, "two-boxes", apart, finder.find(apart, 1), 1)
    expect(#lost.joints == 1 and lost.joints[1].found.still_found == false, "the lost joint was dropped or not marked")
end)

test("a filled joint works out from its measures and materials (end to end)", function()
    os.execute("rm -rf '" .. SCRATCH .. "'")
    os.execute("mkdir -p '" .. SCRATCH .. "/input/calculations' '" .. SCRATCH .. "/output'")
    os.execute("cp '" .. project_dir .. "/input/materials.lua' '" .. SCRATCH .. "/input/'")
    os.execute("cp '" .. project_dir .. "/input/calculations/joint-gap-under-heat.lua' '" .. SCRATCH .. "/input/calculations/'")
    local model = SCRATCH .. "/two-boxes.gltf"
    local file = io.open(model, "w")
    file:write(gltf.write(two_boxes(0.3), "the tests", "millimetres"))
    file:close()
    local program = "luajit '" .. project_dir .. "/src/028-joints.lua' '" .. SCRATCH .. "'"
    local ok, text = shell(program .. " find '" .. model .. "' --distance 1")
    expect(ok, "find failed: " .. text)
    -- unfilled material: refused, nothing written
    local record = records.read(SCRATCH, "two-boxes")
    record.joints[1].equation = "joint-gap-under-heat"
    record.joints[1].inputs = { gap = "structure.gap", reach_a = "structure.reach_a", reach_b = "structure.reach_b",
        expansion_a = "a.expansion", expansion_b = "b.expansion" }
    records.write(SCRATCH, record, {}, {})
    ok, text = shell(program .. " work '" .. model .. "'")
    expect(not ok and text:find("has no material yet", 1, true), "an unassigned material was not refused: " .. text)
    -- materials filled: worked out with stainless on both sides
    record.materials = { left = "stainless-304", right = "stainless-304" }
    records.write(SCRATCH, record, {}, {})
    ok, text = shell(program .. " work '" .. model .. "'")
    expect(ok, "work failed: " .. text)
    local results = data.read_file(SCRATCH .. "/output/joints/two-boxes.results.lua")
    local answer = results.joints[1].results[1]
    -- 0.3 - (10 x 17.3e-6 + 10 x 17.3e-6) / 2 x (30 - 20)
    expect(near(answer.nominal, 0.3 - 10 * 17.3e-6 * 10, 1e-9), "nominal " .. answer.nominal)
    expect(results.joints[1].signature == records.signature(record, record.joints[1]), "signature differs from the record's")
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
