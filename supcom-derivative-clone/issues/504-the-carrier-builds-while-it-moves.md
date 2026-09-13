# 504 — The carrier builds while it moves

| | |
| --- | --- |
| Phase | 5 — The Big Things |
| Blocked by | 307, 308, 501 |
| Blocks | 505, 506 |
| Reads | [enforcers and experimentals](../docs/009-enforcers-and-experimentals.md) |
| Open questions | none |

## Current behavior

Nothing. A factory from issue 307 is a building on a cell and never moves; a
pattern from issue 308 belongs to a factory and is followed by its output.
Issue 501 puts two carrier rows in the catalogue — land and underwater — with
nothing that makes them carriers. `tests/023-the-big-things.lua` asserts that a
moving carrier builds without drawing mass or energy, unleashes what it built
when it stops, does not unleash when told to keep hold, and does unleash when
held and hit.

## Intended behavior

A carrier is **a factory with a pattern.** It is a unit row that follows its
pattern like anything else, and it is a factory row whose position is the
unit's. The factory record grows one field, `carried_by`: the id of the unit
that carries it, zero for a factory that stands on a cell. Every pass that reads
a factory's position reads it through that field.

**It builds while it moves, for free.** The construction pass checks
`carried_by`; when the carrying unit moved this tick, the line draws no mass and
no energy — the vision's "constructing (for free btw)" — and advances by the
carrier's own build power, a catalogue number, rather than the team's. A
finished unit is spawned with mission `carried`: a row in the unit arrays that
is not on the field, not a targeting candidate, and not a claimer, held in the
carrier's `held` list — a flat array of ids with a capacity from the catalogue,
beyond which the line stalls.

**It unleashes when it stands.** A carrier stands when it reaches the end of its
pattern or when its line is stopped. Standing, and with `keep_hold` at zero, the
carrier pass places every held unit at the carrier's position with the
carrier's **attack pattern** — a second drawing, made when the carrier's line
was laid, that the contents follow from wherever the carrier stopped. A carrier
placement therefore carries two patterns, both drawn once, both validated as
issue 308 validates one.

**Unless it is told to keep hold.** With `keep_hold` at one, the contents stay
inside while it stands — until a shot lands on the carrier. The land pass
already appends every target it hits to a per-tick list; the carrier pass reads
that list, and a held carrier that was hit unleashes everything with a
two-point pattern from itself to the shooter's position. They spawn and attack
their attacker, which is the vision's sentence exactly.

**The underwater carrier** is the same machine with the sea domain and a
`submerged` flag set while it moves: excluded from every targeting candidate
list except a torpedo weapon's (issue 506), the way an in-cloud plane is
excluded from every gun's. It surfaces — the flag clears — when it stands, and
is a frigate-sized target while it does.

## Suggested implementation steps

1. Add `carried_by` (integer unit id) to the factory record in `factories`, and
   `held` (flat id array with a count), `keep_hold` (integer flag),
   `attack_pattern` (integer), `submerged` (integer flag), and `moved_this_tick`
   (integer flag, written by the move pass on its own row) to the unit record.
2. Add a `carried` row to the mission table that moves nothing, and exclude
   `carried` and `submerged` rows from candidates in `targeting` and from
   claimers in `territory`, each with a comment naming what the path means.
3. In `economy`'s construction pass (issue 305), route entries whose factory has
   `carried_by` through a second cost table: zero mass, zero energy, the
   carrier's build power, when `moved_this_tick` is set.
4. Extend the carrier line's placement command with the attack pattern and the
   keep-hold flag; validate both patterns.
5. Fill `carrier_pass(world)` in `experimentals`: for each carrier, decide
   standing, read the hit list, and unleash through a two-row table keyed by
   `keep_hold` — free unleash, or unleash-when-hit. Register it after the land
   pass in `the-tick`'s `SYSTEMS`.
6. Set and clear `submerged` in the move pass by whether the row moved.
7. Write the test's four assertions.
8. Update the companions of `factories`, `experimentals`, `targeting`, and
   `territory`.

## Related documents and tools

- [Enforcers and experimentals](../docs/009-enforcers-and-experimentals.md)
- [Factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md)
- [Territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — construction is a stream
- `tests/023-the-big-things.lua`

## Still open

- Whether "for free" should mean free of resources but not of build power, or
  free of both and limited only by the held capacity. The working ruling is the
  first.
- Whether a held unit should heal on its kind's counter while carried. Yes, by
  default, because nothing excludes it and the pair costs nothing.
- Whether a carrier that is hit while moving, rather than standing, should
  unleash. No: the vision ties unleashing to standing.
