# 017-write-a-picture — info

Writes a surface out as a PNG, which means writing a compressor.

For a general: there is no way to write this format without compressing the data, because the format's contents are defined to be a compressed stream. The format does permit blocks marked "not actually compressed", and a picture built from those is valid and opens everywhere -- and is about six times larger than it should be. This project writes two pictures per character for potentially six thousand characters, so six times larger is the difference between a set somebody can keep and a set somebody deletes.

So the real thing, in three parts:

  * finding repeats -- most of a blurred picture is a slow gradient, and a     gradient repeats once you look at it the right way   * the standard code table, which spends fewer bits on the byte values that     turn up most   * the row transformations, which are what turn a gradient into a repeat in     the first place, and are the single largest win available here

Nothing here reads a PNG. The test in `020` carries a small reader, because the only way to know a compressor is right is to decompress what it wrote.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `017-write-a-picture.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.crc32(text, seed)` | The checksum a PNG chunk carries. |
| `M.adler32(bytes, from, to)` | The checksum the compressed stream carries, over the bytes before compression. |
| `M.deflate(bytes, count, chain_limit)` | The bytes, compressed, wrapped as the stream a PNG carries. |
| `M.encode(raw, width, height, channels)` | Pixel bytes in, a whole PNG file out. |
| `M.write_grey(path, surface, canvas_module)` | A surface, written to disk as grey. |
| `M.write_rgba(path, red, green, blue, alpha, canvas_module)` | Four surfaces, written to disk as one colour picture with transparency. |

### `M.adler32(bytes, from, to)`

The checksum the compressed stream carries, over the bytes before compression.

Two running sums, one of the bytes and one of that sum, both kept modulo the largest prime below sixty-five thousand five hundred and thirty-six. The second sum is what makes it notice bytes swapped around, which a plain total would not.

### `M.deflate(bytes, count, chain_limit)`

The bytes, compressed, wrapped as the stream a PNG carries.

Repeats are found with a hash of every three consecutive bytes. Each hash remembers the most recent place it was seen and each place remembers the one before it, so following that chain walks backwards through everywhere the next three bytes have appeared -- and the longest run from any of them is the repeat to write.

The chain is walked only so far. Blurred pictures have enormous numbers of places matching any three bytes, and the hundredth candidate almost never beats the first few; an unbounded walk turns a fast compressor into a slow one for a fraction of a percent.

### `M.encode(raw, width, height, channels)`

Pixel bytes in, a whole PNG file out.

`channels` is one for grey and four for grey-with-transparency... four for colour-with-transparency. One and four are the only two this project makes.

### `M.write_rgba(path, red, green, blue, alpha, canvas_module)`

Four surfaces, written to disk as one colour picture with transparency.

Four separate surfaces rather than one with four numbers per pixel, so that everything in `016` works on them unchanged -- the arrow layer draws into the transparency exactly the way it draws into the colours, and there is no second kind of canvas to maintain.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `bit_writer()` | Somewhere to put bits, in the order this format wants them. |
| `self.put(value, width)` | A plain number, lowest bit first. |
| `self.code(value, width)` | A code-table entry, highest bit first. |
| `self.finish()` |  |
| `write_literal(out, value)` | One uncompressed byte, in the standard code table. |
| `write_match(out, length, distance)` | A repeat: how many bytes, and how far back they were. |
| `filter_rows(raw, width, height, channels)` | Each row rewritten as differences, whichever difference makes it smallest. |
| `chunk(kind, body)` | One PNG chunk: how long, what it is, what it says, and its checksum. |

## Where it sits

Used by `020-test-the-ink`.
