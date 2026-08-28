# 211b — Every Zone Holds a Waypoint

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 211a |
| Blocks | 211c |
| Reads | [the map and its milestones](../docs/002-the-map-and-its-milestones.md), [waves and when one is finished](../docs/005-waves-and-when-one-is-finished.md) |
| Open questions | none |

## Current behavior

A wave advances a single number — its anchor — by its pace, every tick, forever. It
walks the exact centre of the road at the exact same distances as every wave before
it.

## Intended behavior

**Every waypoint zone holds one point, at a random position inside it.** A wave
walking a lane heads for the waypoint of the zone ahead of it, and when the centre
of its formation enters that zone, it takes the next one.

The purpose is variation in **where a wave sits and what angle it arrives at**. It
is hard to tell exactly which direction is optimal while standing on the ground, so
you go roughly that way.

### Random, and therefore from a named stream

The offset is chosen from a **named seeded random stream**, one per team, like every
other random thing in this project. Nothing takes from the clock and nothing takes
from a shared source: a waypoint drawn from an unnamed generator would break the
replay on its first tick, and would make a cosmetic change to the wander silently
change which upgrades a team draws.

### Bounded so the formation stays on the road

The waypoint's offset across the lane is bounded by **the lane's half-width less the
formation's radius**, so a wave aiming at one still has all of itself on the road. A
waypoint at the verge puts half a rank in the ditch.

### The roads get wider to make room

*Settled; see [open questions](../docs/020-open-questions.md), H6.*

A road is about **three times the width of the formation walking it**, and the
**centre lane is nine**. So a side lane carries one formation with a formation's
width of clear ground either side, and the centre carries one with four widths
either side.

That also settles what the centre lane is for, more comfortably than before: three
formations stand abreast in it during a challenge with room to spare, rather than
exactly fitting. The width is still checked against the file count it must carry —
the cap on how many bodies ever stand abreast is what stops a wider road from simply
making a wider army.

**A wave generally marches straight on a straight road.** The wander is not a weave.
It shows most where the road bends and where two waves are closing.

## Suggested implementation steps

1. Add a `waypoint` stream to the named random streams, one per team. Document it in
   the tick's stream table alongside `draw`, `surge` and the rest.
2. Generate a waypoint per waypoint zone per team at map assembly, not per tick — a
   zone's waypoint is a property of the match, so that two runs of the same seed put
   their feet in the same places.
3. Bound the across-offset by half the lane's width less the formation's radius for
   that lane, and clamp rather than trusting the arithmetic.
4. Widen the lanes to three and nine formation widths, and update the validator's
   file-count check, which is what stops the widening from quietly changing how many
   bodies stand abreast.
5. Give a wave a current waypoint and the zone it belongs to. Advance both when the
   formation's centre crosses in.
6. In the formation sandbox: a wave on a **straight** lane must not walk a straight
   line, and its wander must stay inside the bound. Both are the test — a wander of
   zero means the waypoints are not being read, and a wander past the bound means
   the clamp is wrong.

## Related documents and tools

- [211a](211a-the-lane-is-cut-into-zones.md), which cuts the zones this fills
- [211c](211c-a-formation-is-a-circle-that-faces.md), which is what does the aiming
- The named random streams, and the reason there are several of them
