# 202 — The unit catalogue

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 201 |
| Blocks | 205, 306, 501, 608 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | B1, B2 |

## Current behavior

Nothing. `assets/` holds only its placeholder. The test program
`tests/020-things-that-roll-fly-and-sail.lua` names this issue, looks for a
table with the stem `unit-catalogue`, and asserts the *relations* between its
rows — hits-to-kill in tank shells, the cost ratios by alignment — rather than
any magnitude.

## Intended behavior

Every number that describes a kind of unit lives in **one table in `assets/`**,
one row per kind, and in no document. The rows are the six demo kinds — tank,
anti-air gun, helicopter, frigate, command truck, enforcer — with room for the
full game's kinds to be added as rows and nothing else.

Every field of every row is an integer or a double. The fields:

| Field | Type | Meaning |
| --- | --- | --- |
| domain | integer | land, air, or sea |
| reaches | integer | which domains the weapon may target, as a bit set |
| tier | integer | one, two, or experimental |
| health | integer | the heal cap |
| damage | integer | per shot, at full strength |
| falloff_full | double | distance out to which damage is full |
| falloff_floor | double | the fraction damage never falls below |
| shell_speed | double | field units per tick; decides the arrival tick |
| reload_seconds | double | converted to ticks at load |
| heal_seconds | double | the kind's heal counter period; converted at load |
| speed | double | field units per tick on flat ground |
| eye, profile | double | for sightlines |
| altitude | double | flight height; zero for land and sea |
| claim_radius | integer | cells |
| shield, shield_seconds | integer, double | the enforcer's sphere and its recharge period; zero elsewhere |
| cost_mass, cost_energy | integer | the stream's total, drawn across construction |
| build_seconds | double | how long the stream runs at unit build power |

The vision's relations are the design and the tests assert them: **a tank's
health is four of its own shells, an anti-air gun's three, a command truck's
one, an enforcer's six with a shield of four more.** The magnitudes — what a
shell is worth, what a second is — are this table's business and the balance
ledger's, and they are not written in any document.

The catalogue is **loaded once and validated**: every row has every field, every
field is a number, `domain` and `tier` are in range, `reaches` is a non-empty
bit set, `falloff_floor` is between zero and one, and every period converts to
at least one tick. A row that fails is named and the load refuses. Seconds
become ticks at load through the tick rate from issue 105, so nothing in a rule
ever multiplies by a rate.

## Suggested implementation steps

1. Claim `assets/NNN-unit-catalogue.lua` with `./new-source-file --into assets
   unit-catalogue`. The file returns a table keyed by kind name with the fields
   above; its companion is the field table with the vision's relations stated.
2. Give each kind an integer index as well as a name, so the unit row's `kind`
   column can be an integer; export both directions (`index_of`, `name_of`).
3. Write the load-time validator, listing the refusals above, called from the
   catalogue's `load(root, tick_rate)` which also converts seconds to ticks.
4. Fill the six demo rows with the vision's first values as the starting point;
   record them in `docs/balance-updates.md` the first time any of them moves.
5. Write a reporter — the tool the documents point at instead of quoting a
   number — that prints every row and the hits-to-kill relation in tank shells.

## Related documents and tools

- [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- [territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — the cost table's shape, asserted by issue 306
- [the balance ledger](../docs/balance-updates.md)
- `tests/020-things-that-roll-fly-and-sail.lua`

## Still open

- **B1.** The vision's cost ratios and its cost bands cannot both describe a
  tank; the ratios are the design and the bands are a sketch, and this table
  holds working magnitudes until the ledger moves them.
- **B2.** The vision gives no hits-to-kill for the helicopter or the frigate;
  the working ruling is two and eight.
