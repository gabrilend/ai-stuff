-- wizard-rings: a wizard stands on a dim meadow and casts: the arm lifts, the
-- star on the wand's tip flares, and rings of light leave it one after
-- another, each widening and narrowing as it travels toward a crystal on a
-- pedestal, which brightens and swells as each ring arrives. The camera
-- sways gently side to side.
local here = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local wizard_parts = dofile(here .. "parts/wizard.lua")

local GROUND = { size = 10, grid = 22, base = -1.0, waves = { { 0.05, 0.9, 0.6, 0 }, { 0.04, -0.5, 1.2, 0.7 } } }
local WIZARD_AT = { -1.9, 0, 0.2 }
-- Each ring leaves the wand's star from wherever the star is at the moment
-- the ring sets off -- `{ part = "wand-star" }` -- so as the arm lifts and
-- falls the rings leave from the moving tip. (The first cut started them all
-- from one fixed spot near the tip; the owner saw it: "the circles and the
-- magic missiles should be emanated from the tip of the wand. Right now they
-- are emanating from a fixed location.")
local ground_y = -1.0
local TIP = { part = "wand-star" }
local TARGET = { 2.5, ground_y + 1.35, 0.1 }

local instances = {
    { tag = "meadow", mesh = "terrain", hue = "teal", dim = 0.3, style = "solid", mesh_params = GROUND },
    { tag = "wizard", motion = { kind = "fixed", at = WIZARD_AT, on_ground = true },
      -- the wand moves as slowly as wizard-beam's: two gestures a loop (the owner:
      -- "should move their wands slowly, like the wizard-beam")
      parts = wizard_parts({ robe = "violet", hat = "ice", cast_cycles = 2 }) },
    { tag = "pedestal", mesh = "cone", hue = "ice", dim = 0.55, style = "glow", stretch = { 0.35, 0.7, 0.35 },
      mesh_params = { segments = 8 }, motion = { kind = "fixed", at = { TARGET[1], 0.55, TARGET[3] }, on_ground = true } },
    { tag = "crystal", mesh = "icosahedron", hue = "ice", scale = 0.34, style = "glow",
      motion = { kind = "fixed", at = TARGET, sway = { { vector = { 0, 0.06, 0 }, cycles = 2 } } },
      spin = { axis = { 0, 1, 0 }, turns = 1 },
      reacts = { { to = "ring", within = 1.1, effect = "glow", amount = 1.0 },
                 { to = "ring", within = 1.1, effect = "swell", amount = 0.35 } } },
}
-- five rings a loop, in rainbow order, each leaving as the arm lifts; each
-- faces the way it flies and breathes wide and narrow twice on the way
local order = { "rose", "gold", "jade", "teal", "violet" }
for k, hue in ipairs(order) do
    instances[#instances + 1] = {
        tag = "ring", mesh = "torus", hue = hue, scale = 0.42, style = "solid",
        mesh_params = { major = 0.75, minor = 0.09, rings = 28, sides = 8 },
        motion = { kind = "conveyor", from = TIP, to = TARGET, cycles = 1, phase = (k - 1) / #order },
        face_motion = true, orient = { axis = { 0, 0, 1 }, angle = math.pi / 2 },
        pulse = { amount = 0.35, cycles = 10, phase = (k - 1) / #order * 2 },
    }
end
return {
    name = "wizard-rings",
    size = 320, frames = 150, delay_cs = 4,
    ground = GROUND,
    camera = { fov = 48,
               motion = { kind = "dolly", from = { 0.3, 1.3, 7.0 }, to = { -0.7, 1.0, 6.5 }, cycles = 1,
                          target = { 0.1, 0.35, 0 } } },
    framing = { tag = "wizard", at_least = 6 },
    stars = { count = 120, seed = 269, hues = { "gold", "violet", "ice" } },
    instances = instances,
}
