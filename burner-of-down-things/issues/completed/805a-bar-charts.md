# 805a — Bar charts

The first piece of 805.

## Current Behavior

The geometry is built: `src/074-the-chart-canvas.lua`'s `bars(data, width,
height)` returns each bar's pixel box, proportional to its value against
the largest in `data`. It paints nothing itself (804's painter is not
built) and does not yet colour the midline (801c is not built); those are
later pieces to draw on this one. Checked by
`tests/075-checking-the-chart-canvas.lua`.

## Intended Behavior

Canvas word `chart{ kind = "bars", data = {...}, labels = {...} }` over
axes; each bar's height proportional to its value, its midline drawn in
the flair (801c).

## Suggested Implementation Steps

1. The axis/bar-geometry function (data → pixel heights). Done:
   `074-the-chart-canvas.lua`'s `bars`.
2. Drawing each bar as a flaired surface. **Test:** bar heights in pixels
   are proportional to the data (a value twice as large draws twice as
   tall, within rounding). Deferred: needs 804's painter and 801c's flair.

## Blocked by

- 804
- 801c
