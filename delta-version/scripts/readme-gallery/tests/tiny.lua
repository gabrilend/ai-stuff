-- tiny: the smallest scene that still exercises every part of the tool --
-- a morphing solid, an orbiter that reacts to it, a shatter, stars -- at a
-- size and length that film in a moment. Used by test-readme-gallery.sh.
return {
    name = "tiny",
    size = 48, frames = 6, delay_cs = 5,
    camera = { distance = 6, fov = 50, tilt = 0.3 },
    stars = { count = 10, seed = 3 },
    instances = {
        { tag = "core", mesh = "superball", hue = "violet", scale = 1.0,
          mesh_params = { grid = 3 }, morph = { cycles = 1 },
          reacts = { { to = "moon", within = 2.5, effect = "shatter", amount = 0.6 } } },
        { tag = "moon", mesh = "star_prism", hue = "gold", scale = 0.4,
          motion = { kind = "orbit", radius = 1.9, cycles = 1 }, spin = { axis = { 0, 1, 0 }, turns = 1 },
          reacts = { { to = "core", within = 2.5, effect = "bleed_hue" } } },
        { tag = "ring", mesh = "torus", hue = "teal", scale = 0.5, style = "wire",
          motion = { kind = "swing", from = { -2, 0, 0 }, to = { 2, 0, 0 }, cycles = 1 } },
    },
}
