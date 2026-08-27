# Phase 1 Progress — The Ground and the Clock

**The goal:** a world that does nothing, correctly. A map, a heartbeat, one door
for player intent, a way to get pictures out, and the reproducibility guarantee
every later phase leans on. No soldiers, no fighting.

**Ends with:** a headless runner advancing an empty world ten thousand ticks, and
a terminal viewer drawing three empty lanes — so that from phase 2 onward nobody
works blind.

| Issue | | Status |
| --- | --- | --- |
| 101 | The path graph is built by a tool | built |
| 102 | Milestones measure a push | built |
| 103 | The world is flat arrays | built |
| 104 | The tick is a dispatch table | built |
| 105 | Randomness comes from named streams | built |
| 106 | Commands enter through one door | built |
| 107 | Snapshots and replays | snapshots built, replays not |
| 108 | The headless runner | built |
| 109 | A terminal viewer, so we are not blind | built |
| 110 | A scenario you can hold at the gate | built, with a gate |

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

## Where the prototype got to

Everything except a scenario file and the replay half of 107 is standing and
running. The map is built by a tool from shape parameters and refused by a
validator if it is malformed; the world is flat arrays allocated once; the tick is
an ordered array of systems; randomness comes from named streams; commands enter
through one door and every refusal is named; a headless runner plays a match with
no window and prints a report; and the terminal viewer draws the whole field as
text.

**Reproducibility is asserted by a test that runs on every build.** Same seed,
same commands, same match, compared on a fingerprint of every body's position
rather than on a summary.

**Symmetry is not**, and it is the phase's one real gap rather than an oversight —
see G2 in the open questions. The per-team tie streams that made the asymmetry
systematic rather than random are in; a canonical tie-break ordering, which is what
exact symmetry would cost, is not, because whether it is worth the price is a
question for a person.

**110 is built and it is the most useful thing in the phase.** A scenario is a
described world in a hand-written file — which phase, which tick, which towers are
rubble, what is placed where, what anybody is holding — loaded into a fresh world and
**held until released**. The gate is the point: a match that starts running the instant
it loads cannot be looked at before it moves, and the most useful moment when
something is going wrong is almost always the tick before it does. It can be stepped a
fixed number of ticks or run until any event the simulation already announces.

It found a bug in itself immediately. Jumping the clock forward left the spawn timer a
whole match behind, and the spawner produced every wave it thought it owed, one per
tick — a thousand bodies in four hundred ticks. Setting the tick now moves every clock
with it, and the spawner snaps its own forward and **says so** if it ever finds itself
more than an interval behind.

**107 is half.** Snapshots are built; the replay log is not.

One thing 101 asked for that turned out to be already stale: its own text says four
junctions, and the map document says three. See G7.
