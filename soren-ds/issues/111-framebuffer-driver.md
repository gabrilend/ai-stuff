# 111 — Framebuffer driver (parent / index)

The original sketch for the display path split into two sub-issues
(controller-and-bottom-screen, then top-screen-added). On reading
through the actual work involved, the display bring-up is closer
in surface area to all of the USB work combined: the VOP2 display
controller, the MIPI DSI controllers and PHYs that drive the
panels, the JD9365DA-H3 panel's own initialization sequence, and
the framebuffer allocation and scan-out configuration that tie
the lot together. Each of those is its own thing to debug, and
mashing them into two sub-issues makes failure modes hard to
attribute.

This parent index now splits into four sub-issues, each bounded
in scope and individually testable.

## Sub-issues

- `111a-vop2-controller-bringup.md` — bring up the RK3568's VOP2
  display controller: clocks out of reset, basic configuration
  registers, controller alive enough to read back its status.
  No panels yet, no framebuffer yet.
- `111b-dsi-bringup.md` — bring up the two MIPI DSI controllers
  (DSI0 for the bottom panel, DSI1 for the top) and their D-PHYs.
  Shared between the two panels because most of the per-DSI
  bring-up is identical and the controllers are independent
  instances of the same IP.
- `111c-panel-initialization.md` — send the JD9365DA-H3 panel
  initialization register sequence (the long table of DSI
  commands the panel datasheet specifies) to both panels.
- `111d-framebuffer-and-scanout.md` — allocate framebuffers from
  the page allocator, point the VOP2's two video outputs at them,
  and start scan-out. After this closes, both screens are
  actively scanning bytes from RAM and the demo in 112 has
  something to draw into.

## Why this split rather than the old two-issue split

The old split was "controller and bottom screen, then top
screen." That assumed the controller bring-up was the big piece
and adding the second panel was a small extension. In practice
the controller bring-up, the DSI bring-up, the panel init, and
the framebuffer wiring are four substantial pieces, and the
distinction between top and bottom mostly lives in the panel-init
and framebuffer-allocation layers — not in the controller-level
work.

The new split clusters work by "kind of bug you would debug." A
controller-bring-up bug looks very different from a DSI bug,
which looks very different from a panel-init bug. Each sub-
issue closes on its own evidence rather than on the cumulative
"a pixel showed up."

## Both screens at phase 1 close

Phase 1 still demonstrates the hardware, and the hardware still
has two screens. By the end of 111d both VOP2 output paths are
running and both panels are scanning. 112 confirms that an
explicit write to either framebuffer makes a visible pixel.

## Related documents

- `docs/005-display-and-compositor.md` — phase 6 (the compositor)
  is what eventually owns these framebuffers; phase 1's job is to
  get them lit so phase 6 can move in.

## Blocked by

101, 108.

## Blocks

112, 113, phase 6.
