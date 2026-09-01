# 806 — Balls Collide With Each Other

| | |
| --- | --- |
| Phase | 8 — The Mountain |
| Blocked by | 804 |
| Blocks | — |
| Reads | `src/034-the-body-store.info.md`, `src/071-the-model.info.md` |
| Open questions | two, at the bottom |

## Current behavior

Balls pass straight through one another. Three hundred of them run down the same
mountain, take the same staircases and pile up in the same corners, and at no
point does any of them notice that another exists. What looks like a heap at the
bottom of a flight is three hundred independent bodies occupying the same few
cubic cells.

Nothing is wrong in the code; the case was never written. Bodies meet each other
in exactly one place — the meet pass, which pairs them for *social* reasons, asks
whether two of them should idle together or start a duel, and has no opinion
about volume.

## Intended behavior

A ball is a sphere and two spheres cannot overlap.

**Finding the pairs.** The body store already sorts every live body into a bucket
per cell, by a counting sort with no allocation, and already offers the nine-cell
neighbourhood around a point. A ball's radius is well under a cell, so every
possible contact is inside that neighbourhood and the search is bounded by how
crowded the cell is rather than by how many balls exist.

**Resolving one pair.** Two spheres overlap when the distance between their
centres is less than the sum of their radii. Push each back along the line of
centres by half the overlap, then apply the equal-and-opposite impulse that a
collision between two masses with a coefficient of restitution gives. Mass is
radius cubed — the balls are all one size today, and writing it as a volume now
is what stops a dinosaur being knocked across the map by a pebble later.

**Each pair exactly once.** The pass walks every ball and asks the neighbourhood
about each, so every pair comes up twice — once from each end. Resolving it both
times applies the impulse twice and separates the pair twice as far as either
sphere asked for. The pass resolves a pair only when the neighbour's id is the
higher of the two, which is one comparison and needs no memory of what has been
seen.

**The row is not parallel, and says so.** Every other locomotion row touches one
body per iteration and can be split across a thread pool by handing each core a
range. This one writes to two bodies at a time, and the second is not in its
range. The `parallel` flag on the row exists to state exactly this, and the honest
value is false — a claim that costs nothing today, since nothing splits anything
yet, and which is the difference between adding a pool later and auditing every
row for races.

## Suggested implementation steps

1. Do it after the world collision, not before. A ball pushed out of a wall and
   then out of a neighbour ends up somewhere legal; the other order ends with it
   pushed back into the wall.
2. Check the pair count. On three hundred balls in a crowd the pass is quadratic
   in the size of the largest bucket, and `largest_bucket` is already in the
   report for exactly this reason.
3. Test the invariant directly: after a tick, no two live bodies overlap by more
   than a small tolerance. That is one sweep over the buckets and it is the whole
   feature stated as an assertion.
4. Test conservation on a pair in isolation — two balls approaching head-on at
   the same speed leave at the same speed scaled by restitution, and their total
   momentum is unchanged. A collision that quietly adds energy shows up as an
   aquarium that never settles, which looks like liveliness.

## Related documents and tools

- [804](804-a-ball-is-a-sphere-against-faces.md) — the world half of the same pass
- `src/034-the-body-store.info.md` — the buckets, and what makes them bounded

## Open questions

**One. Should a resting ball be woken by a nudge?** A ball that has stopped
accumulates a rest timer and is eventually retired and dropped in again at the
top. A ball struck by another while resting should presumably lose its timer. If
it does not, a heap at the bottom of a flight evaporates on a schedule while
being visibly jostled. Not answered.

**Two. Do balls stack?** Two spheres resting one on the other is a stable
arrangement the resolver will produce, and nothing here stops a tower of them.
Whether that is a pleasing emergent pile or a jittering column depends on how the
rest threshold and the separation interact, and it has not been looked at.
