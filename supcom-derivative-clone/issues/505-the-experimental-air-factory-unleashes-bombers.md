# 505 — The experimental air factory unleashes bombers

| | |
| --- | --- |
| Phase | 5 — The Big Things |
| Blocked by | 406, 504 |
| Blocks | — |
| Reads | [enforcers and experimentals](../docs/009-enforcers-and-experimentals.md) |
| Open questions | none |

## Current behavior

Nothing. The carrier machinery from issue 504 holds and unleashes land and sea
units along an attack pattern; a bombing run from issue 406 flies to a reported
cell, damages it, claims it, and returns to the cloud. Issue 501 puts an air
factory row in the catalogue. `tests/023-the-big-things.lua` asserts that an
unleashed bomber runs to the end of its attack pattern, damages and claims the
cell there, and returns to the carrier rather than to the cloud.

## Intended behavior

"Same for air factory — they can create bomber attack patterns, then move up
close to the enemy and unleash them." The experimental air factory is issue
504's carrier with **bombers** inside, and a bomber is a plane whose whole life
is a bombing run.

A **bomber** is an air kind with the bombing gear bit and `flies_pattern` set,
built by the carrier while it moves, held with mission `carried`, and unleashed
when the carrier stands. Unleashed, its mission is `bombing` — issue 406's row,
unchanged — with its target the **last point of the attack pattern**. It flies
there at flight height, over whatever guns can see it, drops as a bombing run
drops, and then its mission is `returning`.

**Returning goes home, and home is not always the cloud.** The unit record
grows a `home` field: the id of the carrier a plane belongs to, or zero for
the cloud. The `returning` row steps toward the carrier's position when `home`
is set and toward the cloud when it is not, and on arrival a plane with a home
is put back into the carrier's `held` list with mission `carried`, ready to be
unleashed again. A carrier's bombers are therefore reusable; what they cost is
the flight over the guns, twice.

The carrier itself never enters the cloud, never answers a report, and is never
in a round: it is an experimental with the air domain flying a pattern, which
issue 503 already made possible. It is shot on the way like the gunship is.

## Suggested implementation steps

1. Add a bomber row to the unit catalogue with the air domain, the bombing bit
   in `gear`, `flies_pattern` set, and no strength worth a round; add the air
   factory row's line, which builds bombers.
2. Add `home` (integer unit id) to the unit record; the carrier pass sets it on
   every unit it unleashes and the emit pass leaves it zero.
3. In the carrier pass, give the unleash step a per-domain table: land and sea
   contents leave with the attack pattern on leg one; air contents leave with
   mission `bombing` and `target` set to the attack pattern's last point, by
   issue 404's negative-index convention.
4. Change the `returning` row in `the-cloud`'s `MISSIONS` to read `home`, and on
   arrival at a carrier to append the plane to `held` and set `carried`.
5. Confirm a `carried` plane is neither a candidate nor a claimer nor a member
   of the swarm.
6. Write the test's three assertions.
7. Update the companions of `the-cloud`, `experimentals`, and the catalogue.

## Related documents and tools

- [Enforcers and experimentals](../docs/009-enforcers-and-experimentals.md)
- [The cloud](../docs/007-the-cloud.md) — bombing runs and the missions table
- `tests/023-the-big-things.lua`

## Still open

- Whether a bomber that returns to a carrier that has since died should go to
  the cloud or be lost. The cloud, for now: `home` reads as zero when the row is
  dead, and the row's own rule does the rest.
- Whether the carrier should unleash bombers one at a time on a counter rather
  than all at once, so that a defended target is not saturated in one tick.
