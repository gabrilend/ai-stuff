# 020-things-that-roll-fly-and-sail

Phase 2: the unit record, the catalogue's relations, falloff, buffered damage,
shared healing, bones, the truck, the enforcer.

## What it claims

- A spawned unit is one row: team, position, target zero, shield zero for a
  tank; an unknown kind is refused by name.
- The catalogue's relations hold in tank shells — truck one, tank four, gun
  three, enforcer six plus a shield of four — and the enforcer is taller than a
  tank with its head above its eye; every kind heals on its own counter.
- Ships stand on water and not land, tanks the reverse, planes anywhere.
- A unit walks its pattern to the last point and holds there.
- Falloff is full at no distance, less far away, and has a floor; a tank targets
  across the whole field; a gun targets only the air; an enemy truck is preferred.
- A shot is appended at fire time, lands at the tick its distance over the shell
  speed says, and not before.
- One increment heals every tank by one without a walk; health never exceeds the
  cap; two hurts on one increment both apply.
- A dead unit leaves bones where it died, with mass, belonging to nobody.
- The pool slices a range contiguously with no gaps or overlaps.
- The truck moves where pointed, launches once per counter, dies in one shell.
- The enforcer eats bones in its set proportion, and a hit on a friend inside
  its sphere is taken by the shield.

## Subjects it loads

`units` (201), `unit-catalogue` in assets (202), `domains` (203), `movement`
(204), `targeting` (205), `combat` (206), `timers` (106), `bones` (208),
`thread-pool` (209), `command-truck` (210), `enforcer` (211).

## World fields it touches

`world.unit.{team,x,y,target,shield,shield_at,health,health_at,pattern,leg,
alive,eaten,eat_share}`, `world.pattern.{count,points}`, `world.shot.{count,
arrives}`, `world.bone.{count,x,y,mass}`, `world.heal.<kind>`,
`world.recharge.enforcer`, `world.team.mass`, `world.field.height`.
