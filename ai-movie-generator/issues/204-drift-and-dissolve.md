# 204 — drift and dissolve

phase 2, shots into motion

**Depends on:** 203

## Current behavior

Only camera moves exist.

## Intended behavior

drift: chained image-to-image repaints of the previous frame at the shot's strength, same seed, k painted frames per second (default 3) with crossfades between. dissolve: two keyframes crossfaded with a slight push-in.

## Suggested implementation steps

1. The drift chain (painting is sequential on the GPU; the in-between crossfades and encoding are not).
2. Dissolve via ffmpeg.
3. Record the cost per second of drift in the render log.

## Related documents

- docs/datapath-shot-to-clip.md
