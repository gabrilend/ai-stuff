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

## Open questions

- *One event per button, or per frame?* "Emits an event carrying the
  button's identity" reads as one per button; a box returns one value
  per run.
- *How does an event box say "nothing happened"?*
- *What does a button event value hold?*
- *Is the filter for held only?*
- *What if two frames' snapshots arrive out of order?*
- *Where do events go before phase 6?*
- *What is the bit order?*
- *What does the device read before 101?*

### Proposed answers (UNVERIFIED)

Each one is a choice Ritz can overturn.

1. *One per frame*, carrying every button it is about as a bitmap.
   Buttons pressed in the same frame are exactly what the chord detector
   wants together (505), and a value per button would have to be put back
   together downstream.
2. *A comparator.* Each event box is placed as a comparator against an
   all-zero event, and events order by their buttons, so only a frame
   where something happened leaves by "above". No new kind, no box that
   chooses whether to return.
3. *Frame, buttons, and 16-bit milliseconds for each.* The durations
   were 64-bit until a comparator turned out to discard every value
   wider than 64 bytes (313); 65 535 ms (65.5 s) is the longest a
   duration says.
4. *All three take a listen mask* on a fixed port, so `button-down` and
   `button-up` can be filtered as `button-held` was asked to be; the
   input-poll map listens for all eighteen.
5. *The older one changes nothing.* The history knows its frame; a
   snapshot no newer than it is stale and gives no event, held included.
   Reading the buttons is beside the frame loop, so two cores can read
   neighbouring frames at once and finish in either order.
6. *The developer line.* `say_buttons` prints downs and ups (by name,
   with durations); nothing listens to held in the input-poll map,
   because sixty lines a second while a button is down is noise.
7. *D-pad, ABXY, triggers, the center row left to right, stick clicks*
   — `notes/diagnostics/001-button-bit-order.md`. The steps named
   `000-led-codes.md` as a sibling; that note does not exist, so the
   new one stands alone in `notes/diagnostics/`.
8. *Nothing pressed.* `input_buttons_now` is its own small seam (not
   025-platform.h, which three open PRs change): the twin's answers what a
   test set, the device's answers 0 until 101 names the pins.

## What happened

Built on the twin as answered above, on 501's input-poll map.

- `src/boxes/095-input.c` — `read_buttons` reads; `buttons_at_rest`
  and `button_track` keep the history on a loop (the frame each button
  went down rides the wire); `button_down`, `button_up`, `button_held`
  and `say_buttons`; `struct button_state` and `struct button_event`
  with its ordering.
- `src/system/096-input.h` — the bit order, `button_name`, and
  `input_buttons_now`; `src/device/098-input-device.c` and
  `twin/099-input-twin.c` answer it.
- `src/maps/input-poll.map` — the button stub replaced by the history
  loop and three comparators; downs and ups said, held unheard.
- `twin/tests/100-test-buttons.c` (26 checks): a press said once on its
  frame and its release once with its duration (three frames, 50 ms;
  sixty frames, 1000 ms); five buttons in one frame one event each way;
  bits that are not buttons no event; a map listening to held l1 and r1
  hears them every frame they are down and nothing else; a stale
  snapshot changing nothing; on the real timer, a button held for half a
  second read as 500 ms. `097` now counts the buttons by their history
  station.

Not done: the GPIO read itself (101).

## Related documents

- `docs/004-input-model.md`.

## Blocked by

101 (button GPIO mapping), 501.

## Blocks

505 (chord detection consumes button events), 506, 508.
