-- butterfly-weave: five butterflies -- each a slim body and two hinged wings
-- that flap -- wander slow loops over three low flowers, while the camera
-- weaves a figure-eight among them, always watching the middle of the meadow.
-- (Pulled back from its first framing: the owner asked for it "zoomed out a
-- bit".)
local instances = {}

-- {{{ local function butterfly()
-- A body with a wing on each side. All three parts share one path and point
-- nose-first along it; each wing is hinged at the body (pivot) and flaps by
-- rocking about the body's length, the two wings mirrored.
local function butterfly(path, wing_hue, body_hue, flap_phase)
    instances[#instances + 1] = {
        tag = "butterfly", mesh = "octahedron", hue = body_hue, scale = 0.25, stretch = { 1.6, 0.35, 0.35 },
        face_motion = true, motion = path,
    }
    for _, side in ipairs({ 1, -1 }) do
        instances[#instances + 1] = {
            tag = "wing", mesh = "octahedron", hue = wing_hue, scale = 0.44, stretch = { 0.55, 0.05, 0.7 },
            pivot = { 0, 0, 0.7 * side }, face_motion = true, motion = path,
            rock = { axis = { 1, 0, 0 }, center = 0.25 * side, amount = 0.75 * side, cycles = 10, phase = flap_phase },
        }
    end
end
-- }}}

local wings = { { "rose", "gold" }, { "ice", "violet" }, { "gold", "ember" }, { "violet", "ice" }, { "jade", "gold" } }
for b, colours in ipairs(wings) do
    butterfly({ kind = "lissajous", size = { 1.3, 0.35, 1.1 }, freq = { 1, 2, 1 },
                center = { math.cos(b * 1.26) * 0.9, 0.35 + 0.12 * b, math.sin(b * 1.26) * 0.9 },
                phase = b / 5, shift = { 0, 0.1 * b, 0.25 } },
              colours[1], colours[2], b * 0.17)
end

-- three flowers, each eight petals round a gold heart, barely stirring
for f, spot in ipairs({ { -1.2, -0.6 }, { 1.1, -0.3 }, { 0.1, 1.2 } }) do
    for i = 0, 7 do
        instances[#instances + 1] = {
            tag = "petal", mesh = "octahedron", hue = (f == 2) and "violet" or ((i % 2 == 0) and "rose" or "ember"),
            scale = 0.28, stretch = { 0.95, 0.12, 0.42 }, pivot = { 0.95, 0, 0 },
            motion = { kind = "fixed", at = { spot[1], -1.0, spot[2] } },
            orient = { axis = { 0, 1, 0 }, angle = i * math.pi / 4 + f },
            rock = { axis = { 0, 0, 1 }, center = 0.35, amount = 0.06, cycles = 2, phase = f * 0.2 },
        }
    end
    instances[#instances + 1] = {
        tag = "heart", mesh = "icosahedron", hue = "gold", scale = 0.16,
        motion = { kind = "fixed", at = { spot[1], -0.95, spot[2] } }, spin = { axis = { 0, 1, 0 }, turns = 1 },
    }
end
return {
    name = "butterfly-weave",
    size = 320, frames = 144, delay_cs = 4,
    camera = { fov = 50,
               motion = { kind = "fly", size = { 5.6, 0.6, 4.9 }, freq = { 1, 2, 1 }, shift = { 0.25, 0, 0 },
                          center = { 0, 1.5, 0 }, target = { 0, 0.3, 0 } } },
    stars = { count = 100, seed = 241, hues = { "gold", "rose", "jade" } },
    instances = instances,
}
