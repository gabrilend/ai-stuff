# 106 — LED earliest-boot signal

## Current behavior

We have no way to observe what the kernel is doing from outside
the device. There is no screen yet (111a brings it up). There is
no USB debug yet (109 and 110 bring it up). When the kernel
misbehaves between reset and the moment USB device-mode comes up,
the device sits silent and we have nothing to look at.

## Intended behavior

The kernel drives the device's two LEDs (presumably one charging
indicator and one power indicator, possibly with different
colors — 101 confirms the details) to blink boot stages. Specific
patterns encode specific kernel states. A developer watching the
LEDs can tell, without any cable connected, roughly where the
kernel is in its boot sequence and whether it has hung.

A small table of patterns lives in
`notes/diagnostics/000-led-codes.md`. Indicative shapes (final
choices made during implementation):

- One LED on solid, the other off → boot code is running.
- One LED slow-blinking → memory layout is up.
- Both LEDs alternating → USB controller has initialized.
- Both LEDs in sync, fast-blinking → USB enumeration succeeded.
- One LED solid, the other fast-blinking → panic. The blink rate
  on the panicking LED encodes the exception type.

The point is not rich diagnostic information — the LEDs cannot
transmit a stack trace. The point is *the device has a voice
when it has nothing else.* Once USB CDC-ACM is up (110), most
detail goes through that; the LEDs remain the backstop for
situations where USB itself is what's broken.

## Suggested implementation steps

1. From 101's findings, identify the GPIO pins driving the two
   LEDs, their wiring direction (active high or active low), and
   their colors.
2. Write a small driver that turns each LED on, off, or to a
   blink pattern at a chosen rate.
3. Write the boot-stage table and a function the rest of the
   kernel calls to advance the stage indicator.
4. Wire 105's panic handler to set the panic-LED pattern before
   halting.
5. Document the codes in `notes/diagnostics/000-led-codes.md` so
   a developer with a manual can decode what their device is
   stuck on.

## Related documents

- `docs/002-roadmap.md` — phase 1.

## Blocked by

101 (LED GPIO mapping), 104.

## Blocks

105, 109.
