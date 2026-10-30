-- misspelled: a scene with one mistake in each of a dozen places, for the
-- wall's test (050-shape-wall-test.lua). Every one must be reported in one
-- pass, each with the nearest legal word; nothing may be filmed.
return {
    name = "misspelled",
    size = 48, frams = 6, delay_cs = 5,
    camera = { fov = 50, motion = { kind = "orbit", radus = 4, cycles = 1 } },
    instances = {
        { tag = "bloom", mesh = "icosahedorn", hue = "rsoe", style = "glwo",
          spin = { axis = { 0, 1, 0 }, trns = 1 },
          reacts = { { to = "hammr", within = 2, effect = "shater", amount = 1 } } },
        { tag = "hammer", mesh = "cube", hue = "gold", scale = 0.4,
          motion = { kind = "swing", from = { -2, 0, 0 }, to = { 2, 0, 0 }, cycels = 1 } },
        { tag = "ring", mesh = "torus", hue = "teal", mesh_params = { majr = 0.6 },
          motion = { kind = "orbt", radius = 1, cycles = 1 } },
    },
    beams = { { from = "bloon", to = "hammer" } },
}
