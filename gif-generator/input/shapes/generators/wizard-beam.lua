-- wizard-beam: the wizard holds a spell on a floating crystal -- three
-- strands of light that bend, curl and writhe round each other, always
-- joined at one end to the star on the wand's tip and at the other to the
-- crystal, however the wand lifts and falls and however the crystal drifts.
-- The owner's words: "a wizard casting a line that bends and curves and
-- always is connected to the tip of the wand (even as it's moving) and the
-- target." The beam is worked out afresh every frame from where the two
-- ends are (choreography.beams), which is what keeps it attached.
local here = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local wizard_parts = dofile(here .. "parts/wizard.lua")

local GROUND = { size = 10, grid = 22, base = -1.0, waves = { { 0.05, 0.9, 0.6, 0 }, { 0.04, -0.5, 1.2, 0.7 } } }
local WIZARD_AT = { -1.9, 0, 0.2 }
local TARGET = { 2.3, 0.5, 0.0 }

local instances = {
    { tag = "meadow", mesh = "terrain", hue = "jade", dim = 0.26, style = "solid", mesh_params = GROUND },
    { tag = "wizard", motion = { kind = "fixed", at = WIZARD_AT, on_ground = true },
      parts = wizard_parts({ robe = "teal", hat = "violet", cast_cycles = 2 }) },
    -- the crystal drifts on a small slow loop, so the beam has to follow it
    { tag = "crystal", mesh = "icosahedron", hue = "ice", scale = 0.32, style = "glow",
      motion = { kind = "lissajous", center = TARGET, size = { 0.35, 0.3, 0.45 }, freq = { 1, 2, 1 } },
      spin = { axis = { 0.3, 1, 0 }, turns = 2 }, pulse = { amount = 0.12, cycles = 6 } },
    { tag = "crystal-glow", mesh = "star_prism", hue = "gold", scale = 0.14, style = "glow",
      motion = { kind = "lissajous", center = TARGET, size = { 0.35, 0.3, 0.45 }, freq = { 1, 2, 1 },
                 offset = { 0, 0.5, 0 } },
      spin = { axis = { 0, 1, 0 }, turns = -3 } },
}
return {
    name = "wizard-beam",
    size = 320, frames = 150, delay_cs = 4,
    ground = GROUND,
    beams = { { from = "wand-star", to = "crystal", amplitude = 0.38, waves = 2.5, writhe = 4, strands = 3,
                hues = { "violet", "rose", "ice" }, segments = 56 } },
    camera = { fov = 48,
               motion = { kind = "dolly", from = { 0.5, 1.3, 7.0 }, to = { -0.5, 1.0, 6.5 }, cycles = 1,
                          target = { 0.1, 0.35, 0 } } },
    framing = { tag = "wizard", at_least = 6 },
    stars = { count = 120, seed = 277, hues = { "gold", "violet", "ice" } },
    instances = instances,
}
