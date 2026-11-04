# 504 — mouth shapes

phase 5, the monologue booth

**Depends on:** 502

## Current behavior

The mouth does not move with the voice.

## Intended behavior

A few mouth-shape keyframes (closed, half, open) painted by inpainting the mouth region of the portrait, switched by loudness.

## Suggested implementation steps

1. Mouth mask (by hand at first, later from a pose/face controlnet).
2. Inpaint three shapes.
3. Switch per frame.

## Related documents

- docs/datapath-monologue.md
