---
name: HAL — Hall-effect sleep switch
phase: 11
status: pending
blockedBy: [1101]
parent: 1102
---

# 1102g — HAL: Hall-effect sleep switch

ARM-assembly driver for the Hall-effect sensor that detects "lid
closed" (or the equivalent on the RG DS — exact form depends on
mechanical design).

## current behavior

Linux's GPIO subsystem handles the Hall switch. On bare metal,
direct read of the Hall sensor's GPIO.

## intended behavior

- Initialize the GPIO pin the Hall sensor is wired to.
- Configure edge detection (low → high = lid open, high → low =
  lid closed, or vice versa depending on the sensor's polarity).
- On state change, fire an interrupt that the broker (or, on bare
  metal, the kernel) catches and translates to a sleep / wake
  event.

## API surface

- `hall_init`
- `hall_read() → open_or_closed`
- (interrupt-driven; the IRQ handler invokes a callback)

## suggested implementation steps

1. Identify the Hall sensor's GPIO. Document.
2. Configure the GPIO with edge detection.
3. Install the IRQ handler.
4. Test: close and open the lid (or pass a magnet near the sensor);
   see state changes.

## related documents

- `issues/1102-hardware-abstraction-layer.md` — parent issue
- `issues/505-suspend-to-ram.md` — the sleep behavior driven by
  this signal

## notes

- Trivial driver, important consequence. The sleep-to-RAM
  semantics depend on this signal arriving promptly and reliably.
