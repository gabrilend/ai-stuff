# 702 — Riding Is A Derived Position

| | |
| --- | --- |
| Phase | 7 — The Delve |
| Blocked by | 107, 301, 303, 306, 405, 601, 701 |
| Blocks | nothing |
| Reads | [riding and being ridden](../docs/022-riding-and-being-ridden.md) |
| Open questions | 2 |

## Current behavior

Humans and dinosaurs walk past each other.

## Intended behavior

A human on a dinosaur is two bodies and one thing that moves. Neither is
destroyed, neither is absorbed, and separating them is one field set to zero.

The rider's locomotion becomes `carried` and its `partner` is the mount; the
mount takes its intent from the rider rather than deciding for itself.

**The rider's position is not stored — it is derived**: the mount's position,
plus one layer, plus a small offset along the mount's facing. Deriving rather
than storing means the two cannot drift apart, which is the failure mode of every
version that keeps two positions in step by updating both.

The `carried` row does nothing at all, which is the correct amount of work for a
body not moving under its own power, and being a row rather than a flag means the
move pass never learns riding exists.

Four ways to dismount, and the last two are why this is worth building:

1. On purpose.
2. The mount dies — the rider is dropped and falls if there is nothing under it.
3. **The ceiling is too low.** The pair's height is the mount's plus one, so
   there are places a dinosaur fits and a ridden one does not.
   [The headroom check](107-four-answers-to-may-i-move.md) refuses the move.
4. **The corridor is too narrow.** The pair's footprint is the mount's.

Points three and four are the mode's geometry. Mounted, a party is fast and
strong and confined to the open places where everything can see it. Dismounted,
it is slow and fragile and can go anywhere. **The maze already had both kinds of
space in it** before anybody thought about riding.

The headroom check was specified in phase one, has passed pointlessly ever since,
and this is where it stops being pointless.

## Suggested implementation steps

1. Add `willing` to the body store; a dinosaur that has just been attacked is not
   a mount, and "any human may climb any dinosaur" produces a party that mounts
   and dismounts at random whenever two of them brush past.
2. Add the human-to-dinosaur meet entry.
3. Write the roster move into `carried` and back.
4. Write the derived position, used by the renderer and by nothing else.
5. Make the `index` pass skip carried bodies entirely — they are in their mount's
   cell, and skipping them also stops the meet pass pairing a rider with whatever
   its mount walks past.
6. Draw the mount then the rider, both from the mount's bucket.
7. Test: a ridden pair is refused entry to a corridor its mount alone could
   enter... and to one with a ceiling its mount alone could pass under. A mount
   killed mid-step drops its rider onto a legal surface.

## Related documents and tools

- [Riding and being ridden](../docs/022-riding-and-being-ridden.md)
- [Standing somewhere and going elsewhere](../docs/004-standing-somewhere-and-going-elsewhere.md)
