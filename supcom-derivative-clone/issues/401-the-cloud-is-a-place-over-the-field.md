# 401 — The cloud is a place over the field

| | |
| --- | --- |
| Phase | 4 — The Cloud |
| Blocked by | 201, 203 |
| Blocks | 402, 403, 606 |
| Reads | [the cloud](../docs/007-the-cloud.md) |
| Open questions | E1 |

## Current behavior

Nothing. There is no cloud, no plane mission, and no source file named `the-cloud`.
What exists is the specification: `tests/022-the-cloud.lua` looks for a module
with that stem and asserts that a plane with no orders is in the cloud, and
[the cloud](../docs/007-the-cloud.md) describes the place this issue builds. The
unit record from issue 201 already carries a `mission` field and an `altitude`
field, both integers or doubles, both zero for anything that is not a plane;
issue 203 gives the air domain its flight height above the ground.

## Intended behavior

The cloud is **one record in the world**, not a unit and not a building: a
position on the field, an altitude above it, and a round counter. It sits above
the field's centre — the working ruling for E1 — and it is where every plane goes
when it has nothing else to do. Its state is the set of planes whose mission
says they are in it, and nothing more: the swarm has no positions that matter,
and the viewer draws it from counts and colours.

A plane is a unit row with the air domain and a **mission**: an integer that
indexes a dispatch table of six rows, each a function that moves the plane this
tick. The rows and what they mean are the ones the document lists:
`to-cloud`, `in-cloud`, `defensive`, `intercepting`, `bombing`, `returning`.
Adding a mission is adding a row. There is no branch on the mission anywhere in
the simulation; the move pass calls the row.

Membership is **derived, never maintained.** How many of a team's planes are in
the cloud is a walk over the unit arrays counting rows whose mission is
`in-cloud`, in array order. A maintained count is a second copy of a fact that
can disagree with the first, and the walk costs nothing a tick was not already
paying.

The cloud's altitude is the reason issue 405 can exclude it from every gun's
sight without a sightline test: it is a number, and the working ruling for E2 is
that no gun's profile reaches it.

## Suggested implementation steps

1. Add to the world record, in `the-world` (issue 104): `cloud_x`, `cloud_y`
   (doubles, the field's centre at allocation), `cloud_altitude` (double, from
   the catalogue), and the round counter as a periodic effect registered with
   `timers` (issue 106) under the name `cloud-round`.
2. Create `src/NNN-the-cloud.lua` with `./new-source-file` and export
   `MISSIONS`: an ordered table of `{name, run}` rows, `run` taking
   `(world, id)`. Fill six rows; this issue implements only `in-cloud`, which
   moves nothing, and leaves the others as functions that raise with the
   mission's name until their issues arrive. A missing row is an error, not a
   no-op.
3. Export `in_cloud(world, team)`: the count of that team's planes whose mission
   is `in-cloud`, by array walk.
4. Give the unit catalogue (issue 202) a `flight_height` per air kind, and have
   `domains` (issue 203) derive a plane's `altitude` as ground plus flight height
   every move; the cloud's altitude is separate and larger.
5. Have the move pass in `movement` (issue 204) call `MISSIONS[mission].run` for
   every row whose domain is air, and walk legs for every row whose domain is
   not. Two code paths, one table each.
6. Validate at load: the cloud's position is on the field; its altitude exceeds
   the tallest cell plus the tallest profile in the catalogue. Refuse otherwise,
   by name.
7. Write the companion, listing the world fields this issue added and the
   `MISSIONS` rows with their meanings.

## Related documents and tools

- [The cloud](../docs/007-the-cloud.md)
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- [The tick and the timers](../docs/003-the-tick-and-the-timers.md)
- `tests/022-the-cloud.lua`, which asserts a plane with no orders is in the cloud

## Still open

- E1: whether there is one cloud above the field's centre, or one per region, or
  one where the first planes met. The record shape above holds any of those; the
  count and the position are what change.
- Whether the swarm should have positions after all, for the viewer's sake. The
  working ruling is that the viewer invents them from the counts.
