# crowd-scene.lua

Writes the crossing scene at a given army size as text, from the Lua
crossing game's placement (`net/crossing_sim.lua`, `place`): `W H CELL`,
the ground's rows (`#` wall), `HOMES x1 y1 x2 y2`, `UNITS n`, then `x y
radius speed team` per unit in id order (17 significant digits).
**Usage:** `luajit crowd-scene.lua DIR PER_ARMY > scene.txt`.
