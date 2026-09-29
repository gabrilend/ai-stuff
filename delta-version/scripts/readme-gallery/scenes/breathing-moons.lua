-- breathing-moons: a copy of the approved breathing-solid (which stays as it
-- was), whose centre, instead of breathing between rounded shapes, becomes
-- each of its own moons in turn -- octahedron, cube, tetrahedron, icosahedron
-- -- holding each true, sharp-cornered form for a moment, then flowing into
-- the next, its colour changing to that moon's. The four moons ride their
-- tipped ring round it as before, swelling and taking its tint as they pass.
-- The owner's words: "breathing-solid should be copied and should create all
-- of the shapes that are orbiting around it instead of the rounded corner
-- ones." (`morph_through`: each corner of the sphere is pushed out as far as
-- the solid reaches in its direction, so the centre is exactly each solid
-- when it holds.)
return {
    name = "breathing-moons",
    size = 320, frames = 144, delay_cs = 4,
    camera = { distance = 7.2, fov = 44, tilt = 0.45 },
    stars = { count = 80, seed = 5, hues = { "ice", "violet", "gold" } },
    instances = {
        { tag = "heart", mesh = "superball", hue = "violet", scale = 1.25, style = "glow",
          mesh_params = { grid = 14 },
          motion = { kind = "fixed" }, spin = { axis = { 0.25, 1, 0.15 }, turns = 1 },
          morph_through = { cycles = 1, hold = 0.45,
                            shapes = { "octahedron", "cube", "tetrahedron", "icosahedron" },
                            hues = { "ice", "gold", "jade", "rose" } } },

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
