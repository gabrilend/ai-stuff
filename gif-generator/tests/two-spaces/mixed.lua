-- mixed.lua — the first score that speaks both spaces (issue 701d): a
-- violet shape circles a sign of glass standing in the world, passing in
-- front of the sign and behind it; a gold circle is painted on the sign,
-- a jade spark rides the front pane after the shape wherever it appears,
-- and an ice sweep glows on the back pane behind everything.

canvas{ size = 256, fps = 25, length = 4.0, seed = 7, background = "sky" }

camera{ distance = 7.5, fov = 44, tilt = 0.25 }

world{ stars = { count = 60, seed = 3, hues = { "ice", "violet" } } }

shape{ tag = "wanderer", mesh = "icosahedron", hue = "violet", scale = 0.55,
       style = "glow",
       motion = { kind = "orbit", radius = 2.4, cycles = 1, phase = 0.0 },
       spin = { axis = { 0.3, 1, 0.2 }, turns = 2 } }

pane{ name = "sign", at = { 0, 0.2, -0.6 }, facing = { 0, 0, 1 },
      size = { 3, 3 }, pixels = 192 }

pane{ name = "backdrop", place = "back" }

stroke{ name = "circle", pane = "sign", at = 0.0, lasts = 4.0,
        color = "gold", fade = "in-out", ease = "linear",
        shape = arc{ center = { 96, 96 }, radius = 70,
                     from = "12 o'clock", to = "11 o'clock",
                     turn = "clockwise" },
        emit = { rate = 600, speed = 8, aim = 0.4, drag = 2.5, life = 1.6 } }

stroke{ name = "spark", at = 0.0, lasts = 4.0,
        color = "jade", fade = "in-out",
        shape = point{ at = tip("wanderer") },
        emit = { rate = 300, speed = 14, aim = 0.0, drag = 3.0, life = 0.5 } }

stroke{ name = "sweep", pane = "backdrop", at = 0.5, lasts = 3.0,
        color = "ice", fade = "in-out", ease = "smoothstep",
        shape = line{ from = { 20, 230 }, to = { 236, 200 } },
        emit = { rate = 400, speed = 10, aim = 0.3, drag = 2.0, life = 1.2 } }
