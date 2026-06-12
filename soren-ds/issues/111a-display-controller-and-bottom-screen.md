# 111a — Display controller and bottom screen

## Current behavior

The kernel has memory, an LED boot-stage signal, a USB CDC-ACM
debug stream, and a panic handler, but cannot drive pixels onto
either screen. The shared display controller identified in 101 has
not been programmed. The controller's clocks are not running. No
framebuffer memory has been allocated. No output path is
configured.

## Intended behavior

The display controller is brought up to a known good state and the
bottom screen is being actively scanned out from a framebuffer in
RAM. Specifically:

- The controller's clock source is selected and enabled. The
  controller's power gate, if any, is opened.
- The controller's initialization sequence — the long table of
  register writes from its datasheet — is executed in order, with
  the timings the datasheet requires.
- A framebuffer for the bottom screen is allocated from the page
  allocator built in 108. The framebuffer's size is determined by
  the screen's resolution and the color depth chosen for the
  display mode.
- The controller is configured to scan out from that framebuffer
  to its first output path, which feeds the bottom screen.
- A boot-time status check reads back a controller register (a
  status, a frame counter, or whatever the chip offers) and
  confirms the controller is actually running, rather than sitting
  in a configuration limbo. The confirmation is reported through
  the USB CDC-ACM stream from 110.

This sub-issue does *not* address the top screen. That comes in
111b.

## Suggested implementation steps

1. From 101's findings, write the initialization sequence as a
   table of register writes. Include the timing delays the
   datasheet specifies between writes.
2. Drive the table from a single bring-up function.
3. Allocate the bottom screen's framebuffer using 108. Zero it.
4. Configure the controller's first output for the bottom screen.
5. Read back a status register to confirm the controller is
   running, and report through the debug stream.

## Related documents

- `docs/005-display-and-compositor.md` — what later phases build
  on top of this.
- `docs/007-memory-model.md` — the framebuffer lives in the flat
  heap region.

## Blocked by

101 (display controller details), 108 (framebuffer allocation).

## Blocks

112.

## Parent

111.
