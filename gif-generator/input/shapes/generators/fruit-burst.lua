-- fruit-burst: five fruits ride a slow carousel -- an orange, a lime, a plum,
-- a long lemon, a cherry-red berry -- each with a green leaf riding on top.
-- In turn, each fruit falls open into facets of its own colour, hangs there
-- as a sphere of floating slices, and closes whole again.
local fruits = {
    { hue = "ember",  stretch = { 1, 1, 1 },        scale = 0.62 },
    { hue = "jade",   stretch = { 1, 0.95, 1 },     scale = 0.5 },
    { hue = "violet", stretch = { 0.95, 1.05, 0.95 }, scale = 0.52 },
    { hue = "gold",   stretch = { 1.35, 0.85, 0.85 }, scale = 0.5 },
    { hue = "rose",   stretch = { 1, 1.08, 1 },     scale = 0.46 },
}
local instances = {}
for i, fruit in ipairs(fruits) do
    local phase = (i - 1) / #fruits
    local ride = { kind = "orbit", radius = 2.1, cycles = 1, phase = phase, tilt = 0.15 }
    instances[#instances + 1] = {
        tag = "fruit", mesh = "superball", hue = fruit.hue, scale = fruit.scale, stretch = fruit.stretch,
        mesh_params = { grid = 3 }, style = "solid", shards = "own", shard_distance = 0.9,
        motion = ride, spin = { axis = { 0.1, 1, 0 }, turns = 2 },
        -- each fruit opens once per loop, a fifth of a loop after the last
        burst = { amount = 0.9, cycles = 1, phase = -phase, power = 3 },
    }
    instances[#instances + 1] = {
        tag = "leaf", mesh = "octahedron", hue = "jade", scale = 0.2, stretch = { 1.3, 0.25, 0.6 },
        motion = { kind = ride.kind, radius = ride.radius, cycles = ride.cycles, phase = ride.phase,
                   tilt = ride.tilt, offset = { 0, fruit.scale * fruit.stretch[2] + 0.12, 0 } },
        spin = { axis = { 0, 1, 0 }, turns = 2 },
        rock = { axis = { 1, 0, 0 }, center = 0.2, amount = 0.25, cycles = 4, phase = phase },
    }
end
instances[#instances + 1] = {
    tag = "bowl", mesh = "torus", hue = "teal", scale = 2.9, style = "wire",
    mesh_params = { major = 0.75, minor = 0.04, rings = 48, sides = 4 },
    motion = { kind = "fixed", at = { 0, -0.75, 0 } }, spin = { axis = { 0, 1, 0 }, turns = -1 },
}
return {
    name = "fruit-burst",
    size = 320, frames = 120, delay_cs = 4,
    camera = { distance = 7.0, fov = 46, tilt = 0.42 },
    stars = { count = 80, seed = 97, hues = { "gold", "ember", "jade" } },
    instances = instances,
}
