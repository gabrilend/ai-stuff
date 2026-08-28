# 211a — The Lane Is Cut Into Zones

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 101, 102 |
| Blocks | 211b |
| Reads | [the map and its milestones](../docs/002-the-map-and-its-milestones.md) |
| Open questions | none |

## Current behavior

A lane is measured in **milestones**: nine per lane, at fixed fractions of its
length, stored on the lane record as a node id and a path index for each. They do
two jobs at once — they are where the towers stand, and they are the unit push depth
is counted in.

Push depth is therefore an integer from 0 to 8. A lane that is badly lost reads the
same as one that is merely losing.

## Intended behavior

**A lane is cut into zones**, four times finer than its milestone intervals: eight
intervals become thirty-two, so a lane has thirty-three zone boundaries.

A zone is a range of distance along a lane and nothing else. It has a start, an end,
and an index. It is not a node, it does not have neighbours, and nothing walks to it.

**The milestones do not move.** Each milestone interval divides into four, so every
milestone lands exactly on a zone boundary and no tower shifts by a pace. Nothing
that currently says "milestone" changes meaning. *Settled; see
[open questions](../docs/020-open-questions.md), H4.*

The division is written in the shape parameters as **divisions per milestone
interval**, not as a total count, so that milestones stay on boundaries by
construction rather than by arithmetic somebody has to check.

### Two arrays, side by side, holding the same thing

The lane record carries **two** zone arrays:

| | |
| --- | --- |
| the distance zones | what push depth is measured in |
| the waypoint zones | what [211b](211b-every-zone-holds-a-waypoint.md) puts a waypoint inside |

They are identical: same boundaries, same distances, built by one loop.

**Separate, so either can move without moving the other.** The distances a wave
routes through and the distances a push is measured in are the same question today
and are not the same *kind* of question. The first thing anybody will want is to
shift one and leave the other alone.

**Side by side on the same record, so they can be found.** Two arrays next to each
other is a thing somebody reads and understands. The same two arrays in two files is
a thing somebody edits one of.

### Push depth moves to zones

Push depth becomes an integer from 0 to 32 rather than 0 to 8, and every reader of
it changes meaning by a factor of four: the lane-pressure bars, the sign-post
display, the bot's "which lane am I losing", the headless report, the terminal
viewer, the snapshot.

That factor is the risk in this issue and it is worth being blunt about it. A push
depth read as milestones where it is now zones is off by four in a number nobody
prints, and it would be found by somebody playing rather than by a test. Every
reader gets visited; the ones that display a fraction of a lane get the zone count
to divide by rather than a literal 8.

## Suggested implementation steps

1. Add `zone_divisions` to the map's shape parameters — how many zones per milestone
   interval. Four.
2. In the map builder, build both zone arrays in one loop over the milestone
   fractions, so they cannot disagree at birth.
3. Add to the map validator: both arrays have the same length and the same
   boundaries, every milestone lands exactly on a boundary of each, and the zones
   cover the lane end to end with no gap and no overlap. That last is the one that
   catches an off-by-one in the loop.
4. Change push depth to count zones. Find every reader by searching for the field
   rather than by memory.
5. Give the lane a way to answer "which zone is this distance in" without a search —
   the zones are evenly spaced within a milestone interval and the milestones are at
   known fractions, so it is arithmetic, not a scan.

## Related documents and tools

- [The map and its milestones](../docs/002-the-map-and-its-milestones.md)
- [Milestones measure a push](102-milestones-measure-a-push.md), whose unit this
  changes
- The map validator, which is where the boundary agreement gets asserted
