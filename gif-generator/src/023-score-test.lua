-- 023-score-test.lua — proof for the score reader, insertion, and
-- canonical writer.
--
-- What this is, generally: reads a real score from input/, refuses
-- structural nonsense, shuffles strokes through the walk-back
-- insertion, and round-trips the writer — write, read what was
-- written, write again, byte-identical. Run:
-- luajit src/023-score-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local score = require("022-score")

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

-- {{{ local function scratch_write()
-- test scores land in RAM scratch, never in the project
local function scratch_write(name, text)
    local path = "/dev/shm/gif-generator/" .. name
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
    return path
end
-- }}}

-- the shipped reference score reads: canvas named, strokes present,
-- shapes tagged by their constructors
local orbit = score.read(DIR .. "/input/orbit.lua")
check("the orbit reference reads", orbit.canvas ~= nil)
check("the orbit reference has its stroke", #orbit.strokes == 1)
check("constructors tag their shapes",
      orbit.strokes[1].shape.kind == "arc")

-- the vision translation reads too, landmarks intact
local clocks = score.read(DIR .. "/input/two-clocks.lua")
check("the vision translation reads", #clocks.strokes == 6)
local line_stroke
for _, s in ipairs(clocks.strokes) do
    if s.name == "seal-line" then line_stroke = s end
end
check("tip landmarks survive reading",
      line_stroke ~= nil
      and line_stroke.shape.vertices[1].ref == "tip"
      and line_stroke.shape.vertices[1].of == "left-hand")

-- structural walls: no canvas, two canvases, no strokes, computing
check("a score with no canvas is refused",
      not pcall(score.read, scratch_write("no-canvas.lua",
          'stroke{ at = 0, lasts = 1 }')))
check("a score with two canvases is refused",
      not pcall(score.read, scratch_write("two-canvas.lua",
          'canvas{ size = 64, fps = 25, length = 1, seed = 1 }\n'
          .. 'canvas{ size = 64, fps = 25, length = 1, seed = 1 }\n'
          .. 'stroke{ at = 0, lasts = 1 }')))
check("a score with no strokes is refused",
      not pcall(score.read, scratch_write("no-strokes.lua",
          'canvas{ size = 64, fps = 25, length = 1, seed = 1 }')))
check("a score that computes is refused",
      not pcall(score.read, scratch_write("computes.lua",
          'canvas{ size = 64, fps = 25, length = 1, seed = 1 }\n'
          .. 'stroke{ at = os.time(), lasts = 1 }')))

-- the walk-back insertion: shuffled times sort; equal times keep
-- arrival order (stability is a determinism promise, not taste)
local list = {}
score.insert(list, { at = 2.0, tag = "c" })
score.insert(list, { at = 0.0, tag = "a" })
score.insert(list, { at = 1.0, tag = "b" })
score.insert(list, { at = 1.0, tag = "b2" })
score.insert(list, { at = 0.0, tag = "a2" })
local order = {}
for _, s in ipairs(list) do order[#order + 1] = s.tag end
check("shuffled strokes sort by time",
      table.concat(order, ",") == "a,a2,b,b2,c")

-- the canonical writer: write, read back, write again — identical
local text_one = score.write(clocks)
local reread = score.read(scratch_write("rewritten.lua", text_one))
local text_two = score.write(reread)
check("the canonical text is a fixed point (write, read, write)",
      text_one == text_two)
check("comments would ride above strokes",
      score.write({ canvas = clocks.canvas,
                    strokes = { { at = 0, lasts = 1, color = "ember",
                                  fade = "hold",
                                  shape = { kind = "point", at = {1, 2} },
                                  comment = "a sentence of prose" } } })
           :find("-- a sentence of prose", 1, true) ~= nil)

print(string.format("score: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
