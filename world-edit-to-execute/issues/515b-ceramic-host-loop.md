# Issue 515b: Ceramic Host Loop

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515a, 515g (the engine copy it builds on)
**Blocks:** 515c, 515e

---

## Current Behavior

Built (2026-09-25), in `src/render/ceramic/host/`.

- **The programs:**
  - `units-types.lua` writes the lane's answer type, and `units-boxes.c`
    holds `advance`, `move` and `unit_place`;
  - `units-gen.lua` writes the map;
  - `units-host.c` is the host, with a window, `--check` and `--shot`;
  - `run-host.sh` builds, checks and takes the picture; `run-host.sh ""
    window` opens the window.
- **Checked:**
  - 600 frames of 2,048 units each matched `unit_place` called directly;
  - the picture shows the units drawn from the landed answers.
- **The numbers** (picture mode, 1280×720, this machine): hand-in to landed
  about 0.15 ms; drawing about 1.3 ms, which is 2,048 separate `DrawCube`
  calls; 472 frames a second. Drawing, not the engine, is now the
  bottleneck, which points at instanced drawing (one call for every cube) as
  a later step.
- **One lesson for picture mode:** reading a hidden window's screen back
  after the frame is shown gives a black picture. Drawing into an
  off-screen texture and saving that is dependable.
- **Still to confirm:** the interactive window (the orbiting camera and the
  numbers updating live). It needs a person at the screen.

## Intended Behavior

A raylib program whose main thread is the ceramic engine's host, drawing
units posed by a ceramic map every frame. This is the first real frame of
the render graph.

- **The map** (`units.map`, written by `units-gen.lua`):
  - a `clock` station turns the host's tick into the frame's clock and fans
    it out to eight `move` lanes;
  - each lane joins the clock with the host's request for its lane, and
    works out its units' places and colours;
  - the eight lanes' answers are the map's results.

  A lane's answer (`lane_units`: 256 units × position and colour) is a value
  type written as named fields by `units-types.lua`.
- **The host** (`units-host.c`):
  - opens the raylib window (the main thread owns it, so drawing is never a
    station) and starts the engine on the kept copy;
  - each frame, hands the tick and the eight lane requests in to the task
    queue as one batch, waits until all eight answers have landed (the
    count is trusted), and draws every unit as a cube;
  - camera and cursor are handled on this thread;
  - shows frames per second, the time from hand-in to landed, and the time
    spent drawing.

  One frame is in flight: the next is handed in after this one has landed.
  The mailbox (515c) is what lets computing and drawing overlap.
- **Modes, so it can be checked without anybody watching:**
  - `--check FRAMES` opens no window. It hands in and collects FRAMES frames
    and compares every unit's place with the same function called directly.
    It exits nonzero on any difference.
  - `--shot FRAMES PATH` draws FRAMES frames in a hidden window and saves
    the last as a picture.
- **The build** (`run-host.sh`): serac `--emit-c` on the map, the emitted
  `main` cut off, the host's `main` appended, compiled against the engine
  copy and linked with raylib's static library.

## Suggested Implementation Steps

1. `units-types.lua` (the `lane_units` value type as named fields), and
   `units-boxes.c`:
   - `clock(tick) -> frame_clock`;
   - `move(lane_req, frame_clock) -> lane_units`;
   - `unit_place()`, the one function both the box and the check call.
2. `units-gen.lua` writes `units.map`.
3. `units-host.c` with the three modes (window, `--check`, `--shot`).
4. `run-host.sh` builds, runs `--check`, and runs `--shot` so the picture
   can be looked at.

## Acceptance Criteria

- [x] `--check` passes: every unit's place over many frames equals the
      direct computation
- [x] `--shot` produces a picture of the units, drawn by the host from the
      landed answers
- [ ] The window runs interactively, with the numbers on screen
- [x] `.info.md` beside each new source file; what it taught recorded in 515

## Related Documents

- `issues/515-render-graph-on-the-ceramic-engine.md`
- `src/render/ceramic/frame/` (the harness this follows)
- `src/render/run` (how the existing renderer links raylib)
