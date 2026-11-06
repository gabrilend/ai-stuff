# 502 — Experimental artillery

| | |
| --- | --- |
| Phase | 5 — The Big Things |
| Blocked by | 205, 501 |
| Blocks | — |
| Reads | [enforcers and experimentals](../../docs/009-enforcers-and-experimentals.md) |
| Open questions | none |

## Current behavior

Built. Falloff curves are a dispatch table of shapes in `targeting`
(`linear-to-floor`, `flat`), named by each catalogue row's `falloff`. The
catalogue has an `artillery` row with the flat shape, the slowest shell, and
`team_sight`. The aim pass's unsliced step after its slices gathers each team's
sight into a per-unit `seen` bit set, and team-sight kinds choose from it, so
the artillery fires at what its team sees and holds fire when nobody sees.

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

## What happened

- **Built ahead of 501.** The artillery's row goes straight into the unit
  catalogue, tier three, which is where 501 says experimentals live. 501 still
  owns the `experimentals` asset, the other four rows, and pricing through the
  cost table. The row's cost already matches 023's hundred-times rule.
- **A curve returns a fraction, not damage**, as `falloff` always has; the
  shooter multiplies. The unit row's `falloff` column still holds the kind's
  index, and the curve is found through the kind's row, so nothing that already
  calls `falloff(kind, distance)` changes.
- **The shape check runs when targeting loads**, because the units module
  cannot load targeting (targeting loads units). A shape name no row has is
  refused there, by kind and name.
- **`seen` is one integer column on the unit row, a bit per team**, rather than
  a per-team array: one column, fixed size, folded by the hash like any other.
  Teams beyond 31 would need a wider column.
- **No new tick row.** The phase 1 test fixes the tick at thirteen rows, so the
  gather step and the artillery's choosing are the sight-and-aim row's unsliced
  step after its slices, `aim_pass_after`, which `aim_pass` runs.
- **A team-sight unit marks nothing**, so an artillery cannot keep its own
  target seen. A unit still reloading keeps the target it last chose, and that
  target still counts as seen, as the issue's "from every unit's chosen target"
  says.
- **The artillery's letter in the viewer is `R`**, for range.
- **The flight arithmetic has no cap**: a shot across the field flies about 180
  ticks. Firing and landing are issue 206's and are not on this branch.
- Both open questions stay as the issue rules them: team sight, and live sight
  only.

## Related documents and tools

- [Enforcers and experimentals](../../docs/009-enforcers-and-experimentals.md)
- [A unit and what it carries](../../docs/004-a-unit-and-what-it-carries.md) — nothing is out of range
- [The tick and the timers](../../docs/003-the-tick-and-the-timers.md) — the thread pool's rule
- `tests/023-the-big-things.lua`

## Still open

- Whether "fires at what the team can see" is the right reading of "maximises
  range", or whether a very tall eye of its own would do. Team sight is chosen
  because it makes the scout plane worth flying.
- Whether the artillery should be able to fire at a reported position with
  nobody watching it — that is, at a memory. No, for now: sight is live.
