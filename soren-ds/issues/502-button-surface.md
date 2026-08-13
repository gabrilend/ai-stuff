# 502 — Button surface

## Current behavior

The polling map (501) has a `read-buttons` stub that returns
empty. The buttons on the device — D-pad (four directions),
ABXY, L1/R1/L2/R2, the four center buttons, the two stick clicks
— have GPIO wirings documented in 101 but no driver reads them.

## Intended behavior

The `read-buttons` box reads the raw state of every button-shaped
input. Output is a packed bitmap, one bit per button, in a
documented order. The reads happen as one batched GPIO snapshot
per frame so all buttons are sampled at the same instant.

Above `read-buttons` in the map, three event boxes process the
snapshot:

- **`button-down`** — compares the current snapshot to the
  previous frame's. For each button that transitioned from
  released to pressed, emits an event carrying the button's
  identity and the frame number.
- **`button-up`** — for each button that transitioned from
  pressed to released, emits an event carrying the button's
  identity, the frame number, and the total duration the button
  was held (in milliseconds, computed from frame deltas).
- **`button-held`** — for each button currently pressed, emits
  an event once per frame while the button is held. Optional
  per-button suppression (apps that don't care subscribe to a
  filtered version that emits only the buttons they listed).

The button event boxes are ordinary C functions taking the input
bitmap and the previous frame's state, and returning this frame's.

**The history cannot live inside the box.** Two cores can be inside one
box function at the same instant, so anything it kept would be shared
between them — the rule every box obeys, not a hazard particular to
these. The previous frame's state therefore travels on a wire: the box
returns it and an arrow carries it back around to its own input, which
is the engine's only mechanism for state and is exactly what it is for
(307).

The output of each event box is a small struct value (button id,
frame number, optional duration) that consumer maps in later
phases wire into their own input handling.

## Suggested implementation steps

1. `read_buttons_box()` — the GPIO snapshot. Bit order
   documented in `notes/diagnostics/000-led-codes.md`'s sibling
   `notes/diagnostics/001-button-bit-order.md`.
2. `button_down_box()`, `button_up_box()`, `button_held_box()`.
3. Per-button history struct (last-state byte, press-frame).
4. Wire the new boxes into the input-poll map from 501.

## Related documents

- `docs/004-input-model.md`.

## Blocked by

101 (button GPIO mapping), 501.

## Blocks

505 (chord detection consumes button events), 506, 508.
