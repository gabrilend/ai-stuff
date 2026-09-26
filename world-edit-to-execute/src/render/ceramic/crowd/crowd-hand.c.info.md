# crowd-hand.c

The crowd's tick threaded by hand every usual way (issue 515k). A tick is
a snapshot and settling on one thread, and every moving unit deciding in
between, which the ways share out differently.

- **Usage:** `crowd-hand WAY SCENE TICKS THREADS`. Ways: `serial`;
  `slices-sleep` / `slices-hybrid` (each thread a fixed share of units);
  `counter-sleep` / `counter-hybrid` (chunks from a shared counter);
  `jobs` (chunks on per-thread queues with stealing); `measure` (serial,
  timing each phase and each unit).
- **Settings:** `CROWD_CHUNK` (units a chunk, 32), `CROWD_SPIN_US` (how
  long a hybrid wait or an idle job worker spins, 50), `CROWD_TIMELINE`
  (a file: who ran which chunk when, four ticks from `CROWD_TIMELINE_AT`).
- **Output:** way, threads, units, ticks, mean / median / 99th percentile
  / worst tick (ms), checksum of every position. `measure` prints instead:
  units, ticks, the mean ms of the snapshot, the deciding, the settling
  and the orders, the floor (the serial parts plus the deciding shared over
  every hardware thread, no shorter than its longest unit), the longest
  single unit's deciding, hardware threads, crossings ended.
- The regions marked THREADING are what gets counted.
