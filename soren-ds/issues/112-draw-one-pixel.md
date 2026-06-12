# 112 — Draw one pixel

## Current behavior

Both framebuffer pointers from 111a and 111b are reachable but no
code has yet written to them. The screens, even with the
controller initialized and both outputs scanning, show whatever
uninitialized memory happens to live at the framebuffer addresses
— likely garbage or blank panels.

## Intended behavior

The kernel, at the end of its boot sequence, writes a single
unmistakable pixel to a known position on each screen. The pixel
is a bright, fully-saturated color chosen so a human can spot it
immediately on the dark or noisy startup display. The position is
at the center of each screen so it's hard to miss. The two pixels
are different colors so the developer can confirm at a glance
which framebuffer drives which panel.

This is the moment the project earns its first visible signal:
the device is running our code, our code is reaching both
framebuffers, and both framebuffers are being scanned to the
panels. Everything that took ten issues to reach is validated by
two pixels.

## Suggested implementation steps

1. From the end of the kernel's boot sequence, after all earlier
   initialization, compute the byte offset of the center pixel of
   each screen given the dimensions and color depth reported by
   111a and 111b.
2. Write the chosen color value at each offset — one color for the
   bottom screen, a different one for the top.
3. Loop forever. Do not return — there is nothing to return to.

## Related documents

- `docs/002-roadmap.md` — phase 1.
- `docs/005-display-and-compositor.md`.

## Blocked by

111a, 111b.

## Blocks

113.
