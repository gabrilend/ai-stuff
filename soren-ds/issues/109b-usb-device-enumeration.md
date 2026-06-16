# 109b — USB descriptors, dispatcher, and endpoint-zero configuration

## Current behavior

`src/010-usb-enumeration.c` defines the descriptor tables the
USB host expects to read during enumeration:

- A device descriptor declaring USB version 2.0, vendor ID
  `0x1209` (the pid.codes open-hardware development pool),
  product ID `0x5050`, and string indices for manufacturer,
  product, and serial number.
- A configuration descriptor with one configuration, one
  interface, and the interface's class set to `0xFF` (vendor-
  defined). 110 layers CDC-ACM-specific descriptors on top of
  this surface; 109b establishes only the vendor-class
  minimum.
- String descriptors at indices 0 through 3: the language ID
  table (en-US), "Soren DS Project" as the manufacturer string,
  "Soren DS" as the product string, and a fixed-placeholder
  serial number string. Each is UTF-16 little-endian per spec.

A setup-packet dispatcher maps each standard USB control
request to a response:

- `GET_DESCRIPTOR(Device)` returns the device descriptor.
- `GET_DESCRIPTOR(Configuration)` returns the configuration
  descriptor.
- `GET_DESCRIPTOR(String, N)` returns string descriptor N.
- `SET_ADDRESS(N)` marks the address as pending; the polling
  loop in 109c applies it after the status stage.
- `SET_CONFIGURATION(1)` acknowledges the single configuration
  selection.

Endpoint zero is configured through the DWC3 controller's
DEPCMD interface. `usb_endpoint_zero_bringup` allocates an
event buffer from the page allocator, points the controller at
it through the GEVNTADRLO/GEVNTADRHI/GEVNTSIZ registers, issues
the DEPSTARTCFG / DEPCFG / DEPXFERCFG sequence for both
directions of endpoint zero, enables the endpoints in
DALEPENA, and sets the controller's RUN bit.

## Reopened — DEPSTARTCFG hangs on real hardware

Phase-1 hardware testing (after the controller's MMIO base
address was corrected to the actual `0xFCC0_0000`) found the
controller acknowledging its identification register read
correctly — `usb_init` returns success, the LED stage signal
advances to `STAGE_USB_CONTROLLER` — and then the very first
DWC3 endpoint command issued from inside
`usb_endpoint_zero_bringup` never completes. `depcmd_issue`'s
polling loop reads the `DEPCMD` register's `CMDACT` bit and
spins waiting for the controller to clear it. The controller
never does; the kernel sits in the spin forever.

Likely causes, roughly in order of probability:

- The controller's `RUN/STOP` bit in `DCTL` has not been set
  before the first endpoint command. The DWC3 driver flow
  in the upstream Linux kernel sets it as the last step of
  controller bring-up; our current `usb_endpoint_zero_bringup`
  sets it at its own end (after configuring endpoint zero) but
  the controller may need it set *before* it will accept
  endpoint commands.
- The event buffer setup writes correct values but the
  controller is not actually reading them — possibly because
  the event ring's interrupt is being masked off, or because
  the event ring needs a specific initial state we are not
  setting.
- The DEPSTARTCFG command parameters (`par0`/`par1`/`par2`)
  encode something the controller rejects silently — for
  example, the resource index in `par1` may need to match a
  specific layout the upstream code computes from the endpoint
  number.

`kernel_main`'s call to `usb_endpoint_zero_bringup` is removed
for now (the comment in `src/002-main.c` explains the deferral)
so phase 1's downstream eMMC-to-SD backup work can land. The
`debug_write` function in `src/011-cdc-acm.c` gracefully
short-circuits to its SD-log fan-out when `cdc_acm_init` has
not run, so the kernel's text-side diagnostic narration still
reaches the developer through the SD card.

This issue closes when the controller accepts and acknowledges
the first DEPSTARTCFG command. Until then the CDC-ACM debug
stream (issue 110) is not available; phase 1 ships its
diagnostic through the SD-backed log alone.

After this issue closes the controller is configured, the
descriptors are in place, and the dispatcher knows what to say
for every request the host will ask. What it cannot yet do is
*deliver* a response — the runtime transfer machinery (TRB
rings, the setup-packet buffer, and the event-ring decoder)
lives in 109c.

## Why this scope and not the full enumeration

The original sketch for 109b included the polling loop that
parses controller events and posts response transfers, but
that machinery turned out to be substantial enough — a TRB
struct, two rings, a setup buffer, and an event-decoding state
machine — to deserve its own issue. Splitting it out keeps
each piece small enough to debug as a unit when we eventually
exercise this on hardware.

## Closing evidence

The kernel builds with the descriptor tables compiled into
`.rodata`, the DWC3 endpoint-zero configuration sequence
issues without spinning forever on a CMDACT bit, and the
controller's RUN bit is set. The LED stage advances to
`STAGE_USB_CONTROLLER` per 109a's pattern; from the LEDs
alone there is no observable difference between "controller
alive but endpoint 0 not yet configured" and "controller
alive and endpoint 0 configured," because both are stable
healthy states. The difference is in the host's `dmesg` once
the device is plugged in: 109a's level produces electrical
activity only, while 109b's level lets the bus reset complete
without protocol errors even though enumeration still hangs.

## Why descriptors live in `.rodata` rather than allocated

The descriptor tables are read-only data the host requests
during enumeration. They never change at runtime. Storing them
as `const` arrays in `.rodata` is simpler than allocating them
at boot and avoids one more thing that has to succeed before
USB works. The allocator is still used for the event buffer
and (in 109c) the TRB rings and setup-packet buffer, where
bytes flow in from the host and the controller wants DMA-
addressable memory.

## Related documents

- `docs/006-transport-and-networking.md` — what later phases
  build on this.
- `docs/015-led-diagnostic-codes.md` — LED progress signals.

## Blocked by

109a, 108.

## Blocks

109c.

## Parent

109.
