# 017a-read-a-picture — info

Reads a PNG somebody else wrote.

For a general: `017` writes pictures and this reads them, and until now nothing here needed to read one -- every picture this project made, it made from numbers it already had. That changes the moment a diffusion model hands back a finished image and something has to look at it and say whether the character is in there.

So this is a decompressor, which is the compressor in `017` run backwards and then some: that one only ever emits the standard code table, and a picture from anywhere else will use a table built for its own contents and written into the file ahead of the data. Both are handled here.

Numbered to sit beside `017`, which it is the other half of.

It also gives the two of them something they did not have: a way to check each other. A round trip through one misunderstanding twice proves nothing -- but this was written from the format description, to read what an outside program produces, so agreement between them is worth something.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `017a-read-a-picture.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.inflate(text, from)` | A compressed stream, back to the bytes that went into it. |
| `M.read(path)` | One PNG, as brightness values between zero and one. |

### `M.read(path)`

One PNG, as brightness values between zero and one.

Colour is flattened to brightness on the way out, weighted the way an eye weighs it. Everything that reads a picture in this project is asking about light and dark -- whether the strokes are where they should be -- and none of it cares what colour they are.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `bit_reader(text, position)` | Bits out of a byte string, lowest first -- the order this format packs them. |
| `self.take(width)` | A plain number, lowest bit first. |
| `self.align()` | Forget the rest of the current byte. Stored blocks begin on a boundary. |
| `huffman(lengths)` | A code table, from how many bits each symbol is given. |
| `decode(reader, table)` | One symbol. |
| `push(byte)` |  |
| `unfilter(rows, width, height, channels)` | The row transformations undone. |
| `project_read(path)` | Reading a file without dragging the whole project in. |

## Where it sits

Used by `035-test-the-machine`, `046-two-ways-of-saying-it-is-good`, `048-what-a-higher-tier-buys`.
