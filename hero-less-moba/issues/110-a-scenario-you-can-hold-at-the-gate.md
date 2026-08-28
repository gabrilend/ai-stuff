# 110 — A Scenario You Can Hold at the Gate

| | |
| --- | --- |
| Phase | 1 — The Ground and the Clock |
| Blocked by | 103, 106, 108 |
| Blocks | 805, 906 |
| Reads | [the simulation tick](../docs/003-the-simulation-tick.md) · [players, teams, and commands](../docs/016-players-teams-and-commands.md) |
| Open questions | none |

## Current behavior

A scenario is a hand-written file describing a world — which tick, which phase,
which towers are rubble, what is placed where, who holds what, and commands that fire
later — loaded into a fresh world and **held** until released. It can be stepped a
fixed number of ticks or run until any event the simulation already announces.

`./run-scenario` loads one, describes it, and waits.

## Intended behavior

A **scenario**: a described starting state, loaded into a fresh world, **held at a
gate until released**.

This is the third kind of test in the project and it is not the other two. It is
not a unit test over a data structure, and it is not the headless runner from
issue 108 playing a whole match at speed. It is **a simulation test** — put the
world somewhere interesting, look at it, step it, and see what happens next.

### What a scenario file says

Everything the match parameters in `input/` say, plus a described world:

- the seed, map parameters, team size, and each player's commander
- **what already exists**: waves in flight and where, which towers are rubble,
  what each player is holding and what is placed where, resource balances
- **which phase and which tick** to start from — a surge two-thirds through, a
  challenge with the Dragon at the midpoint, a calm with boons unchosen
- **a command script**, optional: commands with the tick they fire on

It is written by hand and it is diffable, which is the point. A scenario that
reproduces a bug is a bug report anybody can run.

### The gate

**Nothing advances until the scenario is released.** Load, look, then say go.

That is the whole feature and it deserves stating plainly, because it is what
separates this from the headless runner. A match that begins running the instant
it loads cannot be *inspected before it moves* — and the most useful moment in
debugging a simulation is almost always the tick before the thing goes wrong.

Release modes, all of which are the same gate:

| | Does |
| --- | --- |
| `go` | run until something else stops it |
| `step N` | advance exactly N ticks and hold again |
| `until <condition>` | advance until a wave wipes, a tower falls, a phase changes |

### Why this is in phase 1

Because everything after it is easier with it and nothing is easier without it.
Phases 2 through 6 each end with a demo showing a thing that only happens in the
middle of a match — a stalemate, a stalemate broken, a surge, a Golem — and every
one of those is currently a ten-minute wait per look.

It is also **what the phase demos should be built out of**. A demo is a scenario
plus a release plus a viewer, and if the demos are hand-rolled instead, they will
drift from the game the first time a rule changes.

## Suggested implementation steps

1. Write the scenario reader: a plain text format, one field per line, sections
   for waves, structures, stones, and players. Reuse the `input/` field names
   exactly rather than inventing parallel ones.
2. Write the **validator before the loader**. A scenario that describes an
   impossible world — a stone in two places, a wave in a lane that does not
   exist, a phase that cannot follow the tick given — must be refused by name and
   line, not loaded into a world that then behaves strangely.
3. Build the world from the description using the **same spawn and placement
   routines the simulation uses**. Never write fields directly. A scenario that
   builds its world by a private path is a scenario that tests a world the game
   cannot produce.
4. Wire the gate into the runner from issue 108 as a held state before tick one,
   with `go`, `step`, and `until`.
5. Write `scenarios/` at the project root and put the first one in it: two waves
   about to meet in the middle of one lane, everything else empty. That is the
   phase-2 demo's whole subject and it should exist before phase 2 does.
6. Write a test that loading a scenario, releasing it, and running N ticks gives
   the same world as running a full match to the same state — which is the check
   that a scenario is describing the real game rather than a plausible one.

## Related documents and tools

- [The simulation tick](../docs/003-the-simulation-tick.md)
- Issue 108 — the headless runner this gates
- Issue 109 — the terminal viewer, which is how a held scenario gets looked at
