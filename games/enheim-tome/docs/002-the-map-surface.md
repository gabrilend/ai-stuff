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

### A second, flat view is wanted eventually

The same city seen from directly above, where scale is uniform and streets are
clean lines. The painting comes first and the flat view later, and the
requirement on it is exact: **it must register with the painting perfectly**, so
that a place is the same place in both.

That requirement has a consequence worth seeing early. Two independently drawn
pictures cannot register — no amount of care makes one artist's city land on
another's. The only way to get exact agreement is for the flat view to be
**derived from the painting rather than drawn beside it**: work out once how the
painting's pixels sit on a flat ground, and the traced fences project onto that
ground as a schematic map that agrees by construction.

Which quietly resurrects the ground plane this project decided it did not need.
It was declined for distance-honesty, and it comes back for registration. Nothing
about the pixel-only rule changes today — the fences stay in painting pixels — but
the flat view cannot exist without a ground plane, and that is now a known cost
rather than a surprise. See [open questions](012-open-questions.md).

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
[open questions](012-open-questions.md) — holding several raw would not fit, and
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
| 1.0 | Native pixels. Past this the painting is magnified rather than revealed, which is allowed and looks like blur. |

**About a five-fold range of honest detail**, which is small for a map
application and is a gift — it is why the whole camera can be three numbers.

### Past native is allowed, and looks like blur

Zooming beyond 1.0 is permitted, in both the game and the tracing tool, and what
you get is **honest blur** — a bigger, softer painting. No sharpening, no
upscaling that invents detail the picture does not contain.

That is a statement about what the board is: finite. A player who leans in far
enough should meet the limit of the artwork rather than a convincing fiction, and
the tracing tool gets the same magnification, which makes placing a vertex on an
exact pixel a matter of aiming at something three pixels wide instead of one.

## The hands

**Two buttons, two meanings, and they are the opposite way round from what
anybody expects.**

| Input | What it does |
| --- | --- |
| **middle drag** | pans the map |
| **wheel** | zooms, anchored on the pointer |
| **left click** | **selects, and explains** — on a place it selects; on a control it tells you what that control does |
| **right click** | **modifies** — on a control, it presses it |

Looking and doing are separate hands. Left is enquiry; right is action.

**The inversion is deliberate and it is not an accident of taste.** Pressing a
button with the right hand and being told what it does with the left is contrary
to every convention, and it is meant to be: the interface asks to be learned
rather than guessed, and refuses the muscle memory a person arrives with. That is
a stance about what kind of game this is, taken knowingly, and it should not be
quietly softened later by somebody making it friendlier.

What it costs, stated once: a middle-button drag is awkward on a trackpad, and
panning is the thing you do most.

What it buys, which was not the intention: **it answers how a dimmed control
explains itself.** A button that cannot be used here is dimmed, and left-clicking
it says why — the enquiry hand works on controls that the action hand cannot. The
colour rule required that a dimmed button say more than "no", and the two-hand
scheme provides the place for it to speak. See [the tome](007-the-tome.md).

There is also an accidental safety in it. Because the world advances only on a
move or on go — see [the day and the curve](008-the-day-and-the-curve.md) — a
mis-aimed right click mostly *queues* something rather than doing it, and a queued
thing can be taken back. The rudeness is survivable because of a decision made
for entirely unrelated reasons.

The anchoring on zoom matters as much as the button choice: **the painting pixel
under the cursor stays under the cursor**. Anything else feels like the city
sliding away from what you are looking at.

## The zoom also decides what a click selects

Four of the levels in [the places of the city](003-the-places-of-the-city.md) can
be selected — building, block, district, quadrant — and **which one a click lands
on follows the zoom**. Far out, a click takes a quadrant; descend and the same
click takes a district, then a block, then a building.

There is no control to learn, because you aim by moving closer, which you were
doing anyway. And it costs nothing to implement: it reuses the same on-screen-size
rule that fades the cage, so **what you can select is exactly what you can see
outlined**. The two behaviours are one rule wearing two hats.

The price is that selecting a whole district means zooming out first, even when
you already know which one you want.

## The cage shows one level, and swaps

**The fence is one pixel, so it is one colour for all lines.** A single pixel
carries neither a gradient nor a weight, so there is no opacity to vary and no
thickness to distinguish levels by.

Which leaves one question — *is this edge drawn?* — and the answer is already
above: **draw the boundaries of the level you can currently select, and only
those.** At the city view that is the two dozen quadrant lines over an otherwise
clean painting. Descend and the cage **swaps** to districts, then blocks, then
buildings. It does not thicken; it changes.

That makes the promise exact rather than approximate: **the cage is the set of
things you can click.** The interface never has to explain itself, because the
visible lines are the explanation.

It also bounds its own density with no cap needed. Blocks become the selectable
level only when they are roughly 24 to 64 screen pixels across — around 250 of
them on a 1180-wide pane. You never see the whole city's blocks at once, because
by the time blocks are the level you are not looking at the whole city.

### What this deleted

An earlier design had every boundary fading in on its own on-screen width. It
carried a problem that one colour dissolves entirely: since the fence runs down
the middle of a street, **nearly every edge is shared by two blocks**, and each
would have wanted its own opacity for a line that is stroked once. A harbour
block 300 pixels across against an alley of 28 — one stroke, two answers, and
every way of arbitrating produced a visible artefact.

With one colour there is nothing to arbitrate. Gone with it: the two fade
thresholds, the four line weights, and the override that drew whatever was under
the pointer at full strength — which existed to rescue places too small to draw,
and at the selectable level nothing is ever too small.

## What the map is allowed to draw

Four things, in this order, every frame:

1. **the painting**
2. **the cage** — one-pixel fences, see [the fence network](004-the-fence-network.md)
3. **the filters** — hatching, see [filters and the weave](006-filters-and-the-weave.md)
4. **the glow**

Nothing else, and never text. When something new wants to appear on the map, the
first question is whether it can be expressed as a filter, because a filter costs
the map no new rules. Where-you-are, for instance, turned out to be answerable
without a fifth mark at all — see [the day and the curve](008-the-day-and-the-curve.md).

## The identity buffer

Between the painting and everything drawn over it sits one offscreen image the
size of the pane, where each pixel holds the integer identity of **the finest
place that covers it** — a building where buildings have been placed, otherwise
the block — or zero for ground nobody has defined yet.

Everything above that resolves by walking the containment chain upward, which is
a lookup rather than a drawing: a pixel is in this building, therefore this block,
therefore this district, therefore this quadrant. So one buffer answers at every
level, and no separate district buffer or quadrant buffer is ever needed.

It does two jobs, and is worth building for either alone:

- **Hit-testing.** What is under the pointer is one pixel read, then a walk up the
  chain to whichever level the zoom has selected. No point-in-polygon tests, no
  spatial index, no bounding-box hierarchy.
- **Filter rendering.** Every filter is then a single pass: for each pixel, look
  up its place, look up that place's reading **for the person whose model this is**,
  evaluate the hatch patterns, resolve the weave.

It is remade whenever the view moves, which is a few thousand filled shapes —
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
[open questions](012-open-questions.md).

## Datapath summary

```
inspiration-pictures/vision-map.png
        │
        │  loaded once, mipmapped
        ▼
   one texture ────────────────┐
                               │
the fence network ──┐          │
building zones  ────┤          │
                    ▼          ▼
              identity      the painting drawn
               buffer       at (pan, zoom)
                    │          │
        ┌───────────┤          │
        │           │          ▼
        ▼           ▼      ┌────────────┐
   pointer →     filter    │ the pane   │
   place id      shading ──▶            │
        │          ▲        │            │
        │          │        │            │
   walk up    whose model   │            │
   the chain  is this?      │            │
   to the     (the person   │            │
   zoom's     you are)      │            │
   level                    │            │
                            │            │
   selection ─── glow ──────▶            │
   time-curve                └────────────┘
   sweep
```

## Related documents

- [What this game is](001-what-this-game-is.md) — why the map carries no text
- [The fence network](004-the-fence-network.md) — where blocks come from
- [Filters and the weave](006-filters-and-the-weave.md) — what shades them
- [Open questions](012-open-questions.md)
