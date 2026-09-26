# crossing.lua (arena)

The crossing demo's map (issue 804), built from a few numbers: a 40×22
field, a dividing wall with a 12-cell gap, and two 2×2 pillars each side,
four cells apart. Returns `cell` (1.0), `rows` (text, "#" wall, "."
ground), `army` (per size: `count`, `radius`, `speed` — 4 large at 0.8 and
2.2 a second, 20 medium at 0.5 and 3.0, 16 small at 0.35 and 3.6) and
`homes` (each army's home point, world units).
