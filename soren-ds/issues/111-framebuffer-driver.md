# 111 — Framebuffer driver (parent / index)

This issue is split into sub-issues because bringing up the display
hardware is the largest single piece of display work in phase 1.
(The largest piece of overall phase 1 work is 109, the USB
controller bring-up.)

## Sub-issues

- `111a-display-controller-and-bottom-screen.md` — bring up the
  shared display controller and configure its first output to
  scan out the bottom screen.
- `111b-top-screen-output.md` — add the top screen's output path
  to the already-configured controller.

## Why split this way

Both screens share a single display controller (per 101's
findings). The bulk of the work — clocks, power, register
initialization sequence, framebuffer memory allocation, scan-out
configuration — is done once, in 111a, and lights up the bottom
screen. The top screen reuses the already-running controller and
needs only its own framebuffer and output-path configuration; that
smaller piece becomes 111b.

Both sub-issues are required to close phase 1. Phase 1
demonstrates the hardware, and the hardware has two screens, so
both outputs are on by the time the demo runs.

## Related documents

- `docs/005-display-and-compositor.md` — phase 6 builds on top of
  both sub-issues.

## Blocked by

101, 108.

## Blocks

112 (via both — the demo lights a pixel on each screen), 113,
phase 6.
