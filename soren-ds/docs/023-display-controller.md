# Soren DS — display controller reconnaissance (VOP2 / MIPI DSI)

Reconnaissance for the phase-1 display bring-up (issues 111a-d
and 112). This is **not** a full register reference — it names the
blocks, the handful of registers needed to get one framebuffer
scanning out to one panel, and the init-ordering constraints, so
the detailed bring-up issues start from a map rather than a blank
TRM. Source: RK3568 TRM Part 2, chapters 13 (VOP2), 29 (MIPI DSI
host), 30 (MIPI TX DPHY); device tree for the absolute bases.

Display bring-up touches **four** register blocks, not two: VOP2,
the DSI host, the MIPI TX DPHY, and a couple of GRF bits.

Base addresses (device tree):

- VOP2: `0xFE04_0000`
- MIPI DSI0 host: `0xFE06_0000`; DSI1 host: `0xFE07_0000`
- MIPI TX DPHY: **DPHY0 `0xFE85_0000`, DPHY1 `0xFE86_0000`**
  (device-tree `mipi-dphy@fe850000`/`@fe860000`, compatible
  `rockchip,rk3568-dsi-dphy`). Resolved from the board DTB
  2026-07-02 — the TRM did not state it. See the resolved-values
  section below.

The two screens are two independent panels (dsi0 → bottom via
VP0, dsi1 → top via VP1). The panel binds as `rocknix,generic-dsi`
and its **entire DCS init sequence, timings, lane count, and reset
GPIO are embedded in the board device tree** (the panel node's
`panel_description` strings) — so the vendor datasheet is not
needed. Decoded in the resolved-values section below.

## VOP2 (Chapter 13) — region map

VOP2 = 3 video ports (VP0/1/2) + layers (2 Cluster, 2 Esmart, 2
Smart) + an overlay mixer + 2 IOMMUs. Register regions (offset
from `0xFE040000`):

| Region | Offset | Role |
|--------|--------|------|
| System | `0x0000` | global ctrl, config-done, interface enable |
| Overlay | `0x0600` | layer→port routing, z-order |
| VP0 / VP1 / VP2 (post-process) | `0x0C00` / `0x0D00` / `0x0E00` | per-port timing + standby |
| Cluster0 / Cluster1 | `0x1000` / `0x1200` | full-featured layers (AFBC) |
| Esmart0 / Esmart1 | `0x1800` / `0x1A00` | scaling layers |
| Smart0 / Smart1 | `0x1C00` / `0x1E00` | simple layers |
| MMU0 / MMU1 | `0x3E00` / `0x3F00` | VOP IOMMU |

### Minimum path to scan one framebuffer

Using **Esmart0** (simplest RGB layer, base `0x1800`):

- `+0x10` `REGION0_MST_CTL` bit 0 = layer enable
- `+0x14` `REGION0_MST_YRGB` = **framebuffer base address**
- `+0x1C` `REGION0_VIR` = virtual width (stride)
- `+0x20` `ACT_INFO` (source W×H), `+0x24` `DSP_INFO` (displayed
  W×H), `+0x28` `DSP_OFFSET` (position)

Route the layer to a port (overlay, base `0x0600`):

- `+0x04` `VOP2_LAYER_SEL` (reset `0x00763210`) — z-order slots
- `+0x08` `VOP2_PORT_SEL` (reset `0x84000743`) — layer→port

Enable the port + its timing (VP0 = POST0, base `0x0C00`):

- `+0x00` `POST0_DSP_CTRL` — **bit 31 `standby`, resets to 1;
  write 0 to start scanout.** Holds `dsp_out_mode`.
- `+0x48`/`+0x4C` H total+HS / H active; `+0x50`/`+0x54` V
  total+VS / V active

Connect the port to the MIPI interface (system, base `0x0000`):

- `+0x28` `SYS_DSP_INFACE_EN` — bit 4 `mipi_out_en` (DSI0) +
  bits 17:16 source-VP mux; bit 20 `mipi1_out_en` (DSI1) + bits
  22:21 mux
- `+0x30` `SYS_DSP_INFACE_POL` — interface polarity

**Commit:** VOP2 registers are double-buffered. After all writes,
write `VOP2_SYS_REG_CFG_DONE` (`0x0000`) to latch at the next
frame boundary. (Exact per-VP commit bit: gap for 111a/111d.)

## MIPI DSI host (Chapter 29) — Synopsys DW MIPI DSI v1.31

Registers prefixed `MIPI_DSI_HOST_`, offset from the host base:

- `0x04` `PWR_UP` bit 0 `shutdownz` (0 = reset, 1 = power up)
- `0x08` `CLKMGR_CFG` escape/to-clock dividers
- `0xA0` `PHY_RSTZ` — bits: `phy_forcepll`(3), `phy_enableclk`(2),
  `phy_rstz`(1), `phy_shutdownz`(0) — release to bring DPHY up
- `0xA4` `PHY_IF_CFG` — **bits 1:0 `n_lanes`** (00=1…11=4, reset 3)
- `0xB0` `PHY_STATUS` — `phy_lock`, stopstate (poll before traffic)
- Panel DCS init: `0x68` `CMD_MODE_CFG` (LP/HS per cmd), `0x6C`
  `GEN_HDR` (write header → triggers TX), `0x70` `GEN_PLD_DATA`
  (long-packet payload), `0x74` `CMD_PKT_STATUS` (FIFO flags)
- **`0x34` `MODE_CFG` bit 0 `cmd_video_mode`: reset = 1 (command
  mode). Write 0 = video mode.** Init the panel in command mode,
  then switch to video.
- Video timing: `0x3C` `VID_PKT_SIZE`, `0x48`-`0x60`
  HSA/HBP/HLINE/VSA/VBP/VFP/VACTIVE
- `0x10` `DPI_COLOR_CODING`, `0x14` `DPI_CFG_POL` (DPI input from
  VOP2)

Note: RK3568 does **not** configure its DSI DPHY through the DW
test interface (`PHY_TST_CTRL0/1` absent); the analog DPHY is the
separate Chapter 30 block.

## MIPI TX DPHY (Chapter 30) — required, separate block

The DSI link clock (PLL) and physical lane enable live here, not
in the DSI host. Byte-wide registers:

- `0x00` `ANALOG_REG00` power + lane enable (reset `0x01`)
- `0x01` `ANALOG_REG01` PLL power (`0xE3`)
- `0x03`/`0x04`/`0x08` PLL prediv / fbdiv / post-div — set the HS
  bit clock
- `0x20` `DIGITAL_REG00` digital reset (`0x1F`)
- `0xE3` `LVDS_REG03` PHY mode select (MIPI vs LVDS)

**Caution:** Chapter 28 "MIPI CSI DPHY" is the camera RX PHY — do
not use it for display.

## Clocks and resets (names; bits via CRU research)

Not in TRM Part 2 — they live in the CRU (Part 1) and the device
tree. Conventional RK3568 names to confirm there when 111x is
picked up:

- VOP2: `ACLK_VOP`, `HCLK_VOP`, `DCLK_VP0/1/2`; resets
  `SRST_A_VOP`, `SRST_H_VOP`, `SRST_D_VOP0/1/2`.
- DSI hosts: `PCLK_DSITX0/1`; byte/escape clocks from the DPHY
  PLL; resets `SRST_P_DSITX0/1` plus the DPHY reset and ref clock.

## Init-ordering constraints the TRM flags

1. **DPHY before scanout.** Program the Ch30 PLL (prediv/fbdiv/
   post-div), enable lanes, release `PHY_RSTZ`, and wait for
   `PHY_STATUS` lock/stopstate before any video traffic.
2. **Panel init in command mode, then video.** `MODE_CFG.cmd_video_mode`
   starts at 1; send the JD9365DA-H3 DCS init via `GEN_HDR`/
   `GEN_PLD_DATA`, then write 0 to enter video mode.
3. **VOP standby gating.** `POST0_DSP_CTRL` bit 31 resets to
   standby=1; configure layers + timing, then clear it (TRM
   recommends a black display first).
4. **Shadow-register latch.** VOP2 changes don't take effect until
   `VOP2_SYS_REG_CFG_DONE` is written.
5. **Interface routing.** `SYS_DSP_INFACE_EN` must enable
   `mipi_out_en`/`mipi1_out_en` and select the source VP.
6. **Dual-screen GRF.** Two independent panels — confirm whether
   each runs single-link or dual-link and which GRF bits select
   that (gap for 111b/111c).

## Device-tree resolved values (board DTB, 2026-07-02)

Decoded from `libs/sd-image-parts/rk3568-anbernic-rg-ds.dtb`
(`dtc -I dtb -O dts`). These are re-derivable — re-run the decompile
rather than trusting the copy here if the board DTB changes.

**Topology.** VP0 → DSI0 (`0xFE060000`) → DPHY0 (`0xFE850000`) →
**bottom** panel. VP1 → DSI1 (`0xFE070000`) → DPHY1 (`0xFE860000`) →
**top** panel. Both DSI/DPHY pairs are identical IP at different
bases; one parameterized bring-up serves both.

**Panel (both screens), from the `panel_description` strings:**

- format **RGB888**, **4 data lanes**, DSI mode flags `0xc03`.
- **640×480**, pixel clock **42.134 MHz** (`clock=42134` kHz),
  horizontal `640,260,220,260`, vertical `480,10,2,16` (active +
  three porch/sync fields, ordering per the ROCKNIX `generic-dsi`
  parser — confirm field order there before trusting HS/porch math).
  ~60 Hz.
- reset/settle delays `20,10,50,120,50` ms; physical size 81×61 mm.
- **DCS init sequence** = the `I seq=RRVV` list: each is a
  single-parameter DCS write (register `0xRR`, value `0xVV`),
  opening with the JD9365 `E0/E1/E2/E3` page-unlock writes. ~200
  entries. The two panels' sequences are near-identical (a few
  per-panel values differ, e.g. register `0x37`). This is the whole
  of what 111c needs — no vendor datasheet.

**Reset GPIOs** (active-low, controller `gpio@fdd60000` = GPIO0):
bottom **GPIO0_B3** (pin 11), top **GPIO0_B4** (pin 12). Panel power
is `vdd-supply` + `iovcc-supply` regulators per panel.

**Backlight (resolved — no burn risk, safety S8 closed).**
`backlight0` (bottom) / `backlight1` (top) are `pwm-backlight`:
brightness on PWM channels **`0xFE700000`** (ch0) / **`0xFE700010`**
(ch1), 40 kHz, gated by enable lines on gpio4. Those are channels 0
and 1 of the **same PWM controller** whose channel 2 (`0xFE700020`)
is the rumble motor — one controller clock-ungate / reset / pin-mux
bring-up serves the two backlights and the rumble together. Crucially,
brightness is **PWM duty only**: the LED forward current is fixed in
hardware, so a `pwm-backlight` can dim but physically cannot
over-drive the LEDs. There is no software path to burn the backlight
and no rated current for us to enforce — this closes bricking
scenario S8 (`notes/safety/000-bricking-and-recovery.md`).

**Clocks / resets (CRU ids; gate/reset bit positions still TBD).**
VOP2: aclk `0xdd`, hclk `0xde`, dclk_vp0/1/2 `0xdf`/`0xe0`/`0xe1` —
gate `CLKGATE_CON20` (`0xFDD20350` bits 2..12) + reset
`SOFTRST_CON16` (`0xFDD20440` bits 0..8), both ON/released at boot
(already resolved by the `display-presence` probe). DSI0/1 pclk
`0xe8`/`0xe9`, apb reset `0x110`/`0x111`. DPHY0/1 ref + pclk
`0x17a`/`0x17b`, reset `0x1bb`/`0x1bc`. The gate/reset register+bit
for the DSI/DPHY ids are the remaining CRU-table lookup (gap below).

## Open gaps to resolve during 111x

- 111a/111d: exact `REG_CFG_DONE` per-VP commit bit; `dsp_out_mode`
  encoding for MIPI RGB888.
- 111x: confirm the ROCKNIX `generic-dsi` porch field ordering so the
  DSI HSA/HBP/HLINE/VSA/VBP/VFP timing is derived correctly. Needed only
  for VIDEO mode (end of 111c / 111d), not for the command-mode bring-up.
  Best determination so far (~70%): `active, front-porch, sync, back-porch`
  (sync is the middle of the three trailing numbers — the vertical `2` is a
  textbook 2-line vsync). Confirm against the ROCKNIX `panel-generic-dsi.c`
  parser when network access allows.

*(Resolved 2026-07-02, DPHY bases + panel data from the board DTB.)*

*(Resolved 2026-07-02 for 111b — see `src/022-mipi-dsi.c`: the CRU
gate/reset bits (TRM Part1: DSI-host `GATE_CON21` b6/7 + `SOFTRST_CON17`
b0/1; D-PHY `GATE_CON33` b14/15 + `SOFTRST_CON27` b11/12), the full D-PHY
MIPI-mode init sequence + PLL formula (TRM Part2 §30.3/§30.4), and the DSI
host command-mode sequence + `PHY_STATUS` lock/stopstate bits (TRM Part2
Ch29). No GRF write is needed — MIPI is the D-PHY's power-on default. Three
hardware-tunable residuals remain, flagged in the driver: the D-PHY word
stride `index<<2`, the exact PLL divider triple (~324 Mbps/lane target),
and the assumption that the VO-domain parent clocks are on at boot.)*

## Related documents

- `docs/datasheets/INDEX.md` — TRM Part 2 chapters 13/29/30.
- `docs/016-physical-memory-map.md` — VOP2/DSI base addresses.
- `docs/005-display-and-compositor.md` — the higher-level
  compositor design these drivers will eventually feed.
- `issues/111a-display-controller-and-bottom-screen.md` and
  siblings `111b`/`111c`/`111d`.
