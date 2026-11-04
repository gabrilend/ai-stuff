# 104 — Stands, units, and movement in tier-time

**Phase:** 1 — The world beneath
**Blocked by:** 103

**Blocks**: 105, 106, 108, 701
**Related documents:** docs/core-terms.md (stand, tier-time),
docs/datapath-world-tick.md

## Current Behavior

The world has positions and rings but nothing in it.

## Intended Behavior

- A stand is a group of units with one position, one owner seat, one current
  order, and a speed in tiers per second (the slowest unit's speed).
- Units have kind, health, attack, range, shield. For now unit kinds are a
  small hand-written table; phase 7 replaces it with the generated catalog.
- Each tick, a stand with a move-like order steps toward its target. Speed is
  in tier-distance, so every band takes the same time to cross (tier-time).
- A stand with no order holds position.
- **Personal space that shrinks toward you** (the owner, 2026-10-10: "can
  we make it so that objects that are near to the player are densified, so
  more of them can stand next to each other? Essentially, the pathing
  radius shrinks the closer they are to you, but they still render at the
  same size. there should be roughly about as many units at each "outward
  radius axis" value from the viewer at each distance from the viewer. But,
  since there's more space far away, they seem farther apart. I think.
  Maybe."). Units keep apart: each has a personal space on the ground whose
  size grows with its ring's radius (in proportion to the ring's length),
  so a ring near the hub holds as many as one far out — crowded near the
  console (figures drawn full size overlap there), spread out far away.
  Units are scattered evenly by tier distance at the start, so each ring
  starts with about the same number. Built in the ceramic engine (020): after
  moving, each unit is nudged away from any neighbour inside their shared
  personal space, reading only last step's places (so chunk order cannot
  change it). Tests: two units on top of each other near the hub settle
  closer than two far out.
- **Sideways is measured on the sphere** (the owner, 2026-10-10: "how else
  do you represent that except two (or more) poles on a sphere? ... They
  will move left-right faster while they are far away, but closer / farther
  is always just dense."). The hub is one pole; the foes' kingdom across
  from it is the far pole, a set number of tiers out (the far pole tier,
  just past the tiers shown). Around the hub at tier distance r, a lap is
  as long as a circle of latitude: (far pole / pi) x sin(pi r / far pole)
  tiers round its radius — small near either pole. The map draws every lap
  as a full circle of its folded radius, so near the far pole a short lap
  is drawn huge and sideways motion crosses the screen fast, while outward
  motion, squeezed by the fold, stays dense. A stand's speed is in tiers
  per second in both directions on the sphere; its turning speed is that
  sideways speed divided by the lap's sphere radius. The haulers already
  walk this way (issue 214, the ceramic engine's steering).

## Suggested Implementation Steps

1. `src/008-unit-kinds.lua`: the temporary unit table (soldier, shield
   bearer, engineer, courier-speed reference).
2. `src/009-stands.lua`: stand creation, speed from its units, step toward a
   target position.
3. Tests: a stand at tier 0.5 with speed 0.1 reaches tier 2.5 in exactly
   20 seconds of ticks; a stand never overshoots its target.
