# 211 — The enforcer walks forward and eats

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 112, 207, 208 |
| Blocks | — |
| Reads | [enforcers and experimentals](../docs/009-enforcers-and-experimentals.md) |
| Open questions | A9 |

## Current behavior

Nothing. Territory (issue 112), the heal pair on units (issue 207), and bones
(issue 208) are the three things the enforcer reads, and none exists. The test
program `tests/020-things-that-roll-fly-and-sail.lua` names this issue, looks
for the stem `enforcer`, and asserts that the sphere absorbs a shot aimed at a
unit inside it.

## Intended behavior

The enforcer is the demo's only tier-two unit and the one unit with three rules
of its own. It is still one row in the unit arrays; the rules are three passes
that read only enforcer rows and the arrays they act on.

**It is tall.** Its `eye` and `profile` are the largest of any land unit in the
catalogue, so it sees over crests that hide a tank and is seen over them too —
and because its profile is taller than its eye, it is seen before it sees, which
is the vision's "their heads often put them in danger before they can use the
cannon." That is a catalogue relation, not code.

**It eats.** The eat pass finds bones (issue 208) within the enforcer's reach,
consumes them, and splits the mass two ways: a share to the team's treasury and
a share to the enforcer's own `eaten` column. The split is a **proportion set at
the factory** when the line was laid — a dial from all-to-treasury to
all-to-upgrade — copied into the enforcer at birth like everything else it
carries, and never changed afterwards. When `eaten` crosses a catalogue
threshold the enforcer **upgrades**: A9's working ruling is that each step raises
the health cap, the damage, and the sphere's radius together, by catalogue
amounts, and the row is rewritten in place.

**It claims with ease.** Its `claim_radius` in the catalogue is larger than a
tank's, and the claim pass (issue 112) reads that column and nothing else about
it; an enforcer walking a ridge paints ground as it goes.

**It has a sphere.** The shield is a health pool on its own recharge counter —
the pair of integers `shield, shield_at`, issue 106 — that absorbs shots aimed
at **any unit inside the sphere**, itself included, until it is down. The land
pass (issue 206) asks, for each landing shot, whether the target stands inside a
live enforcer's sphere on the same team; if so the damage comes off the shield's
derived value first and only the remainder reaches the target. A shield that has
not been hit for its recharge period comes back on its counter, with no walk. The
vision's numbers, quoted once as the vision's: the enforcer takes six tank
shells, the shield four more.

The shield check is the one place a landing shot reads a row that is not its
target's. It is safe because the land pass is unsliced; it is cheap because
enforcers are few and the check is a range walk over their rows.

## Suggested implementation steps

1. Claim `src/NNN-enforcer.lua` with `./new-source-file enforcer`.
2. Add `proportion` to the columns copied at birth for the enforcer kind — an
   integer in a fixed range, zero for every other kind — and the factory line's
   dial to issue 307's placement command.
3. Write `eat_pass(world)`, unsliced (it writes the treasury and the bones
   array): for each live enforcer, `near` from issue 208, `eat` each bone,
   split by `proportion`, credit the treasury, raise `eaten`, and upgrade when
   the threshold is crossed.
4. Write `shield_pass(world)` — or rather `absorb(world, shot)` called from the
   land pass: find a same-team live enforcer whose sphere contains the target,
   derive the shield through issue 106's `read`, take what it can, rewrite the
   pair, return the remainder.
5. Write `upgrade(world, id)`: the catalogue's per-step amounts applied to the
   row's cap, damage, and sphere radius; refuse a step past the catalogue's last.
6. Register `eat_pass` in the tick's dispatch table after the die pass, so the
   bones a tick leaves are eaten the same tick they fall if an enforcer stands
   there.

## Related documents and tools

- [enforcers and experimentals](../docs/009-enforcers-and-experimentals.md)
- [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- [territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — the treasury and the claim
- `tests/020-things-that-roll-fly-and-sail.lua`

## Still open

- **A9.** What an enforcer's upgrade does; the working ruling is cap, damage, and
  sphere together.
- Raised here: whether a shot that would kill the enforcer itself through a
  down shield should be able to be absorbed by a *second* enforcer's sphere. The
  first sphere found in row order takes it; overlapping spheres are a
  proving-ground question.
