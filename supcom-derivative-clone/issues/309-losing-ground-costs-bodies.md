# 309 — Losing ground costs bodies

| | |
| --- | --- |
| Phase | 3 — Inflows and Outflows |
| Blocked by | 112, 304 |
| Blocks | — |
| Reads | [territory mass and energy](../docs/005-territory-mass-and-energy.md) |
| Open questions | none |

## Current behavior

Nothing. Territory changes hands (issue 112) and the roster exists with health
(issue 304), but nothing connects the one to the other: a team can lose every
cell it holds and its builders and engineers are untouched.

What exists that bears on this: `tests/021-inflows-and-outflows.lua` names this
issue and asserts that when a team's territory percentage falls by some amount
in a tick, the same fraction of its roster is hurt that tick; that which members
are hurt is drawn on a named stream so two machines hurt the same ones; that a
hurt member heals on its kind's counter; and that gaining ground hurts nobody.
The economy document describes the consequence.

## Intended behavior

When a team's territory falls by a percentage, **the same percentage of its
builders and engineers are hurt.** Lose four percent of the ground, and four
percent of the roster takes damage — the vision's own example. The members are
chosen at random on the `roster-hurt` stream (issue 107), take a catalogue
amount of damage each, and heal on their kind's recovery counter (issue 304). A
member at zero is gone.

This is how an air war reaches the backline, and it is the only way anything
reaches it: planes that get through take ground under nobody's guns, and every
percent taken is a percent of the labour force in the infirmary. The roster has
no position and cannot be shot; it is hurt through the map, which is the design.

The measurement is per tick, on the territory percentage from issue 112: the
consequences pass compares each team's percentage now to its percentage at the
end of the last tick, and a fall is the fraction to apply. Gaining ground heals
nobody and hurts nobody. The count of members to hurt is the fraction times the
live roster count, rounded down in integer arithmetic, and a fall too small to
reach one member hurts nobody — a fractional remainder is not carried, because
a carried remainder is hidden state that two machines could disagree about.

The chosen members are drawn without replacement from the live roster in array
order, which is stable, so the stream and the count fully determine who is hurt.
The damage is applied through the health pair, the same as a shell landing on a
unit: derive, subtract, rewrite at the increment of now.

## Suggested implementation steps

1. Add to the world a per-team `territory_last_tick` (an integer count of cells,
   so the comparison is exact rather than a percentage of doubles).
2. In the `roster` stem, fill in `hurt(world, team, fraction)` (stubbed in issue
   304): compute the count, draw that many distinct indices from the live
   members on the `roster-hurt` stream, apply the catalogue damage to each
   through the pair. Register `roster-hurt` as a named stream (issue 107).
3. Add a `consequences_pass(world)` to the `economy` stem — the twelfth row of
   the tick (issue 105) — that, for each team, compares held cells now against
   last tick, calls `hurt` with the fraction of a fall, and records now as
   last. Thorns (issue 310) and lost energy buildings (issue 303) hang off the
   same pass, so everything that follows from ground changing hands happens in
   one place and in one order.
4. Let the dead-member sweep in the die pass (issue 304, step 4) remove anyone
   the damage took to zero, on the same tick.
5. Report the count hurt per team per tick in the snapshot (issue 109), so the
   headless runner and the roster display (issue 604) can show the infirmary.
6. Add the claims to `tests/021-inflows-and-outflows.lua`: same fraction, named
   stream, healing after, no harm from gains, no harm from a fall too small
   for one member.

## Related documents and tools

- [territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — losing ground costs bodies
- [the cloud](../docs/007-the-cloud.md) — how the air war reaches the roster
- `tests/021-inflows-and-outflows.lua`
- issue 112 — the percentage this measures
- issue 304 — the roster this hurts
- issue 107 — the stream that decides who

## Still open

Nothing cited in the table. Two things this issue raises:

- Whether builders and engineers are hurt in the same proportion, or engineers
  spared first. The vision says both, equally; built that way.
- Whether a fall that spans several ticks should be measured against a
  high-water mark rather than tick to tick, so that ten small losses cost the
  same as one large one. Tick to tick, for now; the rounding makes small
  losses cheaper, and whether that is a problem is a proving-ground question.
