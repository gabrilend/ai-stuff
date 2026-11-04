-- The reading walk's guide's room, read from its description: a room the reader
-- may look into but not write in; the made-public ledger open on a desk, the
-- kept-to-itself ledger shut beside the key, the reader outside the glass.
scene{ what = "a room with a glass front: an open ledger on a desk, a shut box and a key, a reader outside" }
box { name = "floor of the room", at = {0, 0.02, 0}, size = {2, 0.04, 2}, color = "#c8c0b0" }
box { name = "back wall", at = {0, 1, -1}, size = {2, 2, 0.06}, color = "#9a948a" }
box { name = "left wall", at = {-1, 1, 0}, size = {0.06, 2, 2}, color = "#9a948a" }
box { name = "glass front: everyone may look in", at = {0, 1, 1}, size = {2, 2, 0.02}, color = "#d8eef0", glow = true }
box { name = "made-public ledger (open on the desk)", at = {-0.4, 0.75, -0.3}, size = {0.5, 0.03, 0.35}, color = "#f4f0e4" }
box { name = "desk", at = {-0.4, 0.36, -0.3}, size = {0.9, 0.7, 0.5}, color = "#6a5038" }
box { name = "kept-to-itself ledger (shut)", at = {0.5, 0.2, -0.6}, size = {0.4, 0.3, 0.3}, color = "#3a3a48" }
cylinder { name = "the key, owner only", at = {0.5, 0.42, -0.6}, radius = 0.05, height = 0.12, color = "#c9a02a" }
box { name = "the reader, outside the glass", at = {0.3, 0.8, 1.6}, size = {0.3, 1.6, 0.25}, color = "#4a6a8a" }
