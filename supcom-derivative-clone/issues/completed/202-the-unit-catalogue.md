# 202 — The unit catalogue

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 201 |
| Blocks | 205, 306, 501, 608 |
| Reads | [a unit and what it carries](../../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | B1, B2 |

## Current behavior

Built. `assets/040-unit-catalogue.lua` holds one row per demo kind, keyed by
name, every field a number or a name. `units.catalogue()` loads it once,
refuses a bad row by its name and field, and converts every time in seconds to
ticks at the rules' rate. Kinds have indices (`index_of`, `name_of`), each kind
heals on a counter of its own, and each claims territory with its own radius.
`./report-catalogue` prints every row and the hits to kill in tank shells.

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

## What happened

- **The asset is data only; the loader lives in the units module.** The
  phase 2 test walks every entry of the asset as a row, so the table cannot
  carry functions. `catalogue()`, `validate_catalogue(raw, rate)`, `kind`,
  `index_of` and `name_of` are exports of `units`, and the contract table in
  the tests document now lists them.
- **`heal_period` is the field's name, in seconds**, because the tests
  document and the test use that name; the other times keep the issue's
  `*_seconds`. Each becomes a `*_ticks` field at load.
- **Each row carries `index` and `name`**, so a unit row's `kind` is an
  integer and the order of kinds never depends on how a table iterates.
- **A weapon comes all of a piece.** Damage above zero needs a non-empty
  reach, a shell speed and a reload; a kind with no damage (the command truck)
  must reach nothing. That replaces "reaches is a non-empty bit set", which the
  truck could not meet.
- **Other refusals added:** a field the catalogue does not know, a zero
  health, a shield without a recharge period or the reverse, and an altitude on
  anything but a plane. Zero-length times stay zero rather than one tick, since
  a truck has no reload.
- **Per-kind claim radius (B6):** two cells for the tank, the anti-air gun,
  the frigate and the truck, four for the enforcer, and zero for the
  helicopter, which claims nothing. The rules' single `claim_radius` is gone
  and the claim pass reads each unit's own; the balance ledger records the move.
- **B1 and B2 stay open, with working values.** A shell is worth 25; the
  helicopter takes two and the frigate eight. Costs follow the vision's
  ratios: ten to one mass for land, the reverse for air, equal for the sea and
  for the anti-air gun.
- **The viewer's letters follow the catalogue's index**: T, A, H, F, C, E. A
  phase 2 test holds the two together, since the viewer may not load the
  catalogue.

## Related documents and tools

- [a unit and what it carries](../../docs/004-a-unit-and-what-it-carries.md)
- [territory, mass, and energy](../../docs/005-territory-mass-and-energy.md) — the cost table's shape, asserted by issue 306
- [the balance ledger](../../docs/balance-updates.md)
- `tests/020-things-that-roll-fly-and-sail.lua`

## Still open

- **B1.** The vision's cost ratios and its cost bands cannot both describe a
  tank; the ratios are the design and the bands are a sketch, and this table
  holds working magnitudes until the ledger moves them.
- **B2.** The vision gives no hits-to-kill for the helicopter or the frigate;
  the working ruling is two and eight.
