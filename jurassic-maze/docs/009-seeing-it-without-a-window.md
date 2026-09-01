# Seeing It Without A Window

The simulation does not know that a window exists. It can be run three other
ways, and each one exists to answer a question the window is bad at.

## Headless

`./run-maze --headless --ticks 20000` runs the whole thing with no graphics
module loaded at all — under bare `luajit`, not under the game engine — and
prints a report at the end.

This is the one that matters. A simulation that can only be observed by a person
watching it is a simulation with no tests, because "did that look right" is not
an assertion. Headless makes every property of a run into a number:

| Reported | Why it is worth a number |
| --- | --- |
| bodies that never moved | one is a stuck body; forty is a broken rule |
| bodies that left the world | should be zero. The rim exists so that it is zero. |
| total distance travelled, per locomotion kind | a kind whose number collapses stopped working, and nobody would see it in a window full of other kinds that still do |
| deepest and highest layer visited | says whether the staircases are actually being used, or whether everybody is milling about on the ground |
| ticks spent per pass | where the time goes, without a profiler |
| the seed | so the run can be had again |

Ten thousand of these run overnight, one per core, and the morning's table is
the difference between a project that is tested and a project that is watched.

## The terminal viewer

`./run-maze --terminal` draws one horizontal slice of the maze as characters and
steps the simulation on a key.

It is not a nicer headless mode. It is for the specific situation where a number
says something is wrong and you need to see *where*, over ssh, in a place with no
graphics. One layer at a time, bodies as letters, walls as blocks. It answers
"the ball is stuck — stuck against what?", which is a question the report cannot
answer and the window answers too slowly, because in the window you have to find
the ball first.

The slice is chosen by a key, and the viewer holds at a gate: it advances only
when told. A simulation you can hold still is a simulation you can read.

## Screenshots

`./run-maze --screenshot out.png --ticks 500` opens the window, runs to a tick,
writes a picture, and exits. Used by the phase demos, and used when a rendering
change needs to be compared against the same frame from before it.

## The one rule that makes all three possible

**The simulation never calls the engine, and never imports it.** Not for
randomness, not for time, not for logging. It receives a fixed timestep and it
returns state. The viewer reads that state and draws; the headless runner reads
that state and counts.

The moment one simulation file asks the graphics library for the elapsed time,
headless stops working, and it stops working in a way that looks like an
unrelated crash. So there is a test that greps every file under `src/` that is
part of the simulation and fails if any of them mentions the engine by name. It
is a crude test and it has caught the mistake twice in projects shaped like this
one.

## Related documents and tools

- [The tick](010-the-tick.md) — the fixed timestep the three of them share
- `./run-maze --help` — all of the above, with their flags
- `./run-many-mazes` — the overnight sweep, one worker per core
