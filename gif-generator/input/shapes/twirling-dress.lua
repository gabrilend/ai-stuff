-- twirling-dress: an outfit with nobody in it, twirling. A rose skirt (a
-- cone) flares wide and gathers as it spins, under a violet bodice; a hat
-- with a gold brim floats above, bobbing and tipping in its own time. Ribbons
-- of small gems stream around the skirt's hem, and sparkles swell when the
-- ribbons brush the skirt.
local instances = {
    { tag = "skirt", mesh = "cone", hue = "rose", scale = 1.0, style = "glow",
      mesh_params = { segments = 16, radius = 1.0, height = 1.5 },
      motion = { kind = "fixed", at = { 0, -0.55, 0 } },
      spin = { axis = { 0, 1, 0 }, turns = 3 },
      pulse = { amount = 0.28, cycles = 2, axes = { 1, -0.35, 1 } } },
    { tag = "bodice", mesh = "octahedron", hue = "violet", scale = 0.42, stretch = { 0.8, 1.2, 0.6 },
      motion = { kind = "fixed", at = { 0, 0.55, 0 } }, spin = { axis = { 0, 1, 0 }, turns = 3 } },
    { tag = "hat", mesh = "cone", hue = "violet", scale = 0.42, style = "glow",
      mesh_params = { segments = 12, radius = 0.55, height = 1.0 },
      motion = { kind = "fixed", at = { 0, 1.55, 0 }, sway = { { vector = { 0, 0.15, 0 }, cycles = 2 } } },
      spin = { axis = { 0, 1, 0 }, turns = -1 },
      rock = { axis = { 0, 0, 1 }, amount = 0.22, cycles = 2, phase = 0.25 } },
    { tag = "brim", mesh = "torus", hue = "gold", scale = 0.6, style = "solid",
      mesh_params = { major = 0.75, minor = 0.12, rings = 28, sides = 8 },
      motion = { kind = "fixed", at = { 0, 1.35, 0 }, sway = { { vector = { 0, 0.15, 0 }, cycles = 2 } } },
      spin = { axis = { 0, 1, 0 }, turns = -1 },
      rock = { axis = { 0, 0, 1 }, amount = 0.22, cycles = 2, phase = 0.25 } },
}
-- two ribbons of gems circling the hem in opposite directions
local gem_hues = { "gold", "teal", "jade", "ice" }
for ribbon = 0, 1 do
    for k = 0, 9 do
        instances[#instances + 1] = {
            tag = "gem", mesh = (k % 2 == 0) and "octahedron" or "icosahedron",
            hue = gem_hues[1 + (k + ribbon) % #gem_hues], scale = 0.1,
            motion = { kind = "orbit", radius = 1.65, cycles = (ribbon == 0) and 2 or -2,
                       phase = k / 10 * 0.45 + ribbon * 0.5, tilt = (ribbon == 0) and 0.2 or -0.2,
                       center = { 0, -0.8, 0 }, bob = { amount = 0.25, cycles = 6, phase = k * 0.05 } },
            spin = { axis = { 1, 1, 0 }, turns = 4 },
            reacts = { { to = "skirt", within = 1.9, effect = "swell", amount = 0.6 } },
        }
    end
end
return {
    name = "twirling-dress",
    size = 320, frames = 96, delay_cs = 4,
    camera = { distance = 6.8, fov = 46, tilt = 0.3 },
    stars = { count = 90, seed = 131, hues = { "gold", "rose", "violet" } },
    instances = instances,
}
