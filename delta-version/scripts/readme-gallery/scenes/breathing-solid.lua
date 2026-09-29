-- breathing-solid: one shape breathes between a cube and an octahedron,
-- passing through a sphere on the way, while four small moons ride a tipped
-- ring around it -- each moon swelling as it passes the widest part of the
-- breath, and taking a tint of the violet at the centre.
return {
    name = "breathing-solid",
    size = 320, frames = 96, delay_cs = 4,
    camera = { distance = 7.2, fov = 44, tilt = 0.45 },
    stars = { count = 80, seed = 5, hues = { "ice", "violet", "gold" } },
    instances = {
        { tag = "heart", mesh = "superball", hue = "violet", scale = 1.25, style = "glow",
          mesh_params = { grid = 8 },
          motion = { kind = "fixed" }, spin = { axis = { 0.25, 1, 0.15 }, turns = 1 },
          morph = { cycles = 2, cube = 24, octa = 1.02 } },

        { tag = "moon", mesh = "octahedron", hue = "ice", scale = 0.3, style = "glow",
          motion = { kind = "orbit", radius = 2.35, cycles = 1, phase = 0.0, tilt = 0.5 },
          spin = { axis = { 0, 1, 0 }, turns = 3 },
          reacts = { { to = "heart", within = 2.9, effect = "swell", amount = 0.5 },
                     { to = "heart", within = 2.9, effect = "bleed_hue", amount = 0.9 } } },
        { tag = "moon", mesh = "cube", hue = "gold", scale = 0.26, style = "glow",
          motion = { kind = "orbit", radius = 2.35, cycles = 1, phase = 0.25, tilt = 0.5 },
          spin = { axis = { 1, 1, 0 }, turns = 3 },
          reacts = { { to = "heart", within = 2.9, effect = "swell", amount = 0.5 },
                     { to = "heart", within = 2.9, effect = "bleed_hue", amount = 0.9 } } },
        { tag = "moon", mesh = "tetrahedron", hue = "jade", scale = 0.32, style = "glow",
          motion = { kind = "orbit", radius = 2.35, cycles = 1, phase = 0.5, tilt = 0.5 },
          spin = { axis = { 1, 0, 1 }, turns = 3 },
          reacts = { { to = "heart", within = 2.9, effect = "swell", amount = 0.5 },
                     { to = "heart", within = 2.9, effect = "bleed_hue", amount = 0.9 } } },
        { tag = "moon", mesh = "icosahedron", hue = "rose", scale = 0.3, style = "glow",
          motion = { kind = "orbit", radius = 2.35, cycles = 1, phase = 0.75, tilt = 0.5 },
          spin = { axis = { 0, 1, 1 }, turns = 3 },
          reacts = { { to = "heart", within = 2.9, effect = "swell", amount = 0.5 },
                     { to = "heart", within = 2.9, effect = "bleed_hue", amount = 0.9 } } },
    },
}
