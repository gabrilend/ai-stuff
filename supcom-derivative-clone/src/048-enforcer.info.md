# 048-enforcer

The enforcer eats bones for its team and itself, upgrades on what it has eaten,
and its sphere takes the shots aimed at friends inside it.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The enforcer is the demo's one tier-two unit: one row in the unit arrays, with
rules that read only rows of a kind that eats, upgrades or has a shield. Its
height and its wide claim are catalogue relations and need no code. Its eye and
profile are the tallest of any land kind, and its profile is taller than its
eye, so it is seen before it sees. Its `claim_radius` is wider than a tank's.

**It eats.** The eat pass walks the units in row order. Each one with an
`eat_radius` asks the bones module (`near`) for the bones in reach and eats them
last first, so the rows still to eat keep their places. Each bone's mass is
split by the row's `eat_share`: that share goes to the team's treasury, and the
rest, rounded down, goes to the row's `eaten`, so no mass is lost. `eat_share`
is copied from the catalogue at birth (0.5) until the factory's dial (issue 307)
sets another. The pass runs inside the tick's die row, after the die pass, so
bones are eaten the tick they fall. The tick's thirteen rows are fixed, so it
gets no row of its own.

**It upgrades.** Its step is derived from `eaten`, not stored: one step per
`upgrade_mass`, never past `upgrade_steps`. Each step adds `upgrade_health` to
the health cap, `upgrade_damage` to the damage, and `upgrade_sphere` to the
sphere's radius (A9's working ruling). The cap and the sphere are worked out
from the step. The damage is rewritten in the row by `upgrade`, which the eat
pass calls when the step changes. An upgrade raises the cap, not the health:
the extra comes back on the heal counter.

**It has a sphere.** The shield is the pair `shield, shield_at` on the kind's
recharge counter, so it comes back with no walk. `absorb(world, target,
amount)` is asked by `combat.hurt` before any health is taken. It finds the
first live unit of the target's team, in row order, that has a shield up and
the target inside its sphere. The enforcer itself counts. The sphere is a
sphere, so a plane flying above the radius is outside it. That shield takes as
much as it holds, its pair is rewritten, and the rest is handed back. Without
such a sphere the whole amount goes through. At most one sphere takes a hit;
overlapping spheres are a proving-ground question. The shield's own cap does
not rise with an upgrade.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `eat_pass(world)` | a world | nothing; run by `combat.die_row` |
| `absorb(world, target, amount)` | a world; the unit hit; the damage | what is left for the target's health |
| `upgrade(world, id)` | a world; a unit of a kind that upgrades | the step it has reached, with its damage rewritten; refuses any other row |
| `step(world, id)` | a world; a unit | its upgrade step, zero for a kind that never upgrades |
| `cap(world, id)` | a world; a unit | its health cap: the kind's, plus what its steps add |
| `sphere(world, id)` | a world; a unit | its sphere's radius in cells, zero without a shield |
| `shield(world, id)` | a world; a unit | its shield now, from its pair |
| `KIND` | | `"enforcer"` |

## Data structures it owns

None of its own. It writes a row's `eaten`, `damage`, `shield` and `shield_at`,
the team's `mass`, and the bone queue through the bones module.
