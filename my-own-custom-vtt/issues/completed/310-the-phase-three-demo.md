# 310 -- The phase three demo

**Phase:** 3, the world ticks
**Blocked by:** every other issue in phase 3.
**Blocks:** nothing. It is the capstone of the phase.
**Documents:** [the roadmap](../../docs/015-roadmap.md)

## Current behaviour

`./run-phase-demo` reports that no demos exist.

## Intended behaviour

An executable at `issues/completed/demos/phase-3-demo` that proves determinism and
then spends it.

### Part one: the same session twice

Run a scripted session on one thread and on all of them. Compare the world hash at
every tick. Report the first divergence, or that there was none.

Then replay the same session from its snapshot and command log and compare again.

**Report per-tick, not just at the end.** "They differ" is not a finding; "they
first differ at tick 4,207, in the things block" is.

### Part two: take it back

Run the session to a turn in the middle. Roll back. Run that turn differently.
Show the world following the correction.

Then do it the other way -- roll back and replay the *same* declarations -- and show
the hash returning to exactly where it was. That second one is the sharper test:
an undo that reproduces the original bit for bit means the snapshot captured
everything, including the stream positions that are the easiest thing to forget.

### What it reports

| Reported | Why |
| --- | --- |
| Ticks simulated, and wall time | The heartbeat's real cost with motion and sight running together. |
| Time per pass, per tick | Which of the seven rows is expensive. The sight pass should dominate, and if it does not, something is wrong elsewhere. |
| Hash agreement across thread counts | The determinism claim, as a yes or a first-differing-tick. |
| Snapshot size, and the ring's total memory | What rollback costs, measured rather than estimated. |
| Time to roll back one turn | Whether undo is instant or noticeable. |

### And it should show the fog problem rather than hide it

Roll back a turn in which a body walked into an unexplored room, and **show what
happens to the fog** -- whichever way [3.3](../../docs/016-open-questions.md) was
decided. If fog rolls back, show the map closing again over a place somebody saw.
If it does not, show the map keeping a room the world says was never entered.

Either is uncomfortable to look at, and looking at it is the point. This is the
demo where the project's most honest unsolved problem is visible instead of
described.

## Suggested implementation steps

1. Write the scripted session as a command file that phase 4 can later replace with
   real sockets without changing anything else.
2. Reuse phase 1's fixture-maker and phase 2's terminal drawing rather than writing
   new ones.
3. Report timings measured during the run.
4. Ensure `tmp/shared-memory/` exists before writing logs or snapshots.
5. Confirm `./run-phase-demo` finds it, offers it, and runs it with and without an
   argument.
