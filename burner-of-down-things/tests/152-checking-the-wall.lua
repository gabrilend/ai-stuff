-- 152-checking-the-wall.lua
--
-- Checks issue 802: a canvas with three mistakes gets three findings in
-- one run, each with a line number and a suggestion; a reference to a
-- missing name is a finding, not a crash; compilation resolves names to
-- numbers once, into flat arrays; absent fields take published defaults;
-- every word and field appears in the generated document, and the
-- committed document is exactly what the table generates.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local wall = require("151-the-wall")
local the_look = require("070-the-look")

-- Three mistakes: a misspelt word, a misspelt field, a category that is
-- not one. Each gets its own finding, all in one run.
local three = table.concat({
    'canvas{ category = "diagarm", width = 400, height = 200 }',
    'surface{ name = "store", points = { {10, 10}, {90, 10}, {90, 50} } }',
    'lnie{ from = {0, 0}, to = {100, 100} }',
    'label{ txet = "hello", text = "hello", at = {5, 5} }',
}, "\n")
local compiled, findings = wall.read(three, nil, "three.lua")
kit.equal(compiled, nil, "a canvas with mistakes does not compile")
kit.equal(#findings, 3, "three mistakes, three findings, in one run")
kit.equal(wall.text(findings[1], "three.lua"),
    "three.lua:1: canvas: 'category' wants a category, got the text 'diagarm'; did you mean 'diagram'?",
    "a wrong value: its line and the nearest legal value")
kit.equal(wall.text(findings[2], "three.lua"),
    "three.lua:3: no word 'lnie' in the png paintbrush; did you mean 'line'?",
    "an unknown word: its line and the nearest legal word")
kit.equal(wall.text(findings[3], "three.lua"),
    "three.lua:4: label: has no field 'txet'; did you mean 'text'?",
    "an unknown field: its line and the nearest legal field")
for i, f in ipairs(findings) do
    kit.check(type(f.line) == "number" and f.suggestion ~= nil, "finding " .. i .. " has a line and a suggestion")
end

-- A dangling reference is a finding, not a crash.
local dangling = table.concat({
    'canvas{ category = "diagram" }',
    'surface{ name = "store", points = { {0, 0}, {10, 0}, {10, 10} } }',
    'arrow{ from = "store", to = "shwo" }',
    'diagram{ boxes = { {name = "a"} }, arrows = { {from = "a", to = "b"} } }',
}, "\n")
local ok, none, dfindings = pcall(wall.read, dangling)
kit.check(ok, "a reference to a missing name does not crash")
kit.equal(none, nil, "and does not compile")
kit.equal(#dfindings, 2, "each dangling reference is its own finding")
kit.equal(dfindings[1].line, 3, "the arrow's finding names its line")
kit.check(dfindings[1].message:find("no surface has that name", 1, true) ~= nil, "it says the name is missing")
kit.equal(dfindings[1].suggestion, "store", "and offers the nearest real name")
kit.check(dfindings[2].message:find("arrow 1's to 'b' is no box", 1, true) ~= nil, "a diagram's arrow to no box is a finding too")

-- Other mistakes, each its own finding.
local function first(text)
    local _, f = wall.read(text)
    return f and f[1] and f[1].message or "(none)"
end
kit.check(first('line{ from = {0, 0}, to = {1, 1} }'):find("needs one canvas", 1, true) ~= nil, "a canvas with no canvas{} is refused")
kit.check(first('canvas{ category = "still" }\ncanvas{ category = "still" }'):find("may appear once", 1, true) ~= nil, "canvas{} twice is refused")
kit.check(first('canvas{ category = "still" }\nline{ from = {0, 0} }'):find("needs its field 'to'", 1, true) ~= nil, "a missing required field is named")
kit.check(first('canvas{ category = "still" }\nsurface{ points = { {0, 0}, {1, 1} } }'):find("three points", 1, true) ~= nil, "a surface of two points is refused")
kit.check(first('canvas{ category = "still" }\nx = 1'):find("may not set 'x'", 1, true) ~= nil, "setting a global is refused")
kit.check(first('canvas{ category = "still" }\nwhile true do end'):find("ran past", 1, true) ~= nil, "a canvas that runs forever is stopped and named")
kit.check(first('canvas{ category = "still" }\nlocal s = ("x"):rep(9)'):find("does not run", 1, true) ~= nil, "a canvas cannot reach the string library")
kit.check(first('canvas{ category = "still" '):find("does not parse", 1, true) ~= nil, "a syntax error is one finding")
kit.check(first(string.dump(function() end)):find("not compiled bytecode", 1, true) ~= nil, "bytecode is refused")
kit.check(first('canvas{ category = "still", look = { grond = "gray" } }'):find("no look field 'grond'", 1, true) ~= nil, "an unknown look field is named")
kit.equal(("x"):rep(3), "xxx", "the string library is back once the canvas has run")

local night_only = the_look.NIGHT_ONLY
night_only.still = true
kit.check(first('canvas{ category = "still", look = { ground = "white" } }'):find("look is refused", 1, true) ~= nil,
    "a day look on a night-only category is a finding (801d)")
night_only.still = nil

-- A good canvas compiles to flat arrays, names resolved once.
local good = table.concat({
    'canvas{ category = "diagram", width = 400, height = 200, seed = 7, look = { ground = "gray" } }',
    'surface{ name = "store", points = { {10, 10}, {90, 10}, {90, 50}, {10, 50} } }',
    'surface{ name = "show", points = { {200, 10}, {280, 10}, {280, 50}, {200, 50} }, flair = "off" }',
    'arrow{ from = "store", to = "show", there = "notes", here = "shown" }',
    'arrow{ from = {0, 0}, to = "store" }',
    'line{ from = {0, 100}, to = {400, 100} }',
    'label{ text = "hello", at = {5, 180} }',
    'grid{}',
    'chart{ kind = "dots", data = {1, 2, 3}, labels = {"a", "b", "c"} }',
}, "\n")
local c, gf = wall.read(good)
kit.check(c ~= nil, "a good canvas compiles: " .. tostring(gf and wall.text(gf[1])))
kit.equal(c.canvas.seed, 7, "the seed is the canvas's named field")
kit.equal(c.look.ground, "gray", "the canvas's look is laid on the defaults")
kit.equal(c.names.store, 1, "a name resolves to a number once")
kit.equal(c.names.show, 2, "each named surface has its own number")
kit.equal(c.arrows.from[1], 1, "an arrow's from is the surface's number")
kit.equal(c.arrows.to[1], 2, "an arrow's to is the surface's number")
kit.equal(c.arrows.x1[1], 50, "an arrow starts at its surface's middle, across")
kit.equal(c.arrows.y1[1], 30, "and down")
kit.equal(c.arrows.from[2], 0, "a point end has no surface number")
kit.equal(c.surfaces.first[2], 5, "surfaces' points are one flat array, each surface its first index")
kit.equal(c.surfaces.count[2], 4, "and its count")
kit.equal(#c.xs, 8, "every corner in xs")
kit.equal(c.surfaces.flair[1], "on", "an absent flair takes the look's")
kit.equal(c.surfaces.flair[2], "off", "a given flair is kept")
kit.equal(c.lines.weight[1], the_look.defaults().line_weight, "an absent weight takes the look's line_weight")
kit.equal(c.labels.size[1], 16, "an absent size takes its published default")
kit.equal(c.grids.step[1], 40, "a grid's step defaults to 40")
kit.equal(c.charts.w[1], 400, "a chart with no size fills the canvas")
kit.equal(#c.order, 8, "every drawn word is in the order list")
kit.equal(c.order[1][1], "surface", "in canvas order")

-- The generated document.
local doc = wall.document()
for name, spec in pairs(wall.PNG.words) do
    kit.check(doc:find("## `" .. name .. "{ … }`", 1, true) ~= nil, "the document has the word " .. name)
    for field in pairs(spec.fields) do
        kit.check(doc:find("| `" .. field .. "` |", 1, true) ~= nil, "the document has " .. name .. "'s field " .. field)
    end
    local listed = 0
    for _ in pairs(spec.fields) do listed = listed + 1 end
    kit.equal(#spec.order, listed, name .. "'s order names every field once")
end
local committed = kit.fs.read(kit.DIR .. "/docs/paintbrush-png.md")
kit.equal(committed, doc, "the committed docs/paintbrush-png.md is exactly what the table generates")

kit.finish()
