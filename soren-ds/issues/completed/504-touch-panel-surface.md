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

## Open questions

- *One event per screen, or per frame?*
- *touch-move and touch-move-changed: what is the difference?*
- *Where is "the final position" for touch-up?*
- *Is the frame a panel is first touched also a move?*
- *What happens to the warning and the LED pattern on a missed read?*

### Proposed answers (UNVERIFIED)

Each one is a choice Ritz can overturn.

1. *Per frame, both screens in it*, as the buttons are: a
   `struct touch_event` carries which screens (bit 0 bottom, bit 1 top)
   and where on each. Two screens touched in the same frame are one
   event; each still carries its own screen's place.
2. *None, here.* Positions are whole pixels, so "moved at least one
   pixel" and "the integer position changed" are the same test. One
   `touch_move`; no second box.
3. *The history keeps it.* Once let go, a panel's point stays where it
   was last touched (with `down` 0), so touch-up says that place, not the
   zeros the controller answers when untouched.
4. *No.* The first frame is a down; moves start on the next.
5. *Device work, waiting with the controller (101).* The seam promises
   that a controller which misses the frame's budget reads as untouched;
   the transcript line and the LED pattern belong beside the I2C read.

## What happened

Built on the twin as answered above.

- `src/boxes/095-input.c` — `read_touch` reads both panels;
  `touch_at_rest`, `touch_track` (each panel's history and what happened
  on it), `touch_down`, `touch_move`, `touch_up` (comparators against an
  all-zero event) and `say_touch`.
- `src/maps/input-poll.map` — the stub replaced; downs and ups said on
  the developer line, moves unheard (they come every frame a finger
  slides).
- `src/system/096-input.h` — `input_touch_now(screen, out)`; the device
  answers "not touched" for both, the twin what a test set.
- `twin/tests/103-test-sticks-and-touch.c` — a down that is not a move, a
  still finger that is not a move, a pixel's slide that is, an up at the
  last place, a stale frame; through the map, each panel's down and up
  with its place, and both screens in one event each way.

Waiting for 101 and the device: the controllers' bring-up and per-frame
I2C reads, the missed-read warning and LED pattern.

## Related documents

- `docs/004-input-model.md`.

## Blocked by

101 (touch controller details), 501.

## Blocks

508.
