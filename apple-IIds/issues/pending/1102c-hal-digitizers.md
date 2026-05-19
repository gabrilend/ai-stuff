---
name: HAL — digitizers (top + bottom)
phase: 11
status: pending
blockedBy: [1102b]
parent: 1102
---

# 1102c — HAL: digitizers

ARM-assembly driver for the two multi-touch capacitive digitizers
on the IPS panels, including stylus differentiation.

## current behavior

Linux's evdev / multi-touch input subsystem handles the digitizers.
On bare metal, raw reads from the touch controller.

## intended behavior

- Initialize both digitizer controllers (likely I2C-connected
  touch ICs).
- Receive interrupts when touches change.
- Decode touch points: position, contact ID, tool type
  (finger / stylus), pressure if reported.
- Provide an event queue for the input router.

## API surface

- `digitizer_init`
- `digitizer_poll(panel) → events`
- (interrupt-driven; the events queue is updated on IRQ)

## suggested implementation steps

1. Identify the touch controllers' I2C addresses and protocols.
   Read Linux's input driver source for guidance.
2. Document in `docs/research/rgds-hardware/digitizers.md`.
3. Implement I2C transactions on the RK3568 controller.
4. Implement the controller's command set for streaming touch
   events.
5. Set up the IRQ handler.
6. Decode multi-touch points + tool type.
7. Test: tap each panel, see events stream.

## related documents

- `issues/1102-hardware-abstraction-layer.md` — parent issue
- `issues/408-stylus-vs-finger.md` — tool-type API consumed
  upstream

## notes

- Tool-type differentiation is the unique-to-RG-DS capability.
  Make sure the driver exposes it cleanly so the input liberation
  work (phase 8) can use it on bare metal too.
