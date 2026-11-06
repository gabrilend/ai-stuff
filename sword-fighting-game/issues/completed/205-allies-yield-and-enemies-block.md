# 205 — Allies Yield And Enemies Block

| | |
| --- | --- |
| Phase | 2 — Bodies on the field |
| Blocked by | 202, 203 |
| Blocks | 206, 304, 305 |
| Files | `src/008-movement.lua` |
| Reads | `docs/datapath-battle-tick.md` |

## Current behavior

Built in `src/008-movement.lua`. A step slides along walls (whole step,
else each axis). The half-speed step into an ally trades cells when the
centre crosses, and the ally yields to the mover's old cell along its own
movement. Bug fixed while testing: a yielding ally whose body was still in
the cell it had given away was treated as walking into the mover again and
swapped back, thousands of times a battle; a body may now always move within
the cell it physically stands in, and yields never trade. Regression case in
tests/032-bodies-on-the-field.lua.

## Intended behavior

Each tick a soldier has a wish to move: a forward amount and a side amount
(−1..1) relative to its facing, and optionally a dodge. Movement turns the
wish into a step and applies the occupancy rules:

1. **Speed** — walk speed (configuration) × the region's walk multiplier ×
   the thickness penalty × the shield-wall penalty. Backsteps and sidesteps
   are slower than forward steps.
2. **Enemy-held cells are walls.** If the step would carry the soldier's
   centre into a cell an enemy holds, the step is cut to stay in the current
   cell. Nobody can push anyone.
3. **Ally-held cells are passable at half speed.** If the step leads into a
   cell an ally holds, the step is halved; when the soldier's centre enters
   that cell the two swap claims and the ally is given a **yield**: a short
   step of its own, the other way, along its own dodge movement (it is not
   pushed by the player's input). Yields count in the receipt.
4. **Dodges** are a quick fixed-length step in the wished direction. A dodge
   whose landing cell is held by anyone, ally or enemy, is refused before it
   starts.
5. **Edges** — the field's edge is a wall.

Velocity is kept on the record because momentum (302) reads it.

## Suggested implementation steps

1. Write the step function and the yield; the cell claim moves only when the
   centre crosses into the new cell.
2. Test: a soldier walking at an enemy stops at the cell boundary; a soldier
   walking into an ally moves at half speed and the ally ends up displaced
   the other way; a dodge into any occupied cell is refused.
