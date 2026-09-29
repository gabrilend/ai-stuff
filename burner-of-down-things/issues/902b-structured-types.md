# 902b — Structured types

The second piece of 902.

## Current Behavior

902a recognises scalar shapes only.

## Intended Behavior

Recognisers for `table` (a Lua data file that loads and returns a table),
`image` (a PNG signature), `clip` (an MP4 or GIF signature).

## Suggested Implementation Steps

1. The `table` recogniser (014's `read_record`, sandboxed, never executed
   for effect). 2. The `image`/`clip` signature recognisers (magic bytes).
   **Test:** one fixture per type is recognised; a corrupt PNG signature
   is not mistaken for an image.

## Blocked by

- 902a
