-- jellyfish-drift: two jellyfish, each a stack of glowing rings that squeeze
-- and relax in a wave from crown to hem, drift on slow loops through a field
-- of little gold stars. Their tentacles are chains of tiny crystals that
-- follow the bell a moment behind, rippling; every star a bell passes flares.
local instances = {}

-- {{{ local function jellyfish()
local function jellyfish(hue, tentacle_hue, center, phase)
    local path = { kind = "lissajous", center = center, size = { 0.7, 0.45, 0.35 },
                   freq = { 1, 2, 1 }, phase = phase }
    -- the bell: a flattened dome that squeezes narrow and tall, then relaxes
    -- wide and low, with a glowing ring at its hem that squeezes a moment
    -- later (a stack of rings read as a soft-serve cone, not a jellyfish)
    instances[#instances + 1] = {
        tag = "bell", mesh = "superball", hue = hue, scale = 0.62, stretch = { 1, 0.62, 1 },
        mesh_params = { grid = 6 },
        motion = { kind = path.kind, center = path.center, size = path.size, freq = path.freq,
                   phase = path.phase, offset = { 0, 0.18, 0 } },
        pulse = { amount = 0.2, cycles = 3, axes = { 1, -0.8, 1 } },
    }
    instances[#instances + 1] = {
        tag = "bell", mesh = "torus", hue = tentacle_hue, scale = 0.72, style = "solid",
        mesh_params = { major = 0.8, minor = 0.09, rings = 28, sides = 8 },
        motion = { kind = path.kind, center = path.center, size = path.size, freq = path.freq,
                   phase = path.phase, offset = { 0, -0.02, 0 } },
        pulse = { amount = 0.22, cycles = 3, phase = -0.06, axes = { 1, 0, 1 } },
    }
    -- four tentacles of six crystals, each crystal further behind in time
    -- and further down, rippling outward more toward the tip
    for arm = 0, 3 do
        local a = arm * math.pi / 2 + 0.4
        for k = 1, 6 do
            instances[#instances + 1] = {
                tag = "tentacle", mesh = "octahedron", hue = tentacle_hue, scale = 0.075 * (1.2 - k * 0.1),
                motion = { kind = path.kind, center = path.center, size = path.size, freq = path.freq,
                           phase = path.phase, lag = k * 0.014,
                           offset = { 0.3 * math.cos(a), -0.2 - k * 0.2, 0.3 * math.sin(a) },
                           sway = { { vector = { 0.05 * k * math.cos(a), 0, 0.05 * k * math.sin(a) },
                                      cycles = 3, phase = -k * 0.07 } } },
                spin = { axis = { 0, 1, 0 }, turns = 2 },
            }
        end
    end
end
-- }}}

jellyfish("violet", "ice", { -1.0, -0.1, 0 }, 0.0)
jellyfish("rose", "gold", { 1.1, -0.4, -0.5 }, 0.45)

-- the drifting stars: small gold solids on wide slow loops
for i = 0, 7 do
    instances[#instances + 1] = {
        tag = "star", mesh = "star_prism", hue = "gold", scale = 0.13,
        motion = { kind = "lissajous", size = { 3.0, 1.9, 1.2 }, freq = { 1, 1, 2 },
                   phase = i / 8, shift = { 0, 0.25 + (i % 3) * 0.1, 0 } },
        spin = { axis = { 0.2, 1, 0 }, turns = (i % 2 == 0) and 2 or -2 },
        reacts = { { to = "bell", within = 1.1, effect = "swell", amount = 1.2 },
                   { to = "bell", within = 1.1, effect = "glow", amount = 1.0 } },
    }
end

return {
    name = "jellyfish-drift",
    size = 320, frames = 120, delay_cs = 4,
    camera = { distance = 5.8, fov = 46, tilt = 0.18 },
    stars = { count = 70, seed = 71, hues = { "ice", "violet", "gold" } },
    instances = instances,
}
