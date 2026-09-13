# 025-other-players

Phase 7: two lockstep worlds agree, a missing batch stalls, a bad hash names
its tick, the loopback transport, discovery, rejoining.

## What it claims

- Two machines joined over the loopback and fed commands from both sides never
  disagree on a hash across three hundred ticks, and a command issued at a tick
  is applied at tick plus delay on both.
- Scheduling stamps tick plus delay, and the door refuses a stamped command
  whose tick has passed, naming the tick.
- Cutting one side's wire stalls the other within the delay, which names who it
  is waiting for; mending it moves both again.
- The loopback delivers in order, names the sender, returns nothing from an
  empty inbox, and never echoes to the sender.
- Two machines announcing on a counter hear each other and agree on a seed; one
  that stops announcing ages out.
- A world corrupted behind the rules' back halts the other machine at a named
  tick with its evidence written to the RAM tier.
- A fresh machine rejoining from the command log catches up to the same tick and
  the same hash.

707 (the handheld's transport) is not claimed: its numbers are pending.

## Subjects it loads

`lockstep` (701, 702, 705, 706), `transport-loopback` (703), `discovery` (704),
`snapshot` (109), `commands` (108), `the-tick` (105), `the-world` (104),
`timers` (106).

## World fields it touches

`world.tick`, `world.team.{energy_level,mass}`, `world.applied_at`.
