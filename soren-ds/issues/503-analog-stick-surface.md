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

## Related documents

- `docs/004-input-model.md`.

## Blocked by

101 (ADC channel mapping), 501.

## Blocks

506 (the radial-menu chord accepts a stick direction), 508.
