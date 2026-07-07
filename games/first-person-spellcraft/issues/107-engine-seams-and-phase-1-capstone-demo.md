# 107 — Engine Seams & Phase 1 Capstone Demo

> **Phase:** 1 (Engine Foundation) · **Depends on:** `101`–`106` (all of Phase 1)
> · **Blocks:** nothing in Phase 1; unblocks Phases 2, 3, 4, 6 through the seams
> it verifies · **Difficulty:** medium · **Kind:** capstone — seam-hardening +
> the deliverable phase demo.

The keystone that proves the foundation holds. Two jobs: (1) make the **seams**
other phases plug into explicit, documented, and demonstrably empty-but-present;
(2) build the **Phase 1 demo** — a runnable, visual, statistics-forward program
that shows a player walking, colliding, and platforming through the square-room
world, per the project's phase-demo discipline. The demo is part of the
deliverable, not just an artifact.

## Current Behavior

Nothing exists. Once issues `101`–`106` land, the engine can load a world, run
its loop, render a first-person view, move a player, and platform — but the seams
for later phases aren't consolidated or proven, and there is no phase demo or
demo launcher, so the foundation's readiness can't be *shown*.

## Intended Behavior

**Seams made explicit and verified** (each described as the interface this phase
*exposes*, not the later phase's internals):

- **Input seam (Phase 2).** Confirm the movement/vertical systems read only the
  IntentFrame, and that swapping the intent *translator* changes control without
  touching the loop or the movers. Demonstrate with a trivial alternate
  translator (e.g. a scripted intent playback) driving the same player.
- **Spell-effect render seam (Phase 3).** Confirm the post-geometry/pre-blit
  render hook exists and can be fed a no-op pass; document its contract for
  Phase 3.
- **Room special-property seam (Phase 4).** Confirm the room-behaviour dispatch
  table fires enter/step/exit callbacks as the player crosses rooms, using the
  trivial `plain`/`spawn` entries; document how a later phase registers a real
  puzzle behaviour.
- **World-population seam (Phase 6).** Confirm a World assembled purely as data
  (not hand-wired in engine code) loads and runs identically, proving the
  Dungeon Master can emit worlds the engine consumes unchanged.
- **Platform seam (Phase 9).** Confirm the engine names no framework directly and
  runs entirely through the four Platform verbs.

**The Phase 1 demo** (`issues/completed/demos/`):

- A **visual, runnable** program: a first-person walk through a small square-room
  world with at least one door and one platforming ledge — move semi-quickly,
  slide along walls, jump onto the ledge, fall off it, pass through the door.
- **Statistics-forward** per phase-demo discipline: overlay or print the real
  datapoints — tick rate, internal render resolution, frame time, loaded room and
  cell counts, player position/height — read from the engine and the issue `103`
  validator, **not** hardcoded, so the demo doubles as the live stats readout the
  docs reference.
- Shows the phase's tools **recombined**: the loop, world, renderer, movement, and
  platforming working together, plus the seams exercised (the scripted-intent
  translator and the data-emitted world), so the demo previews how Phases 2/6
  will attach.
- Launched by a **simple bash script** in the demo directory, and reachable from a
  **project-root demo launcher** that asks for a number 1–y (y = completed phases)
  and runs the chosen phase demo. Both scripts follow the `${DIR}` convention
  (hard-coded at top, overridable by argument, all paths relative), and ensure the
  `tmp/` symlink exists before running.

## Suggested Implementation Steps

1. Audit issues `101`–`106` for seam leaks: anything downstream that names a
   framework, reads a device instead of an intent, or hand-wires a world in
   engine code. Fix so every seam is clean.
2. Write the seam contracts into each relevant file's `.info.md` and into
   `docs/datapath-engine-foundation.md`'s seams section (Phase 2/3/4/6/9 entries).
3. Build a **scripted-intent translator** and a **data-emitted test world** as the
   two throwaway-or-kept proofs the input and world-population seams work; decide
   per house rule whether each is kept or marked `-done` for a commit.
4. Build the **Phase 1 demo**: the walkable/platforming world plus the live stats
   overlay sourced from the engine and the issue `103` validator.
5. Write the **demo launch script** (in the demo dir) and the **project-root demo
   launcher** (number-picker over completed phases), both `${DIR}`-convention and
   `tmp/`-symlink-safe.
6. Run the demo end to end; confirm read-`input/`-first and write-`goodbye`-last
   still bookend the run. Update `issues/phase-1-progress.md` to reflect Phase 1's
   completion in the context of its goals.

## Related Documents / Tools

- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  full seams section this issue hardens and the one-run flow the demo exercises.
- [roadmap.md](../docs/roadmap.md) — Bucket A ("It's a world you can move in") and
  the phase-demo-as-deliverable discipline.
- Depends on all of `101`–`106`. Consumers of its seams: Phases 2, 3, 4, 6, 9.
