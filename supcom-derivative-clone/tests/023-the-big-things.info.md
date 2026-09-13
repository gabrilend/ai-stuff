# 023-the-big-things

Phase 5: experimentals for everyone, artillery without falloff, carriers that
build while moving.

## What it claims

- The five experimentals are in the catalogue, cost a hundred times a tank on
  their leaning resource, and belong to no team.
- Artillery's falloff is full next door and full across the field.
- A gunship has a pattern slot and is not bound for the cloud.
- A moving carrier draws nothing while it builds, holds what it built, and
  swarms it out when it stops; told to keep hold, it swarms out only when hit.
- The experimental air factory sends out bombers that are on a run, not bound
  for the cloud.

506 (submarines and torpedo planes) is not claimed: the demo does not build it.

## Subjects it loads

`experimentals` as an asset (501) and as source (504, 505), `cost-table` (306),
`targeting` (502), `units` (201, 503), `the-cloud` (401, 406), `combat` (206).

## World fields it touches

`world.team.{mass,energy}`, `world.carrier.{held,moving}`,
`world.unit.{alive,mission,pattern,count}`.
