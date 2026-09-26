# Issue 405f: Units Path Around Units

**Phase:** 4 - Runtime
**Type:** Implementation
**Priority:** Medium
**Parent:** 405 (collision detection)
**Dependencies:** 403 (A* pathfinding), 405d (movement with collision)
**Blocks:** 804 (the crossing-armies demo), 515k

---

## Current Behavior

**Rebuilt (2026-09-25) after the owner watched the first version;** the
owner to watch again. `src/runtime/crowd.lua`, tested by
`src/tests/test_crowd.lua` (all pass):
- orbiting a standing enemy, passing head-on, going round a bundle, an idle
  ally nudged aside, sixteen mixed sizes packing, and the owner's slow A
  among fast Bs (the Bs fill the middle, A stops on its own side);
- the crossing demo's two armies of 40, mixed sizes (4 large, 20 medium,
  16 small each): no overlap and no wall contact at any tick; most of each
  crossing is done in about 30 s, the last stragglers settle by about
  46 s; about 0.2 ms a tick for 80 units.

What building it taught, each now a rule or number in the file:
- **Reserved spots gridlock.** A first rebuild reserved each group member a
  packed spot as it came near. Members bound for neighbouring spots had to
  cross each other at the finish and blocked each other there for good;
  swapping spots and settling near them only moved the jam. Groups now
  settle where they meet arrived groupmates, which is also the owner's A
  and B story.
- **Settling at the first arrived groupmate makes a comet's tail** behind a
  group arriving from one side; a member now slides round the group until
  within its packed size (the members' area as one disc, at 0.6 packing).
- **Orbiting at full speed round the edge scatters a crowd;** a slide keeps
  the part of the step toward the goal.
- **Re-planning every tick was the cost** (14 ms a tick): a unit now plans
  at most every 15 ticks.
- **Bundles of blocked movers covered the whole crowd;** a bundle is
  standing units only, and a bundle with no way round is ignored.
- **Axis-by-axis wall sliding sticks at a pillar's corner;** units slide
  along the nearest wall edge.
- **A unit giving way in a narrow channel blocked it;** it steps aside
  when there's room.
- **The demo's pillars made a two-cell channel on the armies' straight
  line;** they are now four cells apart.
- **Gridlock, and two radii (the owner, 2026-09-25):** "Can we detect if a
  unit is gridlocked somehow? If so, we should have them move back a bit,
  then try again, just to shake up the entire structure." And: "Warcraft 3
  units have two separate radiuses related to pathfinding [...] the
  pathfinding radius is larger, so they'll try to walk around other
  units. Can you try building that and see how it goes?" Built:
  - a unit no closer to its goal for 2 s backs off from the units
    touching it, and so do the stuck units round it, then tries again (up
    to three times an order); 112 back-offs in one crossing;
  - each unit has a pathing radius (its collision radius + 0.2) and
    steers, up to 0.8 ahead, to pass outside the pathing radii in its way;
    a unit now passes a standing one without touching it.
  - **How it went, measured on the crossing (80 units):**

    | Setup | Crossing | Gave up |
    |---|---|---|
    | neither | 46.5 s | 1 |
    | back-off only | 39.7 s | 0 |
    | both, pathing +0.35, 1.2 ahead | 57.6 s | 13 |
    | both, pathing +0.2, 0.8 ahead (the default) | 45.9 s | 0 |
    | both, pathing +0.15, 0.6 ahead | 66.6 s | 7 |

    Back-off helps; steering by the larger radius slows two head-on armies
    and is sensitive to its numbers. It suits sparse scenes. The demo can
    run with it off (`run-crossing.sh "" window-one-radius`) to compare.
- **The tick in two phases (for issue 515k, 2026-09-25):** every unit
  decides alone from a snapshot of the tick's start, then steps settle in
  id order (a refused step gets a second try after everyone else). A test
  proves deciding in any order gives the same positions, bit for bit.
  Units now react to each other a tick late: the crossing went from
  39.7 s to 47.0 s (back-off on, larger radius off), nobody giving up.
  - **The larger pathing radius is now off by default:** with the
    two-phase tick it took the crossing to 64.7 s with 10 giving up. The
    demo shows it with `run-crossing.sh "" window-two-radii`.
  - **Found on the way:** a unit that had given up, nudged aside, counted
    as arrived at the nudge spot, and its groupmates settled against it in
    the middle of the field; a nudge now restores what the unit was. A
    path planned only as close as it could get no longer counts as
    arrived at its end.
- **Steering lessons:** the side it steers to is kept while anyone is in
  the way (choosing afresh each tick dithered left and right, and between
  a bundle's members); idle allies aren't steered round, they're nudged
  (steering round one in a narrow corridor never reached it); "heading
  the same way" is judged by goal, not speed (at an order's start every
  speed is zero, and an army steered round itself and spread).
- **Known limit:** at the end of a crossing a straggler circling the
  arrived army can still give up after 20 s without getting closer (0 to 2
  a crossing in the test).

## Intended Behavior

Warcraft III's behaviour, as the owner described it (2026-09-25). First:
"units path around each other and don't walk into the same area that
another unit is in"; a moving unit meeting a friendly unit standing still
"paths around." Then, after watching the first version:

> I think Warcraft 3 had a concept of nudging, we might need something
> similar. [...] Units are getting stuck on each other, so two units will
> just stand still blocking each other. We should dynamically route around
> objects. [...] Can you make some units of larger size? Warcraft 3 didn't
> feel so rigidly bound to a grid. That game had lots of circles and you
> could slide around units easier. This demo, not so much. They don't jam.
> If they need to get past a unit, they "orbit" the units in the way,
> viewing them as a bundle. Sometimes they stand still while units move
> past them. Also, if a collection of them is moving to a location and
> another unit is in the way, they'll shuffle past them. If that unit is
> part of the same selection - for example, unit A is surrounded by 15 unit
> Bs. Unit A has a slow movement speed, and unit B's are fast. They arrive
> at the destination first, but unit A is intended to move toward the
> center of the formation. The unit B's will shuffle to fill the space unit
> A is intended for, and unit A will take the closer spot. Remember, units
> can be different sizes, so we have to make sure the waypoints are
> displaced correctly.

**The design (a crowd of circles, not of cells):**
- **Units are circles of their own sizes,** moving continuously. The grid
  only describes the ground (walls, pillars), with each cell's clearance
  (distance to the nearest wall), so a unit of radius r plans only through
  ground at least r clear.
- **Paths are planned around the ground only,** then pulled straight
  (a waypoint is kept only where a straight line would clip a wall at the
  unit's radius), so paths are a few straight legs, not a staircase of
  cells.
- **Sliding:** each tick a unit wants to step toward its next waypoint.
  When the step would overlap another unit, the part of the step pointing
  into that unit is removed and the rest is taken, so it slides along the
  circle. It keeps sliding the same way round (clockwise or anticlockwise,
  chosen at first contact by which side its waypoint is on) until clear:
  that is orbiting. No overlap is ever allowed; a step that would still
  overlap is shortened.
- **Bundles:** units touching each other (or nearly) form a bundle. A unit
  that has slid along a bundle without getting closer for a moment plans
  again with the whole bundle as an obstacle, and goes round it.
- **Giving way:** two moving units that can't slide past each other don't
  both stop: the one of lower priority (the higher id, or the one not in a
  hurry) stands still for a moment while the other goes round it.
- **Nudging:** a unit standing idle that is in the way of a moving unit of
  its own side steps aside, out of the mover's way. Enemies are not
  nudged; they are gone round.
- **Groups settle as they arrive.** A group ordered to one point gets no
  places in advance. Each unit heads for the point; one that meets a
  groupmate already arrived slides on inward while it can and settles once
  within the group's packed size, so the first to arrive fill the middle
  and a slow latecomer stops at the edge nearest itself. Units not in the
  group are nudged aside as members pass through.
- **Sizes:** units come in sizes (radius 0.35, 0.5 and 0.8 in the demo; the
  large ones slower). Every clearance, contact and formation spot uses each
  unit's own radius.
- **What it reports per unit:** position, velocity, facing, radius,
  standing or walking, and its path when that changes.
- Deterministic: same orders, same result.

## Suggested Implementation Steps

1. The ground: walls, and each cell's clearance.
2. Planning with clearance for a radius, and pulling paths straight.
3. Moving with sliding and orbiting; bundles; giving way; nudging.
4. Groups that settle as they meet arrived groupmates, by size.
5. Tests, each a scene checked for overlap at every tick (units, and units
   against walls): a unit orbits a standing enemy; two units pass
   head-on without stopping for long; a unit goes round a bundle; an idle
   ally is nudged aside; sixteen mixed-size units ordered to a point pack
   round it without overlap; the owner's slow unit A among fifteen fast Bs
   ends at the free spot nearest itself while Bs fill the middle; two
   armies of mixed sizes cross without jamming.
6. The demo draws each unit's radius on the ground under it, green for one
   side and purple for the other, and bodies sized by radius.

## Acceptance Criteria

- [x] The tests above pass; no overlap at any tick in any of them
- [x] `.info.md` beside each new source file (updated)
- [ ] The owner watches the demo and agrees it moves like Warcraft III

## Open Questions

- **The narrow-gap jam**, answered by the owner (2026-09-25): "They don't
  jam. If they need to get past a unit, they 'orbit' the units in the way,
  viewing them as a bundle. Sometimes they stand still while units move
  past them." Built into the design above (sliding, bundles, giving way).
- **Who gives way** between two moving units that can't slide past each
  other: the design says the higher id, as a stand-in; Warcraft III's own
  rule isn't recorded here.

## Ideas Waiting on the Owner Watching the Two Radii

The owner (2026-09-25), held until they have seen the two radii run: "might
be better to see how the two pathing radiuses work first..."
- **A vague heading while stuck, one re-path when free:** "when we replan,
  we just keep a general conception of which direction we want to move
  toward vaguely. Then once the unit is out of the gridlock, it re-paths
  just once. That might help us wander around each other." (In the crowd's
  terms: while gridlocked or backing off, a unit follows only the
  direction of its goal, planning nothing; it plans once when it is next
  free to move.)
- **Seeing a blocking mass from the back:** "if large groups of units are
  blocking the path, a unit near the back should pre-emptively realize
  that it'd be fastest if they went around, so they should group the mass
  as one radius in their mind and orbit around that until they have a
  clear path to their target." (A mass ahead, found before touching it,
  treated as one circle round its members, orbited until the way to the
  target is clear.)

## Related Documents

- `issues/completed/404d-advanced-movement-behaviors.md` (separation and sliding, which this doesn't use)
- `issues/completed/405d-movement-collision-integration.md`
- `src/runtime/pathfinding/astar.lua`
