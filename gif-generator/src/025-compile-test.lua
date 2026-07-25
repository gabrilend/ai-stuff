-- 025-compile-test.lua — proof for the compiler and its wall.
--
-- What this is, generally: compiles both reference scores, then
-- throws every kind of malformed score at the wall and checks each
-- refusal names the right stroke, teaches the nearest legal word,
-- and that multiple mistakes arrive TOGETHER, not one per attempt.
-- Run: luajit src/025-compile-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local score = require("022-score")
local compile = require("024-compile")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name)
    end
end
-- }}}

-- {{{ local function good_canvas()
local function good_canvas()
    return { size = 64, fps = 25, length = 4.0, seed = 1 }
end
-- }}}

-- {{{ local function good_stroke()
local function good_stroke(extra)
    local s = { at = 0.0, lasts = 1.0, color = "ember", fade = "hold",
                shape = { kind = "point", at = {10, 10} } }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end
-- }}}

-- {{{ local function wall_says()
-- compile a raw score, expect refusal, return the message
local function wall_says(raw)
    local ok, err = pcall(compile.score, raw)
    if ok then return nil end
    return err
end
-- }}}

-- both reference scores compile
local orbit = compile.score(score.read(DIR .. "/input/orbit.lua"))
check("the orbit reference compiles", #orbit.timeline.tracks == 1)
local clocks = compile.score(score.read(DIR .. "/input/two-clocks.lua"))
check("the vision translation compiles to its six tracks",
      #clocks.timeline.tracks == 6)
check("hues seat in order of first use",
      clocks.hues[1] == "ember" and clocks.hues[2] == "violet")
check("the pool capacity is sized from the compiled demands",
      clocks.capacity > 500)

-- the wall names the stroke and teaches the nearest word
local msg = wall_says({ canvas = good_canvas(), strokes = {
    good_stroke({ name = "hand", color = "ebmer" }) } })
check("a misspelled hue is refused", msg ~= nil)
check("the refusal names the stroke",
      msg:find("stroke 'hand'", 1, true) ~= nil)
check("the refusal teaches ember",
      msg:find("nearest legal: ember", 1, true) ~= nil)

msg = wall_says({ canvas = good_canvas(), strokes = {
    good_stroke({ ease = "strok" }) } })
check("a misspelled easing is taught its word",
      msg ~= nil and msg:find("nearest legal: stroke", 1, true) ~= nil)

msg = wall_says({ canvas = good_canvas(), strokes = {
    good_stroke({ emit = { rte = 100 } }) } })
check("a misspelled emit field is taught its word",
      msg ~= nil and msg:find("nearest legal: rate", 1, true) ~= nil)

-- time discipline: tenths only, inside the canvas
msg = wall_says({ canvas = good_canvas(), strokes = {
    good_stroke({ at = 0.25 }) } })
check("two decimal places are refused",
      msg ~= nil and msg:find("tenths", 1, true) ~= nil)
msg = wall_says({ canvas = good_canvas(), strokes = {
    good_stroke({ at = 3.5, lasts = 1.0 }) } })
check("running past the canvas's end is refused",
      msg ~= nil and msg:find("canvas ends", 1, true) ~= nil)
msg = wall_says({ canvas = { size = 64, fps = 30, length = 4.0,
                             seed = 1 }, strokes = { good_stroke() } })
check("thirty frames a second is refused with its reason",
      msg ~= nil and msg:find("hundredths", 1, true) ~= nil)

-- shape discipline
msg = wall_says({ canvas = good_canvas(), strokes = {
    good_stroke({ shape = { kind = "arc", center = {10, 10},
                            radius = 5, from = 12, to = 7 } }) } })
check("a turnless arc is refused",
      msg ~= nil and msg:find("clockwise", 1, true) ~= nil)

-- landmark discipline: absent names, tipless fills, circles
msg = wall_says({ canvas = good_canvas(), strokes = {
    good_stroke({ shape = { kind = "point",
                            at = { ref = "tip", of = "ghost" } } }) } })
check("borrowing a tip from nobody is refused",
      msg ~= nil and msg:find("no stroke bears that name", 1, true) ~= nil)

msg = wall_says({ canvas = good_canvas(), strokes = {
    good_stroke({ name = "pool", shape = { kind = "fill",
        vertices = { {0, 0}, {10, 0}, {5, 8} }, sweep = "downward" } }),
    good_stroke({ shape = { kind = "point",
                            at = { ref = "tip", of = "pool" } } }) } })
check("borrowing a tip from a fill is refused",
      msg ~= nil and msg:find("no tip to borrow", 1, true) ~= nil)

msg = wall_says({ canvas = good_canvas(), strokes = {
    good_stroke({ name = "ouro", shape = { kind = "line",
        from = { ref = "tip", of = "ouro" }, to = {10, 10} } }) } })
check("a stroke borrowing its own tail is refused",
      msg ~= nil and msg:find("solid ground", 1, true) ~= nil)

-- duplicate names are refused before anyone borrows wrongly
msg = wall_says({ canvas = good_canvas(), strokes = {
    good_stroke({ name = "twin" }), good_stroke({ name = "twin" }) } })
check("duplicate names are refused",
      msg ~= nil and msg:find("already taken", 1, true) ~= nil)

-- and the point of the wall: mistakes arrive together
msg = wall_says({ canvas = good_canvas(), strokes = {
    good_stroke({ color = "ebmer", fade = "fade", at = 0.33 }) } })
check("three mistakes arrive as three, together",
      msg ~= nil and msg:find("3 errors", 1, true) ~= nil)

-- forward borrowing is legal: geometry, not history
local forward = compile.score({ canvas = good_canvas(), strokes = {
    good_stroke({ shape = { kind = "point",
                            at = { ref = "tip", of = "later" } } }),
    good_stroke({ name = "later", at = 2.0, lasts = 1.0,
                  shape = { kind = "arc", center = {32, 32},
                            radius = 10, from = 12, to = 6,
                            turn = "clockwise" } }) } })
check("borrowing forward in time compiles (geometry, not history)",
      #forward.timeline.tracks == 2)

print(string.format("compile: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
