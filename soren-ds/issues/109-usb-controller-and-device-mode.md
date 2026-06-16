# 109 — USB controller and device-mode bring-up (parent / index)

This issue is split into sub-issues because bringing up the USB
controller in device mode is the largest single piece of work in
phase 1, and the two halves of the work have genuinely different
shapes — silicon-level register dance vs protocol-level wire
choreography. Each sub-issue closes against its own evidence,
which means each is debugged against its own failure mode rather
than against a tangled mix.

## Sub-issues

- `109a-usb-phy-and-controller.md` — bring up the USB 2.0 PHY,
  bring the DWC3 controller out of reset and into device mode,
  read back enough status to confirm the controller is alive.
- `109b-usb-device-enumeration.md` — set up endpoint 0, define
  the descriptor tables, implement the control-transfer state
  machine that responds to the host's setup packets and address
  assignment.

## Why split this way

The first sub-issue closes when the laptop's `dmesg` shows raw
USB activity on plug-in — reset attempts, link-up, possibly
repeated "failed to enumerate" lines — even though the device
doesn't yet identify itself. The second sub-issue closes when
`lsusb` reports the device with our vendor ID, product ID, and
the `"Soren DS"` product string. Each evidence is observable
from outside the device and doesn't depend on the other
sub-issue being complete.

The boundary also matches the natural debugging mental model.
"The controller is not responding to the host at all" and "the
controller is responding but the host doesn't understand what
we're saying" are different bugs with different fixes; you
don't want to be debugging both at once.

## Why USB 2.0 and not USB 3.0

The RK3568's USB-C port is wired to a USB 3.0 OTG controller
(DesignWare DWC3), but phase 1 chooses USB 2.0 mode. The CDC-
ACM debug stream issue 110 brings up is far below USB 2.0's
12 Mbps full-speed cap, never mind the 480 Mbps high-speed
mode. USB 3.0 mode adds a SuperSpeed PHY (combophy1 / combophy2
in the memory map) with its own non-trivial bring-up sequence.
Skipping it removes work without removing capability.

If a later phase demands USB 3.0 speeds — large file transfers
over USB mass storage, perhaps — adding the SuperSpeed PHY is a
separate task that layers on top of what 109a brings up, not a
rework of it.

## Related documents

- `docs/006-transport-and-networking.md` — what later phases
  layer on top of the USB device-mode plumbing this issue
  produces.
- `docs/016-physical-memory-map.md` — USB controller and PHY
  register base addresses live here.

## Blocked by

101 (USB controller and PHY details), 104 (boot path), 106
(LED for diagnostics during bring-up), 108 (controller buffers
need to come from the page allocator).

## Blocks

110, 113, phase 7 (USB transport).
