# 022-the-cloud

Phase 4: the swarm, rounds, fight or avoid, defensive flight over the guns,
reports and bombing runs, the upgrade table.

## What it claims

- The cloud has one position, over the field's centre, and the missions are a
  dispatch table with the six documented rows.
- A fresh plane is bound for the cloud, has no pattern, and arrives.
- A team's strength is the sum of its upgrades; a plane copies it at birth and a
  later upgrade does not reach it; the weaker plane goes defensive and the
  stronger intercepts it.
- Nothing happens between round increments; a round hurts one of an even pair.
- A defensive plane flies over its own ground; a gun there targets the
  interceptor; the gun does not reach into the cloud.
- A report sends the idle, equipped plane and not the one in a round, the
  defensive one, or the enemy's; the run knows its goal, ends, returns, and the
  bombed cell is claimed.
- The upgrade table is data with an energy cost and a strength per entry, and an
  unknown upgrade is refused.

## Subjects it loads

`the-cloud` (401 to 406), `plane-upgrades` as source and as an asset (407),
`units` (201), `targeting` (205, 405), `territory` (112), `timers` (106),
`unit-catalogue` (202).

## World fields it touches

`world.cloud.{x,y}`, `world.cloud_round`, `world.unit.{mission,target,strength,
in_round,goal_x,goal_y,x,y,pattern,health,health_at}`, `world.cell.{owner,
claim_by}`, `world.heal.helicopter`.
