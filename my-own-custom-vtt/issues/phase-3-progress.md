# Phase 3 — The world ticks, and turns can be taken back

**Goal:** time. The heartbeat, motion, determinism, the replay — and then turns,
which are transactions that resolve at once and can be undone.

**Status: complete.** All ten issues done. `./run-phase-demo 3` proves
determinism and then spends it.

## The issues

| Issue | What it established |
| --- | --- |
| [301 the tick is a dispatch table](completed/301-the-tick-is-a-dispatch-table.md) | The order of the simulation as readable data, with the empty rows kept. |
| [302 motion is intent, then resolve](completed/302-motion-is-intent-then-resolve.md) | Write down what everybody means to do, settle it afterwards. |
| [303 bodies collide with walls](completed/303-bodies-collide-with-walls.md) | Sliding rather than stopping. Twice, then stop. |
| [304 crossing a boundary changes region](completed/304-crossing-a-boundary-changes-region.md) | The hook under "when they enter the tavern". |
| [305 randomness comes from named streams](completed/305-randomness-comes-from-named-streams.md) | Adding a roll here does not move the rolls over there. |
| [306 the command log is the replay](completed/306-the-command-log-is-the-replay.md) | Editable and indexed, because a retcon is an edit to it. |
| [307 the world hashes itself](completed/307-the-world-hashes-itself.md) | One number for a whole world. Built in phase 1 alongside the file format, since both walk the same fields. |
| [308 the turn is a window](completed/308-the-turn-is-a-window.md) | Declarations accumulate; something closes the window; everything settles at once. |
| [309 taking a turn back](completed/309-taking-a-turn-back.md) | Restore the head and run it again, or run it differently. |
| [310 the phase three demo](completed/310-the-phase-three-demo.md) | The capstone. |

## What is built

| Source | What it is |
| --- | --- |
| `047-streams` | Randomness that comes from somewhere you named. |
| `049-tick` | The eight passes, motion, collision, and the crossings. |
| `051-commandlog` | The record, and the dispatch table that turns it into changes. |
| `053-session` | The window, the ring of heads, and the replay forward. |
| `055-demo-phase-3` | Determinism measured, then spent. |

## What the phase actually established

**Determinism, and then what determinism buys.**

The same 500-beat session with 24 bodies moving runs identically at one, two,
four, and eight threads — compared at **every beat**, not just the end, because
"they differ" is not a finding and "they first differ at beat 137" is.

Then 308 and 309 cash it in. **Rollback is not a feature built on top of the
simulation.** It is a snapshot plus a deterministic replay, and both already
existed for other reasons. That is now the third time a decision made for one
reason has turned out to be the whole answer to a different question, which is
often enough to be worth watching for rather than enjoying.

## The measurement that went the wrong way

**Threading the motion passes makes them slower.** Twenty-four bodies is a few
microseconds of arithmetic, and waking a pool and waiting on a barrier costs more
than the work it coordinates.

Sight was worth parallelising and motion is not — the same measurement pointing
in two directions. The pool is not the wrong tool; motion at tabletop scale is
the wrong size of job for it.

It was **not changed on the spot.** The demo reports it, and
[13.1](../docs/016-open-questions.md) asks where a per-pass threshold should live
and whether it should be measured on the host's machine at startup rather than
compiled in. Changing it quietly would have meant a number nobody measured
replacing a number nobody measured.

## The problem the phase does not solve

Undoing the world is a block copy. **Undoing what somebody saw is impossible.**

Fog rolls back with the world — decided, and shown on screen rather than
described. The demo draws a player's map before a turn, after they walk into the
far room, and after the turn is taken back, and the room visibly closes over.

The person still remembers it. They looked at it. The screen now knows less than
they do. That is the cost, and the alternative is worse in a way that never goes
away: a map holding a place reached in a turn that never happened, contradicting
the world every time anybody walks there again.

**You cannot restore ignorance.** A rollback at a tabletop has always been a
social agreement, and the program's job is to put the board back.

## Open questions this phase settled

- **3.1** — turns are simultaneous transactions with an undo, and the server
  understands nothing else about them.
- **3.3** — fog rolls back with the world.

## Open questions this phase raised

- **13.1** — should the motion passes go to the pool at all, and where does a
  threshold live?
- **13.2** — does a replayed turn re-snapshot? Currently no, deliberately, and
  the reasoning deserves a test nobody has written.
- **13.3** — what happens to commands declared past the point a retcon replays
  to? Cannot come up until phase 4, and will.

## What phase 4 inherits

A world that moves reproducibly, a log that is a replay, a turn that can be taken
back — and a sight pass sitting in row 6 of the tick table with nothing to run
for, waiting for viewers.
