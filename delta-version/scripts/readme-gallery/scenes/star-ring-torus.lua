-- star-ring-torus: eight golden stars stand in a ring, each spinning on its
-- own axis at its own moment in the turn. A teal torus threads a knotted path
-- through and around the ring; every star it passes swells and flares, then
-- settles.
local instances = {
    { tag = "ring", mesh = "torus", hue = "teal", scale = 0.95, style = "solid",
      mesh_params = { major = 0.75, minor = 0.26, rings = 28, sides = 14 },
      motion = { kind = "lissajous", size = { 2.6, 0.7, 2.6 }, freq = { 1, 2, 2 },
                 shift = { 0, 0.25, 0.25 } },
      spin = { axis = { 1, 0.2, 0 }, turns = 2 } },
}
-- Eight stars evenly around the ring, alternating spin direction; each
-- starts its spin a different fraction of a turn along, so they never all
-- stand edge-on at once.
for i = 0, 7 do
    instances[#instances + 1] = {
        tag = "star", mesh = "star_prism", hue = "gold", scale = 0.42, style = "glow",
        motion = { kind = "orbit", radius = 2.6, cycles = 1, phase = i / 8 },
        spin = { axis = { 0, 1, 0 }, turns = (i % 2 == 0) and 2 or -2, phase = (i * 0.37) % 1 },
        reacts = { { to = "ring", within = 1.8, effect = "swell", amount = 0.8 },
                   { to = "ring", within = 1.8, effect = "glow", amount = 1.0 } },
    }
end
return {
    name = "star-ring-torus",
    size = 320, frames = 120, delay_cs = 4,
    camera = { distance = 8.2, fov = 46, tilt = 0.5 },
    stars = { count = 90, seed = 31, hues = { "gold", "ice" } },
    instances = instances,
}
