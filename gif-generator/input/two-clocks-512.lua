-- two-clocks-512.lua — the founding vision at double scale: every
-- coordinate, spread, and speed doubled, densities doubled to keep
-- the glow honest across four times the ground. The phase-5 demo
-- renders this twice — one worker, then many — and demands the same
-- bytes from both.

canvas{ size = 512, fps = 25, length = 4.6, seed = 77 }

stroke{ name = "left-hand", at = 0.0, lasts = 2.0,
        color = "ember", fade = "hold", ease = "stroke",
        shape = arc{ center = {152, 216}, radius = 104,
                     from = "12 o'clock", to = "7 o'clock",
                     turn = "clockwise" },
        emit = { rate = 1400, spread = 4.4, speed = 52, aim = 0.7,
                 drag = 3.0, jitter = 36, life = 0.65,
                 life_jitter = 0.35 } }

stroke{ name = "right-hand", at = 0.0, lasts = 2.0,
        color = "ember", fade = "hold", ease = "stroke",
        shape = arc{ center = {360, 216}, radius = 104,
                     from = "12 o'clock", to = "5 o'clock",
                     turn = "counterclockwise" },
        emit = { rate = 1400, spread = 4.4, speed = 52, aim = 0.7,
                 drag = 3.0, jitter = 36, life = 0.65,
                 life_jitter = 0.35 } }

stroke{ name = "left-rest", at = 2.0, lasts = 2.2,
        color = "ember", fade = "hold",
        shape = point{ at = tip("left-hand") },
        emit = { rate = 180, spread = 3, speed = 12, aim = 0,
                 drag = 2, jitter = 20, life = 0.5 } }

stroke{ name = "right-rest", at = 2.0, lasts = 2.2,
        color = "ember", fade = "hold",
        shape = point{ at = tip("right-hand") },
        emit = { rate = 180, spread = 3, speed = 12, aim = 0,
                 drag = 2, jitter = 20, life = 0.5 } }

stroke{ name = "seal-line", at = 2.2, lasts = 0.9,
        color = "violet", fade = "in",
        shape = fill{ vertices = { tip("left-hand"),
                                   tip("right-hand") },
                      sweep = "at-once" },
        emit = { rate = 1600, spread = 2.4, speed = 10, aim = 0,
                 drag = 2.5, jitter = 16, life = 0.7 } }

stroke{ name = "seal-fill", at = 3.0, lasts = 1.2,
        color = "violet", fade = "in",
        shape = fill{ vertices = { tip("left-hand"),
                                   tip("right-hand"),
                                   {256, 416} },
                      sweep = "downward" },
        emit = { rate = 2800, spread = 2.8, speed = 8, aim = 0,
                 drag = 2.5, jitter = 16, life = 0.9,
                 life_jitter = 0.3 } }
