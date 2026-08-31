# Phase 1 — The Canvas

One painting on screen, pannable and zoomable, and nothing else. No game in it at
all.

**Five issues. None complete. Nothing has been built.**

| Issue | State |
| --- | --- |
| [101 — the painting is one texture](101-the-painting-is-one-texture.md) | not started |
| [102 — the view is an offset and a scale](102-the-view-is-an-offset-and-a-scale.md) | not started |
| [103 — the window and its two panes](103-the-window-and-its-two-panes.md) | not started |
| [104 — pan and zoom by hand](104-pan-and-zoom-by-hand.md) | not started — bindings now settled |
| [105 — a texture converted ahead of time](105-a-texture-converted-ahead-of-time.md) | not started |

## What this phase is for

A viewer with no logic in it is what you reach for when you cannot tell whether a
fault is in the drawing or in the thinking. So this phase produces something that
should stay runnable and unchanged for the whole life of the project, long after
everything else has grown around it.

## What was settled before any of it was written

**The board is one texture.** 25 million pixels, about 96 MiB raw and 128 with
mipmaps, on hardware whose maximum texture dimension is well above the painting's
6148. That single fact removes a tile pyramid, streaming, and a level-of-detail
system from the project entirely — and it is available only because the board is
one fixed image rather than a world.

**The useful zoom range is about five-fold**, from fitting the pane to native
pixels. Small for a map application, and a gift: it is why the whole camera is
three numbers.

**Mipmaps are not optional.** Without them the roofs shimmer at the whole-city
view, which looks like a bug in the drawing and is a missing texture setting.

## What the phase settled while being described

**The hands, and they are inverted on purpose.** Middle drag pans, wheel zooms,
**left click asks and right click acts** — the opposite way round from every
convention. Taken as a stance: the interface asks to be learned rather than
guessed, and refuses the muscle memory a person arrives with.

It dissolved the conflict this phase was blocked on. The worry was that the
tracing tool needs the same gestures for a different job, and that the two
programs would disagree about what a drag means. They do not, because panning is
the middle button and editing is left and right — a drag on empty ground is never
editing in either.

And it paid for something unrelated: the colour rule demands a dimmed control say
more than "no", which an icon alone cannot. **The enquiry hand works on controls
the action hand refuses**, so a greyed button explains itself. A stance taken for
its own sake answered a question in phase 6.

**Past native zoom is allowed, and looks like blur.** No upper clamp beyond a
guard rail. The board is finite and a player leaning in should meet the limit of
the artwork rather than a fiction. The tracing tool gets the same, which turns
placing a vertex on an exact pixel into aiming at something several pixels wide.

**The tome pane is empty until phase 6** — honestly empty, no readouts, no
placeholder. It exists this early so that every visual judgement before then is
made at the real proportions.

## What is blocked, and on what

Nothing. This phase's only recorded question has been answered.

## What the board is

A stand-in. `inspiration-pictures/vision-map.png` is somebody else's painting and
cannot ship. Almost nothing in this phase depends on *this* picture — only on
there being one, in perspective, of a city with streets in it.
