# crossing_scaled.lua

The crossing map at any army size (issue 515k). **Usage:**
`require("net.arenas.crossing_scaled")(per_army) -> map`; everything
grows with the square root of `per_army / 40`, and at 40 it is exactly the
demo's map. Returns `cell`, `rows` (text), `army` (per size: count, radius,
speed; 1 large, 5 medium, 4 small in 10) and `homes` (world units).
