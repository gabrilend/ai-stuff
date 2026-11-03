# 503 — Analog stick surface

## Current behavior

The polling map (501) has a `read-sticks` stub. The device has
two analog sticks, each with an X and Y axis sampled by an ADC,
and each clickable as a button (handled in 502 alongside other
buttons). The continuous X/Y reads are this issue's surface.

## Intended behavior

The `read-sticks` box reads the four ADC channels (left X, left
Y, right X, right Y) into a small struct value. The output is
emitted every frame.

Above `read-sticks`:

- **`stick-deadband`** — clamps tiny center-area readings to
  zero so a thumb resting on a stick doesn't produce drift
  events. The deadband size is calibrated per-device from
  101's findings.
- **`stick-direction`** — quantizes each stick's continuous X/Y
  into one of eight directions (N, NE, E, SE, S, SW, W, NW) or
  the neutral state. The quantization uses angle sectors, not a
  square grid, so diagonal sticks count as diagonals and not as
  either-of-the-cardinals. The directions match the D-pad's
  eight-direction model from `004-input-model.md` so the
  radial-menu chord (506) can accept either stick or D-pad as
  the direction source.
- **`stick-direction-changed`** — emits an event only when the
  quantized direction changes from the previous frame. Apps
  that care about the moment-of-change subscribe here; apps
  that want per-frame updates wire `stick-direction` directly.

The deadband and the angle-sector boundaries are tunable
per-stick. The values for the launch device live in
`notes/diagnostics/002-stick-calibration.md`, written by the
implementer when the hardware is in hand and the calibration
fits the user's grip preferences.

## Suggested implementation steps

1. `read_sticks_box()` — ADC reads.
2. `stick_deadband_box()` — center clamping.
3. `stick_direction_box()` — angle-to-sector quantization.
4. `stick_direction_changed_box()` — per-frame edge detection.
5. Wire into the input-poll map from 501.

## Open questions

- *What range and sense do the axes have?* 101 has not named the ADC.
- *A square resting zone, or a circle?*
- *How are angle sectors found without floating point?*
- *What does "tunable per-stick" tune?*
- *How does stick-direction-changed know the previous frame?*
- *What numbers do the directions have, for 506?*
- *What resting radius until the device is measured?*

### Proposed answers (UNVERIFIED)

Each one is a choice Ritz can overturn.

1. *Centred on 0, x right and y up, about ±2048* — a 12-bit converter
   with its resting middle taken off by the read. The seam
   (`input_sticks_now`) promises that shape; the device answers zeros
   until 101.
2. *A circle* (`x² + y² < r²`), so a small push on a diagonal rests just
   as a small push straight does. Outside it, the reading passes through
   unscaled.
3. *By tangent, in integers.* A point is straight on when its smaller
   axis is within `edge` millionths of its larger; 414 214 (tan 22.5°)
   makes the eight sectors equal, and the boundary falls exactly there.
4. *A `struct stick_tuning` on a fixed port*: each stick's resting radius
   and its edge. A larger edge widens the four straight sectors.
5. *The same way as the buttons*: `stick_track` keeps both directions on
   a loop and marks which changed; `stick_direction_changed` is a
   comparator so only frames with a change go on. A stale frame changes
   nothing.
6. *`enum direction` in 096-input.h*: 0 none, then N, NE, E, SE, S, SW,
   W, NW. The D-pad's two-bit diagonals map onto the same numbers when
   506 needs them.
7. *200*, a placeholder (about a tenth of the throw), written in the
   input-poll map. `notes/diagnostics/002-stick-calibration.md` is not
   written: its numbers come from the device.

## What happened

Built on the twin as answered above.

- `src/boxes/095-input.c` — `read_sticks` reads; `stick_deadband`,
  `stick_direction` (both every frame), `sticks_at_rest`, `stick_track`,
  `stick_direction_changed` and `say_sticks`.
- `src/maps/input-poll.map` — the stub replaced by that chain; changes
  are said on the developer line, and per-frame directions are
  `stick_direction`'s own exit for anyone who wants them.
- `src/system/096-input.h` — `input_sticks_now`, `enum direction`,
  `direction_name`; the device answers zeros
  (`src/device/098-input-device.c`), the twin what a test set.
- `twin/tests/103-test-sticks-and-touch.c` — the eight directions, the
  22.5° edge to the millionth, the circle (150,150 is outside a 200
  circle, where a square would have held it), a widened edge, a stale
  frame; through the map, five changes said and a push that stays east
  not said.

Waiting for 101 and the device: the ADC read, and the calibration.

## Related documents

- `docs/004-input-model.md`.

## Blocked by

101 (ADC channel mapping), 501.

## Blocks

506 (the radial-menu chord accepts a stick direction), 508.
