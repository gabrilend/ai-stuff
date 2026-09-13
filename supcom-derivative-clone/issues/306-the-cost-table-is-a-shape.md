# 306 — The cost table is a shape

| | |
| --- | --- |
| Phase | 3 — Inflows and Outflows |
| Blocked by | 202 |
| Blocks | 307, 501, 608 |
| Reads | [territory mass and energy](../docs/005-territory-mass-and-energy.md) |
| Open questions | B1 |

## Current behavior

Nothing. The unit catalogue (issue 202) gives every kind its hits, domain and
heights; it does not yet say what anything costs, and nothing asks.

What exists that bears on this: `tests/021-inflows-and-outflows.lua` names this
issue and asserts the **relations** and nothing else: for every land kind the
mass is ten times the energy; for every air kind the energy is ten times the
mass; for every sea kind the two are equal; for the anti-air gun the two are
equal; a tier-two kind costs ten times its tier-one cousin in the resource its
alignment leans on; an experimental costs a hundred times. The test never
asserts a magnitude. The economy document gives the ratios as the design.

## Intended behavior

The vision gives the costs as ratios, and the ratios are the design:

| Alignment | Mass : energy |
| --- | --- |
| land | ten to one |
| air | one to ten |
| sea | ten to ten |
| land that shoots air | equal parts |

Tier two costs a hundred of whichever resource its alignment leans on; an
experimental costs a thousand. The demo's tank leans on mass, its helicopter on
energy, its frigate and anti-air gun pay both.

The **cost table** is a catalogue table under `assets/`, one row per kind,
holding a mass and an energy, both integers, and a build time in ticks. It is
data, not code: no document quotes a magnitude, and the magnitudes move through
the balance ledger, never through an issue. What this issue fixes is the
**shape** — the invariants the table must satisfy — and the shape is checked at
load. A catalogue whose tank has more energy than mass is refused by name before
a match starts, because a wrong shape is a wrong game and not a tuning matter.

The invariants are written once, as a table of rules keyed by alignment, and
the loader walks every row against the rule for its row's alignment. Adding an
alignment is adding a rule. The same rule table is what the documentation's toy
(issue 608) draws its sliders from, so the pages and the loader cannot disagree
about what the shape is.

The vision's magnitude sketch — that most units sit in a band of mass and a
band of energy — cannot describe a tank under the ratios, and B1 records that.
The catalogue's first values are the vision's first guesses reconciled toward
the ratios, and the ledger records every move after.

## Suggested implementation steps

1. Claim the `cost-table` stem under `assets/` with `./new-source-file --into
   assets`. The table holds one row per unit kind (issue 202), plus rows for
   builders, engineers, energy buildings, and a thorn's unit of capacity:
   `mass` (integer), `energy` (integer), `ticks` (integer), `alignment` (integer
   indexing the rule table), `tier` (integer).
2. Export `for_kind(kind)` returning the mass and energy, refusing an unknown
   kind by name; and `RULES`, the alignment-keyed table of ratio checks.
3. Write the shape validator, run at load with the rest of the catalogue: every
   row's mass and energy satisfy its alignment's rule; every tier-two row costs
   ten times some tier-one row of the same alignment in the leaning resource;
   every experimental row a hundred times. A failed check names the row and the
   rule.
4. Put the first values in, reconciled from the vision's sketch toward the
   ratios, and open the balance ledger with them so the first move is recorded.
5. Make construction (issue 305) read `for_kind` and nothing else for a cost.
6. Add the relation claims to `tests/021-inflows-and-outflows.lua` — all of them
   as ratios and multiples, none as numbers.

## Related documents and tools

- [territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — the cost table as a shape
- [the shape of the code](../docs/013-the-shape-of-the-code.md) — balance numbers do not live in prose
- [balance updates](../docs/balance-updates.md) — where the magnitudes move
- `tests/021-inflows-and-outflows.lua`
- issue 202 — the unit catalogue this table sits beside
- issue 608 — the toy that draws its sliders from the rule table

## Still open

- B1: the cost magnitudes against the ratios — the vision's two statements
  cannot both describe a tank; this issue builds the ratios as invariants and
  leaves the magnitudes to the ledger, and B1 stays open until a person picks
  the band.
- Whether build time should be derived from cost rather than stored beside it.
  Stored, for now, because a derived time is one more rule to explain and the
  table is easier to tune with the number in it.
