# 805b — Line and dot charts

The second piece of 805.

## Current Behavior

Built. `src/074-the-chart-canvas.lua` now has one axis geometry, `axes`,
that `bars` (805a), `lines` and `dots` share, and the canvas word
`chart{kind, data, labels, width, height}`. A line's points and the dots
sit at each slot's middle and its bar's top. Geometry only: 804 paints it.
Checked by `tests/133-checking-lines-and-dots.lua`.

## Intended Behavior

`chart{ kind = "lines" }` and `chart{ kind = "dots" }`, sharing 805a's axis
geometry: a line through the data's points, or one point per datum.

## Suggested Implementation Steps

1. The axis geometry factored out of 805a for reuse.
2. Line and dot drawing over it. **Test:** a line chart's points fall on
   the same axis positions 805a's geometry computes for the same data.
   Done.

## Decisions

- The shared geometry is `axes(data, width, height)`, and `bars` now uses
  it unchanged in behaviour (805a's check still passes as written).
- A point sits at its slot's middle and its bar's top, so a line chart and
  a bar chart of the same data agree point for point.
- A dot's radius is a share of a slot (0.15), so dots scale with the chart.
- A negative datum is refused for every kind: the axis starts at 0, and a
  bar below it had no meaning in 805a either.
- The canvas word itself is `chart{kind, data, labels, width, height}`;
  labels are optional and, when given, one per datum.

## Blocked by

- 805a
