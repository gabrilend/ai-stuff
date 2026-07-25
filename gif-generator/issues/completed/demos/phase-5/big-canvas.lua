-- big-canvas.lua — the phase-5 demo: the determinism promise
-- performed in public, at scale, with the speedup measured that
-- run and never remembered.
--
-- What this is, generally: renders the doubled vision twice — one
-- worker, then a crew — asserts the two files are byte-identical
-- right here where everyone can watch, and prints the wall-clock
-- speedup. Then the forge showpiece renders with the crew and joins
-- the gallery. All numbers come from the one measurer.

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local gif = require("004-gif")
local score = require("022-score")
local compile = require("024-compile")
local parallel = require("028-parallel")
local stats = require("030-stats")

local CREW = 4

-- {{{ local function land()
local function land(name, bytes)
    local here = DIR .. "/issues/completed/demos/phase-5/"
                 .. name .. ".gif"
    local f = assert(io.open(here, "wb"))
    f:write(bytes)
    f:close()
    local out = assert(io.open(DIR .. "/output/" .. name .. ".gif",
                               "wb"))
    out:write(bytes)
    out:close()
    return here
end
-- }}}

print("— the doubled vision, one hand —")
local t0 = stats.wall()
local one = parallel.render_to_gif(
    compile.score(score.read(DIR .. "/input/two-clocks-512.lua")),
    DIR, 1)
local one_wall = stats.wall() - t0

print(string.format("  one worker: %.2f s wall", one_wall))

print("— the doubled vision, " .. CREW .. " hands —")
local t1 = stats.wall()
local crew, facts = parallel.render_to_gif(
    compile.score(score.read(DIR .. "/input/two-clocks-512.lua")),
    DIR, CREW)
local crew_wall = stats.wall() - t1
print(string.format("  %d workers: %.2f s wall", CREW, crew_wall))

-- the promise, performed: same scene, same seed, same bytes,
-- no matter how many hands drew it
if one == crew then
    print(string.format(
        "  byte-identical: %d bytes both ways. speedup: %.2fx",
        #crew, one_wall / crew_wall))
else
    print("  IDENTITY BROKEN: worker count changed the picture.")
    print("  Nothing else this demo shows can be trusted; fix this.")
    os.exit(1)
end
land("two-clocks-512", crew)
print(string.format("  peak particles: %d, frames: %d",
                    facts.peak, facts.frames))

print("— the forge, " .. CREW .. " hands —")
local t2 = stats.wall()
local forge, forge_facts = parallel.render_to_gif(
    compile.score(score.read(DIR .. "/input/showpiece.lua")),
    DIR, CREW)
local forge_wall = stats.wall() - t2
local forge_home = land("showpiece", forge)
print(string.format(
    "  %d frames, %d bytes, peak %d particles, %.2f s wall",
    forge_facts.frames, #forge, forge_facts.peak, forge_wall))
print("  written to: " .. forge_home)
