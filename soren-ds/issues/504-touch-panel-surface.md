# 504 — Touch panel surface

## Current behavior

The polling map (501) has a `read-touch` stub. Both screens are
touch-capable; their touch controllers are I2C devices (per 101)
the kernel has not yet spoken to.

## Intended behavior

The `read-touch` box queries both touch controllers each frame
and emits a struct value carrying, for each screen, whether a
touch is active and the touch's X and Y position (in screen
pixels). No multi-touch — the controllers report one position
per screen, which matches the device's single-stylus model.

Above `read-touch`:

- **`touch-down`** — fires when a screen's touch transitions
  from "no touch" to "touched." Emits an event with the screen
  id and the position.
- **`touch-move`** — fires every frame the touch is active *and*
  has moved at least one pixel since the previous frame. Emits
  the screen id and the new position. Apps that don't want the
  per-frame moves subscribe to `touch-move-changed` (a variant
  that emits only when the integer pixel position changes).
- **`touch-up`** — fires when a screen's touch transitions from
  "touched" to "no touch." Emits the screen id and the *final*
  position (the last frame's where the touch was active).

The bring-up of the I2C controller is in `read-touch`'s
implementation. The controller's protocol is per-vendor — 101's
findings name the chip and the register map. The I2C transactions
are synchronous from the polling thread's perspective; the chip's
read is small (a few bytes) and fits in the frame budget.

If a touch controller fails to respond within the frame's budget,
`read-touch` reports the missing-screen as "no touch this frame"
and logs a one-event warning into the RAM transcript ring (310).
A persistent miss across many frames flips an LED pattern through
the diagnostics from 106.

## Suggested implementation steps

1. Touch controller init through I2C — per the chip's datasheet.
2. `read_touch_box()` — per-frame I2C transactions for both
   screens.
3. `touch_down_box()`, `touch_move_box()`, `touch_up_box()`.
4. Per-screen history struct (last-state, last-position).
5. Wire into the input-poll map from 501.

## Related documents

- `docs/004-input-model.md`.

## Blocked by

101 (touch controller details), 501.

## Blocks

508.
