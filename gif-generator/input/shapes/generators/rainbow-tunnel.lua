-- rainbow-tunnel: the camera drifts gently forward and back down a tunnel of
-- rainbow rings, the horizon turning once all the way round, while the rings
-- stream steadily toward it out of the dark -- so it feels like falling down
-- the rainbow forever. Tiny gold stars stream between the rings.
local order = { "rose", "ember", "gold", "jade", "teal", "ice", "violet" }
local count = 14
local instances = {}
for k = 0, count - 1 do
    instances[#instances + 1] = {
        tag = "ring", mesh = "torus", hue = order[1 + k % #order], scale = 1.9, style = "solid",
        mesh_params = { major = 0.75, minor = 0.07, rings = 32, sides = 6 },
        -- stood up to face down the tunnel, then carried toward the lens
        orient = { axis = { 1, 0, 0 }, angle = math.pi / 2 },
        motion = { kind = "conveyor", from = { 0, 0, -16 }, to = { 0, 0, 6.5 }, cycles = 1, phase = k / count },
    }
end
for k = 0, 9 do
    local a = k * 2.39996
    instances[#instances + 1] = {
        tag = "spark", mesh = "star_prism", hue = "gold", scale = 0.1,
        motion = { kind = "conveyor", from = { 0.7 * math.cos(a), 0.7 * math.sin(a), -16 },
                   to = { 0.7 * math.cos(a), 0.7 * math.sin(a), 6.5 }, cycles = 1, phase = k / 10 + 0.03 },
        spin = { axis = { 0, 0, 1 }, turns = 2 },
    }
end
return {
    name = "rainbow-tunnel",
    size = 320, frames = 104, delay_cs = 5,
    camera = { fov = 58,
               motion = { kind = "dolly", from = { 0, 0, 5.2 }, to = { 0, 0.15, 4.2 }, cycles = 1,
                          target = { 0, 0, -12 } },
               roll = { turns = 1 } },
    stars = { count = 70, seed = 223, hues = { "gold", "rose", "ice" } },
    instances = instances,
}
