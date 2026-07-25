-- orbit.lua — the minimal reference score: one ember stroke sweeping
-- three quarters of a circle. The simplest complete sentence the
-- language can speak; useful as a first example and a quick smoke
-- test of the whole pipeline.

canvas{ size = 256, fps = 25, length = 3.0, seed = 7 }

stroke{ name = "orbit", at = 0.0, lasts = 2.4,
        color = "ember", fade = "in-out", ease = "smoothstep",
        shape = arc{ center = {128, 128}, radius = 80,
                     from = "12 o'clock", to = "9 o'clock",
                     turn = "clockwise" },
        emit = { rate = 500, speed = 20, aim = 0.6, drag = 2.5,
                 life = 0.8 } }
