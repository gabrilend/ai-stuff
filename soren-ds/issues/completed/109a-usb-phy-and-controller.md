# 109a — USB PHY and controller register bring-up

## Current behavior

`src/009-usb.c` brings up the USB 2.0 PHY and the DWC3
controller in device mode. The PHY's suspend register in the
chip's general register file (`0xFDCA_0004`) is written with the
"normal operation" code through the Rockchip write-enable
convention; the DWC3 controller is soft-reset through bit 11 of
its global control register (`0xFEC0_C110`); the same register's
port-capability direction field is set to device mode; the
device configuration register is pinned to USB 2.0 high speed
so the controller does not advertise SuperSpeed against an
unconfigured SuperSpeed PHY; and the Synopsys identification
register at `0xFEC0_C120` is read back and verified to begin
with the documented `0x5533` magic ("U3" in ASCII).

`kernel_main` calls `usb_init` after the page allocator self-
test passes. On success the LED pattern advances to
`STAGE_USB_CONTROLLER` (green on, amber and red off) — a
deliberately different shape from `STAGE_KERNEL_MAIN` so the
developer can tell at a glance whether USB bring-up reached
this milestone. On failure (the identification register
mismatch case) the kernel falls into the generic panic LED
pattern.

The SuperSpeed (USB 3.0) PHY at the combo PHY's MMIO is left
untouched. The clocks for the USB 2.0 PHY and the DWC3
controller are assumed to be enabled by Anbernic's u-boot
before it hands off; if a future hardware run shows
clock-disabled symptoms the CRU register surface in
`docs/016-physical-memory-map.md` is where the next layer of
bring-up code goes.

The closing evidence — the laptop's `dmesg` showing raw USB
activity on plug-in — has not yet been observed on real
hardware because we have not yet booted from the device.
That validation happens when issue 110b puts our kernel on the
eMMC and we test the full chain end to end. If the laptop
sees nothing at that point the issue reopens.

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
