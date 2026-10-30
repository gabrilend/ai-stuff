-- broken.lua — a two-space score with a dozen mistakes across both
-- spaces, for the wall to report all at once (054-two-spaces-test.lua).
-- Every line here is wrong on purpose; do not fix it.

canvas{ size = 256, fps = 25, length = 4.0, seed = 7, background = "skye" }

camera{ distance = 7.5, fvo = 44 }

world{ starz = { count = 60 } }

shape{ tag = "wanderer", mesh = "icosahedron", hue = "violt",
       motion = { kind = "orbit", radius = 2.4, cycles = 1.5 } }

pane{ name = "sign", at = { 0, 0, -1 }, size = { 3, 3 }, pixels = 192 }

pane{ name = "backdrop", place = "back", pixels = 64 }

pane{ name = "front", place = "front" }

stroke{ name = "circle", pane = "sing", at = 0.0, lasts = 4.0,
        color = "gold", fade = "in-out",
        shape = arc{ center = { 96, 96 }, radius = 70,
                     from = 12, to = 11, turn = "clockwise" } }

stroke{ name = "spark", at = 0.0, lasts = 4.0, color = "jade",
        fade = "in-out", shape = point{ at = tip("wanderr") } }

stroke{ name = "glint", pane = "sign", at = 0.0, lasts = 1.0,
        color = "ice", fade = "in-out",
        shape = point{ at = tip("wanderer") } }

stroke{ name = "veil", pane = "backdrop", at = 0.0, lasts = 1.0,
        color = "rose", fade = "in-out",
        shape = fill{ vertices = { { 0, 0 }, tip("wanderer"), { 50, 50 } },
                      sweep = "radial" } }
