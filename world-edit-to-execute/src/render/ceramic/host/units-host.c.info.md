# units-host.c

The renderer's main thread as the ceramic engine's host (issues 515b, 515c).
It is appended after the map's construction code, built against the kept
engine copy and the mailbox, and linked with raylib.

- **Usage:** `./units-host [--check STATES | --shot FRAMES PATH]`.
  - no option: a window, until closed;
  - `--check`: no window; this thread takes states through the mailbox
    while the feeder races, and compares every unit with `unit_place` at the
    state's time, and every state's number and time with the one before;
    exits 1 on a difference;
  - `--shot`: a hidden window draws into an off-screen texture, and the
    last frame is saved as a picture.
- **`unit_state`:** one whole state as the mailbox carries it: `frame`
  (`int`), `time` the units were true (`float` seconds), `engine_us`
  (`double`, hand-in to landed) and `lanes` (8 × `lane_units`).
- **`host_start`:** starts the engine, finds the doors, makes the mailbox
  (one writer) and starts the feeder thread.
- **The feeder:** per state, points each lane's landing into the buffer it
  writes, hands the tick and eight lane requests in as one batch, waits for
  the eight landings, stamps and publishes; then waits until the draw
  thread has taken it.
- **`host_take`:** the newest state for the draw thread; taking a new one
  lets the feeder go on.
- **`host_stop`:** stops the feeder, then the engine.
- **`draw_units`:** a cube per unit of a state.
- **Output:** one line: mode, frames, mean hand-in-to-landed (µs), mean
  draw-thread frame (µs, before the screen's refresh), mean state age when
  drawn (ms; 0 in the fixed-step modes), frames that drew a state again,
  units.
