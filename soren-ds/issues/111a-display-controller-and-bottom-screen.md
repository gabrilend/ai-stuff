# 111a — VOP2 display controller bring-up

## Current behavior

The RK3568's VOP2 — Video Output Processor v2 — is sitting in
whatever state Anbernic's u-boot left it in. The controller may
or may not be clocked, its registers may or may not be in a
known state, and even if it is configured, our kernel has no
way to know what for. The downstream display path — MIPI DSI,
panel init, framebuffer — depends on a known-good controller
state to build on top of.

**Confirmed by recon (2026-07-02).** VOP2 is at **`0xFE040000`**
(not the stale `0xFEA00000` this issue first wrote), and it is
**alive**: its version register (`0xFE040004`) reads `0x40158023`.
Its clocks (`CLKGATE_CON20` @ `0xFDD20350`, bits 2..12) and resets
(`SOFTRST_CON16` @ `0xFDD20440`, bits 0..8) both reset to
ON / released at power-on, so a clean boot arrives with the block
already clocked — the `display-presence` probe demonstrated all of
this. So this bring-up starts from proven-reachable, not unknown.

## Intended behavior

The VOP2 controller is brought up to a known state from which
the rest of the display work proceeds. Concretely:

- The controller's source clocks (the AHB clock for its register
  interface and the pixel clock for its output) are enabled
  through the CRU, with verification by reading the corresponding
  clock-status registers.
- The controller comes out of any prior reset state through its
  reset register.
- The controller's two video output ports (VP0 and VP1 — the
  ones that drive the two MIPI DSI lanes) are reset to a known
  configuration with their output paths disabled. Issue 111d
  enables them when framebuffers are ready.
- A read-back of a controller register (the version register or
  a status flag) confirms the controller is responding.
- Bring-up status is narrated through the CDC-ACM debug stream
  from 110.

After this issue closes the controller is alive but quiet —
nothing is being scanned anywhere yet, because the DSI lanes
beneath the controller are not up and no framebuffers exist.

## What is deliberately not in scope here

- DSI controller bring-up (111b).
- Panel initialization commands (111c).
- Framebuffer allocation, scan-out configuration, and pixel
  delivery (111d).

This issue is the very bottom of the display stack: the VOP2
itself, clocked and addressable. Everything above it builds on
this layer.

## Suggested implementation steps

1. From `docs/016-physical-memory-map.md`, write down the VOP2
   register base (`0xFEA00000`), the CRU register base, and the
   relevant CRU clock-control bits for the VOP2's source clocks.
2. Enable the source clocks through the CRU. Read back the
   clock-status registers to confirm they took.
3. Bring the controller out of reset through its reset register.
4. Read back the controller's version or status register and
   verify it returns a non-default value (confirming the
   register interface is alive).
5. Narrate each step through CDC-ACM so a real-hardware run
   shows which step failed when bring-up fails.

## Related documents

- `docs/005-display-and-compositor.md` — phase 6 needs the
  framebuffers this issue's downstream issues produce.
- `docs/016-physical-memory-map.md` — VOP2 register base.

## Blocked by

108 (clock setup may want page-allocator-backed scratch
buffers), 110 (CDC-ACM for bring-up narration).

## Blocks

111b, 111c, 111d.

## Parent

111.
