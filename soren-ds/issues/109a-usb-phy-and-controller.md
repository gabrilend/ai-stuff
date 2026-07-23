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
untouched.

The clocks for the USB 2.0 PHY and the DWC3 controller were
assumed to be enabled by the bootloader before its handoff.
The mainline-derived ROCKNIX u-boot on the SD-card development
boot path does **not** enable these clocks — its defconfig
does not include the DWC3 driver and so does not pre-enable
anything USB-related. Anbernic's u-boot on eMMC may or may
not; this is unverified. Until the clocks are enabled by the
kernel itself, the writes the rest of this code performs to
the DWC3 register window land on a peripheral that is not
running, and either silently fail or stall the bus enough to
trigger an exception that the bootloader's installed handler
treats as a reset condition.

This is the bring-up gap surfaced during the phase-1 hardware-
test investigation. The datasheet pass
(`docs/022-usb-device-controller.md`) refined what's actually
required. Two CRU writes are still needed in `usb_init`: ungate
the USB 3.0 OTG controller's clocks (`CLKGATE_CON(10)`
= `0xFDD20328`, bits 8/9/10) and deassert its reset
(`SOFTRST_CON(9)` = `0xFDD20424`, bit 4) — both catalogued in
`docs/017-clocks-and-timers.md`.

The "clear the USB 2.0 PHY power-down bits" step turned out to
be **mostly a non-issue**: the USB2 PHY's OTG-port control
register (`USBPHY_U3_GRF_CON0` at `0xFDCA0000`) reads its reset
value `0x0C52` on our boot path, which already decodes to
"controller-driven, not suspended." There is no dedicated
power-down bit in that GRF to clear; the PHY's real analog
power-up is the CRU's `resetn_usb2phy0_por` reset. So the PHY
arrives essentially ready, and the remaining work is the two CRU
writes plus the DWC3 register sequence. Full decode in
`docs/022-usb-device-controller.md`.

The closing evidence — the laptop's `dmesg` showing raw USB
activity on plug-in — has not yet been observed on real
hardware because we have not yet booted from the device far
enough for USB to be reachable. That validation happens after
the clock-enable writes land and the bring-up sequence runs
end to end.

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

1. From `docs/016-physical-memory-map.md` and
   `docs/017-clocks-and-timers.md`, write down the USB 2.0
   PHY base, the USB 3.0 OTG controller base, the three USB
   3.0 OTG clock-gate bits in `CLKGATE_CON(10)` at
   `0xFDD2_0328` (bits 8, 9, 10 for `ACLK`, `CLK_REF`,
   `CLK_SUSPEND`), the USB 3.0 OTG soft-reset bit in
   `SOFTRST_CON(9)` at `0xFDD2_0424` (bit 4), and the USB
   2.0 PHY power-down register in the PMU GRF.
2. At the top of `usb_init`, ungate the three USB 3.0 OTG
   clocks by writing the single masked word `0x07000000` to
   `0xFDD2_0328`. Mask half names bits 8, 9, 10 in the lower
   half; value half is zero, which clears the gate bits (a
   gate-bit value of zero means ungated). Read the
   register back to confirm the clocks took.
3. Assert and then deassert the USB 3.0 OTG soft-reset.
   Assert by writing `(1u << (4+16)) | (1u << 4) = 0x00100010`
   to `0xFDD2_0424`; deassert by writing `(1u << (4+16)) =
   0x00100000` to the same register. The controller is now
   in its post-reset state with its clocks ticking, ready
   to be configured.
4. Clear the USB 2.0 PHY's power-down bits in the PMU GRF
   so the PHY's analog and digital sections come online.
   The specific register offset and bit positions for the
   PHY power-down clear are not yet researched — the agent's
   research surfaced this as a step but not the exact bits.
   This is the remaining research the implementation needs
   to do; the relevant source is `drivers/phy/rockchip/
   phy-rockchip-inno-usb2.c` in the upstream Linux tree, the
   `rk3568_phy_cfgs` table.
5. Bring the USB 2.0 PHY into operational state through its
   suspend register in the GRF (the existing code in
   `src/009-usb.c` already does this — keep it, just gate it
   behind the power-down clear from step 4).
6. Bring the DWC3 controller out of soft reset through its
   `GCTL.CoreSoftReset` bit. Configure `GCTL.PrtCapDir` to
   device mode. (Existing code keeps doing this; just runs
   after the clock and PHY work from steps 2-5.)
7. Read back the DWC3 ID register (`GSNPSID`) and confirm it
   matches the expected DWC3 magic value (`0x5533` in the
   upper 16 bits — the ASCII "U3" Synopsys publishes for
   the IP). Read the link state register and confirm the
   link is in the expected "disconnected" state until the
   cable is plugged in.
8. Test by plugging in and watching the laptop's `dmesg`.
   Expected outcome: USB activity is visible, the laptop
   notices a device, but enumeration fails (the next
   sub-issue makes enumeration succeed).

## Related documents

- `docs/016-physical-memory-map.md` — controller and PHY base
  addresses.
- `docs/017-clocks-and-timers.md` — the CRU clock-gate and
  soft-reset register layout for the USB 3.0 OTG controller,
  and the broader catalogue of the chip's clocking and reset
  infrastructure.
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
