-- 017-the-word-tests.test.lua - checks the describing language end to end:
-- the vocabulary against its document, the reader, the solver, the builder,
-- and that the same description always makes the same file.
--
-- In plain terms: feeds small descriptions through each step and checks
-- the numbers that come out (a lid "twice as wide" really is twice as wide;
-- a part "on top of" another really touches it), and that every kind of
-- broken description is refused with its line and a useful suggestion.
--
-- Run with LuaJIT (scripts/run-tests does this):
--   luajit src/017-the-word-tests.test.lua <project-dir>
-- Exit status 0 when every test passes, 1 otherwise.

local project_dir = arg[1]
if project_dir == nil then error("usage: luajit 017-the-word-tests.test.lua <project-dir>", 0) end
package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path

local words = require("012-the-shape-words")
local reader = require("013-reading-a-description")
local solver = require("014-solving-the-relations")
local builder = require("015-building-the-solids")
local record = require("001-the-shape-record")

local tests = {}
local function test(name, body) tests[#tests + 1] = { name = name, body = body } end

-- {{{ helpers
-- {{{ local function expect()
local function expect(condition, message)
    if not condition then error(message, 2) end
end
-- }}}

-- {{{ local function near()
local function near(a, b) return math.abs(a - b) < 1e-6 end
-- }}}

-- {{{ local function solve()
-- A description to the solver's result; raises listing refusals if any.
local function solve(text)
    local read, refusals = reader.read(text)
    local model = nil
    if #refusals == 0 then model, refusals = solver.solve(read) end
    if #refusals > 0 then
        local lines = {}
        for _, r in ipairs(refusals) do lines[#lines + 1] = "line " .. r.line .. ": " .. r.message end
        error("refused: " .. table.concat(lines, "; "), 2)
    end
    local by_name = {}
    for _, part in ipairs(model.parts) do by_name[part.name] = part end
    return by_name, read
end
-- }}}

-- {{{ local function refusals_of()
-- A description's refusals (from reading, or else from solving), as text.
local function refusals_of(text)
    local model, refusals = reader.read(text)
    if #refusals == 0 then _, refusals = solver.solve(model) end
    local lines = {}
    for _, r in ipairs(refusals) do lines[#lines + 1] = "line " .. r.line .. ": " .. r.message end
    return refusals, table.concat(lines, "\n")
end
-- }}}
-- }}}

-- {{{ the vocabulary and its document
test("every word the program knows is in docs/shape-words.md, and back", function()
    local file = assert(io.open(project_dir .. "/docs/shape-words.md"))
    local document = file:read("*a")
    file:close()
    local listed = {}
    for word in document:gmatch("`([%w_]+)`") do listed[word] = true end
    local known = words.all_words()
    for word in pairs(known) do expect(listed[word], "the program knows '" .. word .. "' but the document does not list it") end
    -- the document's listed words that are words (not sentence shapes in
    -- capitals) must all be known
    for word in pairs(listed) do
        if word == word:lower() then expect(known[word], "the document lists '" .. word .. "' but the program does not know it") end
    end
end)
-- }}}

-- {{{ the reader
test("words: phrases joined, articles dropped, ratios in digits kept", function()
    local list = table.concat(reader.words_of("The lid is a third as wide as the drum, on top of it"), " ")
    expect(list == "lid is a_third as wide as drum on_top_of it", "got: " .. list)
    list = table.concat(reader.words_of("The cap is 1.5 times as tall as the disc-shaped thing"), " ")
    expect(list == "cap is 1.5_times as tall as disc shaped thing", "got: " .. list)
end)

test("sentences: cut at full stops, not inside numbers; comments skipped", function()
    local sentences = reader.sentences_of("# a comment.\nThe alpha is a box. The beta is 2.5 times as wide as the alpha.\n")
    expect(#sentences == 2, "sentences: " .. #sentences)
    expect(sentences[2].text:find("2.5", 1, true) and sentences[2].line == 2, "the decimal was cut or the line lost")
end)

test("every sentence shape reads", function()
    local _, model = solve([[
There is a red cylinder called the drum.
The lid is a disc. The lid is blue. The lid is twice as wide as the drum. The lid is on top of the drum.
The pin is a rod. The pin is as long as the drum is wide. The pin passes through the lid.
The cap is a box. The cap is slightly smaller than the lid. The cap lies left to right. The cap is beside the drum.
The bead is a ball. The bead is a quarter the size of the drum. The bead is at the end of the pin.
The hoop is a ring. The hoop is proportionally scaled to the lid. The hoop is around the drum.
The twin is a disc. The twin is shaped like the drum. The twin is aligned with the rotational axis of the cylinder shaped thing.
The twin is under the drum.
]])
    local types = {}
    for _, s in ipairs(model.statements) do types[s.type] = true end
    for _, t in ipairs({ "colour", "extent", "place", "direction", "aligned", "proportion" }) do
        expect(types[t], "no '" .. t .. "' statement was read")
    end
    expect(#model.parts == 7, "parts: " .. #model.parts)
end)

test("a misspelt word is refused with the nearest word", function()
    local _, text = refusals_of("The drum is a cylinder.\nThe lid is a disc. The lid is slightly widr than the drum. The lid is on the drum.")
    expect(text:find("unknown word 'widr' (nearest: 'wide' or 'wider')", 1, true), "got: " .. text)
end)

test("three broken lines give three refusals in one pass", function()
    local refusals, text = refusals_of("The drum is a cylinder.\nThe lid is a dsic.\nThe lid is on top of the drun.\nThe knob is purpel.\n")
    local lines = {}
    for _, r in ipairs(refusals) do lines[r.line] = true end
    expect(lines[2] and lines[3] and lines[4], "got: " .. text)
end)

test("a sentence whose name was only an article says so", function()
    local _, text = refusals_of("The a is a box.")
    expect(text:find("has no part name before 'is'", 1, true), "got: " .. text)
end)

test("'the cylinder' with two cylinders lists both", function()
    local _, text = refusals_of("The alpha is a cylinder. The beta is a cylinder. The beta is on top of the cylinder.")
    expect(text:find("could be any of: alpha, beta", 1, true), "got: " .. text)
end)
-- }}}

-- {{{ the solver
test("'twice as wide' doubles; unmentioned extents keep proportion", function()
    local parts = solve("The drum is a cylinder. The lid is a disc. The lid is twice as wide as the drum. The lid is on top of the drum.")
    local lid = parts.lid
    expect(near(lid.extents.across, 2), "across " .. lid.extents.across)
    expect(near(lid.extents.deep, 2), "deep (tied to across) " .. lid.extents.deep)
    expect(near(lid.extents.along, 0.4), "along should keep a disc's 0.2 : 1, got " .. lid.extents.along)
end)

test("'as long as the drum is wide' compares two different extents", function()
    local parts = solve("The drum is a cylinder. The rod is a rod. The rod is twice as long as the drum is wide. The rod is beside the drum.")
    expect(near(parts.rod.extents.along, 2), "rod length " .. parts.rod.extents.along)
end)

test("a part compared with itself in one extent is refused", function()
    local _, text = refusals_of("The drum is a cylinder. The drum is twice as tall as the drum is tall.")
    expect(text:find("compared with itself", 1, true), "got: " .. text)
end)

test("'half as deep as it is wide' measures a part by itself", function()
    local parts = solve("The lens is a plate. The lens faces forward. The lens is half as deep as it is wide.")
    expect(near(parts.lens.extents.deep, 0.5) and near(parts.lens.extents.across, 1), "deep " .. parts.lens.extents.deep)
end)

test("a round part's width measured by its own depth is refused", function()
    local _, text = refusals_of("The drum is a cylinder. The drum is half as deep as it is wide.")
    expect(text:find("always equal", 1, true), "got: " .. text)
end)

test("'on top of' makes faces touch, centred", function()
    local parts = solve("The drum is a cylinder. The lid is a disc. The lid is on top of the drum.")
    local drum_top = parts.drum.centre[2] + parts.drum.extents.along / 2
    local lid_bottom = parts.lid.centre[2] - parts.lid.extents.along / 2
    expect(near(drum_top, lid_bottom), "drum top " .. drum_top .. ", lid bottom " .. lid_bottom)
    expect(near(parts.lid.centre[1], 0) and near(parts.lid.centre[3], 0), "lid is not centred")
end)

test("'aligned with the axis of' puts the middle on the axis line", function()
    local parts = solve([[
The base is a box.
The tube is a cylinder. The tube lies front to back. The tube is beside the base.
The pin is a rod. The pin is on top of the base. The pin is aligned with the axis of the tube.
]])
    local tube, pin = parts.tube, parts.pin
    expect(pin.axis == "z", "pin axis " .. pin.axis)
    expect(near(pin.centre[1], tube.centre[1]) and near(pin.centre[2], tube.centre[2]), "pin is off the tube's axis line")
end)

test("a circle of sizes is refused, naming its lines", function()
    local _, text = refusals_of("The alpha is a box. The beta is a box. The alpha is twice as wide as the beta.\nThe beta is twice as wide as the alpha. The beta is on the alpha.")
    expect(text:find("circle", 1, true) and text:find("1", 1, true) and text:find("2", 1, true), "got: " .. text)
end)

test("two different widths for one part are refused, naming both lines", function()
    local _, text = refusals_of("The alpha is a box.\nThe beta is a box. The beta is twice as wide as the alpha.\nThe beta is half as wide as the alpha. The beta is on the alpha.")
    expect(text:find("lines 2 and 3", 1, true), "got: " .. text)
end)

test("a part never placed is refused, not put somewhere", function()
    local _, text = refusals_of("The alpha is a box. The beta is a box.")
    expect(text:find("'beta' is never placed", 1, true), "got: " .. text)
end)

test("a ring with no hole is refused", function()
    local _, text = refusals_of("The alpha is a ring. The beta is a box. The alpha is as thick as the beta. The alpha is as wide as the beta. The beta is on the alpha.")
    expect(text:find("no hole", 1, true), "got: " .. text)
end)

test("every default used is listed", function()
    local model = reader.read("The alpha is a box.")
    local solved = solver.solve(model)
    expect(#solved.assumptions == 2, "assumptions: " .. #solved.assumptions .. " (size and colour expected)")
end)
-- }}}

-- {{{ the builder
test("each kind's bounds are its extents, in every direction", function()
    for kind in pairs(words.KINDS) do
        for _, direction in ipairs({ "stands upright", "lies left to right", "lies front to back" }) do
            local text = "The alpha is a " .. kind .. ". The alpha " .. direction .. "."
            local model = reader.read(text)
            local solved = solver.solve(model)
            local shape = builder.build(solved, "t")
            local half = solver.half_extents(solved.parts[1])
            for axis = 1, 3 do
                local size = shape.bounds.max[axis] - shape.bounds.min[axis]
                expect(math.abs(size - 2 * half[axis]) < 1e-6 * math.max(1, size) + 1e-9,
                    kind .. " " .. direction .. ": axis " .. axis .. " is " .. size .. ", wanted " .. 2 * half[axis])
            end
            expect(shape.degenerate_count == 0, kind .. ": " .. shape.degenerate_count .. " sliver triangles")
        end
    end
end)

test("convex solids' faces all point outward", function()
    for _, kind in ipairs({ "box", "cylinder", "cone", "sphere" }) do
        local solved = solver.solve(reader.read("The alpha is a " .. kind .. ". The alpha lies left to right."))
        local shape = builder.build(solved, "t")
        local p, n = shape.parts[1].positions, shape.parts[1].normals
        for base = 0, #p - 9, 9 do
            local cx = (p[base + 1] + p[base + 4] + p[base + 7]) / 3
            local cy = (p[base + 2] + p[base + 5] + p[base + 8]) / 3
            local cz = (p[base + 3] + p[base + 6] + p[base + 9]) / 3
            expect(cx * n[base + 1] + cy * n[base + 2] + cz * n[base + 3] > -1e-9, kind .. ": triangle " .. (base / 9 + 1) .. " faces in")
        end
    end
end)
-- }}}

-- {{{ the whole run
test("the same description makes the same file, byte for byte", function()
    local out = {}
    for run = 1, 2 do
        local command = "luajit '" .. project_dir .. "/src/016-describe.lua' '" .. project_dir .. "' '"
            .. project_dir .. "/input/descriptions/drum.txt'"
        local pipe = io.popen(command)
        pipe:read("*a")
        expect(pipe:close(), "describe failed on run " .. run)
        local file = assert(io.open(project_dir .. "/output/described/drum.gltf", "rb"))
        out[run] = file:read("*a")
        file:close()
    end
    expect(out[1] == out[2], "two runs gave different files")
end)

test("every example description is read whole", function()
    for _, name in ipairs({ "drum", "lamp", "crown", "glasses" }) do
        local file = assert(io.open(project_dir .. "/input/descriptions/" .. name .. ".txt"))
        local text = file:read("*a")
        file:close()
        local _, text_of_refusals = refusals_of(text)
        expect(text_of_refusals == "", name .. ": " .. text_of_refusals)
    end
end)
-- }}}

-- {{{ run them
local failed = 0
for _, entry in ipairs(tests) do
    local ok, problem = pcall(entry.body)
    if ok then
        print("pass  " .. entry.name)
    else
        failed = failed + 1
        print("FAIL  " .. entry.name .. "\n      " .. tostring(problem))
    end
end
print(string.format("%d of %d passed", #tests - failed, #tests))
os.exit(failed == 0 and 0 or 1)
-- }}}
