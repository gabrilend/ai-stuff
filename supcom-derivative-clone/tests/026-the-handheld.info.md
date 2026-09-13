# 026-the-handheld

Phase 8: every system in the tick is a pure function that writes only its
slice, and the map file wires the systems in the tick's order.

## What it claims

- Every system run on two equal populated worlds leaves two equal worlds, and a
  system has no memory between calls.
- Every sliceable system run on the slice 5..8 writes to no unit row outside it,
  as traced by the pool.
- The box map describes one station per system, in the tick's order, each
  naming the C file its box lives in, and is written as station lines with both
  ends of every wire.

802, 803, 804 and 806 are looked at on a device and are not claimed.

## Subjects it loads

`the-tick` (801), `the-world` (104), `snapshot` (109), `commands` (108),
`units` (201), `thread-pool` (209), `box-map` (805).

## What it expects of the tick's rows

Each row of `SYSTEMS` carries `name`, `run(world)`, and — for sliceable systems
— `sliceable = true` and `run_slice(world, first, last)`.
