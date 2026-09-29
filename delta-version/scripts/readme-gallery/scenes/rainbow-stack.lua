-- rainbow-stack: seven cubes in rainbow order stand in a swaying column,
-- turning alternately left and right. The column breathes -- the cubes drift
-- apart along a gentle S-curve, then press together into a straight tower --
-- and whenever neighbours touch, each borrows the other's colour, so the
-- rainbow smears and clears with every breath.
local order = { "violet", "ice", "teal", "jade", "gold", "ember", "rose" }
local instances = {}
for i, hue in ipairs(order) do
    local height = (i - 4)
    local sway = math.sin(height * 0.9) * 0.9
    instances[#instances + 1] = {
        tag = "block", mesh = "cube", hue = hue, scale = 0.52, style = "glow",
        motion = { kind = "swing", from = { 0, height * 0.84, 0 },
                   to = { sway, height * 1.2, -sway * 0.6 }, cycles = 2 },
        spin = { axis = { 0, 1, 0 }, turns = (i % 2 == 0) and 1 or -1, phase = i * 0.04 },
        reacts = { { to = "block", within = 1.05, effect = "bleed_hue", amount = 1.0 } },
    }
end
return {
    name = "rainbow-stack",
    size = 320, frames = 96, delay_cs = 4,
    camera = { distance = 9.0, fov = 48, tilt = 0.25 },
    stars = { count = 90, seed = 59, hues = { "gold", "rose", "ice", "violet" } },
    instances = instances,
}
