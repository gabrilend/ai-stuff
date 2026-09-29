-- shell-staircase: a spiral staircase of seashells -- whorled cones and
-- ridged tetrahedra in sunset colours -- winds up around a slender spire.
-- The camera cranes up it while circling once, looking up the stair as it
-- climbs, then sinks back down. The shells only breathe a little; a gold
-- star turns at the top.
local steps = 22
local hues = { "rose", "ember", "gold", "violet", "rose", "ice" }
local instances = {}
for k = 0, steps - 1 do
    local angle = k * 0.45
    local height = -1.6 + k * 0.2
    instances[#instances + 1] = {
        tag = "shell", mesh = (k % 2 == 0) and "cone" or "tetrahedron", hue = hues[1 + k % #hues],
        scale = 0.3, stretch = (k % 2 == 0) and { 0.8, 1.1, 0.8 } or { 1, 1, 1 },
        mesh_params = (k % 2 == 0) and { segments = 9 } or nil, style = "glow",
        motion = { kind = "fixed", at = { 1.1 * math.cos(angle), height, 1.1 * math.sin(angle) } },
        orient = { axis = { 0, 1, 0 }, angle = -angle },
        pulse = { amount = 0.06, cycles = 2, phase = -k * 0.04 },
    }
end
-- the newel: a tall, thin spire the stair winds around, so the eye reads
-- a staircase rather than a scatter of shells
instances[#instances + 1] = {
    tag = "newel", mesh = "cone", hue = "ice", scale = 1.0, stretch = { 0.14, 3.0, 0.14 },
    mesh_params = { segments = 12 }, style = "glow",
    motion = { kind = "fixed", at = { 0, 0.55, 0 } },
}
instances[#instances + 1] = {
    tag = "crown", mesh = "star_prism", hue = "gold", scale = 0.42, style = "glow",
    motion = { kind = "fixed", at = { 0, -1.6 + steps * 0.2 + 0.35, 0 } }, spin = { axis = { 0, 1, 0 }, turns = 2 },
}
return {
    name = "shell-staircase",
    size = 320, frames = 144, delay_cs = 4,
    camera = { fov = 44,
               motion = { kind = "crane", radius = 6.4, low = -0.8, high = 3.0, cycles = 1, turns = 1,
                          target = { 0, -0.6, 0 }, follow = 0.55 } },
    stars = { count = 100, seed = 227, hues = { "ice", "rose", "gold" } },
    instances = instances,
}
