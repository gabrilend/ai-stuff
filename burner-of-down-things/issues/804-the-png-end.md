# 804 — The .png end

Canvas in, `.png` out: the wall (802), the painter (803), and a PNG writer of our own.

## Current Behavior

Pixels can be painted; nothing writes a file.

## Intended Behavior

A PNG writer with uncompressed deflate blocks (CRC-32 and Adler-32 by hand), modelled on delta-version's readme-gallery `png.lua`. A command `paint <canvas.lua>` writes `<name>.png` and its card (809).

## Suggested Implementation Steps

1. The writer. **Test:** an independent decoder in the checks reads the file back to exactly the pixels written; `file` and an image viewer open it.
2. The command. **Test:** the same canvas and seed give byte-identical files.

## Blocked by

- 802
- 803
