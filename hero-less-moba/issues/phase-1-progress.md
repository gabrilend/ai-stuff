# Phase 1 Progress — The Ground and the Clock

**The goal:** a world that does nothing, correctly. A map, a heartbeat, one door
for player intent, a way to get pictures out, and the reproducibility guarantee
every later phase leans on. No soldiers, no fighting.

**Ends with:** a headless runner advancing an empty world ten thousand ticks, and
a terminal viewer drawing three empty lanes — so that from phase 2 onward nobody
works blind.

| Issue | | Status |
| --- | --- | --- |
| 101 | The path graph is built by a tool | not started |
| 102 | Milestones measure a push | not started |
| 103 | The world is flat arrays | not started |
| 104 | The tick is a dispatch table | not started |
| 105 | Randomness comes from named streams | not started |
| 106 | Commands enter through one door | not started |
| 107 | Snapshots and replays | not started |
| 108 | The headless runner | not started |
| 109 | A terminal viewer, so we are not blind | not started |
| 110 | A scenario you can hold at the gate | not started |

**Blocking:** nothing. E2 used to block this phase and phase 2 — fixed point or
floating point — and it is answered: **doubles are fine.** The project is not
lockstep; machines reconcile rather than agree. Durations stay integer ticks,
because two machines must agree on *when* even though they need not agree on
*where*.

**Carry into the work:** issue 105's stream set changed after this phase was
drafted — `draw` became `deck` and stopped being per-team, and `surge` was added
and is the busiest stream in the project. Issue 107's replay is no longer a seed
plus a command list; it records accepted snapshots too.

**Demo:** not yet built.
