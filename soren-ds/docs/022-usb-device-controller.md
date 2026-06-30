# Soren DS — USB device controller and USB2 PHY

This document captures what the RK3568 TRM and the phase-1
register probes tell us about bringing up USB in device mode —
the work split across issues 109a (PHY + controller), 109b
(enumeration), and 109c (control transfers), feeding the CDC-ACM
debug channel (110). The controller is a Synopsys DWC3 (USB 3.0
OTG); the USB 2.0 side runs through a Rockchip Innosilicon USB2
PHY whose control registers live in a GRF syscon.

Base addresses (from `docs/016-physical-memory-map.md` and the
device tree):

- DWC3 USB 3.0 OTG controller: `0xFCC0_0000`
- USB2 PHY 0 GRF (`USBPHY_U3_GRF`): `0xFDCA_0000`
- USB2 PHY 1 GRF (`USBPHY_U2_GRF`): `0xFDCA_8000`

## What the bootloader leaves us, and what 109a must do

On the SD-boot path the bootloader does not bring up USB. Three
pieces of setup are required before the DWC3 register dance in
`usb_init` can succeed (catalogued in
`docs/017-clocks-and-timers.md`):

1. **Ungate the USB3 OTG controller clocks** — `CLKGATE_CON(10)`
   (`0xFDD20328`) bits 8/9/10 (`ACLK_USB3OTG0`,
   `CLK_USB3OTG0_REF`, `CLK_USB3OTG0_SUSPEND`). One masked write
   of `0x07000000`.
2. **Deassert the USB3 OTG controller reset** —
   `SOFTRST_CON(9)` (`0xFDD20424`) bit 4 (`SRST_USB3OTG0`).
3. **Bring the USB2 PHY out of power-on reset** — the PHY's analog
   power-down is controlled by the CRU's `resetn_usb2phy0_por`
   reset, *not* by the GRF (see the next section). This is the
   piece the original 109a reopen flagged as "needs research."

## USB2 PHY GRF (`USBPHY_U3_GRF`, `0xFDCA_0000`)

This syscon is the `rockchip,rk3568-usb2phy-grf`. It has two port
control registers — `CON0` is the **OTG** port (our device-mode
port), `CON1` is the companion **HOST** port of the same dual-role
PHY.

### `CON0` (offset `0x00`) — OTG port. Reset value `0x0C52`.

| Bit | Field | Meaning |
|-----|-------|---------|
| 0 | `utmi_sel` | 0 = OTG controller drives UTMI (default); 1 = GRF static fields override the PHY |
| 1 | `utmi_suspend_n` | **0 = suspend, 1 = normal** |
| 3:2 | `utmi_opmode` | 0 = normal |
| 5:4 | `utmi_xcvrselect` | FS/LS/HS transceiver select |
| 6 | `utmi_termselect` | termination select |
| 8:7 | `utmi_dppulldown`/`dmpulldown` | host-side DP/DM pulldowns |
| 9 | `utmi_iddig_sel` | iddig source: 0 = PHY, 1 = GRF |
| 11:10 | `utmi_iddig`/`idpullup` | OTG plug-ID |
| 31:16 | write-enable mask | per-bit mask for `[15:0]` |

**Key finding from the phase-1 probe:** `CON0` reads its reset
value `0x0C52`, which decodes to `utmi_sel = 0` (controller-driven)
and `utmi_suspend_n = 1` (**normal, not suspended**). So the OTG
PHY is *already* out of GRF-forced suspend at reset — 109a does
**not** need to clear a "PHY power-down" bit here. The Rockchip
driver only writes this register to *force* suspend (it writes
`CON0[8:0] = 0x1D1`) and to resume (writes `0x000`, clearing
`utmi_sel` to hand control back to the controller). Our resume
state is the default; leave `CON0` alone.

### `CON2` (offset `0x08`) — shared PHY analog

| Bit | Field | Meaning |
|-----|-------|---------|
| 1:0 | `usbotg_disable_0/1` | "bypass OTG function" — leave 0 |
| 4 | `usbphy_commononn` | 0 = 480 MHz PLL always on; 1 = PLL off when both ports suspend |

There is **no dedicated OTG analog power-down bit** in this GRF.
The real PHY power-down/up is the CRU `resetn_usb2phy0_por`
power-on reset (TRM Part 1 Ch2). To bring the PHY fully live:
ensure its POR reset is deasserted via the CRU, and leave `CON0`
at its (already-normal) reset value.

### Red herrings

`LS_CON` (`0x40`) and `DIS_CON` (`0x44`) both read `0x00030100` —
these are the line-state and host-disconnect **debounce timers**,
not power control. The phase-1 probe captured them; they are not
relevant to device-mode bring-up.

`CON1` (`0x04`) read `0x01D1` in the probe — the unused HOST half
of the PHY parked in suspend by software. Not our concern for
device mode.

## The 109b endpoint-command hang

109b is reopened because `depcmd_issue`'s polling loop hangs on
the first DWC3 endpoint command. The leading hypothesis (in the
issue) is that the controller's RUN/STOP bit in `DCTL` must be set
before endpoint commands are processed, or the event-buffer setup
is incomplete. The DWC3 register details are in **TRM Part 2
Chapter 17 (USB3.0 Controller)** — the `DCTL`, `DEPCMD`, `GEVNTADR`
event-buffer registers and the documented power-on / run sequence
are the place to resolve this. This document will be extended with
the specific register offsets when 109b is picked up.

## Related documents

- `docs/016-physical-memory-map.md` — USB controller and PHY GRF
  base addresses.
- `docs/017-clocks-and-timers.md` — USB3 OTG clock gates and
  reset.
- `docs/datasheets/INDEX.md` — TRM Part 2 Ch17 (USB3.0
  controller), Ch16 (USB2.0 host).
- `issues/109a-usb-phy-and-controller.md`,
  `issues/109b-usb-device-enumeration.md`.
