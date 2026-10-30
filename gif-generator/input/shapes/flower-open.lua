-- flower-open: a flower seen from above and to the side, its eight petals --
-- flattened octahedra hinged at the centre -- opening wide and folding shut
-- twice a loop, the whole bloom turning slowly. A golden heart swells as the
-- petals open; three bees (small gold-and-violet solids) circle it.
local instances = {}
local petals = 8
for i = 0, petals - 1 do
    instances[#instances + 1] = {
        tag = "petal", mesh = "octahedron", hue = (i % 2 == 0) and "rose" or "violet", scale = 1.0,
        -- a thin blade reaching out along +x, its inner tip moved to the
        -- centre so it hinges there
        stretch = { 0.95, 0.12, 0.42 }, pivot = { 0.95, 0, 0 },
        motion = { kind = "fixed" },
        -- its place around the bloom, turning with the rest: all petals share
        -- one turn per loop, each starting its own eighth of the way round
        spin = { axis = { 0, 1, 0 }, turns = 1, phase = i / petals },
        -- then tipped up about its own hinge: 1.15 radians is a closed bud,
        -- 0.05 lies nearly flat open
        rock = { axis = { 0, 0, 1 }, center = 0.6, amount = 0.55, cycles = 2, phase = 0.25 },
    }
end
instances[#instances + 1] = {
    tag = "heart", mesh = "icosahedron", hue = "gold", scale = 0.38, style = "glow",
    motion = { kind = "fixed", at = { 0, 0.1, 0 } }, spin = { axis = { 0, 1, 0 }, turns = -1 },
    pulse = { amount = 0.25, cycles = 2, phase = 0.5 },
}
for b = 0, 2 do
    instances[#instances + 1] = {
        tag = "bee", mesh = "octahedron", hue = (b == 1) and "violet" or "gold", scale = 0.12,
        stretch = { 1.6, 0.8, 0.8 }, face_motion = true,
        motion = { kind = "orbit", radius = 2.1 + 0.25 * b, cycles = (b == 1) and -2 or 2, phase = b / 3,
                   tilt = 0.25 * (b - 1), bob = { amount = 0.35, cycles = 4, phase = b * 0.3 } },
    }
end
return {
    name = "flower-open",
    size = 320, frames = 96, delay_cs = 4,
    camera = { distance = 6.4, fov = 46, tilt = 0.72 },
    stars = { count = 70, seed = 83, hues = { "gold", "rose", "jade" } },
    instances = instances,
}
