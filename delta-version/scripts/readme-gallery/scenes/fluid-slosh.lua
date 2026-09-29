-- fluid-slosh: a liquid in a box nobody can see. The box rocks back and
-- forth, and the liquid sloshes -- running up one wall, curling back, piling
-- against the other -- drawn as soft drops that melt into one surface, lit in
-- bands by a lamp circling on a turning arm. No container is drawn; it is
-- only there for the liquid to push against.
--
-- The owner's words: "one with a simple fluid simulation inside of an
-- invisible container? No need for a wireframe on it, just use it for the
-- physics of it."
--
-- The liquid is worked out ahead (fluid.lua): settled over a few loops of
-- rocking, then one loop is chosen to start where the liquid most nearly
-- matches itself one loop on, and its first few frames glide from the one
-- into the other so the join never jumps. See fluid.lua and issue 060's open
-- questions for the trade-off.
return {
    name = "fluid-slosh",
    size = 320, frames = 144, delay_cs = 4,
    jobs = 6,
    fluid = {
        count = 180, seed = 41, radius = 0.13,
        box = { 1.4, 0.95, 0.45 },
        tilt = { axis = { 0, 0, 1 }, amount = 0.5, cycles = 2 },
        gravity = 9, stiffness = 1600, drag = 4, substeps = 12, time_scale = 6,
        warmup = 3, blend = 10,
        hues = { "teal", "ice", "teal", "jade" }, bands = 4, soft = 0.22, blob_size = 1.35,
        center = { 0, -0.2, 0 },
    },
    instances = {
        { tag = "machine", motion = { kind = "fixed", at = { 0, 0.9, 0 } }, spin = { axis = { 0, 1, 0 }, turns = 1 },
          parts = {
              { tag = "hub", mesh = "icosahedron", hue = "ice", dim = 0.6, scale = 0.12 },
              { tag = "arm", mesh = "octahedron", hue = "ice", dim = 0.5, stretch = { 1.35, 0.025, 0.025 },
                pivot = { 1.35, 0, 0 },
                parts = { { tag = "lamp", mesh = "icosahedron", hue = "gold", scale = 0.13, offset = { 2.7, 0, 0 } } } },
          } },
    },
    lights = { { tag = "lamp", hue = "cloud", strength = 1.15 } },
    camera = { fov = 46, motion = { kind = "orbit", radius = 5.2, height = 1.9, cycles = 1, target = { 0, -0.3, 0 },
                                    bob = { amount = 0.3, cycles = 1 } } },
    framing = { tag = "drop", at_least = 60 },
    stars = { count = 100, seed = 331, hues = { "ice", "teal", "gold" } },
}
