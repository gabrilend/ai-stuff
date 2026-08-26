# Phase 3 — The world ticks, and turns can be taken back

**Goal:** time. The heartbeat, motion, determinism, the replay — and then turns,
which are transactions that resolve at once and can be undone.

**Status:** not started. All ten issues are written and none is implemented.

## The issues

| Issue | State | What it is for |
| --- | --- | --- |
| [301 the tick is a dispatch table](301-the-tick-is-a-dispatch-table.md) | not started | The order of the simulation as readable data instead of a function body. |
| [302 motion is intent, then resolve](302-motion-is-intent-then-resolve.md) | not started | Write down what everybody means to do, settle it afterwards. |
| [303 bodies collide with walls](303-bodies-collide-with-walls.md) | not started | Sliding rather than stopping, and why bodies pass through each other. |
| [304 crossing a boundary changes region](304-crossing-a-boundary-changes-region.md) | not started | The hook under everything of the form "when they enter the tavern". |
| [305 randomness comes from named streams](305-randomness-comes-from-named-streams.md) | not started | So that adding a roll in one place does not move every roll everywhere. |
| [306 the command log is the replay](306-the-command-log-is-the-replay.md) | not started | Editable and indexed, because a retcon is an edit to it. |
| [307 the world hashes itself](307-the-world-hashes-itself.md) | not started | One number for a whole world, compared every tick, which is where "when" comes from. |
| [308 the turn is a window](308-the-turn-is-a-window.md) | not started | Declarations accumulate; something closes the window; everything settles at once. |
| [309 taking a turn back](309-taking-a-turn-back.md) | **blocked** | Restore the head and run it again. Cannot be completed until 3.3 is answered. |
| [310 the phase three demo](310-the-phase-three-demo.md) | not started | The capstone. Proves determinism, then spends it. |

## What this phase is really establishing

**Determinism, and then what determinism buys.**

The first seven issues exist to make one claim true: the same world, the same
commands, and the same seed produce the same result on any machine with any number
of threads. Every mechanism in them serves it — integers rather than floats,
buffer-then-resolve rather than in-place updates, named streams rather than one
generator, stable tie-breaks rather than whatever the sort did.

Then 308 and 309 cash it in. **Rollback is not a feature built on top of the
simulation — it is determinism plus a snapshot, and both already existed.** That
is the third time in this project a decision made for one reason has turned out to
be the whole answer to a different question, which is now often enough to be worth
watching for rather than enjoying.

## The problem this phase cannot solve

Undoing the world is a block copy. **Undoing what people saw is impossible.**

If somebody walked into an unexplored room during a turn that is now being taken
back, their fog recorded it — and they also just looked at it with their eyes. Roll
the fog back and the program is internally consistent while the person is not.
Leave it and their map holds a room the world says was never entered.

The program can restore state. It cannot restore ignorance. Whichever way
[3.3](../docs/016-open-questions.md) goes, it is a choice about which kind of wrong
is more comfortable, and [310](310-the-phase-three-demo.md) is written to put it on
screen rather than describe it.

## Blocking open questions

- **3.3** — does fog roll back with the world? **Blocks
  [309](309-taking-a-turn-back.md) from being completed**, not from being started.
- **3.4** — who may roll back, when several GMs are present and a retcon rewrites
  what somebody else did?
- **3.5** — what closes a window: everybody declaring, a timer, or a GM?
- **3.6** — does a rolled-back turn reach the engraving? The log keeps it
  regardless.
- **3.2** — the tick rate, which phase 2's demo should have measured by now.
- **12.3** — is the command log capped or rotated? A session is hours long and
  every decoded operand goes into it.
