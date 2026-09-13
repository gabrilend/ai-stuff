# 201 — A unit is one record

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 104 |
| Blocks | 202, 203, 204, 205, 207, 209, 210, 401 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

Nothing. There is no source. The world's flat arrays (issue 104) are the ground
this stands on and do not exist yet either. The test program
`tests/020-things-that-roll-fly-and-sail.lua` names this issue and looks for a
source file with the stem `units`; today it reports that file as a named
absence.

## Intended behavior

Every unit on the field — tank, anti-air gun, helicopter, frigate, command truck,
enforcer, and in the full game everything larger — is **one row across a set of
flat arrays**. There is no class hierarchy and no per-kind record type. A frigate
is a tank with a different domain and a different row in the catalogue, and the
tick walks all of them in one loop from one to the live count.

The columns, one array each, every entry an integer or a double, none ever
absent:

| Column | Type | Holds |
| --- | --- | --- |
| kind | integer | index into the unit catalogue (issue 202) |
| team | integer | which side owns it |
| x, y | double | position on the field |
| domain | integer | land, air, or sea — copied from the catalogue at birth |
| altitude | double | height above the ground; zero for land and sea |
| health, health_at | integer, integer | the heal pair: value written, and the increment it was written at |
| reload_at | integer | the increment the weapon last fired at |
| pattern | integer | which pattern it follows; zero for a plane |
| leg | integer | which segment of the pattern it is on |
| mission | integer | a plane's mission; zero for anything that is not a plane |
| target | integer | the unit it is shooting at; zero for none |
| damage, falloff | integer, integer | copied from the catalogue at birth |
| eye, profile | double, double | how high it looks from, how tall it looks |
| shield, shield_at | integer, integer | the enforcer's shield pair; zero for everything else |
| eaten | integer | mass an enforcer has consumed |
| alive | integer | one while the row is live, zero once it is bones |

**Copied at birth.** A unit carries its own copies of damage, falloff, eye,
profile, domain, and its pattern reference. It holds no reference to its
factory, its team's upgrade table, or the catalogue. The firing path and the
movement path touch only the unit's own row, which is what lets the thread pool
(issue 209) slice them, and it is the vision's "they don't listen after they've
left the factory" arrived at from the performance side.

**Zero is the sentinel.** A tank has a shield of zero, not a missing shield. A
unit with nothing to shoot has a target of zero. Whether every column was filled
is a question the world validator asks once at load and the tick never asks.

Spawning writes a row at the next free index and raises the live count. Killing
(issue 208) marks the row dead; the arrays are never compacted mid-tick, because
compaction would move rows out from under a sliced system holding an index.
Compaction, if it is ever needed, is its own unsliced step at the end of a tick.

## Suggested implementation steps

1. Claim `src/NNN-units.lua` with `./new-source-file units`. Its companion lists
   every column above with its type.
2. Extend the world allocation from issue 104 with one flat array per column,
   sized from the parameters' unit capacity, every entry zero. Prefer an FFI
   struct-of-arrays where the column is numeric and hot.
3. Write `spawn(world, kind, team, x, y)`: reads the catalogue row for `kind`,
   copies domain, damage, falloff, eye, profile, altitude, and the health cap
   into the new row, sets `health_at` to the current increment of the kind's
   heal counter, marks `alive`, and returns the row index. Refuses — by name —
   a kind the catalogue does not have and a world with no free row.
4. Write `alive(world)`: the count of live rows, kept as a field rather than
   re-counted.
5. Write the row validator, called from the world validator: no column of a
   live row holds a non-number; `kind` indexes a catalogue row; `domain`
   agrees with the catalogue.
6. Write a text dump of one row for the terminal viewer and for test failures.

## Related documents and tools

- [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- [the tick and the timers](../docs/003-the-tick-and-the-timers.md)
- [the shape of the code](../docs/013-the-shape-of-the-code.md)
- `tests/020-things-that-roll-fly-and-sail.lua`

## Still open

Nothing beyond the questions in the table. Whether the row arrays are Lua
tables or FFI arrays is a measurement for the headless runner, not a decision
for this issue; the exports are the same either way.
