# 203 — Three domains on one field

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 102, 201 |
| Blocks | 204, 401, 506 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

Nothing. The field (issue 102) has a water line and the unit row (issue 201)
has a domain column, and neither exists. The test program
`tests/020-things-that-roll-fly-and-sail.lua` names this issue and looks for the
stem `domains`.

## Intended behavior

Land, air, and sea are all in from the first build, because the vision says
scaling is the thing that is hard to unfix once a program has specialised.
**There is no separate ship, plane, or tank code.** A domain is an integer in
the unit row, and the one question it changes — *may this unit stand here?* —
is answered by a single function reading the heightfield:

- **Land** may stand on any cell whose height is at or above the water line.
- **Sea** may stand on any cell whose height is below it.
- **Air** may stand anywhere; its altitude is the ground beneath plus its flight
  height, so a plane crossing a dune climbs with it.

That function is the whole of what a domain means to movement. Targeting reads a
second thing, the catalogue's `reaches` bit set (issue 202), which says which
domains a weapon may aim at — tanks and frigates reach land and sea, anti-air
reaches the air — and that is the whole of what a domain means to combat.

The domains are a **dispatch table**: the domain integer indexes a small table of
functions, one per domain, for `can_stand`. Adding a domain — submerged, for the
underwater carrier in issue 506 — is adding a row, not a branch.

Sea factories sit on the shore, a land cell with a sea cell beside it, and their
output appears on the sea cell; a helper answers *is this cell a shore cell?*
by the same height test on the cell and its neighbours, so issue 307 does not
re-derive it.

## Suggested implementation steps

1. Claim `src/NNN-domains.lua` with `./new-source-file domains`.
2. Export the domain constants as named integers (`LAND`, `AIR`, `SEA`) and the
   bit-set values for `reaches`, so the catalogue and the row share one meaning.
3. Write `can_stand(field, domain, x, y)`: rounds the position to a cell,
   refuses a position off the field by name, and dispatches on `domain` to the
   height test above.
4. Write `altitude_at(field, kind, x, y)`: ground height plus the catalogue's
   flight height, used by movement to keep a plane's altitude column current.
5. Write `is_shore(field, x, y)` for the sea factory's placement rule.
6. Write the domain validator, called from the unit validator: every live row's
   position satisfies `can_stand` for its domain. A land unit in the sea is a
   refusal at load and a bug at runtime, never a fallback.

## Related documents and tools

- [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- [the dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md) — the water line
- [factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md) — shore placement
- `tests/020-things-that-roll-fly-and-sail.lua`

## Still open

Nothing beyond the questions in the table. Whether a submerged domain is a
fourth row here or a flag on sea is issue 506's question.
