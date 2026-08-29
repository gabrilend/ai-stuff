# Phase 1 — The Canvas

One painting on screen, pannable and zoomable, and nothing else. No game in it at
all.

**Five issues. None complete. Nothing has been built.**

| Issue | State |
| --- | --- |
| [101 — the painting is one texture](101-the-painting-is-one-texture.md) | not started |
| [102 — the view is an offset and a scale](102-the-view-is-an-offset-and-a-scale.md) | not started |
| [103 — the window and its two panes](103-the-window-and-its-two-panes.md) | not started |
| [104 — pan and zoom by hand](104-pan-and-zoom-by-hand.md) | not started — bindings blocked on open question 1 |
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

## What is blocked, and on what

The pan and zoom bindings are a working ruling rather than a decision, because the
tracing tool needs the same gestures for a different job — a drag there may mean
moving a vertex. The two programs must not disagree about what an unqualified drag
does. See open question 1.

## What the board is

A stand-in. `inspiration-pictures/vision-map.png` is somebody else's painting and
cannot ship. Almost nothing in this phase depends on *this* picture — only on
there being one, in perspective, of a city with streets in it.
