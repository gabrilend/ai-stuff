---
name: HAL — panels (top + bottom)
phase: 11
status: pending
blockedBy: [1101]
parent: 1102
---

# 1102b — HAL: panels

ARM-assembly driver for the two 640×480 IPS panels. Initializes the
panels, pushes framebuffer data, handles DPMS (sleep / wake).

## current behavior

Linux's DRM/KMS subsystem handles the panels. On bare metal, the
panels need their own driver.

## intended behavior

- Initialize both panels at power-on.
- Allocate two framebuffers (one per panel) at known physical
  addresses.
- Push framebuffer data via the SoC's display controller.
- Power management: panels off on sleep, on on wake.
- Frame-pacing: pageflip on vblank; broker / Apple IIds code can
  request a flip-on-next-vblank.

## API surface

- `panel_init` — initialize both panels and their controllers.
- `panel_set_framebuffer(panel, addr)` — set the framebuffer
  address for one panel.
- `panel_flip(panel)` — request a vblank-aligned flip to the
  current framebuffer (for double-buffering, if used).
- `panel_set_power(panel, on)` — DPMS-like power state.

## suggested implementation steps

1. Read Linux's display driver source for the RG DS's panel
   controller (likely an RK3568-integrated display engine).
2. Document the register map and the panel initialization sequence
   in `docs/research/rgds-hardware/panels.md`.
3. Implement `panel_init` — power-up sequence, panel-specific
   commands (the IPS panels have setup magic), pixel-clock
   configuration, sync signals.
4. Allocate the framebuffer regions in RAM.
5. Set up the DMA path from framebuffer to panel.
6. Implement vblank detection (likely an IRQ from the display
   controller).
7. Test: blink each panel a known color.

## related documents

- `issues/1102-hardware-abstraction-layer.md` — parent issue
- `docs/002-hardware-target.md` — panel specs

## notes

- Panels are the most-visible HAL driver. Once it works, "the
  bare-metal device shows a thing" becomes possible.
