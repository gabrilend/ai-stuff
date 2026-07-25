-- 019-tracks-test.lua — proof for tracks and the timeline.
--
-- What this is, generally: exact window edges, eased waypoints
-- checked against hand arithmetic, envelopes gating emission, and
-- two tracks handing off at a shared instant with neither gap nor
-- overlap. Run: luajit src/019-tracks-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local pool = require("006-pool")
local emit = require("008-emit")
local paths = require("014-paths")
local easing = require("016-easing")
local tracks = require("018-tracks")

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

local DT = 0.04

-- {{{ local function hand_track()
-- The vision's left hand: 12 to 7 clockwise over 2 seconds, stroke
-- easing, held envelope (envelope shapes get their own checks).
local function hand_track(envelope_name)
    return tracks.track{
        name = "left-hand", from = 1.0, lasts = 2.0,
        ease = easing.motion("stroke"),
        envelope = easing.envelope(envelope_name or "hold"),
        path = paths.arc{ center = {100, 100}, radius = 60,
                          from = 12, to = 7, turn = "clockwise" },
        recipe = emit.recipe({ rate = 250 }, 0),
    }
end
-- }}}

-- window edges are exact: alive at its first instant, gone at
-- exactly start plus duration
local tr = hand_track()
check("silent before its time", tracks.where(tr, 0.99) == nil)
check("alive at its first instant", tracks.where(tr, 1.0) ~= nil)
check("alive just inside the end", tracks.where(tr, 2.9999) ~= nil)
check("gone at exactly start plus duration",
      tracks.where(tr, 3.0) == nil)

-- eased waypoints match hand arithmetic: at the window's half, the
-- stroke easing has covered 0.5^2.6 of the arc's 210 degrees
local x, y = tracks.where(tr, 2.0)
local progress = 0.5 ^ 2.6
local sweep = (paths.clock_angle(7) - paths.clock_angle(12)) % (2 * math.pi)
local a = paths.clock_angle(12) + sweep * progress
check("halfway through its window, the stroke has crept "
      .. "its eased fraction of the arc",
      math.abs(x - (100 + math.cos(a) * 60)) < 1e-6
      and math.abs(y - (100 + math.sin(a) * 60)) < 1e-6)

-- the endpoint landmark is the path's end, exactly
local ex, ey = tracks.endpoint(tr)
local a7 = paths.clock_angle(7)
check("the endpoint landmark is where the journey ends",
      math.abs(ex - (100 + math.cos(a7) * 60)) < 1e-9
      and math.abs(ey - (100 + math.sin(a7) * 60)) < 1e-9)

-- envelopes gate emission: a fade-in track births less in its first
-- quarter than a held one, and nothing when silent
-- {{{ local function births_by()
local function births_by(envelope_name, upto_t)
    local p = pool.new(2048)
    local rng = emit.rng(5)
    local tr2 = hand_track(envelope_name)
    -- immortal here too: the live count must mean the birth count
    tr2.recipe = emit.recipe({ rate = 250, life = 99, life_jitter = 0 }, 0)
    local tl = tracks.timeline({ tr2 }, 0, 0)
    local t = 0
    while t < upto_t do
        tracks.step(tl, p, rng, t, DT)
        t = t + DT
    end
    return p.live
end
-- }}}
local held = births_by("hold", 1.5)
local eased_in = births_by("in", 1.5)
check("a fade-in track whispers where a held one speaks",
      eased_in < held and eased_in > 0)
check("before any window opens, the world is empty",
      births_by("hold", 0.99) == 0)

-- two windows meeting at one number hand off with neither gap nor
-- doubled tick: births at the shared instant belong to the second
-- counting births by the live count only works if nobody dies
-- during the run — the default lifetime is shorter than these two
-- windows, and this test's first draft forgot its own physics
local immortal = { rate = 25, life = 99, life_jitter = 0 }
local first = tracks.track{
    name = "first", from = 0.0, lasts = 1.0,
    ease = easing.motion("linear"), envelope = easing.envelope("hold"),
    path = paths.point{ at = {10, 10} },
    recipe = emit.recipe(immortal, 0),
}
local second = tracks.track{
    name = "second", from = 1.0, lasts = 1.0,
    ease = easing.motion("linear"), envelope = easing.envelope("hold"),
    path = paths.point{ at = {10, 10} },
    recipe = emit.recipe(immortal, 0),
}
-- rate 25 at dt 0.04 births exactly 1 per active tick, so counting
-- ticks IS counting births: 50 ticks of window, 50 particles
local p2 = pool.new(256)
local rng2 = emit.rng(6)
local tl2 = tracks.timeline({ first, second }, 0, 0)
for i = 0, 49 do
    tracks.step(tl2, p2, rng2, i * DT, DT)
end
check("two meeting windows hand off without gap or double",
      p2.live == 50)

-- a zero-length stroke is refused at the door
check("a stroke that takes no time is refused",
      not pcall(tracks.track, { name = "instant", from = 0, lasts = 0,
                                ease = easing.motion("linear"),
                                envelope = easing.envelope("hold"),
                                path = paths.point{ at = {0, 0} },
                                recipe = emit.recipe({}, 0) }))

print(string.format("tracks: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
