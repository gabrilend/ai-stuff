-- blob-necklace: a ring of twelve soft beads in rainbow order floats round a
-- lamp. The lamp -- a gold orb on a turning arm at the ring's heart -- sweeps
-- round, and each bead's bands of brightness turn to follow it. The beads
-- breathe in and out along the ring, so neighbours touch and melt together,
-- then part.
local instances = {
    { tag = "machine", motion = { kind = "fixed", at = { 0, -0.2, 0 } }, spin = { axis = { 0, 1, 0 }, turns = 2 },
      parts = {
          { tag = "hub", mesh = "icosahedron", hue = "ice", dim = 0.6, scale = 0.16 },
          { tag = "arm", mesh = "octahedron", hue = "ice", dim = 0.6, stretch = { 0.5, 0.03, 0.03 },
            pivot = { 0.5, 0, 0 },
            parts = { { tag = "lamp", mesh = "icosahedron", hue = "gold", scale = 0.12, offset = { 1.0, 0.25, 0 } } } },
      } },
}
local order = { "rose", "ember", "gold", "jade", "teal", "ice", "violet", "rose", "ember", "gold", "jade", "teal" }
for k = 1, #order do
    local a = (k - 1) / #order * 2 * math.pi
    instances[#instances + 1] = {
        tag = "bead", hue = order[k], scale = 0.3,
        blob = { group = "necklace", bands = 4, soft = 0.3 },
        -- each bead drifts a little along the ring and back, out of step
        -- with its neighbours, so pairs meet and part
        motion = { kind = "fixed", at = { 2.1 * math.cos(a), 0, 2.1 * math.sin(a) },
                   sway = { { vector = { -0.3 * math.sin(a), 0, 0.3 * math.cos(a) }, cycles = 2, phase = k * 0.5 },
                            { vector = { 0, 0.18, 0 }, cycles = 3, phase = k / #order } } },
    }
end
return {
    name = "blob-necklace",
    size = 320, frames = 144, delay_cs = 4,
    jobs = 4,
    lights = { { tag = "lamp", hue = "cloud", strength = 1.1 } },
    camera = { fov = 46, motion = { kind = "orbit", radius = 5.4, height = 2.2, cycles = 1, target = { 0, -0.1, 0 } } },
    framing = { tag = "bead", at_least = 10 },
    stars = { count = 100, seed = 311, hues = { "gold", "ice", "violet" } },
    instances = instances,
}
