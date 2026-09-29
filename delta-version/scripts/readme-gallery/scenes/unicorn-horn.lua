-- unicorn-horn: a twisted golden horn flies a looping path, nose first,
-- spinning along its own length, and threads a violet ring on every pass.
-- Behind it streams a rainbow tail of tiny cubes that follow its path a
-- moment late. The ring flares as the horn goes through it, and the stars
-- around it swell.
local instances = {
    { tag = "horn", mesh = "horn", hue = "gold", scale = 0.62, style = "glow",
      mesh_params = { ridges = 3, twist = 2.5, length = 2.2, radius = 0.3, rings = 30 },
      face_motion = true,
      motion = { kind = "lissajous", size = { 2.3, 0.9, 1.3 }, freq = { 1, 2, 1 }, shift = { 0, 0, 0.25 } },
      spin = { axis = { 1, 0, 0 }, turns = 4 } },
    { tag = "ring", mesh = "torus", hue = "violet", scale = 1.05, style = "solid",
      mesh_params = { major = 0.75, minor = 0.11, rings = 36, sides = 10 },
      orient = { axis = { 0, 0, 1 }, angle = math.pi / 2 },
      motion = { kind = "fixed" },
      rock = { axis = { 1, 0, 0 }, amount = 0.25, cycles = 1 },
      reacts = { { to = "horn", within = 1.3, effect = "glow", amount = 1.0 },
                 { to = "horn", within = 1.3, effect = "swell", amount = 0.15 } } },
}
-- the tail: rainbow order, each cube further behind in time and smaller
local tail = { "rose", "ember", "gold", "jade", "teal", "ice", "violet" }
for k = 1, 14 do
    instances[#instances + 1] = {
        tag = "tail", mesh = "cube", hue = tail[1 + (k - 1) % #tail], scale = 0.13 * (1 - k * 0.045),
        motion = { kind = "lissajous", size = { 2.3, 0.9, 1.3 }, freq = { 1, 2, 1 },
                   shift = { 0, 0, 0.25 }, lag = 0.02 + k * 0.011 },
        spin = { axis = { 1, 1, 0 }, turns = 3, phase = k * 0.1 },
    }
end
for s = 0, 5 do
    local a = s * math.pi / 3
    instances[#instances + 1] = {
        tag = "star", mesh = "star_prism", hue = (s % 2 == 0) and "rose" or "gold", scale = 0.17,
        motion = { kind = "fixed", at = { 1.9 * math.cos(a), 1.3 * math.sin(a), -1.0 } },
        spin = { axis = { 0, 0, 1 }, turns = (s % 2 == 0) and 1 or -1 },
        reacts = { { to = "horn", within = 1.6, effect = "swell", amount = 0.9 } },
    }
end
return {
    name = "unicorn-horn",
    size = 320, frames = 120, delay_cs = 4,
    camera = { distance = 7.2, fov = 46, tilt = 0.2 },
    stars = { count = 90, seed = 127, hues = { "gold", "rose", "violet", "ice" } },
    instances = instances,
}
