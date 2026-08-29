# 102 — The View Is an Offset and a Scale

| | |
| --- | --- |
| Phase | 1 — The Canvas |
| Blocked by | 101, 103 |
| Blocks | 104, 204, 206, 207 |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | — |

## Current behavior

The painting exists as a texture. Nothing decides which part of it is on screen.

## Intended behavior

The entire camera is **three numbers**: where in the painting the top-left corner
of the map pane sits, and how many screen pixels one painting pixel occupies.

| Field | Type | Meaning |
| --- | --- | --- |
| `pan_x`, `pan_y` | numbers | position in painting pixels of the pane's top-left |
| `zoom` | number | screen pixels per painting pixel |

There is no camera object with rotation, no matrix stack, no scene graph. Two
conversions are all any other code ever needs, and they are inverses:

- painting to screen: `(p - pan) * zoom`
- screen to painting: `s / zoom + pan`

**Both belong in one place and nowhere else.** Every part of the program that
draws a fence, places a vertex, or asks what is under the pointer goes through
these two, so that a change to how the view works is a change in one file.

### The range has a floor and a ceiling

| Zoom | What it is |
| --- | --- |
| about 0.192 | the whole painting across the pane's width. The **floor** — below it you are looking at letterbox. |
| 1.0 | native pixels. The **ceiling** for honest detail. |

That is roughly a five-fold range, which is small for a map application and is a
gift rather than a limitation. The floor is computed from the pane width divided
by the painting width, never written down — the moment the window resizes or a
different painting loads, a hard-coded 0.192 is wrong.

Since the painting is proportionally wider than the pane, fitting its width
leaves a letterbox above and below of about 57 pixels at a 1600 by 900 window.
That is expected, not a bug to eliminate.

Zooming past 1.0 magnifies rather than reveals. If it is permitted at all it
should look like **honest blur** — no sharpening, no upscaling filter that
invents detail the painting does not contain.

### Panning is clamped, not free

The view cannot wander off the painting. Clamping happens on the pan, after any
zoom change, so that zooming out near an edge pulls the view back in rather than
leaving the board floating in a corner.

## Suggested implementation steps

1. Hold the three numbers in one record with the two conversion functions beside
   them.
2. Compute the zoom floor from the current pane size and painting size, on every
   window resize.
3. Clamp zoom into the floor-to-ceiling range on every change.
4. Clamp pan so the visible rectangle stays within the painting, applying it
   after zoom changes as well as after pan changes.
5. Centre the letterbox rather than pinning the painting to the top, so fitting
   the whole city looks deliberate.
6. Write a test that round-trips a handful of points painting → screen →
   painting at several zooms and asserts they come back where they started.

## Related documents and tools

- [The map surface](../docs/002-the-map-surface.md)
