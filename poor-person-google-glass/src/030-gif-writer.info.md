<!-- written by Claude (Opus 5.5), 2026-10-11, for issue 011 (pictures and moving pictures): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 030-gif-writer

GIF files written from scratch (GIF89a: header, one 256-colour table, looping extension, frames compressed by LZW). Frames are ffi RGBA byte arrays.

| Offers | Takes | Gives |
|---|---|---|
| `palette(frames, width, height, limit, step)` | frames; at most 256 colours; sample every step-th pixel | list of {r,g,b} chosen by median cut, weighted by how often each colour appears |
| `mapper(palette)` | | a function(frame, width, height) → ffi uint8 colour numbers, each pixel's nearest palette colour (remembered per colour) |
| `lzw(indices, count)` | colour numbers | the frame's compressed data, sub-blocked, with its code size and ending |
| `header(width, height, palette)`, `frame_block(width, height, compressed, delay)`, `trailer()` | delay in hundredths of a second | the file's pieces, to be joined in order |
