# 102 — Core Game Loop & Program Lifecycle

> **Phase:** 1 (Engine Foundation) · **Depends on:** `101` (needs the Platform
> seam for timing, input, and blit) · **Blocks:** `104`, `105`, `106`, `107`
> (they run *inside* this loop) · **Difficulty:** medium · **Kind:** load-bearing
> scaffolding.

The heartbeat. This issue builds the skeleton the whole engine runs inside — the
thing that reads `input/` to wake up, ticks the world at a steady rate, draws a
frame, and writes `output/goodbye` to go to sleep. It ships with *stub* systems
so the loop is provable before the world, renderer, and movement exist; later
issues replace the stubs with real systems without touching the loop.

## Current Behavior

Nothing exists. There is no entry point, no clock, no update/render rhythm, and
no wiring of the project's read-`input/`-first / write-`goodbye`-last lifecycle.
The seed files `input/startup` and `output/goodbye` exist and describe the
contract, but no program honours it yet.

## Intended Behavior

A single, legible main loop that owns the program's whole life:

- **First act — read `input/`.** Before opening a window or a device, parse
  `input/startup` into a **RunConfig** (which world to load, input mode, role).
  Missing required keys **error out**, never silently default.
- **Boot.** Ask the Platform (issue `101`) to open a surface, start its clock,
  open input, and allocate the **Framebuffer**. Build/load the World and spawn
  the Player through seams that are stubs today (issues `103`, `105`, `106` fill
  them in).
- **Fixed-timestep simulation.** Accumulate real elapsed time and step the
  simulation in fixed increments so motion and collision are deterministic and
  frame-rate-independent — important on a handheld whose frame rate will wobble.
  Render once per display frame, interpolating between the last two sim states so
  motion stays smooth even when sim ticks and frames don't line up.
- **Per-tick shape.** Each tick: drain Platform input → fill an **IntentFrame**
  (stub translator now; Phase 2 replaces it) → run the update systems (stubs now:
  movement `105`, gravity `106`) → advance the world.
- **Per-frame shape.** Render (stub now: issue `104`) into the Framebuffer, then
  Platform blits it.
- **Quit path.** A quit intent (or Platform close) drops out of the loop cleanly.
- **Last act — write `output/goodbye`.** On exit, write the goodbye file. This is
  the final thing the program does, every run, success or clean quit.
- **Ephemeral logs** are written under the project-local `tmp/` symlink (a
  RAM-backed `/tmp/` directory); the run script ensures that symlink exists
  before the loop starts.
- A **run script** launches the game: hard-coded `${DIR}` at the top, overridable
  by argument, all paths relative to `${DIR}`, so it works launched from anywhere
  (this matters for the eventual handheld/cassette packaging).

## Suggested Implementation Steps

1. Write the **startup reader**: parse `input/startup`'s key = value lines into
   RunConfig; error on missing required keys. Give it its `.info.md`.
2. Write the **EngineState** bundle (Platform, World, Player, Camera, Framebuffer,
   the timestep accumulator/clock, running flag) so the loop passes one value.
3. Implement the **fixed-timestep loop**: accumulate time, step fixed sim ticks,
   render with interpolation, blit. Keep the tick rate a named constant, not a
   magic number, and expose it to a future stats utility rather than hardcoding
   it in docs.
4. Stub the seams the loop calls — poll-input→IntentFrame, update, render — as
   trivial no-ops or a spinning-camera placeholder, each clearly marked as a stub
   that announces itself, so the loop is provable today and honest about what's
   fake.
5. Wire the **lifecycle bookends**: read `input/startup` as the very first act;
   write `output/goodbye` as the very last, including on clean quit.
6. Write the **run script** (`${DIR}` convention, ensures the `tmp/` symlink
   exists) and prove the loop runs, ticks steadily, shows a placeholder frame,
   quits cleanly, and leaves a fresh `output/goodbye`.

## Related Documents / Tools

- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  one-run data flow diagram, the EngineState/RunConfig/IntentFrame structures,
  and the fixed-timestep transform.
- [input/startup](../input/startup) and [output/goodbye](../output/goodbye) — the
  lifecycle bookend seed files this loop honours.
- Depends on issue `101` (Platform). Feeds issues `104`/`105`/`106` (they replace
  this loop's stubs) and `107` (the demo runs this loop).
