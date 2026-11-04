# 303 — the beat sheet viewer

phase 3, the ear

**Depends on:** 302

## Current behavior

The beat sheet can only be read as text.

## Intended behavior

A viewer that draws the envelope, onset ticks and coloured section bands as a PNG. Reads only the beat sheet.

## Suggested implementation steps

1. Draw into a pixel buffer in Lua, write PNG (or PPM → ffmpeg).
2. Test on the generated click track.

## Related documents

- docs/datapath-listening.md
