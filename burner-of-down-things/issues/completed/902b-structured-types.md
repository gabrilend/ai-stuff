# 902b — Structured types

The second piece of 902.

## Current Behavior

Built. `src/081-the-shape-types.lua`'s `recognise` now tries, before 902a's
scalar types: `image` (the PNG signature exactly, and `IHDR` where the
first chunk's type must be), `clip` (`ftyp` at bytes 5-8 of an MP4, or
`GIF87a`/`GIF89a` with its screen descriptor) and `table` (a Lua data file
that loads and returns a table, the form 014's `read_record` reads).
Checked by `tests/123-checking-structured-types.lua` against one real file
per type in `tests/fixtures/shape-types/` (a PNG, an MP4 and a GIF made by
ffmpeg, and a station row as a Lua data file); a PNG with one wrong
signature byte is not an image.

Decisions: the structured types are tried first — a GIF's header and a Lua
data file are both valid text, and would otherwise read as `text`. The
table recogniser works on the bytes, not a path, so it does not call
`read_record`; it keeps that function's empty environment and adds what
"never executed for effect" needs when the bytes come from anyone:
precompiled bytecode is refused unread (loading it is not safe in
LuaJIT), the JIT is off for the chunk and a count hook stops it after
1,000,000 instructions (a loop cannot hang the machine), and string
methods are out of reach while it runs (`("x"):rep(1e9)` cannot exhaust
memory), restored afterwards.

## Intended Behavior

Recognisers for `table` (a Lua data file that loads and returns a table),
`image` (a PNG signature), `clip` (an MP4 or GIF signature).

## Suggested Implementation Steps

1. The `table` recogniser (014's `read_record`, sandboxed, never executed
   for effect). 2. The `image`/`clip` signature recognisers (magic bytes).
   **Test:** one fixture per type is recognised; a corrupt PNG signature
   is not mistaken for an image. Done.

## Blocked by

- 902a
