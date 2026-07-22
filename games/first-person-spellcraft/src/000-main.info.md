# 000-main.c — the program's story

The entry point and narrative spine. No external functions (everything is
`static`) — this file *is* the program, read top to bottom, per
`notes/note-to-claude-ai`.

## The shape of `main()`

1. **say_hello** — announce waking.
2. **read_startup** (the FIRST act) — open `<dir>/input/startup`, parse `key =
   value` lines. Missing file is a loud fatal error (read-`input/`-first is a
   contract, not optional; no silent default). Honors `frames` today; env
   `FPS_FRAMES` overrides for headless/test runs.
3. **boot** — create the worker pool (threads) and slot store (wires); allocate
   the renderables slot.
4. **spin up threads** — start the dedicated render thread (the one thread that
   is not a box — GL affinity), then kick the `mover` source box onto the pool.
5. **run** — watch the `g_quit` flag until the render thread raises it (window
   close or frame budget).
6. **break down** — join the render thread, destroy the pool (the mover sees
   `g_quit` and stops re-arming, so the pool drains), free the slots.
7. **say_goodbye** (the LAST act) — write `<dir>/output/goodbye`. Always.

## The Phase-1 boxes/threads here

- **mover_box** — the frame-clock heartbeat's stand-in: a source box that nudges
  a rectangle across the room and publishes its position into the renderables
  slot, re-arming until quit. Its `nanosleep(~16 ms)` is a **placeholder for the
  real timer box** (SoraMech issue 251); when that lands, the box is driven by a
  clock tick on a wire instead of sleeping.
- **render_thread** — dedicated, always-unblocked: owns the raylib window, drains
  the renderables slot to the latest position each frame, draws it, presents.
  Lagging the pool by a frame or two is fine (`soramech-notes.md` pattern 7).

## Run

`FPS_FRAMES=N ./fps <project-dir>` — auto-quits after N frames (0/unset = run
until the window is closed). Launched normally via the `run` script.

## Related

- `libs/{engine-core,task-pool,platform}` — the substrate + seam it wires.
- Issue `102` — the core loop & lifecycle this realizes.
