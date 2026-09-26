# units-host.c

The renderer's main thread as the ceramic engine's host (issue 515b). It is
appended after the map's construction code, built against the kept engine
copy, and linked with raylib.

- **Usage:** `./units-host [--check FRAMES | --shot FRAMES PATH]`.
  - no option: a window, until closed;
  - `--check`: no window; every unit of every frame is compared with
    `unit_place` called directly, exiting 1 on a difference;
  - `--shot`: a hidden window draws into an off-screen texture, and the
    last frame is saved as a picture.
- **`host_start`:** starts the engine and finds the doors.
- **`host_frame`:** re-arm, hand the tick and eight lane requests in as one
  batch, wait for eight landings; returns the microseconds from hand-in to
  landed.
- **`draw_units`:** a cube per unit.
- **Output:** one line: mode, frames, mean hand-in-to-landed, mean drawing
  (µs), units.
