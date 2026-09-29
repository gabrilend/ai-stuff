-- tiny-fluid: the smallest liquid scene -- a few drops in a tilting box, lit
-- by a lamp on a turning arm, drawn as blobs -- so the tests can film it in a
-- moment, twice, and check both films are the same to the byte.
return {
    name = "tiny-fluid",
    size = 48, frames = 6, delay_cs = 5,
    fluid = {
        count = 24, seed = 5, radius = 0.15, box = { 0.6, 0.5, 0.4 },
        tilt = { axis = { 0, 0, 1 }, amount = 0.4, cycles = 1 },
        stiffness = 800, drag = 3, substeps = 6, warmup = 1, blend = 2, hues = { "teal", "ice" },
    },
    instances = {
        { tag = "machine", motion = { kind = "fixed", at = { 0, 1, 0 } }, spin = { axis = { 0, 1, 0 }, turns = 1 },
          parts = { { tag = "lamp", mesh = "icosahedron", hue = "gold", scale = 0.1, offset = { 1.5, 0, 0 } } } },
    },
    lights = { { tag = "lamp", hue = "cloud" } },
    camera = { distance = 4, fov = 50, tilt = 0.3 },
}
