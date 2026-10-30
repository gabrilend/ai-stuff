-- shell-spiral: a seashell drawn as a logarithmic spiral of tetrahedra, each
-- a little larger than the last, winding up and outward like a conch. The
-- whole shell turns; a swelling wave runs from its tip to its mouth, and a
-- pearl rolls along the spiral's inside, tinting each chamber as it passes.
local chambers = 48
local growth = 0.064       -- each chamber this much larger than the one before
local sweep = 2.6          -- turns of the spiral from tip to mouth
local hues = { "rose", "ember", "gold", "ember", "rose", "violet" }
local instances = {}
for k = 0, chambers - 1 do
    local f = k / (chambers - 1)
    local radius = 0.12 * math.exp(growth * k)
    instances[#instances + 1] = {
        tag = "chamber", mesh = "tetrahedron", hue = hues[1 + (k % #hues)],
        scale = 0.05 + 0.2 * radius, style = "glow",  -- neighbours nearly touch
        -- every chamber rides one shared turn of the shell; its phase is its
        -- angle along the spiral, its radius and height its place in the whorl
        motion = { kind = "orbit", radius = radius, cycles = 1, phase = f * sweep % 1,
                   center = { 0, 1.1 - 2.0 * f, 0 } },
        spin = { axis = { 1, 1, 0 }, turns = 1, phase = f },
        pulse = { amount = 0.35, cycles = 2, phase = -f },
        reacts = { { to = "pearl", within = 0.9, effect = "bleed_hue", amount = 1.2 } },
    }
end
instances[#instances + 1] = {
    tag = "pearl", mesh = "superball", hue = "ice", scale = 0.2, style = "solid", mesh_params = { grid = 5 },
    motion = { kind = "orbit", radius = 0.9, cycles = 3, phase = 0, bob = { amount = 0.9, cycles = 1 } },
    reacts = { { to = "chamber", within = 0.8, effect = "glow", amount = 1.0 } },
}
return {
    name = "shell-spiral",
    size = 320, frames = 120, delay_cs = 4,
    camera = { distance = 7.6, fov = 46, tilt = 0.62 },
    stars = { count = 80, seed = 113, hues = { "ice", "teal", "rose" } },
    instances = instances,
}
