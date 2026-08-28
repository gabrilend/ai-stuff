# 211 — Waypoints, and the Zones They Sit In

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 202, 206, 207 |
| Blocks | — |
| Reads | [the map and its milestones](../docs/002-the-map-and-its-milestones.md), [waves and when one is finished](../docs/005-waves-and-when-one-is-finished.md) |
| Open questions | H4, H5 |

## Current behavior

A wave has a single number for where it is: its **anchor**, a double holding how
far along its lane the front of the formation has got. Every tick the anchor moves
forward by the wave's pace, and every body's place is that number plus its own fixed
offset. There is no destination. There is no aiming. The wave is walking a number up
toward the lane's length and its shape follows the road because the road is what the
numbers are measured against.

Progress is measured separately, in **milestones**: nine points per lane, at fixed
fractions of the lane's length, which are also where the towers stand. Push depth --
the number the whole game runs on -- counts milestones.

Both of those are coarse and neither has any play in it. Every wave in a lane walks
the exact centre line, at the exact same distances, forever.

## Intended behavior

Two changes that fit together.

### Zones: the same measure, four times finer

Split each lane into **zones** -- short stretches of it, about four times as many as
there are milestone intervals. A zone is a range of distance along a lane, nothing
more, and it is the unit push depth is measured in.

Milestones stay exactly as they are. They are where the towers stand and what a
player reads off the map, and moving them would move every tower. Zones sit
underneath them: each milestone interval is divided into four, so every milestone is
still exactly on a zone boundary and nothing about the map's shape changes.

What it buys is resolution. Push depth in milestones is a number between 0 and 8 and
a lane can be badly lost while reading the same as one that is merely losing. In
zones it is a number between 0 and 32, and a frontline that has moved half a
milestone says so.

### Waypoints: a wave aims at a place, not at a number

Every zone carries a **waypoint**: one point inside it, at a random position, chosen
once from a named seeded stream. A wave marching a lane does not advance a number --
it **approaches its waypoint**, and when the centre of the formation enters that
zone, the waypoint becomes the next zone's.

The point is the variation. A wave should not walk the exact centre of the road at
the exact same distance every time; it should approach from slightly off, because
**nobody on the ground knows exactly which direction is optimal.** You go roughly
that way. Two waves marching the same lane on the same map should not lay their feet
in the same places.

### The two sets of zones are stored together and kept apart

The distance zones and the waypoint zones are **identical** -- the same boundaries at
the same distances -- and are stored as **two separate arrays in the same place**, on
the lane record next to the milestone arrays.

Separate, so that either can be moved without moving the other: the distances a
wave routes through and the distances a push is measured in are the same question
today and are not the same *kind* of question, and the first thing anybody will want
is to shift one without disturbing the other.

Together, so they can be found. A pair of arrays side by side on the lane record is
a thing somebody reads and understands; the same two arrays in two files is a thing
somebody edits one of.

## Suggested implementation steps

1. Add a zone count to the shape parameters, expressed as **divisions per milestone
   interval** rather than as a total, so that every milestone stays on a boundary by
   construction rather than by arithmetic that has to be checked.
2. Build both arrays in the map builder, from the same loop, and have the validator
   assert they agree and that every milestone lands on a boundary of both.
3. Add a named random stream for waypoints, per team. Everything random in this
   project comes from a named seeded stream and nothing takes from the clock; a
   waypoint chosen from an unnamed source would break the replay on its first tick.
4. Bound the waypoint's offset across the lane by the **formation's own radius**, so
   that a wave aiming at one still has all of itself on the road. A waypoint at the
   verge would put half a rank in the ditch.
5. Give each wave a current waypoint, and advance it when the formation's centre
   crosses into its zone. The centre is the anchor minus half the formation's depth,
   measured along the direction of travel -- the anchor is the **front**, deliberately,
   and the question here is about the middle.
6. Measure push depth in zones. Every reader of push depth changes: the sign-post
   display, the lane-pressure bars, the bot's "which lane am I losing" and the
   headless report all read a number that is now four times bigger.
7. Extend the formation sandbox: a wave walking a straight lane should **not** walk a
   straight line, and the amount it wanders should be bounded by the lane's width
   less the formation's radius. That bound is the test.

## Related documents and tools

- [The map and its milestones](../docs/002-the-map-and-its-milestones.md)
- [Waves and when one is finished](../docs/005-waves-and-when-one-is-finished.md)
- The formation sandbox, which is where the wander gets measured
- The map validator, which is where "every milestone is on a zone boundary" gets
  asserted rather than assumed

## Still open

Two questions, both of which change what gets built rather than how well.

**H4 -- do milestones stay nine?** Written above as: milestones stay, zones are a
finer measure underneath them, push depth moves to zones. The other reading of "four
times more discrete" is that the milestone table itself becomes thirty-three entries,
with the towers at every fourth one. That preserves the tower positions equally well
and makes one concept instead of two, at the cost of touching every piece of code
that says "milestone" -- the structure sites, the sign-posts, the chest's slot
addressing, the renderer's marks.

**H5 -- does a waypoint steer the formation, or replace the lane?** Written above as:
the wave still advances along the lane, and the waypoint decides *where across it*
the formation is heading, so the approach angle varies and the shape still curves
with the road for free. The other reading is that a waypoint is a genuine
destination in the world and the wave navigates to it, which would mean lane
coordinates stop being what a formation is held in -- and lane coordinates are the
entire reason a rank survives a corner.
