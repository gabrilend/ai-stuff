--[[
crossing.lua - the crossing-armies demo's map: a field split by a wall with one gap (issue 804)

What this is: the map both the server and the renderer read, the way both
sides of a Warcraft III game read the same map file: a 40x22 field, a
dividing wall with a 12-cell gap, two 2x2 pillars each side (four cells
apart: at two apart they made a narrow channel right on the armies'
straight line), and two armies of 40, each 4 large, 20 medium and 16
small (the owner, 2026-09-25: "Can you make some units of larger size?").

It is the scaled map (net/arenas/crossing_scaled.lua) at 40 units per
army; the benchmark builds the same map larger.
]]

return require("net.arenas.crossing_scaled")(40)
