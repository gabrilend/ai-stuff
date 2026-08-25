# 305 — The Base Is One Open Room

| | |
| --- | --- |
| Phase | 3 — Things That Stand and Hold |
| Blocked by | 301, 303, 304 |
| Blocks | 307, 409, 410 |
| Reads | [the base and the library](../docs/008-the-base-and-the-library.md), [guard towers and their guards](../docs/007-guard-towers-and-their-guards.md) |
| Open questions | none |

## Current behavior

The three lanes each end at a separate tower, and the interior of a base is three
unconnected corridors. An invader in the top lane's mouth is untouchable by
anything guarding the bottom lane's, even though they are a few paces apart.

## Intended behavior

The interior of a base is **one open space**, not three corridors. Its three
guard towers stand at the three lane mouths and its library stands behind all of
them, reachable only by crossing that open interior.

Two consequences, and they pull in opposite directions on purpose:

**Guards answer any lane.** The three base towers share one patrol area rather
than three. A guard spawned by any base tower will move to attack an invader from
any lane, because there is nothing between them. Pushing into a base means
fighting every guard in it at once.

**Arrows do not.** A base tower's `range` is a plain radius around its own
position, so in practice it only reaches the mouth of the one lane it sits at.
Bodies flow across the base freely; arrows do not.

The strategic shape this produces, and it should be told to players in as many
words: **splitting a push across two lanes into the same base is meaningfully
better than doubling up on one.** Two lanes' worth of invaders draw the same
guards either way, but only one tower's arrows reach each. That is another shove
away from tunnel vision, and it is the same shove the siege-surge gives from the
other direction when it deals every upgrade evenly across all three lanes.

## Suggested implementation steps

1. Extend the map builder to emit base-interior nodes joining all three lane
   mouths to the library node, with `lane = 0`.
2. Give base towers a shared patrol area: a single leash node at the base's
   centre rather than one per tower, so their guards roam the whole interior.
3. Confirm that base tower radii do **not** reach the other two lane mouths, and
   put that check in the map validator rather than trusting the geometry to stay
   right when the field size changes.
4. Write a test: an invader at the top lane's mouth is engaged by guards from all
   three base towers, and shot at by exactly one of them.

## Related documents and tools

- [The base and the library](../docs/008-the-base-and-the-library.md)
- [Guard towers and their guards](../docs/007-guard-towers-and-their-guards.md)

## Still open

The vision's sentence is: "The guards in the base will move to attack any
invaders no matter which lane they came from, but the range on their arrows is
such that they probably will only be able to hit the units that came from a
single lane — it's just a radius around them." *Will move to attack* is a soldier;
*the range on their arrows* is a tower; the sentence puts both in one clause. This
issue implements both readings at once. If it means only towers, base guards do
not exist and a breach is much easier. If it means only soldiers, base towers
cover the whole interior and a breach is much harder. Worth settling before phase
6, because the challenge monsters walk straight into it.
