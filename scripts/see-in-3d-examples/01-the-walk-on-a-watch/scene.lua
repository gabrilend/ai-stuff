-- The small-screen walk page read as a watch: a black glass face standing on
-- a strap, its lit lines of text as thin bright bars raised from the face.
scene{ what = "the reading walk's OLED page as a watch face: dark glass, lit lines of text" }
box { name = "watch body", at = {0, 0.6, 0}, size = {0.9, 1.2, 0.12}, color = "#1a1a1a" }
box { name = "black face", at = {0, 0.6, 0.065}, size = {0.8, 1.1, 0.01}, color = "#000000" }
box { name = "strap", at = {0, 0.6, -0.1}, size = {0.5, 1.6, 0.04}, color = "#3b2f2a" }
box { name = "position line (dim)", at = {-0.12, 1.07, 0.075}, size = {0.5, 0.025, 0.01}, color = "#6a6a6a", glow = true }
box { name = "stop name (bright, bold)", at = {-0.22, 1.0, 0.075}, size = {0.3, 0.05, 0.012}, color = "#ffffff", glow = true }
box { name = "summary line 1", at = {0.0, 0.9, 0.075}, size = {0.72, 0.04, 0.01}, color = "#f2f2f2", glow = true }
box { name = "summary line 2", at = {-0.08, 0.83, 0.075}, size = {0.56, 0.04, 0.01}, color = "#f2f2f2", glow = true }
box { name = "back link", at = {-0.25, 0.72, 0.075}, size = {0.2, 0.04, 0.01}, color = "#8fb6dc", glow = true }
box { name = "next link", at = {0.02, 0.72, 0.075}, size = {0.2, 0.04, 0.01}, color = "#8fb6dc", glow = true }
