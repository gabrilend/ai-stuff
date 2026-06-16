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
