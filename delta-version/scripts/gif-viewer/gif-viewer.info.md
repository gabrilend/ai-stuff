# gif-viewer

A LÖVE window for watching a folder of gifs (issue 062). Black background,
one gif at a time or all at once in a grid, every gif animating.

## Running it

    view-gifs                       the shape gifs in /home/ritz/pictures/shape-gifs
    view-gifs /some/folder          any folder of gifs
    view-gifs --selftest [--screenshots=/folder]
                                    load everything, save a picture of each view,
                                    print a one-line report, quit (exit 0 / 1)

| Key | Single view | Grid view |
|-----|-------------|-----------|
| left / right | previous / next gif | move the highlight |
| up / down | — | move the highlight a row |
| space | next gif | move the highlight on |
| g | open the grid | back to the single view, on the highlighted gif |
| enter, mouse click | — | open the highlighted / clicked gif |
| mouse wheel | — | scroll |
| esc, q | quit | quit |

## Files

| File | What it is |
|------|------------|
| `view-gifs` | the launcher; the gif folder is hard-coded and overridable |
| `conf.lua` | window settings (resizable, 960×960 to start) |
| `main.lua` | the window: keys (a dispatch table per view), playback, drawing, memory limits |
| `decode-worker.lua` | a background decoder; one per CPU core but one |
| `gif-decode.lua` | the gif reader: plain LuaJIT, no LÖVE, usable on its own |
| `gif-decode-test.lua`, `test-gif-viewer.sh` | the tests |

## gif-decode.lua

### decode(bytes, options) → info
### decode_file(path, options) → info

| option | type | meaning |
|--------|------|---------|
| `max_size` | integer | shrink (nearest sampling) so neither side exceeds this |
| `frame_step` | integer | keep every Nth frame; skipped frames' delays go to the kept one before them, so the loop's length is unchanged |
| `on_frame` | function(index, pixels, width, height, delay_cs) | receive each frame as it is finished; `pixels` is an ffi `uint8_t` array of width×height×4 (R, G, B, A), valid only during the call |

`info`:
- `width`, `height`: output size, in pixels (integers);
- `source_width`, `source_height`: the file's own size (integers);
- `frame_count` (integer);
- `frames`: a list of `{ pixels, delay_cs }`, present only when there is no
  `on_frame`.

Reads any gif:
- global and per-frame palettes;
- frames covering part of the screen;
- transparency;
- all three disposal rules;
- interlaced rows.

A delay of 0 or 1 hundredths becomes 10, as browsers do. A truncated or
foreign file is an error naming the byte.

## Memory

- **Full size:** at most 5 gifs are held at full size, the least recently
  seen being dropped.
- **The grid:** it keeps one copy of every gif, shrunk to 128 pixels, every
  second frame. That is about 130 MB of textures for the 29 shape gifs.
- **Order of decoding:** the gif on screen is decoded first ("urgent"),
  then its neighbours and the grid copies ("background").

## Tests

`test-gif-viewer.sh` passes 19 reader checks. They cover:
- a round trip through the gif-generator's encoder, every pixel;
- a gif built by hand with every feature;
- every real gif's frame count against an independent block walker;
- one frame against ImageMagick, byte for byte;
- the grid copies' size, frame count and loop length.

It then opens the real window in self-test mode, and both views must be
drawn.
