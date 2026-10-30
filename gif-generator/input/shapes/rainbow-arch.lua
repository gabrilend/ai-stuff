-- rainbow-arch: a rainbow made of travelling cubes. Seven bands, violet on
-- the inside to rose on the outside, each a stream of small tumbling cubes
-- that rise out of one white cloud, cross the arch, and sink into the other.
-- The clouds -- clusters of white spheres -- breathe as the cubes arrive.
local bands = { "violet", "ice", "teal", "jade", "gold", "ember", "rose" }
local per_band = 10
local instances = {}
for b, hue in ipairs(bands) do
    local radius = 1.55 + (b - 1) * 0.25
    for k = 0, per_band - 1 do
        instances[#instances + 1] = {
            tag = "brick", mesh = "cube", hue = hue, scale = 0.16, style = "glow",
            motion = { kind = "arc", radius = radius, center = { 0, -1.0, 0 }, cycles = 1,
                       phase = k / per_band + b * 0.021 },
            spin = { axis = { 1, 1, 0.3 }, turns = (b % 2 == 0) and 3 or -3, phase = k * 0.13 },
        }
    end
end
-- {{{ local function cloud()
local function cloud(x, lean)
    local puffs = { { 0, 0, 0, 0.42 }, { -0.4, -0.08, 0.1, 0.32 }, { 0.42, -0.1, -0.05, 0.34 },
                    { 0.12, 0.28, 0.05, 0.3 }, { -0.2, 0.2, -0.15, 0.26 } }
    for p, puff in ipairs(puffs) do
        instances[#instances + 1] = {
            tag = "cloud", mesh = "superball", hue = "cloud", scale = puff[4], style = "solid",
            mesh_params = { grid = 5 },
            motion = { kind = "fixed", at = { x + puff[1] * lean, -1.0 + puff[2], puff[3] } },
            pulse = { amount = 0.12, cycles = per_band, phase = p * 0.07 },
        }
    end
end
-- }}}
cloud(-(1.55 + 0.75), 1)
cloud(1.55 + 0.75, -1)
return {
    name = "rainbow-arch",
    size = 320, frames = 120, delay_cs = 4,
    camera = { distance = 7.4, fov = 46, tilt = 0.08 },
    stars = { count = 90, seed = 101, hues = { "gold", "ice", "rose" } },
    instances = instances,
}
