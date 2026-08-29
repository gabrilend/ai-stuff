# 002 — The Map Surface

The datapath of the left-hand pane: how one painting becomes a thing you can pan
and zoom, and the strictly limited set of marks allowed on top of it.

## The painting

One image, and it is the entire game board — there is no second map, no minimap,
no zoomed-out abstraction. Everything the game ever shows you is this picture
with marks on it.

That image is currently `inspiration-pictures/vision-map.png`, which is **a
stand-in and cannot ship** — it is somebody else's painting. See
[the notice](../inspiration-pictures/NOTICE.md). Almost nothing here depends on
*this* picture, only on there being one, in perspective, of a city with streets
in it; what would have to be redone is the tracing, and only the tracing.

Its measurements as of writing are 6148 by 4092 pixels, 8-bit RGBA. **These
numbers should be read from the file by a reporting tool rather than trusted from
this page** — the moment a different painting arrives they are wrong here and
right there. What follows is the arithmetic they imply, which is what actually
matters.

### It fits in one texture, and does not need tiling

25,157,616 pixels, at four bytes each, is about 96 MiB held raw. The mipmap
chain — the successively halved copies the card samples from when the image is
minified, without which the roofs shimmer and crawl as you zoom out — adds
another third, for roughly 128 MiB resident.

That is comfortable on any desktop card, and 6148 is well under the 8192 or 16384
maximum texture dimension modern hardware offers. **So the painting is one
texture, drawn in one call, with a pan offset and a scale factor.** No tile
pyramid, no streaming, no level-of-detail system. This is the single largest
simplification available to the project and it is available only because the
board is one fixed image.

If a second painting ever joins it — see the seasons entry in
[open questions](010-open-questions.md) — holding several raw would not fit, and
they would need converting ahead of time into a compressed texture format the
card reads natively, dropping each to roughly 24 MiB. That conversion also
matters for a reason unrelated to memory: decoding a 25-megapixel PNG takes on
the order of a second, which would freeze the game at the exact moment a swap
happened.

## Pan and zoom

The view is two numbers and a scale: where in the painting the top-left of the
pane sits, and how many screen pixels one painting pixel occupies.

With a 1600 by 900 window and a tome around 420 wide, the map pane is roughly
1180 by 900. That gives:

| Zoom | What you see |
| --- | --- |
| 0.192 | The whole painting across the pane's width, letterboxed about 57 pixels top and bottom because the painting is proportionally wider than the pane. The floor — there is no reason to go below it. |
| 1.0 | Native pixels. The ceiling for honest detail. |

**About a five-fold range**, which is small for a map application and is a gift.
Past 1.0 the painting is being magnified, not revealed; if zooming further is
allowed at all it should look like honest blur rather than pretending to more
city.

Input bindings for panning and zooming are not decided. See
[open questions](010-open-questions.md).

## What the map is allowed to draw

Four things, in this order, every frame:

1. **the painting**
2. **the cage** — one-pixel fences, see [the fence network](003-the-fence-network.md)
3. **the filters** — hatching, see [filters and the weave](005-filters-and-the-weave.md)
4. **the glow**

Nothing else, and never text. When something new wants to appear on the map, the
first question is whether it can be expressed as a filter, because a filter costs
the map no new rules. Where-you-are, for instance, turned out to be answerable
without a fifth mark at all — see [the day and the curve](007-the-day-and-the-curve.md).

## The block-identity buffer

Between the painting and everything drawn over it sits one offscreen image the
size of the pane, where each pixel holds the integer identity of whichever block
covers it, or zero for unfenced ground. It is made by filling every block's
polygon with its own identity number.

It does two jobs, and it is worth building for either one alone:

- **Hit-testing.** Which block is under the pointer is one pixel read. No
  point-in-polygon tests, no spatial index, no bounding-box hierarchy.
- **Filter rendering.** Every filter is then a single pass: for each pixel, look
  up its block, look up that block's reading in each active filter, evaluate the
  hatch patterns, resolve the weave.

It is remade whenever the view moves, which is a few hundred filled polygons —
nothing for a graphics card, even every frame during a drag.

## The glow

Warm light lifting a block's interior. **Additive light, not a coloured tint** —
this matters, because a translucent tint reads as one thing over harbour blue,
another over slum brown and another over garden green, whereas added light
brightens all three the same way.

It breathes between about thirty percent and full over roughly two and a half
seconds — slow enough to read as breathing rather than blinking, and floored well
above zero so a glowing block never disappears.

**It means *this one*.** Exactly one meaning, used in more than one place:

- the block you have selected
- the block a swept time-curve is pointing at

There is one behaviour change at high zoom. When you are zoomed so far in that
the selected block is the only one fully on screen, marking it is pointless — it
is obviously the one — so the glow flips to following the pointer instead, as an
aiming aid. The threshold that triggers this is a tunable, not a constant, and
the player can switch the behaviour off. The exact tunable is undecided; see
[open questions](010-open-questions.md).

## Datapath summary

```
inspiration-pictures/vision-map.png
        │
        │  loaded once, mipmapped
        ▼
   one texture ────────────────┐
                               │
the fence network ──┐          │
                    ▼          ▼
          block-identity    the painting drawn
             buffer         at (pan, zoom)
                    │          │
        ┌───────────┤          │
        │           │          ▼
        ▼           ▼      ┌────────────┐
   pointer →     filter    │ the pane   │
   block id      shading ──▶            │
                           │            │
   selection ─── glow ─────▶            │
   time-curve                └────────────┘
   sweep
```

## Related documents

- [What this game is](001-what-this-game-is.md) — why the map carries no text
- [The fence network](003-the-fence-network.md) — where blocks come from
- [Filters and the weave](005-filters-and-the-weave.md) — what shades them
- [Open questions](010-open-questions.md)
