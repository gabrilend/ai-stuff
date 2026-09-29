-- jellyfish-flythrough: the camera glides slowly round a pinched loop through a
-- dark sea scattered with small gold stars and slow jellyfish, always looking
-- the way it is going. The jellyfish only breathe and drift a little; all the
-- travel is the camera's.
--
-- How it came to be this way. The first cut flew a figure of eight twice as
-- fast, and the owner found it "too fast, the models are often out of
-- frame"; the second glided a plain ellipse with jellyfish lining the way.
-- Then the owner asked: "ensure we don't pass through any jellyfish, and they
-- should be evenly distributed around the viewer. Also, we shouldn't do a
-- strict circle for the camera movement, we should do an almost 8 shape,
-- except we bend toward the middle, then bend toward the out, then curve
-- around, then bend toward the middle, then bend toward the out, then curve
-- around and repeat." So the camera now flies the `lobed` loop -- pinched in
-- twice, never crossing itself -- and the jellyfish stand beside it in turn
-- inside and outside the loop, above and below the lens. Three promises are
-- checked by tests/framing-test.lua: at least two bells in view in every
-- frame (`framing`), the lens never within a bell's reach or a tentacle's
-- (`clearance`), and as many jellyfish on each side of the path as on the
-- other (built in, below).
local instances = {}

-- {{{ local function jellyfish()
local function jellyfish(at, hue, rim, phase)
    local drift = { kind = "fixed", at = at,
                    sway = { { vector = { 0, 0.12, 0 }, cycles = 2, phase = phase } } }
    instances[#instances + 1] = {
        tag = "bell", mesh = "superball", hue = hue, scale = 0.5, stretch = { 1, 0.62, 1 },
        mesh_params = { grid = 5 }, motion = { kind = "fixed", at = { at[1], at[2] + 0.15, at[3] },
            sway = drift.sway },
        pulse = { amount = 0.14, cycles = 3, phase = phase, axes = { 1, -0.8, 1 } },
    }
    instances[#instances + 1] = {
        tag = "hem", mesh = "torus", hue = rim, scale = 0.58, style = "solid",
        mesh_params = { major = 0.8, minor = 0.09, rings = 24, sides = 6 },
        motion = drift, pulse = { amount = 0.15, cycles = 3, phase = phase - 0.05, axes = { 1, 0, 1 } },
    }
    for arm = 0, 3 do
        local a = arm * math.pi / 2 + 0.4
        for k = 1, 4 do
            instances[#instances + 1] = {
                tag = "tentacle", mesh = "octahedron", hue = rim, scale = 0.06,
                motion = { kind = "fixed", at = { at[1] + 0.25 * math.cos(a), at[2] - 0.15 - k * 0.18, at[3] + 0.25 * math.sin(a) },
                           sway = { drift.sway[1], { vector = { 0.04 * k * math.cos(a), 0, 0.04 * k * math.sin(a) },
                                    cycles = 3, phase = phase - k * 0.07 } } },
            }
        end
    end
end
-- }}}

-- The camera's loop, in the same numbers the camera is given below: its
-- distance from the middle is RADIUS * (1 - PINCH * cos(2 * angle)).
local RADIUS, PINCH, LOBES = 3.7, 0.3, 2
-- {{{ local function loop_point()
local function loop_point(angle)
    local r = RADIUS * (1 - PINCH * math.cos(LOBES * angle))
    return r * math.cos(angle), r * math.sin(angle)
end
-- }}}

-- Sixteen jellyfish, one at each sixteenth of the way round, standing just
-- off the loop at right angles to it: in turn inside the loop and outside it,
-- and in turn above and below the lens -- so wherever the camera is, there
-- are jellyfish to its left and right, above and below, ahead and behind.
-- They stand SIDE from the path, further than a bell's reach, so the camera
-- never passes through one.
local SIDE = 1.15
local colours = { { "violet", "ice" }, { "rose", "gold" }, { "teal", "violet" }, { "ice", "rose" }, { "violet", "gold" } }
for j = 0, 15 do
    local angle = (j + 0.5) / 16 * 2 * math.pi
    local x, z = loop_point(angle)
    local ax, az = loop_point(angle + 1e-4)
    local dx, dz = ax - x, az - z
    local len = math.sqrt(dx * dx + dz * dz)
    -- the outward direction square to the path is (dz, -dx); inside is its opposite
    local side = (j % 2 == 0) and SIDE or -SIDE
    local height = (math.floor(j / 2) % 2 == 0) and 0.55 or -0.75
    local c = colours[1 + j % #colours]
    jellyfish({ x + dz / len * side, height, z - dx / len * side }, c[1], c[2], j * 0.1)
end

-- a scatter of small stars, placed by a fixed recipe so the film repeats
local seed = 7
-- {{{ local function next_random()
local function next_random()
    seed = (seed * 16807) % 2147483647
    return seed / 2147483647
end
-- }}}
for s = 1, 26 do
    instances[#instances + 1] = {
        tag = "star", mesh = "star_prism", hue = (s % 3 == 0) and "rose" or "gold", scale = 0.09,
        motion = { kind = "fixed", at = { next_random() * 10 - 5, next_random() * 3.2 - 1.6, next_random() * 10 - 5 } },
        spin = { axis = { 0, 1, 0 }, turns = (s % 2 == 0) and 1 or -1 },
    }
end
return {
    name = "jellyfish-flythrough",
    size = 320, frames = 200, delay_cs = 6,
    camera = { fov = 70,
               motion = { kind = "lobed", radius = RADIUS, pinch = PINCH, lobes = LOBES, cycles = 1,
                          target = "ahead", lead = 0.12 },
               roll = { amount = 0.05, cycles = 1 } },
    framing = { tag = "bell", at_least = 2 },
    clearance = { { tag = "bell", radius = 0.75 }, { tag = "hem", radius = 0.75 }, { tag = "tentacle", radius = 0.3 } },
    stars = { count = 90, seed = 233, hues = { "ice", "violet", "gold" } },
    instances = instances,
}
