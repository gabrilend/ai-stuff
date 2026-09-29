-- coral-garden-orbit: the camera circles a coral garden once, from a little
-- above, rising and dipping gently. The garden itself barely moves -- spires
-- sway, a brain coral turns, a starfish lies still -- while a few small fish
-- idle round it, slower than the camera, so the frame stays calm.
local instances = {}
-- spires: tall cones in clusters, each rocking a little in the current
local spires = {
    { -0.9, -0.4, "ember", 1.0 }, { -0.6, -0.9, "rose", 0.75 }, { -1.2, 0.2, "violet", 0.6 },
    { 0.9, 0.5, "rose", 0.9 }, { 1.3, 0.1, "ember", 0.65 }, { 0.6, 1.0, "violet", 0.7 },
}
for i, s in ipairs(spires) do
    instances[#instances + 1] = {
        tag = "coral", mesh = "cone", hue = s[3], scale = 0.42 * s[4], stretch = { 0.55, 1.8, 0.55 },
        mesh_params = { segments = 10 }, style = "glow",
        motion = { kind = "fixed", at = { s[1], -0.9 + 0.75 * s[4], s[2] } },
        rock = { axis = { 1, 0, 0.4 }, amount = 0.08, cycles = 2, phase = i * 0.13 },
    }
end
instances[#instances + 1] = {
    tag = "coral", mesh = "icosahedron", hue = "jade", scale = 0.55, style = "glow",
    motion = { kind = "fixed", at = { 0.1, -0.55, -0.2 } }, spin = { axis = { 0, 1, 0 }, turns = 1 },
    pulse = { amount = 0.05, cycles = 2 },
}
instances[#instances + 1] = {
    tag = "coral", mesh = "star_prism", hue = "gold", scale = 0.4, style = "glow",
    motion = { kind = "fixed", at = { 0.3, -0.95, 1.1 } },
    orient = { axis = { 1, 0, 0 }, angle = math.pi / 2 },
}
instances[#instances + 1] = {
    tag = "coral", mesh = "torus", hue = "teal", scale = 0.45, style = "solid",
    mesh_params = { minor = 0.34 },
    motion = { kind = "fixed", at = { -0.4, -0.85, 1.0 } },
    pulse = { amount = 0.08, cycles = 3, axes = { 1, 0, 1 } },
}
for f = 0, 4 do
    instances[#instances + 1] = {
        tag = "fish", mesh = "octahedron", hue = (f % 2 == 0) and "ice" or "teal", scale = 0.11,
        stretch = { 1.9, 0.75, 0.6 }, face_motion = true,
        motion = { kind = "orbit", radius = 1.7 + 0.12 * f, cycles = (f % 2 == 0) and 1 or -1,
                   phase = f / 5, center = { 0, -0.2 + 0.12 * f, 0 },
                   bob = { amount = 0.08, cycles = 3, phase = f * 0.2 } },
    }
end
return {
    name = "coral-garden-orbit",
    size = 320, frames = 144, delay_cs = 4,
    camera = { fov = 46,
               motion = { kind = "orbit", radius = 3.7, height = 1.3, cycles = 1, target = { 0, -0.4, 0 },
                          bob = { amount = 0.35, cycles = 2 } } },
    stars = { count = 110, seed = 211, hues = { "ice", "teal", "gold" } },
    instances = instances,
}
