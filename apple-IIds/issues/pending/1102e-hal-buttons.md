---
name: HAL — buttons (d-pad, face, shoulder, Start, Select, volume, power)
phase: 11
status: pending
blockedBy: [1101]
parent: 1102
---

# 1102e — HAL: buttons

ARM-assembly driver for all the discrete buttons on the RG DS:
d-pad, four face buttons, two L's, two R's, two Start, two Select,
volume up/down, power.

## current behavior

Linux's GPIO / evdev subsystem handles the buttons. On bare metal,
raw GPIO reads.

## intended behavior

- Initialize all the GPIO pins the buttons are wired to.
- Sample on interrupt (button-press triggers IRQ) or poll
  (whichever the GPIO controller supports best).
- Debounce in software (typically a few ms hold-down required to
  register).
- Provide an event queue: `{button_id, state, timestamp}`.

## API surface

- `buttons_init`
- `buttons_poll() → events` (drain the event queue)
- (interrupt-driven event accumulation)

## suggested implementation steps

1. Identify each button's GPIO pin. Document in
   `docs/research/rgds-hardware/buttons.md` with a wire diagram.
2. Configure each pin's pull-up / pull-down and edge detection.
3. Implement the IRQ handler and event queue.
4. Implement debouncing.
5. Test: press each button, see the corresponding event.

## related documents

- `issues/1102-hardware-abstraction-layer.md` — parent issue
- `docs/002-hardware-target.md` — confirmed button layout

## notes

- Easy driver, modest scope. The volume and power buttons may
  route through a different path (PMIC) than the game-input
  buttons; document both.
