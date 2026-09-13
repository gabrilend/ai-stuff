# 304 — Builders are cheap and engineers are not

| | |
| --- | --- |
| Phase | 3 — Inflows and Outflows |
| Blocked by | 104, 106 |
| Blocks | 302, 305, 309 |
| Reads | [territory mass and energy](../docs/005-territory-mass-and-energy.md) |
| Open questions | D2 |

## Current behavior

Nothing. The world has flat arrays for cells and, from phase 2, for units; it has
no arrays for labour. Nothing in the simulation can build anything, because
there is no build power to draw on.

What exists that bears on this: `tests/021-inflows-and-outflows.lua` names this
issue and asserts that a roster member is a health with no position; that a
builder finishes in fewer ticks and for less than an engineer; that a hurt
member heals on the roster-recovery counter for its kind and heals faster when
the team has more engineers; and that a member at zero is gone from the count.
The economy document describes the roster.

## Intended behavior

Two kinds of labour, both counted in a **roster** rather than standing on the
field:

- **Builders** are trivial: cheap, fast to make, contributing build power and
  nothing else. A team makes more whenever it wants.
- **Engineers** take time and effort to make. They contribute build power *or*
  energy, by the menu (issue 302), and they are the thing a team cannot easily
  replace.

Per the working ruling in D2, a roster member has **no position**. It is a row
in a flat array holding a kind, a team, and a health pair — the value and the
increment it was written at, on the roster-recovery counter for its kind (issue
106). It is imagined as living around the command truck, and nothing on the
field can shoot it; the only thing that hurts it is losing ground (issue 309).
That is the design: the roster is the backline, and the backline is reached
through the map, not through a gun.

Each roster kind has its own recovery counter, so builders and engineers mend on
different rhythms. The vision says hurt members "heal slowly. More if there are
many engineers": the healing derived from the pair is scaled by the team's
engineer count over a catalogue divisor, so engineers repair each other and a
team that has lost most of its engineers mends slowest when it most needs to.
A member whose derived health is at or below zero is gone: its row is returned
to the free list and the count drops.

Making a builder or an engineer is construction (issue 305): a line with no
factory, drawing the kind's cost from the stream like anything else, finishing
into a roster row rather than onto the field. Their costs and build times are
catalogue numbers whose relation — an engineer costs more and takes longer —
is what the test asserts.

## Suggested implementation steps

1. Claim the `roster` stem with `./new-source-file`. Add to the world (issue 104)
   a roster array-of-arrays: `kind` (integer: builder or engineer, indexes a
   two-row table), `team` (integer), `health` and `health_at` (integers, the
   pair), allocated once to a catalogue maximum with a live count and a free
   list. Zero everywhere at allocation.
2. Add two recovery counters (issue 106), one per kind, with periods from the
   catalogue. Export `health_of(world, member)` deriving the current value from
   the pair, the counter, the cap, and the engineer-count scaling.
3. Export `count(world, team, kind)`, the live members of a kind; `add(world,
   team, kind)`, which takes a free row and writes a full-health pair; and
   `hurt(world, team, fraction)`, which is issue 309's entry point and is only
   stubbed here to refuse until that issue lands — a stub that silently did
   nothing would be a fallback.
4. Add a dead-member sweep to the die pass (issue 206's `die_pass`): a member at
   or below zero is returned to the free list. Keep it there rather than in the
   roster's own pass so that everything that dies, dies in one place.
5. Add builder and engineer rows to the cost table (issue 306) and let
   construction (issue 305) finish a roster line by calling `add`.
6. Add the claims to `tests/021-inflows-and-outflows.lua`: no position, cheaper
   and faster, per-kind healing scaled by engineers, gone at zero.

## Related documents and tools

- [territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — the roster and what hurts it
- [the tick and the timers](../docs/003-the-tick-and-the-timers.md) — the pair of integers every health uses
- `tests/021-inflows-and-outflows.lua`
- issue 106 — the counters the recovery runs on
- issue 309 — the only thing that hurts a roster member

## Still open

- D2: whether the roster has positions — the working ruling is no, and this
  issue is written to it; if roster members become bodies on the field, they
  become unit rows (issue 201) and this array goes away.
- Whether a team starts with a roster, and of what size, or must build its
  first builders with its command truck. The starting roster is an input file
  matter, not a rule; noted so the headless runner (issue 110) knows to read it.
