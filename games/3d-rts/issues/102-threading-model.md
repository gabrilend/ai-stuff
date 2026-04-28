# 102 — Threading Model (pthreads)

## Status

TODO

## Current behavior

The bootstrap from issue 101 runs entirely on the main thread. There is
no simulation thread, no input queue, no snapshot buffer.

## Intended behavior

The program runs two OS threads as described in `docs/004-architecture.md`:

- The main thread polls raylib input, pushes input events to a queue,
  reads the published snapshot, and renders.
- A simulation thread runs a fixed-rate tick loop that drains the queue,
  updates state (initially: a single moving placeholder marker), and
  publishes a fresh snapshot.

A user runs the binary and sees a placeholder shape moving in a circle
on the screen, driven by the sim thread, while camera/input remain
responsive on the main thread regardless of sim load.

## Suggested implementation steps

1. Create `src/010-config.h` with `SIM_TICK_HZ`, `MAX_UNITS`,
   `MAX_PROJECTILES`, and the snapshot struct shape (forward-declared).
2. Create `src/110-snapshot.c` / `.h` with a double-buffered snapshot
   pair, a `pthread_mutex_t`, and `snapshot_publish()` /
   `snapshot_acquire()` primitives.
3. Create `src/040-input.c` / `.h` with a fixed-capacity ring queue of
   semantic input events plus its mutex. Events are not yet defined —
   start with one placeholder type.
4. Create `src/120-sim.c` with a `sim_thread_main()` function that:
   - Sleeps to maintain `SIM_TICK_HZ`.
   - Drains the input queue.
   - Updates a placeholder "marker" position in a circle.
   - Publishes a snapshot.
5. Update `src/001-main.c` to spawn the sim thread before entering the
   render loop and join it after the window closes.
6. Render the placeholder marker each frame from the snapshot, never
   from sim state directly.

## Related documents

- `docs/004-architecture.md` — full architectural picture.

## Related libraries

- `libs/900-coroutine-pool.h` — an M:N coroutine pool over pthreads
  exists in the project. **It is not used by this issue.** The two
  pthreads here are dedicated, long-lived threads with a clear data
  boundary; substituting a coroutine pool would be a separate
  redesign (and a separate issue). The library is listed here only
  so future readers know it exists. See
  `issues/114-coroutine-pool-library.md` for the rationale.

## Notes

Test that the camera input feels snappy even when the sim has work to do.
A useful sanity test: deliberately `usleep` for 100ms inside one sim tick
and confirm rendering does not stutter — only the marker pauses for a
tick. This confirms the decoupling holds.
