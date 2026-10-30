# 040-gif-decode — the gif reader

The one complete GIF decoder in the studio: plain LuaJIT, no LÖVE, usable
on its own. Reads every feature a gif can carry (a frame's own palette,
partial frames, see-through pixels, every disposal, interlaced rows), and
can shrink and skip frames while it reads. The viewer's workers
(`viewer/decode-worker.lua`) use it.

## Usable surface

- **decode(bytes, options) → info**
- **decode_file(path, options) → info** — options `max_size`,
  `frame_step`, `on_frame(index, pixels, width, height, delay_cs)`.

The options and the shape of `info` are written out in
`viewer/viewer.info.md`, under "040-gif-decode.lua".
