# 311 — Improving territory

| | |
| --- | --- |
| Phase | 3 — Inflows and Outflows |
| Blocked by | 301, 305 |
| Blocks | — |
| Reads | [territory mass and energy](../docs/005-territory-mass-and-energy.md) |
| Open questions | A7 |

## Current behavior

Nothing. Held ground pays a flat amount per cell (issue 301), and there is
nothing a team can do to a cell it holds except keep holding it.

What exists that bears on this: `tests/021-inflows-and-outflows.lua` names this
issue and asserts only the smallest thing the vision's sentence requires: that
spending both mass and energy on a held cell raises what that cell pays, and
that the improvement is gone when the cell is lost. The economy document gives
the sentence and marks the rest open.

## Intended behavior

**This issue is entirely open, and it says so.** The vision has one sentence —
"mass comes with territory. Also you can assign energy and mass to improving
it" — and everything below is the working ruling in A7, written as the smallest
mechanism that could satisfy that sentence, so that it can be built to find out
whether it is the right one and replaced without regret if it is not. It should
not be started until A7 has been worked through with a person; the phase 3
progress file says the same.

The smallest mechanism: an **improvement level** per cell, an integer, zero at
raising. A team may spend both mass and energy — a construction stream (issue
305) opened on a held cell, with its own row in the cost table — to raise the
cell's level by one. A cell's mass payment (issue 301) is the base pay plus the
level times a catalogue amount, so an improved cell pays more for as long as it
is held. When the cell changes hands, the level is reset to zero: the
improvement was the team's, and the ground remembers nothing. This is the one
mass sink that is not a unit, and it decides whether holding ground compounds —
which is exactly why it wants a person's answer before it is built.

What it deliberately does not decide: whether improvement is per cell or per
team; whether it could also raise the cell's claim time, its thorns, or its
sight; whether an improved cell should be visible to the enemy; and whether the
level should survive a change of hands as a prize for the taker. Each of those
is a different economy, and A7 is the place they are weighed.

## Suggested implementation steps

1. Work A7 through with a person. Do nothing below until it is answered or the
   working ruling is explicitly accepted as the thing to build first.
2. Add to the world a per-cell `improvement` array, integers, zero at
   allocation, allocated beside the ownership array (issue 112).
3. Add an improvement row to the cost table (issue 306) — both resources, by
   design — and a construction opener (issue 305) whose finish handler
   increments the cell's level. Add a verb to the door (issue 108) carrying a
   cell; it is refused, by name, for a cell the team does not hold.
4. Make the income pass (issue 301) read the level: pay per cell becomes base
   plus level times the catalogue's step, summed in the same sliced walk.
5. In the consequences pass (issue 309), reset the level of every cell that
   changed hands this tick.
6. Add the two claims to `tests/021-inflows-and-outflows.lua`, and no more,
   until A7 says what else is true.

## Related documents and tools

- [territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — the one sentence, and the working ruling
- [open questions](../docs/016-open-questions.md) — A7, where this is decided
- `tests/021-inflows-and-outflows.lua`
- issue 301 — the pay this raises
- issue 305 — the stream this spends through

## Still open

- A7: what improving territory is. Everything in this issue is the working
  ruling; the questions it does not decide are listed above and belong there.
- Whether an improvement should be undoable — mass and energy back for a level
  down. Not built; nothing else in the economy refunds.
