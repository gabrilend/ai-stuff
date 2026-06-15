# 101 — Hardware specification research

## Current behavior

We know the device is an Anbernic RG DS with two touch screens, an
ARM CPU, USB-C, WiFi, an SD card slot, a D-pad, ABXY, L/R, four
center buttons (`[start1][select1][select2][start2]`), and two
clickable analog sticks. We do not yet know the specific ARM chip,
the amount and layout of RAM, the display controller, the touch
controllers, the WiFi chip, the SD controller, the USB controller,
or the bootloader currently installed and how to replace its
payload. Without these answers, every later issue is blocked on
guesswork.

## Intended behavior

A research note lives at `docs/014-hardware-overview.md` enumerating:

- The exact ARM chip model, its core count, its clock speeds, and
  whether it has an MMU we can later turn on for protection mode.
- The total RAM and its physical address layout — where usable RAM
  starts, where it ends, and which regions are reserved for the GPU,
  the display controller, or other devices.
- The display controller chip and its register / framebuffer layout.
- The button GPIO mapping (which pin corresponds to which button).
- The touch panel controllers and how to talk to them (I2C address,
  protocol).
- The WiFi chip and whether it supports IBSS mode.
- The USB-C controller and whether it can expose a virtual ethernet
  adapter and a mass storage device simultaneously.
- The SD card controller.
- The existing bootloader on the device's SD card (Anbernic ships
  one of the standard handheld Linux variants — ArkOS, JELOS,
  Batocera, or similar; identify which).
- **The chip's built-in USB recovery mode**, which is our primary
  install path: which mode the chip has (FEL for Allwinner,
  Maskrom for Rockchip, USB Burning Tool for Amlogic, equivalents
  for MediaTek, UNISOC, or Actions Semi), which button is held
  during power-on to trigger it, and which laptop-side tool talks
  to it.
- **Whether the existing bootloader (u-boot or equivalent)
  supports flashing kernel images over USB without entering chip
  recovery mode at all** — for example, via `dfu-util` against a
  u-boot DFU configuration, or via `fastboot`. If yes, the
  developer's daily iteration loop becomes "plug in, flash" with
  no button-holding, and chip ROM recovery becomes only the
  bricked-device safety net rather than the everyday path.

Gaps that cannot be answered from public datasheets or
reverse-engineering work are listed explicitly as known unknowns so
later issues can plan around them.

## Suggested implementation steps

1. Open the device and identify visible chips on the board.
2. Search public datasheets for each chip identified.
3. Search for any community reverse-engineering work on the Anbernic
   RG DS or its siblings.
4. Write findings to `docs/014-hardware-overview.md`.
5. Where datasheets are missing, mark the gap explicitly.
6. Confirm the chip ROM recovery procedure works end to end by
   triggering it on the device and observing the laptop sees the
   chip in recovery mode (via the appropriate tool's "list
   devices" command). This is the install path for every
   subsequent phase 1 issue, so it must work reliably before any
   of them can start.

## Related documents

- `docs/001-architecture-overview.md`
- `docs/007-memory-model.md` — the RAM layout discovered here feeds
  directly into the flat memory model.

## Blocks

102, 104, 106, 107, 109, 111a, 113.
