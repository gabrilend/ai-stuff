# 502 — Experimental artillery

| | |
| --- | --- |
| Phase | 5 — The Big Things |
| Blocked by | 205, 501 |
| Blocks | — |
| Reads | [enforcers and experimentals](../docs/009-enforcers-and-experimentals.md) |
| Open questions | none |

## Current behavior

Nothing. Issue 501 puts an artillery row in the catalogue and issue 205 gives
every weapon a falloff curve that declines to a floor. Nothing has a curve that
does not decline, and nothing fires at what somebody else can see.
`tests/023-the-big-things.lua` asserts that artillery loses nothing to distance:
its damage at the far side of the field equals its damage at one cell.

## Intended behavior

"Pick range — everyone can build an experimental artillery." In a game where
nothing is out of range, maximising range means two specific things, and this
issue builds both.

**Its shells lose nothing to distance.** The falloff curve is flat. Rather than
a special case in the aim pass, falloff curves become a **dispatch table of
shapes**: each kind's `falloff` field indexes a row, and the rows are functions
of distance — `linear-to-floor` for the tank and everything else so far, `flat`
for the artillery. Adding a shape is adding a row, and the artillery's is the
second row that has ever existed.

**It fires at what the team can see.** Every other unit's sightline is from its
own eye. The artillery's is from **any friendly eye**: it may fire at any enemy
that any unit on its team has a sightline to this tick. That is the working
ruling stated in the document, and it is what makes the artillery a range
weapon rather than a tall one — a scout on a crest, or a plane, is its eye.

The mechanism respects the thread pool's rule. The sight-and-aim pass is sliced
by unit and may write only its own row, so a unit cannot mark another unit as
seen. Instead each unit already picks its own target; a small unsliced step
after the aim pass walks the unit arrays once and builds, per team, a flat
array of flags — **seen by the team** — from every unit's chosen target. The
artillery's row in the aim pass runs *after* that step and picks from the
flags. One extra walk a tick, no shared write during the slice.

Its shells are the slowest in the catalogue, so a shot across the field lands
many ticks later against wherever its target then is — A3's working ruling —
which is the artillery's counter: move.

## Suggested implementation steps

1. In `targeting` (issue 205), replace the falloff computation with a
   `FALLOFF` table of `{name, curve}` rows, `curve` taking `(kind_row, distance)`
   and returning damage; give every catalogue row a `falloff` index; fill
   `linear-to-floor` and `flat`.
2. Add `team_sight` (integer flag) to the catalogue rows; only the artillery sets
   it.
3. Add to `the-world` a per-team `seen` flag array over units, and a step
   `gather_sight(world)` in `the-tick`'s `SYSTEMS` between sight-and-aim and
   fire that fills it from every unit's `target`.
4. In the aim pass, give kinds with `team_sight` a candidate filter that reads
   the `seen` flags instead of asking the sightline for itself.
5. Confirm the shell speed in the artillery's row is the catalogue's slowest, and
   that the arrival-tick arithmetic in `combat` handles a flight of many ticks
   without a cap.
6. Write the test's assertion at two distances, and a second: with no friendly
   eye on the target, the artillery holds fire.
7. Update the companions of `targeting`, `the-world`, and the catalogue.

## Related documents and tools

- [Enforcers and experimentals](../docs/009-enforcers-and-experimentals.md)
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) — nothing is out of range
- [The tick and the timers](../docs/003-the-tick-and-the-timers.md) — the thread pool's rule
- `tests/023-the-big-things.lua`

## Still open

- Whether "fires at what the team can see" is the right reading of "maximises
  range", or whether a very tall eye of its own would do. Team sight is chosen
  because it makes the scout plane worth flying.
- Whether the artillery should be able to fire at a reported position with
  nobody watching it — that is, at a memory. No, for now: sight is live.
