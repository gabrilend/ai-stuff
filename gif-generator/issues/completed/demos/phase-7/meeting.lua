-- meeting: two moons circle a sign of glass, a gold cube passing in front
-- of it and a violet icosahedron behind it. A rose ring is painted on the
-- sign; a jade spark rides each moon across the picture; a teal comet
-- flies from one moon to the other on the front pane, and an ice sweep
-- glows on the pane behind everything.

canvas{ size = 256, fps = 25, length = 4.0, seed = 21, background = "sky" }

camera{ distance = 7.5, fov = 44, tilt = 0.25 }

world{ stars = { count = 70, seed = 9, hues = { "ice", "violet", "gold" } } }

shape{ tag = "near", mesh = "cube", hue = "gold", scale = 0.42, style = "glow",
       motion = { kind = "orbit", radius = 2.3, cycles = 1, phase = 0.0 },
       spin = { axis = { 1, 1, 0.2 }, turns = 2 } }

shape{ tag = "far", mesh = "icosahedron", hue = "violet", scale = 0.5, style = "glow",
       motion = { kind = "orbit", radius = 2.3, cycles = 1, phase = 0.5 },
       spin = { axis = { 0.3, 1, 0.2 }, turns = 2 } }

pane{ name = "sign", at = { 0, 0.2, -0.4 }, facing = { 0, 0, 1 },
      size = { 2.6, 2.6 }, pixels = 160 }

pane{ name = "backdrop", place = "back" }

stroke{ name = "ring", pane = "sign", at = 0.0, lasts = 4.0,
        color = "rose", fade = "in-out", ease = "linear",
        shape = arc{ center = { 80, 80 }, radius = 58,
                     from = "12 o'clock", to = "11 o'clock",
                     turn = "clockwise" },
        emit = { rate = 500, speed = 8, aim = 0.4, drag = 2.5, life = 1.6 } }

stroke{ at = 0.0, lasts = 4.0, color = "jade", fade = "in-out",
        shape = point{ at = tip("near") },
        emit = { rate = 260, speed = 14, aim = 0.0, drag = 3.0, life = 0.5 } }

stroke{ at = 0.0, lasts = 4.0, color = "jade", fade = "in-out",
        shape = point{ at = tip("far") },
        emit = { rate = 260, speed = 14, aim = 0.0, drag = 3.0, life = 0.5 } }

stroke{ name = "comet", at = 0.5, lasts = 3.0, color = "teal", fade = "in-out",
        ease = "smoothstep",
        shape = line{ from = tip("near"), to = tip("far") },
        emit = { rate = 500, speed = 10, aim = 0.2, drag = 2.0, life = 0.9 } }

stroke{ name = "sweep", pane = "backdrop", at = 0.3, lasts = 3.4,
        color = "ice", fade = "in-out", ease = "smoothstep",
        shape = line{ from = { 16, 228 }, to = { 240, 196 } },
        emit = { rate = 350, speed = 10, aim = 0.3, drag = 2.0, life = 1.2 } }
