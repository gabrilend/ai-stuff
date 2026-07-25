-- showpiece.lua — the forge: written to make the workers sweat
-- honestly. Three rings sweep nearly whole circles at different
-- depths and hues, a violet heart blooms radially in the center,
-- and gold seals fade in between the rings' resting tips. Densities
-- run several thousand particles at the peak on a 512 canvas —
-- denser work than the vision asks, which is the point.

canvas{ size = 512, fps = 25, length = 6.0, seed = 512 }

stroke{ name = "ring-a", at = 0.0, lasts = 2.4,
        color = "gold", fade = "hold", ease = "stroke",
        shape = arc{ center = {256, 256}, radius = 190,
                     from = "12 o'clock", to = "11 o'clock",
                     turn = "clockwise" },
        emit = { rate = 1800, spread = 3, speed = 55, aim = 0.85,
                 drag = 2.2, jitter = 30, life = 0.8 } }

stroke{ name = "ring-b", at = 0.8, lasts = 2.4,
        color = "ice", fade = "hold", ease = "stroke",
        shape = arc{ center = {256, 256}, radius = 140,
                     from = "6 o'clock", to = "5 o'clock",
                     turn = "clockwise" },
        emit = { rate = 1800, spread = 3, speed = 50, aim = 0.85,
                 drag = 2.2, jitter = 30, life = 0.8 } }

stroke{ name = "ring-c", at = 1.6, lasts = 2.4,
        color = "rose", fade = "hold", ease = "stroke",
        shape = arc{ center = {256, 256}, radius = 95,
                     from = "9 o'clock", to = "8 o'clock",
                     turn = "counterclockwise" },
        emit = { rate = 1600, spread = 2.5, speed = 45, aim = 0.85,
                 drag = 2.2, jitter = 26, life = 0.8 } }

stroke{ name = "heart", at = 3.6, lasts = 1.8,
        color = "violet", fade = "in-out", ease = "smoothstep",
        shape = fill{ vertices = { {256, 176}, {326, 256},
                                   {256, 336}, {186, 256} },
                      sweep = "radial" },
        emit = { rate = 3200, spread = 2, speed = 8, aim = 0,
                 drag = 2.5, jitter = 12, life = 1.0 } }

stroke{ at = 4.6, lasts = 1.2, color = "gold", fade = "in-out",
        shape = fill{ vertices = { tip("ring-a"), tip("ring-b") },
                      sweep = "at-once" },
        emit = { rate = 1200, spread = 1.5, speed = 6, aim = 0,
                 drag = 2.5, jitter = 10, life = 0.8 } }

stroke{ at = 4.6, lasts = 1.2, color = "gold", fade = "in-out",
        shape = fill{ vertices = { tip("ring-b"), tip("ring-c") },
                      sweep = "at-once" },
        emit = { rate = 1200, spread = 1.5, speed = 6, aim = 0,
                 drag = 2.5, jitter = 10, life = 0.8 } }
