# 412 — Contributing a Stone

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 402, 404 |
| Blocks | 413, 703 |
| Reads | [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | none |

## Current behavior

Contributing puts a stone in a communal pool where any teammate may use it,
forever, and it appears to each of them as simply one of theirs — no owner shown. It
is one-way, because *whose is it really* is the question the pool exists to delete.

Dismissing is the safety on it: a communal stone can be set aside, and when everybody
has set aside the same one it comes back to all of them.

## Intended behavior

Two verbs that move a stone between players, pointing in different directions.

### `contribute_upgrade` — to everybody

A player contributes one of their stones to the **communal pool**. Once there any
teammate may place it, move it, and place it again.

**It shows up to each of them as simply one of the stones they have.** No owner
recorded in the interface, no *this one is Sam's*, no asking. The record still
knows — `held_by` goes to 0 — but nothing drawn on screen distinguishes a
communal stone from a private one.

That is the whole point and it wants a comment saying so: **a shared thing you
have to remember is shared is not shared.** Remembering costs a small permanent
tax of attention and etiquette, and that tax is what made a lock system seem
necessary in the first place.

**Contributing is one-way.** A stone in the pool does not come back to the giver,
because *whose is it really* is the exact question the pool exists to delete.

### `offer_upgrade` — to one person

A player offers one of their stones to a **named teammate**, and it becomes
theirs — to place, to contribute, or to offer on.

It is the only verb in the game that **transfers** anything. Contributing puts a
stone where anybody might use it; offering puts it in one person's hands because
you think they specifically should have it.

Both cost the giver something real and visible. Neither can be done by accident,
and neither can be done *to* somebody.

## Suggested implementation steps

1. Add `held_by` to the instance record — the owning player, or 0 for communal.
   Every existing check that asked "is this my team's" becomes "is this mine or
   communal."
2. Write `contribute_upgrade`: refuse if not the caller's, refuse if already
   communal, set `held_by` to 0, raise an event.
3. Write `offer_upgrade`: refuse if not the caller's, refuse if the target is not
   a living teammate, set `held_by` to the target.
4. **Do not put ownership into the viewer's frame for communal stones.** The
   frame should carry "this is available to you" and not "this was Sam's." A
   field the renderer is trusted not to draw is a field that gets drawn
   eventually.
5. Write a test that a contributed stone is placeable by every teammate and by no
   opponent.
6. Write a test that an offered stone is placeable by the recipient and **not** by
   the giver.

## Related documents and tools

- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md)
- Issue 413 — the dismissal cycle, which only applies to communal stones
- `issues/will-not-implement/406` — the locking design this replaced
