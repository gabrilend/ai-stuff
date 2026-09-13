# 019-the-dunes-and-the-clock

Phase 1: the field, sightlines, flat arrays, the tick order, the timer pair,
named streams, the command door, snapshots, territory.

## What it claims

- The same seed raises the same field, a different seed a different one, and a
  raised field passes its own validator; a broken one is refused naming the cell.
- A sightline is blocked by a crest and clear along a flat; a tall eye or a tall
  profile clears the crest; there is no maximum distance.
- The world has no absent value anywhere, and empty fields hold the integer zero.
- The tick's systems are the documented thirteen, in the documented order, and
  ten thousand empty ticks run in under two seconds.
- A periodic effect's pair derives the right value after any number of
  increments, never exceeds the cap, and a write restamps the increment.
- Named streams repeat by name and seed, and differ by name.
- The command door has a dispatch table of verbs, refuses unknown verbs and past
  ticks by name, and applies a command at its tick and not before.
- Two runs from one seed and one command list hash the same; one more tick
  changes the hash; a copy is a different table with the same hash.
- The headless runner reports ticks, hash and seed; the terminal viewer draws a
  string with a row per field row.
- A claim completes after enough increments and not before, and a contested
  cell does not change hands.

## Subjects it loads

`the-dunes` (102), `sightlines` (103), `the-world` (104), `the-tick` (105),
`timers` (106), `random-streams` (107), `commands` (108), `snapshot` (109),
`headless-runner` (110), `terminal-viewer` (111), `territory` (112), and
`units` (201) for the one suite that needs a body on the ground.

## World fields it touches

`world.tick`, `world.unit.count`, `world.unit.target`, `world.claim.period`,
`world.claim.increments_to_claim`, `world.field.height`, `world.field.water_line`.
