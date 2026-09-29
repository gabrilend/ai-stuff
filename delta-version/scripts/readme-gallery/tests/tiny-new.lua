-- tiny-new: the second test scene, carrying every word added for the second
-- round of films -- the arc motion, lag/offset/sway, rock with a center,
-- pivot, per-axis pulse, a timed burst with own-colour shards, the cone and
-- horn shapes, and the white "cloud" colour -- at a size that films at once.
return {
    name = "tiny-new",
    size = 48, frames = 6, delay_cs = 5,
    camera = { distance = 6, fov = 50, tilt = 0.3 },
    stars = { count = 8, seed = 5 },
    instances = {
        { tag = "brick", mesh = "cube", hue = "gold", scale = 0.3,
          motion = { kind = "arc", radius = 1.5, cycles = 1, center = { 0, -0.5, 0 } } },
        { tag = "tail", mesh = "octahedron", hue = "ice", scale = 0.2,
          motion = { kind = "arc", radius = 1.5, cycles = 1, center = { 0, -0.5, 0 }, lag = 0.1,
                     offset = { 0, 0, 0.2 }, sway = { { vector = { 0, 0.2, 0 }, cycles = 2 } } } },
        { tag = "petal", mesh = "octahedron", hue = "rose", stretch = { 0.8, 0.1, 0.3 }, pivot = { 0.8, 0, 0 },
          rock = { axis = { 0, 0, 1 }, center = 0.5, amount = 0.4, cycles = 1 } },
        { tag = "skirt", mesh = "cone", hue = "violet", scale = 0.6,
          motion = { kind = "fixed", at = { -1, 0, 0 } },
          pulse = { amount = 0.3, cycles = 1, axes = { 1, 0, 1 } } },
        { tag = "fruit", mesh = "superball", hue = "ember", scale = 0.4, mesh_params = { grid = 2 },
          motion = { kind = "fixed", at = { 1, 0, 0 } }, shards = "own",
          burst = { amount = 0.8, cycles = 1 } },
        { tag = "horn", mesh = "horn", hue = "gold", scale = 0.5, face_motion = true,
          motion = { kind = "orbit", radius = 1.2, cycles = 1 } },
        { tag = "cloud", mesh = "superball", hue = "cloud", scale = 0.3, mesh_params = { grid = 2 },
          motion = { kind = "fixed", at = { 0, 1, 0 } } },
    },
}
