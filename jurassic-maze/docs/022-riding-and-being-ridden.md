# Riding And Being Ridden

A human on a dinosaur is two bodies and one thing that moves. Neither body is
destroyed, neither is absorbed, and pulling them apart is one field being set
back to zero.

## The arrangement

| Body | What changes |
| --- | --- |
| the rider | its locomotion becomes `carried`; its `partner` is the mount |
| the mount | its `partner` is the rider; it now takes its intent from the rider rather than deciding for itself |

The rider's position is not stored while it is carried. It is **derived**: the
mount's position, plus one layer of height, plus a small offset in the direction
the mount is facing. Deriving rather than storing means the two can never drift
apart, which is the failure mode of every version of this that keeps two
positions in step by updating both.

The `carried` row of
[the locomotion table](012-locomotion-is-a-dispatch-table.md) does nothing at
all. That is the correct amount of work for a body that is not moving under its
own power, and having it be a row rather than a flag means the move pass does not
need to know that riding exists.

## Mounting

Through [the meet pass](016-two-bodies-meeting.md), like everything else two
bodies do. A human adjacent to a willing dinosaur, both in the delve, neither
already partnered: the fields above are set and the rider is removed from the
`walking` roster and added to the `carried` one.

Willingness is a field on the dinosaur, because a dinosaur that has just been
attacked is not a mount, and because "any human may climb any dinosaur at any
time" produces a party that spends its time mounting and dismounting at random
whenever two of them brush past each other.

## Dismounting

Four ways, and the last two are the interesting ones:

1. **On purpose.** The rider's brain decides to.
2. **The mount dies.** The rider is dropped where the mount was and falls if
   there is nothing under it.
3. **The ceiling is too low.** The pair's height is the mount's plus one, so
   there are places a dinosaur fits and a *ridden* dinosaur does not. The
   headroom check in
   [the movement rule](004-standing-somewhere-and-going-elsewhere.md) refuses the
   move, and the party's choice is to dismount or go around.
4. **The corridor is too narrow.** The pair's footprint is the mount's, so
   riding into a one-cell corridor is impossible even though the rider alone
   walks down it easily.

Points three and four are the whole reason riding is worth building. Mounted, a
party is fast, strong, and restricted to the wide open parts of the maze where
everything can see it. Dismounted, it is slow and fragile and can go anywhere.
The maze already had both kinds of space in it before anybody thought about
riding — see [the habitat](019-dinosaurs-in-a-habitat.md) — and riding is the
mechanism that makes the difference matter.

Headroom was specified in the movement rule long before there was anything with a
ceiling over it, and the check has been passing pointlessly ever since. This is
where it stops being pointless.

## Dinosaurs with weapons

A dinosaur in the delve carries a weapon: a row in the equipment table giving
reach, damage, and what it is made of — which matters, because a wooden weapon
[burns](023-the-monsters-of-the-delve.md).

Reach is the field that changes behaviour rather than numbers. A dinosaur with a
long weapon can strike a body two cells away, which means it can fight down a
corridor it cannot itself enter, and that is the mounted party's answer to the
narrow places it cannot go.

## Drawing a pair

The mount is drawn, then the rider, in that order, from the mount's bucket.
Both are in the same cell, so both are drawn at the same point in the renderer's
sweep, and the rider being second is what puts it on top.

A rider is never in its own bucket while carried. The `index` pass skips
`carried` bodies entirely — they are not in a cell of their own, they are in
their mount's — and skipping them is also what stops the meet pass from pairing a
rider with something its mount is walking past.

## Related documents and tools

- [The delve](021-the-delve.md) — the mode this belongs to
- [Two bodies meeting](016-two-bodies-meeting.md) — where mounting happens
- [Standing somewhere and going elsewhere](004-standing-somewhere-and-going-elsewhere.md) — the headroom check
