# 207 — Each Boundary Fades on Its Own Size

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | 205, 206 |
| Blocks | 408, 409 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

Every fence draws at full strength whenever it is on screen, so the whole-city
view is a wireframe drawing rather than a painting.

## Intended behavior

Each boundary gets its opacity from **its own on-screen width**, not from the
global zoom.

| On-screen width | Fence |
| --- | --- |
| under about 24 pixels | not drawn at all |
| about 24 to 64 | opacity ramps from nothing to solid |
| over about 64 | solid, at its level's weight |

### Why per-place and not per-zoom

Because the painting is in perspective. At native zoom a harbour block is around
300 screen pixels across while a block by the north wall is around 40. **A single
global threshold makes the harbour cage appear far too late or the northern cage
far too early**, and there is no value that is right for both.

Fading each place on its own size handles the perspective without anyone
correcting for it, in the same way that hand-traced fences carry the
foreshortening for free.

### The override that makes it usable

**Whatever is under the pointer, and whatever is selected, always draw at full
strength** — whatever their size, including places too small to draw otherwise.

Without this, the smallest blocks would be permanently invisible and therefore
unaimable, and a selected place could vanish when you zoomed out to see where it
sat. With it, the map is clean at rest and always shows you what you are actually
touching.

This is why [205](205-hit-testing-is-one-pixel.md) must answer every frame rather
than only on click.

### The thresholds are tunables

24 and 64 come from `input/what-to-start-with`, not the source. They want feeling
rather than reasoning and will be adjusted against the real painting.

**Working ruling:** "width" means the bounding box width in screen pixels, being
cheaper than the square root of the on-screen area, with the difference only
showing on very elongated places.

## Suggested implementation steps

1. Compute each place's on-screen bounding box during the same cull that
   [206](206-the-fence-is-one-pixel-in-screen-space.md) already performs, so the
   width costs nothing extra.
2. Map width to opacity with a smooth ramp between the two thresholds, clamped at
   both ends.
3. Override to full opacity for the hovered and the selected place.
4. Skip drawing entirely below the lower threshold rather than drawing at zero
   opacity — that is the saving that keeps the whole-city view cheap.
5. Check by eye at the whole-city view that the painting reads as a painting, and
   that descending brings the cage up gradually rather than switching it on.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [The map surface](../docs/002-the-map-surface.md)
