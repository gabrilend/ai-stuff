# 501 — Everyone has the same experimentals

| | |
| --- | --- |
| Phase | 5 — The Big Things |
| Blocked by | 202, 306 |
| Blocks | 502, 503, 504 |
| Reads | [enforcers and experimentals](../docs/009-enforcers-and-experimentals.md) |
| Open questions | none |

## Current behavior

Nothing. The unit catalogue from issue 202 holds the demo's six kinds and the
cost table from issue 306 knows two tiers. There is no third tier, no
experimental row, and no module with the stem `experimentals`.
`tests/023-the-big-things.lua` looks for that stem and asserts that every
experimental row costs the tier's multiple of its alignment's leaning resource,
and that no row anywhere in the catalogue names a team.

## Intended behavior

The vision's rule, whole: **"everyone has the same experimentals."** No faction,
no team-specific kind, no exclusive line. Every team can build the same five
machines, and each one "takes one attack pattern and maximizes its impact."

This issue is the catalogue work the other four rest on. The experimentals are
**rows in the unit catalogue** like every other kind — the same record, the same
fields — with a `tier` of three. The cost table's tier multiplier does the
pricing: a thousand of the resource the alignment leans on, derived from the
tier-one magnitude by the same rule that gives the enforcer its hundred, so that
a change to the magnitude moves all three tiers together and the ratio the
vision wrote holds without anybody typing a thousand.

The five rows, with the pattern each maximises:

| Row | Alignment | Maximises |
| --- | --- | --- |
| artillery | land | range — issue 502 |
| gunship | air | damage — issue 503 |
| land carrier | land | utility — issue 504 |
| underwater carrier | sea | utility — issue 504 |
| air factory | air | utility — issue 505 |

Each has a **line** in the line catalogue (issue 307) that any team's factory
of the right domain can lay. There is no faction field in any catalogue and no
team check anywhere in the emit pass; the validator asserts the first, and the
absence of a place to put the second is the design.

The module `experimentals` holds the rows' behaviour that is not already a
plain unit's — the carrier pass, the flat falloff curve's registration — so that
the big things are one file to read and the unit record is not.

## Suggested implementation steps

1. Add a `tier` field (integer, one to three) to every row of the unit catalogue
   (issue 202); the six demo kinds are tier one except the enforcer.
2. In `cost-table` (issue 306), make `for_kind(kind)` apply the tier multiplier
   from a three-row table rather than a per-kind number, and have the validator
   refuse a row whose written cost disagrees with the derived one.
3. Add the five rows to the catalogue with their alignment, domain, reach,
   eye and profile heights, and tier three. Balance numbers go in the rows and
   the ledger, not here.
4. Add five lines to the line catalogue, one per row.
5. Create `src/NNN-experimentals.lua` with `./new-source-file`, exporting
   `rows()` and a `carrier_pass(world)` that raises by name until issue 504
   fills it.
6. Extend the catalogue validator: no row carries a `team` field; every tier
   three row has a line; every line's kinds exist.
7. Write the companion, and the test's two assertions.

## Related documents and tools

- [Enforcers and experimentals](../docs/009-enforcers-and-experimentals.md)
- [Territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — the cost table is a shape
- [Factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md) — lines
- `tests/023-the-big-things.lua`

## Still open

- Whether an experimental should need a tier-three factory to build it, or any
  factory of its domain with enough patience. The vision's streaming economy
  suggests the latter: the cost is the gate, not a building.
- Whether the demo should ship the rows unbuildable, so that the price points
  guide the balance of the six demo kinds without the machines existing yet.
