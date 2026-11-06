# 205 — the gif generator bridge

phase 2, shots into motion

**Depends on:** 201

## Current behavior

Shots marked `by = "gif"` cannot be rendered.

## Intended behavior

A shot with `by = "gif"` and a `score` file is rendered by the gif generator (/mnt/mtwo/programming/ai-stuff/gif-generator) at the film's size and the shot's length, then converted to `<shot id>.mp4` at the film's fps. Used for visions, energy, abstract sound, title cards and transitions — the "difficult to perform" sections diffusion handles poorly. The bridge reads that project's .info.md files for its renderer's entry point rather than guessing.

## Suggested implementation steps

1. Find the gif generator's non-interactive render entry (its docs, then src/*.info.md).
2. Call it with the score; check the gif's length.
3. Convert to mp4.
4. A starter score in `assets/scores/` for a "vision" shot.

## Related documents

- docs/datapath-shot-to-clip.md
- docs/hardware-and-models.md
