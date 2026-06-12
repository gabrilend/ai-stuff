# 701 — WiFi controller bring-up

## Current behavior

The chip has a WiFi controller (101 documents which) that has
not been initialized. The radio is off; the device cannot send
or receive any packets.

## Intended behavior

The kernel brings the WiFi controller up to a known good state.
Specifically:

- The controller's clock source is selected and enabled.
- The controller's power-on sequence runs (the long table of
  register writes from the chip's datasheet).
- The MAC address is configured. We use a stable, per-device
  MAC derived from the chip's serial number or an OTP fuse
  read; this gives the device a consistent identity across
  reboots without our writing fuses (the safety doc forbids
  that).
- The controller's interrupt is hooked into the kernel's
  interrupt handler from 105, with the WiFi-specific dispatch
  routing the controller's events into the WiFi driver's box
  queue.
- The controller is left in a powered-on but not-yet-associated
  state, ready for 702 to push it into IBSS mode.

Diagnostic output through CDC-ACM reports the MAC, the
controller's reported chip ID, and the firmware version (if any)
loaded from disk for chips that need it.

## Suggested implementation steps

1. `wifi_controller_init()` — clocks, power, the init sequence.
2. `wifi_mac_derive()` — read OTP, hash, format as a 48-bit
   address.
3. `wifi_interrupt_dispatch()` — route the controller's IRQ to
   the WiFi driver's box queue.
4. Bring-up report through `debug_write`.

## Related documents

- `docs/006-transport-and-networking.md`.

## Blocked by

101, 105, 108.

## Blocks

702, every later phase 7 radio issue.
