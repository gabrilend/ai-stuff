# 306 — Falling Is Shared By Everybody

| | |
| --- | --- |
| Phase | 3 — The Rolling |
| Blocked by | 102, 107, 303 |
| Blocks | 401, 702 |
| Reads | [rolling with momentum](../../docs/013-rolling-with-momentum.md), [locomotion is a dispatch table](../../docs/012-locomotion-is-a-dispatch-table.md) |
| Open questions | none |

## Current behavior

`Locomotion.apply_falling`, called by both built rows. A walker that walks off a
ledge abandons its step rather than resuming it, because the surface it was
heading for is no longer adjacent to where it landed.

`check_in_world` raises and names the row that let the body get there, which is
the one piece of information the stack trace will not have.

## Intended behavior

Falling is **one piece of machinery every locomotion row calls**, not something
each row implements. A body that has left its surface with nothing under it gains
downward velocity, descends, finds the highest surface below, and lands.

That is identical for a ball that went over a cliff, a little guy that walked off
a terrace, a rider dropped when its mount died, and a vine that let go. Writing
it once is what keeps them agreeing about what a fall is.

Landing: `vz` is reversed and multiplied by `restitution`, and if what remains is
below `bounce_floor` it is set to zero and the body is on a surface again.

`bounce_floor` is not a nicety. Without it a bouncing body's `vz` approaches zero
without reaching it, and the body spends the rest of the run performing several
hundred infinitesimal bounces a second — each one a landing event, none of them
visible, all of them costing.

A walker that lands re-enters walking with its stance set to where it landed. It
does not resume its interrupted step; the step it was taking is abandoned,
because the surface it was stepping toward is no longer adjacent to where it now
is.

The **leaving-the-world** check lives here too. The rim makes it impossible and
the check runs anyway, and it is loud, and the message names the locomotion row
that let the body get there.

## Suggested implementation steps

1. Write `begin_fall(store, bodies, id)` — clear the stance's grip, keep the
   horizontal velocity, zero `vz` if it was not already falling.
2. Write `advance_fall` — gravity on `vz`, integrate `z`, test against
   `highest_surface_below` for the body's current cell.
3. Write `land` with the restitution and the `bounce_floor` cutoff.
4. Call it from the shared part of the move pass, after every row has advanced,
   so a row cannot forget to.
5. Test: a body dropped from every layer lands on the correct surface, in a
   number of ticks that matches the closed-form fall time to within one tick. A
   body dropped onto a surface with `restitution` at zero does not bounce at all
   and its `vz` reaches exactly zero rather than approaching it.

## Related documents and tools

- [Locomotion is a dispatch table](../../docs/012-locomotion-is-a-dispatch-table.md)
- [Rolling with momentum](../../docs/013-rolling-with-momentum.md)
