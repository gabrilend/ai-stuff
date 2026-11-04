-- hill-to-the-stars: five balls roll up a green hill from all sides, each
-- turning exactly as far as it has rolled. Reaching the top, each becomes a
-- yellow star and rockets straight up into space trailing sparks, then --
-- vanished -- it is back at the foot of the hill to roll again. The camera
-- circles slowly, once a loop.
local GROUND = {
    size = 9, grid = 26, base = -1.2,
    hills = { { 0, 0, 2.0, 1.7 } },
    waves = { { 0.06, 1.3, 0.9, 0 } },
}
local RADIUS = 0.36
local TOP = -1.2 + 2.0 + RADIUS       -- the ball's height resting on the summit (the ripple is zero there)
-- Four balls, a quarter of a loop apart. (Five, a fifth apart, arrived too
-- soon: the owner saw each "overlapping the previous ball as it's
-- launching". The pause at the summit is also shorter now, so each star is
-- well clear before the next ball crests. The `spacing` promise below is
-- checked frame by frame: no ball or star ever comes within a ball's
-- diameter plus a little of another.)
--
-- Then "needs juuuust a bit more time. Can you double the increase you just
-- made?" The gap had grown from 1.2 seconds (a fifth of a 6-second loop) to
-- 1.5 (a quarter); doubling that 0.3 makes it 1.8. Each ball's trip keeps its
-- speed -- it still takes what used to be the whole 6-second loop -- and the
-- loop grows to 7.2 seconds (180 frames), so the extra time falls between
-- balls, hidden, and each quarter-loop gap is 1.8 seconds. TRIP is the share
-- of the loop one trip now takes; every moment on the route is scaled by it.
local TRIP = 150 / 180
local balls = { "rose", "ice", "violet", "ember" }
local instances = {
    { tag = "hill", mesh = "terrain", hue = "jade", dim = 0.42, style = "solid", mesh_params = GROUND },
}
for k, hue in ipairs(balls) do
    local a = k * 2 * math.pi / #balls + 0.3
    instances[#instances + 1] = {
        tag = "ball", mesh = "superball", hue = hue, scale = RADIUS, mesh_params = { grid = 4 }, style = "glow",
        -- the route: roll from the foot to the summit (resting on the ground,
        -- lifted by the radius), pause, lift off, soar out of sight; the
        -- size drops to nothing up there, and the jump back to the foot is
        -- made unseen
        motion = { kind = "keyframes", cycles = 1, phase = (k - 1) / #balls, lift = RADIUS,
                   points = { { 0.0, 3.7 * math.cos(a), 3.7 * math.sin(a) },
                              { 0.5 * TRIP, 0, 0 },
                              { 0.56 * TRIP, 0, 0, TOP },
                              { 0.8 * TRIP, 0, 0, 7.5 } },
                   sizes = { { 0.0, 0 }, { 0.05 * TRIP, 1 }, { 0.76 * TRIP, 1 }, { 0.81 * TRIP, 0 } } },
        roll = { radius = RADIUS },
        becomes = { at = 0.52 * TRIP, over = 0.03 * TRIP, mesh = "star_prism", hue = "gold", scale = 0.42, roll = false,
                    tag = "star", spin = { axis = { 0, 1, 0 }, turns = 3 },
                    trail = { count = 9, spacing = 0.007, shrink = 0.84, mesh = "octahedron",
                              hues = { "gold", "ember", "rose" } } },
    }
end
return {
    name = "hill-to-the-stars",
    size = 320, frames = 180, delay_cs = 4,
    ground = GROUND,
    camera = { fov = 50,
               motion = { kind = "orbit", radius = 5.6, height = 1.9, cycles = 1, target = { 0, 0.9, 0 } } },
    framing = { tag = "ball", at_least = 1 },
    spacing = { tags = { "ball", "star" }, at_least = 2 * RADIUS + 0.1 },
    stars = { count = 130, seed = 251, hues = { "gold", "ice", "rose" } },
    instances = instances,
}
