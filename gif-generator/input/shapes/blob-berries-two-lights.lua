-- blob-berries-two-lights: a bunch of soft berries on a leafy stem, bobbing
-- gently and melting into their neighbours, lit by two lamps of different
-- colours -- a rose one and an ice one -- circling the bunch in opposite
-- directions on arms of their own. Where both lights fall the bands add up;
-- each berry shows two sets of stacked brightness levels, one per lamp,
-- sweeping past each other.
local instances = {
    { tag = "machine-rose", motion = { kind = "fixed", at = { 0, 0, 0 } }, spin = { axis = { 0, 1, 0 }, turns = 1 },
      parts = { { tag = "arm", mesh = "octahedron", hue = "rose", dim = 0.4, stretch = { 1.1, 0.025, 0.025 },
                  pivot = { 1.1, 0, 0 }, orient = { axis = { 0, 0, 1 }, angle = 0.35 },
                  parts = { { tag = "lamp-rose", mesh = "icosahedron", hue = "rose", scale = 0.12, offset = { 2.2, 0, 0 } } } } } },
    { tag = "machine-ice", motion = { kind = "fixed", at = { 0, 0, 0 } }, spin = { axis = { 0, 1, 0 }, turns = -1, phase = 0.5 },
      parts = { { tag = "arm", mesh = "octahedron", hue = "ice", dim = 0.4, stretch = { 1.1, 0.025, 0.025 },
                  pivot = { 1.1, 0, 0 }, orient = { axis = { 0, 0, 1 }, angle = -0.3 },
                  parts = { { tag = "lamp-ice", mesh = "icosahedron", hue = "ice", scale = 0.12, offset = { 2.2, 0, 0 } } } } } },
    -- a stem and a leaf, the only hard shapes
    { tag = "stem", mesh = "cone", hue = "jade", dim = 0.7, stretch = { 0.08, 0.5, 0.08 }, mesh_params = { segments = 6 },
      motion = { kind = "fixed", at = { 0, 1.15, 0 } } },
    { tag = "leaf", mesh = "octahedron", hue = "jade", stretch = { 0.45, 0.04, 0.22 }, pivot = { 0.45, 0, 0 },
      motion = { kind = "fixed", at = { 0, 1.35, 0 } }, rock = { axis = { 0, 0, 1 }, center = 0.3, amount = 0.08, cycles = 2 } },
}
-- the bunch: a rough cone of berries, wider at the top, each bobbing a little
local berries = {
    { 0, 0.8, 0 }, { 0.35, 0.65, 0.1 }, { -0.3, 0.62, 0.2 }, { 0.05, 0.6, -0.35 },
    { 0.25, 0.3, -0.15 }, { -0.25, 0.3, -0.1 }, { 0.05, 0.28, 0.3 }, { 0, 0.0, 0 },
    { 0.2, -0.05, 0.12 }, { -0.12, -0.3, 0.05 },
}
-- warm berries: a coloured lamp multiplies the colour it falls on, and dark
-- violet under a rose or ice lamp came out nearly black
local hues = { "rose", "ember", "gold", "rose", "violet", "ember", "rose", "gold", "rose", "ember" }
for k, p in ipairs(berries) do
    instances[#instances + 1] = {
        tag = "berry", hue = hues[k], scale = 0.24,
        blob = { group = "bunch", bands = 3, soft = 0.2 },
        motion = { kind = "fixed", at = p, sway = { { vector = { 0, 0.05, 0 }, cycles = 2, phase = k * 0.13 } } },
    }
end
return {
    name = "blob-berries-two-lights",
    size = 320, frames = 144, delay_cs = 4,
    jobs = 4,
    lights = { { tag = "lamp-rose", hue = "rose", strength = 1.5 }, { tag = "lamp-ice", hue = "ice", strength = 1.5 } },
    camera = { fov = 44, motion = { kind = "orbit", radius = 4.2, height = 1.0, cycles = 1, target = { 0, 0.3, 0 },
                                    bob = { amount = 0.4, cycles = 1 } } },
    framing = { tag = "berry", at_least = 8 },
    stars = { count = 100, seed = 317, hues = { "rose", "ice", "violet" } },
    instances = instances,
}
