# 407 — The plane upgrade table

| | |
| --- | --- |
| Phase | 4 — The Cloud |
| Blocked by | 403 |
| Blocks | — |
| Reads | [the cloud](../docs/007-the-cloud.md) |
| Open questions | E5 |

## Current behavior

Nothing. Issue 403 reads a plane's `strength` field and issue 406 reads its
`gear` field, and both are copied at birth from a team total that does not
exist. `tests/022-the-cloud.lua` looks for a module with the stem
`plane-upgrades`, asserts that a team's strength rises when an upgrade is
bought, and that a plane born before the purchase keeps the strength it was
born with.

## Intended behavior

The vision's "depending on how they upgrade the planes, they'll fight better or
worse accordingly" is a **catalogue table** and a **per-team state**.

The table lives in `assets/`, one row per upgrade: a name, a cost in the two
resources (air leans on energy, so the mass share is small), the strength the
row adds (an integer), and the gear bits the row adds (an integer bitmask,
issue 406's convention). Every field is an integer; the validator refuses a row
that is not.

The per-team state is a flat array of flags, one per row per team: bought or
not. `strength(world, team)` is the kind's base strength plus the sum of the
bought rows' strengths; `gear(world, team)` is the union of the bought rows'
bits with the kind's own. Both are walks over the table in row order.

Buying is a **command** through the door (issue 108), verb `buy-upgrade`, and
it is **constructed, not purchased**: the row's cost streams out of the team's
resources at the build power's rate, like a unit, through issue 305's
construction pass, and the flag flips when the stream has delivered the whole
cost. A team that starts every upgrade at once builds all of them slowly, which
is the same trade the rest of the economy makes.

A plane **copies its team's strength and gear at birth** and never reads the
table again. That is E5's working ruling and the project's copy-at-the-boundary
rule in one: the cloud's rounds touch only the plane's own row, and an upgrade
finished mid-match reaches the planes built after it and not the ones already
in the air. The vision's "they don't listen after they've left the factory"
holds in the sky too.

## Suggested implementation steps

1. Create `assets/NNN-plane-upgrades.lua` with `./new-source-file --into assets`:
   a table of rows with `name` (string), `mass`, `energy`, `strength`, `gear`
   (all integers). Add it to `input/catalogues` when that file exists.
2. Create `src/NNN-plane-upgrades.lua` exporting `strength(world, team)`,
   `gear(world, team)`, and `rows()`; the per-team flag arrays are allocated in
   `the-world` at the table's row count.
3. Add the `buy-upgrade` verb to `commands`' `VERBS` table: it refuses a row
   already bought or under construction, by name, and otherwise opens a
   construction entry through `economy` (issue 305) whose completion flips the
   flag.
4. In `factories`' emit pass and in issue 210's launch, copy `strength` and
   `gear` into the newborn plane's row.
5. Validate the table at load: every field an integer, every name unique, no
   row with zero strength and zero gear.
6. Write the test's two assertions: the total rises; the earlier plane does not.
7. Write the companions for the asset and the module.

## Related documents and tools

- [The cloud](../docs/007-the-cloud.md)
- [Territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — construction is a stream
- [The shape of the code](../docs/013-the-shape-of-the-code.md) — balance numbers live in catalogues
- `tests/022-the-cloud.lua`

## Still open

- E5: whether air strength should come from a bought table at all, or from
  something a team earns — territory held, planes survived. Bought is the
  ruling because it is the one the vision's word "upgrade" points at.
- Whether an upgrade should also reach planes already in the air after a
  return to the cloud, as a refit. No, for now: the copy at birth is the design.
