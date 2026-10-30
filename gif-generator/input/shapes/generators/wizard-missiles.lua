-- wizard-missiles: the same wizard summons magic missiles -- purple darts
-- that leave the wand's star one after another, swing wide on paths of their
-- own like fish in a shoal, and converge on a target, which flares and swells
-- as they strike. Each dart trails a short wake of sparks.
--
-- Each dart's flight is a curve worked out in advance (the `bezier` motion):
-- start at the wand, two pulls that bend it out to one side and then back in,
-- end at the target. Why not steer each dart frame by frame toward the target,
-- with momentum? Because a steered flight depends on every frame before it,
-- and the film is a loop: the dart at the last frame must be exactly where it
-- was at the first, which a step-by-step steering never guarantees. A curve
-- fixed ahead of time is the same at the loop's end as at its start by
-- construction, and respawning at the wand each cycle is then invisible (the
-- dart grows out of nothing there). Whether that trade -- loop-exact curves
-- rather than true momentum -- is the right one is an open question for the
-- owner (issue 060).
local here = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local wizard_parts = dofile(here .. "parts/wizard.lua")

local GROUND = { size = 10, grid = 22, base = -1.0, waves = { { 0.05, 0.9, 0.6, 0 }, { 0.04, -0.5, 1.2, 0.7 } } }
local WIZARD_AT = { -1.9, 0, 0.2 }
local ground_y = -1.0
-- Each dart leaves the wand's star from wherever it is at the dart's launch
-- (`{ part = "wand-star" }`), and its first pull is measured from there too,
-- so every flight bends away from the tip as the wand actually stood. (The
-- first cut launched from one fixed spot; see wizard-rings.lua for the
-- owner's words.)
local TIP = { part = "wand-star" }
local TARGET = { 2.5, ground_y + 1.3, 0.0 }

local instances = {
    { tag = "meadow", mesh = "terrain", hue = "violet", dim = 0.26, style = "solid", mesh_params = GROUND },
    { tag = "wizard", motion = { kind = "fixed", at = WIZARD_AT, on_ground = true },
      -- the wand moves as slowly as wizard-beam's: two gestures a loop (the owner:
      -- "should move their wands slowly, like the wizard-beam")
      parts = wizard_parts({ robe = "rose", hat = "violet", cast_cycles = 2 }) },
    { tag = "pedestal", mesh = "cone", hue = "ice", dim = 0.5, style = "glow", stretch = { 0.35, 0.7, 0.35 },
      mesh_params = { segments = 8 }, motion = { kind = "fixed", at = { TARGET[1], 0.55, TARGET[3] }, on_ground = true } },
    { tag = "target", mesh = "icosahedron", hue = "gold", scale = 0.3, style = "glow",
      motion = { kind = "fixed", at = TARGET }, spin = { axis = { 0.3, 1, 0 }, turns = 1 },
      reacts = { { to = "dart", within = 0.7, effect = "glow", amount = 1.0 },
                 { to = "dart", within = 0.7, effect = "swell", amount = 0.4 } } },
}
-- seven darts, each launched a seventh of a flight after the last, each
-- swinging out on its own side before homing in
local darts = 7
for k = 0, darts - 1 do
    local a = k * 2 * math.pi / darts
    instances[#instances + 1] = {
        tag = "dart", mesh = "octahedron", hue = "violet", scale = 0.19, stretch = { 1.8, 0.32, 0.32 },
        style = "glow", face_motion = true,
        motion = { kind = "bezier", cycles = 2, phase = k / darts,
                   points = { TIP,
                              { part = "wand-star", plus = { 0.9, 1.3 * math.sin(a) + 0.4, 1.6 * math.cos(a) } },
                              { TARGET[1] - 1.3, TARGET[2] + 0.9 * math.sin(a + 1.3), TARGET[3] + 1.3 * math.cos(a + 1.3) },
                              TARGET } },
        trail = { count = 5, spacing = 0.006, shrink = 0.78, mesh = "octahedron", hues = { "violet", "rose" },
                  full_speed = 4 },
    }
end
return {
    name = "wizard-missiles",
    size = 320, frames = 150, delay_cs = 4,
    ground = GROUND,
    camera = { fov = 50,
               motion = { kind = "dolly", from = { -0.4, 2.0, 7.0 }, to = { 0.7, 1.3, 7.4 }, cycles = 1,
                          target = { 0.2, 0.45, 0 } } },
    framing = { tag = "wizard", at_least = 6 },
    stars = { count = 120, seed = 271, hues = { "violet", "rose", "gold" } },
    instances = instances,
}
