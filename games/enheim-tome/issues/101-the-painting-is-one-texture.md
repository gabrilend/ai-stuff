# 101 — The Painting Is One Texture

| | |
| --- | --- |
| Phase | 1 — The Canvas |
| Blocked by | — |
| Blocks | 102, 105, 204 |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | — |

## Current behavior

Nothing exists. There is no program.

## Intended behavior

The whole board is **one image held as one texture**, drawn in one call.

The arithmetic that permits this is worth restating, because every later decision
leans on it. The painting is 6148 by 4092 pixels — 25,157,616 of them. At four
bytes each that is about 96 MiB held raw, and the mipmap chain adds a third for
roughly 128 MiB resident. Any desktop card carries that without complaint, and
6148 is well under the 8192 that even modest hardware offers as a maximum texture
dimension.

So there is **no tile pyramid, no streaming, and no level-of-detail system**. That
is the single largest simplification available to this project and it exists only
because the board is one fixed image rather than a world.

**Mipmaps are not optional.** At the whole-city view the painting is minified
about five times, and without the successively halved copies for the card to
sample from, the roofs shimmer and crawl as you move — an artefact that looks
like a bug in the drawing and is actually a missing texture setting.

The measurements above must be **read from the file at load**, not compiled in.
The moment a different painting arrives, a hard-coded 6148 is a lie in the source
rather than a fact on disk.

## Suggested implementation steps

1. Load the image named by `input/what-to-start-with`, defaulting to the
   stand-in in `inspiration-pictures/`.
2. Read its width and height from the loaded image; store them; never write them
   down anywhere else.
3. Create the texture with mipmaps generated, and linear filtering with mipmap
   selection so minification samples the chain.
4. Refuse loudly if the image's larger dimension exceeds the card's maximum
   texture size, naming both numbers. Do not silently downscale — a quietly
   halved board would make every traced coordinate wrong by a factor of two.
5. Report the resident cost at startup — pixels, bytes, and bytes with mipmaps —
   so the number in the documents can be checked against the number in the
   program rather than trusted.

## Related documents and tools

- [The map surface](../docs/002-the-map-surface.md)
- [The notice on the stand-in board](../inspiration-pictures/NOTICE.md)
