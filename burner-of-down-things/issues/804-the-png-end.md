# 804 — The .png end

Canvas in, `.png` out: the wall (802), the painter (803), and a PNG writer of our own.

## Current Behavior

Step 1 is built: `src/149-the-png-writer.lua` encodes RGBA or RGB pixels
as a PNG of stored deflate blocks, CRC-32 and Adler-32 by hand, and
writes it through a neighbour file and a rename. Checked by
`tests/150-checking-the-png-writer.lua`: an independent decoder in the
check reads each file back to exactly the pixels written, `file` reads it
as a PNG of the right size, and the same pixels give the same bytes.
Step 2, the `paint <canvas.lua>` command, needs the wall (802) to read a
canvas and the painter (803, raylib) to make its pixels, so nothing yet
writes a `.png` from a canvas.

## Intended Behavior

A PNG writer with uncompressed deflate blocks (CRC-32 and Adler-32 by hand), modelled on delta-version's readme-gallery `png.lua`. A command `paint <canvas.lua>` writes `<name>.png` and its card (809).

## Suggested Implementation Steps

1. The writer. **Test:** an independent decoder in the checks reads the file back to exactly the pixels written; `file` and an image viewer open it. Done (`file` checked; an image viewer is the owner's to open).
2. The command. **Test:** the same canvas and seed give byte-identical files.

## Decisions

- The writer is built ahead of 802 and 803, since it takes pixels and
  needs neither: only the command that feeds it does.
- RGBA is the default (what 803's painter reads back from its render
  texture); RGB is kept for stills with no transparency. Depth 8, no
  interlace, every row filter 0 — the bytes as they are.
- No compression and no extra chunks (no time, gamma or text), so a file
  depends only on its pixels; larger files are the accepted cost.
- The check's decoder is written separately (a bitwise CRC with no table,
  its own stored-block reader) and refuses anything but what this writer
  makes, rather than guess.

## Blocked by

- 802
- 803
