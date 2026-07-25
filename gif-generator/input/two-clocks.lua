-- two-clocks.lua — the founding vision, translated into the score
-- vocabulary. Each stroke carries the sentence of prose it
-- translates; this file is the demonstration that the language can
-- hold the vision's own words nearly one for one.
-- (notes/vision is the original text.)

canvas{ size = 256, fps = 25, length = 4.6, seed = 77 }

-- "Two circles, both starting at 12 o'clock and sweeping to around
--  7... sweeping circle, slow at first but then fast like a stroke.
--  the particles are drawn at the tip of the hands, and they are
--  both oriented inward - the one on the left starts at 12 and goes
--  to 7"
stroke{ name = "left-hand", at = 0.0, lasts = 2.0,
        color = "ember", fade = "hold", ease = "stroke",
        shape = arc{ center = {76, 108}, radius = 52,
                     from = "12 o'clock", to = "7 o'clock",
                     turn = "clockwise" },
        emit = { rate = 700, spread = 2.2, speed = 26, aim = 0.7,
                 drag = 3.0, jitter = 18, life = 0.65,
                 life_jitter = 0.35 } }

-- "the one on the right is reversed such that it starts at 12 and
--  sweeps around to about 5, counterclockwise"
stroke{ name = "right-hand", at = 0.0, lasts = 2.0,
        color = "ember", fade = "hold", ease = "stroke",
        shape = arc{ center = {180, 108}, radius = 52,
                     from = "12 o'clock", to = "5 o'clock",
                     turn = "counterclockwise" },
        emit = { rate = 700, spread = 2.2, speed = 26, aim = 0.7,
                 drag = 3.0, jitter = 18, life = 0.65,
                 life_jitter = 0.35 } }

-- the resting tips keep a quiet ember while the seal is drawn —
-- the vision keeps them as the triangle's upper corners
stroke{ name = "left-rest", at = 2.0, lasts = 2.2,
        color = "ember", fade = "hold",
        shape = point{ at = tip("left-hand") },
        emit = { rate = 90, spread = 1.5, speed = 6, aim = 0,
                 drag = 2, jitter = 10, life = 0.5 } }

stroke{ name = "right-rest", at = 2.0, lasts = 2.2,
        color = "ember", fade = "hold",
        shape = point{ at = tip("right-hand") },
        emit = { rate = 90, spread = 1.5, speed = 6, aim = 0,
                 drag = 2, jitter = 10, life = 0.5 } }

-- "After 5 for the left hand and 7 for the right hand, fade in a
--  line between 7 on the left clock and 5 on the right clock."
--  (the vision swaps the hours in its first clause; its line
--  description settles the reading — left rests at 7, right at 5)
stroke{ name = "seal-line", at = 2.2, lasts = 0.9,
        color = "violet", fade = "in",
        shape = fill{ vertices = { tip("left-hand"),
                                   tip("right-hand") },
                      sweep = "at-once" },
        emit = { rate = 800, spread = 1.2, speed = 5, aim = 0,
                 drag = 2.5, jitter = 8, life = 0.7 } }

-- "Fill the 'triangle' between 7 on the left clock, 5 on the right
--  clock, slowly." (the third vertex is unnamed in the vision; a
--  low center point is this translation's reading)
stroke{ name = "seal-fill", at = 3.0, lasts = 1.2,
        color = "violet", fade = "in",
        shape = fill{ vertices = { tip("left-hand"),
                                   tip("right-hand"),
                                   {128, 208} },
                      sweep = "downward" },
        emit = { rate = 1400, spread = 1.4, speed = 4, aim = 0,
                 drag = 2.5, jitter = 8, life = 0.9,
                 life_jitter = 0.3 } }
