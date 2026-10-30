-- fruit-bowl-spiral: a bowl of fruit -- orange, lime, plum, lemon, berry and
-- a bunch of small grapes -- each fruit bobbing gently in place. The camera
-- spirals round it once, sweeping in close and low, then pulling up and away
-- to look down into the bowl.
local fruits = {
    { "ember", { 1, 1, 1 }, 0.5, 0.0 }, { "jade", { 1, 0.95, 1 }, 0.42, 1.25 },
    { "violet", { 0.95, 1.05, 0.95 }, 0.44, 2.5 }, { "gold", { 1.35, 0.85, 0.85 }, 0.42, 3.75 },
    { "rose", { 1, 1.08, 1 }, 0.38, 5.0 },
}
local instances = {}
for i, fruit in ipairs(fruits) do
    local x, z = 1.05 * math.cos(fruit[4]), 1.05 * math.sin(fruit[4])
    instances[#instances + 1] = {
        tag = "fruit", mesh = "superball", hue = fruit[1], scale = fruit[3], stretch = fruit[2],
        mesh_params = { grid = 5 }, style = "solid",
        motion = { kind = "fixed", at = { x, -0.15, z },
                   sway = { { vector = { 0, 0.07, 0 }, cycles = 2, phase = i * 0.17 } } },
        spin = { axis = { 0, 1, 0 }, turns = (i % 2 == 0) and 1 or -1 },
    }
    instances[#instances + 1] = {
        tag = "leaf", mesh = "octahedron", hue = "jade", scale = 0.17, stretch = { 1.3, 0.25, 0.6 },
        motion = { kind = "fixed", at = { x, -0.15 + fruit[3] * fruit[2][2] + 0.1, z },
                   sway = { { vector = { 0, 0.07, 0 }, cycles = 2, phase = i * 0.17 } } },
        spin = { axis = { 0, 1, 0 }, turns = (i % 2 == 0) and 1 or -1 },
    }
end
-- grapes in the middle: a little pyramid of violet spheres
local grapes = { { 0, 0, 0 }, { 0.2, 0, 0.1 }, { -0.15, 0, 0.15 }, { 0.05, 0, -0.2 }, { 0.02, 0.2, 0.02 } }
for g, p in ipairs(grapes) do
    instances[#instances + 1] = {
        tag = "grape", mesh = "superball", hue = "violet", scale = 0.14, mesh_params = { grid = 3 },
        style = "solid", motion = { kind = "fixed", at = { p[1], -0.25 + p[2], p[3] } },
        pulse = { amount = 0.06, cycles = 3, phase = g * 0.2 },
    }
end
instances[#instances + 1] = {
    tag = "bowl", mesh = "torus", hue = "teal", scale = 2.1, style = "solid",
    mesh_params = { major = 0.75, minor = 0.05, rings = 56, sides = 6 },
    motion = { kind = "fixed", at = { 0, -0.55, 0 } },
}
instances[#instances + 1] = {
    tag = "bowl", mesh = "torus", hue = "ice", scale = 1.35, style = "solid",
    mesh_params = { major = 0.75, minor = 0.05, rings = 48, sides = 6 },
    motion = { kind = "fixed", at = { 0, -0.85, 0 } },
}
return {
    name = "fruit-bowl-spiral",
    size = 320, frames = 144, delay_cs = 4,
    camera = { fov = 46,
               motion = { kind = "spiral", near = 3.9, far = 5.8, low = 0.8, high = 3.4, cycles = 1, turns = 1,
                          target = { 0, -0.3, 0 } } },
    stars = { count = 100, seed = 229, hues = { "gold", "ember", "jade" } },
    instances = instances,
}
