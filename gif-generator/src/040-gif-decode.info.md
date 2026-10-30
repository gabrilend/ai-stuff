# 040-gif-decode — the gif reader

The one complete GIF decoder in the studio: plain LuaJIT, no LÖVE, usable
on its own. Reads every feature a gif can carry (a frame's own palette,
partial frames, see-through pixels, every disposal, interlaced rows), and
can shrink and skip frames while it reads. The viewer's workers
(`viewer/decode-worker.lua`) use it.

## Usable surface

- **decode(bytes, options) → info**
- **decode_file(path, options) → info** — options `max_size`,
  `frame_step`, `on_frame(index, pixels, width, height, delay_cs)`, and
  `structure = true` for one record per stored frame (rectangle, local
  palette, interlacing, code size, raw delay, disposal, transparency, raw
  indices, and whether its stream was whole).
- **facts(bytes, options) → info** — the same, without keeping pictures.
  `info` always carries `signature`, `loop`, `trailer_at_end`,
  `global_colours`, `global_palette` and the source size and frame count.
- **facts_line(info) → string** — `signature=… width=… height=… loop=…
  frames=… trailer=…`, the line the shell tests grep.

CLI: `luajit src/040-gif-decode.lua --facts file.gif` prints that line.

Every test that reads a gif reads it with this (issue 701b): the encoder's
proof (005), the shape films' (`test-shape-films`), the round trip (044).
Other projects take a checked copy, named `gif-decoder.lua`, with
`./install-into` and `./check-copy`.

The options and the shape of `info` are written out in
`viewer/viewer.info.md`, under "040-gif-decode.lua".
