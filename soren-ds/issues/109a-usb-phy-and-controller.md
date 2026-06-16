# 109a — USB PHY and controller register bring-up

## Current behavior

The RK3568's USB 3.0 OTG controller (a DesignWare DWC3) and the
USB 2.0 PHY behind it are sitting in whatever state Anbernic's
u-boot left them when it handed control to our kernel. Most
likely the controller is half-configured for host-mode use by
u-boot during its own boot sequence, the PHY clocks may or may
not be running, and the device's USB-C port is connected to
nothing the host laptop's kernel will recognize as a USB device.
Plugging in produces no `dmesg` output beyond the laptop's USB
hub registering electrical activity and giving up.

## Intended behavior

The kernel takes deliberate control of the USB controller and
its PHY, configures both, and brings the controller out of any
prior state into a clean DWC3 device-mode configuration. After
this issue closes:

- The USB 2.0 PHY at `0xFE8A_0000` has its clocks running and
  is in operational state. The combo PHY at `0xFE830000`
  remains untouched — phase 1 picks USB 2.0 speed, leaving the
  SuperSpeed lane for later.
- The DWC3 controller at the USB 3.0 OTG controller's MMIO
  base has been reset, configured for device-mode operation,
  and is responsive — a read-back of the DWC3 ID register
  returns the expected magic value, and a read-back of the
  DWC3 status register shows the controller in the expected
  state.
- On plug-in, the laptop's `dmesg` shows USB activity from the
  port: reset signals, link-up, possibly repeated "no response
  to enumeration" lines because the device side does not yet
  participate in the enumeration handshake. This is the
  expected closing evidence — the controller is *alive*, but
  enumeration is the next sub-issue's job.

LED-blink codes from 106 narrate progress through bring-up:
"PHY clocks enabled," "PHY out of reset," "DWC3 controller out
of reset," "DWC3 in device mode." When a step fails the LED
stays at the last successful stage, which the developer decodes
against the diagnostic-codes table to find where the bring-up
broke.

## Suggested implementation steps

1. From `docs/016-physical-memory-map.md`, write down the USB
   2.0 PHY base, the USB 3.0 OTG controller base, and the
   relevant CRU clock-control registers.
2. Enable the clocks for the USB 2.0 PHY and the USB 3.0 OTG
   controller through the CRU. Read the corresponding clock
   status registers back to confirm the clocks took.
3. Bring the USB 2.0 PHY out of reset through the PHY's own
   reset register or through the chip's GRF, following the
   sequence the RK3568 datasheet's USB chapter specifies. The
   timing requirements are documented; do not guess.
4. Bring the DWC3 controller out of reset through its
   `GCTL.CoreSoftReset` bit. Configure `GCTL.PrtCapDir` to
   device mode.
5. Read back the DWC3 ID register (`GSNPSID`) and confirm it
   matches the expected DWC3 magic value. Read the link state
   register and confirm the link is in the expected "disconnected"
   state until the cable is plugged in.
6. Test by plugging in and watching the laptop's `dmesg`.
   Expected outcome: USB activity is visible, the laptop
   notices a device, but enumeration fails (the next sub-issue
   makes enumeration succeed).

## Related documents

- `docs/016-physical-memory-map.md` — controller and PHY base
  addresses.
- `docs/006-transport-and-networking.md` — the broader USB
  story this is the foundation of.
- `docs/015-led-diagnostic-codes.md` — boot-stage encoding for
  the LED progress signals this issue adds.

## Blocked by

108 (the controller's data buffers come from the page
allocator), 106 (LED progress signals), 104 (boot path).

## Blocks

109b, 110.

## Parent

109.
