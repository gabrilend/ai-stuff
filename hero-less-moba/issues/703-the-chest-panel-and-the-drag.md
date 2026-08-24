# 703 — The Chest Panel and the Drag

| | |
| --- | --- |
| Phase | 7 — Watching It Happen |
| Blocked by | 404, 410, 505, 506, 507, 701 |
| Blocks | 704 |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md), [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | none |

## Current behavior

Placements are issued from a command line. The chest is a list of numbers.

## Intended behavior

The second-most-looked-at thing on the screen, after the lanes themselves.

**Unplaced upgrades are large and impossible to ignore.** An upgrade doing
nothing should be visually annoying — that annoyance is the pressure that makes a
team look at its chest, and it is the only thing in the interface doing that job.
The `unplaced_count` should be prominent enough to be uncomfortable.

Each slot is a visible destination: three lanes, three lanes' stone, one library.
Placing is a **drag** from the chest to a slot. The chest and the lanes are the
two things a player's eyes move between constantly, so they must be arranged so
that a placement is a short drag rather than a trip across the screen. If the map
needs a camera that moves, this gets much harder, which is why open question D7
matters here as much as in issue 702.

Each slot shows what is in it, who locked what, and what has been objected — issue
may legally drop there right now: **anything already in transit greyed out, kinds
that cannot enter stone greyed out, and everything greyed out during a surge.** A
rule you discover by being refused feels arbitrary; a rule you can see before
acting is a constraint you play around.
acting is a constraint you play around.

Hero purchasing lives in the same panel. Affordable heroes are distinguished from
unaffordable at a glance, and the three spawn destinations — a wave, a tower, the
library — are picked by clicking the thing itself in the world, not by picking
from a list. That is the same instinct as sign-posts being objects rather than
menu entries: the destinations are places, so they should be chosen as places.

## Suggested implementation steps

1. Draw the chest from the snapshot, sorted by recency using `placed_tick`.
2. Draw the seven slots, each as a visible target with its contents.
3. Write the drag: pick up, highlight legal destinations, drop, emit a
   `place_upgrade` command.
4. Write the legality preview by asking the same validator the command handler
   uses. **Never a second copy of the rules** — a preview that disagrees with the
   simulation is worse than no preview.
5. Draw the hero purchase row with affordability, and wire the three destinations
   to clicks in the world.
6. Test with three people and one chest. The failure this panel exists to prevent
   is three players silently undoing each other, and it only shows up with three
   people.

## Related documents and tools

- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md)
- [The viewing layer](../docs/017-the-viewing-layer.md)
