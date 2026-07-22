# 102b — Runnable loop: lifecycle, raylib window, render thread, story main()

> **Phase:** 1 (Engine Foundation) · **Sub-issue of:** `102` · **Depends on:**
> `102a` (the dataflow substrate) and `101` (pure-C + raylib) · **Blocks:** every
> Phase-1 issue that runs *inside* a live window (`103`–`107`) · **Difficulty:**
> medium · **Kind:** the thing you can actually launch · **Status:** COMPLETE.

`102a` built the substrate (wires, threads, the graph turning) and proved it
headless. This sub-issue turns it into a **program you run**: it reads `input/`
to wake, opens a window, lets the graph drive what's drawn, and writes `goodbye`
to sleep — the Phase-1 skeleton alive on screen.

## Current Behavior

A launchable program. `./run` (or `make run`) builds the engine into the
exec-capable RAM tier and starts it; it opens a raylib window showing a
rectangle the graph nudges across the room, and quits cleanly on window-close or
after a frame budget (`FPS_FRAMES`), writing `output/goodbye` last.

Pieces:

- **Lifecycle bookends** (`src/000-main.c`) — the first act reads
  `<dir>/input/startup` into a run-config (missing file is a loud fatal error, no
  silent default); the last act writes `<dir>/output/goodbye`, every run.
- **Platform seam** (`libs/platform/platform.{c,h}`) — the four-verb window/GL
  abstraction (open, should-close, time, begin/draw/end frame); raylib is its
  only implementation, so a later SDL/framebuffer backend swaps in here alone.
- **Dedicated render thread** (`src/000-main.c`) — owns the GL context, runs an
  always-unblocked loop that drains the renderables slot to the latest position
  and draws it; may lag the pool a frame or two (no pinning, per the design
  decision in `101`/notes pattern 7).
- **Story `main()`** — the narrative spine (`note-to-claude-ai` shape): hello →
  read input → boot pool+slots → spin up render thread + kick the source box →
  run until quit → break down → goodbye.
- **The `mover` box** — a source box standing in for the frame-clock heartbeat;
  its `nanosleep(~16 ms)` is an explicit placeholder for the real timer box
  (SoraMech issue 251).
- **Build + launch** — a `Makefile` (build/run/test/clean; binary to the /tmp
  exec tier because /dev/shm is noexec) and a `${DIR}`-convention `run` script
  that ensures the RAM symlinks and launches.

## Intended Behavior

Exactly the above: the substrate made launchable, with the framework kept behind
a swappable seam and the lifecycle honouring read-`input/`-first /
write-`goodbye`-last. No spells, mice, world, or real renderer yet — those are
later issues that replace the mover box and the `draw_rect` placeholder.

## Suggested Implementation Steps (as built)

1. **Platform seam** — define the four verbs, back them with raylib in one file.
2. **Render thread** — open the surface on this thread (GL affinity), loop:
   drain renderables to latest, draw, present; raise the shared quit flag on
   close/budget.
3. **Story main()** — read startup; create pool + slots + renderables slot; start
   the render thread; kick the mover source box; watch the quit flag; join, tear
   down, write goodbye.
4. **Build/launch** — Makefile (binary to the exec tier — `/dev/shm` is noexec)
   and a `${DIR}` run script that ensures the RAM tiers exist.

## Discovered along the way

- `/dev/shm` (the `tmp/shared-memory` tier) is mounted **noexec**: executables
  must build into the `/tmp` tier (`tmp/`), `/dev/shm` is for logs/non-exec only.
  Recorded so future build scripts don't repeat the "Permission denied" surprise.

## Relevant files

- `src/000-main.c` (+ `.info.md`), `libs/platform/platform.{c,h}` (+ `.info.md`),
  `Makefile`, `run`, `input/startup`, `output/goodbye`.

## Remaining in the parent (`102`) / later phases

The raw-input→intent seam (Phase 2 mice), and replacing the mover box's
`nanosleep` with the real timer box (SoraMech issue 251) once it exists.
