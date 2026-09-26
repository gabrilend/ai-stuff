# frame-plan.h

Shared by every way of running the fabricated frame (issue 515h), so they
all do the same work.

- **`churn(x, rounds)`**: the stand-in work, a hash chain of `rounds` steps.
  Its cost is real and its answer checkable.
- **`us_rounds(us)`** converts microseconds to rounds using
  `ROUNDS_PER_US`. The build measures that once and passes it to every
  program; compiling without it is an error.
- **The plan:**
  - `fog_us(frame, player)`: 400–1000 µs;
  - `path_count(frame)`: 20–60 requests;
  - `path_us(frame, id)`: 10 µs to about 2 ms, in 8 bands, most short;
  - constants: `SIM_US`, `CULL_US`, `DECODE_US`, `FRAME_PLAYERS`,
    `FRAME_LANES`, `FRAME_UNITS_PER_LANE`, `FRAME_PATHS_MIN` / `_MAX`,
    `FRAME_DECODES`.
- **`mix32(x)`**: a 32-bit hash; every choice in the plan comes from it, by
  frame number.
