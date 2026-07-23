# 111b — MIPI DSI controller and PHY bring-up

## Current behavior

After 111a the VOP2 controller is alive. But VOP2 produces
parallel pixel streams; the actual electrical signal that goes
to each panel is a MIPI DSI (Display Serial Interface) data
stream. The RK3568 has two MIPI DSI controllers (DSI0 and DSI1)
each fronted by a MIPI D-PHY that does the electrical encoding.

**Implemented (2026-07-02) in `src/022-mipi-dsi.c`.** `mipi_dsi_init()`
brings both controllers + D-PHYs up to command mode with the PLL locked,
parameterized on the instance and run twice (DSI0/D-PHY0 → bottom via VP0,
DSI1/D-PHY1 → top via VP1). All register values were derived from the
RK3568 TRM (the local PDFs, extracted with ghostscript, since there is no
network here to pull the Linux drivers): the CRU clock-gate/reset bits
(Part 1), the D-PHY register map + MIPI init sequence + PLL formula
(Part 2 Ch30), and the DSI-host command-mode sequence + PHY_STATUS
lock/stopstate bits (Part 2 Ch29). Three residuals are flagged in the
driver for a hardware run to confirm: the D-PHY register stride
(`index<<2`), the exact PLL divider triple (targeting ~324 Mbps/lane),
and the assumption that the VO-domain parent clocks are on at boot. The
function is written and compile-verified but not yet wired into boot — the
display path is wired in as a whole once panel init (111c) and scanout
(111d) land. Not yet done: everything downstream (panel wake-up, video
mode, framebuffers).

## Intended behavior

Both MIPI DSI controllers and their D-PHYs are brought up to a
state where the controllers can accept pixel data from VOP2 and
can also send command packets to the panels for the
initialization sequence in 111c.

Concretely:

- The two DSI controllers' source clocks come up through the
  CRU. The D-PHYs' separate reference clocks come up.
- Both D-PHYs are taken out of reset through the chip's general
  register file (the same write-enable convention the USB 2.0
  PHY uses — Rockchip's PHY control bits live in the GRF rather
  than in the PHY's own MMIO). The PHYs go through their power-
  up sequence — PLL lock, lane configuration, escape mode for
  command transmission.
- The DSI controllers are configured with the panel timing
  parameters (pixel clock, horizontal/vertical front and back
  porch, sync widths) the JD9365DA-H3 panel datasheet specifies.
  Both panels are identical, so both DSI controllers use the
  same timing values.
- Both controllers are placed into the "command mode" needed
  for the panel initialization sequence. 111c switches them to
  "video mode" after panel init completes.
- Bring-up status flows through the CDC-ACM debug stream.

After this issue closes the DSI controllers and PHYs are
electrically alive, but the panels have not yet been told to
turn on or display anything. That waits on 111c.

## Why one issue for both controllers rather than one each

DSI0 and DSI1 are two instances of the same IP at different
register bases. The bring-up sequence is identical except for
the base address — there is no meaningful "DSI0 succeeded but
DSI1 needs different work" scenario. Splitting would mean
duplicating the same sub-issue with a base-address change. One
sub-issue with a function parameterized on the controller
instance is cleaner.

## Suggested implementation steps

1. Pull DSI controller register layout from upstream Linux
   (`drivers/gpu/drm/rockchip/dw-mipi-dsi-rockchip.c`).
2. Pull D-PHY register layout from upstream Linux
   (`drivers/phy/rockchip/phy-rockchip-inno-mipi-dphy.c` or the
   D-PHY driver paired with the DSI driver for RK3568).
3. From the JD9365DA-H3 datasheet, find the panel's timing
   parameters — pixel clock, horizontal/vertical front-porch
   and back-porch, sync widths.
4. Implement a bring-up function parameterized on `(controller_base,
   phy_base)`. Call it twice — once for each panel's controller.
5. Narrate each step (clock enabled, PHY out of reset, PLL
   locked, controller in command mode) through CDC-ACM.

## Related documents

- `docs/016-physical-memory-map.md` — DSI controller and D-PHY
  base addresses.
- `docs/014-hardware-overview.md` — panel part identification
  (Jadard JD9365DA-H3) and panel reset GPIOs.

## Blocked by

111a, 110.

## Blocks

111c, 111d.

## Parent

111.
