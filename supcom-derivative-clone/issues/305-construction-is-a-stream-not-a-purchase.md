# 305 — Construction is a stream, not a purchase

| | |
| --- | --- |
| Phase | 3 — Inflows and Outflows |
| Blocked by | 301, 304 |
| Blocks | 307, 310, 311 |
| Reads | [territory mass and energy](../docs/005-territory-mass-and-energy.md) |
| Open questions | D3 |

## Current behavior

Nothing. Mass arrives (issue 301) and the roster exists (issue 304), but nothing
spends the one or draws on the other. There is no construction pass in the tick.

What exists that bears on this: `tests/021-inflows-and-outflows.lua` names this
issue and asserts that a build draws its cost across its ticks in proportion to
the build power on it; that a build stalls, and every other build stalls with
it in proportion, when a resource is dry; that a stalled build resumes without
loss when income returns; and that build power is split evenly across
everything under construction. The economy document describes the stream.

## Intended behavior

Nothing is paid for up front. A build — a unit on a line, an energy building, a
roster member, a thorn's worth of defence — is a **stream**: each tick it draws a
share of its mass and energy in proportion to the build power working on it,
and it finishes when the stream has delivered the whole cost. This is the
economy of the game this one derives from, and it is what makes overbuilding a
visible mistake instead of a hidden one: a team that lays more lines than its
ground pays for watches every one of them slow down together.

**Build power** is the roster's builders plus the engineers on build duty
(issue 302's split). Per the working ruling in D3, it is **split evenly** across
everything under construction — more things building means each one builds
slower, never that one is starved for another. The exception is energy raising
(issue 303), whose build power is the energy-duty engineers and whose stream is
kept separate so that the menu's lever trades one against the other cleanly.

A build's progress is a pair of integers: mass delivered and energy delivered.
Each tick, the construction pass computes for each build the share it would
draw — its allotted build power over the build's total work, times its cost in
each resource — and then asks whether the team's totals can cover the sum of
every build's share this tick. If they can, every share is drawn and delivered.
If a resource is short, **every build drawing that resource is scaled by the
same fraction** — what the team has over what was asked — so that a shortage
slows the whole economy proportionally and no build silently jumps the queue.
That fraction is integer arithmetic on the totals, so two machines scale
identically.

A build whose delivered pair equals its cost pair finishes on that tick and is
handed to whoever opened it: a line emits a unit (issue 307), a roster line adds
a member (issue 304), an energy line sets a building standing (issue 303).

## Suggested implementation steps

1. In the `economy` stem, add a build array-of-arrays on the world: `kind` (an
   integer indexing the cost table), `team`, `opener` (an integer naming which
   system opened it, indexing a dispatch table of finish handlers), `opener_row`
   (the line, building, or roster slot), `mass_delivered`, `energy_delivered`,
   all integers, allocated once with a live count and free list.
2. Export `open(world, team, kind, opener, opener_row)` returning a build id, and
   `build_power(world, team)` returning builders plus build-duty engineers.
3. Export `construction_pass(world)`: compute every build's asked share, sum per
   team per resource, compute the scaling fraction where a total is short,
   deliver the scaled shares, subtract from the totals, and call the finish
   handler for every build whose pair has reached its cost. The finish handlers
   are a dispatch table keyed by `opener`; adding an opener is adding a row.
4. Register `construction_pass` as the third row of the tick's dispatch table
   (issue 105), after income and before emit.
5. Refuse, by name, an `open` for a kind the cost table (issue 306) does not
   hold, and a `construction_pass` that finds a build whose opener has no
   handler. Neither is a case to default around.
6. Add the claims to `tests/021-inflows-and-outflows.lua`: proportional draw,
   proportional stall, lossless resume, even split.

## Related documents and tools

- [territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — construction as a stream
- [the tick and the timers](../docs/003-the-tick-and-the-timers.md) — where the pass sits
- `tests/021-inflows-and-outflows.lua`
- issue 301 — the mass this draws on
- issue 304 — the build power this draws with
- issue 307 — the first opener

## Still open

- D3: whether build power is split evenly — the working ruling is yes; a
  priority scheme would be a per-build field and a sort, and the test for the
  even split would change to a test for the priority.
- Whether a stalled build should ever be abandoned with its delivered resources
  refunded. Not built; a stall is a signal to the player, not a state the
  simulation resolves.
