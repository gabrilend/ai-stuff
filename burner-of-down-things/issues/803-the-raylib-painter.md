# 803 — The raylib painter

A small C program that takes a compiled draw list and paints it with raylib — lines and surfaces, anti-aliased — into an off-screen texture, then writes the raw pixels out ([067](../docs/067-datapath-the-studio.md), *each end*).

## Current Behavior

raylib is built as a static library in `/home/ritz/programming/ai-stuff/libs/c/raylib/src/libraylib.a`; nothing here uses it.

## Intended Behavior

- Reads a draw list (a binary of flat arrays: kinds, points, colours, widths) from a file, opens a hidden window, draws into a render texture of the requested size, reads the pixels back, and writes them raw (width, height, RGBA rows top first).
- Draws: ground, lines of a width, filled surfaces (polygons), arrows (line and head), text labels (raylib's default font first; a chosen font later), and the flair on a surface's midline by the four quarter colours 801 computes.
- Never encodes an image itself: raylib's own export is left alone.
- On a machine with no display it refuses, naming why.

## Suggested Implementation Steps

1. Build against the static library; a hidden window; a render texture; read back. **Test:** a draw list of one white pixel on black reads back exactly.
2. Lines, surfaces, arrows, labels, flair. **Test:** a known draw list gives known pixel counts per colour (within anti-aliasing tolerance at edges, exact in flat interiors).
3. The same draw list gives the same bytes twice.

## Blocked by

- 801
