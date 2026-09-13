# 402 — Planes fly from the factory to the cloud

| | |
| --- | --- |
| Phase | 4 — The Cloud |
| Blocked by | 307, 401 |
| Blocks | 503 |
| Reads | [the cloud](../docs/007-the-cloud.md) |
| Open questions | none |

## Current behavior

Nothing. An air factory placed through issue 307 has a line and emits units, but
a unit with the air domain has no mission to leave with and nowhere to go. The
`to-cloud` row in the `MISSIONS` table from issue 401 raises by name until this
issue fills it. `tests/022-the-cloud.lua` places an air factory, lets it emit,
and asserts that some ticks later the plane's mission is `in-cloud`.

## Intended behavior

A plane leaves its factory and flies straight to the cloud. It has no pattern
and is given no destination: the vision's "air factories build planes and they
immediately go to the dogfight." That is the whole of it, and the reason it is
its own issue is that it is the first place the factory, the unit record, the
domains, and the cloud meet.

The **emit pass** decides a newborn's first mission by its domain, through a
table keyed by domain: a land or sea unit starts on leg one of its pattern with
mission zero; an air unit starts with mission `to-cloud` and pattern zero. An
air factory's placement command therefore carries no pattern, and a placement
that supplies one for an air factory is **refused by name** — the pattern would
never be read, and a field that is set and never read is a lie waiting to be
believed. Issue 503 narrows this rule for the one air kind that does fly a
pattern.

The `to-cloud` mission moves the plane toward the cloud's position at the kind's
speed, at ground plus flight height, and flips the mission to `in-cloud` when
the plane is within one cell of the cloud's position. On the way it is a plane
over whatever ground it crosses, and issue 405's guns shoot it if they see it.

The command truck's plane (issue 210) is not emitted by a factory and does not
take this path; its missions are its own rows.

## Suggested implementation steps

1. In `factories` (issue 307), give `emit_pass(world)` a table
   `FIRST_MISSION` keyed by domain, each entry a function that sets the newborn's
   `mission`, `pattern`, and `leg`. Air sets `to-cloud`, zero, zero.
2. In the placement validator of `factories`, refuse a pattern on an air
   factory, returning a refusal that names the factory's cell and says why.
3. Fill the `to-cloud` row in `the-cloud`'s `MISSIONS`: step toward
   `cloud_x, cloud_y` by the kind's speed, set `altitude` through `domains`,
   flip to `in-cloud` within one cell.
4. Confirm the plane is a targeting candidate on the way — nothing in this issue
   excludes it; issue 405 decides who shoots.
5. Update the companions of `factories` and `the-cloud`.

## Related documents and tools

- [The cloud](../docs/007-the-cloud.md)
- [Factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md)
- `tests/022-the-cloud.lua`

## Still open

- Whether a plane should be a targeting candidate on its first flight, or whether
  the factory's own ground is safe air. Nothing in the vision says either; the
  working ruling is that it is a plane like any other from its first tick.
