# 002 — Game Mechanics

This document expands every line of the vision into a concrete rule. When the
implementation is uncertain about behavior, this document is the tiebreaker.
When this document is uncertain, `notes/vision` is the tiebreaker.

## Terrain

The world is a square heightmap: a 2D grid of Z values over an X/Y plane. The
mesh is rendered as triangles. All world positions used by the game (units,
projectiles, rally points, mouse picks) project onto this surface — they have
real X/Y coordinates and a Z derived from the terrain at that X/Y.

Out-of-bounds X/Y is undefined and should be clamped at the boundary.

## Units

A unit is a rectangular box. It has a position on the terrain, a facing
direction, a small set of orders, an optional movement target, hit points,
and a memory of recent misses. All units are functionally identical in
Phase 1 — same size, same speed, same javelin, same firing cadence, same
HP pool.

Units always render with their base flat against the terrain at their X/Y.
They do not tilt with slope in Phase 1. This is a deliberate simplification.

### Hit points, damage, and regeneration

- Maximum HP per unit: **30**.
- Each successful javelin hit deals **10** damage. Three hits destroy a
  unit.
- HP regenerates at **1 HP per 10 seconds**, applied as **0.02 HP every
  0.2 seconds** (a discretized tick, not a continuous smooth function).
  Regeneration is capped at the max.
- HP is a `float` so the 0.02 increments accumulate cleanly.
- Regeneration runs whether or not a unit is in combat. Phase 1 does not
  distinguish in-combat from out-of-combat regen — that lever is for a
  later phase.

This budget — 3 shots to kill, 0.1 HP/sec regen — means a single distant
attacker is harassment, not a threat: the target out-regens damage if hits
land less than once every 100 seconds. Two attackers landing 1-shot-each
per 100 seconds are also recoverable. To actually kill, attackers must
land sustained pressure. This is the design intent and is the reason the
specific numbers were chosen; do not retune without thinking it through.

## Projectiles (javelins)

A javelin is a thin cylinder fired from the shooter's position at a target
point. Once fired:

- Velocity is constant in direction and magnitude (no drag, no gravity steering).
- The projectile travels in a straight line in 3D space until it expires or
  intersects something.
- Hit detection is per-step: the projectile checks whether it has reached or
  passed near a unit's bounding box, or whether it has fallen below the
  terrain at its X/Y.

A javelin that misses is simply consumed — there are no ricochets.

A javelin that hits a unit deals 10 damage to that unit. The projectile is
consumed on hit regardless of whether the target survives. Friendly fire
is allowed — a javelin damages whichever unit it physically intersects,
not whichever unit was designated as the shooter's target.

## Line of sight

A unit only fires at another unit when the line segment between them does not
pass below the heightmap surface at any sampled point along the way. Line of
sight is computed by sampling the height along the segment at a fixed step,
and comparing each sample's Z to the terrain Z at that X/Y. If any sample is
underground, the line is blocked.

A blocked unit holds fire. It does not reposition to find a shot in Phase 1 —
that decision belongs to Phase 3 (advanced movement).

## Aiming variance (the miss memory)

Each unit keeps a running counter of consecutive misses against each enemy
target it has fired at. When the unit fires:

- The aim point starts at the target's X/Y.
- An offset is sampled from a 2D distribution whose width grows with the
  miss count for *that specific target*. The Z is then read from the
  heightmap at the offset X/Y, and the javelin is aimed at that 3D point.
- A successful hit resets the miss counter for that target to zero.

Variance never decays purely from time — only hits clear it. This produces
emergent behavior: units that have been firing wildly at one target keep
firing wildly until they connect.

The exact distribution and growth schedule belong in the implementation; this
document only fixes the contract.

## Selection and orders for units

- Left-click drag draws a 2D screen rectangle. On release, every unit whose
  screen-projected position is inside the rectangle becomes the new selection.
  A click without drag selects the unit under the cursor (if any), else
  clears.
- Right-click on the terrain issues a movement order to selected units. The
  order target is the terrain point under the cursor.
- Shift held while right-clicking *appends* a waypoint to the current chain.
  Each new shift-press-then-hold begins a *new* chain.
- Releasing shift and right-clicking *replaces* all orders with a single
  waypoint at the clicked point.

When a unit has a chain, it walks each waypoint in order until the chain ends.

### Chain splitting on selected units

When a new chain begins (a new shift-press) on a multi-unit selection, the
selection is divided in half: half the units take the existing chain, half
start the new chain. Subsequent shift-presses keep halving the remainder.

The split is a stable partition by selection order, not random.

## Factory

The factory is placed by clicking a UI button to enter placement mode, then
clicking on the terrain to commit. Once placed, the factory:

- Produces one unit roughly every 10 seconds.
- Produced units spawn at the factory and immediately walk the current rally
  chain.
- Has a single rally point by default. Clicking the factory enters rally
  edit mode: drag the rally indicator on the X/Y plane (it renders at the
  terrain's Z), and release to commit.
- Supports shift-chained rally points just like unit movement orders.

### Round-robin chains for factory output

When a factory has multiple rally chains, each newly produced unit picks the
*next* chain in order. After the last chain, the rotation restarts from the
top. This is a strict rotation, not a shuffle.

## Movement while engaged

Units fire while moving. Movement does not interrupt fire and fire does not
interrupt movement. Aim is computed at the moment of release using the
shooter's current position and orientation.

## What is *not* in Phase 1

Resources, costs, attacks-while-stationary toggles, formations, patrol,
attack-move, hold-position, retreat, fog of war, multiple unit types,
multiple players, AI opponents, UI panels beyond a single button, audio.

These belong to later phases or never.
