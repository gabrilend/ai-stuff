-- orbit-kiss: a golden star turns at the centre while five solids circle it
-- on tipped rings at different speeds. Whenever two of them pass close, each
-- borrows some of the other's colour, and the star swells when any comes near.
return {
    name = "orbit-kiss",
    size = 320, frames = 96, delay_cs = 4,
    camera = { distance = 8.5, fov = 44, tilt = 0.62 },
    stars = { count = 110, seed = 11, hues = { "gold", "ice", "rose" } },
    instances = {
        { tag = "sun", mesh = "star_prism", hue = "gold", scale = 0.95, style = "glow",
          motion = { kind = "fixed" }, spin = { axis = { 0.2, 1, 0.1 }, turns = 1 },
          reacts = { { to = "planet", within = 1.9, effect = "swell", amount = 0.25 } } },

        { tag = "planet", mesh = "cube", hue = "rose", scale = 0.42, style = "glow",
          motion = { kind = "orbit", radius = 2.6, cycles = 1, phase = 0.0, tilt = 0.25 },
          spin = { axis = { 1, 1, 0 }, turns = 2 },
          reacts = { { to = "planet", within = 1.4, effect = "bleed_hue" } } },

        { tag = "planet", mesh = "octahedron", hue = "teal", scale = 0.5, style = "glow",
          motion = { kind = "orbit", radius = 2.6, cycles = -2, phase = 0.2, tilt = -0.2 },
          spin = { axis = { 0, 1, 1 }, turns = 3 },
          reacts = { { to = "planet", within = 1.4, effect = "bleed_hue" } } },

        { tag = "planet", mesh = "icosahedron", hue = "violet", scale = 0.5, style = "glow",
          motion = { kind = "orbit", radius = 2.0, cycles = 3, phase = 0.5, tilt = 0.5 },
          spin = { axis = { 1, 0, 1 }, turns = -2 },
          reacts = { { to = "planet", within = 1.4, effect = "bleed_hue" } } },

        { tag = "planet", mesh = "tetrahedron", hue = "jade", scale = 0.5, style = "glow",
          motion = { kind = "orbit", radius = 3.1, cycles = 1, phase = 0.55, tilt = -0.35,
                     bob = { amount = 0.3, cycles = 3 } },
          spin = { axis = { 1, 0.3, 0 }, turns = 3 },
          reacts = { { to = "planet", within = 1.4, effect = "bleed_hue" } } },

        { tag = "planet", mesh = "torus", hue = "ember", scale = 0.6, style = "solid",
          motion = { kind = "orbit", radius = 2.0, cycles = -1, phase = 0.8, tilt = 0.1 },
          spin = { axis = { 1, 0, 0.4 }, turns = 2 },
          reacts = { { to = "planet", within = 1.4, effect = "bleed_hue" } } },
    },
}
