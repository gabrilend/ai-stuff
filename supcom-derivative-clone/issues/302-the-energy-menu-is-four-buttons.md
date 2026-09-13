# 302 — The energy menu is four buttons

| | |
| --- | --- |
| Phase | 3 — Inflows and Outflows |
| Blocked by | 108, 304 |
| Blocks | 303, 604 |
| Reads | [territory mass and energy](../docs/005-territory-mass-and-energy.md) |
| Open questions | D1 |

## Current behavior

Nothing. There is no notion of an engineer being assigned to anything; the
roster (issue 304) is counts with health, and the command door (issue 108)
accepts commands but knows no verb for an assignment level.

What exists that bears on this: `tests/021-inflows-and-outflows.lua` names this
issue and asserts that there are exactly four levels, that each level splits a
roster of engineers into an energy share and a build share in the documented
proportions (none, a third, two thirds, all), that the split is applied at the
tick the command is stamped for and not before, and that a fifth level is
refused by name. The economy document describes the menu and says it must never
grow.

## Intended behavior

The vision's always-open menu: **four buttons that decide how many of a team's
engineers are put toward energy.** Nothing else is on it, and this issue is the
one place that decides there is nothing else: the levels are a table of four
rows, the command that picks one carries a level index, and an index outside the
table is refused with its name.

The four levels are four **assignment fractions** — none of the engineers, a
third, two thirds, all of them. A team holds one current level, an integer
index. Every tick, the number of engineers on energy duty is the roster's
engineer count times the level's fraction, rounded down; the remainder are build
power. So the four buttons are one lever, trading construction speed against
energy income, and that is the whole decision the player makes about energy.

What engineers on energy duty *do* is issue 303's business (raising and
operating energy buildings) and the working ruling in D1; this issue only
decides how many of them there are. Keeping the split here and the work there
means the menu can be tested with no buildings in the world.

The level is a command like any other — a verb in the door's dispatch table,
stamped with a tick, applied at that tick — because "everything can be queued"
is an invariant and the menu is not an exception to it. On the network (issue
702) the level arrives a few ticks later like everything else, and the player
does not notice because a menu press was never instantaneous.

## Suggested implementation steps

1. Claim the `energy-menu` stem with `./new-source-file`. Export `LEVELS`, a table
   of four rows, each holding a name (a string) and a fraction as a numerator
   over three (an integer, so the split is exact integer arithmetic and two
   machines round the same way).
2. Add to the world a per-team `energy_level` array, integers, holding the index
   of the current level; zero is not a valid index and the validator (issue 104)
   refuses a world with a zero here after the first command.
3. Export `set_level(world, team, level)`: refuses an index that is not one to
   four, by name, and otherwise writes it. Export `split(world, team)`: returns
   the engineers on energy duty and the engineers on build duty as two integers
   from the roster's engineer count (issue 304).
4. Add a verb to the command door's dispatch table (issue 108) — `energy-level`,
   carrying a team and an index — whose handler calls `set_level`. A refused
   level is a refused command, returned to the door's caller with the reason.
5. Make build power (issue 305) read the build-duty half of `split`, and make
   energy raising (issue 303) read the energy-duty half, so that no other code
   ever computes the fraction.
6. Add the claims to `tests/021-inflows-and-outflows.lua`: four rows, the split
   for each, applied at the stamped tick, a fifth index refused.

## Related documents and tools

- [territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — the menu and why it never grows
- [factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md) — the queue invariant every command obeys
- `tests/021-inflows-and-outflows.lua`
- issue 108 — the door this command enters by
- issue 304 — the roster whose engineers are split
- issue 604 — the menu drawn on screen, always

## Still open

- D1: what engineers on energy duty do, exactly — this issue only decides how
  many there are, and issue 303 decides what they do; both should be read
  together when D1 is answered.
- Whether a level change should take effect gradually (engineers walking from
  one duty to the other over several ticks) rather than at once. The working
  ruling is at once, because a gradual change is a per-engineer state and the
  roster has none.
