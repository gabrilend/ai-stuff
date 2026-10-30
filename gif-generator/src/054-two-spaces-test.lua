-- 054-two-spaces-test.lua - checks one canvas, two spaces keeps its
-- promises (issue 701d).
--
-- What this is, generally: a score may now speak both vocabularies, with
-- 2D strokes painted onto panes of glass among 3D shapes. This asks:
--   * does a score with only strokes render the very bytes it rendered
--     before panes existed?
--   * does a score with only shapes (each approved film, said as a score)
--     render the very bytes of the approved film?
--   * does the composer give a pane of light exactly the 2D painter's
--     pixels, and hide a world pane behind a nearer shape and nowhere else?
--   * does a score with a dozen mistakes across both spaces hear about all
--     of them at once?
--   * does a mixed score film the same bytes twice, and survive being
--     written out and read back?
--   * does the phase 7 demo's score pass the wall, and are its halves
--     honest: the shapes' half the score without its strokes and panes,
--     both halves the score as it always films?
--
-- Usage: luajit src/054-two-spaces-test.lua DIR   (DIR = the gif-generator project)
-- Prints one line per check; exits 1 if any failed.

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/gif-generator"
package.path = DIR .. "/src/?.lua;" .. package.path
local ffi = require("ffi")
local canvas = require("000-canvas")
local palette = require("002-palette")
local score = require("022-score")
local compile = require("024-compile")
local main = require("026-render-main")
local scene_file = require("045-scene-file")
local frame = require("052-frame")
local SCRATCH = "/dev/shm/gif-generator/two-spaces-test"
os.execute(string.format("mkdir -p %q", SCRATCH))

local passed, failed = 0, 0
-- {{{ local function check()
local function check(label, ok)
    if ok then
        passed = passed + 1
        print("  ok   - " .. label)
    else
        failed = failed + 1
        print("  FAIL - " .. label)
    end
end
-- }}}

-- {{{ local function sha256()
-- The fingerprint of some bytes, by way of a file in RAM.
local function sha256(bytes, name)
    local path = SCRATCH .. "/" .. name
    local handle = assert(io.open(path, "wb"))
    handle:write(bytes)
    handle:close()
    local pipe = io.popen(string.format("sha256sum %q", path))
    local sum = pipe:read("*l"):match("^(%x+)")
    pipe:close()
    return sum
end
-- }}}

-- {{{ local function film()
-- A score file to GIF bytes, through the runner's own spine.
local function film(path)
    return (main.render_to_gif(compile.score(score.read(path))))
end
local function film_compiled(compiled)
    return (main.render_to_gif(compiled))
end
-- }}}

-- {{{ local function as_score()
-- A shape scene said as a score: its size, length and pace in canvas{},
-- its camera in camera{}, each shape a shape{}, the rest of it in
-- world{}, and its stars as the background sky. Written out with the
-- canonical writer, so the reading is the one any score gets.
local SAID_IN_CANVAS = { name = true, size = true, frames = true, delay_cs = true,
                         jobs = true, camera = true, instances = true }
local function as_score(scene)
    local raw = {
        canvas = { size = scene.size, fps = 100 / (scene.delay_cs or 4),
                   frames = scene.frames, seed = 1 },
        camera = scene.camera, shapes = scene.instances, panes = {}, strokes = {},
    }
    local world = {}
    for k, v in pairs(scene) do
        if not SAID_IN_CANVAS[k] then world[k] = v end
    end
    if next(world) then raw.world = world end
    if world.stars then raw.canvas.background = "sky" end
    return score.write(raw)
end
-- }}}

-- Strokes alone: the bytes they made before panes existed.
local stroke_prints = dofile(DIR .. "/tests/two-spaces/stroke-fingerprints.lua")
for _, name in ipairs({ "orbit", "showpiece", "two-clocks", "two-clocks-512" }) do
    local path = DIR .. "/input/" .. name .. ".lua"
    check("a score of strokes alone compiles as it always has (" .. name .. ")",
          compile.score(score.read(path)).studio == nil)
    check("and films the very bytes it filmed before panes (" .. name .. ")",
          sha256(film(path), name .. ".gif") == stroke_prints[name])
end

-- Shapes alone: each approved film, said as a score, is the approved film.
local approved = dofile(DIR .. "/tests/shape-films/approved-films.lua")
local names = {}
for name in pairs(approved) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
    local path = SCRATCH .. "/" .. name .. ".score.lua"
    local handle = assert(io.open(path, "w"))
    handle:write(as_score(scene_file.read(DIR .. "/input/shapes/" .. name .. ".lua")))
    handle:close()
    check("the approved film " .. name .. ", said as a score, films its approved bytes",
          sha256(film(path), name .. ".gif") == approved[name])
end

-- The composer: a pane of light alone is the 2D painter's own picture.
do
    local size = 24
    local cv = canvas.new(size, size)
    local seed = 12345
    for i = 0, size * size * 3 - 1 do
        seed = (seed * 1103515245 + 12345) % 2147483648
        cv.energy[i] = (seed % 1000) / 200
    end
    local pal = palette.build({ "rose", "gold", "teal" })
    local function index_of(r, g, b) return palette.index_of(pal, r, g, b) end
    local front = ffi.new("float[?]", size * size * 3)
    ffi.copy(front, cv.energy, size * size * 3 * 4)
    local mapped = canvas.tonemap(cv)
    local tm = canvas.new(size, size)
    local out = ffi.new("uint8_t[?]", size * size)
    frame.compose{ front = front, tm = tm, tonemap = canvas.tonemap, out = out, index_of = index_of }
    local same = true
    for p = 0, size * size - 1 do
        local i = p * 3
        if out[p] ~= index_of(mapped[i], mapped[i + 1], mapped[i + 2]) then same = false end
    end
    check("a front pane's light alone is composed into the 2D painter's own pixels", same)
end

-- A pane in the world: hidden behind a nearer shape, shining over a farther
-- one, and gathered where nothing is drawn.
do
    local raster = dofile(DIR .. "/src/036-raster.lua")
    local meshes = dofile(DIR .. "/src/034-meshes.lua")
    local rc = raster.new(16, { distance = 7, fov = 45 }, meshes)
    raster.clear(rc)
    local pane = { at = { 0, 0, 0 }, facing = { 0, 0, 1 }, size = { 2, 2 }, cv = canvas.new(8, 8) }
    for i = 0, 8 * 8 * 3 - 1 do pane.cv.energy[i] = 1 end
    local W = rc.W
    local middle = (W / 2) * W + W / 2
    local gathered = ffi.new("float[?]", W * W * 3)
    frame.gather_pane(rc, raster, gathered, pane)
    check("a world pane's light is gathered where nothing is drawn", gathered[middle * 3] == 1)
    check("and nowhere outside the pane's edges", gathered[0] == 0)

    ffi.fill(gathered, W * W * 3 * 4)
    rc.depth[middle] = 1 / 5 -- a surface 5 from the lens, in front of the pane at 7
    frame.gather_pane(rc, raster, gathered, pane)
    check("a shape in front of a world pane hides the pane's light", gathered[middle * 3] == 0)

    ffi.fill(gathered, W * W * 3 * 4)
    rc.depth[middle] = 1 / 9 -- a surface 9 from the lens, behind the pane
    frame.gather_pane(rc, raster, gathered, pane)
    check("a shape behind a world pane shows through, brightened by the pane", gathered[middle * 3] == 1)
end

-- The wall: a dozen mistakes across both spaces, all at once.
local BROKEN = {
    "canvas: no background named 'skye' — say \"black\", \"sky\" (the world's stars) or a hue; nearest legal: sky",
    "pane 'sign' (#1): a pane in the world needs facing = { x, y, z }, the way its front looks",
    "pane 'backdrop' (#2): a pane at the camera covers the whole frame; `pixels` belongs to a pane in the world",
    "pane 'front' (#3): \"front\" is the pane a stroke with no pane is painted on; give this one its own name",
    "stroke 'circle' (#1): no pane named 'sing' — nearest legal: sign",
    "stroke 'spark' (#2): point.at borrows tip(\"wanderr\") but no stroke or shape bears that name — nearest: wanderer",
    "stroke 'glint' (#3): point.at follows the shape 'wanderer', but only a pane at the camera sees where a shape appears",
    "stroke 'veil' (#4): fill vertex 2 follows the shape 'wanderer', but a fill's corners must stand still",
    "world: no word 'starz' in a world — nearest legal: stars",
    "camera: no word 'fvo' in a camera -- nearest legal: fov",
    "shape #1 (wanderer).hue: no hue 'violt' -- nearest legal: violet",
    "shape #1 (wanderer).motion.cycles: must be a whole number, or the loop has a seam",
}
local refused, refusal = pcall(compile.score, score.read(DIR .. "/tests/two-spaces/broken.lua"))
refusal = tostring(refusal)
check("the broken two-space score is refused", not refused)
check(string.format("with all %d mistakes, from both spaces, in one refusal", #BROKEN),
      refusal:match("%((%d+) errors%)") == tostring(#BROKEN))
local said = {}
for line in refusal:gmatch("\n  ([^\n]+)") do said[line] = true end
for _, line in ipairs(BROKEN) do
    check("the wall says: " .. line, said[line] == true)
end

-- A mixed score: films, films the same twice, and survives the writer.
do
    local path = DIR .. "/tests/two-spaces/mixed.lua"
    local compiled = compile.score(score.read(path))
    check("the mixed score has a world, three panes and a shape to follow",
          compiled.studio ~= nil and compiled.studio.world ~= nil and #compiled.studio.panes == 3
          and compiled.studio.landmarks.wanderer ~= nil)
    local first = film(path)
    check("the mixed score films", #first > 0 and first:sub(1, 6) == "GIF89a")
    check("the mixed score films the same bytes twice", film(path) == first)
    local written = score.write(score.read(path))
    local copy = SCRATCH .. "/mixed-written.lua"
    local handle = assert(io.open(copy, "w"))
    handle:write(written)
    handle:close()
    check("written out and read back, it writes the same text", score.write(score.read(copy)) == written)
    check("and films the same bytes", film(copy) == first)
end

-- The phase 7 demo's score, and its halves (issue 701g): the shapes' half
-- is the score with its strokes and panes taken away, and both halves
-- together are the score as any score films.
do
    local two_spaces = require("053-two-spaces")
    local gif = require("004-gif")
    local path = DIR .. "/issues/completed/demos/phase-7/meeting.lua"
    local ok, compiled = pcall(compile.score, score.read(path))
    check("the phase 7 demo's score passes the wall", ok)
    if ok then
        local function encode(c, frames)
            return gif.encode{ width = c.canvas.size, height = c.canvas.size,
                               palette_bytes = c.pal.bytes, frames = frames,
                               delay_cs = math.floor(100 / c.canvas.fps) }
        end
        local shapes_half = encode(compiled, (two_spaces.render(compile.score(score.read(path)), "world")))
        local raw = score.read(path)
        raw.strokes, raw.panes = {}, {}
        check("its shapes' half films the score with its strokes and panes taken away",
              shapes_half == film_compiled(compile.score(raw)))
        local light_half = encode(compiled, (two_spaces.render(compile.score(score.read(path)), "light")))
        check("its light's half films, and differs from the whole",
              light_half:sub(1, 6) == "GIF89a" and light_half ~= film_compiled(compile.score(score.read(path))))
        check("both halves together are the score as it always films",
              encode(compiled, (two_spaces.render(compiled))) == film(path))
    end
end

os.execute(string.format("rm -r %q", SCRATCH))
print("")
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
