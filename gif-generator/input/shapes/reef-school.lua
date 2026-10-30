-- reef-school: a school of small fish -- stretched octahedra in sea blues and
-- greens -- swims a looping figure through a coral reef of three slowly
-- turning shapes. Each fish points along its own path and takes on the
-- coral's colour as it brushes past; each coral swells when the school is near.
local fish_hues = { "teal", "ice", "jade", "teal", "ice", "jade", "teal", "ice", "jade", "ice", "teal", "jade" }

local instances = {
    { tag = "coral", mesh = "icosahedron", hue = "ember", scale = 0.65, style = "glow",
      motion = { kind = "fixed", at = { -1.1, -0.5, 0 } }, spin = { axis = { 0, 1, 0.3 }, turns = 1 },
      reacts = { { to = "fish", within = 1.4, effect = "swell", amount = 0.35 } } },
    { tag = "coral", mesh = "star_prism", hue = "rose", scale = 0.55, style = "glow",
      motion = { kind = "fixed", at = { 1.2, 0.4, -0.3 } }, spin = { axis = { 0.2, 1, 0 }, turns = -1 },
      reacts = { { to = "fish", within = 1.4, effect = "swell", amount = 0.35 } } },
    { tag = "coral", mesh = "torus", hue = "violet", scale = 0.55, style = "solid",
      motion = { kind = "fixed", at = { 0.1, -0.1, 1.1 } }, spin = { axis = { 1, 0.4, 0 }, turns = 1 },
      reacts = { { to = "fish", within = 1.4, effect = "swell", amount = 0.35 } } },
}

-- The school: every fish follows the same knotted path, a little behind the
-- one before it and a little off to one side, so they read as a shoal
-- rather than a single-file line.
for i, hue in ipairs(fish_hues) do
    local lag = (i - 1) * 0.018
    local wobble = ((i % 3) - 1) * 0.28
    instances[#instances + 1] = {
        tag = "fish", mesh = "octahedron", hue = hue, scale = 0.2, stretch = { 1.9, 0.75, 0.6 },
        style = "glow", face_motion = true,
        motion = { kind = "lissajous", size = { 2.7, 1.2 + wobble, 1.9 - wobble }, freq = { 1, 2, 1 },
                   phase = -lag, shift = { 0, 0.1 * (i % 2), 0.25 } },
        reacts = { { to = "coral", within = 1.3, effect = "bleed_hue", amount = 1.0 } },
    }
end

return {
    name = "reef-school",
    size = 320, frames = 120, delay_cs = 4,
    camera = { distance = 6.4, fov = 46, tilt = 0.35 },
    stars = { count = 60, seed = 47, hues = { "ice", "teal" } },
    instances = instances,
}
